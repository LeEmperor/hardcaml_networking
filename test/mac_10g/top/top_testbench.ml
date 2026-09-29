open! Core
open! Hardcaml
open! Mac_10g_of_hardcaml
module Dut = Mac_10g_top
module E = Hardcaml_event_driven_sim.Two_state_simulator
module Sim = E.With_interface (Dut.I) (Dut.O)
module Scheduler = E.Simulator
module Port = Hardcaml_event_driven_sim.Port

type response =
  { data : int
  ; resp : int
  }
[@@deriving sexp, equal, compare]

type word =
  { data : Bits.t
  ; control : int
  }

type frame =
  { bytes : int list
  ; bad : bool
  }
[@@deriving sexp, equal, compare]

type t =
  { sim : Sim.t
  ; scheduler : Scheduler.t
  ; axi_half : int
  ; tx_half : int
  ; rx_half : int
  ; mutable now : int
  ; mutable wire_words : word list
  ; mutable frames : frame list
  ; mutable partial : int list
  ; mutable stalled : Bits.t list option
  ; mutable resetting : bool
  ; mutable rx_pending : word list
  }

let get (p : Bits.t Port.t) = Scheduler.Signal.read p.signal |> Bits.to_int_trunc
let bits (p : Bits.t Port.t) = Scheduler.Signal.read p.signal

let set_bits t (p : Bits.t Port.t) value =
  Scheduler.Expert.schedule_external_set t.scheduler p.signal value
;;

let set t (p : Bits.t Port.t) value =
  set_bits t p (Bits.of_int_trunc ~width:(Signal.width p.base_signal) value)
;;

let rising time half first = time >= first && (time - first) mod (2 * half) = 0

let advance t cycles =
  for _ = 1 to cycles do
    let next = t.now + 1 in
    let o = t.sim.output in
    if rising next t.tx_half 2
    then
      t.wire_words
      <- { data = bits o.xgmii_txd_o; control = get o.xgmii_txc_o } :: t.wire_words;
    if rising next t.rx_half 3
    then (
      let beat =
        List.map
          [ o.m_axis_rx_tdata_o
          ; o.m_axis_rx_tkeep_o
          ; o.m_axis_rx_tvalid_o
          ; o.m_axis_rx_tlast_o
          ; o.m_axis_rx_tuser_o
          ]
          ~f:bits
      in
      if get t.sim.input.rx_reset_i = 0 && not t.resetting
      then
        Option.iter t.stalled ~f:(fun previous ->
          if not (List.equal Bits.equal previous beat)
          then failwith "RX changed while stalled");
      t.stalled
      <- (if get o.m_axis_rx_tvalid_o = 1 && get t.sim.input.m_axis_rx_tready_i = 0
          then Some beat
          else None);
      if get o.m_axis_rx_tvalid_o = 1 && get t.sim.input.m_axis_rx_tready_i = 1
      then (
        let data = bits o.m_axis_rx_tdata_o in
        let bytes =
          List.filter_map (List.range 0 8) ~f:(fun lane ->
            if get o.m_axis_rx_tkeep_o land (1 lsl lane) = 0
            then None
            else
              Some
                (Bits.select data ~high:((8 * lane) + 7) ~low:(8 * lane)
                 |> Bits.to_int_trunc))
        in
        t.partial <- t.partial @ bytes;
        if get o.m_axis_rx_tlast_o = 1
        then (
          t.frames
          <- t.frames @ [ { bytes = t.partial; bad = get o.m_axis_rx_tuser_o = 1 } ];
          t.partial <- [])));
    Scheduler.Expert.schedule_call t.scheduler ~delay:1 ~f:ignore;
    Scheduler.run t.scheduler ~time_limit:next;
    while Scheduler.has_delta_updates t.scheduler do
      Scheduler.delta_step t.scheduler
    done;
    t.now <- next;
    if rising next t.rx_half 3
    then (
      match t.rx_pending with
      | [] -> ()
      | word :: rest ->
        set_bits t t.sim.input.xgmii_rxd_i word.data;
        set t t.sim.input.xgmii_rxc_i word.control;
        t.rx_pending <- rest)
  done
;;

