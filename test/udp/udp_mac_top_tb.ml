(*
  Bohdan Purtell
  University of Florida

  Testbench: Udp_mac_top end-to-end integration test

  Drives a UDP datagram into the application interface (payload_len +
  payload_tdata/tvalid) and checks the *complete* Ethernet frame that comes out
  on the MII pins, byte-for-byte:

    [0..6]   preamble : 7 × 0x55            (MAC)
    [7]      SFD      : 0xD5                 (MAC)
    [8..13]  dst_mac  : ff ff ff ff ff ff    (MAC, hardcoded)
    [14..19] src_mac  : 02 00 00 00 00 01    (MAC, hardcoded)
    [20..21] eth_type : 0x9999               (MAC, hardcoded)
    [22..]   payload  : the IPv4/UDP datagram Udp_tx produced (IP hdr ++ UDP hdr
                        ++ app data), zero-padded by the MAC to the 46-byte
                        Ethernet minimum when the datagram is shorter
    [..]     FCS      : CRC-32 over dst/src/ethertype + (padded) payload  (MAC)

  This exercises the full stack — Udp_tx streaming into Mac_top's store-and-forward
  TX FIFO. The MAC now holds transmission until a whole datagram (tlast) is
  buffered, so the streamed payload tail is emitted intact (previously the
  cut-through drain raced the writer and dropped the first payload byte). The
  golden IPv4 header checksum and the frame FCS are recomputed in OCaml so any
  RTL regression shows up as a byte mismatch.

  NB on driving the AXI application input: Cyclesim recomputes combinational
  outputs to the *next* register state after [cycle], so [payload_tready] read
  after [cycle] is one cycle ahead of the transfer it gates. We therefore sample
  it *before* [cycle] and advance the source pointer on that, keeping the byte
  the MAC actually latches aligned with the source index.
*)

open! Core
open! Hardcaml
open! Udp_of_hardcaml
open! Helper_tb_functions

let () = print_endline "=== Running UDP+MAC Top End-to-End Testbench ==="

module Sim = Cyclesim.With_interface (Udp_mac_top.I) (Udp_mac_top.O)

(* ── golden IPv4/UDP header — MUST match the constants in udp_tx.ml ── *)
let src_ip = [ 192; 168; 1; 10 ]
let dst_ip = [ 192; 168; 1; 1 ]
let src_port = 0x1234
let dst_port = 0x1235

let w16 hi lo = (hi lsl 8) lor lo
let hi8 x = (x lsr 8) land 0xFF
let lo8 x = x land 0xFF

let ip_checksum ~total_length =
  let words =
    [ 0x4500; total_length; 0x0000; 0x4000; 0x4011; 0x0000
    ; w16 (List.nth_exn src_ip 0) (List.nth_exn src_ip 1)
    ; w16 (List.nth_exn src_ip 2) (List.nth_exn src_ip 3)
    ; w16 (List.nth_exn dst_ip 0) (List.nth_exn dst_ip 1)
    ; w16 (List.nth_exn dst_ip 2) (List.nth_exn dst_ip 3)
    ]
  in
  let sum = List.fold words ~init:0 ~f:( + ) in
  let rec fold s = if s > 0xFFFF then fold ((s land 0xFFFF) + (s lsr 16)) else s in
  lnot (fold sum) land 0xFFFF

let golden_datagram ~app =
  let n = List.length app in
  let total_length = 28 + n in
  let udp_length = 8 + n in
  let ck = ip_checksum ~total_length in
  [ 0x45; 0x00; hi8 total_length; lo8 total_length
  ; 0x00; 0x00; 0x40; 0x00; 0x40; 0x11; hi8 ck; lo8 ck ]
  @ src_ip @ dst_ip
  @ [ hi8 src_port; lo8 src_port; hi8 dst_port; lo8 dst_port
    ; hi8 udp_length; lo8 udp_length; 0x00; 0x00 ]
  @ app

(* ── SW CRC-32 reference (reflected poly 0xEDB88320) — matches tx_path_tb ── *)
let sw_crc_bit crc bit =
  let feedback = ((crc land 1) lxor bit) land 1 in
  let shifted = crc lsr 1 in
  if feedback = 1 then shifted lxor 0xEDB88320 else shifted

let sw_crc_byte crc byte =
  let crc = ref crc in
  for i = 0 to 7 do
    crc := sw_crc_bit !crc ((byte lsr i) land 1)
  done;
  !crc

let sw_crc bytes =
  List.fold bytes ~init:0xFFFFFFFF ~f:sw_crc_byte |> fun raw -> raw lxor 0xFFFFFFFF

let bytes_of_int ~n x = List.init n ~f:(fun i -> (x lsr (8 * i)) land 0xFF)

(* ── frame constants the MAC hardcodes (must match tx_datapath.ml) ── *)
let exp_preamble = List.init 7 ~f:(fun _ -> 0x55)
let exp_dst_mac = [ 0xFF; 0xFF; 0xFF; 0xFF; 0xFF; 0xFF ]
let exp_src_mac = [ 0x02; 0x00; 0x00; 0x00; 0x00; 0x01 ]
let exp_eth_type = [ 0x99; 0x99 ]
let min_payload = 46

let () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim = Sim.create (Udp_mac_top.create ~rx_fifo_for_sim:true scope) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let cycle () = Cyclesim.cycle sim in

  let reset () =
    i.Udp_mac_top.I.rx_reset <-- 1;
    i.tx_reset <-- 1;
    i.en <-- 0;
    i.tx_start <-- 0;
    i.payload_len <-- 0;
    i.payload_tdata <-- 0;
    i.payload_tvalid <-- 0;
    i.rx_dv <-- 0;
    i.m_axis_tready <-- 0;
    cycle ();
    i.rx_reset <-- 0;
    i.tx_reset <-- 0;
    i.en <-- 1
  in

  (* Drive [app] as the UDP application payload and collect the emitted MII frame
     (reassembled from nibble pairs, lo nibble first). *)
  let run app =
    reset ();
    let n = List.length app in
    let ptr = ref 0 in
    let started = ref false in
    let nibbles = ref [] in
    let saw_txen = ref false in
    let idle_after = ref 0 in
    let guard = ref 0 in
    i.payload_len <-- n;
    while !idle_after < 16 && !guard < 4000 do
      i.tx_start <-- (if !started then 0 else 1);
      (* proper AXI source: hold tvalid, present app[ptr], advance on a real
         transfer (readiness sampled pre-cycle — see header note) *)
      i.payload_tvalid <-- 1;
      i.payload_tdata <-- List.nth_exn app (min !ptr (n - 1));
      let ready = Bits.to_bool !(o.Udp_mac_top.O.payload_tready) in
      cycle ();
      started := true;
      if ready && !ptr < n then incr ptr;
      let tx_en = Bits.to_bool !(o.tx_en) in
      if tx_en then begin
        saw_txen := true;
        idle_after := 0;
        nibbles := !nibbles @ [ Bits.to_int_trunc !(o.tx_d) ]
      end
      else if !saw_txen then incr idle_after;
      incr guard
    done;
    let rec pair = function
      | lo :: hi :: rest -> ((hi lsl 4) lor lo) :: pair rest
      | _ -> []
    in
    !saw_txen, pair !nibbles
  in

  let check ~label ~app =
    printf "\n-- [%s] app payload = %d bytes --\n" label (List.length app);
    let saw_txen, frame = run app in
    let datagram = golden_datagram ~app in
    let pad_len = Int.max 0 (min_payload - List.length datagram) in
    let wire_payload = datagram @ List.init pad_len ~f:(fun _ -> 0x00) in
    let plen = List.length wire_payload in
    let fcs =
      bytes_of_int ~n:4
        (sw_crc (exp_dst_mac @ exp_src_mac @ exp_eth_type @ wire_payload))
    in
    let expected =
      exp_preamble @ [ 0xD5 ] @ exp_dst_mac @ exp_src_mac @ exp_eth_type
      @ wire_payload @ fcs
    in
    let sub off len =
      if off + len <= List.length frame then List.sub frame ~pos:off ~len else []
    in
    let eq name got exp =
      let ok = List.equal Int.equal got exp in
      printf "  %-10s: %s\n" name (if ok then "PASS" else "FAIL");
      if not ok then begin
        let show l = String.concat ~sep:" " (List.map l ~f:(sprintf "%02x")) in
        printf "    expected: %s\n    got:      %s\n" (show exp) (show got)
      end;
      ok
    in
    printf "  tx_en          : %s\n" (if saw_txen then "PASS" else "FAIL");
    printf "  frame length   : %d (expect %d)\n" (List.length frame)
      (List.length expected);
    let ok_len = List.length frame = List.length expected in
    let ok_pre = eq "preamble" (sub 0 7) exp_preamble in
    let ok_sfd = eq "sfd" (sub 7 1) [ 0xD5 ] in
    let ok_dst = eq "dst_mac" (sub 8 6) exp_dst_mac in
    let ok_src = eq "src_mac" (sub 14 6) exp_src_mac in
    let ok_eth = eq "eth_type" (sub 20 2) exp_eth_type in
    let ok_pay = eq "payload" (sub 22 plen) wire_payload in
    let ok_fcs = eq "fcs" (sub (22 + plen) 4) fcs in
    let ok =
      saw_txen && ok_len && ok_pre && ok_sfd && ok_dst && ok_src && ok_eth
      && ok_pay && ok_fcs
    in
    printf "  %s: %s\n" label (if ok then "PASS" else "FAIL");
    ok
  in

  (* n=18: datagram is exactly 46 bytes → no MAC padding *)
  let r1 = check ~label:"test 1: 18B (no pad)" ~app:(List.init 18 ~f:(fun k -> (0x40 + k) land 0xFF)) in
  (* n=4: datagram is 32 bytes → MAC zero-pads the Ethernet payload to 46 *)
  let r2 = check ~label:"test 2: 4B (MAC-padded)" ~app:[ 0xDE; 0xAD; 0xBE; 0xEF ] in
  (* n=40: datagram is 68 bytes → above the minimum, variable length *)
  let r3 = check ~label:"test 3: 40B (no pad)" ~app:(List.init 40 ~f:(fun k -> (k * 7) land 0xFF)) in

  let results = [ r1; r2; r3 ] in
  printf "\n==== SUMMARY: %d/%d passed ====\n"
    (List.count results ~f:Fn.id) (List.length results);
  print_endline "\n=== SIMULATION COMPLETE ==="
;;
