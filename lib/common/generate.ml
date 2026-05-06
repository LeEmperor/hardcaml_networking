open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Signal

module Circ = Circuit.With_interface (Mac_top.I) (Mac_top.O)

let () =
  Stdio.print_endline "============ Begin Generation Phase =============== ";

  let scope = Scope.create ~flatten_design:false () in
  let circ = Circ.create_exn ~name:"mac_top" (Mac_top.create scope) in
  let hier = Rtl.create Verilog [circ] in
  let rtl  = Rtl.full_hierarchy hier in
  Out_channel.write_all "mac_top.v" ~data:(Rope.to_string rtl)

