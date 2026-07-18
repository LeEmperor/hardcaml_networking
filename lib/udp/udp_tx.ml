(*
  Bohdan Purtell
  University of Florida

  Module: Udp_tx

  UDP/IPv4 transmit header generator. Sits *above* the MII MAC: it emits the
  Ethernet-payload byte stream (IPv4 header ++ UDP header ++ application data)
  into the MAC's [s_axis] input. The MAC itself still wraps that with the
  Ethernet header + FCS.

  Design decisions (see the discussion that produced this file):

  - ONE monotonic byte counter over the fixed 28-byte header (20 B IPv4 + 8 B
    UDP), decoded by offset. The header is a 28-entry byte mux (a small ROM);
    field boundaries live in the mux, not in the FSM, so the FSM is just
    Idle -> Header -> Payload.

  - The payload boundary is data-dependent, so it does NOT share the header
    counter: a separate down-counter [payload_rem] is loaded from [payload_len]
    at [start] and counts to the last byte. (Alternatively gate on an upstream
    tlast — noted below.)

  - IPv4 header checksum is mandatory and lives *before* the addresses it
    covers, so it can't be produced streaming. It's computed combinationally
    from the (latched) length + constant fields. UDP checksum over IPv4 is
    optional -> emitted as 0x0000 for now.

  INTEGRATION CAVEAT: the current MAC tx_controller hardcodes a 46-byte payload
  (counts to 45 then jumps to Fcs). To carry a variable-length UDP datagram the
  MAC TX controller needs a length/tlast handshake instead of the fixed count.
  Until then, size datagrams so IP+UDP+data == 46 bytes (data == 18 bytes), or
  wire [m_tlast] into the MAC controller. [tx_start] here maps to the MAC's
  existing [tx_start]/[start].
*)

open! Core
open! Hardcaml
open! Signal
open! Helper_circuits

let () = Stdio.print_endline "=== Imported UDP TX ==="

(* ── datagram constants (fixed endpoints for the first bring-up) ──
   Swap these for I ports once the fixed-address version is on the wire. *)
let src_ip   = [ 192; 168; 1; 10 ] (* 4 bytes, network order *)
let dst_ip   = [ 192; 168; 1; 1 ]
let src_port = 0x1234
let dst_port = 0x1235

let ip_hdr_len  = 20
let udp_hdr_len = 8
let hdr_len     = ip_hdr_len + udp_hdr_len (* 28 *)

module I = struct
  type 'a t = {
    clock : 'a;
    reset : 'a;
    en    : 'a;

    start         : 'a;               (* pulse: begin a datagram *)
    payload_len   : 'a [@bits 16];    (* application-data length, latched at [start] *)

    (* application-data stream in *)
    payload_tdata  : 'a [@bits 8];
    payload_tvalid : 'a;

    (* backpressure from downstream (MAC s_axis_tready) *)
    mac_tready : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* Ethernet-payload byte stream out -> MAC s_axis *)
    m_tdata  : 'a [@bits 8];
    m_tvalid : 'a;
    m_tlast  : 'a;                    (* asserted on final payload byte *)

    tx_start       : 'a;             (* -> MAC tx_controller.start *)
    payload_tready : 'a;             (* backpressure -> application source *)
    busy           : 'a;

    keep : 'a;
  } [@@deriving hardcaml]
end

module States = struct
  type t =
    | Idle
    | Header
    | Payload
  [@@deriving sexp_of, compare ~localize, enumerate]
end

module I_Regs = struct
  type 'a t = {
    hdr_counter : 'a [@bits 5];       (* 0..27 header byte index *)
    payload_rem : 'a [@bits 16];      (* payload bytes still to send *)
    len_latch   : 'a [@bits 16];      (* payload_len latched at start *)
    busy        : 'a;
  } [@@deriving hardcaml]
end

