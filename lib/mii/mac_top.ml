(*
  Bohdan Purtell
  University of Florida

  Module: Mac_top
  Toplevel of the MII MAC. 
*)

open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC Top ==="

module Rx_word = struct
  type 'a t = {
    data : 'a [@bits 8];
    last : 'a;
    keep : 'a; (* unused *)
    user : 'a; 
  } [@@deriving hardcaml]
end

module Rx_fifo = Hardcaml_circuits.Fast_fifo.Make (Rx_word)

module Tx_word = struct
  type 'a t = {
    data : 'a [@bits 8];
  } [@@deriving hardcaml]
end

module Tx_fifo = Hardcaml_circuits.Fast_fifo.Make (Tx_word)

module I = struct
  type 'a t = {
    (* spec *)
    clock     : 'a; (* rx_clock *)
    reset     : 'a; (* rx rst *)
    en        : 'a;

    (* ethernet phy lines *)
    rx_dv   : 'a; (* activity line *)
    rx_er   : 'a; (* phy error line *)
    rx_data : 'a [@bits 4];

    (* axis exposed out signals *)
    (* Logic -> PHY *)
    m_axis_tready : 'a;

    (* TX AXI-Stream input *)
    s_axis_tdata  : 'a [@bits 8];
    s_axis_tvalid : 'a;
    s_axis_tuser  : 'a;
    tx_start      : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* axis exposed out signals *)
    (* PHY -> MAC -> downstream logic *)
    m_axis_tdata  : 'a [@bits 8]; (* 1 byte *)
    m_axis_tkeep  : 'a;
    m_axis_tlast  : 'a;
    m_axis_tvalid : 'a;
    m_axis_tuser  : 'a;

    (* FSM state indicators *)
    in_preamble : 'a;
    in_dst_mac  : 'a;
    in_payload  : 'a;

    (* CRC result — sampled once per frame *)
    frame_crc_ok : 'a;  (* holds last frame's CRC result; 1 = good *)
    frame_done   : 'a;  (* 1-cycle pulse when a frame completes *)

    (* TX MII output *)
    tx_d  : 'a [@bits 4];
    tx_en : 'a;

    (* TX AXI-Stream backpressure *)
    s_axis_tready : 'a;

    (* debug lines *)
    keep : 'a;
  } [@@deriving hardcaml]
end

