open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Udp_of_hardcaml
open! Uart_of_hardcaml
open! Signal

module Circ_MAC = Circuit.With_interface (Mac_top.I) (Mac_top.O)

module Udp = Udp.Make (struct 
  let bus_width = 8
  let bus_implementation = Udp.Bus_Implementation.BYTE_WISE
end)

module Circ_UDP = Circuit.With_interface (Udp.I) (Udp.O)

let () =
  Stdio.print_endline "============ Begin Generate =============== ";

  Stdio.print_endline "============ Begin Create Phase =============== ";
  let scope = Scope.create ~flatten_design:false () in
  Stdio.print_endline "============ End Create Phase =============== \n";

  Stdio.print_endline "============ Begin Circuit Instantiation Phase =============== ";
  (* let circ = Circ_MAC.create_exn ~name:"hardcaml_eth_mac" (Mac_top.create scope) in *)
  let circ = Circ_UDP.create_exn ~name:"Udp_stack_w_mac" (Udp.create scope) in
  let hier = Rtl.create Verilog [circ] in
  Stdio.print_endline "============ End Circuit Instantiation Phase =============== \n";

  Stdio.print_endline "============ Begin RTL Generation Phase =============== ";
  let rtl  = Rtl.full_hierarchy hier in
  Stdio.print_endline "============ End RTL Generation Phase =============== \n";

  Stdio.print_endline "============ Begin Output Phase =============== ";
  (* Anchor to the repo root (DUNE_SOURCEROOT is set by dune exec) so the RTL
     always lands there rather than wherever the binary happened to be run. *)
  let root = Option.value (Sys.getenv "DUNE_SOURCEROOT") ~default:"." in
  (* let out = Filename.concat root "hardcaml_eth_mac.v" in *)
  let out = Filename.concat root "hardcaml_udp_with_mac.v" in
  Out_channel.write_all out ~data:(Rope.to_string rtl);
  Stdio.printf "wrote %s\n" out;
  Stdio.print_endline "============ End Output Phase =============== \n";

  Stdio.print_endline "============ End Generate =============== \n";
;;

