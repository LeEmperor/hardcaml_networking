open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC RX Datapath ==="

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
    en  : 'a;

    byte_assembler_en : 'a;
    rx_data : 'a [@bits 4];
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    d_out         : 'a [@bits 8];
    d_out_valid   : 'a;
  } [@@deriving hardcaml]
end

let create 
  (inputs) : _ O.t
  = 
  (* port aliases *) (* possible to make a function that auto makes the port aliases for me? *)
    let clk = inputs.I.clk in
    let rst = inputs.I.rst in

    let byte_assembler_inst =
      Rx_byte_assembler.create {
        Rx_byte_assembler.I.rx_data = inputs.I.rx_data;
        Rx_byte_assembler.I.en      = inputs.I.byte_assembler_en;
        Rx_byte_assembler.I.clk     = clk;
        Rx_byte_assembler.I.rst     = rst;
      }
    in

    {
      d_out       = zero 8;
      d_out_valid = zero 1;
    }

