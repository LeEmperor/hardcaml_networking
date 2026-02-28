(** this is intended to be the instantiator of the sink, source, and phy interfacecs*)

open Hardcaml
open Base
open Rx_sink
open Tx_source
open Rgmii_phy

module I = struct
  type 'a t = {
    phy : 'a Rgmii_phy.I.t; (* this is a whole interface, kinda like SV interfaces *)
    tx_source : 'a Tx_source.I.t;
    rx_sink : 'a Rx_sink.I.t;
  } [@@deriving hardcaml]
end

(* where does MDC and MDIO go?*)

module O = struct
  type 'a t = {
    phy : 'a Rgmii_phy.O.t;
    tx_source : 'a Tx_source.O.t;
    rx_sink : 'a Rx_sink.O.t;
  } [@@deriving hardcaml]
end

let create 
  _scope  (* overarching global reg scope *)
  inputs
  = 
  let open Signal in
  (*begin logic*)



  (*end logic*)
  ();;

let () = 
  Stdio.print_endline "bruh"
