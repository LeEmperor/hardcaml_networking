module rx_frame_parser (
    rst,
    clk,
    rx_valid,
    rx_byte,
    byte,
    valid,
    sof,
    eof,
    err,
    state
);

    input rst;
    input clk;
    input rx_valid;
    input [7:0] rx_byte;
    output [7:0] byte;
    output valid;
    output sof;
    output eof;
    output err;
    output [3:0] state;

    wire [1:0] _21;
    wire [3:0] _26;
    wire _47;
    wire _48;
    wire _49;
    wire _40;
    wire _41;
    wire _42;
    wire _43;
    wire _32;
    wire _34;
    wire _30;
    wire _44;
    wire _28;
    wire _50;
    wire _2;
    wire _53;
    wire _52;
    wire _54;
    wire _4;
    wire _59;
    wire _68;
    wire _69;
    wire _70;
    wire _64;
    wire _65;
    wire _66;
    wire _61;
    wire _62;
    wire _57;
    wire _63;
    wire _56;
    wire _67;
    wire _55;
    wire _71;
    wire _6;
    reg _60;
    wire _73;
    wire _74;
    wire _72;
    wire _75;
    wire _7;
    wire _94;
    wire gnd;
    wire vdd;
    wire _10;
    wire _12;
    wire _46;
    wire [1:0] _89;
    wire _45;
    wire [1:0] _90;
    wire [1:0] _91;
    wire [7:0] _38;
    wire _39;
    wire [1:0] _84;
    wire [7:0] _36;
    wire _37;
    wire [1:0] _85;
    wire [1:0] _86;
    wire [1:0] _87;
    wire [1:0] _82;
    wire _14;
    wire _35;
    wire [1:0] _80;
    wire [1:0] _31;
    wire _79;
    wire [1:0] _81;
    wire [1:0] _51;
    wire _78;
    wire [1:0] _83;
    wire [1:0] _29;
    wire _77;
    wire [1:0] _88;
    wire _76;
    wire [1:0] _92;
    wire [1:0] _15;
    reg [1:0] _25;
    wire _93;
    wire _95;
    wire _16;
    wire [7:0] _19;
    assign _21 = 2'b00;
    assign _26 = { _21,
                   _25 };
    assign _47 = _46 ? gnd : vdd;
    assign _48 = _45 ? gnd : _47;
    assign _49 = _14 ? _48 : gnd;
    assign _40 = _39 ? gnd : vdd;
    assign _41 = _37 ? gnd : _40;
    assign _42 = _14 ? _41 : gnd;
    assign _43 = _35 ? vdd : _42;
    assign _32 = _25 == _31;
    assign _34 = _32 ? vdd : gnd;
    assign _30 = _25 == _29;
    assign _44 = _30 ? _43 : _34;
    assign _28 = _25 == _21;
    assign _50 = _28 ? _49 : _44;
    assign _2 = _50;
    assign _53 = _35 ? vdd : gnd;
    assign _52 = _25 == _51;
    assign _54 = _52 ? _53 : gnd;
    assign _4 = _54;
    assign _59 = 1'b0;
    assign _68 = _46 ? vdd : _60;
    assign _69 = _45 ? _60 : _68;
    assign _70 = _14 ? _69 : _60;
    assign _64 = _39 ? vdd : _60;
    assign _65 = _37 ? _60 : _64;
    assign _66 = _14 ? _65 : _60;
    assign _61 = _60 ? gnd : _60;
    assign _62 = _14 ? _61 : _60;
    assign _57 = _25 == _51;
    assign _63 = _57 ? _62 : _60;
    assign _56 = _25 == _29;
    assign _67 = _56 ? _66 : _63;
    assign _55 = _25 == _21;
    assign _71 = _55 ? _70 : _67;
    assign _6 = _71;
    always @(posedge _12) begin
        if (_10)
            _60 <= _59;
        else
            _60 <= _6;
    end
    assign _73 = _60 ? vdd : gnd;
    assign _74 = _14 ? _73 : gnd;
    assign _72 = _25 == _51;
    assign _75 = _72 ? _74 : gnd;
    assign _7 = _75;
    assign _94 = _14 ? vdd : gnd;
    assign gnd = 1'b0;
    assign vdd = 1'b1;
    assign _10 = rst;
    assign _12 = clk;
    assign _46 = _19 == _38;
    assign _89 = _46 ? _51 : _31;
    assign _45 = _19 == _36;
    assign _90 = _45 ? _29 : _89;
    assign _91 = _14 ? _90 : _25;
    assign _38 = 8'b11010101;
    assign _39 = _19 == _38;
    assign _84 = _39 ? _51 : _31;
    assign _36 = 8'b01010101;
    assign _37 = _19 == _36;
    assign _85 = _37 ? _25 : _84;
    assign _86 = _14 ? _85 : _25;
    assign _87 = _35 ? _31 : _86;
    assign _82 = _35 ? _21 : _25;
    assign _14 = rx_valid;
    assign _35 = ~ _14;
    assign _80 = _35 ? _21 : _25;
    assign _31 = 2'b11;
    assign _79 = _25 == _31;
    assign _81 = _79 ? _80 : _25;
    assign _51 = 2'b10;
    assign _78 = _25 == _51;
    assign _83 = _78 ? _82 : _81;
    assign _29 = 2'b01;
    assign _77 = _25 == _29;
    assign _88 = _77 ? _87 : _83;
    assign _76 = _25 == _21;
    assign _92 = _76 ? _91 : _88;
    assign _15 = _92;
    always @(posedge _12) begin
        if (_10)
            _25 <= _21;
        else
            _25 <= _15;
    end
    assign _93 = _25 == _51;
    assign _95 = _93 ? _94 : gnd;
    assign _16 = _95;
    assign _19 = rx_byte;
    assign byte = _19;
    assign valid = _16;
    assign sof = _7;
    assign eof = _4;
    assign err = _2;
    assign state = _26;

endmodule
