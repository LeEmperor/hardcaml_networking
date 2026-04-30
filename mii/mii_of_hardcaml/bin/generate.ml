open! Core
open! Hardcaml
open! Mii_of_hardcaml

let () =
  (* Mac_top.nothing_burger (); (* being removed shortly *) *)

  Stdio.print_endline "============ Begin Generation Phase ============ ";
  let global_spec = Signal.Reg_spec.create ~clock:(Signal.input "clk" 1) in
  ()

  (* let circ : Circuit.t =  *)
  (*   Circuit.create_exn ~name:"mac_top"  *)
  (*   [thing1; thing2] *)
  (* in *)
  (**)
  (* (* takes in a Circuit.t, returns a unit*) *)
  (* (* *)
  (*   C-Equivalent:  *)
  (*   void rtl(Circuit); *)
  (* *) *)
  (* let rtl : Circuit.t -> unit = Rtl.print Verilog in *)


