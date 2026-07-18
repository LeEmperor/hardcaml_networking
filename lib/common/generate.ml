open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Udp_of_hardcaml
open! Uart_of_hardcaml
open! Signal

(* RTL generators, one subcommand per emittable artifact. Pick a target on the
   command line instead of comment-toggling this file, e.g.:

     dune exec lib/common/generate.exe -- mac
     dune exec lib/common/generate.exe -- udp
     dune exec lib/common/generate.exe -- validation

   Targets:
     mac         standalone Ethernet MAC              -> hardcaml_eth_mac.v
     udp         UDP-over-MAC stack                   -> hardcaml_udp_with_mac.v
     validation  board-level MAC validation harness   -> validation/mac_top_validation_harness.v

   The [validation] target instantiates the same board harness that used to live
   in validation/generate_validation.exe (now folded in here). *)

module Udp = Udp.Make (struct
  let bus_width = 8
  let bus_implementation = Udp.Bus_Implementation.BYTE_WISE
end)

module Circ_mac = Circuit.With_interface (Mac_top.I) (Mac_top.O)
module Circ_udp = Circuit.With_interface (Udp.I) (Udp.O)

module Circ_validation =
  Circuit.With_interface
    (Mac_top_validation_harness.I)
    (Mac_top_validation_harness.O)

(* Emit [circ] as hierarchical Verilog at [path]. [path] is resolved against the
   repo root: DUNE_SOURCEROOT is set by [dune exec] so the RTL always lands at a
   stable location rather than wherever the binary happened to run. *)
let emit ~path circ =
  let rtl = Rtl.full_hierarchy (Rtl.create Verilog [ circ ]) in
  let root = Option.value (Sys.getenv "DUNE_SOURCEROOT") ~default:"." in
  let out = Filename.concat root path in
  Out_channel.write_all out ~data:(Rope.to_string rtl);
  Stdio.printf "wrote %s\n" out
;;

(* Each target builds its circuit under a fresh scope, then emits. *)
let target ~summary ~build =
  Command.basic
    ~summary
    (Command.Param.return (fun () ->
       let scope = Scope.create ~flatten_design:false () in
       build scope))
;;

let mac_cmd =
  target ~summary:"standalone Ethernet MAC -> hardcaml_eth_mac.v" ~build:(fun scope ->
    emit
      ~path:"hardcaml_eth_mac.v"
      (Circ_mac.create_exn ~name:"hardcaml_eth_mac" (Mac_top.create scope)))
;;

let udp_cmd =
  target ~summary:"UDP-over-MAC stack -> hardcaml_udp_with_mac.v" ~build:(fun scope ->
    emit
      ~path:"hardcaml_udp_with_mac.v"
      (Circ_udp.create_exn ~name:"Udp_stack_w_mac" (Udp.create scope)))
;;

let validation_cmd =
  target
    ~summary:"board-level MAC validation harness -> validation/mac_top_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~path:"validation/mac_top_validation_harness.v"
        (Circ_validation.create_exn
           ~name:"mac_top_validation_harness"
           (Mac_top_validation_harness.create scope)))
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:"Hardcaml RTL generators (pick a target)"
       [ "mac", mac_cmd; "udp", udp_cmd; "validation", validation_cmd ])
;;
