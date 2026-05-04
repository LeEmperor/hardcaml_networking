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

  (* this sends in little-endian (computer order?) *)
  (* for example 0x12_34 becomes 34 then 12, with an SRL getting 0x3412 across 2 cycles *)
  let send_byte byte =
    let hi = (byte lsr 4) land 0xF in
    let lo = byte land 0xF in
    send hi lo;

    printf "\n==Byte sent: == %X ==\n" byte;
    (* slice the byte in half, how do we do more advanced math with a hex value? *)
  in

  (* let send_bytes (name: string) (bytes: int) (n_bytes: int) =  *)
  let send_bytes name n_bytes bytes = 
    printf "\nsending %s: %d bytes : %X" name n_bytes bytes;
    for i = 0 to (n_bytes - 1) do
      let send_target = (bytes lsr (8 * i)) land 0xFF in
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
  send_byte 0xD5;

  send_bytes "dst_mac"  6  0x71_72_73_74_75_76;
  send_bytes "src_mac"  6  0x66_65_64_63_62_61;
  send_bytes "eth type" 2  0x67_65;

  (* for i = 0 to 20 do *)
  (*   send_bytes "payload burst" 4 i; *)
  (* done; *)

  send_bytes "payload burst 1" 3 0x12_43_56;
  send_bytes "payload burst 2" 2 0x78_90;
  send_bytes "payload burst 3" 4 0xDE_AD_BE_EF;

  t_in <-- 0;

  cycle();
  cycle();
  cycle();
  cycle();

  cycle();
  cycle();
  cycle();

  (* declare data in-valid from PHY line *)
  t_rx_dv <-- 1;

  (* tail cycle *)
  for i = 0 to 10 do
    cycle();
  done;
  idle();

  print_endline "\n=== SIMULATION COMPLETE ===";
  )
;;
