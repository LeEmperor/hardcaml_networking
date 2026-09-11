(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_control_types.ml" *)
(* Direction-neutral values exchanged by the register file and domain mailboxes. *)

open! Core
open! Hardcaml

module Configuration = struct
  type 'a t =
    { tx_enable : 'a
    ; rx_enable : 'a
    ; drop_bad_rx : 'a
    ; max_frame_length : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

module Command = struct
  type 'a t =
    { snapshot : 'a
    ; clear : 'a
    ; tx_soft_reset : 'a
    ; rx_soft_reset : 'a
    }
  [@@deriving hardcaml]
end

module Tx_counters = struct
  type 'a t =
    { frames : 'a [@bits 64]
    ; bytes : 'a [@bits 64]
    ; drops : 'a [@bits 64]
    ; malformed_axi : 'a [@bits 64]
    ; underflow : 'a [@bits 64]
    }
  [@@deriving hardcaml]
end

module Rx_counters = struct
  type 'a t =
    { good_frames : 'a [@bits 64]
    ; bad_frames : 'a [@bits 64]
    ; bytes : 'a [@bits 64]
    ; fcs_errors : 'a [@bits 64]
    ; length_errors : 'a [@bits 64]
    ; xgmii_errors : 'a [@bits 64]
    ; overflow : 'a [@bits 64]
    }
  [@@deriving hardcaml]
end
