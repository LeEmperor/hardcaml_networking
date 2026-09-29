open! Core
open! Hardcaml
open! Top_testbench

let%test_unit "three-clock top loopback covers padding, every tail, stalls and snapshots" =
  List.iter
    [ 7, 4, 11; 3, 7, 5 ]
    ~f:(fun (axi_half, tx_half, rx_half) ->
      let t = create ~axi_half ~tx_half ~rx_half () in
      [%test_result: int] (read_ok t 0) ~expect:0x4d414331;
      write_ok t 0x08 3;
      let lengths = [ 14; 59; 60; 61; 62; 63; 64; 65; 66; 67; 68; 69; 70; 71; 251 ] in
      List.iteri lengths ~f:(fun j length ->
        t.wire_words <- [];
        send_frame t ~gap:(j mod 4 * 9) (payload length);
        advance t 1200;
        let words = List.rev t.wire_words in
        set t t.sim.input.m_axis_rx_tready_i 0;
        inject t words;
        advance t 200;
        set t t.sim.input.m_axis_rx_tready_i 1;
        advance t 1200);
      [%test_result: frame list]
        t.frames
        ~expect:
          (List.map lengths ~f:(fun length ->
             { bytes =
                 payload length @ List.init (Int.max 0 (60 - length)) ~f:(Fn.const 0)
             ; bad = false
             }));
      snapshot t;
      [%test_result: int] (read_ok t 0x100) ~expect:(List.length lengths);
      [%test_result: int] (read_ok t 0x180) ~expect:(List.length lengths);
      let wire_bytes = List.sum (module Int) lengths ~f:(fun len -> Int.max 60 len + 4) in
      [%test_result: int] (read_ok t 0x108) ~expect:wire_bytes;
      [%test_result: int] (read_ok t 0x190) ~expect:wire_bytes;
      [%test_result: int] (read_ok t 0x120) ~expect:0;
      write_ok t 0x1c 3;
      [%test_result: int] (read_ok t 0x100) ~expect:(List.length lengths);
      snapshot t;
      List.iter
        [ 0x100
        ; 0x108
        ; 0x110
        ; 0x118
        ; 0x120
        ; 0x180
        ; 0x188
        ; 0x190
        ; 0x198
        ; 0x1a0
        ; 0x1a8
        ; 0x1b0
        ]
        ~f:(fun address -> [%test_result: int] (read_ok t address) ~expect:0))
;;

let%test_unit "runtime TX limit and disable are applied at accepted frame boundaries" =
  let t = create () in
  write_ok t 0x08 3;
  send_beat t ~last:false (List.take (payload 100) 8);
  write_ok t 0x10 64;
  write_ok t 0x08 2;
  send_frame t (List.drop (payload 100) 8);
  advance t 300;
  [%test_result: int] (get t.sim.output.s_axis_tx_tready_o) ~expect:0;
  write_ok t 0x08 3;
  advance t 1000;
  send_frame t (payload 61);
  send_frame t (payload 60);
  advance t 1000;
  snapshot t;
  [%test_result: int] (read_ok t 0x100) ~expect:2;
  [%test_result: int] (read_ok t 0x110) ~expect:1;
  [%test_result: int] (read_ok t 0x118) ~expect:1;
  [%test_result: int] (read_ok t 0x14 land 3) ~expect:3
;;

let%test_unit "small elaborations bound default limits before software programs them" =
  let t = create ~maximum:64 () in
  [%test_result: int] (read_ok t 0x10) ~expect:1518;
  write_ok t 0x08 3;
  send_frame t (payload 80);
  send_frame t (payload 60);
  inject t (encode (payload 80));
  inject t (encode (payload 60));
  advance t 1500;
  snapshot t;
  [%test_result: int] (read_ok t 0x100) ~expect:1;
  [%test_result: int] (read_ok t 0x110) ~expect:1;
  [%test_result: int] (read_ok t 0x1a0) ~expect:1;
  [%test_result: frame list] t.frames ~expect:[ { bytes = payload 60; bad = false } ]
;;

