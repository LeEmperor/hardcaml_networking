(*
  Bohdan Purtell
  University of Florida

  Module: Tx_byte_disassembler 
  This module serves as the nibble-serializer for my Hardcaml Ethernet MAC
*)

open! Core
open! Hardcaml
open! Signal
open! Helper_circuits

let () =
  Stdio.print_endline "=== Imported MAC TX Nibble Serializer ==="

module I = struct
  type 'a t = {
    (* spec *)
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* data lignes *)
    byte_in : 'a [@bits 8];
    byte_in_valid : 'a;

  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    ready : 'a;
    tx_d  : 'a [@bits 4];
    tx_en : 'a;

    (* debug lines *)
    keep : 'a;
  } [@@deriving hardcaml]
end

(* internal regs mod *)
module I_Regs = struct
  type 'a t = {
    bottom_nibble : 'a [@bits 4];
    upper_nibble  : 'a [@bits 4];
    byte_reg      : 'a [@bits 8];
  } [@@deriving hardcaml]
end

let create 
  (scope : Scope.t )
  (i) : _ O.t
  = 
  (* scope shenanigans *) 
  let _scope : Scope.t = Scope.sub_scope scope "rx_datapath_scope" in

  (* port aliases *)   
  let clk = i.I.clk in
  let rst = i.I.rst in
  let en  = i.I.en in
  let rising_edge = Reg_spec.create ~clock:clk ~clear:rst () in
  
  (* tagging + register creation *)
  let regs = I_Regs.Of_always.reg ~enable:vdd rising_edge in
  I_Regs.Of_always.apply_names ~prefix:"tx_" ~naming_op:(Scope.naming scope) regs;

  {
    s_axis_tready = Signal.zero 1;
    keep = Signal.zero 1;
  }
;;

