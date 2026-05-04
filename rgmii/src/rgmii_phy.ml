open Hardcaml

(** this is intended to be the interface that directly ties to the PHY*)
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

