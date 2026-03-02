open Hardcaml
open Rx_deserializer
open Signal
open Hardcaml_waveterm
open Hardcaml_event_driven_sim
(* open Async *)

(* functor result of Rx_deser*)
module Evsim = Hardcaml_event_driven_sim.Make (Hardcaml_event_driven_sim.Two_state_logic)
module Rx_deser_dut = Evsim.With_interface (Rx_deserializer.I) (Rx_deserializer.O)
module Rx_deser_circ = Circuit.With_interface (Rx_deserializer.I) (Rx_deserializer.O)

let () = 
  print_endline "exec started!";

  (* inst the circuit *)
  let circ : Circuit.t =
    Rx_deser_circ.create_exn
      ~name:"rx_deser"
      (* (Rx_deserializer.create scope global_spec) *)
      (Rx_deserializer.create)
  in

  (* generate *)
  let rtl : Circuit.t -> unit = Rtl.output Verilog in
  rtl circ;

  (* dut *)
  let dut_create inputs : (Signal.t O.t) = Rx_deserializer.create inputs in
  (* let dut_create (inputs : Signal.t I.t) : (Signal.t O.t) = Rx_deserializer.create inputs in *)

  (* testbench stuff *)
  let build_events
    (input : Bits.t Port.t I.t)
    (_output : Bits.t Port.t O.t)
    : Evsim.Event_simulator.Process.t list =
    let open Evsim.Event_simulator in
    let open Async in

    (* wait until clk rises: fires on any change, retries if it was a falling edge *)
    let rec wait_rising () =
      let%bind () = wait_for_change !&(input.I.clk.signal) in
      if Evsim.Logic.to_bool !!(input.I.clk.signal)
      then Deferred.return ()
      else wait_rising ()
    in

    (* wait until clk falls *)
    let rec wait_falling () =
      let%bind () = wait_for_change !&(input.I.clk.signal) in
      if not (Evsim.Logic.to_bool !!(input.I.clk.signal))
      then Deferred.return ()
      else wait_falling ()
    in

    (* drive all 4 bits of rx_data from an integer nibble *)
    let drive_nibble (nibble : int) : unit =
      (* we make bits from a string *) (* this appears to be some funky string comprehension *)
      let bits : string = String.init 4 (fun i -> if (nibble lsr (3 - i)) land 1 = 1 then '1' else '0') in

      (* then we drive the signal full of the bits *)
      input.I.rx_data.signal <-- Evsim.Logic.of_string bits
    in

    (* DDR byte: drive upper AFTER falling (settled before next rising captures it),
       drive lower AFTER rising (settled before next falling captures it) *)
    let send_byte (byte : int) : unit Deferred.t = (* from what i can gather, this adds stuff in here to the list of things to update when the wait_falling callback resolves -> sort of like blocking an item until another item finishes *)
      let upper = (byte lsr 4) land 0xF in
      let lower = byte land 0xF in
      let%bind () = wait_falling () in
      drive_nibble upper;
      let%bind () = wait_rising () in
      drive_nibble lower;
      Deferred.return ()
    in

    (* perpetual block *)
    let clk_event : Process.t =
      Rx_deser_dut.create_clock input.I.clk.signal ~time:2
    in

    (* seq block *)
    let rst_event : Process.t =
      Async.create_process (fun () ->
        input.I.rst.signal <-- Evsim.Logic.of_string "1";
        let%bind () = wait_for_change !&(input.I.clk.signal) in
        let%bind () = wait_for_change !&(input.I.clk.signal) in
        let%bind () = wait_for_change !&(input.I.clk.signal) in
        let%bind () = wait_for_change !&(input.I.clk.signal) in
        input.I.rst.signal <-- Evsim.Logic.of_string "0";
        wait_forever ())
    in

    (* send a few bytes after reset clears *)
    let data_event : Process.t =
      Async.create_process (fun () ->
        (* wait past the reset window: rst deasserts after 4 edges (t=8),
           delay 20 puts us at t=20 which is cleanly after *)
        let%bind () = delay 20 in
        input.I.rx_ctl.signal <-- Evsim.Logic.of_string "1";
        let%bind () = send_byte 0xAB in
        let%bind () = send_byte 0xCD in
        let%bind () = send_byte 0xEF in
        (* send_byte ends after driving the lower nibble at a rising edge;
           wait for the next falling edge so the register captures it before
           we deassert rx_ctl *)
        let%bind () = wait_falling () in
        input.I.rx_ctl.signal <-- Evsim.Logic.of_string "0";
        wait_forever ())
    in

    [ clk_event; rst_event; data_event ]
  in

  (* waveterm and simulator instance *)
  let waves, {Rx_deser_dut.simulator; _} = Rx_deser_dut.with_waveterm dut_create build_events in

  Evsim.Event_simulator.run simulator ~time_limit:200;
  Hardcaml_event_driven_sim.Waveterm.Waveform.print waves ~wave_width:(-1) ~display_width:180;

  ()
;;
