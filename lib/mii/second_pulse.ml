(*
  Module: Second_pulse
  Single-cycle 1 Hz pulse generator. Ported from second_pulse.sv.
  Counter width is Int.ceil_log2 clk_freq (27 bits at 100 MHz).
*)

open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported Second Pulse ==="

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    pulse : 'a;
    keep  : 'a;
  } [@@deriving hardcaml]
end

(* [clk_freq] defaults to 100 MHz (Arty A7 system clock).
   Width is computed at elaboration time so no functor is needed. *)
let create
    ?(clk_freq = 100_000_000)
    (_scope : Scope.t)
    (i : _ I.t)
    : _ O.t =
  let open Always in
  let open Variable in
  let rising_edge = Reg_spec.create ~clock:i.I.clk ~clear:i.I.rst () in
  let width = Int.ceil_log2 clk_freq in
  let cnt   = reg ~enable:vdd rising_edge ~width in
  let pulse = reg ~enable:vdd rising_edge ~width:1 in
  compile [
    pulse <--. 0;
    if_ (cnt.value ==: of_int_trunc ~width (clk_freq - 1)) [
      cnt   <--. 0;
      pulse <--. 1;
    ] [
      cnt <-- cnt.value +:. 1;
    ];
  ];
  ignore (cnt.value   -- "cnt");
  ignore (pulse.value -- "pulse");
  { O. pulse = pulse.value; keep = pulse.value }
;;
