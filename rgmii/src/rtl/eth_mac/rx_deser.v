module rx_deser (
    rx_ctl,
    rst,
    clk,
    rx_data_3,
    rx_data_2,
    rx_data_1,
    rx_data_0,
    byte,
    valid
);

    input rx_ctl;
    input rst;
    input clk;
    input rx_data_3;
    input rx_data_2;
    input rx_data_1;
    input rx_data_0;
    output [7:0] byte;
    output valid;

    wire [3:0] _18;
    wire [3:0] _12;
    wire [3:0] _2;
    reg [3:0] _19;
    wire [3:0] _13;
    wire [3:0] _10;
    reg [3:0] _16;
    wire [7:0] _20;
    assign _18 = 4'b0000;
    assign _12 = { rx_data_0,
                   rx_data_1,
                   rx_data_2,
                   rx_data_3 };
    assign _2 = _12;
    always @(negedge clk) begin
        if (rst)
            _19 <= _18;
        else
            if (rx_ctl)
                _19 <= _2;
    end
    assign _13 = { rx_data_0,
                   rx_data_1,
                   rx_data_2,
                   rx_data_3 };
    assign _10 = _13;
    always @(posedge clk) begin
        if (rst)
            _16 <= _18;
        else
            if (rx_ctl)
                _16 <= _10;
    end
    assign _20 = { _16,
                   _19 };
    assign byte = _20;
    assign valid = rx_ctl;

endmodule
