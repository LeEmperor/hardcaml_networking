# Hardcaml Example Usage

Hardcaml docs from Ocaml "https://docs.hardcaml.org/hardcaml-docs/introduction/why" are very "rough" in their inclusion and examples.
A simple doc list of common idioms in some places is missing. This serves as my own personal documentation for this.

## Registers
Registers are one of the fundamental structures in hardware. In Hardcaml they are handled slightly differently.

Instead of each register needing to be tied to a set of clocks, resets, and enables, Hardcaml groups these signals into a bundled profile or "spec".

Think of a spec belonging to a domain which defines a ```clock```, ```reset```, and ```enable```.

Instead of having to tie each of these signals for all the different registers that you may make, you are able to tie in this spec, which often times will represent some overarching clock/reset/enable domain.

#### Example - Defining Clock Edges
Within these reg speces, you can define things related to their edges. See below
```
  (*creates a default standard reg_spec*)
  let rising_edge: Reg_spec.t = 
    Reg_spec.create ~clock ~clear ~width:num () 
  in

  (*creates a reg spec that sources off the falling edge of the source clock*)
  let falling_edge : Reg_spec.t =
    Reg_spec.create ~clock:inputs.I.clk ~reset:inputs.I.rst ()
    |> Reg_spec.override ~clock_edge:Edge.Falling
  in
```


## Bit Vectors vs Bit Arrays
## Always Variable Usage
## Circuit Instantiation
## RTL Output
## Module Instantiation via False Wrapping
## Dune (from a C-Programmer's Perspective)

