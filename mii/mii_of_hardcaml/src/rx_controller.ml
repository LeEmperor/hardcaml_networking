open! Core
open! Hardcaml
open! Signal
open! Always

let () =
  Stdio.print_endline "=== Imported rx_controller ==="

module I = struct
  type 'a t = {

    (* spec *)
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* control lines  *)
    rx_dv : 'a;
    rx_er : 'a;
    
    (* data line -> rxd presents Preamble/SFD *)
    rx_data : 'a [@bits 4];
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    d_out : 'a;
    byte_assembler_en : 'a;
  } [@@deriving hardcaml]
end

module States = struct
  type t =
    | IDLE
    | PREAMBLE
    | DST_MAC
    | SRC_MAC
    | ETH_TYPE
    | PAYLOAD
    | DONE 
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create 
  (inputs) : (Signal.t O.t)
  =
  let open Variable in

  (*
    Spec: specific rising_edge spec
   *)
  let rising_edge : Reg_spec.t = 
    Reg_spec.create ~clock:inputs.I.clk ~clear:inputs.I.rst ()
  in

  (* negates *)
  let not_rx_dv = (~: (inputs.I.rx_dv) ) in
  let not_rx_er = (~: (inputs.I.rx_er) ) in

  (* internal aliases *)
  let rx_er     = inputs.I.rx_er in
  let rx_dv     = inputs.I.rx_dv in
  let in_data   = inputs.I.rx_data in
  let stable    = ( not_rx_dv |: rx_er ) in

  (* const params *)
  let const_0xD5 = of_int_trunc ~width:8 0xD5 in
  let const_0x55 = of_int_trunc ~width:8 0x55 in

  (* internal regs *)
  let mac_byte_count = reg ~enable:vdd ~width:3 rising_edge in

  let sm = 
    (* let not_rx_dv = Signal.(~:) inputs.I.rx_dv in *)
    State_machine.create (module States) ~enable:vdd rising_edge in

    Always.(compile [
      sm.switch [
        IDLE, [
          if_ (stable) [
            sm.set_next PREAMBLE;
          ] [
            sm.set_next IDLE;
          ]
        ];
        
        PREAMBLE, [
          if_ (stable) [
            Always.switch in_data [
              const_0x55, [sm.set_next PREAMBLE];
              const_0xD5, [sm.set_next DST_MAC];
            ]
          ] [
            sm.set_next IDLE;
          ]
        ];

        DST_MAC, [
          if_ (stable) [
            if_ (mac_byte_count.value ==: of_int_trunc ~width:3 5) [
              mac_byte_count <-- of_int_trunc ~width:3 0;
              sm.set_next SRC_MAC;
            ] [
              mac_byte_count <-- mac_byte_count.value +:. 1;
              sm.set_next DST_MAC;
            ];
          ] [
            sm.set_next IDLE;
          ]
        ];

        SRC_MAC, [
          if_ (stable) [
            if_ (mac_byte_count.value ==: of_int_trunc ~width:3 5) [
              mac_byte_count <-- of_int_trunc ~width:3 0;
              sm.set_next ETH_TYPE;
            ] [
              (* mac_byte_count <-- mac_byte_count.value +: (of_int_trunc ~width:3 1); *)
              mac_byte_count <-- mac_byte_count.value +:. 1;
              sm.set_next SRC_MAC;
            ];
          ] [
            sm.set_next IDLE;
          ]
        ];

        ETH_TYPE, [
          if_ (stable) [
            if_ (mac_byte_count.value ==: of_int_trunc ~width:3 1) [
              mac_byte_count <-- of_int_trunc ~width:3 0;
              sm.set_next PAYLOAD;
            ] [
              mac_byte_count <-- mac_byte_count.value +:. 1;
              sm.set_next ETH_TYPE;
            ];
          ] [
            sm.set_next IDLE;
          ];
        ];

        PAYLOAD, [
          (* priority handle err and datavalid separately *)
          if_ (rx_er) [
            sm.set_next IDLE;
          ] [
            if_ (rx_dv) [
              (* keep taking payload *)
              sm.set_next PAYLOAD;
            ] [
              (* payload finishsed *)
              sm.set_next DONE;
            ];
          ];
        ];
      ]
    ]);

  {
    d_out = zero 1;
    byte_assembler_en = zero 1;
  }

