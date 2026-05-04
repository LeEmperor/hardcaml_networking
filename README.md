# EthMac_of_Hardcaml

Ethernet MAC for 10/100 MBPs transfers. Targeted on Arty A7-100T DP83848x PHY present on board. 

Written in Hardcaml as a learning project. Any suggestions or contributions welcome.

Docs for PHY can be found [here](https://www.ti.com/lit/ds/symlink/dp83848j.pdf?ts=1776919033995&ref_url=http%253A%252F%252Fwww.ti.com%252F).




# Installation Pre-Requisites

## Oxcaml
Oxcaml is WAY too large to have a custom switch invoked on every repo clone, therefore it is a pre-requisite to have it, after which the build system will call into this switch.
```opam switch create oxcaml-5.2 5.2.0+ox --repos ox=git+https://github.com/oxcaml/opam-repository.git,default```

## Ubuntu/Debian (tested on 22/24)
```sudo apt install opam build-essential pkg-config```

## macOS
```brew install opam```

## Windows
```lmao```

# Setup
Run ```./scripts/bootstrap.sh```
