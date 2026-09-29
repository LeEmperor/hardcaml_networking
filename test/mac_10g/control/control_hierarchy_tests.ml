open! Core
open! Hardcaml
open! Mac_10g_of_hardcaml
module Dut = Mac_10g_control
module C = Circuit.With_interface (Dut.I) (Dut.O)

let rtl ~flatten =
  let scope = Scope.create ~flatten_design:flatten () in
  let circuit = C.create_exn ~name:"control_parent" (Dut.hierarchical scope) in
  Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  |> Rtl.full_hierarchy
  |> Rope.to_string
;;

let%test_unit "control plane hierarchy preserves synchronizer attributes" =
  let hierarchy = rtl ~flatten:false in
  List.iter [ "mac_10g_regs"; "mac_10g_cdc"; "mac_10g_control" ] ~f:(fun name ->
    assert (String.is_substring hierarchy ~substring:("module " ^ name)));
  assert (String.is_substring hierarchy ~substring:"ASYNC_REG");
  assert (String.is_substring (rtl ~flatten:true) ~substring:"ASYNC_REG")
;;

let%test_unit "command fanout is driven exclusively by owner-clock registers" =
  let scope = Scope.create ~flatten_design:true () in
  let i =
    Dut.I.map Dut.I.port_names_and_widths ~f:(fun (name, width) ->
      Signal.input name width)
  in
  let o = Dut.create scope i in
  let check ~clock ~reset output =
    let seen = ref Signal.Type.Set.empty in
    let rec visit signal =
      if not (Set.mem !seen signal)
      then (
        seen := Set.add !seen signal;
        match signal with
        | Signal.Type.Reg { register; _ } ->
          assert (
            Signal.Type.Uid.equal (Signal.uid register.clock.clock) (Signal.uid clock))
        | Signal.Type.Wire { driver = None; _ } ->
          assert (Signal.Type.Uid.equal (Signal.uid signal) (Signal.uid reset))
        | _ -> Signal.Type.Deps.iter signal ~f:visit)
    in
    visit output
  in
  List.iter
    [ o.tx_counters_clear_o; o.tx_soft_reset_o ]
    ~f:(check ~clock:i.tx_clock_i ~reset:i.tx_reset_i);
  List.iter
    [ o.rx_counters_clear_o; o.rx_soft_reset_o ]
    ~f:(check ~clock:i.rx_clock_i ~reset:i.rx_reset_i)
;;
