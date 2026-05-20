module baud_gen #(
  parameter int CLK_FREQ = 100000000,
  parameter int BAUD = 115200
) (
  input logic clk,
  input logic rst,
  input logic en,
  input logic resync,
  output logic tick
);
localparam int DIV = CLK_FREQ / BAUD;
localparam int W = $clog2(DIV);
logic [W - 1 : 0] cnt;

always_ff @(posedge clk) begin
  if (rst || resync) begin
    cnt <= 0;
    tick <= 0;
  end else begin
    tick <= 0;
    if (en) begin
      if (cnt == (DIV - 1)) begin
        cnt <= 0;
        tick <= 1;
      end else begin
        cnt <= cnt + 1;
      end
    end
  end
end

endmodule

