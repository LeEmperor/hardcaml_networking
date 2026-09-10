(* University of Florida *)
(* Author: Bohdan Purtell *)

open! Core
open! Hardcaml
open! Signal
open! Mac_10g_of_hardcaml

module Parser = Mac_10g_rx.Make (struct
    let max_supported_frame_length = 1518
  end)

module Parser_circuit = Circuit.With_interface (Parser.I) (Parser.O)

module Egress = Mac_10g_rx_egress.Make (struct
    let error_width = Mac_10g_rx.Error.width
  end)

module Egress_circuit = Circuit.With_interface (Egress.I) (Egress.O)

let hierarchy_rtl create =
  let scope = Scope.create ~flatten_design:false () in
  let top = create scope in
  Rtl.create ~database:(Scope.circuit_database scope) Verilog [ top ]
  |> Rtl.full_hierarchy
  |> Rope.to_string
;;

let%test_unit "parser emits as an independent hierarchy" =
  let rtl =
    hierarchy_rtl (fun scope ->
      Parser_circuit.create_exn ~name:"rx_parser_parent" (Parser.hierarchical scope))
  in
  assert (String.is_substring rtl ~substring:"module mac_10g_rx_1518");
  assert (String.is_substring rtl ~substring:"module rx_parser_parent")
;;

let%test_unit "egress emits as an independent hierarchy" =
  let rtl =
    hierarchy_rtl (fun scope ->
      Egress_circuit.create_exn ~name:"rx_egress_parent" (Egress.hierarchical scope))
  in
  assert (String.is_substring rtl ~substring:"module mac_10g_rx_egress");
  assert (String.is_substring rtl ~substring:"module rx_egress_parent")
;;
