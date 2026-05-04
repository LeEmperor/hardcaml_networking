load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "rx_mac_top_tb",
    srcs = ["//tools:dune_dir.sh"],
    args = ["exec", "./test/mii/rx_mac_top_tb.exe"],
    visibility = ["//visibility:public"],
)
