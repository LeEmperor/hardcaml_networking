load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

exports_files(
    [
        "dune_dir.sh",
        "dune_exec.sh",
        "dune_tb.sh",
        "open_wave.sh",
    ],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "dune_dir",
    srcs = ["dune_dir.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "build",
    srcs = ["dune_build.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "test",
    srcs = ["dune_test.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "fmt",
    srcs = ["dune_fmt.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "exec",
    srcs = ["dune_exec.sh"],
    visibility = ["//visibility:public"],
)


sh_binary(
    name = "dune_tb",
    srcs = ["dune_tb.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "open_wave",
    srcs = ["open_wave.sh"],
    visibility = ["//visibility:public"],
)
