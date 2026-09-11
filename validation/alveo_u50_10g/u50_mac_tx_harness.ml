(* Module: U50_mac_tx_harness

   Alveo U50 TX validation harness: autonomous frame source -> Mac_10g_top -> XGMII. Rung
   1 of the bring-up ladder in docs/mac_10g_u50_tx_validation_plan.md section 11.0.

   This is the analogue of validation/mac_validation_harness.ml, and it differs from it in
   the two ways the boards differ.

   First, it wraps the complete Mac_10g_top rather than a TX-only composition. That is
   what supplies the AXI4-Lite control plane, and the control plane is the whole
   observation strategy here: the Arty harness reported status on LEDs because the Arty
   had sixteen of them, whereas this design reports it through registers read over a
   JTAG-AXI master. The three QSFP cage LEDs are a coarse supplement, not the primary
   interface.

   Second, it has no board pin contract to reuse. Mac_validation_harness takes
   Arty_board_top.I/O as its interface because on the Arty the Hardcaml design IS the top
   level. Here it is not: it sits inside u50_10g_top.sv alongside the AMD PCS/GT IP,
   encrypted primitives, clock buffers, JTAG-AXI master, and ILA. So this module's ports
   are an internal boundary, and the XDC constrains the SystemVerilog top.

   The RX path runs even though this is the TX harness. m_axis_rx_tready_o is held high so
   the egress drains rather than backing up, which costs nothing and makes the RX counter
   bank at 0x180 a live readout of whatever the peer is sending. It is a useful signal
   that the link is bidirectional before rung 2 exists.

   This file was heavily edited by AI, as I find no use in wasting away at writing
   validation harnesses myself. If you have problems with this, bite me.
*)

open! Core
open! Hardcaml
open! Signal
module Mac = Mac_10g_of_hardcaml.Mac_10g_top
module Map = Mac_10g_of_hardcaml.Mac_10g_register_map

