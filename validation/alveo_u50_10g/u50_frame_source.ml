(* Module: U50_frame_source

   Autonomous AXI4-Stream Ethernet frame source for U50 hardware validation. Implements
   docs/mac_10g_u50_tx_validation_plan.md sections 6 and 6.2.

   It is autonomous by design: the U50 has no pushbutton, and requiring PCIe or XDMA to
   trigger a frame would make first bring-up depend on the host interface this design
   deliberately omits. After startup it emits one frame, waits an interval, increments a
   sequence number, and repeats.

   The Arty harnesses put the equivalent stimulus FSM inline in the harness because it was
   driven by btn[3] and therefore board-specific. This one is a real Hardcaml module with
   its own I/O, so the same source can feed the TX, RX, and loopback harnesses, and can be
   simulated on its own against the existing XGMII decoder.

   Frame layout, 60 AXI bytes -> 64 wire bytes with FCS:

   bytes 0..5 ff:ff:ff:ff:ff:ff destination (broadcast) bytes 6..11 02:00:00:00:00:01
   source (locally administered) bytes 12..13 0x99 0x99 EtherType 0x9999 bytes 14..17
   sequence number, big-endian bytes 18..59 0x00, 0x01, ... 0x29 42-byte incrementing
   pattern

   Broadcast destination means the peer NIC accepts the frame without a MAC filter entry.
   EtherType 0x9999 is unassigned, so no host stack claims it and a raw capture sees it
   untouched. The sequence number lets the host detect missing, duplicated, reordered, or
   restarted traffic from the capture alone.

   Byte 0 occupies tdata[7:0] and later bytes occupy increasing lanes, per section 4 of
   docs/mac_10g_interface_contract.md.

   This file was heavily edited by AI, as I find no use in wasting away at writing
   validation harnesses myself. If you have problems with this, bite me.
*)

open! Core
open! Hardcaml
open! Signal

(* Reset is handled by [reset_i]; the plan's Reset and Settling states are the harness's
   startup gate (U50_scaffolding.startup) driving [start_i].

   Wait_for_completion from the plan is deliberately absent. The MAC is store-and-forward:
   once the final beat is accepted the frame is committed and cannot underflow. With a
   one-second interval against an 8192-byte ring there is no way to overrun the buffer, so
   waiting on a completion indication would only add a dependency on TX status without
   changing behaviour. Re-add it if the interval ever drops toward line rate. *)
module States = struct
  type t =
    | Idle
    | Send
    | Interval
  [@@deriving sexp_of, compare ~localize, enumerate]
end

