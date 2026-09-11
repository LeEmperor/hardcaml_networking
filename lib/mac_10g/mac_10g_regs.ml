(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_regs.ml" *)
(* One-outstanding AXI4-Lite slave. AW and W are captured independently; all responses are
   registered. Configuration and W1P writes complete after the CDC acknowledgement.
*)

open! Core
open! Hardcaml
open! Signal
open! Mac_10g_control_types
module Map = Mac_10g_register_map

module I = struct
  type 'a t =
    { clock_i : 'a
    ; reset_i : 'a
    ; s_axi_awaddr_i : 'a [@bits 12]
    ; s_axi_awvalid_i : 'a
    ; s_axi_wdata_i : 'a [@bits 32]
    ; s_axi_wstrb_i : 'a [@bits 4]
    ; s_axi_wvalid_i : 'a
    ; s_axi_bready_i : 'a
    ; s_axi_araddr_i : 'a [@bits 12]
    ; s_axi_arvalid_i : 'a
    ; s_axi_rready_i : 'a
    ; cdc_ready_i : 'a
    ; cdc_done_i : 'a
    ; status_i : 'a [@bits 32]
    ; events_i : 'a [@bits 32]
    ; tx_snapshot_i : 'a Tx_counters.t
    ; rx_snapshot_i : 'a Rx_counters.t
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
    ; configuration_o : 'a Configuration.t
    ; command_o : 'a Command.t
    ; request_o : 'a
    }
  [@@deriving hardcaml]
end

let irq_mask = 0x00000f07
let status_mask = 0x0003030f

let create ?(max_supported_frame_length = 1518) (_scope : Scope.t) (i : _ I.t) : _ O.t =
  if max_supported_frame_length < 64 || max_supported_frame_length > 65535
  then invalid_arg "Mac_10g_regs: max_supported_frame_length must be in 64..65535";
  let spec = Reg_spec.create ~clock:i.clock_i ~clear:i.reset_i () in
  let variable width = Always.Variable.reg spec ~enable:vdd ~width in
  let aw_full = variable 1 in
  let awaddr = variable 12 in
  let w_full = variable 1 in
  let wdata = variable 32 in
  let wstrb = variable 4 in
  let bvalid = variable 1 in
  let bresp = variable 2 in
  let rvalid = variable 1 in
  let rresp = variable 2 in
  let rdata = variable 32 in
  let waiting = variable 1 in
  let request = variable 1 in
  let command = variable 4 in
  let control = variable 3 in
  let maximum =
    Always.Variable.reg
      spec
      ~enable:vdd
      ~width:16
      ~clear_to:(of_int_trunc ~width:16 Map.Value.default_max_frame_length)
  in
  let scratch = variable 32 in
  let irq_status = variable 32 in
  let irq_enable = variable 32 in
  let irq = variable 1 in
  let tx_snapshot = Tx_counters.map Tx_counters.port_widths ~f:variable in
  let rx_snapshot = Rx_counters.map Rx_counters.port_widths ~f:variable in
  let awready = ~:(aw_full.value |: bvalid.value |: waiting.value) in
  let wready = ~:(w_full.value |: bvalid.value |: waiting.value) in
  let arready = ~:(rvalid.value) in
  let execute = aw_full.value &: w_full.value &: ~:(bvalid.value |: waiting.value) in
  let strobes =
    List.init 4 ~f:(fun n -> repeat (bit wstrb.value ~pos:n) ~count:8) |> concat_lsb
  in
  let written = wdata.value &: strobes in
  let merge old = old &: ~:strobes |: written in
  let address_is address = awaddr.value ==:. address in
  let config_write =
    address_is Map.Address.control |: address_is Map.Address.max_frame_length
  in
  let command_write = address_is Map.Address.counter_control in
  let crossing = config_write |: command_write in
  let next_maximum = select (merge (uresize maximum.value ~width:32)) ~high:15 ~low:0 in
  let invalid_maximum =
    address_is Map.Address.max_frame_length
    &: (select wstrb.value ~high:1 ~low:0 <>:. 0)
    &: (next_maximum <:. 64 |: (next_maximum >:. max_supported_frame_length))
  in
  let counter_words base counters =
    List.concat_mapi counters ~f:(fun n counter ->
      [ base + (n * 8), select counter ~high:31 ~low:0
      ; base + (n * 8) + 4, select counter ~high:63 ~low:32
      ])
  in
  let reads =
    [ Map.Address.core_id, of_int_trunc ~width:32 Map.Value.core_id
    ; Map.Address.core_version, of_int_trunc ~width:32 Map.Value.core_version
    ; Map.Address.control, uresize control.value ~width:32
    ; Map.Address.status, i.status_i &: of_int_trunc ~width:32 status_mask
    ; Map.Address.max_frame_length, uresize maximum.value ~width:32
    ; Map.Address.irq_status, irq_status.value
    ; Map.Address.irq_enable, irq_enable.value
    ; Map.Address.counter_control, zero 32
    ; Map.Address.scratch, scratch.value
    ]
    @ counter_words
        Map.Address.tx_frames_low
        (Tx_counters.to_list (Tx_counters.map tx_snapshot ~f:Always.Variable.value))
    @ counter_words
        Map.Address.rx_good_frames_low
        (Rx_counters.to_list (Rx_counters.map rx_snapshot ~f:Always.Variable.value))
  in
  let mapped address =
    List.map reads ~f:(fun (offset, _) -> address ==:. offset) |> reduce ~f:( |: )
  in
  let write_error = ~:(mapped awaddr.value) |: invalid_maximum in
  let finish_write = execute &: (write_error |: ~:crossing |: i.cdc_ready_i) in
  let clear_irqs = finish_write &: ~:write_error &: address_is Map.Address.irq_status in
  let next_irq_status =
    irq_status.value
    &: ~:(mux2 clear_irqs written (zero 32))
    |: (i.events_i &: of_int_trunc ~width:32 irq_mask)
  in
  let next_irq_enable =
    mux2
      (finish_write &: ~:write_error &: address_is Map.Address.irq_enable)
      (merge irq_enable.value &: of_int_trunc ~width:32 irq_mask)
      irq_enable.value
  in
  let open Always in
  compile
    [ request <--. 0
    ; irq_status <-- next_irq_status
    ; irq_enable <-- next_irq_enable
    ; irq <-- (next_irq_status &: next_irq_enable <>:. 0)
    ; when_ (i.s_axi_awvalid_i &: awready) [ aw_full <--. 1; awaddr <-- i.s_axi_awaddr_i ]
    ; when_
        (i.s_axi_wvalid_i &: wready)
        [ w_full <--. 1; wdata <-- i.s_axi_wdata_i; wstrb <-- i.s_axi_wstrb_i ]
    ; when_ (bvalid.value &: i.s_axi_bready_i) [ bvalid <--. 0 ]
    ; when_ (rvalid.value &: i.s_axi_rready_i) [ rvalid <--. 0 ]
    ; when_
        (i.s_axi_arvalid_i &: arready)
        [ rvalid <--. 1
        ; rresp <-- mux2 (mapped i.s_axi_araddr_i) (zero 2) (of_int_trunc ~width:2 2)
        ; rdata
          <-- List.fold reads ~init:(zero 32) ~f:(fun acc (address, data) ->
            mux2 (i.s_axi_araddr_i ==:. address) data acc)
        ]
    ; when_
        finish_write
        [ aw_full <--. 0
        ; w_full <--. 0
        ; bresp <-- mux2 write_error (of_int_trunc ~width:2 2) (zero 2)
        ; if_
            (crossing &: ~:write_error)
            [ waiting <--. 1
            ; request <--. 1
            ; command
              <-- Command.Of_signal.pack
                    { snapshot =
                        command_write &: bit written ~pos:Map.Counter_control.snapshot
                    ; clear = command_write &: bit written ~pos:Map.Counter_control.clear
                    ; tx_soft_reset =
                        address_is Map.Address.control
                        &: bit written ~pos:Map.Control.tx_soft_reset
                    ; rx_soft_reset =
                        address_is Map.Address.control
                        &: bit written ~pos:Map.Control.rx_soft_reset
                    }
            ]
            [ bvalid <--. 1 ]
        ; when_
            ~:write_error
            [ when_
                (address_is Map.Address.control)
                [ control
                  <-- select (merge (uresize control.value ~width:32)) ~high:2 ~low:0
                ]
            ; when_ (address_is Map.Address.max_frame_length) [ maximum <-- next_maximum ]
            ; when_ (address_is Map.Address.scratch) [ scratch <-- merge scratch.value ]
            ]
        ]
    ; when_
        (waiting.value &: i.cdc_done_i)
        ([ waiting <--. 0; bvalid <--. 1 ]
         @ [ when_
               (bit command.value ~pos:0)
               (Tx_counters.to_list
                  (Tx_counters.map2 tx_snapshot i.tx_snapshot_i ~f:(fun dst src ->
                     dst <-- src))
                @ Rx_counters.to_list
                    (Rx_counters.map2 rx_snapshot i.rx_snapshot_i ~f:(fun dst src ->
                       dst <-- src)))
           ])
    ];
  { O.s_axi_awready_o = awready
  ; s_axi_wready_o = wready
  ; s_axi_bresp_o = bresp.value
  ; s_axi_bvalid_o = bvalid.value
  ; s_axi_arready_o = arready
  ; s_axi_rdata_o = rdata.value
  ; s_axi_rresp_o = rresp.value
  ; s_axi_rvalid_o = rvalid.value
  ; irq_o = irq.value
  ; configuration_o =
      { tx_enable = bit control.value ~pos:0
      ; rx_enable = bit control.value ~pos:1
      ; drop_bad_rx = bit control.value ~pos:2
      ; max_frame_length = maximum.value
      }
  ; command_o = Command.Of_signal.unpack command.value
  ; request_o = request.value
  }
;;

let hierarchical ?(max_supported_frame_length = 1518) scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"mac_10g_regs" (create ~max_supported_frame_length) i
;;
