(* Module: U50_scaffolding

   Shared Alveo U50 plumbing for the 10G MAC validation harnesses. The analogue of
   validation/board_scaffolding.ml, which serves the same role for the Arty A7-100T MII
   harnesses.

   Almost nothing carries over from the Arty version, because almost nothing about the two
   boards' bring-up is alike. The Arty scaffolding is built around a PHY it must reset and
   clock (phy_hard_reset, the 25 MHz eth_ref_clk divider) and a human-visible control
   surface (heartbeat LED, one-second RX drain). The U50 has no PHY to reset -- the PCS/GT
   owns that -- and no buttons, switches, or general LEDs. Its control surface is
   AXI4-Lite over a JTAG-AXI master.

   What does carry over is the clock-domain discipline: reset_sync, sync2, and pulse_sync
   are reproduced here unchanged in behaviour. They are duplicated rather than shared
   because lifting them into helper_circuits touches every existing Arty harness, which is
   a refactor and not part of this scaffold. That move is still the right end state; see
   docs/mac_10g_u50_tx_validation_plan.md section 8.1.

   These are plain helper functions, not Hardcaml sub-modules: they build signals directly
   into the caller's circuit, so the emitted RTL matches hand-inlined plumbing and the
   caller keeps control over signal-creation order.

   This file was heavily edited by AI, as I find no use in wasting away at writing
   validation harnesses myself. If you have problems with this, bite me.
*)

open! Core
open! Hardcaml
open! Signal

(* Per-domain reset synchronizer: async-assert, sync-deassert. The PCS/GT reset-done
   indications and any external reset are asynchronous to the domain that consumes them,
   so drop them through a 2-FF chain that resets to 1. Reset releases two edges after
   [async_rst] releases, giving clean per-domain recovery. *)
let reset_sync ~clock ~async_rst =
  let spec = Reg_spec.create ~clock ~reset:async_rst () in
  let ff0 = Signal.reg spec ~reset_to:(Bits.one 1) Signal.gnd in
  Signal.reg spec ~reset_to:(Bits.one 1) ff0
;;

(* Plain 2-FF level synchronizer into [spec]'s domain. For quasi-static levels only --
   block lock, fault status, reset-done. Not for pulses; use [pulse_sync]. *)
let sync2 ~spec x = Signal.reg spec (Signal.reg spec x)

(* Toggle-based pulse synchronizer: a one-cycle pulse in [src_spec]'s domain becomes a
   one-cycle pulse in [dst_spec]'s. A bare level sync would drop or stretch a single-cycle
   pulse across the crossing. *)
let pulse_sync ~src_spec ~dst_spec src_pulse =
  let tog =
    Signal.reg_fb src_spec ~enable:vdd ~width:1 ~f:(fun q -> mux2 src_pulse ~:q q)
  in
  let tog_dst = Signal.reg dst_spec (Signal.reg dst_spec tog) in
  tog_dst ^: Signal.reg dst_spec tog_dst
;;

(* Stretch a one-cycle pulse to roughly [cycles] so it is visible on an LED. At 156.25 MHz
   a frame pulse is 6.4 ns; the default is about 50 ms, which reads as a distinct blink
   per frame at one frame per second and as a steady glow under continuous traffic. *)
let led_stretch ?(cycles = 8_000_000) ~spec pulse =
  let width = Int.ceil_log2 (cycles + 1) in
  let counter =
    Signal.reg_fb spec ~enable:vdd ~width ~f:(fun q ->
      mux2 pulse (of_int_trunc ~width cycles) (mux2 (q ==:. 0) q (q -:. 1)))
  in
  counter <>:. 0
;;

module Startup = struct
  type t =
    { released : Signal.t (* datapath reset: high until the link stack is up *)
    ; settled : Signal.t (* high once the post-release settling interval has elapsed *)
    }
end

(* Datapath startup gate, per docs/mac_10g_u50_tx_validation_plan.md section 9.2.

   [link_up] should be the AND of everything that must be true before the Hardcaml
   datapath may run: SI5394 PLL lock, PCS/GT TX and RX reset-done. It is synchronized
   here, so pass it raw. Reset stays asserted while it is low, and for [settle_cycles]
   after it rises; [settled] then goes high and the frame source may start.

   Holding reset on loss of [link_up] is deliberate. If the GT drops out, the MAC stops
   rather than transmitting into a dead link and counting underflows that describe the
   transceiver rather than the MAC. *)
let startup ?(settle_cycles = 1_000_000) ~spec ~external_reset ~link_up () =
  let link_up = sync2 ~spec link_up -- "link_up_sync" in
  let width = Int.ceil_log2 (settle_cycles + 1) in
  let counter =
    Signal.reg_fb spec ~enable:vdd ~width ~f:(fun q ->
      mux2
        (external_reset |: ~:link_up)
        (zero width)
        (mux2 (q ==:. settle_cycles) q (q +:. 1)))
    -- "settle_counter"
  in
  let settled = (counter ==:. settle_cycles) -- "settled" in
  { Startup.released = (external_reset |: ~:link_up) -- "startup_reset"; settled }
;;
