open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

(* TODO: how does this work? its a 1F && ~1F it appears? *)
(* does this map to a reg as the output, or a wire combo'd of the prev value *)
let falling_edge_detector 
  spec
  x
  =
    let x_d = Signal.reg spec x in
    (x_d) &: (~:x)
;; (* on an edge, if the old value of the register is high, and the new value is low, then falling edge found *)

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

let rising_edge_delayed spec ~n_cycles x t = 
  let rose= rising_edge_detector spec x in
  delay_by spec ~n_cycles rose
;;

