(* Bohdan Purtell University of Florida

   Module: Uart_rx The receiving half of the 8-N-1 pair, and the mirror of [Uart_tx]: one
   space start bit, eight data bits least significant first, one mark stop bit. Like the
   transmitter it advances on [tick] rather than on the clock, so the baud rate lives in
   whatever generates [tick].

   The start bit is found by a falling edge on [uart_rx_d] rather than by oversampling, so
   this receiver has no majority vote and no mid-bit resynchronisation. START then waits
   for the next [tick] before sampling begins, which lines the sample points up with the
   generator's phase rather than with the transmitter's - the two agree only as long as
   the tick period matches the sender's bit period closely enough to stay inside a bit
   over the ten bits of a frame. That is the usual UART tolerance budget, and it is the
   reason [tick] wants to be a bit-rate tick and not a free-running divider that has
   drifted.

   Because the edge detector lives on the caller's [spec], the caller's clear zeroes its
   history; see the [Helper_circuits] header for what that does to an input that is
   already high out of clear. A line idling at mark is high, so the first edge after a
   clear is a genuine start bit rather than a spurious one.

   [d_out_valid] is a wire held high for the whole STOP state, not a single-cycle pulse,
   and [d_out] is the shift register read straight out - so the byte is stable for as long
   as STOP lasts and is overwritten by the next frame's payload. A consumer that cannot
   accept the byte during STOP has to register it. The stop bit itself is never checked: a
   framing error is not detected, and STOP falls back to IDLE on the next tick whatever
   the line is doing. *)

open! Core
open! Hardcaml
open! Signal
open! Always

module I = struct
  type 'a t =
    { clock : 'a
    ; reset : 'a
    ; en : 'a
    ; tick : 'a
    ; uart_rx_d : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { (* debug lines *)
      keep : 'a
    ; d_out : 'a [@bits 8]
    ; d_out_valid : 'a
    }
  [@@deriving hardcaml]
end

module States = struct
  type t =
    | IDLE (* line idles high; wait for start bit *)
    | START (* start bit detected; sync to baud tick *)
    | PAYLOAD (* shift in 8 data bits, LSB first *)
    | STOP (* stop bit window; d_out_valid held high *)
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(* internal regs block *)
module I_Regs = struct
  type 'a t =
    { data_place_counter : 'a [@bits 3]
    ; rx_byte : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

(* internal wires block *)
module I_Wires = struct
  type 'a t = { d_out_valid : 'a } [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : _ I.t) : _ O.t =
  (* port aliases *)
  let clock = i.I.clock in
  let reset = i.I.reset in
  let en = i.I.en in
  let rising_edge : Reg_spec.t = Reg_spec.create ~clock ~clear:reset () in
  (* state machine *)
  let sm = Always.State_machine.create (module States) ~enable:en rising_edge in
  (* tagging + register creation - the datapath registers are deliberately NOT gated by
     [en], only the state is, which is how this block was first written. A frame already
     in flight when [en] drops therefore keeps shifting into a state machine that has
     stopped advancing. *)
  let i_regs = I_Regs.Of_always.reg ~enable:vdd rising_edge in
  I_Regs.Of_always.apply_names ~prefix:"reg_" ~naming_op:(Scope.naming scope) i_regs;
  (* tagging + wire creation - valid is low unless a state raises it *)
  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;
  let data_place_counter = i_regs.data_place_counter in
  let rx_byte = i_regs.rx_byte in
  let d_out_valid = i_wires.d_out_valid in
  (* Falling edge on uart_rx_d signals the start bit. *)
  let start_bit = Helper_circuits.falling_edge_detector rising_edge i.I.uart_rx_d in
  Always.(
    compile
      [ (* default *)
        d_out_valid <--. 0
      ; sm.switch
          ~default:[]
          [ IDLE, [ when_ start_bit [ sm.set_next START ] ]
          ; ( START
            , [ (* Wait for the next baud tick so that subsequent ticks land at roughly
                   the same phase as the transmitter's bit boundaries. *)
                when_ i.I.tick [ data_place_counter <--. 0; sm.set_next PAYLOAD ]
              ] )
          ; ( PAYLOAD
            , [ when_
                  i.I.tick
                  [ (* Shift right: new bit enters at the MSB. After 8 ticks: rx_byte =
                       [{b7, b6, ..., b0}], b0 = first received = LSB. *)
                    rx_byte
                    <-- concat_msb [ i.I.uart_rx_d; drop_bottom rx_byte.value ~width:1 ]
                  ; if_
                      (data_place_counter.value ==: of_int_trunc ~width:3 7)
                      [ sm.set_next STOP ]
                      [ data_place_counter <-- data_place_counter.value +:. 1 ]
                  ]
              ] )
          ; STOP, [ d_out_valid <--. 1; when_ i.I.tick [ sm.set_next IDLE ] ]
          ]
      ]);
  (* Synthesis anti-pruning, in the shape the MII blocks use: OR-reduce the internals that
     nothing else drives out of the module, so they survive into the netlist and the VCD.
     The value means nothing - only that it depends on the shift register, the bit counter
     and the valid wire. *)
  let keep =
    reduce
      ~f:( |: )
      (bits_lsb rx_byte.value @ bits_lsb data_place_counter.value @ [ d_out_valid.value ])
  in
  { keep; d_out = rx_byte.value; d_out_valid = d_out_valid.value }
;;
