(** 
  module_name: rx_deserializer 
  file_name: rx_deserializer.ml
  desc:
    this is a DDR-related module
    input:
      we take in the following from the PHY
        1. RXD [3:0]
        2. RX_CTL
        3. RX_CLK

    output:
      we output the following:
        grouped bytes of data from the PHY

    internal logic:
      take in the rx_ctl to mark the start of a transmission
      on the rising edge of the rx_clk,
        sample the rx_data line and write these into the upper nibble of the byte-to-be-transmitted
      on the falling edge of the same rx_clk,
        sample the rx_data line and write these into the lower nibble of the byte-to-be-transmitted
 *)

open Hardcaml

module I = struct
  type 'a t = {
    clk : 'a; (* 125 MHz clock, DDR from PHY *)
    clk_div2 : 'a; (* 62.5 MHz clock for byte sync *)

    rst : 'a;
    rx_data : 'a array [@length 4];
    rx_ctl : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    byte : 'a [@bits 8];
    valid : 'a;
    (* start_of_frame : 'a; *)
    (* end_of_frame : 'a; *)
    (* error : 'a; *)
  } [@@deriving hardcaml]
end

let create 
  (inputs: Signal.t I.t)
  : 
  (Signal.t O.t) (* returns an output O*)
  = 

  (* step 1: wait for the rx_ctl edge *)

  let rising_edge : Reg_spec.t = 
    (* Reg_spec.create ~clock:inputs.I.clk ~reset:inputs.I.rst ()  *)
    Reg_spec.create ~clock:inputs.I.clk ~clear:inputs.I.rst () 
  in

  let falling_edge : Reg_spec.t =
    (* Reg_spec.create ~clock:inputs.I.clk ~reset:inputs.I.rst () *)
    Reg_spec.create ~clock:inputs.I.clk ~clear:inputs.I.rst ()
    |> Reg_spec.override ~clock_edge:Edge.Falling
  in

  (* register to store upper data bits, uses the rising edge as an enable*)
  let data_upper : Always.Variable.t = 
    Always.Variable.reg 
      ~enable:inputs.I.rx_ctl
      ~width:4
      rising_edge  
  in

  let data_lower : Always.Variable.t = 
    Always.Variable.reg
      ~enable:inputs.I.rx_ctl
      ~width:4
      falling_edge
  in

  (* assign the data values of data_upper and data_lower as the inputs of I (needs a transformation from Array to List)*)
  let _ =
  Always.(
    compile [
      data_upper <-- Signal.concat_msb (Array.to_list inputs.I.rx_data);
      data_lower <-- Signal.concat_msb (Array.to_list inputs.I.rx_data);
    ]
  ) in

  let data_byte : Signal.t = 
    Signal.concat_msb [
      Always.Variable.value data_upper;
      Always.Variable.value data_lower;
    ] in

  let valid : Signal.t = inputs.I.rx_ctl in 

  {
    byte = data_byte;
    valid = valid;
  }

let () = 
  print_endline "deserializer lib imported!"
