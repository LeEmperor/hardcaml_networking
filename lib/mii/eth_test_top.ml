(*
  Module: Eth_test_top
  Board-level Ethernet test design for the Arty A7-100T.
  Uses Board_top.I/O as its pin interface and instantiates the full MAC stack.

  Instantiated submodules:
    Mac_top       — full-duplex MII MAC, clocked from eth_rx_clk
    Second_pulse  — 1 Hz heartbeat LED, clocked from clk100mhz

  btn[0] is used as an active-high synchronous reset for both clock domains.

  RX frames are drained immediately (m_axis_tready = vdd).
  TX path is idle (s_axis_tvalid = gnd; tx_start = gnd).
  eth_ref_clk is stubbed to gnd — replace with a 25 MHz MMCM output via ODDR.
*)

open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported Eth Test Top ==="

module I = Board_top.I
module O = Board_top.O

let create (scope : Scope.t) (i : _ I.t) : _ O.t =
  let rst = select i.I.btn ~high:0 ~low:0 in   (* btn[0]: active-high synchronous reset *)

  let (mac : _ Mac_top.O.t) =
    Mac_top.create scope {
      Mac_top.I.clock       = i.I.eth_rx_clk;
      reset                 = rst;
      en                    = vdd;
      rx_dv                 = i.I.eth_rx_dv;
      rx_er                 = i.I.eth_rxerr;
      rx_data               = i.I.eth_rxd;
      m_axis_tready         = vdd;     (* drain all incoming frames immediately *)
      s_axis_tdata          = zero 8;
      s_axis_tvalid         = gnd;
      s_axis_tuser          = gnd;
      tx_start              = gnd;
    }
  in

  let (blinker : _ Second_pulse.O.t) =
    Second_pulse.create scope {
      Second_pulse.I.clk = i.I.clk100mhz;
      rst;
    }
  in

  ignore blinker.keep;
  ignore mac.keep;

  { O.
    (* led[0]=1 Hz heartbeat  led[1]=last-frame CRC ok  led[2]=in payload  led[3]=unused *)
    led = concat_msb [ gnd; mac.in_payload; mac.frame_crc_ok; blinker.pulse ];

    (* led0 RGB: green while a frame payload is being received *)
    led0_r = gnd;  led0_g = mac.in_payload;  led0_b = gnd;
    led1_r = gnd;  led1_g = gnd;             led1_b = gnd;
    led2_r = gnd;  led2_g = gnd;             led2_b = gnd;
    led3_r = gnd;  led3_g = gnd;             led3_b = gnd;

    uart_rxd_out = vdd;    (* UART idle-high; not used in this test *)

    eth_mdc      = gnd;    (* MDC unused: no PHY register access *)
    eth_rstn     = vdd;    (* PHY held out of reset *)
    eth_ref_clk  = gnd;    (* TODO: drive from 25 MHz MMCM output via ODDR *)
    eth_tx_en    = mac.tx_en;
    eth_txd      = mac.tx_d;
  }
;;
