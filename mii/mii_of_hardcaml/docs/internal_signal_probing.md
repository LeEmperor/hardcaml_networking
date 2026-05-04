# Internal Signal Probing in Hardcaml Simulations

By default, `Cyclesim` only exposes the top-level I/O ports of the module you are simulating.
To see signals buried inside submodules you need two things: a **Scope** and the `--` naming operator.

---

## The Two Pieces

### 1. Name signals with `--`

Inside any `create` function, tag signals you care about:

```ocaml
let byte_out   = byte_assembler_inst.byte_out   -- "byte_assembler_out" in
let byte_valid = byte_assembler_inst.byte_valid -- "byte_assembler_valid" in
let wire_out   = mux sel [zero 8; byte_out]     -- "wire_out" in
```

`--` is a passthrough — it returns the same signal unchanged but registers the name.
The string becomes the signal's label in the waveform/VCD.

### 2. Create the sim with `trace_all` and a flat Scope

In your testbench:

```ocaml
let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
let sim   = Sim.create ~config:Cyclesim.Config.trace_all (My_module.create scope) in
```

- `flatten_design:true` — collapses all hierarchy into one flat circuit for simulation,
  making every named signal reachable regardless of nesting depth.
- `trace_all` — tells Cyclesim to expose all named signals as observable ports,
  not just the top-level I/O.
- The scope is partially applied to `create` before being handed to `Sim.create`,
  satisfying the expected `Signal.t I.t -> Signal.t O.t` type.

---

## Hierarchical Naming with `Scope.sub_scope`

If you have multiple submodules and want their signals namespaced, use `sub_scope`:

```ocaml
let create scope inputs =
  let scope = Scope.sub_scope scope "rx_datapath" in
  let wire_out = some_signal -- "wire_out" in   (* visible as "rx_datapath$wire_out" *)
  ...
```

Each level of `sub_scope` prepends a path segment, so signals from different submodules
stay distinguishable in the waveform even if they share the same local name.

---

## Full Testbench Pattern

```ocaml
module Sim = Cyclesim.With_interface(My_module.I)(My_module.O)

let create_sim () =
  let scope = Scope.create ~flatten_design:true ~auto_label_hierarchical_ports:true () in
  let sim   = Sim.create ~config:Cyclesim.Config.trace_all (My_module.create scope) in
  let waves, sim = Waveform.create sim in
  let inputs  : _ My_module.I.t = Cyclesim.inputs sim in
  let outputs : _ My_module.O.t = Cyclesim.outputs sim in
  (sim, waves, inputs, outputs)
```

---

## Summary

| What you want | How to do it |
|---|---|
| Name an internal signal | `let x = signal -- "label" in` |
| Expose all named signals in sim | `~config:Cyclesim.Config.trace_all` |
| Flatten hierarchy for simulation | `Scope.create ~flatten_design:true ()` |
| Namespace signals by submodule | `Scope.sub_scope scope "name"` |
| Pass scope into create | partial application: `My_module.create scope` |
