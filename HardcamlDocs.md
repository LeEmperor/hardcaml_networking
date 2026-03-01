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
Bit vectors are more supported than bit arrays. One will have to use ```Array.to_list``` in order to access individual elements with an array, though arrays offer more support with potentially software-minded manipulations of the array (such as operations in which we make an array as a result of an HLS-ish approach to things).

## Always Variable Usage
This thing is truly screwy. 

## Circuit Instantiation
To make a circuit you need "inputs", "outputs", and a "circuit" instance. A circuit instance is a "Circuit.t" item that is made by tracing the dependencies from a Signal.output. The Circuit.t is made from a "create_exn" call which takes in a list of output signals.

## RTL Output
The "Rtl" module has various ways to finally print out the RTL as a result of this Circuit.t item via functions such as "Rtl.output" and "Rtl.print". Rtl.print will print out the Verilog to stdio. Rtl.output will write a file (specced by the language of VHDL/Verilog). This comes from the calling location, so if you call from some nested directory it will create it there vs in a more "standard" place.

## Module Instantiation via False Wrapping
The standard way that Dune handles its "libraries" relates to each directory with a "dune" file in it wrapping all the .ml (and .mli) files into a single library. If you wish to house multiple libraries in a single directory it is required that the "library" stanza in the dune file explicitly list the modules in each of them like so
```
(library
 (name rgmii_interfaces)
 ; (modules rgmii_interfaces rgmii_phy rgmii_types rx_deserializer)
 (modules rgmii_interfaces rgmii_phy rx_sink tx_source rx_deserializer)
 (libraries hardcaml hardcaml_waveterm)
 (preprocess (pps ppx_hardcaml ppx_jane))
 (wrapped false)
 (flags (:standard -w -27-57-33-34-35-40-63-47-26))
)

(library
 (name eth_mac)
 ; (modules eth_mac mac_core crc32)
 (modules eth_mac)
 (libraries hardcaml rgmii_interfaces)
 (preprocess (pps ppx_hardcaml ppx_jane))
 (flags (:standard -w -27-57-33-34-35-40-63-47))
)
```
Here we see (2) libraries, each of which are constructed of a series of modules. It must be noted that a module can only ever be included in (1) library at a time. If you wish to call upon a module that is in a library, aka I have "big_library" with which "small_service" is contained within (both are modules), then you would have to use "Open Big_library" and then call functions from "small_service" via "Small_service.function". 

This method of calling can be annoying and tedious however; instead we can use the "wrapped" sexp in the library stanza. See above that "wrapped" is listed as "false", which gives the caller the ability to call (and open) modules nested inside of other modules/libraries.

## Dune (from a C-Programmer's Perspective)
A "dune" file is a essentially a header system that OCaml uses. A given project will consist of a "dune-project" file which will act as a project root for any on going dune projects developed. When "dune run" or "dune build" are executed, it (being the compiler/dune? itself) will dig upwards from wherever it is until it finds a dune-project file. This is quite useful as you can be in a deeply nested directory of a project, and "dune build" will still be a functional command to run - however any files that are made as a result of the execution such as what gets made by an "Rtl.output" call will go in the calling directory (unless you have some sort of handling for this).

Your "main dune", which we shall reference as the dune file that corresponds to your main.ml file, will be able to use library sexps calling upon any libraries made by library stanzas elsewhere in your project.

## Reg Specs
When creating your overaching design you will find the need for a reg_spec that encompasses your global "clock".
Reg_spec has a required argument of the "clock" label (accessed via ~clock) in order to return a correct Reg_spec.t
If this is a label I have no idea why we need this thing.

## Using Cyclesim
Cyclesim is ¨à la poubelle¨. Cycle-based simulators are garbage things that should be ignored for any slightly serious development of RTL. Event-driven simulation is the only way to approach things as you are given a much finer tuned control over stuff for heavier simulation, though it may run slower. I find it very plausible that the Janestreet devs hoard the good tools and documentation to their internals, and use this mess of garbage to act as a "trial by fire" to understanding pretty much anything. I accept this challenge. 

## Modules as Typed Namespaces
Instead of creating a bunch of hanging garbage everywhere, apparently you can use the "module" keyword to create a module. Modules appear to be this sort of object that contains a set of functions/expressions. This essentially let's you call things like Module.create which will instantiate the circuit within it, and give you back a state of the Module?

```module Thing = Evsim.With_interface (Counter.I) (Counter.O)```
This appears to wrap your interfaces and the corresponding record types together. Instead of having to make a bunch of the individual "Signal.input" and "Signal.output" pins yourself, you can use this functor to automatically tie together your input and output record, and keep them scoped in the functor instance. Or something like that, this shit is confusing as balls.

Functor "With_interface" takes in (2) modules - expecting them to be the input and output ones.
The functor returns a new module "Thing" as I have called it.

Think of "modules" as a very weird type of object instance.

Let's form a practical example out of Hardcaml-relevant things. First of all, one must redo their idea of what a "module" is. In the RTL world many of us use the word module as a loose definition for a "thing that does a thing." However in Hardcaml land, the definition of a module is more-so override by the use of the namesake keyword in OCaml.

Let's take a given circuit : a counter. A Hardcaml circuit is loosely constructed of the following:
    1. Input Interface (which is defined as a module)
    2. Output Interface (which is also defined as a module)
    3. Logic Function (which is NOT defined as a module)

```With_interface``` itself takes in 2 modules as we have described before. But what use is this for us? This returned module has knowledge on the type and shape of the input and output ports. This special module that has been returned by With_interface also has what's essentially a ptr to a function for the create implementation. 

