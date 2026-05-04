open Hardcaml
open Rx_deserializer
open Signal
open Hardcaml_waveterm

module Thing = Circuit.With_interface (Rx_deserializer.I) (Rx_deserializer.O)

let () = 
  print_endline "exec started!";
  (* let scope = Scope.create ~flatten_design:true () in *)
  (* let global_spec = Reg_spec.create ~clock:(Signal.input "clk" 1) in *)

  let circ : Circuit.t =
    Thing.create_exn
      ~name:"rx_deser"
      (* (Rx_deserializer.create scope global_spec) *)
      (Rx_deserializer.create)
  in

  (* Generate *)
  (* this means that "rtl" is a function that takes in Circuit.t and returns unit*)
  (* as compared to an expression, which would just have : unit as the return*)
  let rtl : Circuit.t -> unit = Rtl.output Verilog in
  rtl circ;

  (* let () = Rtl.print Verilog circ in *)

  (* sim stuff *)
  let (simulator : _ Cyclesim.t) = 
    Cyclesim.create circ 
  in

  let sim_clk = 
    Cyclesim.in_port simulator "clk" 
  in

  let sim_rst = 
    Cyclesim.in_port simulator "rst"
  in

  let sim_ctl = 
    Cyclesim.in_port simulator "rx_ctl"
  in

  (* let sim_data_in =  *)
  (*   Cyclesim.in_port simulator "rx_data_1" *)
  (* in *)

  let sim_data = Array.init 4 (fun i ->
    Cyclesim.in_port simulator (Printf.sprintf "rx_data_%d" i)
  ) in

  let sim_data_out = 
    Cyclesim.out_port simulator "byte"
  in

  let sim_valid_out = 
    Cyclesim.out_port simulator "valid"
  in

  Cyclesim.reset simulator;
  
  let waveform, simulator = 
    Hardcaml_waveterm.Waveform.create simulator
  in

  (* Helper function to set 4-bit data *)
  let set_data value =
    Array.iteri (fun i port ->
      port := Bits.of_int ~width:1 ((value lsr i) land 1)
    ) sim_data
  in
  
  (* Reset phase *)
  sim_rst := Bits.vdd;
  for _ = 0 to 5 do
    sim_clk := Bits.vdd;
    Cyclesim.cycle simulator;
    sim_clk := Bits.gnd;
    Cyclesim.cycle simulator
  done;
  sim_rst := Bits.gnd;
  
  (* Test: send 4-bit value 0xA (1010) *)
  set_data 0xA;
  sim_ctl := Bits.vdd;  (* Strobe the control line *)
  sim_clk := Bits.vdd;
  Cyclesim.cycle simulator;
  
  sim_ctl := Bits.gnd;  (* Release control *)
  sim_clk := Bits.gnd;
  Cyclesim.cycle simulator;
  
  (* Let it settle for a few more cycles *)
  for _ = 0 to 10 do
    sim_clk := Bits.vdd;
    Cyclesim.cycle simulator;
    sim_clk := Bits.gnd;
    Cyclesim.cycle simulator
  done;
  
  Hardcaml_waveterm.Waveform.print waveform;

  ()
;;
