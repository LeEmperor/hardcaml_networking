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

    (* control lignes *)
    byte_mux_sel : 'a [@bits 3];
    mac_byte_sel : 'a [@bits 3];

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

module I_Wires = struct
  type 'a t = {
    payload_byte : 'a [@bits 8];
    fcs_byte : 'a [@bits 8];
    dst_mac_byte : 'a [@bits 8];
    src_mac_byte : 'a [@bits 8];
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
  let en  = i.I.en -- "en" in (* does this need to be tagged manually or nah? *)
  let byte_mux_sel = i.I.byte_mux_sel in
  let mac_byte_sel = i.I.mac_byte_sel in (* do i need this aliases? *)
  let rising_edge = Reg_spec.create ~clock:clk ~clear:rst () in

  (* const *)
  (* could I make a reusable function for the mapping? *)
  (* aka byte_const_map that calls map for a specified width and returns the Signal.t list *)
  let dst_mac_addr = List.map ~f:(of_int_trunc ~width:8) 
    [0x12; 0x34; 0x56; 0x78; 0x90;] 
  in

  let src_mac_addr = List.map ~f:(of_int_trunc ~width:8) 
    [0x90; 0x78; 0x56; 0x34; 0x12;] 
  in
  
  (* tagging + register creation *)
  let regs = I_Regs.Of_always.reg ~enable:vdd rising_edge in
  I_Regs.Of_always.apply_names ~prefix:"tx_" ~naming_op:(Scope.naming scope) regs;

  (* tagging + wire creation *)
  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;

  (* dst mac mux6 *)
  let dst_mac_mux = mux mac_byte_sel dst_mac_addr in

  (* src mac mux6 *)
  let src_mac_mux = mux mac_byte_sel src_mac_addr in

  (* mux6 *)
  let byte_mux = mux byte_mux_sel [
    i_wires.payload_byte.value;(* fastest to check for all 0s, crit path nicer? *)
    i_wires.fcs_byte.value;
    (* i_wires.dst_mac_byte.value; *)
    (* i_wires.src_mac_byte.value; *)
    dst_mac_mux;
    src_mac_mux;
    of_int_trunc ~width:8 0x55;
    of_int_trunc ~width:8 0xD5;
  ] -- "mtag_byte_mux" in 

  {
    s_axis_tready = Signal.zero 1;
    keep = Signal.zero 1;
  }
;;

