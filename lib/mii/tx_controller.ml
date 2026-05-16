(* 
  Bohdan Purtell
  University of Florida

  Module: Tx_controller 
  This module serves as an FSM controller for the transmit path of my Hardcaml 
  ethernet MAC.
*)

(* 
   TODO:
this code looks awfully alot like SystemVerilog
is there a more Hardcaml way to do this stuff?
 *)

open! Core
open! Hardcaml
open! Signal
open! Helper_circuits

let () = 
  Stdio.print_endline "=== Imported MAC TX Controller ==="
;;

module I = struct
  type 'a t = {
    (* spec *)
    clk : 'a;
    rst : 'a;
    en  : 'a;

    (* control lines *)
    start : 'a;
    fifo_empty : 'a;

  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    byte_mux_sel : 'a [@bits 3];
    crc_en : 'a;
  } [@@deriving hardcaml]
end

(* enumerate over this for the mux that feeds the byte serializer *)
module Byte_sel_e = struct
  (* enum type *)
  type t = 
    | Preamble (* does this get encoded as 00, or does the compiler have an idea of the most common state -> reduce timing when comparing against 0s for something like PAYLOAD routing *)
    | Sfd
    | Dst_mac
    | Src_mac
    | Eth_type
    | Payload
    | Fcs
    [@@deriving sexp_of, compare ~localize, enumerate]

  let width = Int.ceil_log2 (List.length all)

  let to_signal t =
    List.findi_exn all ~f:(fun _ v -> compare v t = 0)
    |> fst
    |> Signal.of_int_trunc ~width
  ;;
end

(* why might i want this local to create instead of just global? *)
let sel =
  Byte_sel_e.to_signal
;;

module States = struct
  type t = 
    | Wait_frame
    | Preamble
    | Dst_mac
    | Src_mac
    | Eth_type
    | Payload
    | Fcs
    | DONE
  [@@deriving sexp_of, compare ~localize, enumerate]
end

module I_Regs = struct
  type 'a t = {
    byte_counter : 'a[@bits 11];
    busy : 'a;

    (* debug visibility items perhaps? *)
    (* is there a way to not have to drag from here and instead do some sort of "injection" scheme to grab signal values from a different inner-scope of the hierarchy? *)
    in_preamble : 'a;
    in_sfd      : 'a;
    in_payload  :'a;
    in_fcs      : 'a;
  } [@@deriving hardcaml]
end

module I_Wires = struct
  type 'a t = {
    byte_disassembler_en : 'a;
    byte_mux_sel : 'a [@bits 3];
    crc_en : 'a;
  } [@@deriving hardcaml]
end