let%test_unit "RX length changes wait for the next start and stalled verdict stays stable"
  =
  let t = create ~axi_half:2 ~rx_half:11 () in
  write_ok t 0x08 3;
  start_inject t (encode ~lane:4 (payload 100));
  advance t 60;
  write_ok t 0x10 64;
  wait t ~label:"frame end" (fun () -> List.is_empty t.rx_pending);
  advance t 1000;
  set t t.sim.input.m_axis_rx_tready_i 0;
  inject t (encode ~bad:true (payload 60));
  advance t 200;
  write_ok t 0x08 4;
  advance t 200;
  set t t.sim.input.m_axis_rx_tready_i 1;
  advance t 1000;
  [%test_result: frame list]
    t.frames
    ~expect:[ { bytes = payload 100; bad = false }; { bytes = payload 60; bad = true } ];
  write_ok t 0x08 7;
  inject t (encode ~bad:true (payload 60));
  advance t 1000;
  [%test_result: int] (List.length t.frames) ~expect:2;
  snapshot t;
  [%test_result: int] (read_ok t 0x188) ~expect:2;
  [%test_result: int] (read_ok t 0x198) ~expect:2
;;

let%test_unit "RX overflow, fault IRQ rearming and soft-reset recovery are connected" =
  let t = create () in
  write_ok t 0x08 3;
  write_ok t 0x18 0xf00;
  set t t.sim.input.m_axis_rx_tready_i 0;
  List.iter (List.range 0 7) ~f:(fun _ -> inject t (encode (payload 60)));
  advance t 300;
  snapshot t;
  assert (read_ok t 0x1b0 > 0);
  assert (read_ok t 0x0c land 0x200 <> 0);
  [%test_result: int] (get t.sim.output.irq_o) ~expect:1;
  t.resetting <- true;
  write_ok t 0x08 0x203;
  advance t 1000;
  t.stalled <- None;
  t.resetting <- false;
  set t t.sim.input.m_axis_rx_tready_i 1;
  inject t (encode (payload 60));
  advance t 1000;
  [%test_result: frame list] t.frames ~expect:[ { bytes = payload 60; bad = false } ];
  [%test_result: int] (read_ok t 0x0c land 0x200) ~expect:0;
  let fault = { data = Bits.of_hex ~width:64 "0100009c0100009c"; control = 0x11 } in
  inject t [ fault; fault; fault ];
  advance t 1000;
  assert (read_ok t 0x14 land 0x400 <> 0);
  write_ok t 0x14 0xf00;
  advance t 1000;
  [%test_result: int] (get t.sim.output.irq_o) ~expect:0;
  inject t [ fault ];
  advance t 1000;
  [%test_result: int] (get t.sim.output.irq_o) ~expect:1
;;

let%test_unit "disabling TX on the wire completes the frame and independent TX reset \
               recovers"
  =
  let t = create ~axi_half:2 ~tx_half:11 () in
  write_ok t 0x08 3;
  t.wire_words <- [];
  send_frame t (payload 251);
  advance t 60;
  write_ok t 0x08 2;
  advance t 1200;
  inject t (List.rev t.wire_words);
  advance t 1200;
  [%test_result: frame list] t.frames ~expect:[ { bytes = payload 251; bad = false } ];
  write_ok t 0x08 3;
  send_beat t ~last:false (payload 8);
  set t t.sim.input.tx_reset_i 1;
  advance t 100;
  [%test_result: int] (get t.sim.output.s_axis_tx_tready_o) ~expect:0;
  set t t.sim.input.tx_reset_i 0;
  advance t 100;
  t.wire_words <- [];
  send_frame t (payload 60);
  advance t 1000;
  inject t (List.rev t.wire_words);
  advance t 1000;
  [%test_result: frame list]
    t.frames
    ~expect:[ { bytes = payload 251; bad = false }; { bytes = payload 60; bad = false } ];
  snapshot t;
  [%test_result: int] (read_ok t 0x100) ~expect:1;
  [%test_result: int] (read_ok t 0x180) ~expect:2
;;

