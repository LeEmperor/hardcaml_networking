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


