(*
  Module: Eth_test_top
  Board-level Ethernet test design for the Arty A7-100T.
  Uses Board_top.I/O as its pin interface and instantiates the full MAC stack.

  Instantiated submodules:
    Mac_top       — full-duplex MII MAC, clocked from eth_rx_clk
    Second_pulse  — 1 Hz heartbeat LED, clocked from clk100mhz

  btn[0] is used as an active-high synchronous reset for both clock domains.
  btn[3] triggers a TX frame once the sequencer has saturated.

  RX frames are drained immediately (m_axis_tready = vdd).
  TX: sequencer_counter fills the TX FIFO at 1 Hz after the PHY comes out of reset,
      then saturates and holds. btn[3] (active-high) fires tx_start after seq_done.
*)

open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported Eth Test Top ==="

module I = Board_top.I
module O = Board_top.O

module I_Wires = struct
  type 'a t = {
    sequencer_data : 'a [@bits 8];
  } [@@deriving hardcaml]
end

module I_Regs = struct
  type 'a t = {
    sequencer_on : 'a;
  } [@@deriving hardcaml]
end

let create
  (scope : Scope.t)
  (i : _ I.t)
  : _ O.t
  =
  let open Always in
  let open Variable in

  let rst : Signal.t = Signal.bit i.I.btn ~pos:0 in (* btn[0]: active-high synchronous reset *)
  let en  : Signal.t = Signal.bit i.I.sw  ~pos:0 in (* sw[0]: active-high enable *)

  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;

  let spec100 = Reg_spec.create ~clock:i.I.clk100mhz ~clear:rst () in

  let clk_div_inst = Clk_div.create scope {
    Clk_div.I.src_clk = i.I.clk100mhz;
    rst;
    en;
  } in

  let _spec25 = Reg_spec.create ~clock:clk_div_inst.dst_clk ~clear:rst () in

  let i_regs = I_Regs.Of_always.reg ~enable:vdd spec100 in
  I_Regs.Of_always.apply_names ~prefix:"reg_" ~naming_op:(Scope.naming scope) i_regs;

  let heartbeat_inst = Second_pulse.create scope {
    Second_pulse.I.clk = i.I.clk100mhz;
    rst;
  } in

  (* hold the PHY rst high for ~0.66 ms after board power-on *)
  let phy_rst_cnt : Signal.t =
    Signal.reg_fb spec100 ~enable:vdd ~width:17
      ~f:(fun q ->
          mux2 rst (zero 17)
            (mux2 (msb q) q (q +:. 1)))
  in

  (* sequencer: counts up one beat per heartbeat pulse after PHY is ready.
     saturates when MSB flips (~128 pulses = ~2 min) and holds forever. *)
  let phy_ready = Signal.msb phy_rst_cnt -- "phy_ready" in

  let sequencer_counter : Signal.t =
    Signal.reg_fb spec100 ~width:8 ~enable:heartbeat_inst.pulse
      ~f:(fun q ->
          mux2 rst (zero 8)
            (mux2 phy_ready
              (mux2 (msb q) q (q +:. 1))
              (zero 8)))
    -- "sequencer_counter"
  in

  let seq_done = Signal.msb sequencer_counter -- "seq_done" in
  let btn3     = Signal.bit i.I.btn ~pos:3    -- "btn3" in

  let mac_inst = Mac_top.create scope {
    Mac_top.I.clock       = i.I.eth_rx_clk;
    reset                 = rst;
    en                    = vdd;
    rx_dv                 = i.I.eth_rx_dv;
    rx_er                 = i.I.eth_rxerr;
    rx_data               = i.I.eth_rxd;
    m_axis_tready         = vdd;
    s_axis_tdata          = sequencer_counter;
    s_axis_tvalid         = heartbeat_inst.pulse &: phy_ready &: ~:seq_done;
    s_axis_tuser          = gnd;
    tx_start              = seq_done &: btn3;
  } in

  compile [
    i_wires.sequencer_data <-- sequencer_counter;
    i_regs.sequencer_on    <-- seq_done;
  ];

  ignore heartbeat_inst.keep;
  ignore mac_inst.keep;

  { O.
    (* LED3: sequencer saturated  LED2: PHY out of reset
       LED1: RX in payload        LED0: last RX frame CRC ok *)
    led = concat_msb [
      seq_done;
      phy_ready;
      mac_inst.in_payload;
      mac_inst.frame_crc_ok;
    ];

    led0_r = heartbeat_inst.pulse;
    led0_g = gnd;
    led0_b = gnd;

    led1_r = gnd;
    led1_g = gnd;
    led1_b = gnd;

    led2_r = gnd;
    led2_g = gnd;
    led2_b = gnd;

    led3_r = gnd;
    led3_g = gnd;
    led3_b = gnd;

    uart_rxd_out = vdd;

    eth_mdc      = gnd;
    eth_rstn     = Signal.msb phy_rst_cnt;
    eth_ref_clk  = clk_div_inst.dst_clk;
    eth_tx_en    = mac_inst.tx_en;
    eth_txd      = mac_inst.tx_d;
  }
;;
