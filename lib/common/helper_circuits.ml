open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

let falling_edge_detector 
  spec
  x
  =
    let x_d = Signal.reg spec x in
    (x_d) &: (~:x)
;;

let rising_edge_detector 
  spec
  x
  =
    let x_d = Signal.reg spec x in
    (~:x_d) &: (x)
;;

let delay_by (spec) ~n_cycles x =
  let rec loop n acc =
    if n = 0 then acc
    else loop (n - 1) (Signal.reg spec acc)
  in
  loop n_cycles x
;;

let falling_edge_delayed spec ~n_cycles x =
  let fell = falling_edge_detector spec x in
  delay_by spec ~n_cycles fell
;;

let rising_edge_delayed spec ~n_cycles x = 
  let rose= rising_edge_detector spec x in
  delay_by spec ~n_cycles rose
;;

