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

let create 
  (scope : Scope.t) 
  (i : _ I.t) 
  : _ O.t 
  =
  let rst : Signal.t = Signal.bit i.I.btn ~pos:0 in (* btn[0]: active-high synchronous reset *)
  let en  : Signal.t = Signal.bit i.I.sw ~pos:0 in (* sw[0]: active-high *)

  (* let en  : Signal.t = select i.I.sw ~high:0 ~low: 0 in (* sw[0]: active-high *) *)
  (* let rst : Signal.t = select i.I.btn ~high:0 ~low:0 in (* btn[0]: active-high synchronous reset *) *)

  let mac_inst  =
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

  let heartbeat_inst =
    Second_pulse.create scope 
    {
      Second_pulse.I.clk = i.I.clk100mhz;
      rst;
    }
  in

  let clk_div_inst = 
    Clk_div.create scope {
      Clk_div.I.src_clk = i.I.clk100mhz;
      rst;
      en;
    }
  in

  (* hold the PHY rst high for a bit after board power on *)
  let spec100 = Reg_spec.create ~clock:i.I.clk100mhz () in
  let phy_rst_cnt : Signal.t = 
    Signal.reg_fb spec100 ~enable:vdd ~width:17 
      ~f:( fun q -> (* a function f takes in an input q *)
          mux2 rst (zero 17) (mux2 (msb q) q (q +:. 1)))
  in

  ignore heartbeat_inst.keep;
  ignore mac_inst.keep;

  { O.
    (* led[0]=1 Hz heartbeat  led[1]=last-frame CRC ok  led[2]=in payload  led[3]=unused *)

    (* concate a list of Signal.t *)
    led = concat_msb [ 
      gnd;                    (* LED3 *)
      gnd;                    (* LED2*)
      mac_inst.in_payload;    (* LED1 *)
      mac_inst.frame_crc_ok;  (* LED0 *)
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

    uart_rxd_out = vdd;    (* UART idle-high; not used in this test *)

    eth_mdc      = gnd;    (* MDC unused: no PHY register access *)
    eth_rstn     = Signal.msb phy_rst_cnt;
    eth_ref_clk  = clk_div_inst.dst_clk;     
    eth_tx_en    = mac_inst.tx_en;
    eth_txd      = mac_inst.tx_d;
  }
;;
