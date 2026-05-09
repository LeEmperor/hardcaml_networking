open! Core
open! Hardcaml
open! Signal
open! Always
open! Variable

let () =
  print_endline "=== Imported MAC RX Byte Assembler ==="

module I = struct
  type 'a t = {
    clk       : 'a;
    rst       : 'a;
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
  (inputs) : (_ O.t) = 
    (* port aliases *)
    let rx_data = inputs.I.rx_data in
    let en      = inputs.I.en in
    let clk     = inputs.I.clk in
    let rst     = inputs.I.rst in

    (* reg spec *)
    let spec : Reg_spec.t = Reg_spec.create ~clock:clk ~clear:rst () in

    (* internal wires *)
    let byte_valid = reg ~enable:vdd ~width:1 spec in
    let data_upper = reg ~enable:vdd ~width:4 spec in
    let data_lower = reg ~enable:vdd ~width:4 spec in
    let have_upper = reg ~enable:vdd ~width:1 spec in

    (* floating always block *)
      Always.(
        compile [
          byte_valid <--. 0;
          if_ (inputs.en) [
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
    byte_out    = data_lower.value @: data_upper.value;
    byte_valid  = byte_valid.value;
  }

