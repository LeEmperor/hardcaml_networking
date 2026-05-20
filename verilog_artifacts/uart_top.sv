module uart_top #(
  parameter int WIDTH = 10
) (
  input logic clk,
  input logic rst,
  input logic en,

  output logic uart_tx
);

// internals
wire  tick;
wire  resync;
wire  byte_valid;
logic uart_tx_prev;

// 1Hz trigger — fires d_in_valid for one cycle per second
second_pulse #(
  .CLK_FREQ(100_000_000)
) second_pulse_i0 (
  .clk(clk),
  .rst(rst),
  .pulse(byte_valid)
);

// falling edge of uart_tx = IDLE->START; resync baud_gen so START bit is a full period
always_ff @(posedge clk) begin
  if (rst) uart_tx_prev <= 1'b1;
  else     uart_tx_prev <= uart_tx;
end
assign resync = uart_tx_prev & ~uart_tx;

// UART TX Instance
uart_tx uart_tx_i0 (
  .d_in(8'h55),
  .d_in_valid(byte_valid),
  .clk(clk),
  .rst(rst),
  .en(en),
  .tick(tick),
  .uart_tx(uart_tx),
  .keep()
);

// 115200 Clock Generation
baud_gen #(
  .CLK_FREQ(100_000_000),
  .BAUD(115200)
) baud_gen_i0 (
  .clk(clk),
  .rst(rst),
  .en(en),
  .resync(resync),
  .tick(tick)
);

endmodule

