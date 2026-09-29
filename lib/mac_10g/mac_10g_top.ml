(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_top.ml" *)
(* Full-duplex three-clock 10G XGMII MAC. The control mailbox remains alive during
   datapath soft reset; runtime configuration is applied at local frame boundaries.
*)

open! Core
open! Hardcaml
open! Signal
open! Xgmii_of_hardcaml

module Config = struct
  let minimum_wire_frame_length = 64
  let maximum_length_field_value = 0xffff
  let default_max_supported_frame_length = 1518
  let default_tx_buffer_depth_bytes = 8192
  let default_rx_buffer_depth_bytes = 8192
  let default_descriptor_capacity = 4

  let validate_buffer ~name ~depth_bytes ~max_supported_frame_length =
    if depth_bytes < max_supported_frame_length || not (Int.is_pow2 depth_bytes)
    then
      raise_s
        [%message
          "Mac_10g_top.create: buffer depth must be a power of two and at least the \
           maximum supported wire-frame length"
            (name : string)
            (depth_bytes : int)
            (max_supported_frame_length : int)]
  ;;

  let validate
    ~tx_buffer_depth_bytes
    ~rx_buffer_depth_bytes
    ~descriptor_capacity
    ~max_supported_frame_length
    =
    if max_supported_frame_length < minimum_wire_frame_length
       || max_supported_frame_length > maximum_length_field_value
    then
      raise_s
        [%message
          "Mac_10g_top.create: maximum supported wire-frame length must be in 64..65535"
            (max_supported_frame_length : int)];
    validate_buffer
      ~name:"TX"
      ~depth_bytes:tx_buffer_depth_bytes
      ~max_supported_frame_length;
    validate_buffer
      ~name:"RX"
      ~depth_bytes:rx_buffer_depth_bytes
      ~max_supported_frame_length;
    if descriptor_capacity < 2 || not (Int.is_pow2 descriptor_capacity)
    then
      raise_s
        [%message
          "Mac_10g_top.create: descriptor capacity must be a power of two and at least 2"
            (descriptor_capacity : int)]
  ;;
end

module I = struct
  type 'a t =
    { (* AXI4-Stream TX ingress and XGMII TX, synchronous to tx_clock_i. *)
      tx_clock_i : 'a
    ; tx_reset_i : 'a
    ; s_axis_tx_tdata_i : 'a [@bits 64]
    ; s_axis_tx_tkeep_i : 'a [@bits 8]
    ; s_axis_tx_tvalid_i : 'a
    ; s_axis_tx_tlast_i : 'a
    ; s_axis_tx_tuser_i : 'a
    ; (* XGMII RX and AXI4-Stream RX egress, synchronous to rx_clock_i. *)
      rx_clock_i : 'a
    ; rx_reset_i : 'a
    ; xgmii_rxd_i : 'a [@bits 64]
    ; xgmii_rxc_i : 'a [@bits 8]
    ; m_axis_rx_tready_i : 'a
    ; (* AXI4-Lite control plane, synchronous to axi_clock_i. *)
      axi_clock_i : 'a
    ; axi_reset_i : 'a
    ; s_axi_awaddr_i : 'a [@bits 12]
    ; s_axi_awvalid_i : 'a
    ; s_axi_wdata_i : 'a [@bits 32]
    ; s_axi_wstrb_i : 'a [@bits 4]
    ; s_axi_wvalid_i : 'a
    ; s_axi_bready_i : 'a
    ; s_axi_araddr_i : 'a [@bits 12]
    ; s_axi_arvalid_i : 'a
    ; s_axi_rready_i : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { (* AXI4-Stream TX ingress and XGMII TX, synchronous to tx_clock_i. *)
      s_axis_tx_tready_o : 'a
    ; xgmii_txd_o : 'a [@bits 64]
    ; xgmii_txc_o : 'a [@bits 8]
    ; (* AXI4-Stream RX egress, synchronous to rx_clock_i. *)
      m_axis_rx_tdata_o : 'a [@bits 64]
    ; m_axis_rx_tkeep_o : 'a [@bits 8]
    ; m_axis_rx_tvalid_o : 'a
    ; m_axis_rx_tlast_o : 'a
    ; m_axis_rx_tuser_o : 'a
    ; (* AXI4-Lite control plane and interrupt, synchronous to axi_clock_i. *)
      s_axi_awready_o : 'a
    ; s_axi_wready_o : 'a
    ; s_axi_bresp_o : 'a [@bits 2]
    ; s_axi_bvalid_o : 'a
    ; s_axi_arready_o : 'a
    ; s_axi_rdata_o : 'a [@bits 32]
    ; s_axi_rresp_o : 'a [@bits 2]
    ; s_axi_rvalid_o : 'a
    ; irq_o : 'a
    }
  [@@deriving hardcaml]
end

let create
  ?(tx_buffer_depth_bytes = Config.default_tx_buffer_depth_bytes)
  ?(rx_buffer_depth_bytes = Config.default_rx_buffer_depth_bytes)
  ?(descriptor_capacity = Config.default_descriptor_capacity)
  ?(max_supported_frame_length = Config.default_max_supported_frame_length)
  (scope : Scope.t)
  (i : _ I.t)
  : _ O.t
  =
  Config.validate
    ~tx_buffer_depth_bytes
    ~rx_buffer_depth_bytes
    ~descriptor_capacity
    ~max_supported_frame_length;
  let module Tx_buffer =
    Mac_10g_packet_buffer.Make (struct
      let depth_bytes = tx_buffer_depth_bytes
      let descriptor_capacity = descriptor_capacity
      let error_width = 1
    end)
  in
  let module Rx_buffer =
    Mac_10g_packet_buffer.Make (struct
      let depth_bytes = rx_buffer_depth_bytes
      let descriptor_capacity = descriptor_capacity
      let error_width = Mac_10g_rx.Error.width
    end)
  in
  let module Ingress =
    Mac_10g_tx_ingress.Make (struct
      let max_supported_frame_length = max_supported_frame_length
      let buffer_length_width = Tx_buffer.length_width
    end)
  in
  let module Rx =
    Mac_10g_rx.Make (struct
      let max_supported_frame_length = max_supported_frame_length
    end)
  in
  let module Egress =
    Mac_10g_rx_egress.Make (struct
      let error_width = Mac_10g_rx.Error.width
    end)
  in
  let module C = Mac_10g_control_types in
  let tx_counters = C.Tx_counters.map C.Tx_counters.port_widths ~f:wire in
  let rx_counters = C.Rx_counters.map C.Rx_counters.port_widths ~f:wire in
  let tx_status = wire 32 in
  let rx_status = wire 32 in
  let tx_events = wire 32 in
  let rx_events = wire 32 in
  let control =
    Mac_10g_control.hierarchical
      ~max_supported_frame_length
      scope
      { axi_clock_i = i.axi_clock_i
      ; axi_reset_i = i.axi_reset_i
      ; tx_clock_i = i.tx_clock_i
      ; tx_reset_i = i.tx_reset_i
      ; rx_clock_i = i.rx_clock_i
      ; rx_reset_i = i.rx_reset_i
      ; s_axi_awaddr_i = i.s_axi_awaddr_i
      ; s_axi_awvalid_i = i.s_axi_awvalid_i
      ; s_axi_wdata_i = i.s_axi_wdata_i
      ; s_axi_wstrb_i = i.s_axi_wstrb_i
      ; s_axi_wvalid_i = i.s_axi_wvalid_i
      ; s_axi_bready_i = i.s_axi_bready_i
      ; s_axi_araddr_i = i.s_axi_araddr_i
      ; s_axi_arvalid_i = i.s_axi_arvalid_i
      ; s_axi_rready_i = i.s_axi_rready_i
      ; tx_counters_i = tx_counters
      ; rx_counters_i = rx_counters
      ; tx_status_i = tx_status
      ; rx_status_i = rx_status
      ; tx_events_i = tx_events
      ; rx_events_i = rx_events
      }
  in
  (* Never feed soft reset back into the CDC command acceptance gate. *)
  let tx_reset = i.tx_reset_i |: control.tx_soft_reset_o in
  let rx_reset = i.rx_reset_i |: control.rx_soft_reset_o in
  let tx_spec = Reg_spec.create ~clock:i.tx_clock_i ~clear:tx_reset () in
  let rx_spec = Reg_spec.create ~clock:i.rx_clock_i ~clear:rx_reset () in
  let tx_feedback = Mac_10g_tx.O.map Mac_10g_tx.O.port_widths ~f:wire in
  let ingress_feedback = Ingress.O.map Ingress.O.port_widths ~f:wire in
  let rx_feedback = Rx.O.map Rx.O.port_widths ~f:wire in
  let egress_feedback = Egress.O.map Egress.O.port_widths ~f:wire in
  (* An elastic read stage isolates the asynchronous ring/descriptor read path from the
     formatter's CRC path. It prefetches while the formatter emits preamble/IFG, replaces
     a consumed beat on the same edge, and holds all sidebands under stall. *)
  let tx_read_valid = wire 1 in
  let tx_read_ready = ~:tx_read_valid |: tx_feedback.buffer_ready_o &: ~:tx_reset in
  let tx_buffer =
    Tx_buffer.hierarchical
      ~instance:"tx_buffer"
      scope
      { clock_i = i.tx_clock_i
      ; reset_i = tx_reset
      ; write_data_i = ingress_feedback.buffer_write_data_o
      ; write_keep_i = ingress_feedback.buffer_write_keep_o
      ; write_valid_i = ingress_feedback.buffer_write_valid_o
      ; commit_i = ingress_feedback.buffer_commit_o
      ; rollback_i = ingress_feedback.buffer_rollback_o
      ; commit_error_i = gnd
      ; read_ready_i = tx_read_ready
      }
  in
  let rx_buffer =
    Rx_buffer.hierarchical
      ~instance:"rx_buffer"
      scope
      { clock_i = i.rx_clock_i
      ; reset_i = rx_reset
      ; write_data_i = rx_feedback.buffer_write_data_o
      ; write_keep_i = rx_feedback.buffer_write_keep_o
      ; write_valid_i = rx_feedback.buffer_write_valid_o
      ; commit_i = rx_feedback.buffer_commit_o
      ; rollback_i = rx_feedback.buffer_rollback_o
      ; commit_error_i = rx_feedback.buffer_commit_error_o
      ; read_ready_i = egress_feedback.buffer_ready_o
      }
  in
  assign tx_read_valid (reg tx_spec ~enable:tx_read_ready tx_buffer.read_valid_o);
  let tx_read_data = reg tx_spec ~enable:tx_read_ready tx_buffer.read_data_o in
  let tx_read_keep = reg tx_spec ~enable:tx_read_ready tx_buffer.read_keep_o in
  let tx_read_last = reg tx_spec ~enable:tx_read_ready tx_buffer.read_last_o in
  let tx_configuration = control.tx_configuration_o in
  let rx_configuration = control.rx_configuration_o in
  let ingress =
    Ingress.hierarchical
      scope
      { clock_i = i.tx_clock_i
      ; reset_i = tx_reset
      ; enable_i = tx_configuration.tx_enable
      ; counters_clear_i = control.tx_counters_clear_o
      ; max_frame_length_i = tx_configuration.max_frame_length
      ; axis_data_i = i.s_axis_tx_tdata_i
      ; axis_keep_i = i.s_axis_tx_tkeep_i
      ; axis_valid_i = i.s_axis_tx_tvalid_i
      ; axis_last_i = i.s_axis_tx_tlast_i
      ; axis_user_i = i.s_axis_tx_tuser_i
      ; buffer_write_ready_i = tx_buffer.write_ready_o
      ; buffer_commit_ready_i = tx_buffer.commit_ready_o
      ; buffer_frame_length_i = tx_buffer.current_frame_length_o
      }
  in
  (* Finish an on-wire frame before disabling the formatter. Queued descriptors remain
     buffered until enabled again or explicitly reset. *)
  let tx_in_frame =
    tx_feedback.state_o
    <>:. Mac_10g_tx.state_wait
    &: (tx_feedback.state_o <>:. Mac_10g_tx.state_ifg)
  in
  let tx_enable = tx_configuration.tx_enable |: tx_in_frame &: ~:tx_reset in
  let tx =
    Mac_10g_tx.hierarchical
      scope
      { clock_i = i.tx_clock_i
      ; reset_i = tx_reset
      ; enable_i = tx_enable
      ; counters_clear_i = control.tx_counters_clear_o
      ; buffer_data_i = tx_read_data
      ; buffer_keep_i = tx_read_keep
      ; buffer_valid_i = tx_read_valid
      ; buffer_last_i = tx_read_last
      }
  in
  (* Idle/discard can accept a new /S/. Hold length through preamble, body and descriptor
     commit, including when software changes the shadow meanwhile. *)
  let rx_boundary =
    rx_feedback.state_o ==:. Rx.state_idle |: (rx_feedback.state_o ==:. Rx.state_discard)
  in
  let bounded_rx_limit =
    mux2
      (rx_configuration.max_frame_length >:. max_supported_frame_length)
      (of_int_trunc ~width:16 max_supported_frame_length)
      rx_configuration.max_frame_length
  in
  let saved_rx_limit = reg rx_spec ~enable:rx_boundary bounded_rx_limit in
  let rx_enable = rx_configuration.rx_enable |: ~:rx_boundary &: ~:rx_reset in
  let rx =
    Rx.hierarchical
      scope
      { clock_i = i.rx_clock_i
      ; reset_i = rx_reset
      ; enable_i = rx_enable
      ; counters_clear_i = control.rx_counters_clear_o
      ; max_frame_length_i = mux2 rx_boundary bounded_rx_limit saved_rx_limit
      ; xgmii_data_i = i.xgmii_rxd_i
      ; xgmii_control_i = i.xgmii_rxc_i
      ; buffer_write_ready_i = rx_buffer.write_ready_o
      ; buffer_commit_ready_i = rx_buffer.commit_ready_o
      }
  in
  let egress =
    Egress.hierarchical
      scope
      { clock_i = i.rx_clock_i
      ; reset_i = rx_reset
      ; enable_i = rx_configuration.rx_enable &: ~:rx_reset
      ; drop_bad_i = rx_configuration.drop_bad_rx
      ; axis_ready_i = i.m_axis_rx_tready_i
      ; buffer_data_i = rx_buffer.read_data_o
      ; buffer_keep_i = rx_buffer.read_keep_o
      ; buffer_valid_i = rx_buffer.read_valid_o &: ~:rx_reset
      ; buffer_last_i = rx_buffer.read_last_o
      ; buffer_error_i = rx_buffer.read_error_o
      }
  in
  Ingress.O.iter2 ingress_feedback ingress ~f:assign;
  Mac_10g_tx.O.iter2 tx_feedback tx ~f:assign;
  Rx.O.iter2 rx_feedback rx ~f:assign;
  Egress.O.iter2 egress_feedback egress ~f:assign;
  C.Tx_counters.iter2
    tx_counters
    { frames = tx.frames_o
    ; bytes = tx.bytes_o
    ; drops = ingress.drops_o
    ; malformed_axi = ingress.malformed_frames_o
    ; underflow = tx.underflows_o
    }
    ~f:assign;
  C.Rx_counters.iter2
    rx_counters
    { good_frames = rx.good_frames_o
    ; bad_frames = rx.bad_frames_o
    ; bytes = rx.bytes_o
    ; fcs_errors = rx.fcs_errors_o
    ; length_errors = rx.length_errors_o
    ; xgmii_errors = rx.xgmii_errors_o
    ; overflow = rx.overflow_drops_o
    }
    ~f:assign;
  let overflow_sticky =
    reg_fb rx_spec ~width:1 ~f:(fun previous ->
      mux2 control.rx_counters_clear_o gnd (previous |: rx.overflow_pulse_o))
  in
  let local_fault = reg rx_spec rx.local_fault_o in
  let remote_fault = reg rx_spec rx.remote_fault_o in
  let mask fields =
    List.fold fields ~init:(zero 32) ~f:(fun result (position, value) ->
      result |: sll (uresize value ~width:32) ~by:position)
  in
  let module S = Mac_10g_register_map.Status in
  let module E = Mac_10g_register_map.Irq in
  assign
    tx_status
    (mask
       [ S.tx_active, tx_enable
       ; S.tx_buffer_nonempty, tx_buffer.bytes_used_o <>:. 0 |: tx_read_valid
       ; S.tx_underflow, tx.underflow_sticky_o
       ]);
  assign
    rx_status
    (mask
       [ S.rx_active, rx_enable
       ; S.rx_buffer_nonempty, rx_buffer.bytes_used_o <>:. 0
       ; S.rx_overflow, overflow_sticky
       ; S.local_fault, local_fault
       ; S.remote_fault, remote_fault
       ]);
  assign
    tx_events
    (mask
       [ E.tx_drop, ingress.drop_pulse_o
       ; E.tx_malformed_axi, ingress.malformed_pulse_o
       ; E.tx_underflow, tx.underflow_pulse_o
       ]);
  assign
    rx_events
    (mask
       [ E.rx_bad_frame, rx.bad_frame_pulse_o
       ; E.rx_overflow, rx.overflow_pulse_o
       ; E.local_fault, rx.local_fault_o &: ~:local_fault &: ~:rx_reset
       ; E.remote_fault, rx.remote_fault_o &: ~:remote_fault &: ~:rx_reset
       ]);
  { O.s_axis_tx_tready_o = ingress.axis_ready_o
  ; xgmii_txd_o = tx.xgmii_txd_o
  ; xgmii_txc_o = tx.xgmii_txc_o
  ; m_axis_rx_tdata_o = egress.axis_data_o
  ; m_axis_rx_tkeep_o = egress.axis_keep_o
  ; m_axis_rx_tvalid_o = egress.axis_valid_o
  ; m_axis_rx_tlast_o = egress.axis_last_o
  ; m_axis_rx_tuser_o = egress.axis_user_o
  ; s_axi_awready_o = control.s_axi_awready_o
  ; s_axi_wready_o = control.s_axi_wready_o
  ; s_axi_bresp_o = control.s_axi_bresp_o
  ; s_axi_bvalid_o = control.s_axi_bvalid_o
  ; s_axi_arready_o = control.s_axi_arready_o
  ; s_axi_rdata_o = control.s_axi_rdata_o
  ; s_axi_rresp_o = control.s_axi_rresp_o
  ; s_axi_rvalid_o = control.s_axi_rvalid_o
  ; irq_o = control.irq_o
  }
;;

let hierarchical
  ?(tx_buffer_depth_bytes = Config.default_tx_buffer_depth_bytes)
  ?(rx_buffer_depth_bytes = Config.default_rx_buffer_depth_bytes)
  ?(descriptor_capacity = Config.default_descriptor_capacity)
  ?(max_supported_frame_length = Config.default_max_supported_frame_length)
  scope
  i
  =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical
    ~scope
    ~name:"mac_10g_top"
    (create
       ~tx_buffer_depth_bytes
       ~rx_buffer_depth_bytes
       ~descriptor_capacity
       ~max_supported_frame_length)
    i
;;
