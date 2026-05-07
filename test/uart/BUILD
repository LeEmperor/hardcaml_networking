load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "uart_tx_tb",
    srcs = ["//tools:dune_tb.sh"],
    args = ["./test/uart/uart_tx_tb.exe"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "wave_tx_uart_top_tb",
    srcs = ["//tools:open_wave.sh"],
    args = ["waves_uart_top.vcd"],
    visibility = ["//visibility:public"],
)