let create 
  (scope : Scope.t )
  inputs : (_ O.t)
  = 
    let open Always in
    let open Variable in

    (* port aliases *)
    let clock  = inputs.I.clock in
    let reset  = inputs.I.reset in
    let clear  = reset in
    let en     = inputs.I.en in
    let d_in   = inputs.I.rx_data in
    let d_out  = Signal.wire 8 in

    let rising_edge : Reg_spec.t = 
      Reg_spec.create ~clock ~clear () 
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
    let wire_fcs_present        = Signal.wire 1 in

    let keep = Signal.wire 1 in

    let datapath_inst : Signal.t Rx_datapath.O.t = 
      Rx_datapath.create 
        scope
      {
        Rx_datapath.I.rx_data           = d_in;
        Rx_datapath.I.byte_assembler_en = wire_byte_assembler_en;
        Rx_datapath.I.clock             = clock;
        Rx_datapath.I.reset             = reset;
        Rx_datapath.I.en                = en;
        Rx_datapath.I.payload_sel       = wire_payload_sel;
        Rx_datapath.I.dst_mac_reg_en    = wire_dst_mac_reg_en;
        Rx_datapath.I.src_mac_reg_en    = wire_src_mac_reg_en;
        Rx_datapath.I.eth_type_reg_en   = wire_eth_type_reg_en;
        Rx_datapath.I.emit_payload      = wire_emit_payload;
        Rx_datapath.I.fcs_present       = wire_fcs_present; (* perhaps fcs can be moved to purely datapath item instead of needing to cross from the controller to the datapath *)
      }
    in

    let controller_inst = 
      Rx_controller.create 
        scope
      {
        Rx_controller.I.clock = clock;
        rst                   = rst;
        en                    = en;
        rx_dv                 = inputs.I.rx_dv;
        rx_er                 = inputs.I.rx_er;
        rx_data_valid         = wire_raw_byte_out_valid;
        (* rx_data               = wire_byte_out; *)
        rx_data               = datapath_inst.raw_byte_out;
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
  Signal.(wire_fcs_present        <-- controller_inst.fcs_present);

  let frame_end   = Helper_circuits.falling_edge_detector rising_edge inputs.I.rx_dv in
  (* rx_dv drops before byte_valid fires for FCS[3] (the last byte).  Extend
     crc_en through frame_end so the CRC processes that final byte and settles
     at the residue on the cycle when we sample crc_valid for tuser. *)
  let crc_en =
    (~: (controller_inst.in_preamble)) &: (inputs.I.rx_dv |: frame_end) &: en
  in

  let crc_inst =
    Rx_crc.create scope
    { Rx_crc.I.clock           = clock;
      rst                    = rst;
      en                     = crc_en;
      rx_data                = datapath_inst.raw_byte_out;
      rx_data_valid          = datapath_inst.raw_byte_out_valid;
    }
  in

  (* frame_end_d: frame_end delayed by 1 cycle.
     B(F3) = the extra cycle after rx_dv drops (raw_byte_out_valid=1 for FCS[3]).
     wr_enable_raw=1 at B(F3) → wr_valid_d=1 one cycle later (i=0 of drain phase).
     frame_end fires at B(F3); frame_end_d fires at i=0, aligning with wr_valid_d. *)
  let frame_end_d = Signal.reg rising_edge frame_end in
  (* frame_end fires when rx_dv drops; crc_reg updates with FCS[3] at the clock
     edge ending that cycle.  frame_end_d fires one cycle later when crc_valid
     is already settled — that is the correct sample point. *)
  let frame_ok    = Signal.reg rising_edge ~enable:frame_end_d crc_inst.crc_valid in

  (* gate on raw_byte_out_valid: the datapath holds payload_out_valid high
     between nibble pairs, so without this gate every byte would be written twice *)
  let wr_enable_raw = datapath_inst.payload_out_valid &: datapath_inst.raw_byte_out_valid in
  (* 1-cycle delay: crc_inst.crc_valid is combinatorial from crc_reg, which is updated
     at the clock edge that processes FCS[3]. the delayed write lands on the following
     cycle when crc_valid is already settled, so we can use it directly for tuser. *)
  let wr_data_d  = Signal.reg rising_edge datapath_inst.payload_out in
  let wr_valid_d = Signal.reg rising_edge wr_enable_raw in
  (* tlast: frame_end_d (1-cycle-delayed falling edge) aligns with wr_valid_d for last byte *)
  let tlast_wr   = frame_end_d &: wr_valid_d in

  let rx_fifo =
    Rx_fifo.create
    ~cut_through:true
    ~capacity:128
    scope
    {
      Rx_fifo.I.clock = clock;
      clear = rst;
      wr_enable = wr_valid_d;
      wr_data =
        {
          Rx_word.data = wr_data_d;
          last         = tlast_wr;
          keep         = Signal.vdd;
          user         = mux2 tlast_wr (~: (crc_inst.crc_valid)) Signal.gnd;
        };
        rd_enable = inputs.m_axis_tready
    }
  in

  (* TX payload FIFO: AXI-S writes in, controller reads out during Payload state.
     wire_tx_fifo_rd_en and wire_dis_ready break instantiation-order dependencies. *)
  let wire_tx_fifo_rd_en = Signal.wire 1 in
  let wire_dis_ready     = Signal.wire 1 in
  let wire_fcs_byte      = Signal.wire 8 in

  let tx_fifo =
    Tx_fifo.create
    ~cut_through:true
    ~capacity:128
    scope
    { Tx_fifo.I.clock     = clock;
      clear               = rst;
      wr_enable           = inputs.I.s_axis_tvalid;
      wr_data             = { Tx_word.data = inputs.I.s_axis_tdata };
      rd_enable           = wire_tx_fifo_rd_en;
    }
  in

  let tx_ctrl =
    Tx_controller.create scope
    { Tx_controller.I.clock        = clock;
      rst                         = rst;
      en                          = en;
      start                       = inputs.I.tx_start;
      fifo_empty                  = ~:(tx_fifo.rd_valid);
      dis_ready                   = wire_dis_ready;
    }
  in

  (* Pop FIFO and advance controller only when the serializer can accept the next byte *)
  Signal.(wire_tx_fifo_rd_en <-- (tx_ctrl.state ==:. 6 &: wire_dis_ready));

  let tx_dp =
    Tx_datapath.create scope
    { Tx_datapath.I.clock           = clock;
      rst                          = rst;
      en                           = en;
      s_axis_tdata                 = tx_fifo.rd_data.data;
      s_axis_tvalid                = tx_fifo.rd_valid;
      s_axis_tuser                 = inputs.I.s_axis_tuser;
      fcs_byte                     = wire_fcs_byte;
      byte_mux_sel                 = tx_ctrl.byte_mux_sel;
      mac_byte_sel                 = tx_ctrl.mac_byte_sel;
    }
  in

  let tx_ser =
    Tx_byte_disassembler.create scope
    { Tx_byte_disassembler.I.clock          = clock;
      rst                                  = rst;
      en                                   = en;
      byte_in                              = tx_dp.byte_out;
      byte_in_valid                        = ~:(tx_ctrl.state ==:. 0);
    }
  in

  Signal.(wire_dis_ready <-- tx_ser.ready);

  (* CRC accumulates dst_mac/src_mac/eth_type/payload (states 3-6), gated on
     dis_ready so each byte is counted exactly once.  en=0 in Idle resets the
     accumulator between frames.  byte_sel drives the FCS byte mux in Fcs state. *)
  let crc_active = (tx_ctrl.state >=:. 3) &: (tx_ctrl.state <=:. 6) in
  let tx_crc_inst =
    Tx_crc.create scope
    { Tx_crc.I.clock       = clock;
      rst                  = rst;
      en                   = ~:(tx_ctrl.state ==:. 0);
      data                 = tx_dp.byte_out;
      data_valid           = wire_dis_ready &: crc_active;
      byte_sel             = Signal.select tx_ctrl.mac_byte_sel ~high:1 ~low:0;
    }
  in

  Signal.(wire_fcs_byte <-- tx_crc_inst.fcs_byte);

  (* can i map this to a function that lets me auto-bind the keep functionality? *)
  let keep = reduce ~f:(|:) (
      (bits_lsb datapath_inst.keep) @
      (bits_lsb controller_inst.keep)
  ) in

  (* old non-fifo interface -> use param to emulate generate block *)
  (* { *)
  (*   m_axis_tdata  = datapath_inst.payload_out; *)
  (*   m_axis_tuser  = Signal.gnd; *)
  (*   m_axis_tvalid = datapath_inst.payload_out_valid; *)
  (*   m_axis_tlast  = Signal.gnd; *)
  (*   m_axis_tkeep  = Signal.gnd; *)
  (**)
  (*   keep = Signal.zero 1; *)
  (* } *)
  (**)

  {
    m_axis_tdata  = rx_fifo.rd_data.data;
    m_axis_tvalid = rx_fifo.rd_valid;
    m_axis_tlast  = rx_fifo.rd_data.last;
    m_axis_tkeep  = rx_fifo.rd_data.keep;
    m_axis_tuser  = rx_fifo.rd_data.user;

    in_preamble   = controller_inst.in_preamble;
    in_dst_mac    = controller_inst.in_dst_mac;
    in_payload    = controller_inst.in_payload;
    frame_crc_ok  = frame_ok;
    frame_done    = Signal.reg rising_edge frame_end_d;
    tx_d          = tx_ser.tx_d;
    tx_en         = tx_ser.tx_en;
    s_axis_tready = ~:(tx_fifo.full);
    keep          = keep;
  }

