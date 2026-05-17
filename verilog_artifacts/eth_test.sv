// Top-level test: RX + TX Ethernet via eth_mac_tx (combined Hardcaml MAC).
//
// RX side: receives frames, pops one byte per second from the AXI-S FIFO,
// displays lower 4 bits on LEDs.
//
// TX side: after reset the sequencer fills the TX FIFO with 38 bytes of
// incrementing payload (0x00..0x25), then pulses tx_start.  The MAC sends
// preamble → SFD → dst_mac (ff:ff:ff:ff:ff:ff) → src_mac (02:00:00:00:00:01)
// → ethertype (0x9999) → payload → FCS automatically.  Sniff with:
//   tcpdump -i <iface> ether proto 0x9999
//
// All logic runs on eth_tx_clk (25 MHz from PHY) so TX data is registered on
// the same clock the PHY samples.  eth_rx_clk is kept as a port for XDC only.
//
// Debug RGB LED 0:
//   led0_r — rst_eth     : ON  = MAC is in reset (bad)
//   led0_g — pulse_toggle: blinks 0.5 Hz when eth_rx_clk is running
//   led0_b — rx_dv_seen  : ON  = PHY asserted rx_dv at least once

module eth_test #(
  parameter int ETH_CLK_FREQ = 25_000_000  // match negotiated MII speed
) (
  input  logic       clk,          // 100 MHz system clock (E3)
  input  logic       rst,          // sw[1] active-high reset
  input  logic       en,           // sw[0] enable MAC

  // DP83848 MII RX
  input  logic       eth_rx_clk,  // 25 MHz @ 100 Mbps / 2.5 MHz @ 10 Mbps
  input  logic       eth_rx_dv,
  input  logic [3:0] eth_rxd,
  input  logic       eth_rxerr,

  // DP83848 MII TX
  input  logic       eth_tx_clk,  // 25 MHz TX clock from PHY (timing reference)
  output logic [3:0] eth_txd,
  output logic       eth_tx_en,

  // PHY control
  output logic       eth_rstn,    // active-low PHY reset
  output logic       eth_ref_clk, // 25 MHz ref clock to PHY XI pin

  // Arty A7 green LEDs [3:0] — payload byte nibble
  output logic [3:0] led,

  // RGB LED 0 — debug
  output logic       led0_r,      // rst_eth
  output logic       led0_g,      // pulse_toggle (0.5 Hz blink)
  output logic       led0_b,      // sticky rx_dv seen

  // RGB LED 1 — FIFO debug
  output logic       led1_g,      // sticky: m_tvalid ever high
  output logic       led1_b,      // sticky: byte ever popped

  // RGB LED 2 — FSM state milestones (sticky)
  output logic       led2_b,      // ever entered PREAMBLE
  output logic       led2_r,      // ever entered DST_MAC
  output logic       led2_g,      // ever entered PAYLOAD

  // RGB LED 3 — CRC result of last completed frame
  output logic       led3_g,      // last frame CRC good
  output logic       led3_r       // last frame CRC bad
);

  // -------------------------------------------------------------------------
  // 25 MHz reference clock to PHY.
  // DP83848 in MII mode wants 25 MHz on XI.  Divide 100 MHz sys clock by 4.
  // -------------------------------------------------------------------------
  logic [1:0] ref_div;
  always_ff @(posedge clk) ref_div <= ref_div + 1;
  assign eth_ref_clk = ref_div[1];

  // -------------------------------------------------------------------------
  // PHY reset: hold eth_rstn low for ~1.3 ms after FPGA startup, then release.
  // -------------------------------------------------------------------------
  logic [16:0] phy_rst_cnt;
  always_ff @(posedge clk) begin
    if (rst) phy_rst_cnt <= '0;
    else if (!phy_rst_cnt[16]) phy_rst_cnt <= phy_rst_cnt + 1;
  end
  assign eth_rstn = phy_rst_cnt[16];

  // -------------------------------------------------------------------------
  // Reset synchroniser into eth_tx_clk domain
  // -------------------------------------------------------------------------
  logic [1:0] rst_sync;
  always_ff @(posedge eth_tx_clk or posedge rst) begin
    if (rst) rst_sync <= 2'b11;
    else     rst_sync <= {rst_sync[0], 1'b0};
  end
  wire rst_eth = rst_sync[1];

  // -------------------------------------------------------------------------
  // TX sequencer — waits ~3 s for PHY autoneg, then fills FIFO and fires tx_start
  //
  // Every rst toggle resets eth_rstn (PHY hard-reset).  The DP83848 needs
  // ~165 ms to init plus up to ~2 s for autoneg.  Without the wait the
  // one-shot frame fires before the link is up and never reaches the wire.
  // At 25 MHz: 3 s = 75_000_000 cycles → 27-bit counter.
  // -------------------------------------------------------------------------
  localparam int PHY_WAIT_CYCLES = 75_000_000;  // 3 s @ 25 MHz

  logic [26:0] phy_wait_cnt;
  logic        phy_ready;

  logic [5:0] load_cnt;   // counts 0..45
  logic       loading;
  logic [7:0] seq_tdata;
  logic       seq_tvalid;
  logic       seq_tstart;
  logic       mac_s_axis_tready;  // wired from MAC output

  assign seq_tdata  = {2'b0, load_cnt};  // 0x00, 0x01, ... 0x2D
  assign seq_tvalid = loading && phy_ready;  // don't write FIFO during PHY wait

  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) begin
      phy_wait_cnt <= 27'd0;
      phy_ready    <= 1'b0;
      load_cnt     <= 6'd0;
      loading      <= 1'b1;
      seq_tstart   <= 1'b0;
    end else begin
      seq_tstart <= 1'b0;

      // Phase 1: wait for PHY to come up
      if (!phy_ready) begin
        if (phy_wait_cnt == PHY_WAIT_CYCLES - 1)
          phy_ready <= 1'b1;
        else
          phy_wait_cnt <= phy_wait_cnt + 27'd1;

      // Phase 2: fill FIFO then kick TX FSM
      end else if (loading && mac_s_axis_tready) begin
        if (load_cnt == 6'd45) begin
          loading    <= 1'b0;
          seq_tstart <= 1'b1;
        end else begin
          load_cnt <= load_cnt + 6'd1;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // TX debug sticky latches — drives led[3:0] (orange LEDs)
  //   led[3] = loading (live: ON while filling FIFO, clears when done)
  //   led[2] = tx_en_seen  (sticky: eth_tx_en ever went high → MAC actually serialised)
  //   led[1] = tx_start_seen (sticky: tx_start pulsed → sequencer completed)
  //   led[0] = tx_load_done  (sticky: all 38 bytes accepted by FIFO)
  // -------------------------------------------------------------------------
  logic tx_load_done, tx_start_seen, tx_en_seen;

  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) begin
      tx_load_done  <= 1'b0;
      tx_start_seen <= 1'b0;
      tx_en_seen    <= 1'b0;
    end else begin
      if (seq_tstart) begin
        tx_load_done  <= 1'b1;
        tx_start_seen <= 1'b1;
      end
      if (eth_tx_en) tx_en_seen <= 1'b1;
    end
  end

  // -------------------------------------------------------------------------
  // Combined RX + TX MAC
  // -------------------------------------------------------------------------
  logic [7:0] m_tdata;
  logic        m_tvalid, m_tready, m_tlast, m_tkeep, m_tuser, mac_keep_nc;
  logic        mac_in_preamble, mac_in_dst_mac, mac_in_payload;
  logic        mac_frame_crc_ok, mac_frame_done;

  eth_mac_tx u_mac (
    // clocking / reset
    .clock         (eth_tx_clk),
    .reset         (rst_eth),
    .en            (en),

    // MII RX inputs
    .rx_data       (eth_rxd),
    .rx_dv         (eth_rx_dv),
    .rx_er         (eth_rxerr),

    // AXI-S RX output (downstream consumer)
    .m_axis_tdata  (m_tdata),
    .m_axis_tvalid (m_tvalid),
    .m_axis_tready (m_tready),
    .m_axis_tlast  (m_tlast),
    .m_axis_tkeep  (m_tkeep),
    .m_axis_tuser  (m_tuser),

    // RX FSM debug
    .in_preamble   (mac_in_preamble),
    .in_dst_mac    (mac_in_dst_mac),
    .in_payload    (mac_in_payload),
    .frame_crc_ok  (mac_frame_crc_ok),
    .frame_done    (mac_frame_done),

    // MII TX outputs
    .tx_d          (eth_txd),
    .tx_en         (eth_tx_en),

    // AXI-S TX input (from sequencer)
    .s_axis_tdata  (seq_tdata),
    .s_axis_tvalid (seq_tvalid),
    .s_axis_tuser  (1'b0),
    .tx_start      (seq_tstart),
    .s_axis_tready (mac_s_axis_tready),

    .keep          (mac_keep_nc)
  );

  // -------------------------------------------------------------------------
  // 1-second pulse (in eth_tx_clk domain)
  // -------------------------------------------------------------------------
  logic pulse;
  second_pulse #(.CLK_FREQ(ETH_CLK_FREQ)) u_pulse (
    .clk  (eth_tx_clk),
    .rst  (rst_eth),
    .pulse(pulse)
  );

  // -------------------------------------------------------------------------
  // Pop one RX byte per second and show lower nibble on LEDs
  // -------------------------------------------------------------------------
  assign m_tready = pulse & m_tvalid;

  // led[3] = phy_ready: OFF for ~3 s after reset (waiting for autoneg), then ON
  assign led = {phy_ready, tx_en_seen, tx_start_seen, tx_load_done};

  // -------------------------------------------------------------------------
  // Debug outputs
  // -------------------------------------------------------------------------
  assign led0_r = rst_eth;

  logic pulse_toggle;
  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) pulse_toggle <= 1'b0;
    else if (pulse) pulse_toggle <= ~pulse_toggle;
  end
  assign led0_g = pulse_toggle;

  logic rx_dv_seen;
  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) rx_dv_seen <= 1'b0;
    else if (eth_rx_dv) rx_dv_seen <= 1'b1;
  end
  assign led0_b = rx_dv_seen;

  logic tvalid_seen;
  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) tvalid_seen <= 1'b0;
    else if (m_tvalid) tvalid_seen <= 1'b1;
  end
  assign led1_g = tvalid_seen;

  logic pop_seen;
  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) pop_seen <= 1'b0;
    else if (pulse & m_tvalid) pop_seen <= 1'b1;
  end
  assign led1_b = pop_seen;

  logic ever_preamble, ever_dst_mac, ever_payload;
  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) begin
      ever_preamble <= 1'b0;
      ever_dst_mac  <= 1'b0;
      ever_payload  <= 1'b0;
    end else begin
      if (mac_in_preamble) ever_preamble <= 1'b1;
      if (mac_in_dst_mac)  ever_dst_mac  <= 1'b1;
      if (mac_in_payload)  ever_payload  <= 1'b1;
    end
  end
  assign led2_b = ever_preamble;
  assign led2_r = ever_dst_mac;
  assign led2_g = ever_payload;

  logic frame_ever_done, crc_ok_latched;
  always_ff @(posedge eth_tx_clk) begin
    if (rst_eth) begin
      frame_ever_done <= 1'b0;
      crc_ok_latched  <= 1'b0;
    end else if (mac_frame_done) begin
      frame_ever_done <= 1'b1;
      crc_ok_latched  <= mac_frame_crc_ok;
    end
  end
  assign led3_g = frame_ever_done &  crc_ok_latched;
  assign led3_r = frame_ever_done & ~crc_ok_latched;

endmodule
