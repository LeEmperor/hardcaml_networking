# EthMac_of_Hardcaml

Ethernet MAC for 10/100 MBPs transfers. Targeted on Arty A7-100T DP83848x PHY present on board. 

Written in [HardCaml](https://github.com/janestreet/hardcaml) as a learning project. Any suggestions or contributions welcome.

Docs for PHY can be found [here](https://www.ti.com/lit/ds/symlink/dp83848j.pdf?ts=1776919033995&ref_url=http%253A%252F%252Fwww.ti.com%252F).



---
<br>

# Installation Pre-Requisites

## Automatic
This will install a new [opam](https://opam.ocaml.org/) switch for [OxCaml](https://oxcaml.org/get-oxcaml/), as well as the relevant package dependencies for you. 

Run ```./bootstrap.sh --install-deps```

WARNING: This may take up to 30 minutes to install!

<br>


## Manual
This is the recommended way of installing as any breaking objects won't damage the state of the repo.

#### OxCaml
OxCaml install:

```opam switch create oxcaml-5.2 5.2.0+ox --repos ox=git+https://github.com/oxcaml/opam-repository.git,default```

You will also want the following libraries for [OCaml](https://ocaml.org/)
1. ```dune```
2. ```hardcaml```
3. ```ppx_hardcaml```
4. ```hardcaml_waveterm```
5. ```alcotest```
6. ```ocamlformat```

Use ```opam install --switch=5.2.0+ox -y dune hardcaml ppx_hardcaml hardcaml_waveterm alcotest ocamlformat``` to install the set of dependencies manually, 

```OR``` let the bootstrap ```--install-deps``` flag handle it for you. You can also opt to install the main OxCaml switch yourself, and then let the dependencies afterwards get handled by ```./bootstrap.sh```.

<br>

#### Ubuntu/Debian (tested on 22.04/24.04)
```sudo apt install opam build-essential pkg-config```

#### macOS
```brew install opam```

#### Windows
```lmao```

<br>

---

# Setup
Run ```./bootstrap.sh```, followed by ```source ./env.sh```. You will see relevant targets for [Bazel](https://bazel.build/) listed as examples.
