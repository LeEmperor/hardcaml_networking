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

let () = 
  Stdio.print_endline "=== Imported MAC TX Controller ==="
;;

module I = struct
  type 'a t = {
    (* spec *)
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* control lines *)

  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    keep : 'a;
  } [@@deriving hardcaml]
end

module States = struct
  type t = 
    | IDLE
    | WAIT_FRAME
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
  (i) : (_ O.t)
  =
  let open Always in
  let open Variable in

  (* port aliases *)
  let clk = i.I.clk in
  let rst = i.I.rst in
  let en  = i.I.en in

  let rising_edge : Reg_spec.t =
    Reg_spec.create ~clock:clk ~clear:rst ()
  in

  (* state machine *)
  let sm = State_machine.create (module States) ~enable:vdd rising_edge in

  (* internal regs *)
  let mac_byte_count    = Always.Variable.reg ~enable:vdd ~width:3 rising_edge in
  let dst_mac_reg_en    = reg ~enable:vdd ~width:1 rising_edge in
  let src_mac_reg_en    = reg ~enable:vdd ~width:1 rising_edge in
  let eth_type_reg_en   = reg ~enable:vdd ~width:1 rising_edge in

  (* const params *)
  let const_0xD5 = of_int_trunc ~width:8 0xD5 in
  let const_0x55 = of_int_trunc ~width:8 0x55 in

  compile [

  ];

  {
    keep = Signal.gnd;
  }

