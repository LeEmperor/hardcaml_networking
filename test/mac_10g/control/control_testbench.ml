(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "control_testbench.ml" *)
(* Event-driven, independently clocked AXI master and data-domain monitors. *)

open! Core
open! Hardcaml
open! Mac_10g_of_hardcaml
open! Mac_10g_control_types
module Dut = Mac_10g_control
module E = Hardcaml_event_driven_sim.Two_state_simulator
module Sim = E.With_interface (Dut.I) (Dut.O)
module Scheduler = E.Simulator
module Port = Hardcaml_event_driven_sim.Port

type configuration =
  { tx_enable : int
  ; rx_enable : int
  ; drop_bad_rx : int
  ; maximum : int
  }
[@@deriving sexp, equal, compare]

type response =
  { data : int
  ; resp : int
  }
[@@deriving sexp, equal, compare]

(* [tx_reset]/[rx_reset] count soft-reset *commands* observed by the domain; the output
   itself is held for several owner-clock cycles, and [*_reset_cycles] counts those. *)
type commands =
  { mutable tx_clear : int
  ; mutable rx_clear : int
  ; mutable tx_reset : int
  ; mutable rx_reset : int
  ; mutable tx_reset_cycles : int
  ; mutable rx_reset_cycles : int
  }
[@@deriving sexp]

type t =
  { sim : Sim.t
  ; scheduler : Scheduler.t
  ; axi_half : int
  ; tx_half : int
  ; rx_half : int
  ; commands : commands
  ; mutable now : int
  ; mutable count : bool
  ; mutable tx_reset_level : int
  ; mutable rx_reset_level : int
  ; mutable tx_configurations : configuration list
  ; mutable rx_configurations : configuration list
  }

let get (port : Bits.t Port.t) = Scheduler.Signal.read port.signal |> Bits.to_int_trunc
let bits (port : Bits.t Port.t) = Scheduler.Signal.read port.signal

let set t (port : Bits.t Port.t) value =
  Scheduler.Expert.schedule_external_set
    t.scheduler
    port.signal
    (Bits.of_int_trunc ~width:(Signal.width port.base_signal) value)
;;

let configuration (ports : Bits.t Port.t Configuration.t) =
  { tx_enable = get ports.tx_enable
  ; rx_enable = get ports.rx_enable
  ; drop_bad_rx = get ports.drop_bad_rx
  ; maximum = get ports.max_frame_length
  }
;;

let rising time half first = time >= first && (time - first) mod (2 * half) = 0

let advance t cycles =
  for _ = 1 to cycles do
    let next = t.now + 1 in
    let tx_edge = rising next t.tx_half 2 in
    let rx_edge = rising next t.rx_half 3 in
    let o = t.sim.output in
    let tx_clear = tx_edge && get o.tx_counters_clear_o = 1 in
    let rx_clear = rx_edge && get o.rx_counters_clear_o = 1 in
    if tx_edge
    then (
      let level = get o.tx_soft_reset_o in
      t.commands.tx_clear <- t.commands.tx_clear + Bool.to_int tx_clear;
      t.commands.tx_reset
      <- t.commands.tx_reset + Bool.to_int (level = 1 && t.tx_reset_level = 0);
      t.commands.tx_reset_cycles <- t.commands.tx_reset_cycles + level;
      t.tx_reset_level <- level;
      t.tx_configurations <- configuration o.tx_configuration_o :: t.tx_configurations);
    if rx_edge
    then (
      let level = get o.rx_soft_reset_o in
      t.commands.rx_clear <- t.commands.rx_clear + Bool.to_int rx_clear;
      t.commands.rx_reset
      <- t.commands.rx_reset + Bool.to_int (level = 1 && t.rx_reset_level = 0);
      t.commands.rx_reset_cycles <- t.commands.rx_reset_cycles + level;
      t.rx_reset_level <- level;
      t.rx_configurations <- configuration o.rx_configuration_o :: t.rx_configurations);
    Scheduler.Expert.schedule_call t.scheduler ~delay:1 ~f:ignore;
    Scheduler.run t.scheduler ~time_limit:next;
    while Scheduler.has_delta_updates t.scheduler do
      Scheduler.delta_step t.scheduler
    done;
    t.now <- next;
    (* The synthetic counter owners update after their sampling edge, like registers. A
       simultaneous snapshot/clear therefore captures the pre-clear value. *)
    let update clear edge ports =
      if edge
      then
        List.iter ports ~f:(fun port ->
          if clear then set t port 0 else if t.count then set t port (get port + 1))
    in
    update tx_clear tx_edge (Tx_counters.to_list t.sim.input.tx_counters_i);
    update rx_clear rx_edge (Rx_counters.to_list t.sim.input.rx_counters_i)
  done
