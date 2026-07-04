(*
  Module: Mac_top_validation_harness
  Board-level validation harness for the full-duplex MII MAC on the Arty A7-100T.

  This is the *active* top used for hardware bring-up. It lives outside lib/ on
  purpose: lib/ holds the reusable MAC; this dir holds the throwaway scaffolding
  that drives it on real silicon. It reuses Arty_board_top.I/O (the canonical pin
  contract in lib/common) as its port interface and supplies its own [create].

  Structure
  ─────────
    clk100mhz domain:
      Clk_div       → eth_ref_clk (25 MHz to PHY XI)
      phy_rst_cnt   → eth_rstn    (hold PHY in reset ~0.66 ms after power-on)
      Second_pulse  → heartbeat   → led0 toggle (0.5 Hz, eye-visible)

    eth_tx_clk domain (MAC + everything it touches — TX data is registered on the
    same edge the PHY samples, per the DP83848 MII TX timing):
      sequencer     → fills TX FIFO with incrementing bytes after PHY is ready,
                      then trips tx_start (manual: btn[3])
      Mac_top       → RX (PHY→AXI-S) + TX (AXI-S→PHY)
      Second_pulse  → 1 Hz RX drain (m_axis_tready)
      Regs (stub)   → AXI4-Lite status/control block, taps MAC status for readback

  Controls: btn[0] = active-high sync reset, sw[0] = enable, btn[3] = fire TX.

  LED map:
    led[3:0]  lower nibble of last drained RX byte
    led0_r    heartbeat toggle
    led2_g    last-frame CRC ok        led2_b  in_payload (RX active)
    led3_r    last-frame CRC bad
*)

open! Core
open! Hardcaml
open! Mii_of_hardcaml   (* Mac_top lives in the wrapped mii library *)
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC Validation Harness ==="

(* Reuse the canonical board pin contract as the harness port interface. *)
module I = Arty_board_top.I
module O = Arty_board_top.O

