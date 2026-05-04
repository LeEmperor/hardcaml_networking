open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm
(* open! Bits *)

let () =
  print_endline "=== Running MAC RX Controller Testbench ===";;

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Rx_controller.I)(Rx_controller.O)
(* we hand Sim's namespace a create function and it does the heavy lifting because the shapes were known from the earlier functor call *)

let create_sim () 
  =
  let sim                               = Sim.create Rx_controller.create in
  (* let waves, sim                        = Waveform.create sim in *)
  let inputs  : _ Rx_controller.I.t = Cyclesim.inputs sim in
  let outputs : _ Rx_controller.O.t = Cyclesim.outputs sim in
  (* (sim, waves, inputs, outputs) *)
  (sim, inputs, outputs)

  (* Hardcaml.Vcd.wrap : (string -> unit) -> ('i, 'o) Cyclesim.t -> ('i, 'o) Cyclesim.t *)
  (* 
     3 args: 
        1. (string, unit) tuple?
        2. Cyclesim.t object
        3. returns Cyclesim.t object
  *)

let () = 
  let open Bits in
  (* let sim, waves, inputs, outputs = create_sim () in *)
  let sim, inputs, outputs = create_sim () in

  Out_channel.with_file "waves.vcd" ~f:(fun oc ->
  let sim = Vcd.wrap oc sim in

  (* display helper *)

 let cycle () =
    Cyclesim.cycle sim;
    (* printf "rx_data=%x rx_dv=%d rx_er=%d rx_en=%d\n" *)
    (*   (Bits.to_int_trunc !(inputs.clk)) *)
    (*   (Bits.to_int_trunc !(inputs.rst)) *)
    (*   (Bits.to_int_trunc !(inputs.en)) *)
    (*   (Bits.to_int_trunc !(inputs.rx_dv)) *)
    (*   (Bits.to_int_trunc !(inputs.rx_er)) *)
    (*   (Bits.to_int_trunc !(inputs.rx_data)) *)
    (*   (Bits.to_int_trunc !(inputs.rx_data_valid)) *)
  in
  
  (* assign helper *)
  let (<--) r i = r := Bits.of_int_trunc ~width:(Bits.width !r) i in

  (* signal aliases *)
  let t_rst   = inputs.rst in
  let t_en    = inputs.en in
  let t_in    = inputs.rx_data in
  let t_in_valid = inputs.rx_data_valid in
  let t_rx_dv = inputs.rx_dv in

  let t_byte_assembler_en =  outputs.byte_assembler_en in
  (* let t_state_vec = outputs.debug_state_vec in *)
  (* let t_stable = outputs.debug_stable in *)

  let reset () =
    t_en  <-- 0;
    t_rst <-- 1;
    t_rx_dv <-- 0;
    cycle ();
    t_rst <-- 0;
  in

  let send lo hi =
    t_en <-- 1;
    t_in_valid <-- 0;
    t_in <-- lo;
    cycle ();
    t_in <-- hi;
    t_in_valid <-- 1;
    cycle ();
  in

  let send_byte byte =
    let hi = (byte lsl 4) land 0xF in
    let lo = byte land 0xF in
    send hi lo;

    printf "\n==Byte sent: == %d ==\n" byte;
    (* slice the byte in half, how do we do more advanced math with a hex value? *)
  in

  let send_byte_oneshot byte =
    t_en <-- 1;
    t_in_valid <-- 1;
    t_in <-- byte;
    cycle();
  in

  let idle () =
    t_en <-- 0;
    cycle ();
  in

  (* -- test 1: 0x55 for a while -> expect state=PREAMBLE -- *)
  printf "\n[test 1] STUFF ";
  reset ();

  (*PREAMBLE*)
  send_byte_oneshot 0x55;
  send_byte_oneshot 0x55;
  send_byte_oneshot 0x55;
  send_byte_oneshot 0x55;

  (* SFD *)
  send_byte_oneshot 0xD5;

  (* DST MAC *)
  for i = 0x20 to 0x26 do
    send_byte_oneshot i;
  done;

  (* SRC MAC*)
  for i = 0x30 to 0x36 do
    send_byte_oneshot i;
  done;

  (* ETH_TYPE *)
  send_byte_oneshot 0x11;
  send_byte_oneshot 0x22;

  (* PAYLOAD *)
  for i = 0x01 to 0x40 do
    send_byte_oneshot i;
  done;

  (* drive frame finish *)
  t_rx_dv <-- 1;

  (* tail cycle *)
  for i = 0 to 10 do
    cycle();
  done;

  idle ();
  cycle();

  print_endline "\n=== SIMULATION COMPLETE ===";
  )
;;

