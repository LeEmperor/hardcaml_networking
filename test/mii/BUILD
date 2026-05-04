load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "rx_mac_top_tb",
    srcs = ["//tools:dune_tb.sh"],
    args = ["./test/mii/rx_mac_top_tb.exe"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "wave_rx_mac_top_tb",
    srcs = ["//tools:open_wave.sh"],
    args = ["waves_top.vcd"],
    visibility = ["//visibility:public"],
)