let create
  ?(axi_half = 7)
  ?(tx_half = 4)
  ?(rx_half = 11)
  ?(maximum = 255)
  ?(depth = 256)
  ()
  =
  let scope = Scope.create ~flatten_design:true () in
  let sim =
    Sim.create
      (Dut.create
         ~tx_buffer_depth_bytes:depth
         ~rx_buffer_depth_bytes:depth
         ~max_supported_frame_length:maximum
         scope)
  in
  let scheduler =
    Scheduler.create
      ([ Sim.create_clock ~time:axi_half ~initial_delay:1 sim.input.axi_clock_i.signal
       ; Sim.create_clock ~time:tx_half ~initial_delay:2 sim.input.tx_clock_i.signal
       ; Sim.create_clock ~time:rx_half ~initial_delay:3 sim.input.rx_clock_i.signal
       ]
       @ sim.processes)
  in
  let t =
    { sim
    ; scheduler
    ; axi_half
    ; tx_half
    ; rx_half
    ; now = 0
    ; wire_words = []
    ; frames = []
    ; partial = []
    ; stalled = None
    ; resetting = false
    ; rx_pending = []
    }
  in
  set t sim.input.axi_reset_i 1;
  set t sim.input.tx_reset_i 1;
  set t sim.input.rx_reset_i 1;
  set_bits t sim.input.xgmii_rxd_i (Bits.of_hex ~width:64 "0707070707070707");
  set t sim.input.xgmii_rxc_i 255;
  set t sim.input.m_axis_rx_tready_i 1;
  advance t 200;
  set t sim.input.axi_reset_i 0;
  set t sim.input.tx_reset_i 0;
  set t sim.input.rx_reset_i 0;
  advance t 300;
  t
;;

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

let before_edge t half first =
  wait t ~label:"clock edge" (fun () -> rising (t.now + 1) half first)
;;

let payload length = List.init length ~f:(fun n -> ((n * 37) + length) land 255)

let pack bytes =
  List.init 8 ~f:(fun lane ->
    Bits.of_int_trunc ~width:8 (Option.value (List.nth bytes lane) ~default:0))
  |> Bits.concat_lsb
;;

let send_beat t ?(user = false) ?keep ~last bytes =
  (* Launch after an edge so the settling step cannot consume an unobserved beat. *)
  before_edge t t.tx_half 2;
  advance t 1;
  let i = t.sim.input in
  set_bits t i.s_axis_tx_tdata_i (pack bytes);
  set t i.s_axis_tx_tkeep_i (Option.value keep ~default:((1 lsl List.length bytes) - 1));
  set t i.s_axis_tx_tlast_i (Bool.to_int last);
  set t i.s_axis_tx_tuser_i (Bool.to_int user);
  set t i.s_axis_tx_tvalid_i 1;
  advance t 1;
  let rec loop remaining =
    if remaining = 0 then failwith "TX stuck";
    before_edge t t.tx_half 2;
    let ready = get t.sim.output.s_axis_tx_tready_o = 1 in
    advance t 1;
    if not ready then loop (remaining - 1)
  in
  loop 2000;
  set t i.s_axis_tx_tvalid_i 0;
  advance t 1
;;

let send_frame t ?(gap = 0) ?(user = false) bytes =
  let rec loop = function
    | [] -> ()
    | remaining ->
      let #(beat, rest) = List.split_n remaining 8 in
      send_beat t ~user ~last:(List.is_empty rest) beat;
      advance t gap;
      loop rest
  in
  loop bytes
;;

let idle = { data = Bits.of_hex ~width:64 "0707070707070707"; control = 255 }

let start_inject t words =
  assert (List.is_empty t.rx_pending);
  before_edge t t.rx_half 3;
  advance t 1;
  match words with
  | [] -> ()
  | word :: rest ->
    set_bits t t.sim.input.xgmii_rxd_i word.data;
    set t t.sim.input.xgmii_rxc_i word.control;
    t.rx_pending <- rest @ [ idle ]
;;

let inject t words =
  start_inject t words;
  wait t ~label:"XGMII peer" (fun () -> List.is_empty t.rx_pending);
  advance t 1
;;

let encode ?(lane = 0) ?(bad = false) bytes =
  let fcs = Hardcaml_verif.Crc32.fcs_bytes bytes in
  let fcs = List.mapi fcs ~f:(fun j byte -> if bad && j = 0 then byte lxor 1 else byte) in
  let events =
    List.init lane ~f:(Fn.const (7, true))
    @ [ 251, true ]
    @ List.init 6 ~f:(Fn.const (85, false))
    @ [ 213, false ]
    @ List.map (bytes @ fcs) ~f:(fun byte -> byte, false)
    @ [ 253, true ]
  in
  let events =
    events @ List.init ((8 - (List.length events mod 8)) mod 8) ~f:(Fn.const (7, true))
  in
  List.chunks_of events ~length:8
  |> List.map ~f:(fun lanes ->
    { data = pack (List.map lanes ~f:fst)
    ; control =
        List.foldi lanes ~init:0 ~f:(fun j mask (_, c) -> mask lor (Bool.to_int c lsl j))
    })
;;

let snapshot t = write_ok t 0x1c 1
