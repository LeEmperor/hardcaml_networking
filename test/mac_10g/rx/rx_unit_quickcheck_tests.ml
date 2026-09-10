(* University of Florida *)
(* Author: Bohdan Purtell *)
(* Module: "rx_unit_quickcheck_tests.ml" *)

open! Core
open! Hardcaml_verif
open! Rx_testbench

let payload length = List.init length ~f:(fun index -> ((index * 29) + 7) land 0xff)

let set_lane word ~lane ~byte ~is_control =
  { Xword.bytes =
      List.mapi word.Xword.bytes ~f:(fun index old -> if index = lane then byte else old)
  ; control =
      (if is_control
       then word.control lor (1 lsl lane)
       else word.control land lnot (1 lsl lane))
  }
;;

let fault_word fault_type =
  { Xword.bytes = [ 0x9c; 0; 0; fault_type; 0x9c; 0; 0; fault_type ]; control = 0x11 }
;;

let%test_unit "both start alignments and every terminate lane round-trip" =
  List.iter [ 0; 4 ] ~f:(fun start_lane ->
    List.iter (List.range 60 68) ~f:(fun length ->
      let frame = payload length in
      let result = Testbench.run (encode_frame ~start_lane frame) in
      [%test_result: int list] result.payload ~expect:frame;
      [%test_result: bool option] result.final_user ~expect:(Some false);
      [%test_result: int] result.good_frames ~expect:1;
      [%test_result: int] result.bad_frames ~expect:0;
      [%test_result: int] result.bytes ~expect:(length + 4)))
;;

let%test_unit "bad FCS is emitted with final tuser, or dropped by policy" =
  let frame = payload 73 in
  let emitted = Testbench.run (encode_frame ~bad_fcs:true frame) in
  [%test_result: int list] emitted.payload ~expect:frame;
  [%test_result: bool option] emitted.final_user ~expect:(Some true);
  [%test_result: int] emitted.bad_frames ~expect:1;
  [%test_result: int] emitted.fcs_errors ~expect:1;
  let dropped = Testbench.run ~drop_bad:true (encode_frame ~bad_fcs:true frame) in
  [%test_result: int list] dropped.payload ~expect:[];
  [%test_result: bool option] dropped.final_user ~expect:None;
  [%test_result: int] dropped.bad_frames ~expect:1
;;

let%test_unit "a policy change cannot retract a bad frame already stalled on AXI" =
  let frame = payload 73 in
  let words = encode_frame ~bad_fcs:true frame in
  let input_cycles = List.length words in
  let result =
    Testbench.run
      ~drop_bad_at:(fun cycle -> cycle >= input_cycles + 2)
      ~ready:(fun cycle -> cycle >= input_cycles + 10)
      words
  in
  [%test_result: int list] result.payload ~expect:frame;
  [%test_result: bool option] result.final_user ~expect:(Some true);
  [%test_result: bool] result.stable_while_stalled ~expect:true
;;

let%test_unit "disabling RX cannot truncate a frame already stalled on AXI" =
  let frame = payload 73 in
  let words = encode_frame frame in
  let input_cycles = List.length words in
  let result =
    Testbench.run
      ~enable:(fun cycle -> cycle < input_cycles + 1)
      ~ready:(fun cycle -> cycle >= input_cycles + 10)
      words
  in
  [%test_result: int list] result.payload ~expect:frame;
  [%test_result: bool option] result.final_user ~expect:(Some false);
  [%test_result: bool] result.stable_while_stalled ~expect:true
;;

let%test_unit "AXI output is stable under arbitrary stalls" =
  let frame = payload 127 in
  let result =
    Testbench.run
      ~ready:(fun cycle -> cycle mod 5 <> 1 && cycle mod 7 <> 3)
      (encode_frame ~start_lane:4 frame)
  in
  [%test_result: int list] result.payload ~expect:frame;
  [%test_result: bool] result.stable_while_stalled ~expect:true
;;

