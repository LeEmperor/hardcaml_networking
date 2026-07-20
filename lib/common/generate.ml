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
     dune exec lib/common/generate.exe -- udp-validation
     dune exec lib/common/generate.exe -- udp-rx-validation

   Targets:
     mac                standalone Ethernet MAC            -> hardcaml_eth_mac.v
     udp                UDP-over-MAC stack                 -> hardcaml_udp_with_mac.v
     validation         board MAC validation harness       -> validation/mac_top_validation_harness.v
     udp-validation     board UDP-over-MAC TX validation harness -> validation/udp_mac_top_validation_harness.v
     udp-rx-validation  board UDP-over-MAC RX validation harness -> validation/udp_rx_mac_top_validation_harness.v

   The board-harness targets instantiate the same tops that used to live in
   validation/generate_validation.exe (now folded in here). *)

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

module Circ_udp_validation =
  Circuit.With_interface
    (Udp_mac_top_validation_harness.I)
    (Udp_mac_top_validation_harness.O)

module Circ_udp_rx_validation =
  Circuit.With_interface
    (Udp_rx_mac_top_validation_harness.I)
    (Udp_rx_mac_top_validation_harness.O)

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

let udp_validation_cmd =
  target
    ~summary:
      "board UDP-over-MAC validation harness -> validation/udp_mac_top_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~path:"validation/udp_mac_top_validation_harness.v"
        (Circ_udp_validation.create_exn
           ~name:"udp_mac_top_validation_harness"
           (Udp_mac_top_validation_harness.create scope)))
;;

let udp_rx_validation_cmd =
  target
    ~summary:
      "board UDP-over-MAC RX validation harness -> validation/udp_rx_mac_top_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~path:"validation/udp_rx_mac_top_validation_harness.v"
        (Circ_udp_rx_validation.create_exn
           ~name:"udp_rx_mac_top_validation_harness"
           (Udp_rx_mac_top_validation_harness.create scope)))
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:"Hardcaml RTL generators (pick a target)"
       [ "mac", mac_cmd
       ; "udp", udp_cmd
       ; "validation", validation_cmd
       ; "udp-validation", udp_validation_cmd
       ; "udp-rx-validation", udp_rx_validation_cmd
       ])
;;
