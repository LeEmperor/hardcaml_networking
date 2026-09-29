open! Core
open! Hardcaml
open! Mac_10g_of_hardcaml
module M = Mac_10g_top
module C = Circuit.With_interface (M.I) (M.O)

let rtl flatten =
  let scope = Scope.create ~flatten_design:flatten () in
  let circuit =
    C.create_exn
      ~name:"mac_parent"
      (M.hierarchical
         ~tx_buffer_depth_bytes:256
         ~rx_buffer_depth_bytes:256
         ~max_supported_frame_length:255
         scope)
  in
  Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  |> Rtl.full_hierarchy
  |> Rope.to_string
;;

let%test_unit "complete hierarchy preserves all owners and CDC attributes" =
  let hierarchy = rtl false in
  List.iter
    [ "mac_10g_top"
    ; "mac_10g_tx_ingress"
    ; "mac_10g_tx"
    ; "mac_10g_rx"
    ; "mac_10g_rx_egress"
    ; "mac_10g_packet_buffer"
    ; "mac_10g_control"
    ; "mac_10g_regs"
    ; "mac_10g_cdc"
    ]
    ~f:(fun name -> assert (String.is_substring hierarchy ~substring:("module " ^ name)));
  assert (String.is_substring hierarchy ~substring:"ASYNC_REG");
  assert (String.is_substring (rtl true) ~substring:"ASYNC_REG")
;;
