open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Uart_of_hardcaml
open! Signal

module Circ = Circuit.With_interface (Mac_top.I) (Mac_top.O)
(* module Circ = Circuit.With_interface (Tx_byte_disassembler.I) (Tx_byte_disassembler.O) *)
(* module Circ = Circuit.With_interface (Tx_byte_disassembler.I) (Tx_byte_disassembler.O) *)
(* module Circ = Circuit.With_interface (Uart_tx.I) (Uart_tx.O) *)

let () =
  Stdio.print_endline "============ Begin Generation Phase =============== ";

  let scope = Scope.create ~flatten_design:false () in
  (* let circ = Circ.create_exn ~name:"mac_top" (Mac_top.create scope) in *)
  (* let circ = Circ.create_exn ~name:"uart_tx" (Uart_tx.create scope) in *)
  (* let circ = Circ.create_exn ~name:"eth_mac_rx" (Mac_top.create scope) in *)
  (* let circ = Circ.create_exn ~name:"tx_byte_disassembler" (Tx_byte_disassembler.create scope) in *)
  let circ = Circ.create_exn ~name:"eth_mac_tx" (Mac_top.create scope) in
  let hier = Rtl.create Verilog [circ] in
  let rtl  = Rtl.full_hierarchy hier in
  (* Out_channel.write_all "mac_top.v" ~data:(Rope.to_string rtl) *)
  (* Out_channel.write_all "eth_mac_rx.v" ~data:(Rope.to_string rtl) *)
  (* Out_channel.write_all "tx_byte_disassembler.v" ~data:(Rope.to_string rtl) *)
  Out_channel.write_all "eth_mac_tx.v" ~data:(Rope.to_string rtl)