let%test_unit "generated full-duplex traffic and errors retain independent counters" =
  let t = create ~axi_half:5 ~tx_half:7 ~rx_half:4 () in
  write_ok t 0x08 3;
  let rng = Random.State.make [| 0x10_6006 |] in
  let lengths = List.init 16 ~f:(fun _ -> 60 + Random.State.int rng 192) in
  List.iteri lengths ~f:(fun index length ->
    start_inject
      t
      (encode ~lane:(4 * (index mod 2)) ~bad:(index mod 3 = 0) (payload length));
    send_frame t ~user:(index mod 4 = 0) ~gap:(Random.State.int rng 15) (payload length);
    wait t ~label:"peer completion" (fun () -> List.is_empty t.rx_pending);
    advance t 1000);
  [%test_result: frame list]
    t.frames
    ~expect:
      (List.mapi lengths ~f:(fun index length ->
         { bytes = payload length; bad = index mod 3 = 0 }));
  snapshot t;
  [%test_result: int] (read_ok t 0x100) ~expect:12;
  [%test_result: int] (read_ok t 0x110) ~expect:4;
  [%test_result: int] (read_ok t 0x118) ~expect:0;
  [%test_result: int] (read_ok t 0x180) ~expect:10;
  [%test_result: int] (read_ok t 0x188) ~expect:6;
  [%test_result: int] (read_ok t 0x198) ~expect:6
;;

let%test_unit "TX read stage preserves continuous minimum-frame DIC scheduling" =
  let t = create () in
  write_ok t 0x08 3;
  t.wire_words <- [];
  for index = 0 to 63 do
    send_frame t (payload (14 + (index land 1)))
  done;
  advance t 2000;
  let positions code =
    List.concat_mapi (List.rev t.wire_words) ~f:(fun cycle word ->
      List.filter_map (List.range 0 8) ~f:(fun lane ->
        let byte =
          Bits.select word.data ~high:((8 * lane) + 7) ~low:(8 * lane)
          |> Bits.to_int_trunc
        in
        if word.control land (1 lsl lane) <> 0 && byte = code
        then Some ((8 * cycle) + lane)
        else None))
  in
  let starts = positions 0xfb in
  let terms = positions 0xfd in
  [%test_result: int] (List.length starts) ~expect:64;
  [%test_result: int] (List.length terms) ~expect:64;
  [%test_result: int list]
    (List.map starts ~f:(fun p -> p mod 8) |> List.dedup_and_sort ~compare:Int.compare)
    ~expect:[ 0; 4 ];
  let gaps =
    List.map2_exn (List.tl_exn starts) (List.drop_last_exn terms) ~f:(fun start term ->
      start - term - 1)
  in
  let sum = ref 0 in
  List.iteri gaps ~f:(fun index gap ->
    assert (gap >= 9 && gap <= 15);
    sum := !sum + gap;
    assert (!sum >= (12 * (index + 1)) - 3));
  snapshot t;
  [%test_result: int] (read_ok t 0x100) ~expect:64;
  [%test_result: int] (read_ok t 0x120) ~expect:0
;;

let%test_unit "default MTU boundary round-trips through the complete MAC" =
  let t = create ~maximum:1518 ~depth:2048 () in
  write_ok t 0x08 3;
  List.iter [ 1513; 1514 ] ~f:(fun length ->
    t.wire_words <- [];
    send_frame t (payload length);
    advance t 2000;
    inject t (List.rev t.wire_words);
    advance t 5000);
  send_frame t (payload 1515);
  t.wire_words <- [];
  send_frame t (payload 60);
  advance t 2000;
  inject t (List.rev t.wire_words);
  advance t 1000;
  [%test_result: frame list]
    t.frames
    ~expect:
      (List.map [ 1513; 1514; 60 ] ~f:(fun length ->
         { bytes = payload length; bad = false }));
  snapshot t;
  [%test_result: int] (read_ok t 0x100) ~expect:3;
  [%test_result: int] (read_ok t 0x110) ~expect:1;
  [%test_result: int] (read_ok t 0x118) ~expect:1;
  [%test_result: int] (read_ok t 0x180) ~expect:3;
  [%test_result: int] (read_ok t 0x108) ~expect:3099;
  [%test_result: int] (read_ok t 0x190) ~expect:3099
;;
