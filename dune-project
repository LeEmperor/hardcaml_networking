(lang dune 3.17)

(name hardcaml_networking)

(generate_opam_files true)

(source
 (github LeEmperor/hardcaml_networking))

(authors "Bohdan Purtell <bohdanpurtell@gmail.com>")

(maintainers "Bohdan Purtell <bohdanpurtell@gmail.com>")

(package
 (name hardcaml_networking)
 (synopsis "Networking hardware (Ethernet MAC, UART) written in Hardcaml")
 (description
  "Synthesizable networking blocks written in Hardcaml: a full-duplex 10/100 MII\nEthernet MAC, an IPv4/UDP stack over it, and a tick-driven UART pair, plus the\nsmall common circuits (edge detectors, clock divider, heartbeat) and the Arty\nA7-100T pin contract they share. Installs as hardcaml_networking.{common,mii,\nipv4,udp,uart}.")
 (depends
  (ocaml
   (>= 5.1))
  (dune
   (>= 3.17))
  ; The installed library surface (lib/) needs exactly these five. Everything
  ; below is test or repo tooling and must not be forced on a consumer.
  core
  hardcaml
  hardcaml_circuits
  ppx_hardcaml
  ppx_jane
  ; Test frameworks: test/ only.
  (hardcaml_step_testbench :with-test)
  (hardcaml_waveterm :with-test)
  (ppx_expect :with-test)
  (base_quickcheck :with-test)
  (alcotest :with-test)
  ; Repo tooling: synthesis/ reports and bin/generate.exe. Never
  ; installed, but needed for a root `dune build`, so they ride with-test
  ; rather than being dropped.
  (hardcaml_xilinx_reports :with-test)
  (async :with-test)
  (core_unix :with-test)
  (jane_rope :with-test)
  (ppx_js_style :with-dev-setup)
  (ocamlformat :with-dev-setup)
  (ocaml-lsp-server :with-dev-setup)))
