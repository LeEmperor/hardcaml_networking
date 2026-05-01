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
    raw_byte_out        : 'a [@bits 8];
    payload_out         : 'a [@bits 8];
    payload_out_valid   : 'a;

    (* debug_dst_mac : 'a [@bits 48]; *)
    keep : 'a;
  } [@@deriving hardcaml]
end

(* let tag_reg name (v : Always.Variable.t) = *)
(*   Always.Variable.{ v with value = v.value -- name } *)

let create 
  (scope : Scope.t )
  (inputs) : _ O.t
  = 
  (* scope shenanigans *)
  let _scope : Scope.t = Scope.sub_scope scope "rx_datapath_scope" in

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
  (* let dst_addr = dst_addr_reg.value -- "dst_addr" in *)
  (* let dst_addr_reg = Always.Variable.reg ~enable:vdd ~width:48 rising_edge |> tag_reg "dst_addr" in *)
  let src_addr_reg = Always.Variable.reg ~enable:vdd ~width:48 rising_edge in

  let byte_assembler_inst =
    Rx_byte_assembler.create {
      Rx_byte_assembler.I.rx_data = inputs.I.rx_data;
      Rx_byte_assembler.I.en      = inputs.I.byte_assembler_en;
      Rx_byte_assembler.I.clk     = clk;
      Rx_byte_assembler.I.rst     = rst;
    }
  in

  let byte_out    = byte_assembler_inst.byte_out   -- "byte_assembler_out" in
  let byte_valid  = byte_assembler_inst.byte_valid -- "byte_assembler_valid" in
  (* let byte_valid_bruh  = byte_assembler_inst.byte_valid -- "byte_assembler_valid" in *)
  let dst_addr = dst_addr_reg.value -- "dst_addr"
  and src_addr = src_addr_reg.value -- "src_addr" in

  (* mux the payload out between 0 and the actual byte out *)
  let wire_out    = mux payload_sel [zero 8; byte_out] -- "payload_out" in

  let keep = reduce ~f:(|:) (bits_lsb dst_addr @ bits_lsb src_addr) in

  (* behavioural register instantiations *)
  compile [
    when_ (dst_mac_reg_en &: byte_valid) [
      dst_addr_reg <-- (
        (sll dst_addr ~by:8)
        |: (uresize byte_out ~width:48)
      );
    ];
    when_ (src_mac_reg_en &: byte_valid) [
      src_addr_reg <-- (
        (sll src_addr ~by:8)
        |: (uresize byte_out ~width:48);
      );
    ];
  ];

  {
    (* this is what the controller uses to branch *)
    raw_byte_out = byte_assembler_inst.byte_out;

    (* this is the actual output *)
    payload_out       = wire_out;
    payload_out_valid = byte_valid;
    (* this should be driven by the controller *)

    (* debug_dst_mac = dst_addr; *)
    keep = keep; (* truncation issues? *)
  }

