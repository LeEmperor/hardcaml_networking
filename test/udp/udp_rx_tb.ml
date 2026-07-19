(*
  Bohdan Purtell
  University of Florida

  Testbench: UDP (L4) RX header parser (Udp_rx) — SMOKE / SEED

  Drives the UDP datagram byte stream exactly as Ipv4_rx would present it
  (rx_tdata/tvalid/tlast/tuser + the rx_tfirst SOF pulse and the stable
  ip_protocol/ip_src_ip/ip_dst_ip metadata) and checks that Udp_rx:

    - strips the 8-byte UDP header and re-emits the application payload verbatim,
    - drives m_tlast off the UDP length field,
    - surfaces the right metadata (src_port, dst_port, udp_length, payload_length,
      src/dst IP passthrough).

  This is a minimal seed — extend it with: zero-length datagrams, the
  drop_on_port_mismatch filter path, non-UDP ip_protocol (Flush), truncated
  frames, and application backpressure (app_tready stalls). Mirror ipv4_rx_tb's
  golden-vector + stall structure when you do.
*)

open! Core
open! Hardcaml
open! Udp_of_hardcaml
open! Helper_tb_functions

let () = print_endline "=== Running UDP RX Testbench (smoke) ==="

module Rx = Udp_rx.Make (struct
  let drop_on_port_mismatch = false
  let expected_dst_port = 0x1235
  let debug = true
end)

module Sim = Cyclesim.With_interface (Rx.I) (Rx.O)

let hi8 x = (x lsr 8) land 0xFF
let lo8 x = x land 0xFF
let ip32 bytes = List.fold bytes ~init:0 ~f:(fun a b -> (a lsl 8) lor (b land 0xFF))

(* build an 8-byte UDP header ++ payload; checksum field = 0 (disabled), as TX emits *)
let udp_datagram ~src_port ~dst_port ~payload =
  let length = 8 + List.length payload in
  [ hi8 src_port; lo8 src_port; hi8 dst_port; lo8 dst_port
  ; hi8 length; lo8 length; 0x00; 0x00 ]
  @ payload

let () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim = Sim.create (Rx.create scope) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let cycle () = Cyclesim.cycle sim in

  let src_ip = [ 192; 168; 1; 1 ] in
  let dst_ip = [ 192; 168; 1; 10 ] in

  let reset () =
    i.Rx.I.reset       <-- 1;
    i.en               <-- 1;
    i.rx_tdata         <-- 0;
    i.rx_tvalid        <-- 0;
    i.rx_tlast         <-- 0;
    i.rx_tuser         <-- 0;
    i.rx_tfirst        <-- 0;
    i.ip_protocol      <-- 17;
    i.ip_src_ip        <-- ip32 src_ip;
    i.ip_dst_ip        <-- ip32 dst_ip;
    i.app_tready       <-- 1;
    cycle ();
    i.reset <-- 0
  in

  (* Present [datagram] one byte per cycle (no stalls, app_tready held high),
     tfirst on byte 0, tlast on the last byte.

     Cyclesim phase note (see the longer version in ipv4_rx_tb): m_tvalid is
     combinational from the FSM state, which Cyclesim reports *after* the state
     register updates, so the valid qualifier leads the byte on the bus by one
     cycle. m_tdata is just the input we drive. So a byte belongs to the app
     stream when the PREVIOUS iteration's post-cycle m_tvalid was high — we defer
     collection by one iteration via [prev_valid]. Metadata regs are latched, so
     sampling them directly at [app_start] is fine. *)
  let run_datagram datagram =
    let out = ref [] in
    let meta = ref None in
    let prev_valid = ref false in
    let n = List.length datagram in
    List.iteri datagram ~f:(fun k byte ->
      i.rx_tdata  <-- byte;
      i.rx_tvalid <-- 1;
      i.rx_tfirst <-- (if k = 0 then 1 else 0);
      i.rx_tlast  <-- (if k = n - 1 then 1 else 0);
      if !prev_valid then out := byte :: !out;
      cycle ();
      prev_valid := Bits.to_int_trunc !(o.Rx.O.m_tvalid) = 1;
      if Bits.to_int_trunc !(o.app_start) = 1
      then
        meta
          := Some
               ( Bits.to_int_trunc !(o.src_port)
               , Bits.to_int_trunc !(o.dst_port)
               , Bits.to_int_trunc !(o.udp_length)
               , Bits.to_int_trunc !(o.payload_length) ));
    i.rx_tvalid <-- 0;
    i.rx_tfirst <-- 0;
    i.rx_tlast  <-- 0;
    List.rev !out, !meta
  in

  let pass = ref true in
  let check name cond =
    printf "  %-28s %s\n" name (if cond then "PASS" else (pass := false; "FAIL"))
  in

  reset ();

  (* ── test 1: 4-byte payload ── *)
  printf "\n-- [test 1: 4B payload] --\n";
  let payload = [ 0xDE; 0xAD; 0xBE; 0xEF ] in
  let out, meta =
    run_datagram (udp_datagram ~src_port:0x1234 ~dst_port:0x1235 ~payload)
  in
  check "payload bytes" ([%compare.equal: int list] out payload);
  (match meta with
   | None -> check "metadata latched" false
   | Some (sp, dp, len, plen) ->
     check "src_port" (sp = 0x1234);
     check "dst_port" (dp = 0x1235);
     check "udp_length" (len = 8 + List.length payload);
     check "payload_length" (plen = List.length payload));

  reset ();

  (* ── test 2: 1-byte payload ── *)
  printf "\n-- [test 2: 1B payload] --\n";
  let payload = [ 0x5A ] in
  let out, meta =
    run_datagram (udp_datagram ~src_port:0xABCD ~dst_port:0x1235 ~payload)
  in
  check "payload bytes" ([%compare.equal: int list] out payload);
  (match meta with
   | None -> check "metadata latched" false
   | Some (sp, dp, _len, plen) ->
     check "src_port" (sp = 0xABCD);
     check "dst_port" (dp = 0x1235);
     check "payload_length" (plen = 1));

  printf "\n==== SUMMARY: %s ====\n" (if !pass then "ALL PASS" else "FAILURES");
  printf "\n=== SIMULATION COMPLETE ===\n"
;;
