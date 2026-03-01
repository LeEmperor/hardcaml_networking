open Hardcaml
open Rx_deserializer
open Signal
open Hardcaml_waveterm
open Hardcaml_event_driven_sim

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
  (* rtl circ; *)

  (* dut *)
  let dut_create inputs : (Signal.t O.t) = Rx_deserializer.create inputs in
  (* let dut_create (inputs : Signal.t I.t) : (Signal.t O.t) = Rx_deserializer.create inputs in *)

  (* testbench stuff *)
  let build_events
    (input : Bits.t Port.t I.t)
    (_output : Bits.t Port.t O.t)
    : Evsim.Event_simulator.Process.t list =
    let open Evsim.Event_simulator in

    let clk_event : Process.t =
      Rx_deser_dut.create_clock input.I.clk.signal ~time:2
    in

    let drive_inputs_event : Process.t =
      Process.create [] (fun () -> (* how does this syntax work? *)
        input.I.rst.signal <-- Evsim.Logic.of_string "0";
      )
    in

    [ clk_event; drive_inputs_event ]
  in

  (* waveterm and simulator instance *)
  let waves, {Rx_deser_dut.simulator; _} = Rx_deser_dut.with_waveterm dut_create build_events in

  ()
;;
