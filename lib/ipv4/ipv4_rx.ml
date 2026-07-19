(*

  Jane Street
  Author: Bohdan Purtell
  
  Module: "ipv4_rx.ml"

  Naive module structuring for the rx side of an ipv4 layer-3 OSI model item for Hardcaml networking stack on hardware.


  TODO: resolve, answer, or remove
  Design Notes:

    ipv4 
      20B base
      byte 0: version/ihl
      byte 1: TOS
      byte 2-3: total len

  ipv4 rx looks alot different than udp tx lmao im being a dumbass


  strange yoda stuff
*)

open! Core
open! Hardcaml
open! Signal
open! Helper_circuits
open! Always
open! Variable

let () =
  Stdio.print_endline "=== Imported IPv4 RX Logic ===";
;;

(* constants du monde *)
let ip_hdr_len = 20

(* struct ou sig? *)
module type Config = sig
  val version : int 

  (* 'egalement ce voudrait en ciel d'un enumerable custom type pour le versoning que les implenmentations de ipv4 on peut avoir; ARP peut-etre un truc necessaire pour faire avilable *)

  val debug : bool (* si ou non pour le debug -> pour l'utilisation de keep folding *)
end

module Make (C : Config) = struct

  module I = struct
    (* define a record type t *)
    type 'a t = {
      bruh_i : 'a;

      clock_i : 'a;
      reset_i : 'a;
      start_i : 'a;

    } [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = {
      tvalid : 'a
      ; tlast : 'a
      ; tstart : 'a


      ; busy : 'a;
      (* axi pass-off for downstream consumption by layer 4 (UDP/TCP) *)
    } [@@deriving hardcaml]
  end

  module States = struct
    type t = 
      | Idle_s
      | Header_s
      | Payload_s
  [@@deriving sexp_of, compare ~localize, enumerate]
  end

  module I_Regs = struct
    type 'a t = {
      hdr_counter : 'a [@bits 5];       (* 0..19 header byte index *)
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

  let create
    (scope : Scope.t)
    (i : _ I.t)
    : _ O.t
    =

    (* local aliases *)
    let clock = i.I.clock_i in
    let reset = i.I.reset_i in
    let rising_edge = Reg_spec.create ~clock ~reset () in

    let start = i.I.start_i in

    (* house keeping *)
    let sm = State_machine.create (module States) ~enable:vdd rising_edge in
    let r = I_Regs.Of_always.reg ~enable:vdd rising_edge in
    I_Regs.Of_always.apply_names ~prefix:"reg_" ~naming_op:(Scope.naming scope) r;
    let w = I_Wires.Of_always.wire Signal.zero in
    I_Wires.Of_always.apply_names ~prefix:"wire_" ~naming_op:(Scope.naming scope) w;

    (* composed aliases *)

    (* helper functions *)


    (* logic *)
    compile 
      [
        (* defaults - wires only *)
        w.tvalid <--. 0
        ; w.tx_start <--. 0
        ; r.busy <-- r.busy.value (* pourquoi tu est ici? *)

        ; sm.switch ~default:[]
        [
          ( Idle_s
          , [
            when_ start
              [
                r.busy <--. 1
                ; r.hdr_counter <--. 0
                ;  
              ];
          ];
          )

          ; ( Header_s
            , [
              w.tvalid <--. 1
            ]
          )

          ; (Payload_s
            , [

            ]
          )
          ;
        ];


      ];

    (* keep folding for debug preservability *)
    if (true) then (* est-ce que cette faire un probleme avec le record definer pour O? *)

    (* let keep = *)
    (*     reduce ~f:( |: ) (bits_lsb start @ bits_lsb start) in *)
    (* ;; *)
    (**)
    Stdio.print_endline "nada";

    { O.
      tstart    = gnd
      ; tlast   = gnd
      ; tvalid  = gnd
      ; busy = r.busy.value
    }
  ;;


end
;;
