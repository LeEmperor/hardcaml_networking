open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Uart_of_hardcaml
open! Signal

module Circ = Circuit.With_interface (Mac_top.I) (Mac_top.O)

let () =
  Stdio.print_endline "============ Begin Generate =============== ";

  Stdio.print_endline "============ Begin Create Phase =============== ";
  let scope = Scope.create ~flatten_design:false () in
  Stdio.print_endline "============ End Create Phase =============== \n";

  Stdio.print_endline "============ Begin Circuit Instantiation Phase =============== ";
  let circ = Circ.create_exn ~name:"hardcaml_eth_mac" (Mac_top.create scope) in
  let hier = Rtl.create Verilog [circ] in
  Stdio.print_endline "============ End Circuit Instantiation Phase =============== \n";

  Stdio.print_endline "============ Begin RTL Generation Phase =============== ";
  let rtl  = Rtl.full_hierarchy hier in
  Stdio.print_endline "============ End RTL Generation Phase =============== \n";

  Stdio.print_endline "============ Begin Output Phase =============== ";
  Out_channel.write_all "hardcaml_eth_mac.v" ~data:(Rope.to_string rtl);
  Stdio.print_endline "============ End Output Phase =============== \n";

  Stdio.print_endline "============ End Generate =============== \n";
;;