module I = struct
  type 'a t =
    { clock_i : 'a
    ; reset_i : 'a
    ; enable_i : 'a
    ; (* Hold low until the PCS/GT link stack is up and settled. *)
      start_i : 'a
    ; s_axis_tready_i : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { s_axis_tdata_o : 'a [@bits 64]
    ; s_axis_tkeep_o : 'a [@bits 8]
    ; s_axis_tvalid_o : 'a
    ; s_axis_tlast_o : 'a
    ; s_axis_tuser_o : 'a
    ; (* Sequence number carried by the frame currently being presented. *)
      sequence_o : 'a [@bits 32]
    ; (* One cycle when the final beat is accepted, i.e. one frame committed. *)
      frame_pulse_o : 'a
    ; state_o : 'a [@bits 2]
    ; keep : 'a
    }
  [@@deriving hardcaml]
end

let frame_bytes = 60
let beats = (frame_bytes + 7) / 8
let final_keep = frame_bytes - ((beats - 1) * 8)

(* The 60 frame bytes, least-significant byte of the frame first. Only bytes 14..17 vary;
   everything else folds to a constant at elaboration. *)
let frame_byte_signals ~sequence =
  let k value = of_int_trunc ~width:8 value in
  let sequence_byte n = select sequence ~high:((8 * n) + 7) ~low:(8 * n) in
  List.concat
    [ List.init 6 ~f:(fun _ -> k 0xff)
    ; List.map [ 0x02; 0x00; 0x00; 0x00; 0x00; 0x01 ] ~f:k
    ; [ k 0x99; k 0x99 ]
    ; (* Big-endian on the wire, so a host capture reads the counter directly. *)
      [ sequence_byte 3; sequence_byte 2; sequence_byte 1; sequence_byte 0 ]
    ; List.init (frame_bytes - 18) ~f:(fun i -> k (i land 0xff))
    ]
;;

(* Group the frame into 64-bit beats. The final beat is short, so pad it to a full word;
   [tkeep] is what tells the MAC which lanes are real. *)
let frame_beat_words ~sequence =
  frame_byte_signals ~sequence
  |> List.chunks_of ~length:8
  |> List.map ~f:(fun chunk ->
    let padding = List.init (8 - List.length chunk) ~f:(fun _ -> zero 8) in
    concat_lsb (chunk @ padding))
;;

let create ?(interval_cycles = 156_250_000) (scope : Scope.t) (i : _ I.t) : _ O.t =
  let ( -- ) = Scope.naming scope in
  let spec = Reg_spec.create ~clock:i.clock_i ~clear:i.reset_i () in
  let sm = Always.State_machine.create (module States) ~enable:vdd spec in
  let beat_width = Int.ceil_log2 beats in
  let beat = Always.Variable.reg ~enable:vdd ~width:beat_width spec in
  let sequence = Always.Variable.reg ~enable:vdd ~width:32 spec in
  let interval_width = Int.ceil_log2 (interval_cycles + 1) in
  let interval = Always.Variable.reg ~enable:vdd ~width:interval_width spec in
  let tvalid = Always.Variable.wire ~default:gnd () in
  let frame_pulse = Always.Variable.wire ~default:gnd () in
  let words = frame_beat_words ~sequence:sequence.value in
  let tdata = mux beat.value words -- "source_tdata" in
  let last_beat = (beat.value ==:. beats - 1) -- "source_last_beat" in
  let tkeep =
    mux2 last_beat (of_int_trunc ~width:8 ((1 lsl final_keep) - 1)) (ones 8)
    -- "source_tkeep"
  in
  (* A beat is transferred only when both valid and ready are high; everything the source
     presents must stay stable while stalled, which it does because tdata and tkeep are
     functions of registers that only advance on [accepted]. *)
  let accepted = (tvalid.value &: i.s_axis_tready_i) -- "source_accepted" in
  Always.(
    compile
      [ sm.switch
          [ ( Idle
            , [ beat <-- zero beat_width
              ; interval <-- zero interval_width
              ; when_ (i.enable_i &: i.start_i) [ sm.set_next Send ]
              ] )
          ; ( Send
            , [ tvalid <-- vdd
              ; when_
                  accepted
                  [ beat <-- beat.value +:. 1
                  ; when_
                      last_beat
                      [ frame_pulse <-- vdd
                      ; beat <-- zero beat_width
                      ; sequence <-- sequence.value +:. 1
                      ; sm.set_next Interval
                      ]
                  ]
              ] )
          ; ( Interval
            , [ interval <-- interval.value +:. 1
              ; when_
                  (interval.value ==:. interval_cycles)
                  [ interval <-- zero interval_width; sm.set_next Idle ]
              ] )
          ]
        (* Losing enable or the link mid-frame abandons the partial frame rather than
           leaving tvalid stuck. The MAC discards an uncommitted speculative frame on its
           own soft reset, so nothing is left half-written in the ring. *)
      ; when_ ~:(i.enable_i &: i.start_i) [ sm.set_next Idle; beat <-- zero beat_width ]
      ]);
  let keep =
    [ tdata; tkeep; sequence.value; sm.current; accepted ]
    |> List.map ~f:(fun s -> reduce ~f:( |: ) (bits_lsb s))
    |> reduce ~f:( |: )
  in
  { O.s_axis_tdata_o = tdata
  ; s_axis_tkeep_o = tkeep
  ; s_axis_tvalid_o = tvalid.value -- "source_tvalid"
  ; s_axis_tlast_o = last_beat &: tvalid.value
  ; (* Never requests a discard: this source only ever emits well-formed frames. *)
    s_axis_tuser_o = gnd
  ; sequence_o = sequence.value -- "source_sequence"
  ; frame_pulse_o = frame_pulse.value -- "source_frame_pulse"
  ; state_o = uresize sm.current ~width:2 -- "source_state"
  ; keep
  }
;;

let hierarchical ?interval_cycles ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"u50_frame_source" (create ?interval_cycles) i
;;