let%test_unit "generated legal frames match the byte-oriented model under stalls" =
  let generator =
    let open Quickcheck.Generator.Let_syntax in
    let%bind frame = Generators.byte_list ~min_length:60 ~max_length:251 () in
    let%map start_lane = Int.gen_incl 0 1 in
    frame, if start_lane = 0 then 0 else 4
  in
  Quickcheck.test
    ~trials:80
    ~seed:(`Deterministic "mac-10g-functional-rx")
    ~sexp_of:[%sexp_of: int list * int]
    generator
    ~f:(fun (frame, start_lane) ->
      let result =
        Testbench.run
          ~ready:(fun cycle -> cycle mod 3 <> 1 && cycle mod 11 <> 7)
          (encode_frame ~start_lane frame)
      in
      [%test_result: int list] result.payload ~expect:frame;
      [%test_result: bool option] result.final_user ~expect:(Some false);
      [%test_result: int] result.good_frames ~expect:1;
      [%test_result: int] result.bytes ~expect:(List.length frame + 4);
      [%test_result: bool] result.stable_while_stalled ~expect:true)
;;

let%test_unit "runt frames are observable with a length error" =
  let frame = payload 14 in
  let result = Testbench.run (encode_frame frame) in
  [%test_result: int list] result.payload ~expect:frame;
  [%test_result: bool option] result.final_user ~expect:(Some true);
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.length_errors ~expect:1
;;

let%test_unit "oversize frames roll back instead of emitting a truncation" =
  let result = Testbench.run (encode_frame (payload 252)) in
  [%test_result: int list] result.payload ~expect:[];
  [%test_result: bool option] result.final_user ~expect:None;
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.length_errors ~expect:1
;;

let%test_unit "lane-4 oversize detected in the terminate word recovers immediately" =
  let result = Testbench.run (encode_frame ~start_lane:4 (payload 252)) in
  [%test_result: int list] result.payload ~expect:[];
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.length_errors ~expect:1;
  [%test_result: int] result.final_state ~expect:0
;;

let%test_unit "strict preamble rejects a malformed lane-0 start" =
  let words = encode_frame (payload 60) in
  let words =
    List.mapi words ~f:(fun index word ->
      if index = 0
      then
        { word with
          Xword.bytes =
            List.mapi word.bytes ~f:(fun lane byte -> if lane = 1 then 0x54 else byte)
        }
      else word)
  in
  let result = Testbench.run words in
  [%test_result: int list] result.payload ~expect:[];
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.xgmii_errors ~expect:1
;;

let%test_unit "strict preamble rejects a malformed lane-4 continuation" =
  let words =
    encode_frame ~start_lane:4 (payload 60)
    |> List.mapi ~f:(fun index word ->
      if index = 1 then set_lane word ~lane:2 ~byte:0x54 ~is_control:false else word)
  in
  let result = Testbench.run words in
  [%test_result: int list] result.payload ~expect:[];
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.xgmii_errors ~expect:1;
  [%test_result: int] result.final_state ~expect:0
;;

let%test_unit "unexpected /E/ rolls back and recovers at terminate" =
  let words = encode_frame (payload 60) in
  let words =
    List.mapi words ~f:(fun index word ->
      if index = 3
      then
        { Xword.bytes =
            List.mapi word.bytes ~f:(fun lane byte -> if lane = 2 then 0xfe else byte)
        ; control = word.control lor (1 lsl 2)
        }
      else word)
  in
  let result = Testbench.run words in
  [%test_result: int list] result.payload ~expect:[];
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.xgmii_errors ~expect:1
;;

let%test_unit "generated control errors roll back and recover on the next frame" =
  let generator =
    let open Quickcheck.Generator.Let_syntax in
    let%bind damaged = Generators.byte_list ~min_length:60 ~max_length:180 () in
    let%bind recovery = Generators.byte_list ~min_length:60 ~max_length:180 () in
    let%bind damaged_alignment = Int.gen_incl 0 1 in
    let%bind recovery_alignment = Int.gen_incl 0 1 in
    let%map injection = Int.gen_incl 0 0xffff in
    damaged, recovery, damaged_alignment, recovery_alignment, injection
  in
  Quickcheck.test
    ~trials:60
    ~seed:(`Deterministic "mac-10g-rx-error-recovery")
    ~sexp_of:[%sexp_of: int list * int list * int * int * int]
    generator
    ~f:(fun (damaged, recovery, damaged_alignment, recovery_alignment, injection) ->
      let damaged_start = if damaged_alignment = 0 then 0 else 4 in
      let recovery_start = if recovery_alignment = 0 then 0 else 4 in
      let byte_index = injection mod List.length damaged in
      let event_index = (if damaged_start = 0 then 8 else 12) + byte_index in
      let word_index = event_index / 8 in
      let lane = event_index mod 8 in
      let damaged_words =
        encode_frame ~start_lane:damaged_start damaged
        |> List.mapi ~f:(fun index word ->
          if index = word_index
          then set_lane word ~lane ~byte:0xfe ~is_control:true
          else word)
      in
      let result =
        Testbench.run (damaged_words @ encode_frame ~start_lane:recovery_start recovery)
      in
      [%test_result: int list] result.payload ~expect:recovery;
      [%test_result: bool option] result.final_user ~expect:(Some false);
      [%test_result: int] result.good_frames ~expect:1;
      [%test_result: int] result.bad_frames ~expect:1;
      [%test_result: int] result.xgmii_errors ~expect:1;
      [%test_result: int] result.final_state ~expect:0)
;;

