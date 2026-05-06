open! Core
open! Hardcaml
open! Uart_of_hardcaml
open! Hardcaml_waveterm

let () = 
  print_endline "=== Running UART TX Top Testbench ==="
;;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Uart_top.I)(Uart_top.O)

let create_sim ()=
  let top_tb_scope : Scope.t = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim = Sim.create ~config:Cyclesim.Config.trace_all (Uart_top.create top_tb_scope) in
  let waves, sim              = Waveform.create sim in
  let inputs  : _ Uart_top.I.t = Cyclesim.inputs sim in
  let outputs : _ Uart_top.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)
;;

let () =
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in
  Out_channel.with_file "waves_uart_top.vcd" ~f:(fun oc->
    let 
  );;


