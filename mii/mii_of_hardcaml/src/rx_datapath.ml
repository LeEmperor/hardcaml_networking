open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

(* config option for a fifo or not at the very end of the rx path ? *)

let () =
  Stdio.print_endline "=== Imported MAC RX Datapath ==="

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* reg ens *)
    dst_mac_reg_en    : 'a;
    src_mac_reg_en    : 'a;
    byte_assembler_en : 'a;
    eth_type_reg_en   : 'a;

    (* sels *)
    payload_sel : 'a;

    (* branch input *)
    rx_data : 'a [@bits 4];
    (* how does one prevent an initial phase shift of 180 degrees of the nibbles alignment? *)
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    raw_byte_out        : 'a [@bits 8];
    raw_byte_out_valid  : 'a;
    payload_out         : 'a [@bits 8];

    (* debug lines *)
    keep : 'a;
  } [@@deriving hardcaml]
end

(* let tag_reg name (v : Always.Variable.t) = *)
(*   Always.Variable.{ v with value = v.value -- name } *)

let create 
  (scope : Scope.t )
  (i) : _ O.t
  = 
  (* scope shenanigans *) 
  let _scope : Scope.t = Scope.sub_scope scope "rx_datapath_scope" in

  (* port aliases *) (* possible to make a function that auto makes the port aliases for me? *)
  let clk = i.I.clk in
  let rst = i.I.rst in
  let en = i.I.en in
  let payload_sel = i.I.payload_sel in
  let dst_mac_reg_en = i.I.dst_mac_reg_en in
  let src_mac_reg_en = i.I.src_mac_reg_en in
  let eth_type_reg_en = i.I.eth_type_reg_en in
  let rising_edge = Reg_spec.create ~clock:clk ~clear:rst () in

  (* dst/src mac addr register blocks *)
  (* in theory this is another "assembler" thingy that I wrote with the nibble assembler, therefore I might be able to parameterize one for the word with in and the word with out, which should become an SRL or just MUXs in a Xilinx CLB *)
  let dst_addr_reg = reg ~enable:vdd ~width:48 rising_edge in
  (* let dst_addr = dst_addr_reg.value -- "dst_addr" in *)
  (* let dst_addr_reg = Always.Variable.reg ~enable:vdd ~width:48 rising_edge |> tag_reg "dst_addr" in *)
  let src_addr_reg = reg ~enable:vdd ~width:48 rising_edge in
  let eth_type_reg = reg ~enable:vdd ~width:16 rising_edge in

  let byte_assembler_inst =
    Rx_byte_assembler.create {
      Rx_byte_assembler.I.rx_data = i.I.rx_data;
      Rx_byte_assembler.I.en      = i.I.byte_assembler_en;
      Rx_byte_assembler.I.clk     = clk;
      Rx_byte_assembler.I.rst     = rst;
    }
  in

  let raw_byte_out        = byte_assembler_inst.byte_out   -- "dbg_byte_assembler_out" in
  let raw_byte_out_valid  = byte_assembler_inst.byte_valid -- "dbg_byte_assembler_valid" in
  let dst_addr = dst_addr_reg.value -- "dbg_dst_addr" in
  let src_addr = src_addr_reg.value -- "dbg_src_addr" in
  let eth_type = eth_type_reg.value -- "dbg_eth_type" in

  (* mux the payload out between 0 and the actual byte out *)
  let wire_out    = mux payload_sel [zero 8; raw_byte_out] -- "dbg_payload_out" in

  (* keep shenanigans for dbg *)
  let keep = reduce ~f:(|:) (
    (bits_lsb raw_byte_out) @
    (bits_lsb raw_byte_out_valid) @
    (bits_lsb dst_addr) @ 
    (bits_lsb src_addr) @ 
    (bits_lsb eth_type) @ 
    (bits_lsb wire_out)
  ) in

  (* behavioural register instantiations *)
  compile [
    when_ (dst_mac_reg_en &: raw_byte_out_valid) [
      dst_addr_reg <-- (
        (sll dst_addr ~by:8)
        |: (uresize raw_byte_out ~width:48)
      );
    ];
    when_ (src_mac_reg_en &: raw_byte_out_valid) [
      src_addr_reg <-- (
        (sll src_addr ~by:8)
        |: (uresize raw_byte_out ~width:48);
      );
    ];
    when_ (eth_type_reg_en &: raw_byte_out_valid) [
      eth_type_reg <-- (
        (sll eth_type ~by:8)
        |: (uresize raw_byte_out ~width:16)
      );
    ];
  ];

  {
    (* this is what the controller uses to branch *)
    raw_byte_out        = raw_byte_out;
    raw_byte_out_valid  = raw_byte_out_valid;

    (* this is the actual output *)
    payload_out       = wire_out;

    (* debug_dst_mac = dst_addr; *)
    keep = keep; (* truncation issues? *)
  }

