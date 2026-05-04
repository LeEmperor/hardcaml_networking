load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "common",
    srcs = ["//tools:dune_dir.sh"],
    args = ["build", "lib/common"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "mii",
    srcs = ["//tools:dune_dir.sh"],
    args = ["build", "lib/mii"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "rgmii",
    srcs = ["//tools:dune_dir.sh"],
    args = ["build", "lib/rgmii"],
    visibility = ["//visibility:public"],
)
