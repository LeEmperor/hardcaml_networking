open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm
open! Helper_tb_functions

let () =
  print_endline "=== Running MAC TX Byte Disassembler Testbench ===";;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Tx_byte_disassembler.I)(Tx_byte_disassembler.O)

(* is it possible to make a functor that takes in the shapes and makes me all these items so I don't have to re-define create_sim every time? *)
let create_sim () 
  =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in

  let sim = Sim.create ~config:Cyclesim.Config.trace_all (Tx_byte_disassembler.create scope) in
  let waves, sim = Waveform.create sim in
  let i  : _ Tx_byte_disassembler.I.t = Cyclesim.inputs sim in
  let o : _ Tx_byte_disassembler.O.t = Cyclesim.outputs sim in
  (sim, waves, i, o)
;;

let () = 
  let open Bits in
  let sim, waves, i, o = create_sim () in

  (* vcd wrap *)
  Out_channel.with_file "waves_byte_disassembler.vcd" ~f:(fun oc->
    let sim = Vcd.wrap oc sim in

  (* display helper *)
  let cycle () =
    Cyclesim.cycle sim;
    (* printf ""  *)
    (* () *)
  in
  
  (* assign helper *)
  let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in

  (* signal aliases *)
  let t_rst       = i.rst in
  let t_en        = i.en in
  let t_in        = i.byte_in in
  let t_in_valid  = i.byte_in_valid in

  let reset () =
    (* data lines *)
    t_in <-- 0;
    t_in_valid <-- 0;

    (* spec lines *)
    t_en  <-- 0;
    t_rst <-- 1;
    cycle ();
    t_rst <-- 0;
    cycle();
  in

  let send lo hi =
    t_en <-- 1;
    t_in <-- lo;
    cycle ();
    t_in <-- hi;
    cycle ();
  in

  let send_byte byte : unit =
    t_in <-- byte;
    t_in_valid <-- 1;
    cycle();
  in

  let idle () =
    t_en <-- 0;
    cycle ();
  in

  reset();
  (* -- test 1: feed a byte and watch both nibbles come out -- *)
  printf "\n[test 1] 0xAB -> expect 0xA, 0xB\n";
  send_byte 0xAB;
  t_in <-- 0;
  t_in_valid <-- 0;

  (* tail cycle *)
  for i=0 to 10 do
    cycle();
  done;

  idle ();

  (* Waveform.print ~display_width:150 waves; *)
  print_endline "\n=== SIMULATION COMPLETE ===";
  )

;;