let%test_unit "a legal start resynchronizes a frame whose terminate was lost" =
  let incomplete = List.take (encode_frame (payload 100)) 3 in
  let good = payload 67 in
  let result = Testbench.run (incomplete @ encode_frame ~start_lane:4 good) in
  [%test_result: int list] result.payload ~expect:good;
  [%test_result: bool option] result.final_user ~expect:(Some false);
  [%test_result: int] result.good_frames ~expect:1;
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.xgmii_errors ~expect:1;
  [%test_result: int] result.final_state ~expect:0
;;

let%test_unit "malformed lanes after terminate are emitted with an XGMII verdict" =
  let frame = payload 62 in
  let changed = ref false in
  let words =
    encode_frame frame
    |> List.map ~f:(fun word ->
      if !changed
      then word
      else (
        match
          List.findi word.Xword.bytes ~f:(fun lane byte ->
            word.control land (1 lsl lane) <> 0 && byte = 0xfd)
        with
        | None -> word
        | Some (lane, _) ->
          changed := true;
          assert (lane < 7);
          set_lane word ~lane:(lane + 1) ~byte:0xfe ~is_control:true))
  in
  let result = Testbench.run words in
  [%test_result: int list] result.payload ~expect:frame;
  [%test_result: bool option] result.final_user ~expect:(Some true);
  [%test_result: int] result.bad_frames ~expect:1;
  [%test_result: int] result.xgmii_errors ~expect:1
;;

let%test_unit "disabling RX mid-frame rolls speculative bytes back" =
  let interrupted = encode_frame (payload 100) in
  let good = payload 64 in
  let words = interrupted @ encode_frame good in
  let result =
    Testbench.run
      ~enable:(fun cycle -> cycle < 3 || cycle >= List.length interrupted)
      words
  in
  [%test_result: int list] result.payload ~expect:good;
  [%test_result: int] result.good_frames ~expect:1;
  [%test_result: int] result.bad_frames ~expect:0;
  [%test_result: int] result.final_state ~expect:0
;;

let%test_unit "buffer pressure drops only the uncommitted frame" =
  let one = encode_frame (payload 60) in
  let words = List.concat (List.init 5 ~f:(Fn.const one)) in
  let result = Testbench.run ~ready:(Fn.const false) words in
  [%test_result: int list] result.payload ~expect:[];
  [%test_result: int] result.good_frames ~expect:4;
  [%test_result: int] result.overflow_drops ~expect:1
;;

let%test_unit "overflow on the terminate word does not strand discard state" =
  let resident = List.concat (List.init 3 ~f:(fun _ -> encode_frame (payload 60))) in
  let terminal_overflow = encode_frame ~start_lane:4 (payload 77) in
  let result = Testbench.run ~ready:(Fn.const false) (resident @ terminal_overflow) in
  [%test_result: int] result.good_frames ~expect:3;
  [%test_result: int] result.overflow_drops ~expect:1;
  [%test_result: int] result.final_state ~expect:0
;;

let%test_unit "descriptor pressure recovers after the missed frame terminates" =
  let runt = payload 14 in
  let accepted = List.concat (List.init 5 ~f:(fun _ -> encode_frame runt)) in
  let missed = encode_frame (payload 15) in
  let words = accepted @ missed in
  let result = Testbench.run ~ready:(fun cycle -> cycle >= List.length words) words in
  [%test_result: int list]
    result.payload
    ~expect:(List.concat (List.init 5 ~f:(Fn.const runt)));
  [%test_result: int] result.bad_frames ~expect:5;
  [%test_result: int] result.length_errors ~expect:5;
  [%test_result: int] result.overflow_drops ~expect:1;
  [%test_result: int] result.final_state ~expect:0
;;

let%test_unit "fault ordered sets are status and not frames" =
  let result = Testbench.run [ fault_word 1; fault_word 2 ] in
  [%test_result: bool] result.saw_local_fault ~expect:true;
  [%test_result: bool] result.saw_remote_fault ~expect:true;
  [%test_result: int] result.good_frames ~expect:0;
  [%test_result: int] result.bad_frames ~expect:0;
  [%test_result: int list] result.payload ~expect:[]
;;

let%test_unit "RX counter clear resets every owning-domain statistic" =
  let words = encode_frame ~bad_fcs:true (payload 60) in
  let result =
    Testbench.run ~counters_clear:(fun cycle -> cycle >= List.length words) words
  in
  [%test_result: int] result.good_frames ~expect:0;
  [%test_result: int] result.bad_frames ~expect:0;
  [%test_result: int] result.bytes ~expect:0;
  [%test_result: int] result.fcs_errors ~expect:0;
  [%test_result: int] result.length_errors ~expect:0;
  [%test_result: int] result.xgmii_errors ~expect:0;
  [%test_result: int] result.overflow_drops ~expect:0
;;
