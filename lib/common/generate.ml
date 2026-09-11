open! Core
open! Hardcaml
open! Mii_of_hardcaml
open! Udp_of_hardcaml
open! Uart_of_hardcaml
open! Signal

(*
 * RTL generators, one subcommand per emittable artifact. Pick a target on the
 * command line instead of comment-toggling this file, e.g.:
 *
 *   dune exec lib/common/generate.exe -- mac
 *   dune exec lib/common/generate.exe -- udp
 *   dune exec lib/common/generate.exe -- mac-validation
 *   dune exec lib/common/generate.exe -- udp-tx-validation
 *   dune exec lib/common/generate.exe -- udp-rx-validation
 *   dune exec lib/common/generate.exe -- udp-loopback-validation
 *   dune exec lib/common/generate.exe -- u50-10g-tx-validation
 *
 * Targets:
 *   mac                    standalone Ethernet MAC        -> hardcaml_eth_mac.v
 *   udp                    UDP-over-MAC stack             -> hardcaml_udp_with_mac.v
 *   mac-validation         board MAC harness (bare MAC, both dirs) -> validation/mac_validation_harness.v
 *   udp-tx-validation      board UDP TX harness (fpga->laptop, btn[3]) -> validation/udp_tx_validation_harness.v
 *   udp-rx-validation      board UDP RX harness (laptop->fpga, 1B/s drain) -> validation/udp_rx_validation_harness.v
 *   udp-duplex-validation  board full-duplex UDP harness, DECOUPLED TX+RX -> validation/udp_duplex_validation_harness.v
 *   udp-loopback-validation board echo/loopback UDP harness, RX->TX bridge -> validation/udp_loopback_validation_harness.v
 *   u50-10g-tx-validation  Alveo U50 10G TX harness (autonomous source + Mac_10g_top)
 *                          -> validation/alveo_u50_10g/u50_mac_tx_harness.v
 *
 * Naming: the UDP full-duplex tops are distinguished by coupling --
 *   duplex   = independent TX + RX side-by-side on one Mac_top (no coupling)
 *   loopback = RX->TX bridge (echo); host-asserted RX validation.
 *
 * The board-harness targets instantiate the same tops that used to live in
 * validation/generate_validation.exe (now folded in here).
 *)

module Circ_mac = Circuit.With_interface (Mac_top.I) (Mac_top.O)
module Circ_udp = Circuit.With_interface (Udp_mac_top.I) (Udp_mac_top.O)

module Circ_validation =
  Circuit.With_interface (Mac_validation_harness.I) (Mac_validation_harness.O)

module Circ_udp_validation =
  Circuit.With_interface (Udp_tx_validation_harness.I) (Udp_tx_validation_harness.O)

module Circ_udp_rx_validation =
  Circuit.With_interface (Udp_rx_validation_harness.I) (Udp_rx_validation_harness.O)

module Circ_udp_duplex_validation =
  Circuit.With_interface
    (Udp_duplex_validation_harness.I)
    (Udp_duplex_validation_harness.O)

module Circ_udp_loopback_validation =
  Circuit.With_interface
    (Udp_loopback_validation_harness.I)
    (Udp_loopback_validation_harness.O)

(* Emit [circ] as hierarchical Verilog at [path]. [path] is resolved against the repo
   root: DUNE_SOURCEROOT is set by [dune exec] so the RTL always lands at a stable
   location rather than wherever the binary happened to run. *)
let emit ~scope ~path circ =
  let rtl =
    Rtl.full_hierarchy
      (Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circ ])
  in
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
      ~scope
      ~path:"hardcaml_eth_mac.v"
      (Circ_mac.create_exn ~name:"hardcaml_eth_mac" (Mac_top.create scope)))
;;

let mac_10g_cmd ~flatten =
  Command.basic
    ~summary:"full-duplex 10G XGMII MAC"
    (Command.Param.return (fun () ->
       let module M = Mac_10g_of_hardcaml.Mac_10g_top in
       let module C = Circuit.With_interface (M.I) (M.O) in
       let scope = Scope.create ~flatten_design:flatten () in
       emit
         ~scope
         ~path:(if flatten then "hardcaml_mac_10g_flat.v" else "hardcaml_mac_10g.v")
         (C.create_exn ~name:"mac_10g_top" (M.create scope))))
