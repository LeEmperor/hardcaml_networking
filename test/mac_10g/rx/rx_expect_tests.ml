(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "rx_expect_tests.ml" *)

open! Core
open! Rx_testbench

let%expect_test "bad-FCS descriptor and counters" =
  let payload = List.init 60 ~f:(fun index -> index) in
  let result = Testbench.run (encode_frame ~start_lane:4 ~bad_fcs:true payload) in
  print_s [%sexp (result : Result.t)];
  [%expect
    {|
    ((payload
      (0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27
       28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52
       53 54 55 56 57 58 59))
     (final_user (true)) (good_frames 0) (bad_frames 1) (bytes 64) (fcs_errors 1)
     (length_errors 0) (xgmii_errors 0) (overflow_drops 0)
     (stable_while_stalled true) (final_state 0) (saw_local_fault false)
     (saw_remote_fault false))
    |}]
;;
