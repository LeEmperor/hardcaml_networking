(* University of Florida *)
(* Author: Bohdan Purtell *)

open! Core
open! Tx_testbench

let%expect_test "short-frame TX phase trace" =
  Testbench.run (Beat.of_frame (List.range 0 14))
  |> List.filter_mapi ~f:(fun cycle snapshot ->
    if cycle < 4 || snapshot.Snapshot.control <> 0xff || snapshot.state <> 0
    then Some (cycle, snapshot.state, snapshot.control, snapshot.frames, snapshot.bytes)
    else None)
  |> List.iter ~f:(fun row -> print_s [%sexp (row : int * int * int * int * int)]);
  [%expect
    {|
    (0 0 255 0 0)
    (1 0 255 0 0)
    (2 0 1 0 0)
    (3 1 0 0 0)
    (4 1 0 0 0)
    (5 2 0 0 0)
    (6 2 0 0 0)
    (7 2 0 0 0)
    (8 2 0 0 0)
    (9 2 0 0 0)
    (10 2 0 0 0)
    (11 3 255 0 0)
    |}]
;;

let%expect_test "DIC alternates legal start alignments" =
  let frames = List.init 6 ~f:(fun index -> List.init 14 ~f:(fun byte -> index + byte)) in
  Testbench.run (List.concat_map frames ~f:Beat.of_frame)
  |> List.iteri ~f:(fun cycle ({ Snapshot.lanes; control; _ } : Snapshot.t) ->
    List.iteri lanes ~f:(fun lane value ->
      if control land (1 lsl lane) <> 0 && (value = 0xfb || value = 0xfd)
      then
        print_s
          [%sexp
            ((cycle, (if value = 0xfb then "start" else "terminate"), lane)
             : int * string * int)]));
  [%expect
    {|
    (2 start 0)
    (11 terminate 0)
    (12 start 4)
    (21 terminate 4)
    (23 start 0)
    (32 terminate 0)
    (33 start 4)
    (42 terminate 4)
    (44 start 4)
    (53 terminate 4)
    (55 start 0)
    (64 terminate 0)
    |}]
;;
