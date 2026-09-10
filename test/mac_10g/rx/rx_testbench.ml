(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "rx_testbench.ml" *)

open! Core
open! Hardcaml
open! Signal
open! Hardcaml_verif
open! Mac_10g_of_hardcaml

module Buffer = Mac_10g_packet_buffer.Make (struct
    let depth_bytes = 256
    let descriptor_capacity = 4
    let error_width = Mac_10g_rx.Error.width
  end)

module Parser = Mac_10g_rx.Make (struct
    let max_supported_frame_length = 255
  end)

module Egress = Mac_10g_rx_egress.Make (struct
    let error_width = Mac_10g_rx.Error.width
  end)

module Dut = struct
  module I = struct
    type 'a t =
      { clock_i : 'a
      ; reset_i : 'a
      ; enable_i : 'a
      ; counters_clear_i : 'a
      ; drop_bad_i : 'a
      ; ready_i : 'a
      ; data_i : 'a [@bits 64]
      ; control_i : 'a [@bits 8]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { data_o : 'a [@bits 64]
      ; keep_o : 'a [@bits 8]
      ; valid_o : 'a
      ; last_o : 'a
      ; user_o : 'a
      ; state_o : 'a [@bits 3]
      ; good_frames_o : 'a [@bits 64]
      ; bad_frames_o : 'a [@bits 64]
      ; bytes_o : 'a [@bits 64]
      ; fcs_errors_o : 'a [@bits 64]
      ; length_errors_o : 'a [@bits 64]
      ; xgmii_errors_o : 'a [@bits 64]
      ; overflow_drops_o : 'a [@bits 64]
      ; local_fault_o : 'a
      ; remote_fault_o : 'a
      }
    [@@deriving hardcaml]
  end

  let create scope (i : _ I.t) : _ O.t =
    let write_data = wire 64 in
    let write_keep = wire 8 in
    let write_valid = wire 1 in
    let commit = wire 1 in
    let rollback = wire 1 in
    let commit_error = wire Mac_10g_rx.Error.width in
    let read_ready = wire 1 in
    let buffer =
      Buffer.create
        (Scope.sub_scope scope "buffer")
        { Buffer.I.clock_i = i.clock_i
        ; reset_i = i.reset_i
        ; write_data_i = write_data
        ; write_keep_i = write_keep
        ; write_valid_i = write_valid
        ; commit_i = commit
        ; rollback_i = rollback
        ; commit_error_i = commit_error
        ; read_ready_i = read_ready
        }
    in
    let parser =
      Parser.create
        (Scope.sub_scope scope "parser")
        { Parser.I.clock_i = i.clock_i
        ; reset_i = i.reset_i
        ; enable_i = i.enable_i
        ; counters_clear_i = i.counters_clear_i
        ; max_frame_length_i = of_int_trunc ~width:16 255
        ; xgmii_data_i = i.data_i
        ; xgmii_control_i = i.control_i
        ; buffer_write_ready_i = buffer.write_ready_o
        ; buffer_commit_ready_i = buffer.commit_ready_o
        }
    in
    let egress =
      Egress.create
        (Scope.sub_scope scope "egress")
        { Egress.I.clock_i = i.clock_i
        ; reset_i = i.reset_i
        ; enable_i = i.enable_i
        ; drop_bad_i = i.drop_bad_i
        ; axis_ready_i = i.ready_i
        ; buffer_data_i = buffer.read_data_o
        ; buffer_keep_i = buffer.read_keep_o
        ; buffer_valid_i = buffer.read_valid_o
        ; buffer_last_i = buffer.read_last_o
        ; buffer_error_i = buffer.read_error_o
        }
    in
    Signal.(write_data <-- parser.buffer_write_data_o);
    Signal.(write_keep <-- parser.buffer_write_keep_o);
    Signal.(write_valid <-- parser.buffer_write_valid_o);
    Signal.(commit <-- parser.buffer_commit_o);
    Signal.(rollback <-- parser.buffer_rollback_o);
    Signal.(commit_error <-- parser.buffer_commit_error_o);
    Signal.(read_ready <-- egress.buffer_ready_o);
    { O.data_o = egress.axis_data_o
    ; keep_o = egress.axis_keep_o
    ; valid_o = egress.axis_valid_o
    ; last_o = egress.axis_last_o
    ; user_o = egress.axis_user_o
    ; state_o = parser.state_o
    ; good_frames_o = parser.good_frames_o
    ; bad_frames_o = parser.bad_frames_o
    ; bytes_o = parser.bytes_o
    ; fcs_errors_o = parser.fcs_errors_o
    ; length_errors_o = parser.length_errors_o
    ; xgmii_errors_o = parser.xgmii_errors_o
    ; overflow_drops_o = parser.overflow_drops_o
    ; local_fault_o = parser.local_fault_o
    ; remote_fault_o = parser.remote_fault_o
    }
  ;;