;;

let create
  ?(axi_half = 7)
  ?(tx_half = 4)
  ?(rx_half = 11)
  ?(maximum = 2048)
  ?(soft_reset_cycles = 16)
  ()
  =
  let scope = Scope.create ~flatten_design:true () in
  let sim =
    Sim.create (Dut.create ~max_supported_frame_length:maximum ~soft_reset_cycles scope)
  in
  let clocks =
    [ Sim.create_clock ~time:axi_half ~initial_delay:1 sim.input.axi_clock_i.signal
    ; Sim.create_clock ~time:tx_half ~initial_delay:2 sim.input.tx_clock_i.signal
    ; Sim.create_clock ~time:rx_half ~initial_delay:3 sim.input.rx_clock_i.signal
    ]
  in
  let scheduler = Scheduler.create (clocks @ sim.processes) in
  let t =
    { sim
    ; scheduler
    ; axi_half
    ; tx_half
    ; rx_half
    ; commands =
        { tx_clear = 0
        ; rx_clear = 0
        ; tx_reset = 0
        ; rx_reset = 0
        ; tx_reset_cycles = 0
        ; rx_reset_cycles = 0
        }
    ; now = 0
    ; count = false
    ; tx_reset_level = 0
    ; rx_reset_level = 0
    ; tx_configurations = []
    ; rx_configurations = []
    }
  in
  set t sim.input.axi_reset_i 1;
  set t sim.input.tx_reset_i 1;
  set t sim.input.rx_reset_i 1;
  advance t (8 * Int.max axi_half (Int.max tx_half rx_half));
  set t sim.input.axi_reset_i 0;
  set t sim.input.tx_reset_i 0;
  set t sim.input.rx_reset_i 0;
  advance t (12 * Int.max axi_half (Int.max tx_half rx_half));
  t
;;

(* Arrive one time unit before an AXI rising edge, sample the handshake, then cross it.
   Stimuli are never changed on that sampling edge. *)
let before_axi t =
  let rec loop () =
    if not (rising (t.now + 1) t.axi_half 1)
    then (
      advance t 1;
      loop ())
  in
  loop ()
;;

let axi_cycle t =
  advance t 1;
  before_axi t;
  advance t 1
;;

let wait t ~label predicate =
  let rec loop remaining =
    if predicate ()
    then ()
    else if remaining = 0
    then failwithf "timeout at t=%d: %s" t.now label ()
    else (
      advance t 1;
      loop (remaining - 1))
  in
  loop 20000
;;

let send t valid ready =
  before_axi t;
  advance t 1;
  set t valid 1;
  advance t 1;
  let rec loop remaining =
    before_axi t;
    let accepted = get ready = 1 in
    advance t 1;
    if not accepted
    then (
      if remaining = 0 then failwith "AXI request timed out";
      advance t 1;
      loop (remaining - 1))
  in
  loop 2000;
  set t valid 0;
  advance t 1
;;

let send_aw t address =
  set t t.sim.input.s_axi_awaddr_i address;
  send t t.sim.input.s_axi_awvalid_i t.sim.output.s_axi_awready_o
;;

let send_w t ~data ~strb =
  set t t.sim.input.s_axi_wdata_i data;
  set t t.sim.input.s_axi_wstrb_i strb;
  send t t.sim.input.s_axi_wvalid_i t.sim.output.s_axi_wready_o
;;

let finish_write ?(stall = 0) t =
  let o = t.sim.output in
  wait t ~label:"BVALID" (fun () -> get o.s_axi_bvalid_o = 1);
  let response = get o.s_axi_bresp_o in
  for _ = 1 to stall do
    axi_cycle t;
    [%test_result: int] (get o.s_axi_bvalid_o) ~expect:1;
    [%test_result: int] (get o.s_axi_bresp_o) ~expect:response;
    [%test_result: int] (get o.s_axi_awready_o) ~expect:0;
    [%test_result: int] (get o.s_axi_wready_o) ~expect:0
  done;
  set t t.sim.input.s_axi_bready_i 1;
  axi_cycle t;
  set t t.sim.input.s_axi_bready_i 0;
  advance t 1;
  response
;;

let write ?(strb = 15) ?(w_first = false) ?(gap = 0) ?(stall = 0) t address data =
  if w_first
  then (
    send_w t ~data ~strb;
    advance t gap;
    send_aw t address)
  else (
    send_aw t address;
    advance t gap;
    send_w t ~data ~strb);
  finish_write ~stall t
;;

