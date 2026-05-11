open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

let () =
  Stdio.print_endline "=== Imported MAC RX CRC Module ==="

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;
    en  : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    crc_valid : 'a;
  } [@@deriving hardcaml]
end

let const_crc_reflect = Signal.of_int_trunc ~width:32 0xEDB88320;;

(* define crc for a single bit *)
let crc_bit (current_crc) : Signal.t = 
  (* how in the world does this accessor work? *)
  let least_sig_bit = current_crc.:[0,0] in

  (* always shift*)
  let shifted = srl current_crc ~by:1 in

  (* possible xor fold *)
  let folded = (shifted ^: const_crc_reflect) in

  (* decision node: use xor-folded shift or not *)
  mux2 least_sig_bit (folded) (shifted)
;;

(* define crc for an arbitrary number of bits *)
(* let crc_n_bits (current_crc) = *)


let create 
  (scope : Scope.t)
  (i) : _ O.t
  =
  (* scope shenanigans *)
  let _scope : Scope.t = Scope.sub_scope scope "rx_crc_scope" in

  (* port aliases *)
  let clk = i.I.clk in
  let rst = i.I.rst in
  let en  = i.I.en in






  {
    crc_valid = Signal.zero 1;
  }