;;

let udp_cmd =
  target ~summary:"UDP-over-MAC stack -> hardcaml_udp_with_mac.v" ~build:(fun scope ->
    emit
      ~scope
      ~path:"hardcaml_udp_with_mac.v"
      (Circ_udp.create_exn ~name:"Udp_stack_w_mac" (Udp_mac_top.create scope)))
;;

let mac_validation_cmd =
  target
    ~summary:
      "board MAC harness (bare MAC, both dirs) -> validation/mac_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~scope
        ~path:"validation/mac_validation_harness.v"
        (Circ_validation.create_exn
           ~name:"mac_validation_harness"
           (Mac_validation_harness.create scope)))
;;

let udp_tx_validation_cmd =
  target
    ~summary:
      "board UDP TX harness (fpga->laptop, btn[3]) -> \
       validation/udp_tx_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~scope
        ~path:"validation/udp_tx_validation_harness.v"
        (Circ_udp_validation.create_exn
           ~name:"udp_tx_validation_harness"
           (Udp_tx_validation_harness.create scope)))
;;

let udp_rx_validation_cmd =
  target
    ~summary:
      "board UDP RX harness (laptop->fpga, 1B/s drain) -> \
       validation/udp_rx_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~scope
        ~path:"validation/udp_rx_validation_harness.v"
        (Circ_udp_rx_validation.create_exn
           ~name:"udp_rx_validation_harness"
           (Udp_rx_validation_harness.create scope)))
;;

let udp_duplex_validation_cmd =
  target
    ~summary:
      "board full-duplex UDP harness, DECOUPLED TX+RX -> \
       validation/udp_duplex_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~scope
        ~path:"validation/udp_duplex_validation_harness.v"
        (Circ_udp_duplex_validation.create_exn
           ~name:"udp_duplex_validation_harness"
           (Udp_duplex_validation_harness.create scope)))
;;

let udp_loopback_validation_cmd =
  target
    ~summary:
      "board echo/loopback UDP harness, RX->TX bridge -> \
       validation/udp_loopback_validation_harness.v"
    ~build:(fun scope ->
      emit
        ~scope
        ~path:"validation/udp_loopback_validation_harness.v"
        (Circ_udp_loopback_validation.create_exn
           ~name:"udp_loopback_validation_harness"
           (Udp_loopback_validation_harness.create scope)))
;;

(* Alveo U50 10G validation harnesses. Unlike the Arty tops these are not board tops: they
   are emitted to be instantiated inside u50_10g_top.sv alongside the AMD PCS/GT IP. See
   docs/mac_10g_u50_tx_validation_plan.md. *)
let u50_10g_tx_validation_cmd =
  target
    ~summary:"Alveo U50 10G TX harness -> validation/alveo_u50_10g/u50_mac_tx_harness.v"
    ~build:(fun scope ->
      let module C = Circuit.With_interface (U50_mac_tx_harness.I) (U50_mac_tx_harness.O)
      in
      emit
        ~scope
        ~path:"validation/alveo_u50_10g/u50_mac_tx_harness.v"
        (C.create_exn ~name:"u50_mac_tx_harness" (U50_mac_tx_harness.create scope)))
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:"Hardcaml RTL generators (pick a target)"
       [ "mac", mac_cmd
       ; "mac-10g", mac_10g_cmd ~flatten:false
       ; "mac-10g-flat", mac_10g_cmd ~flatten:true
       ; "udp", udp_cmd
       ; "mac-validation", mac_validation_cmd
       ; "udp-tx-validation", udp_tx_validation_cmd
       ; "udp-rx-validation", udp_rx_validation_cmd
       ; "udp-duplex-validation", udp_duplex_validation_cmd
       ; "udp-loopback-validation", udp_loopback_validation_cmd
       ; "u50-10g-tx-validation", u50_10g_tx_validation_cmd
       ])
;;
