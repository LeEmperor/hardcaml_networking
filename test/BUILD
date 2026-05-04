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
