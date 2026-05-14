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
    keep : 'a;
    byte_mux_sel : 'a [@bits 3];
  } [@@deriving hardcaml]
end

module States = struct
  type t = 
    | IDLE
    | WAIT_FRAME
    | PREAMBLE
    | DST_MAC
    | SRC_MAC
    | ETH_TYPE
    | PAYLOAD
    | DONE

    | STARTED
  [@@deriving sexp_of, compare ~localize, enumerate]
end

module I_Regs = struct
  type 'a t = {
    byte_counter : 'a[@bits 11];
    started : 'a;

    bruh : 'a;
  } [@@deriving hardcaml]
end

module I_Wires = struct
  type 'a t = {
    byte_disassembler_en : 'a;
    byte_mux_sel : 'a [@bits 3];
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
  let clk = i.I.clk in
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

  (* tagging + wire creation *)
  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;

  compile [
    (* defaults *)
    i_regs.bruh <-- i_regs.bruh.value;
    i_regs.started <-- i_regs.started.value;
    i_wires.byte_mux_sel <--. 0;

    (* sm *)
    sm.switch ~default:[] [
      WAIT_FRAME, [
        when_ (start) [
          when_ (~:fifo_empty) [
            sm.set_next PREAMBLE;

            i_regs.byte_counter <--. 0;
          ];
        ];
      ];

      PREAMBLE, [
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 7) [
            i_regs.byte_counter <--. 0;
            (* 
            biggest timing concern is the state reg (1-hot) and the counter needing reading to 
            decide on the mux select, though in theory one could 1-hot the counter register as well? 
            *)
            (* other big concern is the distance between the counter and the mux thats selecting which byte of dst/src MAC we're on, since the counter's 3 bottom bits are essentially just the select bits that are feeding those (2) muxes *)
            i_wires.byte_mux_sel <--. 1;
            i_regs.byte_counter <--. 0;
            sm.set_next DST_MAC;
            (* nice enough with Mealy assignments, we can cut down on an entire state *)
          ] [
            (* increm the counter *)
            i_regs.byte_counter <-- i_regs.byte_counter.value +:. 1;

            (* have datapath select the const *)
            i_wires.byte_mux_sel <--. 0;
          ];
        ];

      ];

      DST_MAC, [
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 5) [
            (* reset counter *)
            i_regs.byte_counter <--. 0;

            sm.set_next SRC_MAC;
          ] [
            (* increm counter + feed *)

          ];
        ];
      ];

      SRC_MAC, [
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 5) [
            (* reset counter *)
            i_regs.byte_counter <--. 0;
            sm.set_next ETH_TYPE;
          ] [

          ];
        ];
      ];

      ETH_TYPE, [
        when_ (~:fifo_empty) [
          if_ (i_regs.byte_counter.value ==:. 1) [
            (* reset counter *)
            i_regs.byte_counter <--. 0;
            sm.set_next PAYLOAD;
          ] [

          ];
        ];
      ];
    ];
  ];

  {
    keep = Signal.gnd;
    byte_mux_sel = i_wires.byte_mux_sel.value;
  }

