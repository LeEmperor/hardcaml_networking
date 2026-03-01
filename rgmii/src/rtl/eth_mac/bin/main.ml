open Hardcaml
open Rx_deserializer
open Signal
open Hardcaml_waveterm
open Hardcaml_event_driven_sim

(* functor result of Rx_deser*)
module Rx_deser = Circuit.With_interface (Rx_deserializer.I) (Rx_deserializer.O)
module Evsim = Hardcaml_event_driven_sim.Make (Hardcaml_event_driven_sim.Two_state_logic)

let () = 
  print_endline "exec started!";

  (* inst the circuit *)
  let circ : Circuit.t =
    Rx_deser.create_exn
      ~name:"rx_deser"
      (* (Rx_deserializer.create scope global_spec) *)
      (Rx_deserializer.create)
  in

  (* generate *)
  let rtl : Circuit.t -> unit = Rtl.output Verilog in
  (* rtl circ; *)

  (* inst the simulator *) 
  let wave, {Rx_deser.simulator, _} = 
    Rx_deser.with_waveterm
      Rx_deserializer.create




  ()
;;
