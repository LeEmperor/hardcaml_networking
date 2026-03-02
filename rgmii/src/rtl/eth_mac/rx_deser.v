module rx_deser (
    rx_ctl,
    rst,
    clk,
    rx_data,
    clk_div2,
    byte,
    valid
);

    input rx_ctl;
    input rst;
    input clk;
    input [3:0] rx_data;
    input clk_div2;
    output [7:0] byte;
    output valid;

    wire [3:0] _17;
    wire [3:0] _2;
    reg [3:0] _18;
    wire _4;
    wire _6;
    wire _8;
    wire [3:0] _10;
    wire [3:0] _11;
    reg [3:0] _15;
    wire [7:0] _19;
    assign _17 = 4'b0000;
    assign _2 = _10;
    always @(negedge _8) begin
        if (_6)
            _18 <= _17;
        else
            if (_4)
                _18 <= _2;
    end
    assign _4 = rx_ctl;
    assign _6 = rst;
    assign _8 = clk;
    assign _10 = rx_data;
    assign _11 = _10;
    always @(posedge _8) begin
        if (_6)
            _15 <= _17;
        else
            if (_4)
                _15 <= _11;
    end
    assign _19 = { _15,
                   _18 };
    assign byte = _19;
    assign valid = _4;

endmodule