end

module Xword = struct
  type t =
    { bytes : int list
    ; control : int
    }
  [@@deriving sexp, equal]

  let idle = { bytes = List.init 8 ~f:(Fn.const 0x07); control = 0xff }
end

let chunks_of_events events =
  let rec loop events =
    match events with
    | [] -> []
    | _ ->
      let #(word, rest) = List.split_n events 8 in
      let bytes = List.map word ~f:fst in
      let control =
        List.foldi word ~init:0 ~f:(fun lane mask (_, is_control) ->
          if is_control then mask lor (1 lsl lane) else mask)
      in
      { Xword.bytes; control } :: loop rest
  in
  loop events
;;

let encode_frame ?(start_lane = 0) ?(bad_fcs = false) payload =
  let fcs = Crc32.fcs_bytes payload in
  let wire =
    payload
    @
    if bad_fcs
    then List.mapi fcs ~f:(fun index byte -> if index = 0 then byte lxor 1 else byte)
    else fcs
  in
  let idle = 0x07, true in
  let data byte = byte, false in
  let control byte = byte, true in
  let events =
    match start_lane with
    | 0 ->
      [ control 0xfb ]
      @ List.init 6 ~f:(Fn.const (data 0x55))
      @ [ data 0xd5 ]
      @ List.map wire ~f:data
      @ [ control 0xfd ]
    | 4 ->
      List.init 4 ~f:(Fn.const idle)
      @ [ control 0xfb ]
      @ List.init 6 ~f:(Fn.const (data 0x55))
      @ [ data 0xd5 ]
      @ List.map wire ~f:data
      @ [ control 0xfd ]
    | lane -> invalid_argf "illegal start lane %d" lane ()
  in
  let padding = (8 - (List.length events mod 8)) mod 8 in
  chunks_of_events (events @ List.init padding ~f:(Fn.const idle))
;;

module Result = struct
  type t =
    { payload : int list
    ; final_user : bool option
    ; good_frames : int
    ; bad_frames : int
    ; bytes : int
    ; fcs_errors : int
    ; length_errors : int
    ; xgmii_errors : int
    ; overflow_drops : int
    ; stable_while_stalled : bool
    ; final_state : int
    ; saw_local_fault : bool
    ; saw_remote_fault : bool
    }
  [@@deriving sexp, equal]
end