let create
  (scope : Scope.t)
  (i) : (_ O.t)
  =
  let open Always in
  let open Variable in

  (* scope shenanigans *)
  let _scope : Scope.t = Scope.sub_scope scope "tx_controller_scope" in

  (* port aliases *)
  let clk = i.I.clk in (* instead of aliasing these could I include them in the i_wires construct so that they are present in the tagged wires of the module hierarchy? is there another better way to do something like this? *)
  let rst = i.I.rst in
  let en  = i.I.en in
  let start = i.I.start in
  let fifo_empty = i.I.fifo_empty -- "fifo_empty" in
  (* anyway to autotag these as well? *)

  let rising_edge : Reg_spec.t =
    Reg_spec.create ~clock:clk ~clear:rst ()
  in

  (* state machine *)
  let sm = State_machine.create (module States) ~enable:vdd rising_edge in

  (* const params *)
  let const_0xD5 = of_int_trunc ~width:8 0xD5 in
  let const_0x55 = of_int_trunc ~width:8 0x55 in

  (* tagging + register creation *)
  let i_regs = I_Regs.Of_always.reg ~enable:vdd rising_edge in
  I_Regs.Of_always.apply_names ~prefix:"reg_" ~naming_op:(Scope.naming scope) i_regs;

  (* TODO: is there a more repeatable way to do this creation + tagging in a single function call that is shorter perhaps? We know that things like apply_names and prefix and naming op will mostly all be the same every time? *)

  (* further extending this, is a dictionary-ish mapping even the right way to go about that? *)

  (* tagging + wire creation *)
  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;

  (* map the byte sel case into an int, where should this function be declared? *)
  let byte_source_sel = function
    | Byte_sel_e.Preamble   -> of_int_trunc ~width:8 0
    | Sfd                   -> of_int_trunc ~width:8 1
    | Src_mac               -> of_int_trunc ~width:8 2 
    | Dst_mac               -> of_int_trunc ~width:8 3
    | Eth_type              -> of_int_trunc ~width:8 4
    | Payload               -> of_int_trunc ~width:8 5 
    | Fcs                   -> Signal.of_int_trunc ~width:8 6 
  in

  (* byte sel formation *)
  let byte_mux_sel = 
    List.map Byte_sel_e.all ~f:(byte_source_sel)
  in

  (* I want a wire that is the byte_sel : Signal.t *)

  (* is there a way to make these functions generic to the module they operate on? *)
  (* isnt that just a functor? *)
  (* can the rst and increm counter functions be implemented for a generic register item by chance? *)

  let serializer_sel s =
    i_wires.byte_mux_sel <-- Byte_sel_e.to_signal s
  in

  let rst_counter = 
    i_regs.byte_counter <--. 0
  in

  let increm_counter = 
    i_regs.byte_counter <-- i_regs.byte_counter.value +:. 1
  in

  (* in the style that each state is simply a description of the counter value, and the serializer_sel value, is there an even more "functional" way to define just a few Lists that represent the map of these common factors that will make or emulate what this compile block is aiming to do in the first place? *)

  compile [
    (* defaults *)
    serializer_sel Preamble;
    i_wires.crc_en <--. 0;
    i_regs.busy <-- i_regs.busy.value; (* TODO: are regs automatically their prev values? *)

    (* sm *)
    sm.switch ~default:[] [
      States.Wait_frame, [
        when_ (start) [ (* TODO: what order should this be evaluated in? *)
          (* does it matter if I do && or just nested if_ check them? *)
          when_ (~:fifo_empty) [
            i_regs.busy <--. 1;
            rst_counter;
            sm.set_next Preamble;
          ];
        ];
      ];

      Preamble, [ (* 7 bytes + 1 for sfd *)
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 6) [
            rst_counter;
            serializer_sel Dst_mac; (* this is going to miss the sfd? *)
            sm.set_next Dst_mac;
          ] [
            increm_counter;
            serializer_sel Preamble;
          ];
        ];

      ];

      Dst_mac, [ (* 6 bytes *) 
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 5) [
            rst_counter;
            serializer_sel Src_mac;
            sm.set_next Src_mac;
          ] [
            increm_counter;
            serializer_sel Dst_mac;
          ];
        ];
      ];

      Src_mac, [ (* 6 bytes *)
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 5) [
            rst_counter;
            serializer_sel Eth_type;
            sm.set_next Eth_type;
          ] [
            increm_counter;

            i_wires.byte_mux_sel <-- sel Src_mac;
          ];
        ];
      ];

      Eth_type, [ (* 2 bytes *)
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 1) [
            rst_counter;
            serializer_sel Payload;
            sm.set_next Payload;
          ] [
            increm_counter;
            serializer_sel Eth_type;
          ];
        ];
      ];

      (* by now we've gone through 7 + 1 + 6 + 6 + 2 = 22 bytes of overhead *)
      (* minimum frame enforcement is 64 - 4 (fcs) = 60 bytes; 60 - 22 = 38 payload *)
      Payload, [
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 37) [
            rst_counter;
            i_wires.crc_en <--. 1;
            serializer_sel Fcs;
            sm.set_next Fcs;
          ] [
            serializer_sel Payload;
          ];
        ];
      ];

      Fcs, [
        (* at this point we don't care if the fifo is empty or not *)
        if_ (i_regs.byte_counter.value ==:. 3) [
          rst_counter;
          sm.set_next Wait_frame;
        ] [
          i_wires.crc_en <--. 1;
          i_regs.busy <--. 0;
          increm_counter;
          serializer_sel Fcs;
        ];
      ];
    ];
  ];

  {
    byte_mux_sel = i_wires.byte_mux_sel.value;
    crc_en = i_wires.crc_en.value;
  }

