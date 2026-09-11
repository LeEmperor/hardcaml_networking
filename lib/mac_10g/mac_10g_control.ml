(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_control.ml" *)
(* Three-clock control plane, independently usable before the full MAC composition.
   Data-domain status and events use the register ABI's bit positions. Counter records
   come directly from their owners; all outputs named tx_/rx_ belong to that domain.
*)

open! Core
open! Hardcaml
open! Signal
open! Mac_10g_control_types

module I = struct
  type 'a t =
    { axi_clock_i : 'a
    ; axi_reset_i : 'a
    ; tx_clock_i : 'a
    ; tx_reset_i : 'a
    ; rx_clock_i : 'a
    ; rx_reset_i : 'a
    ; s_axi_awaddr_i : 'a [@bits 12]
    ; s_axi_awvalid_i : 'a
    ; s_axi_wdata_i : 'a [@bits 32]
    ; s_axi_wstrb_i : 'a [@bits 4]
    ; s_axi_wvalid_i : 'a
    ; s_axi_bready_i : 'a
    ; s_axi_araddr_i : 'a [@bits 12]
    ; s_axi_arvalid_i : 'a
    ; s_axi_rready_i : 'a
    ; tx_counters_i : 'a Tx_counters.t
    ; rx_counters_i : 'a Rx_counters.t
    ; tx_status_i : 'a [@bits 32]
    ; rx_status_i : 'a [@bits 32]
    ; tx_events_i : 'a [@bits 32]
    ; rx_events_i : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { s_axi_awready_o : 'a
    ; s_axi_wready_o : 'a
    ; s_axi_bresp_o : 'a [@bits 2]
    ; s_axi_bvalid_o : 'a
    ; s_axi_arready_o : 'a
    ; s_axi_rdata_o : 'a [@bits 32]
    ; s_axi_rresp_o : 'a [@bits 2]
    ; s_axi_rvalid_o : 'a
    ; irq_o : 'a
    ; tx_configuration_o : 'a Configuration.t
    ; rx_configuration_o : 'a Configuration.t
    ; tx_counters_clear_o : 'a
    ; rx_counters_clear_o : 'a
    ; tx_soft_reset_o : 'a
    ; rx_soft_reset_o : 'a
    }
  [@@deriving hardcaml]
end

let create
  ?(max_supported_frame_length = 1518)
  ?(soft_reset_cycles = 16)
  scope
  (i : _ I.t)
  : _ O.t
  =
  let feedback = Mac_10g_cdc.O.map Mac_10g_cdc.O.port_widths ~f:wire in
  let regs =
    Mac_10g_regs.hierarchical
      ~max_supported_frame_length
      scope
      { clock_i = i.axi_clock_i
      ; reset_i = i.axi_reset_i
      ; s_axi_awaddr_i = i.s_axi_awaddr_i
      ; s_axi_awvalid_i = i.s_axi_awvalid_i
      ; s_axi_wdata_i = i.s_axi_wdata_i
      ; s_axi_wstrb_i = i.s_axi_wstrb_i
      ; s_axi_wvalid_i = i.s_axi_wvalid_i
      ; s_axi_bready_i = i.s_axi_bready_i
      ; s_axi_araddr_i = i.s_axi_araddr_i
      ; s_axi_arvalid_i = i.s_axi_arvalid_i
      ; s_axi_rready_i = i.s_axi_rready_i
      ; cdc_ready_i = feedback.ready_o
      ; cdc_done_i = feedback.done_o
      ; status_i = feedback.status_o
      ; events_i = feedback.events_o
      ; tx_snapshot_i = feedback.tx_snapshot_o
      ; rx_snapshot_i = feedback.rx_snapshot_o
      }
  in
  let cdc =
    Mac_10g_cdc.hierarchical
      ~max_supported_frame_length
      ~soft_reset_cycles
      scope
      { axi_clock_i = i.axi_clock_i
      ; axi_reset_i = i.axi_reset_i
      ; tx_clock_i = i.tx_clock_i
      ; tx_reset_i = i.tx_reset_i
      ; rx_clock_i = i.rx_clock_i
      ; rx_reset_i = i.rx_reset_i
      ; configuration_i = regs.configuration_o
      ; command_i = regs.command_o
      ; request_i = regs.request_o
      ; tx_counters_i = i.tx_counters_i
      ; rx_counters_i = i.rx_counters_i
      ; tx_status_i = i.tx_status_i
      ; rx_status_i = i.rx_status_i
      ; tx_events_i = i.tx_events_i
      ; rx_events_i = i.rx_events_i
      }
  in
  Mac_10g_cdc.O.iter2 feedback cdc ~f:assign;
  { O.s_axi_awready_o = regs.s_axi_awready_o
  ; s_axi_wready_o = regs.s_axi_wready_o
  ; s_axi_bresp_o = regs.s_axi_bresp_o
  ; s_axi_bvalid_o = regs.s_axi_bvalid_o
  ; s_axi_arready_o = regs.s_axi_arready_o
  ; s_axi_rdata_o = regs.s_axi_rdata_o
  ; s_axi_rresp_o = regs.s_axi_rresp_o
  ; s_axi_rvalid_o = regs.s_axi_rvalid_o
  ; irq_o = regs.irq_o
  ; tx_configuration_o = cdc.tx_configuration_o
  ; rx_configuration_o = cdc.rx_configuration_o
  ; tx_counters_clear_o = cdc.tx_counters_clear_o
  ; rx_counters_clear_o = cdc.rx_counters_clear_o
  ; tx_soft_reset_o = cdc.tx_soft_reset_o
  ; rx_soft_reset_o = cdc.rx_soft_reset_o
  }
;;

let hierarchical ?(max_supported_frame_length = 1518) ?(soft_reset_cycles = 16) scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical
    ~scope
    ~name:"mac_10g_control"
    (create ~max_supported_frame_length ~soft_reset_cycles)
    i
;;