module I_Wires = struct
  type 'a t = {
    tvalid   : 'a;
    tlast    : 'a;
    tx_start : 'a;
    p_ready  : 'a;
  } [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : _ I.t) : _ O.t =
  let open Always in
  let open Variable in

  let rising_edge = Reg_spec.create ~clock:i.I.clock ~clear:i.I.reset () in
  let sm = State_machine.create (module States) ~enable:vdd rising_edge in

  let i_regs = I_Regs.Of_always.reg ~enable:vdd rising_edge in
  I_Regs.Of_always.apply_names ~prefix:"reg_" ~naming_op:(Scope.naming scope) i_regs;

  let i_wires = I_Wires.Of_always.wire Signal.zero in
  I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) i_wires;

  (* ── byte helpers ── *)
  let const8 v = of_int_trunc ~width:8 v in
  let hi16 w = select w ~high:15 ~low:8 in       (* MSB-first on the wire *)
  let lo16 w = select w ~high:7 ~low:0 in

  (* lengths derived from the latched payload length *)
  let payload_len = i_regs.len_latch.value in
  let total_length = payload_len +:. hdr_len       -- "ip_total_len" in  (* IP total = 28 + data *)
  let udp_length   = payload_len +:. udp_hdr_len    -- "udp_len"     in  (* UDP len  =  8 + data *)

  (* ── IPv4 header checksum: one's-complement 16-bit sum of the header words
     (checksum field taken as 0), end-around carry, then complemented. Purely
     combinational; only [total_length] is dynamic. ── *)
  let ip_hdr_words =
    [ of_hex ~width:16 "4500"        (* version/IHL=0x45, DSCP/ECN=0 *)
    ; total_length
    ; zero 16                        (* identification *)
    ; of_hex ~width:16 "4000"        (* flags: DF, frag offset=0 *)
    ; of_hex ~width:16 "4011"        (* TTL=64, protocol=17 (UDP) *)
    ; zero 16                        (* checksum placeholder *)
    ; of_hex ~width:16 (sprintf "%02x%02x" (List.nth_exn src_ip 0) (List.nth_exn src_ip 1))
    ; of_hex ~width:16 (sprintf "%02x%02x" (List.nth_exn src_ip 2) (List.nth_exn src_ip 3))
    ; of_hex ~width:16 (sprintf "%02x%02x" (List.nth_exn dst_ip 0) (List.nth_exn dst_ip 1))
    ; of_hex ~width:16 (sprintf "%02x%02x" (List.nth_exn dst_ip 2) (List.nth_exn dst_ip 3))
    ]
  in
  (* sum of 10 words fits comfortably in 20 bits *)
  let raw_sum =
    List.fold ip_hdr_words ~init:(zero 20) ~f:(fun a w -> a +: uresize w ~width:20)
  in
  (* collapse bits above 16 back into the low 16 (end-around carry); applying
     twice is sufficient for a 20-bit input *)
  let fold_carry s =
    let lo = uresize (select s ~high:15 ~low:0) ~width:17 in
    let hi = uresize (select s ~high:(width s - 1) ~low:16) ~width:17 in
    lo +: hi
  in
  let ip_checksum = ~:(select (fold_carry (fold_carry raw_sum)) ~high:15 ~low:0)
                    -- "ip_checksum" in

  (* ── the 28-byte header, in wire order → one byte mux indexed by hdr_counter ── *)
  let header_bytes =
    (* IPv4 (20) *)
    [ const8 0x45; const8 0x00; hi16 total_length; lo16 total_length
    ; const8 0x00; const8 0x00 (* identification *)
    ; const8 0x40; const8 0x00 (* flags/frag: DF *)
    ; const8 0x40; const8 0x11 (* TTL / protocol *)
    ; hi16 ip_checksum; lo16 ip_checksum
    ]
    @ List.map src_ip ~f:const8
    @ List.map dst_ip ~f:const8
    (* UDP (8) *)
    @ [ const8 (src_port lsr 8); const8 (src_port land 0xff)
      ; const8 (dst_port lsr 8); const8 (dst_port land 0xff)
      ; hi16 udp_length; lo16 udp_length
      ; const8 0x00; const8 0x00 (* UDP checksum = 0 (optional over IPv4) *)
      ]
  in
  assert (List.length header_bytes = hdr_len);
  let header_byte = mux i_regs.hdr_counter.value header_bytes -- "header_byte" in

  let start          = i.I.start in
  let mac_tready     = i.I.mac_tready in
  let payload_tvalid = i.I.payload_tvalid in

  compile
    [ (* defaults *)
      i_wires.tvalid   <--. 0
    ; i_wires.tlast    <--. 0
    ; i_wires.tx_start <--. 0
    ; i_wires.p_ready  <--. 0
    ; i_regs.busy      <-- i_regs.busy.value

    ; sm.switch ~default:[]
        [ ( Idle
          , [ when_ start
                [ i_regs.busy        <--. 1
                ; i_regs.hdr_counter <--. 0
                ; i_regs.len_latch   <-- i.I.payload_len
                ; i_regs.payload_rem <-- i.I.payload_len
                ; i_wires.tx_start   <--. 1   (* open a frame at the MAC *)
                ; sm.set_next Header
                ]
            ] )

        ; ( Header
          , [ i_wires.tvalid <--. 1                    (* header byte always valid *)
            ; when_ mac_tready                          (* advance only when accepted *)
                [ if_ (i_regs.hdr_counter.value ==:. hdr_len - 1)
                    [ i_regs.hdr_counter <--. 0
                    ; if_ (i_regs.payload_rem.value ==:. 0)   (* zero-length datagram *)
                        [ i_regs.busy <--. 0; sm.set_next Idle ]
                        [ sm.set_next Payload ]
                    ]
                    [ i_regs.hdr_counter <-- i_regs.hdr_counter.value +:. 1 ]
                ]
            ] )

        ; ( Payload
          , [ i_wires.p_ready <-- mac_tready            (* forward backpressure *)
            ; i_wires.tvalid  <-- payload_tvalid
            ; when_ (payload_tvalid &: mac_tready)
                [ if_ (i_regs.payload_rem.value ==:. 1)
                    [ i_wires.tlast    <--. 1           (* final payload byte *)
                    ; i_regs.payload_rem <--. 0
                    ; i_regs.busy      <--. 0
                    ; sm.set_next Idle
                    ]
                    [ i_regs.payload_rem <-- i_regs.payload_rem.value -:. 1 ]
                ]
            ] )
        ]
    ];

  let out_byte = mux2 (sm.is Payload) i.I.payload_tdata header_byte in

  let keep =
    reduce ~f:( |: ) (bits_lsb out_byte @ bits_lsb ip_checksum @ [ i_regs.busy.value ])
  in

  { O.m_tdata        = out_byte
  ; m_tvalid        = i_wires.tvalid.value
  ; m_tlast         = i_wires.tlast.value
  ; tx_start        = i_wires.tx_start.value
  ; payload_tready  = i_wires.p_ready.value
  ; busy            = i_regs.busy.value
  ; keep
  }
;;