let write_simultaneous t address data =
  before_axi t;
  advance t 1;
  set t t.sim.input.s_axi_awaddr_i address;
  set t t.sim.input.s_axi_awvalid_i 1;
  set t t.sim.input.s_axi_wdata_i data;
  set t t.sim.input.s_axi_wstrb_i 15;
  set t t.sim.input.s_axi_wvalid_i 1;
  advance t 1;
  before_axi t;
  assert (get t.sim.output.s_axi_awready_o = 1);
  assert (get t.sim.output.s_axi_wready_o = 1);
  advance t 1;
  set t t.sim.input.s_axi_awvalid_i 0;
  set t t.sim.input.s_axi_wvalid_i 0;
  advance t 1;
  finish_write ~stall:5 t
;;

(* Direct register-file check isolates a same-edge W1C/event race from CDC latency. *)
let irq_set_wins () =
  let module R = Mac_10g_regs in
  let module S = Cyclesim.With_interface (R.I) (R.O) in
  let sim = S.create (R.create (Scope.create ~flatten_design:true ())) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let drive p width value = p := Bits.of_int_trunc ~width value in
  drive i.reset_i 1 1;
  Cyclesim.cycle sim;
  drive i.reset_i 1 0;
  drive i.s_axi_awaddr_i 12 0x14;
  drive i.s_axi_awvalid_i 1 1;
  drive i.s_axi_wdata_i 32 1;
  drive i.s_axi_wstrb_i 4 1;
  drive i.s_axi_wvalid_i 1 1;
  Cyclesim.cycle sim;
  drive i.s_axi_awvalid_i 1 0;
  drive i.s_axi_wvalid_i 1 0;
  drive i.events_i 32 1;
  Cyclesim.cycle sim;
  drive i.events_i 32 0;
  drive i.s_axi_araddr_i 12 0x14;
  drive i.s_axi_arvalid_i 1 1;
  Cyclesim.cycle sim;
  Bits.to_int_trunc !(o.s_axi_rdata_o)
;;

let begin_read t address =
  set t t.sim.input.s_axi_araddr_i address;
  send t t.sim.input.s_axi_arvalid_i t.sim.output.s_axi_arready_o;
  wait t ~label:"RVALID" (fun () -> get t.sim.output.s_axi_rvalid_o = 1)
;;

let read_response t =
  { data = get t.sim.output.s_axi_rdata_o; resp = get t.sim.output.s_axi_rresp_o }
;;

let finish_read ?(stall = 0) t =
  let result = read_response t in
  for _ = 1 to stall do
    axi_cycle t;
    [%test_result: int] (get t.sim.output.s_axi_rvalid_o) ~expect:1;
    [%test_result: int] (get t.sim.output.s_axi_arready_o) ~expect:0;
    [%test_result: response] (read_response t) ~expect:result
  done;
  set t t.sim.input.s_axi_rready_i 1;
  axi_cycle t;
  set t t.sim.input.s_axi_rready_i 0;
  advance t 1;
  result
;;

let read ?(stall = 0) t address =
  begin_read t address;
  finish_read ~stall t
;;

let read_ok t address =
  let r = read t address in
  assert (r.resp = 0);
  r.data
;;

let write_ok t address data = [%test_result: int] (write t address data) ~expect:0

let set_counters t ~tx ~rx =
  List.iter2_exn (Tx_counters.to_list t.sim.input.tx_counters_i) tx ~f:(set t);
  List.iter2_exn (Rx_counters.to_list t.sim.input.rx_counters_i) rx ~f:(set t);
  advance t 1
;;

let counter t base index =
  let low = read_ok t (base + (8 * index)) in
  let high = read_ok t (base + (8 * index) + 4) in
  low lor (high lsl 32)
;;

let event t ~tx mask =
  let port, half, first =
    if tx
    then t.sim.input.tx_events_i, t.tx_half, 2
    else t.sim.input.rx_events_i, t.rx_half, 3
  in
  set t port mask;
  advance t 1;
  while not (rising (t.now + 1) half first) do
    advance t 1
  done;
  advance t 1;
  set t port 0;
  advance t 1
;;

let golden () =
  let t = create () in
  let id = read_ok t 0 in
  let maximum = read_ok t 0x10 in
  send_aw t 0x20;
  advance t 100;
  let before_data = get t.sim.output.s_axi_bvalid_o in
  send_w t ~data:0x12345678 ~strb:15;
  let response = finish_write ~stall:5 t in
  let scratch = read_ok t 0x20 in
  write_ok t 8 7;
  let tx = configuration t.sim.output.tx_configuration_o in
  let rx = configuration t.sim.output.rx_configuration_o in
  id, maximum, before_data, response, scratch, tx, rx
;;
