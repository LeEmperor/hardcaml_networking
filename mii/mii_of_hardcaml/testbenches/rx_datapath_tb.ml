open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm

let () =
  print_endline "=== Running  MAC RX Datapath Testbench ===";;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Rx_datapath.I)(Rx_datapath.O)
(* we hand Sim's namespace a create function and it does the heavy lifting because the shapes were known from the earlier functor call *)

let create_sim ()
  =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim   = Sim.create ~config:Cyclesim.Config.trace_all (Rx_datapath.create scope) in
  let waves, sim                        = Waveform.create sim in
  let inputs  : _ Rx_datapath.I.t = Cyclesim.inputs sim in
  let outputs : _ Rx_datapath.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)

let () = 
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in

  (* vcd wrapper *)
  Out_channel.with_file "waves_datapath.vcd" ~f:(fun oc->
  let sim = Vcd.wrap oc sim in

  (* display helper *)
 let cycle () =
    Cyclesim.cycle sim;
  in
  
  (* assign helper *)
  let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in

  (* signal aliases *)
  let t_clk   = inputs.clk in
  let t_rst   = inputs.rst in
  let t_en    = inputs.byte_assembler_en in

  let t_in          = inputs.rx_data in
  let t_payload_sel = inputs.payload_sel in

  let t_out       = outputs.payload_out in
  let t_out_valid = outputs.payload_out_valid in

  let reset () =
    t_en  <-- 0;
    t_rst <-- 1;
    cycle ();
    t_rst <-- 0;
    t_en <-- 1;
    t_in <-- 0;
  in

  let send lo hi =
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

  (* -- test 1: 0x55 for a while -> expect state=PREAMBLE -- *)
  printf "\n[test 1] 0x55";
  reset ();

  for i = 0 to 5 do
    (* send_byte 0x55; *)
    t_in <-- 0x5;
    cycle();
    t_in <-- 0x5;
    cycle();
  done;

  t_payload_sel <-- 1;
  for i = 0x61 to 0x67 do
    send_byte i;
  done;

  idle ();

  (* tail cycle *)
  for i = 0 to 10 do
    cycle();
  done;

  print_endline "\n=== SIMULATION COMPLETE ===";
  )
;;