module Testbench = struct
  module Sim = Cyclesim.With_interface (Dut.I) (Dut.O)

  let bits_of_bytes bytes =
    List.init 8 ~f:(fun lane -> List.nth bytes lane |> Option.value ~default:0)
    |> List.map ~f:(Bits.of_int_trunc ~width:8)
    |> Bits.concat_lsb
  ;;

  let input
    ?(reset = false)
    ?(enable = true)
    ?(counters_clear = false)
    ?(drop_bad = false)
    ?(ready = true)
    word
    =
    { Dut.I.clock_i = Bits.empty
    ; reset_i = Bits_conv.bit reset
    ; enable_i = Bits_conv.bit enable
    ; counters_clear_i = Bits_conv.bit counters_clear
    ; drop_bad_i = Bits_conv.bit drop_bad
    ; ready_i = Bits_conv.bit ready
    ; data_i = bits_of_bytes word.Xword.bytes
    ; control_i = Bits.of_int_trunc ~width:8 word.control
    }
  ;;

  let drive refs values =
    Dut.I.iter2 refs values ~f:(fun reference value ->
      if not (Bits.is_empty value) then reference := value)
  ;;

  let run
    ?(drop_bad = false)
    ?(drop_bad_at = fun _ -> drop_bad)
    ?(ready = fun _ -> true)
    ?(enable = fun _ -> true)
    ?(counters_clear = fun _ -> false)
    words
    =
    let sim = Sim.create (Dut.create (Scope.create ~flatten_design:true ())) in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs ~clock_edge:Before sim in
    let raw value =
      drive inputs value;
      Cyclesim.cycle sim
    in
    raw (input ~reset:true Xword.idle);
    raw (input ~reset:true Xword.idle);
    raw (input Xword.idle);
    let output_bytes = ref [] in
    let final_user = ref None in
    let stable = ref true in
    let saw_local_fault = ref false in
    let saw_remote_fault = ref false in
    let stalled_value = ref None in
    let last_outputs = ref None in
    List.iteri
      (words @ List.init 80 ~f:(Fn.const Xword.idle))
      ~f:(fun cycle word ->
        let sink_ready = ready cycle in
        drive
          inputs
          (input
             ~enable:(enable cycle)
             ~counters_clear:(counters_clear cycle)
             ~drop_bad:(drop_bad_at cycle)
             ~ready:sink_ready
             word);
        Cyclesim.cycle_before_clock_edge sim;
        let o = Dut.O.map outputs ~f:( ! ) in
        last_outputs := Some o;
        let valid = Bits_conv.to_bool o.valid_o in
        saw_local_fault := !saw_local_fault || Bits_conv.to_bool o.local_fault_o;
        saw_remote_fault := !saw_remote_fault || Bits_conv.to_bool o.remote_fault_o;
        let held = o.data_o, o.keep_o, o.last_o, o.user_o in
        (match !stalled_value with
         | Some (a, b, c, d)
           when not
                  (Bits.equal a o.data_o
                   && Bits.equal b o.keep_o
                   && Bits.equal c o.last_o
                   && Bits.equal d o.user_o) -> stable := false
         | _ -> ());
        stalled_value := if valid && not sink_ready then Some held else None;
        if valid && sink_ready
        then (
          let keep = Bits.to_int_trunc o.keep_o in
          List.iter (List.range 0 8) ~f:(fun lane ->
            if keep land (1 lsl lane) <> 0
            then
              output_bytes
              := (Bits.select o.data_o ~high:((8 * lane) + 7) ~low:(8 * lane)
                  |> Bits.to_int_trunc)
                 :: !output_bytes);
          if Bits_conv.to_bool o.last_o
          then final_user := Some (Bits_conv.to_bool o.user_o));
        Cyclesim.cycle_at_clock_edge sim;
        Cyclesim.cycle_after_clock_edge sim);
    let o = Option.value_exn !last_outputs in
    { Result.payload = List.rev !output_bytes
    ; final_user = !final_user
    ; good_frames = Bits.to_int_trunc o.good_frames_o
    ; bad_frames = Bits.to_int_trunc o.bad_frames_o
    ; bytes = Bits.to_int_trunc o.bytes_o
    ; fcs_errors = Bits.to_int_trunc o.fcs_errors_o
    ; length_errors = Bits.to_int_trunc o.length_errors_o
    ; xgmii_errors = Bits.to_int_trunc o.xgmii_errors_o
    ; overflow_drops = Bits.to_int_trunc o.overflow_drops_o
    ; stable_while_stalled = !stable
    ; final_state = Bits.to_int_trunc o.state_o
    ; saw_local_fault = !saw_local_fault
    ; saw_remote_fault = !saw_remote_fault
    }
  ;;
end
