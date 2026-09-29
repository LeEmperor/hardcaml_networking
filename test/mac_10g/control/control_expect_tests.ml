open! Core
open! Control_testbench

let%expect_test "separated AW/W, delayed B handshake, acknowledged configuration" =
  let id, maximum, bvalid_before_data, bresp, scratch, tx, rx = golden () in
  print_s
    [%sexp
      (id : int)
      , (maximum : int)
      , (bvalid_before_data : int)
      , (bresp : int)
      , (scratch : int)
      , (tx : configuration)
      , (rx : configuration)];
  [%expect
    {|
    (1296122673 1518 0 0 305419896
     ((tx_enable 1) (rx_enable 1) (drop_bad_rx 1) (maximum 1518))
     ((tx_enable 1) (rx_enable 1) (drop_bad_rx 1) (maximum 1518)))
    |}]
;;
