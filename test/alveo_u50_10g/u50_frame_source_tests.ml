open! Core
open! Hardcaml
module Sim = Cyclesim.With_interface (U50_frame_source.I) (U50_frame_source.O)

(* A short interval keeps the simulation quick; the real default is 156_250_000 cycles,
   which is one second at 156.25 MHz. Nothing about frame content depends on it. *)
let interval_cycles = 8

let create () =
  let scope = Scope.create ~flatten_design:true () in
  Sim.create (U50_frame_source.create ~interval_cycles scope)
;;

let set port value = port := Bits.of_int_trunc ~width:(Bits.width !port) value
let get port = Bits.to_int_trunc !port

(* Collect frames as byte lists by honouring the AXI4-Stream contract: sample a beat only
   when tvalid and tready are both high, and take only the tkeep-selected lanes.

   Cycling is split into phases, following the pattern in test/mac_10g/tx/tx_testbench.ml:
   drive, settle combinationally, sample, then clock. Using the monolithic
   [Cyclesim.cycle] and sampling afterwards reads outputs belonging to the next edge,
   which pairs each beat with the wrong tready and silently corrupts the capture under any
   backpressure. *)
let run ?(tready = fun _ -> true) ~cycles () =
  let sim = create () in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  set i.reset_i 1;
  set i.enable_i 1;
  set i.start_i 1;
  Cyclesim.cycle sim;
  set i.reset_i 0;
  let frames = ref [] in
  let current = ref [] in
  let pulses = ref 0 in
  for cycle = 0 to cycles - 1 do
    set i.s_axis_tready_i (if tready cycle then 1 else 0);
    Cyclesim.cycle_before_clock_edge sim;
    if get o.s_axis_tvalid_o = 1 && get i.s_axis_tready_i = 1
    then (
      let data = !(o.s_axis_tdata_o) in
      let keep = get o.s_axis_tkeep_o in
      for lane = 0 to 7 do
        if (keep lsr lane) land 1 = 1
        then
          current
          := Bits.to_int_trunc (Bits.select data ~high:((8 * lane) + 7) ~low:(8 * lane))
             :: !current
      done;
      if get o.s_axis_tlast_o = 1
      then (
        frames := List.rev !current :: !frames;
        current := []));
    if get o.frame_pulse_o = 1 then incr pulses;
    Cyclesim.cycle_at_clock_edge sim;
    Cyclesim.cycle_after_clock_edge sim
  done;
  List.rev !frames, !pulses
;;

let expected_frame sequence =
  List.concat
    [ List.init 6 ~f:(Fn.const 0xff)
    ; [ 0x02; 0x00; 0x00; 0x00; 0x00; 0x01 ]
    ; [ 0x99; 0x99 ]
    ; [ (sequence lsr 24) land 0xff
      ; (sequence lsr 16) land 0xff
      ; (sequence lsr 8) land 0xff
      ; sequence land 0xff
      ]
    ; List.init 42 ~f:(fun i -> i land 0xff)
    ]
;;

let%test_unit "frame content matches the plan's section 6.2 layout" =
  let frames, _ = run ~cycles:200 () in
  [%test_pred: int list list] (fun f -> not (List.is_empty f)) frames;
  let frame = List.hd_exn frames in
  (* 60 AXI bytes: the MAC adds the four FCS bytes, giving the 64-byte minimum wire frame.
     Anything shorter than 60 would be zero-padded by the MAC and the payload pattern
     would no longer end where the test expects. *)
  [%test_result: int] (List.length frame) ~expect:60;
  [%test_result: int list] frame ~expect:(expected_frame 0)
;;

let%test_unit "sequence numbers increment once per frame and pulse once per frame" =
  let frames, pulses = run ~cycles:400 () in
  [%test_pred: int] (fun n -> n >= 3) (List.length frames);
  List.iteri frames ~f:(fun index frame ->
    [%test_result: int list] frame ~expect:(expected_frame index));
  [%test_result: int] pulses ~expect:(List.length frames)
;;

(* The AXI4-Stream contract requires payload and sidebands to stay stable while valid and
   not ready. A source that advanced its beat counter on tvalid alone would emit corrupt
   frames under any real backpressure, and the MAC's ingress would see them as well-formed
   -- so this is worth proving rather than assuming. *)
let%test_unit "frames are intact under ready backpressure" =
  let frames, _ = run ~tready:(fun cycle -> cycle % 3 = 0) ~cycles:900 () in
  [%test_pred: int] (fun n -> n >= 2) (List.length frames);
  List.iteri frames ~f:(fun index frame ->
    [%test_result: int list] frame ~expect:(expected_frame index))
;;

let%test_unit "start_i gates transmission" =
  let sim = create () in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  set i.reset_i 1;
  Cyclesim.cycle sim;
  set i.reset_i 0;
  set i.enable_i 1;
  set i.start_i 0;
  set i.s_axis_tready_i 1;
  for _ = 0 to 99 do
    Cyclesim.cycle_before_clock_edge sim;
    [%test_result: int] (get o.s_axis_tvalid_o) ~expect:0;
    Cyclesim.cycle_at_clock_edge sim;
    Cyclesim.cycle_after_clock_edge sim
  done
;;
