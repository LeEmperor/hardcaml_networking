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

    payload_sel : 'a;
    (* payload_out_valid : 'a; *)
    byte_assembler_en : 'a;
    rx_data : 'a [@bits 4];
    (* how does one prevent an initial phase shift of 180 degrees of the nibbles alignment? *)
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    payload_out         : 'a [@bits 8];
    payload_out_valid   : 'a;
    debug_byte_assembler_d_out : 'a [@bits 8];
  } [@@deriving hardcaml]
end

let create 
  (inputs) : _ O.t
  = 
  (* port aliases *) (* possible to make a function that auto makes the port aliases for me? *)
    let clk = inputs.I.clk in
    let rst = inputs.I.rst in
    let en = inputs.I.en in
    let payload_sel = inputs.I.payload_sel in

    let byte_assembler_inst =
      Rx_byte_assembler.create {
        Rx_byte_assembler.I.rx_data = inputs.I.rx_data;
        Rx_byte_assembler.I.en      = inputs.I.byte_assembler_en;
        Rx_byte_assembler.I.clk     = clk;
        Rx_byte_assembler.I.rst     = rst;
      }
    in

    let wire_out = mux payload_sel [zero 8; byte_assembler_inst.byte_out; ] in

    {
      payload_out       = wire_out;
      payload_out_valid = byte_assembler_inst.byte_valid;
      (* this should be driven by the controller *)

      debug_byte_assembler_d_out = byte_assembler_inst.byte_out;
    }

