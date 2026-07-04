load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "rx_path_tb",
    srcs = ["//tools:dune_tb.sh"],
    args = ["./test/mii/rx_path_tb.exe"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "wave_rx_path_tb",
    srcs = ["//tools:open_wave.sh"],
    args = ["waves_top.vcd"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "tx_byte_disassembler_tb",
    srcs = ["//tools:dune_tb.sh"],
    args = ["./test/mii/tx_byte_disassembler_tb.exe"],
    visibility = ["//visibility:public"],
)

