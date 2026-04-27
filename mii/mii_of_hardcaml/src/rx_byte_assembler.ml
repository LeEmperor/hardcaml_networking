open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

let () =
  print_endline "=== Imported MAC RX Byte Assembler ==="

module I = struct
  type 'a t = {
    rx_data   : 'a [@bits 4];
    en        : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    byte_out    : 'a [@bits 8]; (* 1 byte *)
    byte_valid  : 'a;
  } [@@deriving hardcaml]
end

let create 
  (scope) (spec) (inputs) : (_ O.t) = 
    (* port aliases *)
    let rx_data = inputs.I.rx_data in
    let en      = inputs.I.en in

    let byte_valid = wire ~default:gnd () in
    let data_upper = reg ~enable:vdd ~width:4 spec in
    let data_lower = reg ~enable:vdd ~width:4 spec in
    let have_upper = reg ~enable:vdd ~width:1 spec in

    (* floating always block *)
      Always.(
        compile [
          if_ (inputs.en) [
            (* if en *)
            if_ (have_upper.value) [
              data_lower <-- rx_data;
              have_upper <--. 0;
              byte_valid <--. 1;
            ] [
              data_upper <-- rx_data;
              have_upper <--. 1;
            ]
          ] [];
        ];
      );

  {
    byte_out    = data_upper.value @: data_lower.value;
    byte_valid  = byte_valid.value;
  }

