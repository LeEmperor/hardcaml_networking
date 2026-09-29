open! Core
open! Hardcaml
open! Mac_10g_of_hardcaml
module Dut = Mac_10g_control
module C = Circuit.With_interface (Dut.I) (Dut.O)

let () =
  let scope = Scope.create ~flatten_design:false () in
  let circuit = C.create_exn ~name:"mac_10g_control_parent" (Dut.hierarchical scope) in
  let rtl =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
    |> Rtl.full_hierarchy
    |> Rope.to_string
  in
  Out_channel.write_all (Sys.get_argv ()).(1) ~data:rtl
;;
