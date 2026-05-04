(lang dune 3.17)

(name EthMac_of_Hardcaml)

(generate_opam_files true)

(package
 (name EthMac_of_Hardcaml)
 (synopsis "Ethernet MAC (10/100) components written in Hardcaml")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.15))
  hardcaml
  ppx_hardcaml
  hardcaml_waveterm
  alcotest))
