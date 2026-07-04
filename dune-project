(lang dune 3.17)

(name EthMac_of_Hardcaml)

(generate_opam_files true)

(package
 (name EthMac_of_Hardcaml)
 (allow_empty)
 (synopsis "Ethernet MAC (10/100) components written in Hardcaml")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.15))
  core
  hardcaml
  ppx_hardcaml
  hardcaml_circuits
  hardcaml_waveterm
  alcotest))
