(*
  Bohdan Purtell
  University of Florida

  Testbench: UDP/IPv4 TX header generator (Udp_tx)

  Verifies the byte stream Udp_tx emits on its AXI-S output (m_tdata/m_tvalid/
  m_tlast) against a software-computed golden datagram:

    [0..27]   IPv4 header (20) ++ UDP header (8)
    [28..]    application payload, verbatim
    m_tlast   asserted on the final payload byte

  Udp_tx does NOT pad — sub-46-byte datagrams come out short here; the MAC adds
  the Ethernet minimum padding downstream (covered in tx_path_tb.ml). So the
  expected output length is exactly 28 + payload_len.

  The golden IPv4 header checksum is recomputed in OCaml (one's-complement sum,
  end-around carry, complement) so a bug in the RTL checksum shows up as a
  mismatch on bytes [10..11].
*)

open! Core
open! Hardcaml
open! Udp_of_hardcaml
open! Hardcaml_waveterm
open! Helper_tb_functions  (* provides the (<--) : Bits.t ref -> int -> unit driver *)

let () = print_endline "=== Running UDP TX Testbench ==="

module Sim = Cyclesim.With_interface (Udp_tx.I) (Udp_tx.O)

(* ── golden model — MUST match the constants in udp_tx.ml ── *)
let src_ip   = [ 192; 168; 1; 10 ]
let dst_ip   = [ 192; 168; 1; 1 ]
let src_port = 0x1234
let dst_port = 0x1235

let w16 hi lo = (hi lsl 8) lor lo
let hi8 x = (x lsr 8) land 0xFF
let lo8 x = x land 0xFF

(* IPv4 header checksum over the 10 header words (checksum field = 0) *)
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

let golden_header ~n =
  let total_length = 28 + n in
  let udp_length   = 8 + n in
  let ck = ip_checksum ~total_length in
  (* IPv4 (20) *)
  [ 0x45; 0x00; hi8 total_length; lo8 total_length
  ; 0x00; 0x00; 0x40; 0x00; 0x40; 0x11; hi8 ck; lo8 ck ]
  @ src_ip @ dst_ip
  (* UDP (8) *)
  @ [ hi8 src_port; lo8 src_port; hi8 dst_port; lo8 dst_port
    ; hi8 udp_length; lo8 udp_length; 0x00; 0x00 ]