module I = struct
  type 'a t =
    { (* All three clocks are supplied by the wrapper. tx_clock_i and rx_clock_i are
         expected to be the same PCS tx_mii_clk net; see plan section 9.1. The MAC imposes
         no relationship between them either way. *)
      tx_clock_i : 'a
    ; rx_clock_i : 'a
    ; axi_clock_i : 'a
    ; axi_reset_i : 'a
    ; (* Asynchronous external reset, synchronized per domain below. *)
      external_reset_i : 'a
    ; (* XGMII receive from the PCS. *)
      xgmii_rxd_i : 'a [@bits 64]
    ; xgmii_rxc_i : 'a [@bits 8]
    ; (* Link-stack status. Gate the datapath on these rather than free-running: the GT
         reference clock comes from the on-board SI5394, and if it is not locked the GT
         never leaves reset. See plan section 2.2. *)
      si5394_pll_lock_i : 'a
    ; pcs_tx_reset_done_i : 'a
    ; pcs_rx_reset_done_i : 'a
    ; pcs_rx_block_lock_i : 'a
    ; pcs_local_fault_i : 'a
    ; pcs_remote_fault_i : 'a
    ; (* AXI4-Lite control plane, driven by the JTAG-AXI master. *)
      s_axi_awaddr_i : 'a [@bits 12]
    ; s_axi_awvalid_i : 'a
    ; s_axi_wdata_i : 'a [@bits 32]
    ; s_axi_wstrb_i : 'a [@bits 4]
    ; s_axi_wvalid_i : 'a
    ; s_axi_bready_i : 'a
    ; s_axi_araddr_i : 'a [@bits 12]
    ; s_axi_arvalid_i : 'a
    ; s_axi_rready_i : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { (* XGMII transmit to the PCS. *)
      xgmii_txd_o : 'a [@bits 64]
    ; xgmii_txc_o : 'a [@bits 8]
    ; (* AXI4-Lite control plane. *)
      s_axi_awready_o : 'a
    ; s_axi_wready_o : 'a
    ; s_axi_bresp_o : 'a [@bits 2]
    ; s_axi_bvalid_o : 'a
    ; s_axi_arready_o : 'a
    ; s_axi_rdata_o : 'a [@bits 32]
    ; s_axi_rresp_o : 'a [@bits 2]
    ; s_axi_rvalid_o : 'a
    ; irq_o : 'a
    ; (* QSFP28 cage 0 LEDs; see plan section 10.1. False-pathed in the board XDC. *)
      qsfp_status_led_g_o : 'a
    ; qsfp_status_led_y_o : 'a
    ; qsfp_activity_led_o : 'a
    ; (* ILA probes; see plan section 10.2. *)
      source_state_o : 'a [@bits 2]
    ; source_sequence_o : 'a [@bits 32]
    ; source_tvalid_o : 'a
    ; source_tready_o : 'a
    ; frame_pulse_o : 'a
    ; xgmii_start_pulse_o : 'a
    ; keep : 'a
    }
  [@@deriving hardcaml]
end

let create
  ?interval_cycles
  ?settle_cycles
  ?max_supported_frame_length
  (scope : Scope.t)
  (i : _ I.t)
  : _ O.t
  =
  let ( -- ) = Scope.naming scope in
  (* Per-domain reset synchronizers off the raw asynchronous external reset. *)
  let tx_reset =
    U50_scaffolding.reset_sync ~clock:i.tx_clock_i ~async_rst:i.external_reset_i
    -- "tx_reset"
  in
  let rx_reset =
    U50_scaffolding.reset_sync ~clock:i.rx_clock_i ~async_rst:i.external_reset_i
    -- "rx_reset"
  in
  let tx_spec = Reg_spec.create ~clock:i.tx_clock_i ~clear:tx_reset () in
  let rx_spec = Reg_spec.create ~clock:i.rx_clock_i ~clear:rx_reset () in
  (* Everything that must be true before the datapath may run. *)
  let link_up =
    (i.si5394_pll_lock_i &: i.pcs_tx_reset_done_i &: i.pcs_rx_reset_done_i) -- "link_up"
  in
  let startup =
    U50_scaffolding.startup
      ?settle_cycles
      ~spec:tx_spec
      ~external_reset:tx_reset
      ~link_up
      ()
  in
  (* wire-back stub breaks the source <-> MAC instantiation cycle, the same pattern
     mac_top.ml and the Arty harnesses use. *)
  let wire_tready = Signal.wire 1 -- "wire_tready" in
  let source =
    U50_frame_source.hierarchical
      ?interval_cycles
      scope
      { U50_frame_source.I.clock_i = i.tx_clock_i
      ; reset_i = startup.released
      ; enable_i = vdd
      ; start_i = startup.settled
      ; s_axis_tready_i = wire_tready
      }
  in
  let mac =
    Mac.hierarchical
      ?max_supported_frame_length
      scope
      { Mac.I.tx_clock_i = i.tx_clock_i
      ; tx_reset_i = startup.released
      ; s_axis_tx_tdata_i = source.s_axis_tdata_o
      ; s_axis_tx_tkeep_i = source.s_axis_tkeep_o
      ; s_axis_tx_tvalid_i = source.s_axis_tvalid_o
      ; s_axis_tx_tlast_i = source.s_axis_tlast_o
      ; s_axis_tx_tuser_i = source.s_axis_tuser_o
      ; rx_clock_i = i.rx_clock_i
      ; rx_reset_i = rx_reset
      ; xgmii_rxd_i = i.xgmii_rxd_i
      ; xgmii_rxc_i = i.xgmii_rxc_i
      ; (* Drain RX unconditionally: no consumer here, and a backed-up egress would show
           up as overflow counts that say nothing about the TX path. *)
        m_axis_rx_tready_i = vdd
      ; axi_clock_i = i.axi_clock_i
      ; axi_reset_i = i.axi_reset_i
      ; s_axi_awaddr_i = i.s_axi_awaddr_i
      ; s_axi_awvalid_i = i.s_axi_awvalid_i
      ; s_axi_wdata_i = i.s_axi_wdata_i
      ; s_axi_wstrb_i = i.s_axi_wstrb_i
      ; s_axi_wvalid_i = i.s_axi_wvalid_i
      ; s_axi_bready_i = i.s_axi_bready_i
      ; s_axi_araddr_i = i.s_axi_araddr_i
      ; s_axi_arvalid_i = i.s_axi_arvalid_i
      ; s_axi_rready_i = i.s_axi_rready_i
      }
  in
  Signal.(wire_tready <-- mac.s_axis_tx_tready_o);
  (* Debug-only start-of-frame observation, per plan section 7: XGMII /S/ is the control
     character 0xfb in lane 0. This must never gate transmission -- the formatter decides
     when to start, and deriving control from its output would invert that. *)
  let xgmii_start_pulse =
    (select mac.xgmii_txc_o ~high:0 ~low:0
     ==:. 1
     &: (select mac.xgmii_txd_o ~high:7 ~low:0 ==:. 0xfb))
    -- "xgmii_start_pulse"
  in
  (* LED map, plan section 10.1. Synchronize the PCS status levels into the TX domain
     before using them; they are quasi-static, so a 2-FF level sync is correct. *)
  let block_lock = U50_scaffolding.sync2 ~spec:tx_spec i.pcs_rx_block_lock_i in
  let fault =
    U50_scaffolding.sync2 ~spec:tx_spec (i.pcs_local_fault_i |: i.pcs_remote_fault_i)
  in
  (* Yellow covers every reason the link stack is not healthy, including the SI5394 case
     that otherwise presents as an unexplained GT failure. MAC-side underflow is
     deliberately not folded in here: it is a sticky bit in STATUS (0x00c) and a counter
     at 0x120, both of which say far more than one LED can. *)
  let led_yellow =
    (fault |: ~:(U50_scaffolding.sync2 ~spec:tx_spec link_up)) -- "led_y"
  in
  let led_activity =
    U50_scaffolding.led_stretch ~spec:tx_spec source.frame_pulse_o -- "led_activity"
  in
  (* Anti-prune OR-reduction, per the convention in CLAUDE.md. Mac_10g_top exposes no
     [keep] of its own -- that convention belongs to the MII library -- so only the
     harness-local debug signals are collected here. *)
  let keep =
    [ source.keep; xgmii_start_pulse; block_lock; led_yellow; led_activity ]
    |> reduce ~f:( |: )
  in
  { O.xgmii_txd_o = mac.xgmii_txd_o
  ; xgmii_txc_o = mac.xgmii_txc_o
  ; s_axi_awready_o = mac.s_axi_awready_o
  ; s_axi_wready_o = mac.s_axi_wready_o
  ; s_axi_bresp_o = mac.s_axi_bresp_o
  ; s_axi_bvalid_o = mac.s_axi_bvalid_o
  ; s_axi_arready_o = mac.s_axi_arready_o
  ; s_axi_rdata_o = mac.s_axi_rdata_o
  ; s_axi_rresp_o = mac.s_axi_rresp_o
  ; s_axi_rvalid_o = mac.s_axi_rvalid_o
  ; irq_o = mac.irq_o
  ; qsfp_status_led_g_o = block_lock
  ; qsfp_status_led_y_o = led_yellow
  ; qsfp_activity_led_o = led_activity
  ; source_state_o = source.state_o
  ; source_sequence_o = source.sequence_o
  ; source_tvalid_o = source.s_axis_tvalid_o
  ; source_tready_o = mac.s_axis_tx_tready_o
  ; frame_pulse_o = source.frame_pulse_o
  ; xgmii_start_pulse_o = xgmii_start_pulse
  ; keep
  }
;;
