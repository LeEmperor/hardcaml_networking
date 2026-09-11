(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_tx_ingress.ml" *)
(* AXI4-Stream frame validation and transactional TX-buffer control. *)

open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val max_supported_frame_length : int
  val buffer_length_width : int
end

module Make (Config : Config) = struct
  let () =
    if Config.max_supported_frame_length < 64
       || Config.max_supported_frame_length > 0xffff
    then invalid_arg "Mac_10g_tx_ingress: max_supported_frame_length must be in 64..65535";
    if Config.buffer_length_width < 4 || Config.buffer_length_width > 17
    then invalid_arg "Mac_10g_tx_ingress: buffer_length_width must be in 4..17"
  ;;

  module I = struct
    type 'a t =
      { clock_i : 'a
      ; reset_i : 'a
      ; enable_i : 'a
      ; counters_clear_i : 'a
      ; max_frame_length_i : 'a [@bits 16]
      ; axis_data_i : 'a [@bits 64]
      ; axis_keep_i : 'a [@bits 8]
      ; axis_valid_i : 'a
      ; axis_last_i : 'a
      ; axis_user_i : 'a
      ; buffer_write_ready_i : 'a
      ; buffer_commit_ready_i : 'a
      ; buffer_frame_length_i : 'a [@bits Config.buffer_length_width]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { axis_ready_o : 'a
      ; buffer_write_data_o : 'a [@bits 64]
      ; buffer_write_keep_o : 'a [@bits 8]
      ; buffer_write_valid_o : 'a
      ; buffer_commit_o : 'a
      ; buffer_rollback_o : 'a
      ; frame_commit_pulse_o : 'a
      ; drop_pulse_o : 'a
      ; malformed_pulse_o : 'a
      ; drops_o : 'a [@bits 64]
      ; malformed_frames_o : 'a [@bits 64]
      }
    [@@deriving hardcaml]
  end

  [@@@ocamlformat "disable"]

  let create (scope : Scope.t) (i : _ I.t) : _ O.t =
    (* spec *)
    let spec = Reg_spec.create ~clock:i.clock_i ~clear:i.reset_i () in

    (* helpers *)
    let ( -- ) = Scope.naming scope in
    let reg_var width = Always.Variable.reg ~enable:vdd ~width spec in

    let dropping          = reg_var 1 in
    let malformed         = reg_var 1 in
    let pending_commit    = reg_var 1 in
    let in_frame = reg_var 1 in
    let frame_limit = reg_var 17 in
    (* Capture the bounded wire limit on the first accepted beat. An enable or
       length update cannot strand or reclassify a partially accepted frame. *)
    let bounded_limit =
      mux2 (i.max_frame_length_i >:. Config.max_supported_frame_length)
        (of_int_trunc ~width:17 Config.max_supported_frame_length)
        (uresize i.max_frame_length_i ~width:17)
    in
    let effective_limit = mux2 in_frame.value frame_limit.value bounded_limit in
    let payload_limit = effective_limit -:. 4 in

    (* diag regs *)
    let drops             = reg_var 64 in
    let malformed_frames  = reg_var 64 in
    let keep_legal        =
      Mac_10g_axis.beat_has_legal_keep ~keep:i.axis_keep_i ~last:i.axis_last_i
    in

    (* popcount of the beat *)
    let beat_count = Mac_10g_axis.keep_byte_count i.axis_keep_i in

    (* *)
    let frame_length_after_beat =
      uresize i.buffer_frame_length_i ~width:17 +: uresize beat_count ~width:17
    in

    (* asd *)
    let length_legal =
      frame_length_after_beat
      >=:. 14
      &: (frame_length_after_beat <=: payload_limit)
    in
    (* The packet buffer has no maximum-frame guard of its own, so an over-length frame
       has to be rejected on the beat that crosses the limit, not at [axis_last_i].
       Deferring it lets a frame fill the byte ring, and a full ring holding an
       uncommitted frame stalls the whole TX path until that frame finally ends. The
       short-frame half of [length_legal] stays on the final beat, which is the only place
       it means anything.
    *)
    let over_length =
      (frame_length_after_beat >: payload_limit) -- "over_length"
    in

    let final_rejected = i.axis_last_i &: (i.axis_user_i |: ~:length_legal) in
    let reject_current = ~:keep_legal |: over_length |: final_rejected in

    (* enable fanout might be bad *)
    let ready =
      ((i.enable_i |: in_frame.value) &: ~:(i.reset_i)
       &: ~:(pending_commit.value)
       &: mux2 (dropping.value |: reject_current) vdd i.buffer_write_ready_i)
      -- "axis_ready"
    in

    (* handshake *)
    let accepted = (i.axis_valid_i &: ready) -- "axis_accepted" in

    (* handshake good; but the beat is bad *)
    let accepted_reject = accepted &: reject_current in

    (* handshake good; beat is good *)
    let accepted_good = accepted &: ~:(dropping.value) &: ~:reject_current in

    (* handshake + beat good + last in the beat *)
    let commit_request = accepted_good &: i.axis_last_i in
    let commit = (pending_commit.value |: commit_request) -- "buffer_commit" in
    let rollback = (accepted_reject &: ~:(dropping.value)) -- "buffer_rollback" in
    let completed_drop =
      (accepted &: i.axis_last_i &: (dropping.value |: reject_current))
      -- "completed_drop"
    in
    let completed_malformed =
      (completed_drop &: (malformed.value |: ~:keep_legal |: ~:length_legal))
      -- "completed_malformed"
    in

    (* main seq blocks  *)
    Always.(
      compile
        [ when_ (accepted &: ~:(in_frame.value)) [ frame_limit <-- bounded_limit ]
        ; when_ accepted [ in_frame <-- ~:(i.axis_last_i) ]
        ; if_
            i.counters_clear_i (* clear all counters? *)

            (* yes - self explanatory *)
            [ drops <--. 0;
              malformed_frames <--. 0
            ]

            (* no - inc the counters *)
            [ when_ completed_drop [ drops <-- drops.value +:. 1 ]
            ; when_
                completed_malformed
                [ malformed_frames <-- malformed_frames.value +:. 1 ]
            ]

        (* if the commit is being requested, and the buffer is NOT ready to commit; list a pending *)
        ; when_ (commit_request &:
                 ~:(i.buffer_commit_ready_i)
                )
            [ pending_commit <--. 1 ]

        (* if the commit is being requested, and the buffer is ready to commit; pending commit is no longer *)
        ; when_
            (pending_commit.value &: i.buffer_commit_ready_i)
            [ pending_commit <--. 0 ]
        ; when_
            accepted
            [ if_
                i.axis_last_i (* check last; *)
                [ dropping <--. 0; malformed <--. 0 ]
                [ when_
                    (~:(dropping.value) &: reject_current)
                    [ dropping <--. 1; malformed <-- (~:keep_legal |: ~:length_legal) ]
                ]
            ]
        ]);

    { O.axis_ready_o = ready
    ; buffer_write_data_o = i.axis_data_i
    ; buffer_write_keep_o = i.axis_keep_i
    ; buffer_write_valid_o = accepted_good
    ; buffer_commit_o = commit
    ; buffer_rollback_o = rollback
    ; frame_commit_pulse_o = commit &: i.buffer_commit_ready_i
    ; drop_pulse_o = completed_drop
    ; malformed_pulse_o = completed_malformed
    ; drops_o = drops.value
    ; malformed_frames_o = malformed_frames.value
    }

  [@@@ocamlformat "enable"]

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical
      ?instance
      ~scope
      ~name:(sprintf "mac_10g_tx_ingress_%d" Config.max_supported_frame_length)
      create
      i
  ;;
end
