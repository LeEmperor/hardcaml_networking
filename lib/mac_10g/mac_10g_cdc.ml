(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_cdc.ml" *)
(* Bundled-data toggle mailboxes for configuration, commands, counter snapshots, and
   autonomous status/event delivery. Only the handshake bits use two-flop synchronizers.
   AXI reset starts a new transport epoch, with asynchronous assertion and locally
   synchronized release. Data-domain resets pause command delivery without resetting
   mailbox sequence numbers, so resetting one datapath cannot replay a command.
*)

open! Core
open! Hardcaml
open! Signal
open! Mac_10g_control_types
module Map = Mac_10g_register_map

module I = struct
  type 'a t =
    { axi_clock_i : 'a
    ; axi_reset_i : 'a
    ; tx_clock_i : 'a
    ; tx_reset_i : 'a
    ; rx_clock_i : 'a
    ; rx_reset_i : 'a
    ; configuration_i : 'a Configuration.t
    ; command_i : 'a Command.t
    ; request_i : 'a
    ; tx_counters_i : 'a Tx_counters.t
    ; rx_counters_i : 'a Rx_counters.t
    ; (* Status uses STATUS bit positions; events are owner-clock pulses using IRQ bits. *)
      tx_status_i : 'a [@bits 32]
    ; rx_status_i : 'a [@bits 32]
    ; tx_events_i : 'a [@bits 32]
    ; rx_events_i : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready_o : 'a
    ; done_o : 'a
    ; tx_configuration_o : 'a Configuration.t
    ; rx_configuration_o : 'a Configuration.t
    ; tx_counters_clear_o : 'a
    ; rx_counters_clear_o : 'a
    ; tx_soft_reset_o : 'a
    ; rx_soft_reset_o : 'a
    ; tx_snapshot_o : 'a Tx_counters.t
    ; rx_snapshot_o : 'a Rx_counters.t
    ; status_o : 'a [@bits 32]
    ; events_o : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

(* candidate to put in helper circuits; actually most of this module is *)
(* top 10 functions of hardcaml ever wtf Rtl_attribute is insane *)
(* survives the CDC report in Vivado because of the attribute *)
(* the only thing that bridges between domains *)
let synchronizer scope spec name input =
  (* alias *)
  let ( -- ) = Scope.naming scope in
  let stage suffix input =
    reg spec ~enable:vdd input
    |> fun s ->
    add_attribute s (Rtl_attribute.Vivado.async_reg true) |> fun s -> s -- (name ^ suffix)
  in
  stage "_sync2" (stage "_sync1" input)
;;

(* create a spec across 2 regs *)
(* dead code lmao *)
let transport_spec scope ~clock ~reset =
  (* spec 1 *)
  let spec = Reg_spec.create ~clock ~reset () in
  (* make the first reg *)
  let released = synchronizer scope spec "transport_release" vdd in
  (* make the second spec *)
  (* creates an async reset on axi_reset *)
  (* async assert/sync deassert reset sync *)
  (* every user of this is async reset by axi, held sync clear by local *)
  Reg_spec.create ~clock ~reset ~clear:~:released (), released
;;

(* an owner - a clock domain that holds its own private configuration

   has it's own ack bit, soft reset, and mailbox for telemetry
*)
type owner =
  { configuration : Signal.t Configuration.t
  ; counters_clear : Signal.t
  ; soft_reset : Signal.t
  ; snapshot : Signal.t
  ; ack : Signal.t
  ; online : Signal.t
  ; status : Signal.t
  ; events : Signal.t
  }

[@@@ocamlformat "disable"]
let owner
  (* top scope over the entire thing *)
  scope

  (* axi items *)
  ~axi_spec
  ~axi_reset
  ~clock
  ~reset
  ~request
  ~configuration
  ~(command : _ Command.t)
  ~soft_reset_command
  ~soft_reset_cycles
  ~counters
  ~status
  ~events
  ~status_mask
  ~event_mask
  ~default_maximum
  =
  (* main forward path paradigm:
        configuration (19b),
        command (4b),
        request toggle,
        pending

      accept = request_i && ready => latches payload, flip toggle to pending = 1, accept window self-closes
        -> therefore a req for multiple cycles cant be accepted twice; can we formally prove this?

      this is for AXI to TX/RX side of things; duplex
  *)
  let spec, released =
    (fun scope ~clock ~reset ->
       (* spec *)
      let spec = Reg_spec.create ~clock ~reset () in
      let released = synchronizer scope spec "transport_release" vdd in
      Reg_spec.create ~clock ~reset ~clear:~:released (), released)
      scope
      ~clock
      ~reset:axi_reset
  in

  let variable width = Always.Variable.reg spec ~enable:vdd ~width in

  (* ack wire out *)
  let ack = variable 1 in

  (* 2ff sync on the request into our accept domain *)
  (* Synchronizer D paths stay free of release muxes. The async transport reset
     initializes both stages; [released] gates command execution and telemetry. *)
  let sync_spec = Reg_spec.create ~clock ~reset:axi_reset () in
  let request_sync = synchronizer scope sync_spec "command_request" request in

  (* Capture the held payload into local registers before executing commands. This
     keeps command fanout inside the owner clock domain, rather than letting AXI
     holding-register bits reach every counter/reset/RAM control pin combinationally.
     Snapshot and clear still execute on the same local edge; acknowledge that edge.


     Acknowledge paradigm - TX/RX -> AXI

    Both owners must agree before.
  *)

  let captured_configuration = Configuration.map Configuration.port_widths ~f:variable in
  let captured_command = Command.map Command.port_widths ~f:variable in
  let captured_soft_reset = variable 1 in
  let captured_request = variable 1 in
  let captured = variable 1 in
  let capture_command = released &: ~:reset &: ~:(captured.value)
                        &: (request_sync <>: ack.value) in
  let apply = released &: ~:reset &: captured.value in
  let local_command = Command.map captured_command ~f:Always.Variable.value in
  let local_configuration = Configuration.map captured_configuration ~f:Always.Variable.value in
  let config = Configuration.map Configuration.port_widths ~f:variable in
  let maximum =
    Always.Variable.reg
      spec
      ~enable:vdd
      ~width:16
      ~reset_to:(Bits.of_int_trunc ~width:16 default_maximum)
      ~clear_to:(of_int_trunc ~width:16 default_maximum)
  in

  let config = { config with max_frame_length = maximum } in
  let snapshot = variable (width counters) in
  let config_values = Configuration.map config ~f:Always.Variable.value in
  let counters_clear = apply &: local_command.clear in
  (* One sampling edge is enough for a counter clear but too narrow to drive a reset
     tree: every consumer would have to stretch it itself, and one that forgot would
     half-reset its datapath. Hold it here instead, for [soft_reset_cycles] owner-clock
     cycles starting on the accepting edge, reloading if a retrigger lands inside the
     window

     AXI acknowledgement still goes out on the accepting edge, so the reset
     outlives its own B response - software cannot treat BVALID as "datapath is back"
  *)
  let soft_reset_remaining =
    Always.Variable.reg
      spec
      ~enable:vdd
      ~width:(Int.max 1 (Int.ceil_log2 soft_reset_cycles))
  in

  let soft_reset_start = apply &: captured_soft_reset.value in
  let soft_reset = soft_reset_start |: (soft_reset_remaining.value <>:. 0) in
  (* The return mailbox runs continuously, independently of software snapshots. Pending
     events accumulate while its payload is held for acknowledgement. An event coincident
     with a launch is included in that launch; later events go into the following one
  *)
  let return_request  = variable 1 in
  let return_ack      = wire 1 in
  let return_ack_sync = synchronizer scope sync_spec "telemetry_ack" return_ack in
  let pending_events  = variable 32 in
  let payload         = variable 64 in
  let masked_events =
    mux2
      (* are we in reset? *)
      reset

      (* zero out *)
      (zero 32)

      (* combine out the events with the event keep mask for downstream pass *)
      (events &:
      of_int_trunc ~width:32 event_mask)
  in

  let accumulated = pending_events.value |: masked_events in
  let send = released &: (return_request.value ==: return_ack_sync) in

  Always.(
    compile
      [ when_ capture_command
          ([ captured <--. 1; captured_request <-- request_sync
           ; captured_soft_reset <-- soft_reset_command ]
           @ Configuration.to_list
               (Configuration.map2 captured_configuration configuration ~f:(fun dst src -> dst <-- src))
           @ Command.to_list
               (Command.map2 captured_command command ~f:(fun dst src -> dst <-- src)))
      ; when_
          apply
          ([ ack <-- captured_request.value; captured <--. 0 ]
           @ Configuration.to_list
               (Configuration.map2 config local_configuration ~f:(fun dst src -> dst <-- src))
           @ [ when_ local_command.snapshot [ snapshot <-- counters ] ])
      ; pending_events <-- mux2 send (zero 32) accumulated
      ; when_
          send
          [ payload
            <-- concat_lsb [ status &: of_int_trunc ~width:32 status_mask; accumulated ]
          ; return_request <-- ~:(return_request.value)
          ]
      ; if_
          soft_reset_start
          [ soft_reset_remaining <--. (soft_reset_cycles - 1) ]
          [ when_
              (soft_reset_remaining.value <>:. 0)
              [ soft_reset_remaining <-- soft_reset_remaining.value -:. 1 ]
          ]
      ]);

  let received = Always.Variable.reg axi_spec ~enable:vdd ~width:1 in
  let return_request_sync =
    synchronizer scope axi_spec "telemetry_request" return_request.value
  in

  let capture = return_request_sync <>: received.value in
  let status = reg axi_spec ~enable:capture (select payload.value ~high:31 ~low:0) in
  let events =
    reg
      axi_spec
      ~enable:vdd
      (mux2 capture (select payload.value ~high:63 ~low:32) (zero 32))
  in
  Always.(compile [ when_ capture [ received <-- return_request_sync ] ]);
  assign return_ack received.value;

  { configuration =
      { config_values with
        tx_enable = config_values.tx_enable &: ~:reset &: released
      ; rx_enable = config_values.rx_enable &: ~:reset &: released
      }
  ; counters_clear
  ; soft_reset
  ; snapshot = snapshot.value
  ; ack = synchronizer scope axi_spec "command_ack" ack.value
  ; online = synchronizer scope axi_spec "owner_online" released
  ; status
  ; events
  }
;;

let create
  ?(max_supported_frame_length = 1518)
  ?(soft_reset_cycles = 16)
  scope
  (i : _ I.t)
  : _ O.t
  =

  (* elab time checks *)
  if max_supported_frame_length < 64 || max_supported_frame_length > 65535
  then invalid_arg "Mac_10g_cdc: max_supported_frame_length must be in 64..65535";
  if soft_reset_cycles < 1
  then invalid_arg "Mac_10g_cdc: soft_reset_cycles must be at least 1";

  (* status_o/events_o merge the two owner mailboxes with a bitwise OR, which is only a
     merge while the masks are disjoint. Catch a bit handed to both owners here rather
     than as one domain quietly overwriting the other's status in silicon. *)
  if Map.Mask.tx_status land Map.Mask.rx_status <> 0
     || Map.Mask.tx_irq land Map.Mask.rx_irq <> 0
  then invalid_arg "Mac_10g_cdc: TX and RX masks must be disjoint";

  (* spec - axi domain - for example the zynq block would feed this from the SMC *)
  let spec = Reg_spec.create ~clock:i.axi_clock_i ~clear:i.axi_reset_i () in

  (* local alias; kinda screwy but we'll run with this *)
  let variable width = Always.Variable.reg spec ~enable:vdd ~width in
  let pending         = variable 1 in
  let request         = variable 1 in
  let configuration   = variable 19 in
  let command         = variable 4 in

  (* so we can interpret the command - almost like packed structs with unions *)
  let command_value   = Command.Of_signal.unpack command.value in

  (* helper for owner creation; essentially just an owning over the axi spec passed in as owner to the TX and RX specs *)
  let make_owner
    name
    ~clock
    ~reset
    ~soft_reset_command
    ~counters
    ~status
    ~events
    ~status_mask
    ~event_mask
    =
    owner
      (Scope.sub_scope scope name)
      ~axi_spec:spec
      ~axi_reset:i.axi_reset_i
      ~clock
      ~reset
      ~request:request.value
      ~configuration:(Configuration.Of_signal.unpack configuration.value)
      ~command:command_value
      ~soft_reset_command
      ~soft_reset_cycles
      ~counters
      ~status
      ~events
      ~status_mask
      ~event_mask
      ~default_maximum:Map.Value.default_max_frame_length
  in

  let tx =
    make_owner
      "tx"
      ~clock:i.tx_clock_i
      ~reset:i.tx_reset_i
      ~soft_reset_command:command_value.tx_soft_reset
      ~counters:(Tx_counters.Of_signal.pack i.tx_counters_i)
      ~status:i.tx_status_i
      ~events:i.tx_events_i
      ~status_mask:Map.Mask.tx_status
      ~event_mask:Map.Mask.tx_irq
  in

  let rx =
    make_owner
      "rx"
      ~clock:i.rx_clock_i
      ~reset:i.rx_reset_i
      ~soft_reset_command:command_value.rx_soft_reset
      ~counters:(Rx_counters.Of_signal.pack i.rx_counters_i)
      ~status:i.rx_status_i
      ~events:i.rx_events_i
      ~status_mask:Map.Mask.rx_status
      ~event_mask:Map.Mask.rx_irq
  in

  let ready = ~:(pending.value) &: tx.online &: rx.online in
  let done_ = pending.value &: (tx.ack ==: request.value) &: (rx.ack ==: request.value) in
  let done_pulse = reg spec ~enable:vdd done_ in
  let tx_snapshot = reg spec ~enable:(done_ &: command_value.snapshot) tx.snapshot in
  let rx_snapshot = reg spec ~enable:(done_ &: command_value.snapshot) rx.snapshot in

  Always.(
    compile
      [ when_
          (i.request_i &: ready)
          [ configuration <-- Configuration.Of_signal.pack i.configuration_i
          ; command <-- Command.Of_signal.pack i.command_i
          ; request <-- ~:(request.value)
          ; pending <--. 1
          ]
      ; when_ done_ [ pending <--. 0 ]
      ]);

  { O.ready_o = ready
  ; done_o = done_pulse
  ; tx_configuration_o = tx.configuration
  ; rx_configuration_o = rx.configuration
  ; tx_counters_clear_o = tx.counters_clear
  ; rx_counters_clear_o = rx.counters_clear
  ; tx_soft_reset_o = tx.soft_reset
  ; rx_soft_reset_o = rx.soft_reset
  ; tx_snapshot_o = Tx_counters.Of_signal.unpack tx_snapshot
  ; rx_snapshot_o = Rx_counters.Of_signal.unpack rx_snapshot
  ; status_o = tx.status |: rx.status
  ; events_o = tx.events |: rx.events
  }
[@@@ocamlformat "enable"]

let hierarchical ?(max_supported_frame_length = 1518) ?(soft_reset_cycles = 16) scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical
    ~scope
    ~name:"mac_10g_cdc"
    (create ~max_supported_frame_length ~soft_reset_cycles)
    i
;;
