open! Core
open! Control_testbench

let%test_unit "independent AW/W channels, byte strobes, and stalled responses" =
  let t = create () in
  let expected = ref 0 in
  Quickcheck.test
    ~trials:64
    ~seed:(`Deterministic "mac-10g-axi-lite")
    Quickcheck.Generator.(
      tuple4 (Int.gen_incl 0 0xffffffff) (Int.gen_incl 0 15) bool (Int.gen_incl 0 80))
    ~sexp_of:[%sexp_of: int * int * bool * int]
    ~f:(fun (data, strb, w_first, gap) ->
      let mask =
        List.init 4 ~f:(fun n -> if strb land (1 lsl n) <> 0 then 0xff lsl (8 * n) else 0)
        |> List.fold ~init:0 ~f:( lor )
      in
      expected := !expected land lnot mask lor (data land mask);
      [%test_result: int] (write ~strb ~w_first ~gap ~stall:3 t 0x20 data) ~expect:0;
      [%test_result: response]
        (read ~stall:3 t 0x20)
        ~expect:{ data = !expected; resp = 0 })
;;

let%test_unit "ABI decode, reserved bits, RO writes and maximum validation" =
  let t = create () in
  [%test_result: int] (read_ok t 0) ~expect:0x4d414331;
  [%test_result: int] (read_ok t 4) ~expect:0x01000000;
  List.iter [ 0; 4; 12; 0x100; 0x184 ] ~f:(fun address -> write_ok t address 0xffffffff);
  [%test_result: int] (read_ok t 0) ~expect:0x4d414331;
  List.iter [ 1; 2; 3; 0x24; 0x126; 0x128; 0x1b8; 0xffc ] ~f:(fun address ->
    [%test_result: int] (write t address 7) ~expect:2;
    [%test_result: response] (read ~stall:2 t address) ~expect:{ data = 0; resp = 2 });
  List.iter [ 0; 63; 2049; 65535 ] ~f:(fun value ->
    [%test_result: int] (write t 0x10 value) ~expect:2;
    [%test_result: int] (read_ok t 0x10) ~expect:1518);
  write_ok t 0x10 2048;
  [%test_result: int] (write ~strb:1 t 0x10 0x40) ~expect:2;
  [%test_result: int] (read_ok t 0x10) ~expect:2048;
  [%test_result: int] (write ~strb:12 t 0x10 0xffffffff) ~expect:0;
  [%test_result: int] (read_ok t 0x10) ~expect:2048;
  write_ok t 0x10 64;
  [%test_result: int] (read_ok t 0x10) ~expect:64;
  [%test_result: int] (write ~strb:0 t 8 0xffffffff) ~expect:0;
  [%test_result: int] (read_ok t 8) ~expect:0;
  [%test_result: int] (write ~strb:1 t 8 0xffffffff) ~expect:0;
  [%test_result: int] (read_ok t 8) ~expect:7;
  [%test_result: int] t.commands.tx_reset ~expect:0;
  [%test_result: int] t.commands.rx_reset ~expect:0;
  write_ok t 0x18 0xffffffff;
  [%test_result: int] (read_ok t 0x18) ~expect:0xf07
;;

let%test_unit "small elaborations preserve the frozen reset ABI and constrain writes" =
  let t = create ~maximum:128 () in
  [%test_result: int] (read_ok t 0x10) ~expect:1518;
  [%test_result: int] (write ~strb:0 t 0x10 0) ~expect:0;
  [%test_result: int] (write ~strb:12 t 0x10 0xffffffff) ~expect:0;
  [%test_result: int] (write t 0x10 129) ~expect:2;
  write_ok t 0x10 128;
  [%test_result: int] (configuration t.sim.output.tx_configuration_o).maximum ~expect:128
;;

let%test_unit "read and write progress independently and RDATA remains latched" =
  let t = create () in
  write_ok t 0x20 10;
  begin_read t 0x20;
  write_ok t 0x20 20;
  [%test_result: response] (finish_read ~stall:5 t) ~expect:{ data = 10; resp = 0 };
  [%test_result: int] (read_ok t 0x20) ~expect:20;
  send_aw t 0x20;
  [%test_result: int] (read_ok t 0) ~expect:0x4d414331;
  send_w t ~data:30 ~strb:15;
  [%test_result: int] (finish_write t) ~expect:0
;;

let%test_unit "configuration arrives atomically before successful write response" =
  List.iter
    [ 3, 11, 7; 13, 2, 5; 5, 17, 3 ]
    ~f:(fun (axi_half, tx_half, rx_half) ->
      let t = create ~axi_half ~tx_half ~rx_half () in
      List.iter [ 64; 1518; 2048; 1522 ] ~f:(fun maximum ->
        write_ok t 0x10 maximum;
        List.iter [ 0; 7; 1; 2; 4 ] ~f:(fun control ->
          let old_tx = configuration t.sim.output.tx_configuration_o in
          let old_rx = configuration t.sim.output.rx_configuration_o in
          t.tx_configurations <- [];
          t.rx_configurations <- [];
          write_ok t 8 control;
          let expected =
            { tx_enable = control land 1
            ; rx_enable = (control lsr 1) land 1
            ; drop_bad_rx = (control lsr 2) land 1
            ; maximum
            }
          in
          [%test_result: configuration]
            (configuration t.sim.output.tx_configuration_o)
            ~expect:expected;
          [%test_result: configuration]
            (configuration t.sim.output.rx_configuration_o)
            ~expect:expected;
          assert (
            List.for_all t.tx_configurations ~f:(fun c ->
              equal_configuration c old_tx || equal_configuration c expected));
          assert (
            List.for_all t.rx_configurations ~f:(fun c ->
              equal_configuration c old_rx || equal_configuration c expected)))))
;;

let%test_unit "simultaneous AW/W and same-edge interrupt set/clear" =
  let t = create () in
  [%test_result: int] (write_simultaneous t 0x20 123) ~expect:0;
  [%test_result: int] (read_ok t 0x20) ~expect:123;
  [%test_result: int] (irq_set_wins ()) ~expect:1
;;

let%test_unit "all counter words snapshot, freeze, and clear with exactly one command" =
  let t = create () in
  let tx = List.init 5 ~f:(fun n -> ((n + 1) lsl 32) + 0xfffffff0 + n) in
  let rx = List.init 7 ~f:(fun n -> ((n + 11) lsl 32) + n) in
  set_counters t ~tx ~rx;
  [%test_result: int] (counter t 0x100 0) ~expect:0;
  write_ok t 0x1c 1;
  set_counters t ~tx:(List.init 5 ~f:(fun _ -> 99)) ~rx:(List.init 7 ~f:(fun _ -> 88));
  List.iteri tx ~f:(fun n expected ->
    [%test_result: int] (counter t 0x100 n) ~expect:expected);
  List.iteri rx ~f:(fun n expected ->
    [%test_result: int] (counter t 0x180 n) ~expect:expected);
  write_ok t 0x1c 2;
  [%test_result: int] t.commands.tx_clear ~expect:1;
  [%test_result: int] t.commands.rx_clear ~expect:1;
  [%test_result: int] (counter t 0x100 0) ~expect:(List.hd_exn tx);
  write_ok t 0x1c 1;
  [%test_result: int] (counter t 0x100 0) ~expect:0;
  [%test_result: int] (counter t 0x180 0) ~expect:0;
  set_counters t ~tx ~rx;
  write_ok t 0x1c 3;
  [%test_result: int] (counter t 0x100 0) ~expect:(List.hd_exn tx);
  [%test_result: int] (counter t 0x180 0) ~expect:(List.hd_exn rx);
  [%test_result: int] t.commands.tx_clear ~expect:2;
  [%test_result: int] t.commands.rx_clear ~expect:2;
  [%test_result: int] (read_ok t 0x1c) ~expect:0;
  [%test_result: int] (write ~strb:0 t 0x1c 3) ~expect:0;
  [%test_result: int] t.commands.tx_clear ~expect:2
;;

let%test_unit "snapshot banks are coherent while owner counters cross low-word wrap" =
  let t = create ~axi_half:3 ~tx_half:7 ~rx_half:19 () in
  let initial = (3 lsl 32) - 10 in
  set_counters
    t
    ~tx:(List.init 5 ~f:(fun n -> initial + (n * 10000)))
    ~rx:(List.init 7 ~f:(fun n -> initial + (n * 10000)));
  t.count <- true;
  for _ = 1 to 8 do
    write_ok t 0x1c 1;
    let tx = counter t 0x100 0 in
    let rx = counter t 0x180 0 in
    for n = 1 to 4 do
      [%test_result: int] (counter t 0x100 n) ~expect:(tx + (n * 10000))
    done;
    for n = 1 to 6 do
      [%test_result: int] (counter t 0x180 n) ~expect:(rx + (n * 10000))
    done
  done
;;

let%test_unit "narrow events survive faster owner clocks and W1C can rearm" =
  let t = create ~axi_half:17 ~tx_half:2 ~rx_half:3 () in
  event t ~tx:true 7;
  event t ~tx:false 0xf00;
  advance t 1000;
  [%test_result: int] (read_ok t 0x14) ~expect:0xf07;
  [%test_result: int] (get t.sim.output.irq_o) ~expect:0;
  write_ok t 0x18 0xf07;
  [%test_result: int] (get t.sim.output.irq_o) ~expect:1;
  [%test_result: int] (write ~strb:1 t 0x14 0xffffffff) ~expect:0;
  [%test_result: int] (read_ok t 0x14) ~expect:0xf00;
  [%test_result: int] (write ~strb:0 t 0x14 0xffffffff) ~expect:0;
  [%test_result: int] (read_ok t 0x14) ~expect:0xf00;
  write_ok t 0x14 0xf00;
  advance t 1000;
  [%test_result: int] (read_ok t 0x14) ~expect:0;
  [%test_result: int] (get t.sim.output.irq_o) ~expect:0;
  event t ~tx:true 1;
  advance t 1000;
  [%test_result: int] (read_ok t 0x14) ~expect:1;
  set t t.sim.input.tx_status_i 0xffffffff;
  set t t.sim.input.rx_status_i 0xffffffff;
  advance t 1000;
  [%test_result: int] (read_ok t 0x0c) ~expect:0x3030f
;;

let%test_unit "old snapshot remains visible until both domains acknowledge" =
  let t = create () in
  set_counters t ~tx:[ 1; 2; 3; 4; 5 ] ~rx:[ 6; 7; 8; 9; 10; 11; 12 ];
  write_ok t 0x1c 1;
  set_counters t ~tx:[ 11; 12; 13; 14; 15 ] ~rx:[ 16; 17; 18; 19; 20; 21; 22 ];
  set t t.sim.input.rx_reset_i 1;
  advance t 50;
  send_aw t 0x1c;
  send_w t ~data:1 ~strb:15;
  advance t 500;
  [%test_result: int] (get t.sim.output.s_axi_bvalid_o) ~expect:0;
  [%test_result: int] (counter t 0x100 0) ~expect:1;
  [%test_result: int] (counter t 0x180 0) ~expect:6;
  set t t.sim.input.rx_reset_i 0;
  [%test_result: int] (finish_write t) ~expect:0;
  [%test_result: int] (counter t 0x100 0) ~expect:11;
  [%test_result: int] (counter t 0x180 0) ~expect:16
;;

let%test_unit "data reset pauses pending commands and cannot replay a completed toggle" =
  let t = create () in
  write_ok t 8 3;
  set t t.sim.input.rx_reset_i 1;
  advance t 50;
  send_aw t 8;
  send_w t ~data:0x303 ~strb:15;
  advance t 500;
  [%test_result: int] (get t.sim.output.s_axi_bvalid_o) ~expect:0;
  [%test_result: int] t.commands.tx_reset ~expect:1;
  [%test_result: int] t.commands.rx_reset ~expect:0;
  set t t.sim.input.rx_reset_i 0;
  [%test_result: int] (finish_write ~stall:10 t) ~expect:0;
  [%test_result: int] t.commands.rx_reset ~expect:1;
  set t t.sim.input.tx_reset_i 1;
  set t t.sim.input.rx_reset_i 1;
  advance t 100;
  set t t.sim.input.tx_reset_i 0;
  set t t.sim.input.rx_reset_i 0;
  advance t 500;
  [%test_result: int] t.commands.tx_reset ~expect:1;
  [%test_result: int] t.commands.rx_reset ~expect:1;
  write_ok t 8 0x303;
  [%test_result: int] t.commands.tx_reset ~expect:2;
  [%test_result: int] t.commands.rx_reset ~expect:2
;;

(* A single sampling edge is enough to clear a counter but not to drive a datapath reset
   tree, so the CDC holds the soft-reset output for its elaborated number of owner-clock
   cycles. The command count below is rising edges; the cycle count is sampling edges. *)
let%test_unit "soft reset is held for the elaborated number of owner cycles" =
  let t = create ~soft_reset_cycles:8 () in
  write_ok t 8 0x303;
  advance t 1000;
  [%test_result: int] t.commands.tx_reset ~expect:1;
  [%test_result: int] t.commands.rx_reset ~expect:1;
  [%test_result: int] t.commands.tx_reset_cycles ~expect:8;
  [%test_result: int] t.commands.rx_reset_cycles ~expect:8;
  write_ok t 8 0x303;
  advance t 1000;
  [%test_result: int] t.commands.tx_reset ~expect:2;
  [%test_result: int] t.commands.rx_reset ~expect:2;
  [%test_result: int] t.commands.tx_reset_cycles ~expect:16;
  [%test_result: int] t.commands.rx_reset_cycles ~expect:16
;;

let%test_unit "AXI reset flushes partial transactions, stalled responses and a pending \
               CDC command"
  =
  let t = create ~axi_half:3 ~tx_half:13 ~rx_half:17 () in
  let reset () =
    set t t.sim.input.axi_reset_i 1;
    axi_cycle t;
    [%test_result: int] (get t.sim.output.s_axi_bvalid_o) ~expect:0;
    [%test_result: int] (get t.sim.output.s_axi_rvalid_o) ~expect:0;
    set t t.sim.input.axi_reset_i 0;
    advance t 300
  in
  send_aw t 0x20;
  reset ();
  send_w t ~data:99 ~strb:15;
  advance t 100;
  [%test_result: int] (get t.sim.output.s_axi_bvalid_o) ~expect:0;
  reset ();
  write_ok t 0x20 44;
  begin_read t 0x20;
  send_aw t 0x20;
  send_w t ~data:55 ~strb:15;
  wait t ~label:"stalled B" (fun () -> get t.sim.output.s_axi_bvalid_o = 1);
  reset ();
  [%test_result: int] (read_ok t 0x20) ~expect:0;
  set t t.sim.input.tx_reset_i 1;
  set t t.sim.input.rx_reset_i 1;
  advance t 100;
  send_aw t 0x1c;
  send_w t ~data:2 ~strb:15;
  advance t 100;
  reset ();
  set t t.sim.input.tx_reset_i 0;
  set t t.sim.input.rx_reset_i 0;
  advance t 300;
  [%test_result: int] t.commands.tx_clear ~expect:0;
  [%test_result: int] t.commands.rx_clear ~expect:0;
  write_ok t 8 7;
  [%test_result: int] (configuration t.sim.output.tx_configuration_o).tx_enable ~expect:1
;;
