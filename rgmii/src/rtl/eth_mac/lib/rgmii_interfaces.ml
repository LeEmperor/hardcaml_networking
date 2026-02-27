open Hardcaml
open Base

module I = struct
  type 'a t = {
    rgmii_rxd : 'a [@bits 4]; (* transmit datapath *)
    rgmii_rxctl : 'a; (* transmit enable *)
    rgmii_rxc : 'a; (* receive clock*)
    reset_n : 'a; (* PHY reset - active low*)
  } [@@deriving hardcaml]
end

(* where does MDC and MDIO go?*)

module O = struct
  type 'a t = {
    rgmii_txd : 'a [@bits 4];
    rgmii_txctl : 'a;
    rgmii_txc : 'a;
  } [@@deriving hardcaml]
end

let create 
  _scope  (* overarching global reg scope *)
  inputs
  = 
  let open Signal in
  (*begin logic*)

  (* let rxd_rising = wire 4 in *)
  (* let rxctl_rising = wire 1 in *)
  (* let rxc_rising = wire 1 in *)

  (* thing I want to do: sample an edge of the clock, and use that to write values into a register *)

  let rising_spec: Reg_spec.t = Reg_spec.create ~clock:inputs.I.rgmii_rxc () in

  let falling_spec: Reg_spec.t = Reg_spec.create ~clock:inputs.I.rgmii_rxc () in
  let falling_spec: Reg_spec.t = Reg_spec.override falling_spec ~clock_edge:Edge.Falling in

  let rxd_rising: Signal.t = Signal.reg rising_spec inputs.I.rgmii_rxd in
  let rxd_falling: Signal.t = Signal.reg falling_spec inputs.I.rgmii_rxd in
  (* let rxd_falling2: Signal.t = Signal.reg _scope inputs.I.rgmii_rxd in *)

  (* let rx_byte: Signal.t = wire 8 in *)
  (* let rx_byte: Signal.t = Signal.concat [ rxd_falling; rxd_rising] in *)
  let rx_byte: Signal.t = rxd_falling @: rxd_rising in
  
  (*end logic*)
  (* { *)
  (*   O.rgmii_txd = inputs.I.rgmii_rxd; *)
  (*   rgmii_txctl = inputs.I.rgmii_rxctl; *)
  (*   rgmii_txc = inputs.I.rgmii_rxc; *)
  (* } *)
  (* let rx_byte = rxd_rising.q @: rxd_falling.q in *)
  {
    rx_byte;
  }
  ;;

let () = 
  print_endline "nothing lmao"
