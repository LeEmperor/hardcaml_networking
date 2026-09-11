# ---------------------------------------------------------------------------
# u50_10g.xdc -- Alveo U50 board constraints for the 10G MAC validation design.
#
# Pins and frequencies below are taken from the installed board file:
#   ~/tools/xilinx/board_files/au50/production/1.3/{board.xml,part0_pins.xml}
#   xilinx.com:au50:1.3   part xcu50-fsvh2104-2-e
#
# This file is the BOARD layer. The MAC's own CDC budgets live in
# synthesis/constraints/mac_10g_cdc_scoped.xdc, read scoped to -ref mac_10g_cdc.
# Keep them separate: this file is U50-specific and disposable, that one travels
# with the MAC to any integration.
# ---------------------------------------------------------------------------

# --- GT reference clock: SYNCE_CLK, 161.132812 MHz ------------------------
# board.xml component qsfp_161mhz, "QSFP Differential Clock 0", labelled
# SYNCE_CLK on the board. Its preferred_ip is xxv_ethernet -- i.e. this is the
# clock the 10G/25G Ethernet Subsystem expects. Sourced from the on-board
# SI5394; see the SI5394 status section at the bottom.
set_property -dict {PACKAGE_PIN N36 IOSTANDARD LVDS} [get_ports qsfp_refclk_p]
set_property -dict {PACKAGE_PIN N37 IOSTANDARD LVDS} [get_ports qsfp_refclk_n]
create_clock -period 6.206 -name qsfp_refclk [get_ports qsfp_refclk_p]

# --- Free-running init clock: SYSCLK2 / cmc_clk, 100 MHz ------------------
# board.xml component cmc_clk. A real on-board LVDS oscillator input, free
# running from power-on and independent of the GT -- which is exactly what the
# PCS/GT reset sequence needs. We are not instantiating CMS, so it is unused
# and available. (SYSCLK3 / hbm_clk at BB18/BC18 is an identical 100 MHz
# alternative; SYSCLK2 sits in the same I/O region as the QSFP LEDs and SI5394
# status pins, keeping all the slow management logic together.)
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVDS} [get_ports sysclk2_p]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVDS} [get_ports sysclk2_n]
create_clock -period 10.000 -name sysclk2 [get_ports sysclk2_p]

# --- Clock relationships --------------------------------------------------
# sysclk2 drives PCS/GT init and the AXI4-Lite control plane. The PCS-generated
# 156.25 MHz tx_mii_clk drives the whole XGMII datapath. They are unrelated
# oscillators.
#
# This is safe to declare asynchronous ONLY because the MAC's own AXI<->datapath
# crossings are separately bounded by mac_10g_cdc_scoped.xdc with
# set_max_delay -datapath_only and set_bus_skew. Without that file this line
# would silently unconstrain every mailbox crossing in the design.
set_clock_groups -asynchronous \
    -group [get_clocks sysclk2] \
    -group [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *tx_mii_clk}]]

# Global uncertainty. Matches the 0.100 ns used for the recorded post-route
# result in docs/mac_10g_integration.md, so board numbers stay comparable to
# the out-of-context ones.
set_clock_uncertainty 0.100 [all_clocks]

# --- QSFP28 cage 0 status LEDs -------------------------------------------
# The U50's only user-drivable indicators. LVCMOS18, drive 8, per part0_pins.
# Suggested map, following docs/mac_10g_u50_tx_validation_plan.md section 10.1:
#   green    PCS RX block lock
#   yellow   PCS/GT fault or MAC underflow sticky
#   activity stretched pulse per transmitted frame
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports qsfp0_status_led_g]
set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports qsfp0_status_led_y]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports qsfp0_activity_led]
set_false_path -to [get_ports {qsfp0_status_led_g qsfp0_status_led_y qsfp0_activity_led}]

# --- SI5394 status --------------------------------------------------------
# The QSFP reference clock comes from the on-board SI5394. If it is not locked,
# SYNCE_CLK is not running and the GT will never come out of reset -- a failure
# that looks identical to a GT/PCS misconfiguration. Bring these in and expose
# them (LED or AXI status bit) BEFORE debugging anything downstream.
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS18} [get_ports si5394_pll_lock]
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS18} [get_ports si5394_in_los]
set_false_path -from [get_ports {si5394_pll_lock si5394_in_los}]

# --- QSFP28 cage 0, lane 0 serial ----------------------------------------
# Do NOT add PACKAGE_PIN constraints for these. The serial pins follow from the
# GT quad/channel selected in the Ethernet IP; constraining them here conflicts
# with the IP's own placement. Listed only so the intended lane is verifiable
# against the board file:
#
#   QSFP28_0_TX_P0/N0  D42 / D43
#   QSFP28_0_RX_P0/N0  J45 / J46
#
# Lanes 1..3 (C40/C41, B42/B43, A40/A41 TX) are unused at 1x10G.
#
# Note the board file defines serial lanes for QSFP28_0 only -- the U50 has a
# single physical QSFP28 cage. QSFP28_1_* LED pins exist but there is no second
# cage, so "which lane" is settled: cage 0, lane 0.
