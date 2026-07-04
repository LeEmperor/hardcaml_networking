# Constraints File: "unified_tx_rx.xdc" 
# Author: Bohdan Purtel
# 
# Constraints for validation for unified TX/RX on Ethernet MII MAC written on Arty A7 100T.
#
# Port names meant to align with Board_top.I/O fields exactly.
#
## DP83848x PHY, MII interface, 100 Mbps (eth_rx_clk = 25 MHz).

## ── Clocks ────────────────────────────────────────────────────────────────

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk100mhz]
create_clock -period 10.000 -name clk100mhz -waveform {0.000 5.000} [get_ports clk100mhz]

set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS33} [get_ports eth_rx_clk]
create_clock -period 40.000 -name eth_rx_clk -waveform {0.000 20.000} [get_ports eth_rx_clk]

set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports eth_tx_clk]
create_clock -period 40.000 -name eth_tx_clk -waveform {0.000 20.000} [get_ports eth_tx_clk]

## ── Slide switches ────────────────────────────────────────────────────────

set_property -dict {PACKAGE_PIN A8  IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]

## ── Push buttons ──────────────────────────────────────────────────────────
## btn[0] = active-high synchronous reset for the design

set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]

## ── Plain LEDs ────────────────────────────────────────────────────────────
## led[0] = 1 Hz heartbeat  led[1] = last-frame CRC ok  led[2] = in payload

set_property -dict {PACKAGE_PIN H5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J5  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## ── RGB LEDs ──────────────────────────────────────────────────────────────
## led0: green while a frame payload is being received

set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports led0_r]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports led0_g]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports led0_b]

set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports led1_r]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports led1_g]
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports led1_b]

set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports led2_r]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports led2_g]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports led2_b]

set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33} [get_ports led3_r]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports led3_g]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports led3_b]

## ── USB-UART ──────────────────────────────────────────────────────────────

set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_rxd_out]
set_property -dict {PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports uart_txd_in]

## ── Ethernet PHY (DP83848x) ───────────────────────────────────────────────

set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports eth_col]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports eth_crs]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports eth_rx_dv]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[0]}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[1]}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[2]}]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[3]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports eth_rxerr]

set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports eth_mdc]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports eth_rstn]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports eth_ref_clk]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports eth_tx_en]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {eth_txd[2]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {eth_txd[3]}]

## ── Timing exceptions ─────────────────────────────────────────────────────

# sw and btn are slow switch/button inputs
set_false_path -from [get_ports {sw[*] btn[*]}]

# eth_ref_clk is a generated clock output; no input timing constraint needed
set_false_path -to [get_ports eth_ref_clk]

# All three clocks are asynchronous to each other.
# clk100mhz drives second_pulse (LEDs only); eth_rx_clk and eth_tx_clk drive the MAC.
set_clock_groups -asynchronous \
    -group [get_clocks clk100mhz] \
    -group [get_clocks eth_rx_clk] \
    -group [get_clocks eth_tx_clk]

## ── Bitstream config ──────────────────────────────────────────────────────

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
