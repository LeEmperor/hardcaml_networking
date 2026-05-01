(* 
  Bohdan Purtell
  University of Florida

  Module: Rx_controller_explicit 
  This module serves as a more explicit controller of the rx path, with the intention that the
  current_state and next_state values are both grabbable by debug, instead of running with the
  standard 1-state implementation paradigm of an FSM. 

  Why Hardcaml doesn't support this already is beyond me.
*)

open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC RX Controller (explicit state) ==="

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
    rx_data       : 'a [@bits 8];
    rx_data_valid : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    d_out : 'a;
    byte_assembler_en : 'a;

    (* debug lines *)
    state_map_vec : 'a [@bits 3];
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
  (inputs) : (_ O.t)
  =
  let open Always in
  let open Variable in

  let rising_edge : Reg_spec.t = 
    Reg_spec.create ~clock:inputs.I.clk ~clear:inputs.I.rst ()
  in

  (* state items *)
  let current_state = reg ~enable:vdd ~width:3 rising_edge in
  let next_state    = Variable.wire ~default:current_state.value in

  (* negates *)
  let not_rx_dv = (~: (inputs.I.rx_dv) ) in
  let not_rx_er = (~: (inputs.I.rx_er) ) in

  (* internal aliases *)
  let rx_er         = inputs.I.rx_er in
  let rx_dv         = inputs.I.rx_dv in
  let in_data       = inputs.I.rx_data in
  let en            = inputs.I.en in
  let valid = inputs.I.rx_data_valid in
  let stable        = ( not_rx_dv |: rx_er &: en) in

  (* const params *)
  let const_0xD5 = of_int_trunc ~width:8 0xD5 in
  let const_0x55 = of_int_trunc ~width:8 0x55 in

  (* internal regs *)
  let mac_byte_count = reg ~enable:vdd ~width:3 rising_edge in

  (* let debug_block = *)
  (*   {} *)
  (* in *)

  (* state machine encoder function *)
  let state_width : int = Int.ceil_log2 (List.length States.all) in
  let enc (s : States.t) = 
    List.findi_exn States.all ~f:(fun _ x -> States.compare x s = 0)
    |> fst
    |> Signal.of_int_trunc ~width:state_width
  in
  
  let sm : States.t State_machine.t = 
    State_machine.create (module States) ~enable:vdd rising_edge in

    Always.(compile [
      next_state () <-- current_state.value;

      when_ (valid) [
        switch current_state.value [
          enc IDLE, [
            if_ (stable) [] []
          ];
        ];

        sm.switch ~default:[sm.set_next IDLE] [

        IDLE, [
          if_ (stable) [sm.set_next PREAMBLE] [sm.set_next IDLE]
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

        (* DONE, [sm.set_next DONE]; *)
      ] (* sm.switch[] *)
    ] (* when_ (valid)[] *)
    ] (* Always.(compile[]) *)
    );

  {
    d_out               = zero 1;
    byte_assembler_en   = inputs.I.en; (* byte assembler is how we branch, therefore it should be on when we are also on, with WE = controller*)
    state_map_vec = sm.current;
  }

