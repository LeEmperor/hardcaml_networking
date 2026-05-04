open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC RX Top ==="

module I = struct
  type 'a t = {
    (* spec *)
    clock     : 'a; (* rx_clk *)
    reset     : 'a; (* rx rst *)
    en        : 'a;

    (* ethernet phy lines *)
    rx_dv   : 'a; (* activity line *)
    rx_er   : 'a; (* phy error line *)
    rx_data : 'a [@bits 4];

    (* axis exposed out signals *)
    (* Logic -> PHY *)
    m_axis_tready : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* axis exposed out signals *)
    (* PHY -> Logic *)
    m_axis_tdata  : 'a [@bits 8]; (* 1 byte *)
    m_axis_tkeep  : 'a;
    m_axis_tlast  : 'a;
    m_axis_tvalid : 'a;
    m_axis_tuser  : 'a;

    (* debug lines *)
    keep : 'a;
  } [@@deriving hardcaml]
end

module States = struct
  type t =
    | IDLE
    | PREAMBLE
    | DST_MAC
    | SRC_MAC
    | ETH_TYPE
    | PAYLOAD
    | DONE 
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create 
  (scope : Scope.t )
  inputs : (_ O.t)
  = 
    let open Always in
    let open Variable in

    (* port aliases *)
    let clk  = inputs.I.clock in
    let rst  = inputs.I.reset in
    let en   = inputs.I.en in
    let d_in = inputs.I.rx_data in
    let d_out = Signal.wire 8 in

    let rising_edge : Reg_spec.t = 
      Reg_spec.create ~clock:clk ~clear:rst () 
    in

    (* internal ties *)
    (* let wire_byte_assembler_en = wire ~default:gnd in (* does this autosize? *) *)
    let wire_byte_assembler_en  = Signal.wire 1 in
    let wire_raw_byte_out       = Signal.wire 8 in
    let wire_raw_byte_out_valid = Signal.wire 1 in
    let wire_payload_sel        = Signal.wire 1 in
    let wire_dst_mac_reg_en     = Signal.wire 1 in
    let wire_src_mac_reg_en     = Signal.wire 1 in
    let wire_eth_type_reg_en    = Signal.wire 1 in
    let wire_emit_payload       = Signal.wire 1 in

    let keep = Signal.wire 1 in

    let datapath_inst : Signal.t Rx_datapath.O.t = 
      Rx_datapath.create 
        scope
      {
        Rx_datapath.I.rx_data           = d_in;
        Rx_datapath.I.byte_assembler_en = wire_byte_assembler_en;
        Rx_datapath.I.clk               = clk;
        Rx_datapath.I.rst               = rst;
        Rx_datapath.I.en                = rst;
        Rx_datapath.I.payload_sel       = wire_payload_sel;
        Rx_datapath.I.dst_mac_reg_en    = wire_dst_mac_reg_en;
        Rx_datapath.I.src_mac_reg_en    = wire_src_mac_reg_en;
        Rx_datapath.I.eth_type_reg_en   = wire_eth_type_reg_en;
        Rx_datapath.I.emit_payload      = wire_emit_payload;
      }
    in

    let controller_inst = 
      Rx_controller.create 
        scope
      {
        Rx_controller.I.clk = clk;
        rst             = rst;
        en              = en;
        rx_dv           = inputs.I.rx_dv;
        rx_er           = inputs.I.rx_er;
        rx_data_valid   = wire_raw_byte_out_valid;
        (* rx_data         = wire_byte_out; *)
        rx_data         = datapath_inst.raw_byte_out;
      }
    in

  (* wire assigns *)
  Signal.(wire_raw_byte_out          <-- datapath_inst.raw_byte_out);
  Signal.(wire_raw_byte_out_valid    <-- datapath_inst.raw_byte_out_valid);

  Signal.(wire_byte_assembler_en  <-- controller_inst.byte_assembler_en);
  Signal.(wire_payload_sel        <-- controller_inst.payload_sel);
  Signal.(wire_dst_mac_reg_en     <-- controller_inst.dst_mac_reg_en);
  Signal.(wire_src_mac_reg_en     <-- controller_inst.src_mac_reg_en);
  Signal.(wire_eth_type_reg_en    <-- controller_inst.eth_type_reg_en);
  Signal.(wire_emit_payload       <-- controller_inst.emit_payload);

  (* can i map this to a function that lets me auto-bind the keep functionality? *)
  let keep = reduce ~f:(|:) (
      (bits_lsb datapath_inst.keep) @ 
      (bits_lsb controller_inst.keep)
  ) in

  {
    m_axis_tdata  = datapath_inst.payload_out;
    m_axis_tuser  = Signal.gnd;
    m_axis_tvalid = datapath_inst.payload_out_valid;
    m_axis_tlast  = Signal.gnd;
    m_axis_tkeep  = Signal.gnd;

    keep = keep;
  }


