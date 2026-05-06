load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "mii",
    srcs = ["//tools:dune_dir.sh"],
    args = ["test", "test/mii"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "rgmii",
    srcs = ["//tools:dune_dir.sh"],
    args = ["test", "test/rgmii"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "wave_rx_mac_top_tb",
    srcs = ["//tools/open_wave.sh"],
    args = ["waves/rx_mac_top_tb.vcd"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "wave_tx_uart_top_tb",
    srcs = ["//tools/open_wave.sh"],
    args = ["waves/bruh.vcd"],
    visibility = ["//visibility:public"],
)

