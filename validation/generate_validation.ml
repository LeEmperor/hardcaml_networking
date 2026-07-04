(*
  Emits the validation harness RTL for the unified TX/RX Vivado project.
  Writes mac_top_validation_harness.v into this directory; add that file (plus
  constraints/unified_tx_rx.xdc) as sources to validation/vivado25_project.

  Run:  ./scripts/with-switch.sh dune exec validation/generate_validation.exe
*)

open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Signal

module Circ =
  Circuit.With_interface
    (Mac_top_validation_harness.I)
    (Mac_top_validation_harness.O)

let () =
  let scope = Scope.create ~flatten_design:false () in
  let circ =
    Circ.create_exn ~name:"mac_top_validation_harness"
      (Mac_top_validation_harness.create scope)
  in
  let hier = Rtl.create Verilog [ circ ] in
  let rtl = Rtl.full_hierarchy hier in
  (* Anchor the output to the repo root so it lands next to the Vivado project no
     matter which directory [dune exec] was invoked from. DUNE_SOURCEROOT is set
     by dune at runtime; fall back to cwd when running the raw binary. *)
  let root = Option.value (Sys.getenv "DUNE_SOURCEROOT") ~default:"." in
  let out = Filename.concat root "validation/mac_top_validation_harness.v" in
  Out_channel.write_all out ~data:(Rope.to_string rtl);
  Stdio.printf "wrote %s\n" out
;;

