(* University of Florida *)
(* Author: Bohdan Purtell *)

open! Core
open! Hardcaml_verif
open! Tx_testbench

let bytes length = List.init length ~f:(fun n -> ((n * 37) + length) land 0xff)

let%test_unit "all final keep widths, padding boundary, and termination lanes decode" =
  let lengths = List.range 14 74 in
  let frames = List.map lengths ~f:bytes in
  let observations = frames |> List.concat_map ~f:Beat.of_frame |> Testbench.run in
  [%test_result: int list list]
    (decode_frames observations)
    ~expect:(List.map frames ~f:expected_wire_frame);
  [%test_result: int list]
    (termination_lanes observations |> List.dedup_and_sort ~compare:Int.compare)
    ~expect:(List.range 0 8);
  let gaps = interframe_idle_counts observations in
  check_dic_gaps gaps;
  [%test_result: int] (List.length gaps) ~expect:(List.length frames - 1);
  [%test_result: int list]
    (start_lanes observations |> List.dedup_and_sort ~compare:Int.compare)
    ~expect:[ 0; 4 ];
  let final = List.last_exn observations in
  [%test_result: int] final.frames ~expect:(List.length frames);
  [%test_result: int]
    final.bytes
    ~expect:
      (List.sum (module Int) frames ~f:(fun frame -> Int.max 60 (List.length frame) + 4));
  [%test_result: int] final.underflows ~expect:0
;;

let%test_unit "long random frame sequences preserve bytes, CRC, and DIC schedule" =
  let frame_generator = Generators.byte_list ~min_length:14 ~max_length:251 () in
  let sequence_generator = Quickcheck.Generator.list_with_length 24 frame_generator in
  Quickcheck.test
    ~trials:20
    ~seed:(`Deterministic "mac-10g-line-rate-sequences")
    ~sexp_of:[%sexp_of: int list list]
    sequence_generator
    ~f:(fun frames ->
      let observations = frames |> List.concat_map ~f:Beat.of_frame |> Testbench.run in
      [%test_result: int list list]
        (decode_frames observations)
        ~expect:(List.map frames ~f:expected_wire_frame);
      check_dic_gaps (interframe_idle_counts observations);
      [%test_result: int list]
        (start_lanes observations |> List.dedup_and_sort ~compare:Int.compare)
        ~expect:[ 0; 4 ];
      let final = List.last_exn observations in
      [%test_result: int] final.frames ~expect:(List.length frames);
      [%test_result: int] final.underflows ~expect:0)
;;

let%test_unit "back-to-back minimum frames use the line-rate DIC schedule" =
  let frames = List.init 128 ~f:(fun index -> bytes (14 + (index land 1))) in
  let observations = frames |> List.concat_map ~f:Beat.of_frame |> Testbench.run in
  [%test_result: int list list]
    (decode_frames observations)
    ~expect:(List.map frames ~f:expected_wire_frame);
  let gaps = interframe_idle_counts observations in
  check_dic_gaps gaps;
  [%test_result: int] (List.length gaps) ~expect:(List.length frames - 1);
  assert (List.for_all gaps ~f:(fun gap -> gap <= 15));
  [%test_result: int list]
    (start_lanes observations |> List.dedup_and_sort ~compare:Int.compare)
    ~expect:[ 0; 4 ];
  let final = List.last_exn observations in
  [%test_result: int] final.frames ~expect:(List.length frames);
  [%test_result: int] final.underflows ~expect:0
;;

let%test_unit "arbitrary pre-commit AXI gaps cannot cause wire underflow" =
  let frame_generator = Generators.byte_list ~min_length:14 ~max_length:180 () in
  Quickcheck.test
    ~trials:60
    ~seed:(`Deterministic "mac-10g-functional-tx")
    ~sexp_of:[%sexp_of: int list]
    frame_generator
    ~f:(fun frame ->
      let observations =
        Testbench.run
          ~gaps:(fun cycle -> cycle mod 5 = 1 || cycle mod 11 = 3)
          (Beat.of_frame frame)
      in
      [%test_result: int list list]
        (decode_frames observations)
        ~expect:[ expected_wire_frame frame ];
      [%test_result: int] (List.last_exn observations).underflows ~expect:0)
;;

let%test_unit "tuser, illegal keeps, and illegal lengths roll back whole frames" =
  let good = bytes 32 in
  let bad_keep =
    [ { Beat.bytes = bytes 8; keep = 0xff; last = false; user = false }
    ; { Beat.bytes = bytes 3; keep = 0x05; last = true; user = false }
    ]
  in
  let too_short = Beat.of_frame (bytes 13) in
  let observations =
    Testbench.run
      (Beat.of_frame ~user:true (bytes 20) @ bad_keep @ too_short @ Beat.of_frame good)
  in
  [%test_result: int list list]
    (decode_frames observations)
    ~expect:[ expected_wire_frame good ];
  let final = List.last_exn observations in
  [%test_result: int] final.frames ~expect:1;
  [%test_result: int] final.drops ~expect:3;
  [%test_result: int] final.malformed ~expect:2
;;

(* [max_supported_frame_length] is 255 here and the byte ring is 256 deep, so at most 251
   frame bytes are ever stored. A frame that runs past that has to be rejected on the beat
   that crosses the limit: deferring the check to the final beat lets the ring fill, and a
   full ring holding an uncommitted frame stalls ingress until the frame ends, which the
   testbench sees as a timeout rather than a drop. *)
let%test_unit "over-length frames are rejected before they can fill the byte ring" =
  let good = bytes 40 in
  let observations = Testbench.run (Beat.of_frame (bytes 300) @ Beat.of_frame good) in
  [%test_result: int list list]
    (decode_frames observations)
    ~expect:[ expected_wire_frame good ];
  let final = List.last_exn observations in
  [%test_result: int] final.frames ~expect:1;
  [%test_result: int] final.drops ~expect:1;
  [%test_result: int] final.malformed ~expect:1
;;

let%test_unit "the largest legal frame transmits and one byte more is dropped" =
  let largest = bytes 251 in
  [%test_result: int list list]
    (decode_frames (Testbench.run (Beat.of_frame largest)))
    ~expect:[ expected_wire_frame largest ];
  let observations = Testbench.run (Beat.of_frame (bytes 252)) in
  [%test_result: int list list] (decode_frames observations) ~expect:[];
  let final = List.last_exn observations in
  [%test_result: int] final.frames ~expect:0;
  [%test_result: int] final.drops ~expect:1;
  [%test_result: int] final.malformed ~expect:1
;;

let%test_unit "TX counter clear resets every owning-domain statistic and sticky event" =
  let final =
    Testbench.run ~clear_counters:true (Beat.of_frame (bytes 80)) |> List.last_exn
  in
  [%test_result: int] final.frames ~expect:0;
  [%test_result: int] final.bytes ~expect:0;
  [%test_result: int] final.drops ~expect:0;
  [%test_result: int] final.malformed ~expect:0;
  [%test_result: int] final.underflows ~expect:0;
  [%test_result: bool] final.underflow_sticky ~expect:false
;;
