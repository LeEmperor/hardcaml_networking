module second_pulse #(
  parameter int CLK_FREQ = 100_000_000
) (
  input  logic clk,
  input  logic rst,
  output logic pulse
);

localparam int W = $clog2(CLK_FREQ);

logic [W-1:0] cnt;

always_ff @(posedge clk) begin
  if (rst) begin
    cnt   <= '0;
    pulse <= 1'b0;
  end else begin
    pulse <= 1'b0;
    if (cnt == W'(CLK_FREQ - 1)) begin
      cnt   <= '0;
      pulse <= 1'b1;
    end else begin
      cnt <= cnt + 1;
    end
  end
end

endmodule
