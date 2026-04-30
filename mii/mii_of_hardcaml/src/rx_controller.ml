open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

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
    byte_assembler_en : 'a;
    payload_sel : 'a;
    dst_mac_reg_en : 'a;
    src_mac_reg_en : 'a;

    (* debug lines *)
    debug_state_vec   : 'a [@bits 3];
    debug_stable          : 'a;
    debug_byte_valid      : 'a;
    debug_en              : 'a;
    debug_d_in            : 'a [@bits 8];
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
  let payload_sel   = reg ~enable:vdd ~width:1 rising_edge in

  (* const params *)
  let const_0xD5 = of_int_trunc ~width:8 0xD5 in
  let const_0x55 = of_int_trunc ~width:8 0x55 in

  (* internal regs *)
  let mac_byte_count = reg ~enable:vdd ~width:3 rising_edge in
  let dst_mac_reg_en = reg ~enable:vdd ~width:1 rising_edge in
  let src_mac_reg_en = reg ~enable:vdd ~width:1 rising_edge in

  (* let debug_block = *)
  (*   {} *)
  (* in *)

  let sm = 
    State_machine.create (module States) ~enable:vdd rising_edge in

    compile [
      (* default value *)
      payload_sel <--. 0;
      dst_mac_reg_en <--. 0;
      src_mac_reg_en <--. 0;

      (* moore-ish? *)
      sm.switch ~default:[] [
        DST_MAC, [
          dst_mac_reg_en <--. 1;
        ];
        SRC_MAC, [
          src_mac_reg_en <--. 1;
        ];
      ];

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
            if_ (rx_dv) [
              (* keep taking payload *)
              sm.set_next PAYLOAD;
              payload_sel <--. 1;
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

    (* (* moore assignments *) *)
    (* compile [ *)
    (*   (* defaults *) *)
    (* ]; *)

  {
    byte_assembler_en     = inputs.I.en; (* byte assembler is how we branch, therefore it should be on when we are also on, with WE = controller*)
    (* payload_sel        = reg_payload_sel.value; *)
    payload_sel           = payload_sel.value;
    dst_mac_reg_en        = dst_mac_reg_en.value;
    src_mac_reg_en        = src_mac_reg_en.value;

    debug_state_vec       = sm.current;
    debug_stable          = stable;
    debug_byte_valid      = valid;
    debug_en              = en;
    debug_d_in            = in_data;
  }

