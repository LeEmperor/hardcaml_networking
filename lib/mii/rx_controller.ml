(* 
  Bohdan Purtell
  University of Florida

  Module: Rx_controller
  This module serves as an FSM controller for the receive path of my Hardcaml 
  ethernet MAC.
*)

open Core
open Hardcaml
open Signal
open Always
open Variable
open Helper_circuits

let () =
  Stdio.print_endline "=== Imported MAC RX Controller ==="

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
    (* submodule ens *)
    byte_assembler_en : 'a;

    (* reg ens *)
    dst_mac_reg_en    : 'a;
    src_mac_reg_en    : 'a;
    eth_type_reg_en   : 'a;

    (* sels *)
    payload_sel : 'a;

    (* misc *)
    emit_payload  : 'a;
    fcs_present   : 'a;

    (* debug lines *)
    keep : 'a;
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
  (scope : Scope.t)
  (inputs) : (_ O.t)
  =
  let open Always in
  let open Variable in

  let rising_edge : Reg_spec.t = 
    Reg_spec.create ~clock:inputs.I.clk ~clear:inputs.I.rst ()
  in

  (* state machine *)
  let sm = State_machine.create (module States) ~enable:vdd rising_edge in

  (* negates *)
  let not_rx_dv = (~: (inputs.I.rx_dv) ) in
  let not_rx_er = (~: (inputs.I.rx_er) ) in

  (* internal aliases *)
  let rx_er         = inputs.I.rx_er in
  let rx_dv         = inputs.I.rx_dv in
  let in_data       = inputs.I.rx_data in
  let en            = inputs.I.en in
  let valid         = inputs.I.rx_data_valid in
  let stable        = ( (not_rx_dv |: rx_er) &: en) in

  (* this would like to be a wire instead? essentially a mux *)
  (* let reg_payload_sel   = reg ~enable:vdd ~width:1 rising_edge in *)
  (* let payload_sel   = reg ~enable:vdd ~width:1 rising_edge in *)
  let payload_sel   = Always.Variable.wire ~default:gnd () in

  (* const params *)
  let const_0xD5 = of_int_trunc ~width:8 0xD5 in
  let const_0x55 = of_int_trunc ~width:8 0x55 in

  (* internal regs *)
  let mac_byte_count    = reg ~enable:vdd ~width:3 rising_edge in
  let dst_mac_reg_en    = reg ~enable:vdd ~width:1 rising_edge in
  let src_mac_reg_en    = reg ~enable:vdd ~width:1 rising_edge in
  let eth_type_reg_en   = reg ~enable:vdd ~width:1 rising_edge in
  (* let payload_out_valid = reg ~enable:vdd ~width:1 rising_edge in *)
  let payload_out_valid = Always.Variable.wire ~default:(Signal.zero 1) () in

  let dbg_mac_byte_count = mac_byte_count.value -- "dbg_mac_byte_count" in
  let dbg_dst_mac_reg_en = dst_mac_reg_en.value -- "dbg_dst_mac_reg_en" in
  let dbg_src_mac_reg_en = src_mac_reg_en.value -- "dbg_dst_src_reg_en" in
  let state_vec = Always.Variable.wire ~default:(Signal.zero 3) () in
  let dbg_state_vec = state_vec.value -- "state_vec" in
  let dbg_emit_payload = payload_out_valid.value -- "dbg_emit_payload_controller" in

  (* highkey lost what this does *)
  let bruh3 = (Always.Variable.wire ~default:(Signal.zero 3) ()).value in

  (* rising edge detect on dv for the crc_valid strobe line *)
  let fcs_present = (rising_edge_delayed rising_edge ~n_cycles:1 inputs.I.rx_dv) -- "dbg_fcs_present" in

  (* i swear this can be automated *)
  let keep = reduce ~f:(|:) (
    (bits_lsb dbg_mac_byte_count) @ 
    (bits_lsb dbg_dst_mac_reg_en) @
    (bits_lsb dbg_src_mac_reg_en) @
    (bits_lsb dbg_state_vec) @
    (bits_lsb dbg_emit_payload) @
    (bits_lsb fcs_present)
  ) in

  (* let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in *)

  compile [
    (* default values *)
    payload_sel     <--. 0;
    dst_mac_reg_en  <--. 0;
    src_mac_reg_en  <--. 0;
    eth_type_reg_en <--. 0;
    payload_out_valid <--. 0;
    payload_sel <--. 0;

    state_vec <-- sm.current;

    (* moore assigments *)
    sm.switch ~default:[] [
      DST_MAC, [
        dst_mac_reg_en <--. 1;
      ];
      SRC_MAC, [
        src_mac_reg_en <--. 1;
      ];
      ETH_TYPE, [
        eth_type_reg_en <--. 1;
      ];
      PAYLOAD, [
        payload_sel <--. 1;
        payload_out_valid <--. 1;
      ];
    ];

    (* next state logic *)
    when_ (valid) [
      sm.switch ~default:[sm.set_next IDLE] [

      IDLE, [
        if_ (stable) [sm.set_next PREAMBLE] [sm.set_next IDLE]
      ];
      
      PREAMBLE, [
        if_ (stable) [
          Always.switch in_data [
            const_0x55, [sm.set_next PREAMBLE];
            const_0xD5, [
              sm.set_next DST_MAC; 
            ];
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
            (* very odd timing issue that requires the register enable to be high one longer cycle *)
            (* might be more easily remediable with a moore approach, but why doesnt the mealy work? *)
            (* my thought is that the byte valid is a moore based assignment from the byte assembler, therefore *)
            (* my assignments following have to be in the moore domain *)
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
          if_ (not_rx_dv) [
            (* keep taking payload *)
            sm.set_next PAYLOAD;
          ] [
            (* payload finishsed *)
            sm.set_next PREAMBLE;
          ];
        ];
      ];

      DONE, [sm.set_next DONE];
    ] (* sm.switch[] *)
  ]   (* when_ (valid)[] *)
  ];  (* compile[] *)

  {
    byte_assembler_en     = inputs.I.en; 

    (* byte assembler is how we branch, therefore it should be on when we are also on, with WE = controller*)
    dst_mac_reg_en        = dst_mac_reg_en.value;
    src_mac_reg_en        = src_mac_reg_en.value;
    eth_type_reg_en       = eth_type_reg_en.value;

    payload_sel           = payload_sel.value;
    emit_payload          = payload_out_valid.value;
    fcs_present           = fcs_present;

    keep = keep;
  }
;;
