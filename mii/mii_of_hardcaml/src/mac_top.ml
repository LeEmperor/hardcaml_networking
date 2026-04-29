open! Core
open! Hardcaml
open! Signal

let () =
  Stdio.print_endline "=== Imported MAC RX Top ==="

module I = struct
  type 'a t = {
    (* spec *)
    clock     : 'a; (* rx_clk *)
    reset     : 'a; (* rx rst *)
    en        : 'a;

    (* ethernet phy lines *)
    rx_dv   : 'a; (* activity line *)
    rx_er   : 'a; (* phy error line *)
    rx_data : 'a [@bits 4];

    (* axis exposed out signals *)
    (* Logic -> PHY *)
    m_axis_tready : 'a;
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

    debug_datapath_d_out : 'a [@bits 8];
    debug_datapath_byte_assembler_d_out : 'a [@bits 8];

    debug_controller_en_loopback : 'a;
    debug_controller_current_state : 'a [@bits 3];

    (* debug_state_vec : 'a [@bits 3]; *)
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
    let open Always in
    let open Variable in

    (* port aliases *)
    let clk  = inputs.I.clock in
    let rst  = inputs.I.reset in
    let en   = inputs.I.en in
    let d_in = inputs.I.rx_data in
    let d_out = Signal.wire 8 in

  let rising_edge : Reg_spec.t = 
    (* Reg_spec.create ~clock:inputs.I.clk ~reset:inputs.I.rst ()  *)
    Reg_spec.create ~clock:clk ~clear:rst () 
  in

  (* internal ties *)
  (* let wire_byte_assembler_en = wire ~default:gnd in (* does this autosize? *) *)
  let wire_byte_assembler_en  = Signal.wire 1 in
  let wire_byte_out           = Signal.wire 8 in
  let wire_byte_out_valid     = Signal.wire 1 in
  let wire_payload_sel        = Signal.wire 1 in

  let datapath_inst : Signal.t Rx_datapath.O.t = 
    Rx_datapath.create {
      Rx_datapath.I.rx_data           = d_in;
      Rx_datapath.I.byte_assembler_en = wire_byte_assembler_en;
      Rx_datapath.I.clk = clk;
      Rx_datapath.I.rst = rst;
      Rx_datapath.I.en  = rst;
      Rx_datapath.I.payload_sel = wire_payload_sel;
    }
  in

  let controller_inst : Signal.t Rx_controller.O.t = 
    Rx_controller.create {
      Rx_controller.I.clk = clk;
      rst             = rst;
      en              = en;
      rx_dv           = inputs.I.rx_dv;
      rx_er           = inputs.I.rx_er;
      rx_data_valid   = wire_byte_out_valid;
      (* rx_data         = wire_byte_out; *)
      rx_data         = datapath_inst.payload_out;
    }
  in

  (* wire assigns *)
  Signal.(wire_byte_assembler_en <-- controller_inst.byte_assembler_en);
  Signal.(wire_byte_out          <-- datapath_inst.payload_out);
  Signal.(wire_byte_out_valid    <-- datapath_inst.payload_out_valid);
  Signal.(wire_payload_sel       <-- controller_inst.payload_sel);

  {
    m_axis_tdata  = datapath_inst.payload_out;
    m_axis_tuser  = Signal.gnd;
    m_axis_tvalid = Signal.gnd;
    m_axis_tlast  = Signal.gnd;
    m_axis_tkeep  = Signal.gnd;

    (* debug drawout *)
    debug_datapath_d_out = datapath_inst.payload_out;
    debug_datapath_byte_assembler_d_out = datapath_inst.debug_byte_assembler_d_out;
    debug_controller_en_loopback = controller_inst.debug_en;
    debug_controller_current_state = controller_inst.debug_state_vec; 
  }


