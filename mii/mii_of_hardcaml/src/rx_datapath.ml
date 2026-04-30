open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

(* config option for a fifo or not at the very end of the rx path *)

let () =
  Stdio.print_endline "=== Imported MAC RX Datapath ==="

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
    en  : 'a;

    payload_sel : 'a;
    dst_mac_reg_en : 'a;
    src_mac_reg_en : 'a;
    byte_assembler_en : 'a;
    rx_data : 'a [@bits 4];
    (* how does one prevent an initial phase shift of 180 degrees of the nibbles alignment? *)
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* real data lines *)
    raw_byte_out        : 'a [@bits 8];
    payload_out         : 'a [@bits 8];
    payload_out_valid   : 'a;

    (* debug lines *)
    debug_byte_assembler_d_out : 'a [@bits 8];
    debug_byte_assembler_d_out_valid : 'a;
    debug_dst_addr : 'a [@bits 48];
    debug_src_addr : 'a [@bits 48];
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
  let dst_mac_reg_en = inputs.I.dst_mac_reg_en in
  let src_mac_reg_en = inputs.I.src_mac_reg_en in
  let rising_edge = Reg_spec.create ~clock:clk ~clear:rst () in

  (* dst/src mac addr register blocks *)
  (* in theory this is another "assembler" thingy that I wrote with the nibble assembler, therefore I might be able to parameterize one for the word with in and the word with out, which should become an SRL or just MUXs in a Xilinx CLB *)
  let dst_addr_reg = Always.Variable.reg ~enable:vdd ~width:48 rising_edge in
  let src_addr_reg = Always.Variable.reg ~enable:vdd ~width:48 rising_edge in

  let byte_assembler_inst =
    Rx_byte_assembler.create {
      Rx_byte_assembler.I.rx_data = inputs.I.rx_data;
      Rx_byte_assembler.I.en      = inputs.I.byte_assembler_en;
      Rx_byte_assembler.I.clk     = clk;
      Rx_byte_assembler.I.rst     = rst;
    }
  in

  let wire_out = mux payload_sel [zero 8; byte_assembler_inst.byte_out; ] in
  
    compile [
      when_ (dst_mac_reg_en &: byte_assembler_inst.byte_valid) [
        dst_addr_reg <-- (
          (sll dst_addr_reg.value ~by:8) 
          |: (uresize byte_assembler_inst.byte_out ~width:48)
        );
      ];
      when_ (src_mac_reg_en &: byte_assembler_inst.byte_valid) [
        src_addr_reg <-- (
          (sll src_addr_reg.value ~by:8)
          |: (uresize byte_assembler_inst.byte_out ~width:48);
        );
      ];
    ];

  {
    (* this is what the controller uses to branch *)
    raw_byte_out = byte_assembler_inst.byte_out;

    (* this is the actual output *)
    payload_out       = wire_out;
    payload_out_valid = byte_assembler_inst.byte_valid;
    (* this should be driven by the controller *)

    debug_byte_assembler_d_out = byte_assembler_inst.byte_out;
    debug_byte_assembler_d_out_valid = byte_assembler_inst.byte_valid;
    debug_dst_addr = dst_addr_reg.value;
    debug_src_addr = src_addr_reg.value;

    (* debug_dst_addr = zero 48; *)
    (* debug_src_addr = zero 48; *)
  }

