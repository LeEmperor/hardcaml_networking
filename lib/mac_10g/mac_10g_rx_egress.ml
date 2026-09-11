(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "mac_10g_rx_egress.ml" *)
(* Committed RX descriptor to AXI4-Stream adapter. *)

open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val error_width : int
end

module Make (Config : Config) = struct
  let () =
    if Config.error_width < 1
    then invalid_arg "Mac_10g_rx_egress: error_width must be positive"
  ;;

  module I = struct
    type 'a t =
      { clock_i : 'a
      ; reset_i : 'a
      ; enable_i : 'a
      ; drop_bad_i : 'a
      ; axis_ready_i : 'a
      ; buffer_data_i : 'a [@bits 64]
      ; buffer_keep_i : 'a [@bits 8]
      ; buffer_valid_i : 'a
      ; buffer_last_i : 'a
      ; buffer_error_i : 'a [@bits Config.error_width]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { axis_data_o : 'a [@bits 64]
      ; axis_keep_o : 'a [@bits 8]
      ; axis_valid_o : 'a
      ; axis_last_o : 'a
      ; axis_user_o : 'a
      ; buffer_ready_o : 'a
      ; dropped_bad_frame_pulse_o : 'a
      }
    [@@deriving hardcaml]
  end

  [@@@ocamlformat "disable"]

  let create (_scope : Scope.t) (i : _ I.t) : _ O.t =
    (* spec *)
    let spec = Reg_spec.create ~clock:i.clock_i ~clear:i.reset_i () in

    (* main statement managers - don't really need full states for this unless we become ambitious *)
    (* why must we make these Variable regs first vs Signal regs? *)
    let in_frame    = Always.Variable.reg ~enable:vdd ~width:1 spec in
    let drop_frame  = Always.Variable.reg ~enable:vdd ~width:1 spec in

    (* if the buffer error ever is 0, then we have a bad frame -> panic *)
    let bad = i.buffer_error_i <>:. 0 in

    (* are we allowed to start? *)
    let start_allowed =
      ~:(in_frame.value) &: (* are we NOT in a frame right now *)
      i.enable_i
    in

    (* reg for error state *)
    let start_dropping = start_allowed &: i.drop_bad_i &: bad in
    let dropping =
      i.buffer_valid_i &:
      mux2
        (* if we're in a frame already *)
        in_frame.value

        (* pass the drop frame register *)
        drop_frame.value

        (* else declare start_dropping *)
        start_dropping
    in

    (* opposite of dropping - possible to formally prove these are a thing? *)
    let presenting =
      i.buffer_valid_i
      &: mux2
        in_frame.value
        ~:(drop_frame.value)
        (start_allowed &: ~:start_dropping) (* probably via this *)
    in

    (* backpressure! *)
    let buffer_ready = dropping |:
                       (presenting &: i.axis_ready_i)
    in

    (* this is the indicateur of the descriptoin sidebands coming from the rx line *)
    let first_descriptor_beat = start_allowed &:
                                i.buffer_valid_i in

    (* bsaic compose of the beat being finished *)
    let completed_beat = i.buffer_valid_i &: buffer_ready &: i.buffer_last_i in

    Always.(
      compile
        [ when_
            first_descriptor_beat
            [ drop_frame <-- start_dropping
            ; in_frame <-- (~:completed_beat)
            ]

      (* when we're in the frmae itself, and we've completed, reset the state *)
        ; when_ (in_frame.value &: completed_beat)
            [ in_frame <--. 0 ]
        ]);

    { O.axis_data_o = i.buffer_data_i
    ; axis_keep_o = mux2 presenting i.buffer_keep_i (zero 8)
    ; axis_valid_o = presenting
    ; axis_last_o = presenting &: i.buffer_last_i
    ; axis_user_o = presenting &: i.buffer_last_i &: bad
    ; buffer_ready_o = buffer_ready
    ; dropped_bad_frame_pulse_o = dropping &: i.buffer_last_i
    }

  [@@@ocamlformat "enable"]

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"mac_10g_rx_egress" create i
  ;;
end
