(*
  Bohdan Purtell
  University of Florida

  Module: Tx_datapath
  This module serves as the datapath for my Hardcaml Ethernet MAC
*)

open! Core
open! Hardcaml
open! Signal
open! Helper_circuits

let () =
  Stdio.print_endline "=== Imported MAC TX Datapath ==="

module I = struct
  type 'a t = {
    (* spec *)
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* data lignes *)
    s_axis_tdata  : 'a [@bits 8];
    s_axis_tvalid : 'a;
    s_axis_tuser  : 'a;

  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* axis lines *)
    s_axis_tready : 'a;

    (* debug lines *)
    keep : 'a;
  } [@@deriving hardcaml]
end

(* internal regs mod *)
module I_Regs = struct
  type 'a t = {
    bottom_nibble : 'a [@bits 4];
    upper_nibble  : 'a [@bits 4];
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

