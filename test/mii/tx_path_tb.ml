(*
  Bohdan Purtell
  University of Florida

  Testbench: TX MAC top-level integration test

  Verification strategy (mirror of the RX testbench):
    RX TB: push MII nibbles from the PHY side → read bytes on AXI-S output
    TX TB: write bytes into the TX FIFO via AXI-S → read MII nibbles from tx_d/tx_en
           → reassemble nibbles back into bytes → parse + check frame structure

  Expected frame layout:
    [0..6]   preamble:  7 × 0x55
    [7]      SFD:       0xD5
    [8..13]  dst_mac:   hardcoded in tx_datapath (0x12 0x34 0x56 0x78 0x90 0xAB)
    [14..19] src_mac:   hardcoded in tx_datapath (0xAB 0x90 0x78 0x56 0x34 0x12)
    [20..21] eth_type:  hardcoded in tx_datapath (0x08 0x00)
    [22..59] payload:   38 bytes from FIFO
    [60..63] FCS:       CRC-32 over [8..59]
*)

open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm
open! Helper_tb_functions

let () = print_endline "=== Running MAC TX Top Testbench ==="

module Sim = Cyclesim.With_interface(Mac_top.I)(Mac_top.O)

let create_sim () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim   = Sim.create ~config:Cyclesim.Config.trace_all (Mac_top.create scope) in
  let waves, sim = Waveform.create sim in
  let inputs  : _ Mac_top.I.t = Cyclesim.inputs  sim in
  let outputs : _ Mac_top.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)

(* ── SW CRC-32 reference (reflected poly 0xEDB88320, init/finalXOR 0xFFFFFFFF) ── *)
let sw_crc_bit crc bit =
  let feedback = ((crc land 1) lxor bit) land 1 in
  let shifted  = crc lsr 1 in
  if feedback = 1 then shifted lxor 0xEDB88320 else shifted

let sw_crc_byte crc byte =
  let crc = ref crc in
  for i = 0 to 7 do crc := sw_crc_bit !crc ((byte lsr i) land 1) done;
  !crc

let sw_crc bytes =
  List.fold bytes ~init:0xFFFFFFFF ~f:sw_crc_byte
  |> fun raw -> raw lxor 0xFFFFFFFF

let bytes_of_int ~n x = 
  List.init n ~f:(fun i -> (x lsr (8 * i)) land 0xFF)

(* ── nibble collector + byte reassembler ── *)

(* 
   Read all nibbles that come out of tx_d while tx_en is 1
   Waits up to [max_wait] cycles for tx_en to first assert, then collects until
   it deasserts

   Returns the reassembled byte list (lo nibble first per byte)
*)

let collect_frame ~cycle ~outputs ~max_wait =
  let tx_en () = Bits.to_bool    !(outputs.Mac_top.O.tx_en) in (* ! grabs value from a container ref *)
  let tx_d  () = Bits.to_int_trunc !(outputs.Mac_top.O.tx_d) in
  let nibbles = ref [] in
  (* wait for first tx_en *)
  let waiting = ref true in
  let i = ref 0 in
  while !waiting && !i < max_wait do
    if tx_en ()
    then waiting := false
    else (cycle (); incr i)
  done;
  (* collect while tx_en is high *)
  while tx_en () do
    nibbles := !nibbles @ [tx_d ()];
    cycle ()
  done;
  (* reassemble pairs [lo; hi] → byte *)
  let rec pair = function
    | lo :: hi :: rest -> ((hi lsl 4) lor lo) :: pair rest
    | _ -> []
  in
  pair !nibbles

(* ── tb ── *)
let () =
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in

  Out_channel.with_file "waves_tx_top.vcd" ~f:(fun oc ->
  let sim = Vcd.wrap oc sim in

  let cycle () = Cyclesim.cycle sim in

  let reset () =
    inputs.reset        <-- 1;
    inputs.en           <-- 0;
    inputs.tx_start     <-- 0;
    inputs.s_axis_tvalid <-- 0;
    inputs.rx_dv        <-- 0;
    cycle ();
    inputs.reset <-- 0;
    inputs.en    <-- 1;
  in

  (* hardcoded frame header constants from tx_datapath.ml *)
  let exp_dst_mac  = [0x12; 0x34; 0x56; 0x78; 0x90; 0xAB] in
  let exp_src_mac  = [0xAB; 0x90; 0x78; 0x56; 0x34; 0x12] in
  let exp_eth_type = [0x08; 0x00] in

  (* 38-byte payload: sequential values 0x01..0x26 for easy inspection *)
  let payload_bytes = List.init 38 ~f:(fun i -> i + 1) in

  (* SW reference FCS covers everything after preamble, before FCS itself *)
  let frame_for_crc = exp_dst_mac @ exp_src_mac @ exp_eth_type @ payload_bytes in
  let expected_fcs  = bytes_of_int ~n:4 (sw_crc frame_for_crc) in
  printf "SW reference FCS = %02x %02x %02x %02x\n"
    (List.nth_exn expected_fcs 0) (List.nth_exn expected_fcs 1)
    (List.nth_exn expected_fcs 2) (List.nth_exn expected_fcs 3);

  (* ── test 1: frame structure and payload round-trip ── *)
  printf "\n-- [test 1] TX frame structure --\n";
  reset ();

  (* fill FIFO with payload before asserting tx_start *)
  List.iter payload_bytes ~f:(fun b ->
    inputs.s_axis_tdata  <-- b;
    inputs.s_axis_tvalid <-- 1;
    cycle ()
  );
  inputs.s_axis_tvalid <-- 0;

  (* pulse tx_start for one cycle *)
  inputs.tx_start <-- 1;
  cycle ();
  inputs.tx_start <-- 0;

  (* collect the frame off the MII pins *)
  let frame = collect_frame ~cycle ~outputs ~max_wait:300 in

  printf "frame length: %d bytes (expect 64)\n" (List.length frame);
  List.iteri frame ~f:(fun i b -> printf "  [%2d] 0x%02x\n" i b);

  (* parse and check *)
  let check_region name offset expected =
    let n = List.length expected in
    let got = List.sub frame ~pos:offset ~len:n in (* List.sub slices a list, this returns a subset of it as another List object *)
    let ok  = List.equal Int.equal got expected in
    printf "%s @ [%d..%d]: %s\n" name offset (offset + n - 1) (if ok then "PASS" else "FAIL");
    if not ok then begin
      printf "  expected: %s\n"
        (String.concat ~sep:" " (List.map expected ~f:(sprintf "%02x")));
      printf "  got:      %s\n"
        (String.concat ~sep:" " (List.map got     ~f:(sprintf "%02x")))
    end;
    ok
  in

  let exp_preamble = List.init 7 ~f:(fun _ -> 0x55) in

  let t1_preamble  = check_region "preamble " 0  exp_preamble   in
  let t1_sfd       = check_region "sfd      " 7  [0xD5]         in
  let t1_dst_mac   = check_region "dst_mac  " 8  exp_dst_mac    in
  let t1_src_mac   = check_region "src_mac  " 14 exp_src_mac    in
  let t1_eth_type  = check_region "eth_type " 20 exp_eth_type   in
  let t1_payload   = check_region "payload  " 22 payload_bytes  in

  let t1_fcs = check_region "fcs      " 60 expected_fcs in

  let t1_ok = t1_preamble && t1_sfd && t1_dst_mac && t1_src_mac && t1_eth_type && t1_payload && t1_fcs in
  printf "test 1: %s\n" (if t1_ok then "PASS" else "FAIL");

  print_endline "\n=== SIMULATION COMPLETE ===";
  Waveform.print ~display_width:100 waves;
  )