let create
  (scope : Scope.t)
  (i : _ I.t)
  : _ O.t
  =
  let rst = Signal.bit i.I.btn ~pos:0 -- "rst" in  (* btn[0]: active-high sync reset *)
  let en  = Signal.bit i.I.sw  ~pos:0 -- "en"  in  (* sw[0]:  active-high enable      *)

  let spec100 = Reg_spec.create ~clock:i.I.clk100mhz ~clear:rst () in
  let spec_tx = Reg_spec.create ~clock:i.I.eth_tx_clk ~clear:rst () in

  (* ── 25 MHz reference clock to the PHY ───────────────────────────────────── *)
  let clk_div_inst = Clk_div.create scope {
    Clk_div.I.src_clk = i.I.clk100mhz;
    rst;
    en;
  } in

  (* ── PHY hard reset: hold eth_rstn low ~0.66 ms, then release and hold high ─ *)
  let phy_rst_cnt =
    Signal.reg_fb spec100 ~enable:vdd ~width:17
      ~f:(fun q -> mux2 rst (zero 17) (mux2 (msb q) q (q +:. 1)))
    -- "phy_rst_cnt"
  in
  let phy_ready = Signal.msb phy_rst_cnt -- "phy_ready" in

  (* ── Heartbeat: 1 Hz pulse toggled into a 0.5 Hz square wave on led0 ──────── *)
  let heartbeat = Second_pulse.create scope {
    Second_pulse.I.clk = i.I.clk100mhz;
    rst;
  } in
  let heartbeat_toggle =
    Signal.reg_fb spec100 ~enable:heartbeat.pulse ~width:1 ~f:(fun q -> ~:q)
    -- "heartbeat_toggle"
  in

  (* ── TX sequencer ────────────────────────────────────────────────────────── *)
  (* Fills the TX FIFO with an incrementing byte per heartbeat pulse once the PHY
     is out of reset, saturates when the MSB flips, then holds. btn[3] fires the
     one-shot tx_start after saturation.
     TODO: replace the ~0.66 ms phy_ready gate with a ~3 s autoneg-settle wait
     (75_000_000 cycles @ 25 MHz), and auto-fire tx_start on seq_done rising edge
     — see the reference eth_test.sv for the fuller sequencer. *)
  let sequencer_counter =
    Signal.reg_fb spec100 ~enable:heartbeat.pulse ~width:8
      ~f:(fun q ->
          mux2 rst (zero 8)
            (mux2 phy_ready (mux2 (msb q) q (q +:. 1)) (zero 8)))
    -- "sequencer_counter"
  in
  let seq_done = Signal.msb sequencer_counter -- "seq_done" in
  let btn3     = Signal.bit i.I.btn ~pos:3    -- "btn3" in

  (* ── RX drain: pop one byte per second, show low nibble on the plain LEDs ─── *)
  let rx_drain = Second_pulse.create ~clk_freq:25_000_000 scope {
    Second_pulse.I.clk = i.I.eth_tx_clk;
    rst;
  } in

  (* ── The MAC ─────────────────────────────────────────────────────────────── *)
  let mac_inst = Mac_top.create scope {
    Mac_top.I.clock = i.I.eth_tx_clk;
    reset           = rst;
    en;
    rx_dv           = i.I.eth_rx_dv;
    rx_er           = i.I.eth_rxerr;
    rx_data         = i.I.eth_rxd;
    m_axis_tready   = rx_drain.pulse;
    s_axis_tdata    = sequencer_counter;
    s_axis_tvalid   = heartbeat.pulse &: phy_ready &: ~:seq_done;
    s_axis_tuser    = gnd;
    tx_start        = seq_done &: btn3;
  } in

  (* ── Register block (STUB) ───────────────────────────────────────────────── *)
  (* AXI4-Lite slave tied off for now — no on-board master yet. It taps MAC
     status for eventual processor readback. When control feedback (soft_reset /
     tx_start_req) is wired back into the MAC, use the mac_top.ml wire-back
     pattern (Signal.wire stubs) to break the ordering/comb loop. *)
  let regs_inst = Mac_top_validation_harness_regs.create scope {
    Mac_top_validation_harness_regs.I.clock = i.I.eth_tx_clk;
    reset         = rst;
    s_axi_awaddr  = zero 4;
    s_axi_awvalid = gnd;
    s_axi_wdata   = zero 32;
    s_axi_wstrb   = zero 4;
    s_axi_wvalid  = gnd;
    s_axi_bready  = gnd;
    s_axi_araddr  = zero 4;
    s_axi_arvalid = gnd;
    s_axi_rready  = gnd;
    frame_done    = mac_inst.frame_done;
    frame_crc_ok  = mac_inst.frame_crc_ok;
    in_payload    = mac_inst.in_payload;
    tx_en         = mac_inst.tx_en;
    rx_dv         = i.I.eth_rx_dv;
  } in

  (* ── Last drained RX byte → led[3:0] ─────────────────────────────────────── *)
  let last_byte =
    Signal.reg spec_tx
      ~enable:(rx_drain.pulse &: mac_inst.m_axis_tvalid)
      mac_inst.m_axis_tdata
  in

  (* keep debug OR-reductions alive so synthesis doesn't prune the submodules *)
  ignore heartbeat.keep;
  ignore rx_drain.keep;
  ignore mac_inst.keep;
  ignore regs_inst.keep;

  { O.
    led = Signal.select last_byte ~high:3 ~low:0;

    led0_r = heartbeat_toggle;
    led0_g = gnd;
    led0_b = gnd;

    led1_r = gnd;
    led1_g = gnd;
    led1_b = gnd;

    led2_r = gnd;
    led2_g = mac_inst.frame_crc_ok;
    led2_b = mac_inst.in_payload;

    led3_r = mac_inst.frame_done &: ~:(mac_inst.frame_crc_ok);
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
