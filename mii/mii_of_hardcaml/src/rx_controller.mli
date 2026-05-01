(* 
  Bohdan Purtell
  University of Florida

  Interface: Rx_controller
  This module serves interface to an FSM controller for a Hardcaml ethernet MAC.
*)

open! Core
open! Hardcaml

module I : sig
  type 'a t = {
    (* spec *)
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* control lines  *)
    rx_dv : 'a;
    rx_er : 'a;
    
    (* data line -> rxd presents Preamble/SFD *)
    rx_data       : 'a [@bits 8];
    rx_data_valid : 'a;
  } [@@deriving hardcaml]
end

module O : sig
  type 'a t = {
    byte_assembler_en : 'a;
    payload_sel : 'a;
    dst_mac_reg_en : 'a;
    src_mac_reg_en : 'a;

    (* debug lines *)
    debug_state_vec       : 'a [@bits 3];
    debug_stable          : 'a;
    debug_byte_valid      : 'a;
    debug_en              : 'a;
    debug_d_in            : 'a [@bits 8];
  } [@@deriving hardcaml ]
end

val create : Signal.t I.t -> Signal.t O.t

