open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Hardcaml_waveterm
open! Helper_tb_functions

let () = print_endline "=== Running MAC RX Top Testbench ==="

module Waveform = Hardcaml_waveterm.Waveform
module Sim = Cyclesim.With_interface(Mac_top.I)(Mac_top.O)

let create_sim () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim   = Sim.create ~config:Cyclesim.Config.trace_all (Mac_top.create ~rx_fifo_for_sim:true scope) in
  let waves, sim = Waveform.create sim in
  let inputs  : _ Mac_top.I.t = Cyclesim.inputs  sim in
  let outputs : _ Mac_top.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)

(* SW CRC-32 reference (reflected poly 0xEDB88320, init 0xFFFFFFFF, no final XOR) *)
let sw_crc_bit crc bit =
  let feedback = ((crc land 1) lxor bit) land 1 in
  let shifted   = crc lsr 1 in
  if feedback = 1 then shifted lxor 0xEDB88320 else shifted

let sw_crc_byte crc byte =
  let crc = ref crc in
  for i = 0 to 7 do crc := sw_crc_bit !crc ((byte lsr i) land 1) done;
  !crc

let sw_crc bytes = List.fold bytes ~init:0xFFFFFFFF ~f:sw_crc_byte

(* extract n bytes from an OCaml int, LSB first — matches send_bytes ordering *)
let bytes_of_int ~n x = List.init n ~f:(fun i -> (x lsr (8 * i)) land 0xFF)

(* CRC-32 of frame_bytes in little-endian, ready to feed as FCS *)
let compute_fcs frame_bytes =
  let crc32 = (sw_crc frame_bytes) lxor 0xFFFF_FFFF in
  bytes_of_int ~n:4 crc32

let () =
  let open Bits in
  let sim, waves, inputs, outputs = create_sim () in

  Out_channel.with_file "waves_top.vcd" ~f:(fun oc ->
  let sim = Vcd.wrap oc sim in

  let t_rst_rx = inputs.rx_reset in
  let t_rst_tx = inputs.tx_reset in
  let t_en     = inputs.en in
  let t_in     = inputs.rx_data in
  let t_rx_dv  = inputs.rx_dv in
  let t_tready = inputs.m_axis_tready in

  let cycle () = Cyclesim.cycle sim in

  let reset () =
    t_tready <-- 0;
    t_en     <-- 0;
    t_rst_rx <-- 1;
    t_rst_tx <-- 1;
    t_rx_dv  <-- 0;
    cycle ();
    t_en     <-- 1;
    t_rst_rx <-- 0;
    t_rst_tx <-- 0;
  in

  let dst_mac     = 0x36_12_73_36_24_85 in
  let src_mac     = 0x37_52_33_76_94_05 in
  let eth_type    = 0x45_21 in
  let payload     = 0x12_34_56_78_90 in
  let payload_len = 5 in

  let frame_bytes =
    bytes_of_int ~n:6 dst_mac  @
    bytes_of_int ~n:6 src_mac  @
    bytes_of_int ~n:2 eth_type @
    bytes_of_int ~n:payload_len payload
  in
  let fcs_bytes = compute_fcs frame_bytes in
  printf "computed FCS = %02x %02x %02x %02x\n"
    (List.nth_exn fcs_bytes 0) (List.nth_exn fcs_bytes 1)
    (List.nth_exn fcs_bytes 2) (List.nth_exn fcs_bytes 3);

  let send_frame_with_fcs fcs =
    t_rx_dv <-- 1;
    send_frame ~cycle ~t_in "frame"
      ~dst_mac ~src_mac ~eth_type
      ~payload_length:payload_len ~payload;
    List.iter fcs ~f:(send_byte ~cycle ~t_in);
    t_rx_dv <-- 0;
    cycle ()   (* tlast_wr fires on this cycle *)
  in

  let collect_output () =
    let bytes_out = ref [] in
    let tlast_byte = ref None in
    let tuser_on_last = ref false in
    (* Sample BEFORE cycling: in cut-through FIFO the head word is already at
       the output.  Read while tvalid&tready, then cycle to advance to next word. *)
    for i = 0 to 30 do
      let v = Bits.to_bool    !(outputs.m_axis_tvalid) in
      let b = Bits.to_int_trunc !(outputs.m_axis_tdata) in
      let l = Bits.to_bool    !(outputs.m_axis_tlast) in
      let u = Bits.to_bool    !(outputs.m_axis_tuser) in
      printf "  [%2d] valid=%d data=0x%02x last=%d user=%d\n"
        i (if v then 1 else 0) b (if l then 1 else 0) (if u then 1 else 0);
      if v then begin
        bytes_out := !bytes_out @ [b];
        if l then begin
          tlast_byte    := Some b;
          tuser_on_last := u
        end
      end;
      cycle ()
    done;
    (!bytes_out, !tlast_byte, !tuser_on_last)
  in

  (* ── test 1: valid frame — expect tuser=0 on tlast ── *)
  printf "\n-- [test 1] valid FCS --\n";
  reset ();
  (* tready stays 0 (set by reset) so the FIFO buffers bytes while frame arrives;
     then we set tready=1 to drain and observe tlast/tuser *)
  send_frame_with_fcs fcs_bytes;
  t_tready <-- 1;
  let (got, last, user) = collect_output () in
  let expected = bytes_of_int ~n:payload_len payload in
  let t1_ok =
    List.equal Int.equal got expected
    && Option.is_some last
    && not user
  in
  printf "test 1: %s  (bytes_match=%b  got_tlast=%b  tuser=0=%b)\n"
    (if t1_ok then "PASS" else "FAIL")
    (List.equal Int.equal got expected)
    (Option.is_some last)
    (not user);

  (* ── test 2: bad FCS — expect tuser=1 on tlast ── *)
  printf "\n-- [test 2] bad FCS (all bytes inverted) --\n";
  reset ();
  let bad_fcs = List.map fcs_bytes ~f:(fun b -> b lxor 0xFF) in
  send_frame_with_fcs bad_fcs;
  t_tready <-- 1;
  let (_got2, last2, user2) = collect_output () in
  let t2_ok = Option.is_some last2 && user2 in
  printf "test 2: %s  (got_tlast=%b  tuser=1=%b)\n"
    (if t2_ok then "PASS" else "FAIL")
    (Option.is_some last2)
    user2;

  print_endline "\n=== SIMULATION COMPLETE ===";
  Waveform.print ~display_width:96 waves;
  )