(* ── tb ── *)
let () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim = Sim.create (Udp_tx.create scope) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let cycle () = Cyclesim.cycle sim in

  let reset () =
    i.Udp_tx.I.reset <-- 1;
    i.en             <-- 1;
    i.start          <-- 0;
    i.payload_len    <-- 0;
    i.payload_tdata  <-- 0;
    i.payload_tvalid <-- 0;
    i.mac_tready     <-- 0;
    cycle ();
    i.reset <-- 0
  in

  (* Drive a datagram of [n] payload bytes and collect the emitted stream.
     [stall_every]=k inserts a mac_tready=0 bubble every k accepted bytes to
     exercise backpressure; 0 disables stalling. Returns (bytes, tlast_index). *)
  let run ~n ~stall_every =
    reset ();
    let data = List.init n ~f:(fun k -> (0x40 + k) land 0xFF) in
    i.payload_len <-- n;  (* held stable; latched by udp_tx on the start cycle *)

    let collected = ref [] in
    let tlast_idx = ref (-1) in
    let ptr       = ref 0 in
    let accepted  = ref 0 in
    let saw_last  = ref false in
    let started   = ref false in  (* pulse start on the first iteration only *)
    let guard     = ref 0 in
    (* Every emitted cycle is observed here: set inputs → cycle → read. The
       start pulse is folded into the first iteration (an Idle cycle, tvalid=0)
       so header byte 0 isn't consumed by an un-sampled cycle. *)
    while (not !saw_last) && !guard < 500 do
      i.start <-- (if !started then 0 else 1);
      (* backpressure: insert a mac_tready=0 bubble every (stall_every+1) cycles.
         Keyed on the cycle counter (not on accepted) so a held-off byte can't
         wedge the stall condition permanently. *)
      let stalling = stall_every > 0 && !guard % (stall_every + 1) = stall_every in
      i.mac_tready <-- (if stalling then 0 else 1);
      (* always present the current payload byte; udp_tx consumes it only in
         its Payload state (signalled by payload_tready) *)
      let has = !ptr < n in
      i.payload_tvalid <-- (if has then 1 else 0);
      i.payload_tdata  <-- (if has then List.nth_exn data !ptr else 0);

      (* propagate: outputs read AFTER cycle reflect the inputs just set and the
         state active during this cycle (m_tdata is combinational off payload_tdata) *)
      cycle ();
      started := true;

      let tvalid = Bits.to_bool !(o.Udp_tx.O.m_tvalid) in
      let tready = Bits.to_bool !(i.mac_tready) in
      let tdata  = Bits.to_int_trunc !(o.m_tdata) in
      let tlast  = Bits.to_bool !(o.m_tlast) in
      let pready = Bits.to_bool !(o.payload_tready) in

      (* a byte transfers only when valid AND downstream ready *)
      if tvalid && tready then begin
        collected := !collected @ [ tdata ];
        if tlast then tlast_idx := List.length !collected - 1;
        if tlast then saw_last := true;
        incr accepted
      end;
      (* advance the app pointer when udp_tx actually took a payload byte *)
      if pready && tready then incr ptr;

      incr guard
    done;
    if !guard >= 500 then printf "WARNING: never saw tlast within guard — likely FSM stall\n";
    (!collected, !tlast_idx)
  in

  let check ~label ~n ~stall_every =
    printf "\n-- [%s] payload = %d bytes, stall_every = %d --\n" label n stall_every;
    let got, tlast_idx = run ~n ~stall_every in
    let expected = golden_header ~n @ List.init n ~f:(fun k -> (0x40 + k) land 0xFF) in
    let exp_len  = 28 + n in

    let len_ok = List.length got = exp_len in
    if not len_ok then printf "  length: FAIL got %d expect %d\n" (List.length got) exp_len;

    let bytes_ok = List.equal Int.equal got expected in
    if not bytes_ok then begin
      let show l = String.concat ~sep:" " (List.map l ~f:(sprintf "%02x")) in
      printf "  bytes MISMATCH\n";
      printf "    expected: %s\n" (show expected);
      printf "    got:      %s\n" (show got)
    end;

    (* header field spot-checks for a readable failure signal *)
    let field name off len = List.sub got ~pos:off ~len |> List.map ~f:(sprintf "%02x") |> String.concat ~sep:"" in
    if bytes_ok then begin
      printf "  ip.total_len = 0x%s  udp.len = 0x%s  ip.cksum = 0x%s\n"
        (field "" 2 2) (field "" 24 2) (field "" 10 2)
    end;

    let tlast_ok = tlast_idx = exp_len - 1 in
    if not tlast_ok then printf "  tlast index: FAIL got %d expect %d\n" tlast_idx (exp_len - 1);

    let ok = len_ok && bytes_ok && tlast_ok in
    printf "  %s: %s\n" label (if ok then "PASS" else "FAIL");
    ok
  in

  let r1 = check ~label:"test 1: 18B"          ~n:18 ~stall_every:0 in
  let r2 = check ~label:"test 2: 1B"           ~n:1  ~stall_every:0 in
  let r3 = check ~label:"test 3: 50B"          ~n:50 ~stall_every:0 in
  let r4 = check ~label:"test 4: 18B + stalls" ~n:18 ~stall_every:3 in
  let results = [ r1; r2; r3; r4 ] in

  printf "\n==== SUMMARY: %d/%d passed ====\n"
    (List.count results ~f:Fn.id) (List.length results);

  print_endline "\n=== SIMULATION COMPLETE ==="
;;
