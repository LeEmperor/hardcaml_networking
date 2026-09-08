(* Bohdan Purtell University of Florida

   Module: Uart_test_top A board-level smoke test for the UART pair: it sends the byte
   0x55 continuously out the USB-UART pin and blinks a heartbeat, so a host terminal and
   an LED between them say whether the toolchain, the pin map and [Uart_tx] all work
   before anything heavier is wired up. 0x55 is alternating ones and zeroes, which makes a
   scope trace of a wrong baud rate obvious rather than plausible.

   The port interface is [Arty_board_top]'s, reused wholesale rather than re-declared, so
   this top and the pin map cannot drift apart; every pin this design does not use is
   driven to its inactive level here.

   The baud tick is a [Second_pulse] with [clk_freq] reused as a plain divisor rather than
   as a frequency: 100 MHz / 868 is about 115.2 kBd, which is 115200 to within 0.16%.
   [d_in_valid] is tied high and [d_in] is constant, so the transmitter returns to IDLE
   and immediately starts the next frame - the line carries back-to-back 0x55 frames for
   as long as the enable switch is up. *)

open! Core
open! Hardcaml
open! Signal
module I = Arty_board_top.I
module O = Arty_board_top.O

let create scope i : _ O.t =
  (* port aliases *)
  let clock100 = i.I.clk100mhz in
  let rst = Signal.bit i.I.btn ~pos:0 in
  let en = Signal.bit i.I.sw ~pos:0 in
  (* hierarchical instantiations *)
  let heartbeat_inst = Second_pulse.create scope { Second_pulse.I.clk = clock100; rst } in
  (* 100e6 / 868 ~= 115.2 kBd *)
  let baud_inst =
    Second_pulse.create scope ~clk_freq:868 { Second_pulse.I.clk = clock100; rst }
  in
  let uart_inst =
    Uart_tx.create
      scope
      { Uart_tx.I.clk = clock100
      ; rst
      ; en
      ; tick = baud_inst.pulse
      ; d_in = of_int_trunc ~width:8 0x55
      ; d_in_valid = vdd
      }
  in
  { O.led = zero 4
  ; led0_r = heartbeat_inst.pulse
  ; led0_g = gnd
  ; led0_b = gnd
  ; led1_r = gnd
  ; led1_g = gnd
  ; led1_b = gnd
  ; led2_r = gnd
  ; led2_g = gnd
  ; led2_b = gnd
  ; led3_r = gnd
  ; led3_g = gnd
  ; led3_b = gnd
  ; (* named for the host's point of view: this is the FPGA's tx pin *)
    uart_rxd_out = uart_inst.uart_tx
  ; eth_mdc = gnd
  ; eth_rstn = vdd
  ; eth_ref_clk = gnd
  ; eth_tx_en = gnd
  ; eth_txd = zero 4
  }
;;
