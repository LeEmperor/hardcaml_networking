(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_rx.ml" *)
(* XGMII receive parser with strict preamble validation, four-byte FCS holdback,
   transactional packet-buffer control, error classification, and RX statistics.
*)

open! Core
open! Hardcaml
open! Signal
open! Xgmii_of_hardcaml

module type Config = sig
  val max_supported_frame_length : int
end

module Error = struct
  let width = 3
  let fcs = 0
  let length = 1
  let xgmii = 2
end

module Make (Config : Config) = struct
  let () =
    if Config.max_supported_frame_length < 64
       || Config.max_supported_frame_length > 0xffff
    then invalid_arg "Mac_10g_rx: max_supported_frame_length must be in 64..65535"
  ;;

  module I = struct
    type 'a t =
      { clock_i : 'a
      ; reset_i : 'a
      ; enable_i : 'a
      ; counters_clear_i : 'a
      ; max_frame_length_i : 'a [@bits 16]
      ; xgmii_data_i : 'a [@bits 64]
      ; xgmii_control_i : 'a [@bits 8]
      ; buffer_write_ready_i : 'a
      ; buffer_commit_ready_i : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { buffer_write_data_o : 'a [@bits 64]
      ; buffer_write_keep_o : 'a [@bits 8]
      ; buffer_write_valid_o : 'a
      ; buffer_commit_o : 'a
      ; buffer_rollback_o : 'a
      ; buffer_commit_error_o : 'a [@bits Error.width]
      ; state_o : 'a [@bits 3]
      ; good_frame_pulse_o : 'a
      ; bad_frame_pulse_o : 'a
      ; overflow_pulse_o : 'a
      ; local_fault_o : 'a
      ; remote_fault_o : 'a
      ; good_frames_o : 'a [@bits 64]
      ; bad_frames_o : 'a [@bits 64]
      ; bytes_o : 'a [@bits 64]
      ; fcs_errors_o : 'a [@bits 64]
      ; length_errors_o : 'a [@bits 64]
      ; xgmii_errors_o : 'a [@bits 64]
      ; overflow_drops_o : 'a [@bits 64]
      }
    [@@deriving hardcaml]
  end

  (* id like to adhere to good state idioms here lmao *)
  (* nvm we'll eat this later *)
  module State = struct
    type t =
      | Idle
      | Premable_Lane4
      | Frame
      | Discard
      | Commit
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  (* Parser states are exposed numerically for waveform/debug visibility. Ultimatley quite
     poor; I eventually will standardize the approach I've taken to them, but still cannot
     figure out a good canonical approach to it since larger-example designs don't exist
     with enough structuring outside of maybe Hardcaml_circuits.Stack
  *)
  let state_idle = 0
  let state_preamble_lane4 = 1
  let state_frame = 2
  let state_discard = 3
  let state_commit = 4

  (* Extract one wire-order byte lane. *)
  let byte data lane = select data ~high:((8 * lane) + 7) ~low:(8 * lane)

  let word_equal ~data ~control (word : Signal.t Xgmii.Word.t) =
    data ==: word.data &: (control ==: word.control)
  ;;

  (* Select byte [position] from the compact concatenation of the old tail and this
     cycle's data prefix. [tail_count] is only 0..4; the remaining mux arms are defensive
     don't-care values
  *)
  let combined_byte ~tail_data ~tail_count ~body_data position =
    mux
      tail_count
      (List.init 8 ~f:(fun count ->
         if count > 4
         then zero 8
         else if position < count
         then byte tail_data position
         else if position - count < 8
         then byte body_data (position - count)
         else zero 8))
  ;;

  [@@@ocamlformat "disable"]

  let create (scope : Scope.t) (i : _ I.t) : _ O.t =
    (* spec *)
    let spec = Reg_spec.create ~clock:i.clock_i ~clear:i.reset_i () in

    (* Hierarchical signal naming helper. *)
    let ( -- ) = Scope.naming scope in

    (* standard users *)
    let reg_var width = Always.Variable.reg ~enable:vdd ~width spec in
    let state = reg_var 3 in

    (* forward declarations *)

    (* crc reg *)
    let crc                     = reg_var 32 in

    (* running 17b counter of the bytes in the frame *)
    let wire_length             = reg_var 17 in
    let tail_data               = reg_var 32 in (* carried over bytes *)
    let tail_count              = reg_var 3 in (* bytes carried over in tail_data *)

    (* encoding error - /T seen in a bad neighborhood for example *)
    let xgmii_error             = reg_var 1 in
    (* commit_ready_i was low but an error pended *)
    let pending_error           = reg_var Error.width in

    (* while stalled in a commit, a new /S arrived - that frmae becomes lost;
       overflow_pulse sticky fires once
    *)
    let missed_while_committing = reg_var 1 in

    (* Discard entered becuase of oversize *)
    (* discard/commit paradigm used in speculative approach
       either make it visible with buffer_commit_o
        or rollback with buffer_rollback_o

      Discard: frame died and we're discarding junk until a new /T
      Commit: the frame was good, but the buffe wasn't ready to take the commit
          thus we need to hold buffer_commit_o until consumed and NOT loose the error word
    *)
    let discard_length_error    = reg_var 1 in

    (* Discar entered because of encoding violation; supresses double counts *)
    let discard_xgmii_error     = reg_var 1 in

    (* diagnostic counters *)
    let good_frames             = reg_var 64 in
    let bad_frames              = reg_var 64 in
    let bytes                   = reg_var 64 in
    let fcs_errors              = reg_var 64 in
    let length_errors           = reg_var 64 in
    let xgmii_errors            = reg_var 64 in
    let overflow_drops          = reg_var 64 in

    (* PPX maxxing *)
    let is_idle           = state.value ==:. state_idle in
    let is_preamble_lane4 = state.value ==:. state_preamble_lane4 in
    let is_frame          = state.value ==:. state_frame in
    let is_discard        = state.value ==:. state_discard in
    let is_commit         = state.value ==:. state_commit in

    (* cousins of the XGMII library items *)
    let lane_byte     lane = byte i.xgmii_data_i lane in
    let lane_control  lane = bit i.xgmii_control_i ~pos:lane in
    let lane_is       lane value = lane_byte lane ==:. value in

    (* composed into any_start *)
    let start_lane0 = lane_control 0 &: lane_is 0 Xgmii.Control_character.start in
    let start_lane4 = lane_control 4 &: lane_is 4 Xgmii.Control_character.start in

    (* per XGMII, only recognize starts in lanes 0 or 4 *)
    let any_start = start_lane0 |: start_lane4 in

    (*
      Example: this is what a good 0'd /S frame looks like for the preamble beat
        xgmii_data_i    = 64'hD5_55_55_55_55_55_55_FB
        xgmii_control_i = 8'b00000001
    *)

    (* seven bytes after /S appear fine *)
    let lane0_preamble_bytes_good =
      List.range 1 7 (* from 1 to 6 *)
      |> List.fold ~init:vdd ~f:(fun valid lane ->
          (* is the lane valid && the lane's value is specifically 0x55 *)
          valid &: lane_is lane 0x55)
      |> fun valid -> valid &: lane_is 7 0xd5 (* pipe into specifically the last thing is the SFD *)
    in

    (* based on a lane 0 /S appearance,
      is the start in lane 0?
      && is the control mask on lane 0 correct?
      && are the preamble bytes correct?
    *)
    let lane0_preamble_good =
      start_lane0 &:
      (i.xgmii_control_i ==:. 0x01) &:
      lane0_preamble_bytes_good
    in

    (* lane 4 equivalent for checking start validity *)
    (* in this case, we have to verify that the lanes before 4 are IDLE XGMII words *)

    (*
      Example: this is what a lane4-starting frame should look like
        xgmii_data_i    = 64'h55_55_55_FB_07_07_07_07
        xgmii_control_i = 8'b0001_1111 (this is 0x1F)
    *)
    let lane4_prefix_good =
      List.range 0 4
      |> List.fold ~init:vdd ~f:(fun valid lane ->
        valid &: lane_is lane Xgmii.Control_character.idle)
    in

    let lane4_preamble_bytes_good =
      List.range 5 8
      |> List.fold ~init:vdd ~f:(fun valid lane -> valid &: lane_is lane 0x55)
    in

    let lane4_preamble_good =
      start_lane4
      &: (i.xgmii_control_i ==:. 0x1f) (* should have idle bytes leading into the control 0xFB*)
      &: lane4_prefix_good
      &: lane4_preamble_bytes_good
    in

    (* the lane4 preamble finishes correctly on the next XGMII beat *)
    let lane4_finish_good =
      i.xgmii_control_i
      &: of_int_trunc ~width:8 0x0f ==:. 0 (* binding power here is strange *)
      &: lane_is 0 0x55
      &: lane_is 1 0x55
      &: lane_is 2 0x55
      &: lane_is 3 0xd5
    in

    (* Lane-4 starts put the first four frame bytes in lanes 4..7 of the following word.
       Compact them to lanes 0..3 so the body machinery is alignment-neutral.

      This may have timing implications with a pre-emptive crossbar. We'll see.
    *)
    let body_data = mux2 is_preamble_lane4 (srl i.xgmii_data_i ~by:32) i.xgmii_data_i in
    let body_control =
      mux2

        (* Is the preamble in lane 4? *)
        is_preamble_lane4

        (* yes - snag the control word items from the high part of the mask *)
        (uresize (select i.xgmii_control_i ~high:7 ~low:4) ~width:8)

        (* no - pass the standard control word items *)
        i.xgmii_control_i
    in

    let available_count =
      mux2
        (* if preamble is *)
        is_preamble_lane4
        (of_int_trunc ~width:4 4)
        (of_int_trunc ~width:4 8)
    in

    (* more helpers *)
    let body_lane_active  lane = of_int_trunc ~width:4 lane <: available_count in
    let body_lane_control lane = bit body_control ~pos:lane in
    let body_lane_byte    lane = byte body_data lane in

    let terminate_at =
      (* build indexable 8-sized array of lanes *)
      Array.init 8 ~f:(fun lane ->
        body_lane_active lane (* is the body lane real *)
        &: body_lane_control lane (* is the body lane control? *)
        &: (body_lane_byte lane ==:. Xgmii.Control_character.terminate) (* is the body lane byte a terminate character? *)
           (* this should build us a onehot_selectable item perhaps *)
      )
    in

    (* fold it to see if any of them are terminate-candidates *)
    let terminate_present = Array.reduce_exn terminate_at ~f:( |: ) in

    (* prefixed data bits -> to be used in combined *)
    let prefix_mask_bits =
      List.init 8 ~f:(fun lane -> (* 8 Signal.t list *)
          (* confirm all lanes before the terminate character are data lanes *)
        let all_prior_lanes_are_data =
          List.range 0 lane
          |> List.fold ~init:vdd ~f:(fun valid prior_lane ->
            valid &: (~:(body_lane_active prior_lane) |: ~:(body_lane_control prior_lane)))
            (* the lane is a body active data lane, AND NOT a control lane *)
        in
        (body_lane_active lane) &:
        (all_prior_lanes_are_data) &:
        ~:(body_lane_control lane)
      )
    in

    (* build mask vector out of the prefix_mask_bits Signal.t list *)
    (* where are the body data bytes? aka if we have a terminate somewhere, then only so much
        of the beat is actually valid data info

      this stops at the first control lane
    *)
    let body_mask = concat_lsb prefix_mask_bits in

    (* pop_count out of the mask for ref *)
    let body_count = Mac_10g_axis.keep_byte_count body_mask in

    (* find the terimination location - assuming that the body mask prefixing was legal *)
    let normal_terminate_at =
      List.init 8 ~f:(fun term_lane ->

        (* eveyrthing before the terminate has to be non-control words *)
        let before_ok = (* for 0 to the lane we're touching, *)
          List.range 0 term_lane
          |> List.fold ~init:vdd ~f:(fun ok lane ->
              ok &: ~:(body_lane_control lane)
            )
        in

        (* after the terminate point, everything has to be Idle characters *)
        let after_ok =
          List.range (term_lane + 1) 8
          |> List.fold ~init:vdd ~f:(fun ok lane ->
            let inactive = ~:(body_lane_active lane) in
            let idle =
              body_lane_control lane
              &: (body_lane_byte lane ==:. Xgmii.Control_character.idle)
            in
            ok &: (inactive |: idle))
        in

        (* return the termination point, as well as packed on the fact that the before info is fine (non control mask),
          and the after stuff is Idle
        *)
        terminate_at.(term_lane) (* array indexability heeheeheehaw *)
        &: before_ok &: after_ok
        )
    in

    (* find the termination location as a list for vector comp later
        if someone terminated correctly, it gets represented into this fold tree
      *)
    let normal_terminate =
      List.reduce_exn
        normal_terminate_at ~f:( |: )
    in

    (* junk with no terminate at all -> will ultimately pend for a resync *)
    let unexpected_control =
      List.range 0 8 (* from 0 to 7 *)
      |> List.fold ~init:gnd ~f:(fun seen lane -> (* fold into *)
        seen
        |: (body_lane_active lane &: (* an or on the lane being active and control *)
            body_lane_control lane &:
            ~:(terminate_at.(lane)) (* active && control && terminate there = *)
           )
        )
    in

    (* A legal start seen while a frame is open terminates the malformed old frame, but
       is also the earliest unambiguous point at which RX can resynchronize

       Reusing that word avoids unnecessarily throwing away the following well-formed frame
    *)
    let restart_lane0 = is_frame &: lane0_preamble_good in
    let restart_lane4 = is_frame &: ~:start_lane0 &: lane4_preamble_good in
    let restart_at_start = restart_lane0 |: restart_lane4 in

    (* [enable_i] is part of the datapath handshake.

       in particular, if software
       disables RX in the middle of a frame we must not accept one last word before
       rolling the speculative packet back
    *)
    let processing_body =
      i.enable_i &:
      (is_frame |:
       (is_preamble_lane4 &: lane4_finish_good)
      )
    in

    (* crc call *)
    let crc_after_body =
      Mac_10g_crc32.update crc.value ~data:body_data ~valid_bytes:body_mask
    in

    (* wire length [frame_counter] given the amount of body we're about to commit *)
    let wire_length_after_body = wire_length.value +: (uresize body_count ~width:17) in

    (* popcount on the tailcount and bodycount combinator *)
    let combined_count =
      (uresize tail_count.value ~width:4) +: body_count
    in

    (* write count into where? the packet_buffer *)
    let write_count =
      mux2
        (* is the combined count greater than 4? *)
        (combined_count >:. 4)
        (* yes - eat the 4 *)
        (combined_count -:. 4)
        (* no - zero out *)
        (zero 4)
    in


    (*
       the last 4B of the frame are the FCS; must not reach the AXIS;
       can't know the last is reached until /T is found and validated
      therefore can't emit a byte until we've seen the 4 behind it

       tail_data and tail_count are that 4B line

      thus concat [tail; body] forms a 12B word

      uses combined_count to count how many are in combined, similar to body_count
    *)
    let combined =
      (* 12 indexed packed vector *)
      Array.init 12 ~f:(fun position ->
        combined_byte
          ~tail_data:tail_data.value
          ~tail_count:tail_count.value
          ~body_data
          position)
    in

    (* vector compose the list of lane candidates to be written *)
    (* grabs the bottom 8B out of the combined vector *)
    let write_data =
      concat_lsb (List.init 8 ~f:(fun lane ->
          combined.(lane)) (* grab the lane candidate, use it to form the 64b vector *)
        )
    in

    (* generate a pop_count of the write candidate *)
    let write_keep = Mac_10g_axis.keep_of_byte_count write_count in

    let next_tail_count =
      mux2
        (* is the combined_count greater than 4? *)
        (combined_count >=:. 4)

        (* yes - set out 4 *)
        (of_int_trunc ~width:3 4)

        (* no - stream the calculated count *)
        (uresize combined_count ~width:3)
    in

    (* whole next tail vector; truly beautiful OCaml *)
    let next_tail_data =
      concat_lsb
        (List.init 4 ~f:(fun lane -> (* smash the vector into ... *)
           mux
             (* select on ? *)
             combined_count (* 4b *)

            (* given lane *)
             (List.init 16 ~f:(fun count -> (* form 16 bytes as a candidate mask *)
                if count = 0 || count > 12 || lane >= Int.min 4 count
                then zero 8
                else (
                  let start = Int.max 0 (count - 4) in
                  combined.(start + lane))
                )
             )
           )
        )
    in

    (* diagnostic wires *)
    let final_fcs_error = ~:(Mac_10g_crc32.has_valid_residue crc_after_body) in
    let final_length_error =
      wire_length_after_body
      <:. 64
      |: (wire_length_after_body >: uresize i.max_frame_length_i ~width:17)
    in
    let final_xgmii_error = xgmii_error.value |: ~:normal_terminate in
    let final_error =
      concat_lsb [ final_fcs_error; final_length_error; final_xgmii_error ]
    in

    (* was the final thing bad specifically? *)
    let final_bad = final_error <>:. 0 in
    let has_axis_payload = wire_length_after_body >:. 4 in
    let over_length = wire_length_after_body >: uresize i.max_frame_length_i ~width:17 in

    (* for downstream prop; depends on error *)
    let buffer_write_valid =
      processing_body
      &: (write_count <>:. 0)
      &: ~:over_length
      &: ~:(unexpected_control &: ~:terminate_present)
    in

    (* used for error prop and commit/discard entry *)
    let write_failed = buffer_write_valid &: ~:(i.buffer_write_ready_i) in

    (* commit/discard paradigm signals *)
    let finish = processing_body &: terminate_present in
    let commit_request = finish &: has_axis_payload &: ~:write_failed &: ~:over_length in
    let commit = i.enable_i &: (commit_request |: is_commit) in

    let commit_error =
      mux2
        (* are we commiting? *)
        is_commit
        pending_error.value (* is the error pending? *)
        final_error (* else final set error *)
    in

    let disabled_rollback =
      ~:(i.enable_i) &: (is_preamble_lane4 |: is_frame |: is_commit)
    in

    let rollback =
      processing_body
      &: (write_failed |: over_length |: (unexpected_control &: ~:terminate_present))
      |: (finish &: ~:has_axis_payload)
      |: (is_preamble_lane4 &: ~:lane4_finish_good)
      |: disabled_rollback
    in

    (* diagnostic fault decodes *)
    let local_fault =
      (* we caused *)
      word_equal ~data:i.xgmii_data_i ~control:i.xgmii_control_i Xgmii.local_fault_word
    in

    (* link caused *)
    let remote_fault =
      (* is the data word the remote_fault_word, and should we interpret it that way? *)
      word_equal ~data:i.xgmii_data_i ~control:i.xgmii_control_i Xgmii.remote_fault_word
    in

    let good_frame_pulse    = Always.Variable.wire ~default:gnd () in
    let bad_frame_pulse     = Always.Variable.wire ~default:gnd () in
    let overflow_pulse      = Always.Variable.wire ~default:gnd () in
    let completed_length    = Always.Variable.wire ~default:(zero 17) () in
    let fcs_error_pulse     = Always.Variable.wire ~default:gnd () in
    let length_error_pulse  = Always.Variable.wire ~default:gnd () in
    let xgmii_error_pulse   = Always.Variable.wire ~default:gnd () in

    Always.(
      compile
        [ if_
            ~:(i.enable_i)
            (* reset state in Idle *)
            [ state <--. state_idle
            ; crc <-- Mac_10g_crc32.initial
            ; wire_length <--. 0
            ; tail_data <--. 0
            ; tail_count <--. 0
            ; xgmii_error <--. 0
            ; missed_while_committing <--. 0
            ; discard_length_error <--. 0
            ; discard_xgmii_error <--. 0
            ]
            [ when_
                is_idle
                [ when_
                    start_lane0
                    [ if_
                      (* zero set as we start, transition to start *)
                        lane0_preamble_good
                        [ state <--. state_frame
                        ; crc <-- Mac_10g_crc32.initial
                        ; wire_length <--. 0
                        ; tail_data <--. 0
                        ; tail_count <--. 0
                        ; xgmii_error <--. 0
                        ]
                        [ state <--. state_discard
                        ; discard_xgmii_error <--. 1
                        ; bad_frame_pulse <-- vdd
                        ; xgmii_error_pulse <-- vdd
                        ]
                    ]
                ; when_
                  (* exclusively on lane4 - might need a formal prop for no double 0 and 4 start *)
                    (~:start_lane0 &: start_lane4)
                    [ if_
                        lane4_preamble_good
                        [ state <--. state_preamble_lane4
                        ; crc <-- Mac_10g_crc32.initial
                        ; wire_length <--. 0
                        ; tail_data <--. 0
                        ; tail_count <--. 0
                        ; xgmii_error <--. 0
                        ]
                        [ state <--. state_discard
                        ; discard_xgmii_error <--. 1
                        ; bad_frame_pulse <-- vdd
                        ; xgmii_error_pulse <-- vdd
                        ]
                    ]
                ]

            ; when_
                (is_preamble_lane4 &: ~:lane4_finish_good)
                [ state <--. state_discard
                ; discard_xgmii_error <--. 1
                ; bad_frame_pulse <-- vdd
                ; xgmii_error_pulse <-- vdd
                ]

            ; when_
                processing_body
                [ crc <-- crc_after_body
                ; wire_length <-- wire_length_after_body
                ; tail_data <-- next_tail_data
                ; tail_count <-- next_tail_count
                ; when_
                    (is_preamble_lane4 &: ~:terminate_present)
                    [ state <--. state_frame ]
                ; when_ (~:normal_terminate &: terminate_present) [ xgmii_error <--. 1 ]
                ; if_
                    write_failed
                    [ (* The failing word can also contain /T/.  There is then
                         nothing left to discard, so recover immediately. *)
                      state
                      <-- mux2
                            finish
                            (of_int_trunc ~width:3 state_idle)
                            (of_int_trunc ~width:3 state_discard)
                    ; overflow_pulse <-- vdd
                    ]
                    [ if_
                        over_length
                        [ if_
                            finish
                            [ state <--. state_idle
                            ; bad_frame_pulse <-- vdd
                            ; length_error_pulse <-- vdd
                            ; discard_length_error <--. 0
                            ]
                            [ state <--. state_discard
                            ; discard_length_error <--. 1
                            ]
                        ]
                        [ if_
                            (unexpected_control &: ~:terminate_present)
                            [ if_
                                restart_at_start
                                [ state
                                  <-- mux2
                                        restart_lane4
                                        (of_int_trunc ~width:3 state_preamble_lane4)
                                        (of_int_trunc ~width:3 state_frame)
                                ; crc <-- Mac_10g_crc32.initial
                                ; wire_length <--. 0
                                ; tail_data <--. 0
                                ; tail_count <--. 0
                                ; xgmii_error <--. 0
                                ; discard_xgmii_error <--. 0
                                ]
                                [ state <--. state_discard
                                ; discard_xgmii_error <--. 1
                                ]
                            ; bad_frame_pulse <-- vdd
                            ; xgmii_error_pulse <-- vdd
                            ]
                            [ when_
                                finish
                                [ completed_length <-- wire_length_after_body
                                ; fcs_error_pulse <-- final_fcs_error
                                ; length_error_pulse <-- final_length_error
                                ; xgmii_error_pulse <-- final_xgmii_error
                                ; if_
                                    final_bad
                                    [ bad_frame_pulse <-- vdd ]
                                    [ good_frame_pulse <-- vdd ]
                                ; if_
                                    has_axis_payload
                                    [ if_
                                        i.buffer_commit_ready_i
                                        [ state <--. state_idle ]
                                        [ state <--. state_commit
                                        ; pending_error <-- final_error
                                        ; missed_while_committing <--. 0
                                        ]
                                    ]
                                    [ state <--. state_idle ]
                                ]
                            ]
                        ]
                    ]
                ]

            ; when_
                is_commit
                [ when_
                    any_start
                    [ when_
                        ~:(missed_while_committing.value)
                        [ overflow_pulse <-- vdd; missed_while_committing <--. 1 ]
                    ]
                ; (* Once the unbuffered frame terminates there is no residual wire
                     traffic to discard.  Remembering only that a start was missed
                     would otherwise strand RX in discard after the pending descriptor
                     finally commits. *)
                  when_
                    (missed_while_committing.value &: terminate_present)
                    [ missed_while_committing <--. 0 ]
                ; when_
                    i.buffer_commit_ready_i
                    [ if_
                        (missed_while_committing.value &: ~:terminate_present)
                        [ state <--. state_discard ]
                        [ state <--. state_idle ]
                    ; missed_while_committing <--. 0
                    ]
                ]

            ; when_
                is_discard
                (* discard state assignments; *)
                [ when_
                    terminate_present (* we're done! *)
                    [ state <--. state_idle
                    ; when_
                        discard_length_error.value
                        [ bad_frame_pulse <-- vdd
                        ; length_error_pulse <-- vdd
                        ]
                    ; when_
                        discard_xgmii_error.value
                        [ (* malformed preambles were counted at detection *)
                          discard_xgmii_error <--. 0
                        ]
                    ; discard_length_error <--. 0
                    ]

                ; when_
                    start_lane0
                    [ if_
                        lane0_preamble_good
                        [ state <--. state_frame
                        ; crc <-- Mac_10g_crc32.initial
                        ; wire_length <--. 0
                        ; tail_data <--. 0
                        ; tail_count <--. 0
                        ; xgmii_error <--. 0
                        ; discard_length_error <--. 0
                        ; discard_xgmii_error <--. 0
                        ]
                        [ discard_xgmii_error <--. 1 ]
                    ]
                ; when_
                    (~:start_lane0 &: start_lane4 &: lane4_preamble_good)
                    [ state <--. state_preamble_lane4
                    ; crc <-- Mac_10g_crc32.initial
                    ; wire_length <--. 0
                    ; tail_data <--. 0
                    ; tail_count <--. 0
                    ; xgmii_error <--. 0
                    ; discard_length_error <--. 0
                    ; discard_xgmii_error <--. 0
                    ]
                ]
            ]

        ; if_
            i.counters_clear_i
            [ good_frames <--. 0
            ; bad_frames <--. 0
            ; bytes <--. 0
            ; fcs_errors <--. 0
            ; length_errors <--. 0
            ; xgmii_errors <--. 0
            ; overflow_drops <--. 0
            ]
            [ when_ good_frame_pulse.value
                [ good_frames <-- good_frames.value +:. 1 ]

            ; when_ bad_frame_pulse.value
                [ bad_frames <-- bad_frames.value +:. 1 ]

            ; when_
                (completed_length.value <>:. 0)
                [ bytes <-- bytes.value +: uresize completed_length.value ~width:64 ]

            ; when_ fcs_error_pulse.value [ fcs_errors <-- fcs_errors.value +:. 1 ]

            ; when_
                length_error_pulse.value
                [ length_errors <-- length_errors.value +:. 1 ]
            ; when_ xgmii_error_pulse.value [ xgmii_errors <-- xgmii_errors.value +:. 1 ]
            ; when_ overflow_pulse.value [ overflow_drops <-- overflow_drops.value +:. 1 ]
            ]
        ]);

    { O.buffer_write_data_o     = write_data
    ; buffer_write_keep_o       = write_keep
    ; buffer_write_valid_o      = buffer_write_valid
    ; buffer_commit_o           = commit
    ; buffer_rollback_o         = rollback
    ; buffer_commit_error_o     = commit_error
    ; state_o                   = state.value
    ; good_frame_pulse_o        = good_frame_pulse.value
    ; bad_frame_pulse_o = bad_frame_pulse.value
    ; overflow_pulse_o = overflow_pulse.value
    ; local_fault_o = local_fault
    ; remote_fault_o = remote_fault
    ; good_frames_o = good_frames.value
    ; bad_frames_o = bad_frames.value
    ; bytes_o = bytes.value
    ; fcs_errors_o = fcs_errors.value
    ; length_errors_o = length_errors.value
    ; xgmii_errors_o = xgmii_errors.value
    ; overflow_drops_o = overflow_drops.value
    }

  [@@@ocamlformat "enable"]

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical
      ?instance
      ~scope
      ~name:(sprintf "mac_10g_rx_%d" Config.max_supported_frame_length)
      create
      i
  ;;
end
