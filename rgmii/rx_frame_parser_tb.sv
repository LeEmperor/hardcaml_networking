module rx_frame_parser_tb;

logic t_clk;
logic clk_en;
logic t_rst;
logic t_rx_valid;
logic [7:0] t_rx_byte;
wire [7:0] t_byte;
wire t_valid;
wire t_sof;
wire t_eof;
wire t_err;
wire [3:0] t_state;

rx_frame_parser dut (
  .rst(t_rst),
  .clk(t_clk),
  .rx_valid(t_rx_valid),
  .rx_byte(t_rx_byte),
  .valid(t_valid),
  .sof(t_sof),
  .eof(t_sof),
  .err(t_err),
  .state(t_state)
);

initial begin : clk_proc
  t_clk = 0;
  forever #5 t_clk = ~t_clk & clk_en;

end

initial begin
  clk_en = 1;
  t_rst = 1;
  t_clk = 0;
  #10

  t_rst = 0;
  t_rx_valid = 1;
  t_rx_byte = 8'h55;
  #10

  #50

  t_rx_byte = 8'hD5;
  #10

  t_rx_byte = 8'hAB;
  #20

  #100
  t_rx_valid = 0;
  #50

  #50
  clk_en = 0;
  disable clk_proc;
end

endmodule

