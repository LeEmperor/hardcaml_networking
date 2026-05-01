open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm

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

  let t_out   = outputs.m_axis_tdata in
  let t_keep  = outputs.m_axis_tkeep in
  let t_last  = outputs.m_axis_tlast in
  let t_valid = outputs.m_axis_tvalid in
  let t_user  = outputs.m_axis_tuser in

  (* display helper *)
  let cycle () =
    Cyclesim.cycle sim;
  in

  (* assign helper *)
  let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in

  (* helpers *)
  let reset () =
    t_en  <-- 0;
    t_rst <-- 1;
    cycle ();
    t_en <-- 1;
    t_rst <-- 0;
  in

  let send hi lo =
    t_in <-- hi;
    cycle ();
    t_in <-- lo;
    cycle ();
  in

  let send_byte byte =
    let hi = (byte lsr 4) land 0xF in
    let lo = byte land 0xF in
    send hi lo;

    printf "\n==Byte sent: == %d ==\n" byte;
    (* slice the byte in half, how do we do more advanced math with a hex value? *)
  in

  let send_dst_mac_addr mac_addr = 
    printf "\ndst_mac_addr: %X" mac_addr;
    for i = 0 to 5 do
      (* printf "\ndst_mac_addr left shift %d bytes: %X" (i) (dst_mac_addr lsr (8 * i)); *)
      let send_target = (mac_addr lsr (8 * i)) land 0xFF in
      send_byte send_target;
      printf "sending portion: %X" send_target;
    done;
  in

  let send_src_mac_addr mac_addr = 
    printf "\nsrc_mac_addr: %X" mac_addr;
    for i = 0 to 5 do
      (* printf "\ndst_mac_addr left shift %d bytes: %X" (i) (dst_mac_addr lsr (8 * i)); *)
      let send_target = (mac_addr lsr (8 * i)) land 0xFF in
      send_byte send_target;
      printf "sending portion: %X" send_target;
    done;
  in

  let idle () =
    t_en <-- 0;
    cycle ();
  in

  (* -- test 1: 0x55 for a while -> expect state=PREAMBLE -- *)
  printf "\n[test 1] 0x55";
  reset ();
  t_rx_dv <-- 0;

  (* sit preamble *)
  for i = 0 to 5 do
    send_byte 0x55;
  done;

  (* SFD *)
  (* cycle(); *)
  (* cycle(); *)
  send_byte 0xD5;

  send_dst_mac_addr 0x71_72_73_74_75_76;
  send_src_mac_addr 0x66_65_64_63_62_61;
  cycle();
  cycle();

  t_rx_dv <-- 1;

  (* tail cycle *)
  for i = 0 to 10 do
    cycle();
  done;
  idle();

  print_endline "\n=== SIMULATION COMPLETE ===";
  )
;;
