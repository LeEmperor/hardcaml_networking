(**
  module_name: rx_frame_parser2
  file_name: rx_frame_parser2.ml
  desc:
    Ethernet RX frame parser. Sits downstream of rx_deserializer and consumes
    its byte-stream output (byte [7:0] + valid).

    Detects preamble (0x55) + SFD (0xD5), then emits frame bytes with
    sof / eof / err markers.

    Ethernet frame structure (all bytes in rx order):
      Preamble : 7 × 0x55
      SFD      : 1 × 0xD5
      Dst MAC  : 6 bytes  ─┐
      Src MAC  : 6 bytes   │  emitted with valid=1
      Ethertype: 2 bytes   │  sof=1 on the first data byte (Dst MAC[0])
      Payload  : variable  │
      FCS      : 4 bytes  ─┘
      (eof pulses the cycle after the last frame byte, when valid drops)

  state machine:
    Idle     – waiting for valid to assert
    Preamble – consuming 0x55 preamble bytes
    Data     – passing frame bytes to consumer; sof on first, eof when done
    Err      – bad preamble byte or premature end; hold until valid drops
*)

open Hardcaml

module States = struct
  type t = Idle | Preamble | Data | Err
  [@@deriving sexp_of, compare, enumerate]
end

module I = struct
  type 'a t = {
    clk      : 'a;
    rst      : 'a;
    (* from rx_deserializer -- prefixed to avoid port-name collision with O *)
    rx_byte  : 'a [@bits 8];
    rx_valid : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    byte  : 'a [@bits 8];
    valid : 'a;  (* frame data byte present on `byte` output *)
    sof   : 'a;  (* pulses high on the first frame data byte *)
    eof   : 'a;  (* pulses high the cycle after the last frame byte *)
    err   : 'a;  (* preamble / format error *)
  } [@@deriving hardcaml]
end

let create (inputs : Signal.t I.t) : Signal.t O.t =
  let spec = Reg_spec.create ~clock:inputs.clk ~clear:inputs.rst () in
  let sm = Always.State_machine.create (module States) spec ~enable:Signal.vdd in

  (* set when SFD is seen; cleared on first data byte to generate the sof pulse *)
  let sof_pending = Always.Variable.reg ~enable:Signal.vdd ~width:1 spec in

  (* combinational output wires – default low every cycle *)
  let out_valid = Always.Variable.wire ~default:Signal.gnd in
  let out_sof   = Always.Variable.wire ~default:Signal.gnd in
  let out_eof   = Always.Variable.wire ~default:Signal.gnd in
  let out_err   = Always.Variable.wire ~default:Signal.gnd in

  let preamble  = Signal.of_int ~width:8 0x55 in
  let sfd       = Signal.of_int ~width:8 0xD5 in
  (* prefix ~: binds tighter than '.', so pre-compute the negation here *)
  let not_valid = Signal.( ~: ) inputs.rx_valid in

  Always.(compile [
    sm.switch [

      States.Idle, [
        when_ inputs.rx_valid [
          if_ Signal.(inputs.rx_byte ==: preamble)
            [ sm.set_next States.Preamble ]
            [ if_ Signal.(inputs.rx_byte ==: sfd)
                (* PHY stripped the preamble -- jump straight to data *)
                [ sm.set_next States.Data;
                  sof_pending <-- Signal.vdd ]
                [ sm.set_next States.Err;
                  out_err <-- Signal.vdd ] ]
        ]
      ];

      States.Preamble, [
        when_ inputs.rx_valid [
          if_ Signal.(inputs.rx_byte ==: preamble)
            [] (* more preamble -- stay *)
            [ if_ Signal.(inputs.rx_byte ==: sfd)
                [ sm.set_next States.Data;
                  sof_pending <-- Signal.vdd ]
                [ sm.set_next States.Err;
                  out_err <-- Signal.vdd ] ]
        ];
        (* valid dropped before SFD -- malformed / aborted frame *)
        when_ not_valid [
          sm.set_next States.Err;
          out_err <-- Signal.vdd
        ]
      ];

      States.Data, [
        when_ inputs.rx_valid [
          out_valid <-- Signal.vdd;
          (* first data byte after SFD: emit sof pulse and clear pending flag *)
          when_ (Variable.value sof_pending) [
            out_sof     <-- Signal.vdd;
            sof_pending <-- Signal.gnd
          ]
        ];
        (* valid dropped -- frame ended normally *)
        when_ not_valid [
          out_eof <-- Signal.vdd;
          sm.set_next States.Idle
        ]
      ];

      States.Err, [
        out_err <-- Signal.vdd;
        when_ not_valid [
          sm.set_next States.Idle
        ]
      ]

    ]
  ]);

  { O.
    byte  = inputs.rx_byte;
    valid = Always.Variable.value out_valid;
    sof   = Always.Variable.value out_sof;
    eof   = Always.Variable.value out_eof;
    err   = Always.Variable.value out_err;
  }
