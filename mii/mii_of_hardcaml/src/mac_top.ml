open Core
open Hardcaml
open Signal

let () =
  Stdio.print_endline "=== Imported MAC RX Top ==="

let nothing_burger () =
  (* Stdio.print_endline "imported mac top seriously tho" *)
  ()

module I = struct
  type 'a t = {
    (* ethernet phy lines *)
    rx_clk  : 'a; (* rx_clk *)
    reset   : 'a; (* rx rst *)
    rx_dv   : 'a; (* activity line *)
    rx_er   : 'a; (* phy error line *)
    rx_data : 'a [@bits 4];
    rx_master_enable : 'a;

    (* axis exposed out signals *)
    (* Logic -> PHY *)
    s_axis_tdata  : 'a [@bits 8]; (* 1 byte *)
    s_axis_tkeep  : 'a;
    s_axis_tlast  : 'a;
    s_axis_tvalid : 'a;
    s_axis_tuser  : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* axis exposed out signals *)
    (* PHY -> Logic *)
    m_axis_tdata  : 'a [@bits 8]; (* 1 byte *)
    m_axis_tkeep  : 'a;
    m_axis_tlast  : 'a;
    m_axis_tvalid : 'a;
    m_axis_tuser  : 'a;
  } [@@deriving hardcaml]
end

module States = struct
  type t =
    | IDLE
    | PREAMBLE
    | DST_MAC
    | SRC_MAC
    | ETH_TYPE
    | PAYLOAD
    | DONE 
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create 
  inputs : (_ O.t)
  = 
  (*
    Spec: specific rising_edge spec
  *)
  let rising_edge : Reg_spec.t = 
    (* Reg_spec.create ~clock:inputs.I.clk ~reset:inputs.I.rst ()  *)
    Reg_spec.create ~clock:inputs.I.rx_clk ~clear:inputs.I.reset () 
  in

  let datapath_inst : Signal.t Rx_datapath.O.t = 
    Rx_datapath.create {
      Rx_datapath.I.placeholder_in = zero 1;
    }
  in

  let controller_inst : Signal.t Rx_controller.O.t = 
    Rx_controller.create {
      Rx_controller.I.clk = inputs.I.rx_clk;
      rst = inputs.I.reset;
      en = inputs.I.rx_master_enable;
      rx_dv = inputs.I.rx_dv;
      rx_er = inputs.I.rx_er;
      rx_data = inputs.I.rx_data;
    }
  in

  {
    m_axis_tdata  = zero 8;
    m_axis_tuser  = Signal.gnd;
    m_axis_tvalid = Signal.gnd;
    m_axis_tlast  = Signal.gnd;
    m_axis_tkeep  = Signal.gnd;
  }


