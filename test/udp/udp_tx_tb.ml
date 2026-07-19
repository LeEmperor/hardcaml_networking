(*
  Bohdan Purtell
  University of Florida

  Testbench: UDP (L4) TX header generator (Udp_tx)

  Since the IPv4/UDP split, Udp_tx emits ONLY the UDP datagram — 8-byte UDP
  header ++ application payload — down to the IPv4 layer. This tb checks that
  byte stream (m_tdata/m_tvalid/m_tlast) against a software golden:

    [0..7]   UDP header (src_port, dst_port, udp_length, checksum=0)
    [8..]    application payload, verbatim
    m_tlast  asserted on the final payload byte

  The IPv4 header (and its checksum) is now Ipv4_tx's job — see ipv4_tx_tb.ml.
  Expected output length is exactly 8 + payload_len (Udp_tx does not pad).
*)

open! Core
open! Hardcaml
open! Udp_of_hardcaml
open! Hardcaml_waveterm
open! Helper_tb_functions  (* provides the (<--) : Bits.t ref -> int -> unit driver *)

let () = print_endline "=== Running UDP TX Testbench ==="

(* endpoints — MUST match the Config used below *)
let src_port = 0x1234
let dst_port = 0x1235

module U = Udp_tx.Make (struct
  let src_port = src_port
  let dst_port = dst_port
end)

module Sim = Cyclesim.With_interface (U.I) (U.O)

let hi8 x = (x lsr 8) land 0xFF
let lo8 x = x land 0xFF

let golden_header ~n =
  let udp_length = 8 + n in
  [ hi8 src_port; lo8 src_port; hi8 dst_port; lo8 dst_port
  ; hi8 udp_length; lo8 udp_length; 0x00; 0x00 ]

(* ── tb ── *)
let () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim = Sim.create (U.create scope) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let cycle () = Cyclesim.cycle sim in

  let reset () =
    i.U.I.reset    <-- 1;
    i.en             <-- 1;
    i.start          <-- 0;
    i.payload_len    <-- 0;
    i.payload_tdata  <-- 0;
    i.payload_tvalid <-- 0;
    i.l4_tready      <-- 0;
    cycle ();
    i.reset <-- 0
  in

  (* Drive a datagram of [n] payload bytes and collect the emitted stream.
     [stall_every]=k inserts an l4_tready=0 bubble every k cycles to exercise
     backpressure; 0 disables stalling. Returns (bytes, tlast_index). *)
  let run ~n ~stall_every =
    reset ();
    let data = List.init n ~f:(fun k -> (0x40 + k) land 0xFF) in
    i.payload_len <-- n;  (* held stable; latched by udp_tx on the start cycle *)

    let collected = ref [] in
    let tlast_idx = ref (-1) in
    let ptr       = ref 0 in
    let saw_last  = ref false in
    let started   = ref false in  (* pulse start on the first iteration only *)
    let guard     = ref 0 in
    while (not !saw_last) && !guard < 500 do
      i.start <-- (if !started then 0 else 1);
      let stalling = stall_every > 0 && !guard % (stall_every + 1) = stall_every in
      i.l4_tready <-- (if stalling then 0 else 1);
      let has = !ptr < n in
      i.payload_tvalid <-- (if has then 1 else 0);
      i.payload_tdata  <-- (if has then List.nth_exn data !ptr else 0);

      cycle ();
      started := true;

      let tvalid = Bits.to_bool !(o.U.O.m_tvalid) in
      let tready = Bits.to_bool !(i.l4_tready) in
      let tdata  = Bits.to_int_trunc !(o.m_tdata) in
      let tlast  = Bits.to_bool !(o.m_tlast) in
      let pready = Bits.to_bool !(o.payload_tready) in

      if tvalid && tready then begin
        collected := !collected @ [ tdata ];
        if tlast then tlast_idx := List.length !collected - 1;
        if tlast then saw_last := true
      end;
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
    let exp_len  = 8 + n in

    let len_ok = List.length got = exp_len in
    if not len_ok then printf "  length: FAIL got %d expect %d\n" (List.length got) exp_len;

    let bytes_ok = List.equal Int.equal got expected in
    if not bytes_ok then begin
      let show l = String.concat ~sep:" " (List.map l ~f:(sprintf "%02x")) in
      printf "  bytes MISMATCH\n";
      printf "    expected: %s\n" (show expected);
      printf "    got:      %s\n" (show got)
    end;

    let field off len = List.sub got ~pos:off ~len |> List.map ~f:(sprintf "%02x") |> String.concat ~sep:"" in
    if bytes_ok then
      printf "  udp.src = 0x%s  udp.dst = 0x%s  udp.len = 0x%s\n"
        (field 0 2) (field 2 2) (field 4 2);

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
