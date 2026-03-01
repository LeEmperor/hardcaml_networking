module rx_deser (
    rx_ctl,
    rst,
    clk,
    rx_data3,
    rx_data2,
    rx_data1,
    rx_data0,
    clk_div2,
    byte,
    valid
);

    input rx_ctl;
    input rst;
    input clk;
    input rx_data3;
    input rx_data2;
    input rx_data1;
    input rx_data0;
    input clk_div2;
    output [7:0] byte;
    output valid;

    wire [3:0] _25;
    wire [3:0] _19;
    wire [3:0] _2;
    reg [3:0] _26;
    wire _4;
    wire _6;
    wire _8;
    wire _10;
    wire _12;
    wire _14;
    wire _16;
    wire [3:0] _20;
    wire [3:0] _17;
    reg [3:0] _23;
    wire [7:0] _27;
    assign _25 = 4'b0000;
    assign _19 = { _16,
                   _14,
                   _12,
                   _10 };
    assign _2 = _19;
    always @(negedge _8) begin
        if (_6)
            _26 <= _25;
        else
            if (_4)
                _26 <= _2;
    end
    assign _4 = rx_ctl;
    assign _6 = rst;
    assign _8 = clk;
    assign _10 = rx_data3;
    assign _12 = rx_data2;
    assign _14 = rx_data1;
    assign _16 = rx_data0;
    assign _20 = { _16,
                   _14,
                   _12,
                   _10 };
    assign _17 = _20;
    always @(posedge _8) begin
        if (_6)
            _23 <= _25;
        else
            if (_4)
                _23 <= _17;
    end
    assign _27 = { _23,
                   _26 };
    assign byte = _27;
    assign valid = _4;

endmodule
