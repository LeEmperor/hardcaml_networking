open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm

let () =
  print_endline "=== Running MAC RX Top Testbench ===";;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Mac_top.I)(Mac_top.O)
(* we hand Sim's namespace a create function and it does the heavy lifting because the shapes were known from the earlier functor call *)

let create_sim () 
  =
  let sim                               = Sim.create Mac_top.create in
  let waves, sim                        = Waveform.create sim in
  let inputs  : _ Mac_top.I.t = Cyclesim.inputs sim in
  let outputs : _ Mac_top.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)

let () = 
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in

  (* display helper *)
  (* let cycle () = *)
  (*   Cyclesim.cycle sim; *)
  (* in *)
 let cycle () =
    Cyclesim.cycle sim;
    printf "rx_data=%x rx_dv=%d rx_er=%d rx_en=%d\n"
      (Bits.to_int_trunc !(inputs.rx_data))
      (Bits.to_int_trunc !(inputs.rx_dv))
      (Bits.to_int_trunc !(inputs.rx_er))
      (Bits.to_int_trunc !(inputs.rx_master_enable))
  in
  
  (* assign helper *)
  let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in

  (* signal aliases *)
  let t_rst   = inputs.rst in
  let t_en    = inputs.rx_master_enable in
  let t_in    = inputs.rx_data in

  let t_out  =  outputs.m_axis_tdata in
  let t_keep =  outputs.m_axis_tkeep in

  let t_last =  outputs.m_axis_tlast in
  let t_valid =  outputs.m_axis_tvalid in
  let t_user = outputs.m_axis_tuser in

  let reset () =
    t_en  <-- 0;
    t_rst <-- 1;
    cycle ();
    t_rst <-- 0;
  in

  let send lo hi =
    t_en <-- 1;
    t_in <-- lo;
    cycle ();
    t_in <-- hi;
    cycle ();
  in

  let send_byte byte =
    let hi = (byte lsr 4) land 0xF in
    let lo = byte land 0xF in
    send hi lo;

    printf "\n==Byte sent: == %d ==\n" byte;
    (* slice the byte in half, how do we do more advanced math with a hex value? *)
  in

  let idle () =
    t_en <-- 0;
    cycle ();
  in

  (* -- test 1: basic pair 0xA, 0xB -> expect 0xAB -- *)
  printf "\n[test 1] 0x55";
  reset ();
  send_byte 0x55;
  send_byte 0x55;
  send_byte 0x55;
  send_byte 0x55;
  idle ();

  cycle();
  cycle();
  cycle();

  (* (* -- test 2: back-to-back bytes without idle -- *) *)
  (* printf "\n[test 2] back-to-back: 0xC,0xD then 0xE,0xF -> expect 0xCD then 0xEF\n"; *)
  (* reset (); *)
  (* send 0xC 0xD; *)
  (* send 0xE 0xF; *)
  (* idle (); *)
  (**)
  (* (* -- test 3: en drops mid-byte, then resumes -- *) *)
  (* printf "\n[test 3] upper nibble 0x3, en drops, then 0x4,0x5 -> expect 0x45\n"; *)
  (* reset (); *)
  (* t_en <-- 1; *)
  (* t_in <-- 0x3; *)
  (* cycle ();          (* upper=0x3, have_upper=1 *) *)
  (* idle ();           (* en drops — have_upper stays 1 *) *)
  (* send 0x4 0x5;      (* resumes: 0x4 taken as upper, 0x5 as lower -> 0x45 *) *)
  (* idle (); *)

  (* Waveform.print ~display_width:80 waves; *)

  print_endline "hi";
  Waveform.print
    ~display_width:130
    ~display_height:20
    ~display_values:true
    ~display_rules:[
      Display_rule.port_name_is "rx_data"          ~wave_format:Hex;
      Display_rule.port_name_is "rx_master_enable" ~wave_format:Bit;
      Display_rule.port_name_is "rx_dv"            ~wave_format:Bit;
      Display_rule.port_name_is "rx_er"            ~wave_format:Bit;
      Display_rule.default;
    ]
    waves;

  print_endline "\n=== SIMULATION COMPLETE ===";
;;
