(**
  module_name: rx_frame_parser
  file_name: rx_frame_parser.ml
  desc:
    this is intended to be the frame parsing logic on the RX side

    input:
      we take in the following from the rx_deserializer
        1. byte [7:0]
        2. valid

    output:
      we output the bytes, with a valid flag as we parse through the bytes in the frame
      1. byte [7:0]
      2. valid

    logic:
      run through a state machine to parse apart the following:
        1. idle -> preamble detection
        2. preamble detection -> sfd detection
        3. sfd detection -> payload detection

    notes:
      downstream is meant to handle the FCS item
 *)

open Hardcaml

module States = struct
  type t = Idle |
    Preamble |
    Data | 
    Error 
    [@@deriving sexp_of, compare, enumerate]
end

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
    rx_byte : 'a [@bits 8];
    rx_valid : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    byte  : 'a [@bits 8];
    valid : 'a;
    sof   : 'a;
    eof   : 'a;
    err   : 'a;
    state : 'a [@bits 4];  (* debug: 1=Idle 2=Preamble 3=Data 4=Error *)
    (* astate_bruh_state : 'a [@bits 4];  (* debug: 1=Idle 2=Preamble 3=Data 4=Error *) *)
    (* astate_bruh_state2 : 'a [@bits 4];  (* debug: 1=Idle 2=Preamble 3=Data 4=Error *) *)
  } [@@deriving hardcaml]
end

let create
  (inputs: Signal.t I.t)
  :
  (Signal.t O.t)
  =
    let spec : Reg_spec.t = Reg_spec.create ~clock:inputs.I.clk ~clear:inputs.rst () in
    let state_machine = Always.State_machine.create (module States) spec ~enable:Signal.vdd in

    (* standard intermediaries for output pins *)
    let out_valid : Always.Variable.t = Always.Variable.wire ~default:Signal.gnd in
    let out_sof   = Always.Variable.wire ~default:Signal.gnd in
    let out_eof   = Always.Variable.wire ~default:Signal.gnd in
    let out_err   = Always.Variable.wire ~default:Signal.gnd in

    let test_out = Always.Variable.wire ~default:Signal.gnd in

    (* const compares for the preamble and start-frame-delimiter *)
    let const_preamble = Signal.of_int ~width:8 0x55 in
    let const_sfd = Signal.of_int ~width:8 0xD5 in

    (* funky binding powers affect the ability to invert this *)
    let not_valid = Signal.( ~: ) inputs.rx_valid in

    (* for strobing the sof at the beginning *)
    let sof_pending = Always.Variable.reg ~enable:Signal.vdd ~width:1 spec in

    (* main always logic *)
    Always.(compile [
      test_out<--Signal.vdd;

      state_machine.switch [

        (* this naively assumes that there are no transmission errors during the preamble; though I suppose that it'd be fine to for a dropped preamble bit to exist *)
        States.Idle, [
          when_ inputs.rx_valid [
            (* if byte == preamble, goto preamble*)
            (* else if byte == sfd, goto data*)
            (**)
            if_ Signal.(inputs.rx_byte ==: const_preamble)
              [state_machine.set_next States.Preamble]
              [ if_ Signal.(inputs.rx_byte ==: const_sfd)
                [ state_machine.set_next States.Data;
                  sof_pending <-- Signal.vdd; ]
                [state_machine.set_next States.Error;
                  out_err <-- Signal.vdd ]
              ]
          ]
        ];

        States.Preamble, [
          when_ inputs.rx_valid [
            if_ Signal.(inputs.rx_byte ==: const_preamble)
              (* [state_machine.set_next States.Preamble] (* if preamble, stay in preamble sense*) *)
              []
              [ if_ Signal.(inputs.rx_byte ==: const_sfd) (* if not, check if sfd sequence*)
                [ state_machine.set_next States.Data; 
                  sof_pending <-- Signal.vdd; ] (* if sfd move into payload *)
                [ state_machine.set_next States.Error;
                  out_err <-- Signal.vdd; ] (* else err *)
              ]
          ];

          (* valid drops during preamble sync *)
          when_ not_valid [
            state_machine.set_next States.Error;
            out_err <-- Signal.vdd;
          ]
        ];

        States.Data, [
          when_ inputs.rx_valid [
            out_valid <-- Signal.vdd;

            when_ (Variable.value sof_pending) [
              out_sof <-- Signal.vdd;
              sof_pending <-- Signal.gnd;
              (* is there a better way to do "strobing" effects? *)
            ]
          ];

          (* valid drops mid-data stream *)
          when_ not_valid [
            state_machine.set_next States.Idle;
            out_eof <-- Signal.vdd; (* currently we always hit the error state at the very end of the transmission, perhaps a way to recognize the not_valid as the end of the frame somehow is better for eof detection? *)
          ]
        ];

        States.Error, [
          out_err <-- Signal.vdd;
          when_ not_valid [
            state_machine.set_next States.Idle;
          ];
        ];

      ];
    ]);

    {
      O.
      byte  = inputs.rx_byte;
      valid = Always.Variable.value out_valid;
      sof   = Always.Variable.value out_sof;
      eof   = Always.Variable.value out_eof;
      err   = Always.Variable.value out_err;
      (* state = Signal.uresize state_machine.current 4; *)
      (* astate_bruh_state = Always.Variable.value test_out; *)
      (* astate_bruh_state2 = Signal.uresize state_machine.current 4; *)
      state = Signal.uresize state_machine.current 4;
      (* state = Signal.vdd; *)
    }

let () =
  print_endline "rx frame parser lib opened"
