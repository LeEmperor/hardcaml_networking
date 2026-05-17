(*
  Bohdan Purtell
  University of Florida

  Module: Tx_controller
  This module serves as an FSM controller for the transmit path of my Hardcaml
  ethernet MAC.
*)

open! Core
open! Hardcaml
open! Signal
open! Helper_circuits
open! Common_types

let () =
  Stdio.print_endline "=== Imported MAC TX Controller ==="
;;

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
    en  : 'a;

    start      : 'a;
    fifo_empty : 'a;
    dis_ready  : 'a;  (* tx_byte_disassembler.ready — 1 when it can accept a new byte *)
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    byte_mux_sel : 'a [@bits 3];
    mac_byte_sel : 'a [@bits 3];
    crc_en       : 'a;
    state        : 'a [@bits 3];
  } [@@deriving hardcaml]
end

module I_Regs = struct
  type 'a t = {
    byte_counter : 'a [@bits 11];
    busy         : 'a;
    in_preamble  : 'a;
    in_sfd       : 'a;
    in_payload   : 'a;
    in_fcs       : 'a;
  } [@@deriving hardcaml]
end

module I_Wires = struct
  type 'a t = {
    byte_disassembler_en : 'a;
    crc_en               : 'a;
  } [@@deriving hardcaml]
end

let create
  (scope : Scope.t)
  (i) : (_ O.t)
  =
  let open Always in
  let open Variable in

  let _scope : Scope.t = Scope.sub_scope scope "tx_controller_scope" in

  let clk        = i.I.clk in
  let rst        = i.I.rst in
  let _en        = i.I.en in
  let start      = i.I.start in
  let fifo_empty = i.I.fifo_empty -- "fifo_empty" in
  let dis_ready  = i.I.dis_ready  -- "dis_ready"  in

  let rising_edge : Reg_spec.t =
    Reg_spec.create ~clock:clk ~clear:rst ()
  in

  let sm = State_machine.create (module States) ~enable:vdd rising_edge in

  let i_regs = I_Regs.Of_always.reg ~enable:vdd rising_edge in
  I_Regs.Of_always.apply_names ~prefix:"reg_" ~naming_op:(Scope.naming scope) i_regs;

  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;

  let rst_counter    = i_regs.byte_counter <--. 0 in
  let increm_counter = i_regs.byte_counter <-- i_regs.byte_counter.value +:. 1 in

  compile [
    i_wires.crc_en <--. 0;
    i_regs.busy <-- i_regs.busy.value;

    sm.switch ~default:[] [
      Idle, [
        when_ (start) [
          when_ (~:fifo_empty) [
            i_regs.busy <--. 1;
            rst_counter;
            sm.set_next Preamble;
          ];
        ];
      ];

      Preamble, [ (* 7 bytes of 0x55 *)
        when_ (dis_ready) [
          if_ (i_regs.byte_counter.value ==:. 6) [
            rst_counter;
            sm.set_next Sfd;
          ] [
            increm_counter;
          ];
        ];
      ];

      Sfd, [ (* 1 byte: 0xD5 *)
        when_ (dis_ready) [
          sm.set_next Dst_mac;
        ];
      ];

      Dst_mac, [ (* 6 bytes *)
        when_ (dis_ready) [
          if_ (i_regs.byte_counter.value ==:. 5) [
            rst_counter;
            sm.set_next Src_mac;
          ] [
            increm_counter;
          ];
        ];
      ];

      Src_mac, [ (* 6 bytes *)
        when_ (dis_ready) [
          if_ (i_regs.byte_counter.value ==:. 5) [
            rst_counter;
            sm.set_next Eth_type;
          ] [
            increm_counter;
          ];
        ];
      ];

      Eth_type, [ (* 2 bytes *)
        when_ (dis_ready) [
          if_ (i_regs.byte_counter.value ==:. 1) [
            rst_counter;
            sm.set_next Payload;
          ] [
            increm_counter;
          ];
        ];
      ];

      (* by now: 7 + 6 + 6 + 2 = 21 bytes overhead *)
      (* minimum frame 64 - 4 (fcs) = 60; 60 - 21 = 39 payload bytes minimum *)
      Payload, [
        when_ (~:fifo_empty &: dis_ready) [
          if_ (i_regs.byte_counter.value ==:. 37) [
            rst_counter;
            i_wires.crc_en <--. 1;
            sm.set_next Fcs;
          ] [
            increm_counter;
          ];
        ];
      ];

      Fcs, [ (* 4 bytes *)
        when_ (dis_ready) [
          if_ (i_regs.byte_counter.value ==:. 3) [
            rst_counter;
            sm.set_next Idle;
          ] [
            i_wires.crc_en <--. 1;
            i_regs.busy <--. 0;
            increm_counter;
          ];
        ];
      ];
    ];
  ];

  {
    byte_mux_sel = sm.current;
    mac_byte_sel = select i_regs.byte_counter.value ~high:2 ~low:0;
    crc_en       = i_wires.crc_en.value;
    state        = sm.current;
  }
