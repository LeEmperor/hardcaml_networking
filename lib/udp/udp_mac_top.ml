(*
  Bohdan Purtell
  University of Florida

  Module: Udp_mac_top

  Composition layer: a UDP/IPv4 TX generator (Udp_tx) stacked on top of the MII
  Ethernet MAC (Mac_top). This module owns the *wiring*, so the layering stays
  one-directional:

      Udp_tx  ─(Ethernet-payload AXI-S)→  Mac_top.s_axis  ─→ MII PHY

  The MAC does NOT depend on UDP — [mii_of_hardcaml] has no knowledge of this
  library. The MAC's s_axis sink can equally be driven by a raw-frame source,
  a different protocol layer, or nothing. "Including a UDP stack" is therefore a
  question of *what you instantiate around the MAC*, not a compile-time flag on
  the MAC itself — hence composition here rather than a Config functor on
  Mac_top. (If you later want one buildable top that can include/exclude UDP,
  make THIS module the functor; leave Mac_top plain.)

  Everything here lives in the tx_clock domain (the MAC's TX side); the RX path
  is passed straight through untouched.

  CAVEAT: Mac_top's tx_datapath still emits ethertype 0x9999. A real IPv4 host
  wants 0x0800 — parameterize the MAC's ethertype (or the datapath constants)
  before expecting a kernel to accept these frames. For loopback/tcpdump bring-up
  0x9999 is fine.
*)

open! Core
open! Hardcaml
open! Signal
open! Mii_of_hardcaml

let () = Stdio.print_endline "=== Imported UDP+MAC Top ==="

module I = struct
  type 'a t = {
    (* two clock domains, mirroring Mac_top *)
    rx_clock : 'a;
    rx_reset : 'a;
    tx_clock : 'a;
    tx_reset : 'a;
    en       : 'a;

    (* PHY RX pins *)
    rx_dv   : 'a;
    rx_er   : 'a;
    rx_data : 'a [@bits 4];

    (* RX AXI-S consumer backpressure *)
    m_axis_tready : 'a;

    (* UDP application TX side (tx_clock domain) *)
    tx_start       : 'a;             (* begin a datagram *)
    payload_len    : 'a [@bits 16];  (* application-data length, latched at tx_start *)
    payload_tdata  : 'a [@bits 8];
    payload_tvalid : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* RX AXI-S output (straight through from the MAC) *)
    m_axis_tdata  : 'a [@bits 8];
    m_axis_tkeep  : 'a;
    m_axis_tlast  : 'a;
    m_axis_tvalid : 'a;
    m_axis_tuser  : 'a;

    (* MII TX pins *)
    tx_d    : 'a [@bits 4];
    tx_en   : 'a;
    tx_busy : 'a;

    (* UDP application backpressure / status *)
    payload_tready : 'a;
    udp_busy       : 'a;
  } [@@deriving hardcaml]
end

let create ?(rx_fifo_for_sim = false) (scope : Scope.t) (i : _ I.t) : _ O.t =
  (* break the udp_tx <-> mac backpressure combinational loop with a wire stub *)
  let wire_mac_tready = Signal.wire 1 in

  let udp =
    Udp_tx.create scope
      { Udp_tx.I.clock  = i.tx_clock
      ; reset          = i.tx_reset
      ; en             = i.en
      ; start          = i.tx_start
      ; payload_len    = i.payload_len
      ; payload_tdata  = i.payload_tdata
      ; payload_tvalid = i.payload_tvalid
      ; mac_tready     = wire_mac_tready
      }
  in

  let mac =
    Mac_top.create ~rx_fifo_for_sim scope
      { Mac_top.I.rx_clock = i.rx_clock
      ; rx_reset      = i.rx_reset
      ; tx_clock      = i.tx_clock
      ; tx_reset      = i.tx_reset
      ; en            = i.en
      ; rx_dv         = i.rx_dv
      ; rx_er         = i.rx_er
      ; rx_data       = i.rx_data
      ; m_axis_tready = i.m_axis_tready
      (* the wiring: UDP byte stream → MAC's Ethernet-payload sink.
         udp_tx pulses tx_start as it emits its first byte; the MAC latches that
         in start_pending and holds transmission until the whole datagram is
         buffered (store-and-forward — see the frames_buffered gate in
         mac_top.ml). That resolves the earlier cut-through race in which the
         MAC's read side overtook the streaming writer at the header→payload
         boundary and dropped the first payload byte. The full frame — Ethernet
         framing, IPv4/UDP header, streamed app payload, MAC zero-padding, and
         FCS — is now emitted byte-perfect (verified end-to-end in
         udp_mac_top_tb.ml). *)
      ; s_axis_tdata  = udp.m_tdata
      ; s_axis_tvalid = udp.m_tvalid
      ; s_axis_tlast  = udp.m_tlast
      ; s_axis_tuser  = Signal.gnd
      ; tx_start      = udp.tx_start
      }
  in

  Signal.(wire_mac_tready <-- mac.s_axis_tready);

  { O.m_axis_tdata  = mac.m_axis_tdata
  ; m_axis_tkeep   = mac.m_axis_tkeep
  ; m_axis_tlast   = mac.m_axis_tlast
  ; m_axis_tvalid  = mac.m_axis_tvalid
  ; m_axis_tuser   = mac.m_axis_tuser
  ; tx_d           = mac.tx_d
  ; tx_en          = mac.tx_en
  ; tx_busy        = mac.tx_busy
  ; payload_tready = udp.payload_tready
  ; udp_busy       = udp.busy
  }
;;
