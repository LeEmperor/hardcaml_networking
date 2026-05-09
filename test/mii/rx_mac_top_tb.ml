open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm
open! Helper_tb_functions

let () =
  print_endline "=== Running  MAC RX Top Testbench ===";;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Mac_top.I)(Mac_top.O)
(* we hand Sim's namespace a create function and it does the heavy lifting because the shapes were known from the earlier functor call *)

let create_sim () 
  =
  let top_tb_scope : Scope.t = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim = Sim.create ~config:Cyclesim.Config.trace_all (Mac_top.create top_tb_scope) in
  let waves, sim              = Waveform.create sim in
  let inputs  : _ Mac_top.I.t = Cyclesim.inputs sim in
  let outputs : _ Mac_top.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)

let () = 
  (* sim instance *)
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in

  (* vcd wrapper *)
  Out_channel.with_file "waves_top.vcd" ~f:(fun oc->
  let sim = Vcd.wrap oc sim in

  (* signal aliases *)
  let t_clk   = inputs.clock in
  let t_rst   = inputs.reset in
  let t_en    = inputs.en in

  let t_in    = inputs.rx_data in
  let t_rx_dv = inputs.rx_dv in
  let t_rx_er = inputs.rx_er in
  let t_tready = inputs.m_axis_tready in

  let t_out   = outputs.m_axis_tdata in
  let t_keep  = outputs.m_axis_tkeep in
  let t_last  = outputs.m_axis_tlast in
  let t_valid = outputs.m_axis_tvalid in
  let t_user  = outputs.m_axis_tuser in

  (* display helper *)
  let cycle () =
    Cyclesim.cycle sim;
  in

  (* helpers *)
  let reset () =
    t_tready <-- 0;
    t_en  <-- 0;
    t_rst <-- 1;
    cycle ();
    t_en <-- 1;
    t_rst <-- 0;
  in

  let idle () =
    t_en <-- 0;
    cycle ();
  in

  (* -- test 1: basic frame -- *)
  printf "\n-- [test 1] basic frame --";
  reset ();
  t_rx_dv <-- 0;
  t_tready <-- 1;

  send_frame ~cycle ~t_in
      "=== test frame 1 ==="
      ~dst_mac:0x36_12_73_36_24_85
      ~src_mac:0x37_52_33_76_94_05
      ~eth_type:0x45_21
      ~payload_length:5
      ~payload:0x12_34_56_78_90;

  send_bytes ~cycle ~t_in "test CRC" 4 0xCA_FE_BA_BE;

  (* declare data in-valid from PHY line *)
  t_rx_dv <-- 1;

  (* drain: run for a few cycles and print any bytes that emerge *)
  printf "\n-- rx bytes --";
  for _ = 0 to 15 do
    cycle ();
    if Bits.to_bool !(outputs.m_axis_tvalid)
    then printf "\n  %02X" (Bits.to_int_trunc !(outputs.m_axis_tdata))
  done;

  idle ();

  print_endline "\n=== SIMULATION COMPLETE ===";
  )
;;
