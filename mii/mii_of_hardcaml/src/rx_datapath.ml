open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC RX Datapath ==="

module I = struct
  type 'a t = {
    placeholder_in : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    placeholder_out : 'a;
  } [@@deriving hardcaml]
end

let create 
  (scope)
  (spec : Reg_spec.t)
  (inputs: Signal.t I.t)
  : 
  (Signal.t O.t)
  = 
  let byte_assembler_inst : Signal.t Rx_byte_assembler.O.t =
    Rx_byte_assembler.create scope spec {
      Rx_byte_assembler.I.rx_data = zero 4;
      Rx_byte_assembler.I.en = zero 1;
    }
  in

  {
    placeholder_out = zero 1;
  }

