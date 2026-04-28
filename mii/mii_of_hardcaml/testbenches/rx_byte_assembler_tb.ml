open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm

let () =
  print_endline "=== Running MAC RX Byte Assembler Testbench ===";;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Rx_byte_assembler.I)(Rx_byte_assembler.O)
(* we hand Sim's namespace a create function and it does the heavy lifting because the shapes were known from the earlier functor call *)

let create_sim () 
  =
  let sim = Sim.create Rx_byte_assembler.create in
  let waves, sim = Waveform.create sim in
  let inputs  : _ Rx_byte_assembler.I.t = Cyclesim.inputs sim in
  let outputs : _ Rx_byte_assembler.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)

let () = 
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in

  (* display helper *)
  let cycle () =
    Cyclesim.cycle sim;
    printf "byte_out = 0x%02x byte_valid=%d\n"
    (Bits.to_int_trunc !(outputs.byte_out))
    (Bits.to_int_trunc !(outputs.byte_valid))
  in
  
  (* assign helper *)
  let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in

  (* signal aliases *)
  let t_rst   = inputs.rst in
  let t_en    = inputs.en in
  let t_in    = inputs.rx_data in

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

  let idle () =
    t_en <-- 0;
    cycle ();
  in

  (* -- test 1: basic pair 0xA, 0xB -> expect 0xAB -- *)
  printf "\n[test 1] 0xA,0xB -> expect 0xAB\n";
  reset ();
  send 0xA 0xB;
  idle ();

  (* -- test 2: back-to-back bytes without idle -- *)
  printf "\n[test 2] back-to-back: 0xC,0xD then 0xE,0xF -> expect 0xCD then 0xEF\n";
  reset ();
  send 0xC 0xD;
  send 0xE 0xF;
  idle ();

  (* -- test 3: en drops mid-byte, then resumes -- *)
  printf "\n[test 3] upper nibble 0x3, en drops, then 0x4,0x5 -> expect 0x45\n";
  reset ();
  t_en <-- 1;
  t_in <-- 0x3;
  cycle ();          (* upper=0x3, have_upper=1 *)
  idle ();           (* en drops — have_upper stays 1 *)
  send 0x4 0x5;      (* resumes: 0x4 taken as upper, 0x5 as lower -> 0x45 *)
  idle ();

  (* -- test 4: boundary values -- *)
  printf "\n[test 4] 0xF,0xF -> expect 0xFF and 0x0,0x0 -> expect 0x00\n";
  reset ();
  send 0xF 0xF;
  send 0x0 0x0;
  idle ();

  Waveform.print ~display_width:150 waves;
  print_endline "\n=== SIMULATION COMPLETE ===";