We can call "Thing.create <create_function_name>" and it will understand that we are attempting to use (in this example) Counter's create function. The modules special space will now construct the input and output records, and instantiate them in the steps to make a Circuit.t.

The standard abstraction we consider if we group these things together is called a "module" as well. So where does the use of these seemingly "special" modules come in Hardcaml? The answer lies in the namespaces, as well as grouping/scoping together of the inputs and outputs. Instead of having to construct together some floating input and output signals, we can keep them contained in a certain namespace or in OCaml terms, a "modulespace". This ensures that our input and outputs are not conflicted by some other name conflict. 

TLDR
```With_interface``` is a functor, and takes in (2) modules - the input and output interfaces of your circuit, and returns a module that bundles together your 2 interfaces. This is compile time. And lays a bunch of stuff out.

Thing.create will do the following roughly in order:
    1. Instantiate input signal records.
    2. Tie these to the input pins in your circuit design.
    3. Run your "create" command, with which output pins are generated.
    4. Instantiate output records.
    5. Tie output pins to signal records.
    6. Run create_exn on this set of created things.
    7. Chuck the created Circuit.t (from create_exn) into event-driven ops/processes
    8. Return {processes; inputs; outputs; memories; internals}

  Counter.create
      ↓
    called with fresh Signal.input nodes matching I
      ↓
    returns Signal.t O.t  (a graph of connected signals)
      ↓
    Circuit.create_exn wraps the graph into a Circuit.t
      ↓
    Ops.circuit_to_processes walks the graph, emits one Process.t per gate
      ↓
    your testbench callback is called → returns more Process.t (clock, stimulus)
      ↓
    Waveterm probes are created → more Process.t that record signal changes
      ↓
    Simulator.create(all processes combined) → Simulator.t
      ↓
    returns (Waveform.t, { simulator; ports_and_processes })

## The Event Driven Simulator
This is apparently some esoteric and oddly documented library for event-driven simulation with Hardcaml. 
It appears that the newest versions of this item (0.18prev) are not available on opam, and thus must be manually compiled from the Github repo.
Opam install <repo> appears to find the dune-project file fine and install relatively ok.

```Make``` takes in a logic module, and returns a few modules that we need use of:
    1. Event_simulator <-- Simulation object of our test
    2. Logic (yes this is the same logic we just put in)
    3. With_interface <-- the interface definitions
    4. Ops - lower level circuit compiler
    5. Vcd - VCD output

We can think of our module instance "Thing" now as our overarching group of objects we want to access/use. This is a namespace in definition, and can be treated as a set of objects (functions, functors, modules) with which we can manipulate. 

For example, we can call Thing.simulator, but in the space of "this is Thing's simulator item", which itself (points is probably a bad descriptor) is an Evsim.Event_simulator.t.

## Logic.S in Hardcaml
There are two different types of logic in Hardcaml (currently). 
    1. Two_state_logic - implements 0s and 1s
    2. Four_state_logic - implements 0s, 1s, Zs, and Xs


throaway:
    Circuit.t is what we need to make RTL
        comes from create_exn on a scoped module that comes from With_interface instantiatons
    Simulator.t, Waveform.t are what we need for simulation
        comes from With_waveterm calls
            returned is (Waveterm.Waveform.t * { Simulator.t, ports_and_processes})
            you can just throway the ports_and_processes with a _ in the return statement (kind of like structured bindings)

## With_waveterm
This gives us a Waveterm.Waveform.t, and a Evsim.Event_simulator.t
what does it want?

```
  val with_waveterm
    :  ?config:Config.t
    -> Hardcaml.Interface.Create_fn(Input)(Output).t  (* your circuit function *)
    -> testbench_processes                             (* your callback *)
    -> Waveform.t * testbench

  type testbench_processes =
    Logic.t Port.t Input.t        (* wired input ports *)
    -> Logic.t Port.t Output.t    (* wired output ports *)
    -> Event_driven_sim.Simulator.Process.t list
```

## Function Typing - REWRITE TO BE MORE CLEAR

  (* this means that "rtl" is a function that takes in Circuit.t and returns unit*)
  (* as compared to an expression, which would just have : unit as the return*)
  let rtl : Circuit.t -> unit = Rtl.output Verilog in
  rtl circ;

Functions are implied on their return types many a time, but if you wish to be explicit, the explicit function signature consists of the name, the inputs, and the outputs. What is unique is that any input beyond the first (or perhaps output beyond the first) is carried over as a single argument to each instance of the function. So for a function "john_pork" you may have it take in 2 ints:

  ```
let john_pork : int -> int -> unit
```

And this function may display the two ints for example and then return nothing.

In the Rtl example, we define a function "rtl" that takes in a Circuit.t and returns a unit. This is just a shortened version of "Rtl.output", with the ~language lable being set as Verilog in any further calls of "rtl".

This represents that the function "john_pork" has the type "int -> int -> unit", which in itself is a curried representation of the function.
Technically "rtl" has type "int", but it returns a function that itself returns an int that itself returns a unit - key thing to note is that a function in OCaml can only ever have (1) argument at a time, so any demonstration is simply an implementation of this cascaded approach.

One must note that in function calls with many args, we may often times annotate the individual inputs.

```
let create (inputs : Signal.t I.t) (scope : Scope.t) : (Signal.t O.t) = blah blah
```

you must consider that the ":" in the very middle of all those parenthesis (the one in between the scope and signal sexps) is annotating the return type of the function itself. Each individual argument also has it's own type annotation as we can see in the sexps.

john_pork differentiates based on the fact that it only annotates the typing, but includes NOT the names of the inputs.
You would still need to define the names of the inputs in the fashion "fun input1 input2 -> <implementation>".
The way with the lots of sexps is simply sugar for the john_pork way.

