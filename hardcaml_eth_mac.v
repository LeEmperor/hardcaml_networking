module hardcaml_eth_mac (
    clk100mhz,
    eth_rxd,
    eth_rxerr,
    btn,
    eth_rx_clk,
    eth_rx_dv,
    ck_a_i,
    ck_io_inner_i,
    ck_io_outer_i,
    ck_ioa_i,
    ck_miso,
    ck_rst_i,
    ck_scl_i,
    ck_sda_i,
    eth_col,
    eth_crs,
    eth_mdio_i,
    eth_tx_clk,
    isns0v95_n,
    isns0v95_p,
    isns5v0_n,
    isns5v0_p,
    ja_i,
    jb_i,
    jc_i,
    jd_i,
    qspi_dq_i,
    sw,
    uart_txd_in,
    vsns5v0_n,
    vsns5v0_p,
    vsnsvu_n,
    vsnsvu_p,
    led,
    led0_r,
    led0_g,
    led0_b,
    led1_r,
    led1_g,
    led1_b,
    led2_r,
    led2_g,
    led2_b,
    led3_r,
    led3_g,
    led3_b,
    uart_rxd_out,
    eth_mdc,
    eth_rstn,
    eth_ref_clk,
    eth_tx_en,
    eth_txd,
    ja_o,
    ja_oe,
    jb_o,
    jb_oe,
    jc_o,
    jc_oe,
    jd_o,
    jd_oe,
    ck_io_outer_o,
    ck_io_outer_oe,
    ck_io_inner_o,
    ck_io_inner_oe,
    ck_a_o,
    ck_a_oe,
    ck_mosi,
    ck_sck,
    ck_ss,
    ck_scl_o,
    ck_scl_oe,
    ck_sda_o,
    ck_sda_oe,
    scl_pup,
    sda_pup,
    ck_ioa_o,
    ck_ioa_oe,
    ck_rst_o,
    ck_rst_oe,
    eth_mdio_o,
    eth_mdio_oe,
    qspi_cs,
    qspi_dq_o,
    qspi_dq_oe,
    keep
);

    input clk100mhz;
    input [3:0] eth_rxd;
    input eth_rxerr;
    input [3:0] btn;
    input eth_rx_clk;
    input eth_rx_dv;
    input [11:0] ck_a_i;
    input [15:0] ck_io_inner_i;
    input [13:0] ck_io_outer_i;
    input ck_ioa_i;
    input ck_miso;
    input ck_rst_i;
    input ck_scl_i;
    input ck_sda_i;
    input eth_col;
    input eth_crs;
    input eth_mdio_i;
    input eth_tx_clk;
    input isns0v95_n;
    input isns0v95_p;
    input isns5v0_n;
    input isns5v0_p;
    input [7:0] ja_i;
    input [7:0] jb_i;
    input [7:0] jc_i;
    input [7:0] jd_i;
    input [3:0] qspi_dq_i;
    input [3:0] sw;
    input uart_txd_in;
    input vsns5v0_n;
    input vsns5v0_p;
    input vsnsvu_n;
    input vsnsvu_p;
    output [3:0] led;
    output led0_r;
    output led0_g;
    output led0_b;
    output led1_r;
    output led1_g;
    output led1_b;
    output led2_r;
    output led2_g;
    output led2_b;
    output led3_r;
    output led3_g;
    output led3_b;
    output uart_rxd_out;
    output eth_mdc;
    output eth_rstn;
    output eth_ref_clk;
    output eth_tx_en;
    output [3:0] eth_txd;
    output [7:0] ja_o;
    output [7:0] ja_oe;
    output [7:0] jb_o;
    output [7:0] jb_oe;
    output [7:0] jc_o;
    output [7:0] jc_oe;
    output [7:0] jd_o;
    output [7:0] jd_oe;
    output [13:0] ck_io_outer_o;
    output [13:0] ck_io_outer_oe;
    output [15:0] ck_io_inner_o;
    output [15:0] ck_io_inner_oe;
    output [11:0] ck_a_o;
    output [11:0] ck_a_oe;
    output ck_mosi;
    output ck_sck;
    output ck_ss;
    output ck_scl_o;
    output ck_scl_oe;
    output ck_sda_o;
    output ck_sda_oe;
    output scl_pup;
    output sda_pup;
    output ck_ioa_o;
    output ck_ioa_oe;
    output ck_rst_o;
    output ck_rst_oe;
    output eth_mdio_o;
    output eth_mdio_oe;
    output qspi_cs;
    output [3:0] qspi_dq_o;
    output [3:0] qspi_dq_oe;
    output keep;

    wire _115;
    wire _113;
    reg _116;
    wire dbg_emit_payload_controller;
    wire _528;
    wire _526;
    wire [2:0] state_vec;
    wire _524;
    wire _520;
    wire _518;
    wire _517;
    wire _519;
    wire _521;
    wire _522;
    wire _523;
    wire _525;
    wire _527;
    wire _529;
    wire _530;
    wire _531;
    reg _118;
    wire _119;
    wire _120;
    reg dbg_fcs_present;
    wire dbg_datapath_fcs_present;
    wire _512;
    wire _510;
    wire _508;
    wire _506;
    wire _504;
    wire _502;
    wire _500;
    wire _498;
    wire _496;
    wire _494;
    wire _492;
    wire _490;
    wire _488;
    wire _486;
    wire _484;
    wire _482;
    wire _480;
    wire _478;
    wire _476;
    wire _474;
    wire _472;
    wire _470;
    wire _468;
    wire _466;
    wire _464;
    wire _462;
    wire _460;
    wire _458;
    wire _456;
    wire _454;
    wire _452;
    wire [15:0] _447;
    wire [23:0] _448;
    wire [31:0] dbg_crc_4_bytes;
    wire _450;
    wire _445;
    wire _443;
    wire _441;
    wire _439;
    wire _437;
    wire _435;
    wire _433;
    wire [7:0] _428;
    reg [7:0] dbg_stage1_val;
    reg [7:0] dbg_stage2;
    reg [7:0] dbg_stage3;
    reg [7:0] dbg_stage4;
    reg _125;
    wire _4;
    wire _5;
    wire [7:0] dbg_payload_out_delayed;
    wire _431;
    wire _419;
    wire _417;
    wire _415;
    wire _413;
    wire _411;
    wire _409;
    wire _407;
    wire _405;
    wire _403;
    wire _401;
    wire _399;
    wire _397;
    wire _395;
    wire _393;
    wire _391;
    wire [15:0] _135;
    wire [15:0] _146;
    wire [7:0] _137;
    wire [15:0] _139;
    wire [15:0] _147;
    reg _129;
    wire _6;
    reg _131;
    wire _7;
    wire _134;
    wire [15:0] _148;
    wire [15:0] _8;
    reg [15:0] dbg_eth_type;
    wire _389;
    wire _387;
    wire _385;
    wire _383;
    wire _381;
    wire _379;
    wire _377;
    wire _375;
    wire _373;
    wire _371;
    wire _369;
    wire _367;
    wire _365;
    wire _363;
    wire _361;
    wire _359;
    wire _357;
    wire _355;
    wire _353;
    wire _351;
    wire _349;
    wire _347;
    wire _345;
    wire _343;
    wire _341;
    wire _339;
    wire _337;
    wire _335;
    wire _333;
    wire _331;
    wire _329;
    wire _327;
    wire _325;
    wire _323;
    wire _321;
    wire _319;
    wire _317;
    wire _315;
    wire _313;
    wire _311;
    wire _309;
    wire _307;
    wire _305;
    wire _303;
    wire _301;
    wire _299;
    wire _297;
    wire _295;
    wire [47:0] _156;
    wire [39:0] _161;
    wire [47:0] _162;
    wire [39:0] _158;
    wire [47:0] _160;
    wire [47:0] _163;
    reg _152;
    wire _9;
    reg dbg_dst_src_reg_en;
    wire _10;
    wire _155;
    wire [47:0] _164;
    wire [47:0] _11;
    reg [47:0] dbg_src_addr;
    wire _293;
    wire _291;
    wire _289;
    wire _287;
    wire _285;
    wire _283;
    wire _281;
    wire _279;
    wire _277;
    wire _275;
    wire _273;
    wire _271;
    wire _269;
    wire _267;
    wire _265;
    wire _263;
    wire _261;
    wire _259;
    wire _257;
    wire _255;
    wire _253;
    wire _251;
    wire _249;
    wire _247;
    wire _245;
    wire _243;
    wire _241;
    wire _239;
    wire _237;
    wire _235;
    wire _233;
    wire _231;
    wire _229;
    wire _227;
    wire _225;
    wire _223;
    wire _221;
    wire _219;
    wire _217;
    wire _215;
    wire _213;
    wire _211;
    wire _209;
    wire _207;
    wire _205;
    wire _203;
    wire _201;
    wire _199;
    wire [47:0] _178;
    wire [39:0] _174;
    wire [47:0] _176;
    wire [47:0] _179;
    reg _168;
    wire _12;
    reg dbg_dst_mac_reg_en;
    wire _13;
    wire _171;
    wire [47:0] _180;
    wire [47:0] _14;
    reg [47:0] dbg_dst_addr;
    wire _197;
    wire _194;
    wire _192;
    wire _190;
    wire _188;
    wire _186;
    wire _184;
    wire _182;
    wire _181;
    wire _183;
    wire _185;
    wire _187;
    wire _189;
    wire _191;
    wire _193;
    wire _195;
    wire _196;
    wire _198;
    wire _200;
    wire _202;
    wire _204;
    wire _206;
    wire _208;
    wire _210;
    wire _212;
    wire _214;
    wire _216;
    wire _218;
    wire _220;
    wire _222;
    wire _224;
    wire _226;
    wire _228;
    wire _230;
    wire _232;
    wire _234;
    wire _236;
    wire _238;
    wire _240;
    wire _242;
    wire _244;
    wire _246;
    wire _248;
    wire _250;
    wire _252;
    wire _254;
    wire _256;
    wire _258;
    wire _260;
    wire _262;
    wire _264;
    wire _266;
    wire _268;
    wire _270;
    wire _272;
    wire _274;
    wire _276;
    wire _278;
    wire _280;
    wire _282;
    wire _284;
    wire _286;
    wire _288;
    wire _290;
    wire _292;
    wire _294;
    wire _296;
    wire _298;
    wire _300;
    wire _302;
    wire _304;
    wire _306;
    wire _308;
    wire _310;
    wire _312;
    wire _314;
    wire _316;
    wire _318;
    wire _320;
    wire _322;
    wire _324;
    wire _326;
    wire _328;
    wire _330;
    wire _332;
    wire _334;
    wire _336;
    wire _338;
    wire _340;
    wire _342;
    wire _344;
    wire _346;
    wire _348;
    wire _350;
    wire _352;
    wire _354;
    wire _356;
    wire _358;
    wire _360;
    wire _362;
    wire _364;
    wire _366;
    wire _368;
    wire _370;
    wire _372;
    wire _374;
    wire _376;
    wire _378;
    wire _380;
    wire _382;
    wire _384;
    wire _386;
    wire _388;
    wire _390;
    wire _392;
    wire _394;
    wire _396;
    wire _398;
    wire _400;
    wire _402;
    wire _404;
    wire _406;
    wire _408;
    wire _410;
    wire _412;
    wire _414;
    wire _416;
    wire _418;
    wire _420;
    wire _432;
    wire _434;
    wire _436;
    wire _438;
    wire _440;
    wire _442;
    wire _444;
    wire _446;
    wire _451;
    wire _453;
    wire _455;
    wire _457;
    wire _459;
    wire _461;
    wire _463;
    wire _465;
    wire _467;
    wire _469;
    wire _471;
    wire _473;
    wire _475;
    wire _477;
    wire _479;
    wire _481;
    wire _483;
    wire _485;
    wire _487;
    wire _489;
    wire _491;
    wire _493;
    wire _495;
    wire _497;
    wire _499;
    wire _501;
    wire _503;
    wire _505;
    wire _507;
    wire _509;
    wire _511;
    wire _513;
    wire _514;
    wire _532;
    wire _535;
    wire [3:0] _536;
    wire [11:0] _540;
    wire [13:0] _544;
    wire [7:0] _617;
    wire [7:0] _618;
    wire [7:0] _48;
    reg [7:0] reg_byte_reg;
    wire [3:0] _717;
    wire [7:0] _706;
    wire [7:0] _705;
    wire [7:0] _704;
    wire [31:0] _699;
    wire [31:0] _696;
    wire [30:0] _694;
    wire [31:0] _695;
    wire _691;
    wire [31:0] _688;
    wire [30:0] _686;
    wire [31:0] _687;
    wire _683;
    wire [31:0] _680;
    wire [30:0] _678;
    wire [31:0] _679;
    wire _675;
    wire [31:0] _672;
    wire [30:0] _670;
    wire [31:0] _671;
    wire _667;
    wire [31:0] _664;
    wire [30:0] _662;
    wire [31:0] _663;
    wire _659;
    wire [31:0] _656;
    wire [30:0] _654;
    wire [31:0] _655;
    wire _651;
    wire [31:0] _648;
    wire [30:0] _646;
    wire [31:0] _647;
    wire _643;
    wire [31:0] _639;
    wire [31:0] _640;
    wire [30:0] _637;
    wire [31:0] _638;
    wire _634;
    wire _633;
    wire _635;
    wire [31:0] _641;
    wire _642;
    wire _644;
    wire [31:0] _649;
    wire _650;
    wire _652;
    wire [31:0] _657;
    wire _658;
    wire _660;
    wire [31:0] _665;
    wire _666;
    wire _668;
    wire [31:0] _673;
    wire _674;
    wire _676;
    wire [31:0] _681;
    wire _682;
    wire _684;
    wire [31:0] _689;
    wire _690;
    wire _692;
    wire [31:0] _697;
    wire [2:0] _627;
    wire _628;
    wire _629;
    wire [2:0] _624;
    wire _625;
    wire _626;
    wire _630;
    wire _631;
    wire [31:0] _698;
    wire [2:0] _619;
    wire _620;
    wire _621;
    wire _622;
    wire _623;
    wire [31:0] _700;
    wire [31:0] _49;
    reg [31:0] _632;
    wire [31:0] _702;
    wire [7:0] _703;
    wire [1:0] _701;
    reg [7:0] _707;
    wire [7:0] _50;
    reg [7:0] data_before_collision;
    wire [6:0] _710;
    wire [6:0] _708;
    wire [6:0] WRITE_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [6:0] WRITE_ADDRESS;
    wire [6:0] _51;
    (* RAM_STYLE="registers" *)
    reg [7:0] _609[0:127];
    wire [6:0] READ_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [6:0] READ_ADDRESS;
    wire [6:0] _52;
    wire _600;
    wire [7:0] _593;
    wire _598;
    reg used_gt_one;
    wire _602;
    wire [6:0] RA;
    reg [6:0] _606;
    wire [7:0] ram_rbw_data;
    reg collision;
    wire [7:0] memory;
    reg [7:0] _614;
    wire [7:0] _615;
    wire [7:0] _584;
    reg [7:0] _585;
    wire [7:0] _576;
    reg [7:0] _582;
    wire [7:0] _574;
    wire [2:0] _568;
    reg [7:0] _575;
    wire [7:0] _565;
    wire [7:0] _564;
    reg [7:0] byte_mux;
    wire [3:0] _715;
    wire [3:0] _716;
    wire [3:0] _718;
    wire [3:0] wire_output_nibble;
    wire _800;
    wire [2:0] _791;
    wire [2:0] _792;
    wire [2:0] _776;
    wire [2:0] _789;
    wire [2:0] _790;
    wire [2:0] _787;
    wire [2:0] _788;
    wire [2:0] _760;
    wire [2:0] _785;
    wire [2:0] _786;
    wire [2:0] _755;
    wire [2:0] _783;
    wire [2:0] _784;
    wire [2:0] _782;
    wire [2:0] _779;
    wire [10:0] _738;
    wire [10:0] _566;
    wire [10:0] _772;
    wire _773;
    wire [10:0] _774;
    wire [10:0] _775;
    wire [10:0] _767;
    wire _768;
    wire [10:0] _769;
    wire [7:0] _720;
    reg [7:0] USED_MINUS_1 = 8'b11111111;
    wire [7:0] _55;
    wire [7:0] _724;
    reg [7:0] USED_PLUS_1 = 8'b00000001;
    wire [7:0] _56;
    wire [7:0] _596;
    reg [7:0] USED;
    wire [7:0] _57;
    wire WR_INT;
    wire _58;
    wire _591;
    wire _730;
    wire _731;
    wire _59;
    wire _60;
    wire _589;
    wire _590;
    wire RD_INT;
    wire _595;
    wire [7:0] USED_NEXT;
    wire _733;
    wire _734;
    reg not_empty;
    wire _61;
    wire _586;
    wire _762;
    wire _761;
    wire _763;
    wire fifo_empty;
    wire _765;
    wire _766;
    wire [10:0] _770;
    wire [10:0] _756;
    wire _757;
    wire [10:0] _758;
    wire [10:0] _759;
    wire [10:0] _751;
    wire _752;
    wire [10:0] _753;
    wire [10:0] _754;
    wire _747;
    wire [10:0] _748;
    wire [10:0] _749;
    wire [10:0] _741;
    wire [10:0] _743;
    wire [10:0] _744;
    reg [10:0] _777;
    wire [10:0] _62;
    reg [10:0] reg_byte_counter;
    wire _739;
    wire [2:0] _780;
    wire _778;
    wire dis_ready;
    wire [2:0] _781;
    reg [2:0] _793;
    wire [2:0] _64;
    (* fsm_encoding="one_hot" *)
    reg [2:0] _557;
    wire _559;
    wire _560;
    wire _795;
    wire _797;
    wire _65;
    reg reg_high_sent;
    wire _802;
    wire wire_nibble_valid;
    wire vdd;
    wire [26:0] _805;
    wire [26:0] _803;
    wire _85;
    wire [26:0] _807;
    wire [26:0] _808;
    wire [26:0] _810;
    wire [26:0] _86;
    reg [26:0] cnt;
    wire _806;
    wire _813;
    wire _87;
    reg pulse;
    reg _957;
    wire [31:0] _953;
    wire [31:0] _890;
    wire [30:0] _888;
    wire [31:0] _889;
    wire _885;
    wire [31:0] _882;
    wire [30:0] _880;
    wire [31:0] _881;
    wire _877;
    wire [31:0] _874;
    wire [30:0] _872;
    wire [31:0] _873;
    wire _869;
    wire [31:0] _866;
    wire [30:0] _864;
    wire [31:0] _865;
    wire _861;
    wire [31:0] _858;
    wire [30:0] _856;
    wire [31:0] _857;
    wire _853;
    wire [31:0] _850;
    wire [30:0] _848;
    wire [31:0] _849;
    wire _845;
    wire [31:0] _842;
    wire [30:0] _840;
    wire [31:0] _841;
    wire _837;
    wire [31:0] _834;
    wire [30:0] _831;
    wire [31:0] _832;
    wire _828;
    wire _827;
    wire _829;
    wire [31:0] _835;
    wire _836;
    wire _838;
    wire [31:0] _843;
    wire _844;
    wire _846;
    wire [31:0] _851;
    wire _852;
    wire _854;
    wire [31:0] _859;
    wire _860;
    wire _862;
    wire [31:0] _867;
    wire _868;
    wire _870;
    wire [31:0] _875;
    wire _876;
    wire _878;
    wire [31:0] _883;
    wire _884;
    wire _886;
    wire [31:0] _891;
    wire [31:0] _892;
    wire _820;
    reg _819;
    wire _821;
    wire _822;
    reg _816;
    wire _88;
    wire _817;
    wire _823;
    wire _824;
    wire _825;
    wire [31:0] _894;
    wire [31:0] _89;
    reg [31:0] _826;
    wire _954;
    reg _958;
    wire [2:0] _946;
    wire [2:0] _947;
    wire [2:0] _944;
    wire [2:0] _945;
    wire [2:0] _942;
    wire [2:0] _943;
    wire [2:0] _913;
    wire [2:0] _914;
    wire _912;
    wire [2:0] _916;
    wire [2:0] _917;
    wire [2:0] _907;
    wire _905;
    wire [2:0] _909;
    wire [2:0] _910;
    wire [2:0] _900;
    wire [2:0] _902;
    wire [2:0] _903;
    reg [2:0] _918;
    wire [2:0] _919;
    wire [2:0] _90;
    reg [2:0] dbg_mac_byte_count;
    wire _898;
    wire [2:0] _940;
    wire [2:0] _941;
    wire [3:0] _922;
    wire [3:0] _923;
    wire [3:0] _91;
    reg [3:0] _144;
    wire [3:0] _93;
    wire [3:0] _924;
    wire [3:0] _925;
    wire [3:0] _94;
    reg [3:0] _142;
    wire [7:0] dbg_byte_assembler_out;
    reg [2:0] _938;
    wire [2:0] _939;
    wire _96;
    wire _895;
    wire _896;
    wire [2:0] _935;
    reg [2:0] _949;
    wire [3:0] _98;
    wire _110;
    wire _100;
    wire _928;
    wire _929;
    wire _101;
    reg _921;
    wire _932;
    wire _103;
    wire _104;
    wire _933;
    wire _105;
    reg dbg_byte_assembler_valid;
    wire _106;
    wire [2:0] _950;
    wire [2:0] _107;
    (* fsm_encoding="one_hot" *)
    reg [2:0] _112;
    reg _952;
    wire _108;
    wire gnd;
    wire [3:0] _959;
    assign _115 = 1'b0;
    assign _113 = 1'b1;
    always @* begin
        case (_112)
        3'b101:
            _116 <= _113;
        default:
            _116 <= _115;
        endcase
    end
    assign dbg_emit_payload_controller = _116;
    assign _528 = state_vec[2:2];
    assign _526 = state_vec[1:1];
    assign state_vec = _112;
    assign _524 = state_vec[0:0];
    assign _520 = dbg_mac_byte_count[2:2];
    assign _518 = dbg_mac_byte_count[1:1];
    assign _517 = dbg_mac_byte_count[0:0];
    assign _519 = _517 | _518;
    assign _521 = _519 | _520;
    assign _522 = _521 | dbg_dst_mac_reg_en;
    assign _523 = _522 | dbg_dst_src_reg_en;
    assign _525 = _523 | _524;
    assign _527 = _525 | _526;
    assign _529 = _527 | _528;
    assign _530 = _529 | dbg_emit_payload_controller;
    assign _531 = _530 | dbg_fcs_present;
    always @(posedge _100) begin
        if (_110)
            _118 <= _115;
        else
            _118 <= _103;
    end
    assign _119 = ~ _118;
    assign _120 = _119 & _103;
    always @(posedge _100) begin
        if (_110)
            dbg_fcs_present <= _115;
        else
            dbg_fcs_present <= _120;
    end
    assign dbg_datapath_fcs_present = dbg_fcs_present;
    assign _512 = dbg_crc_4_bytes[31:31];
    assign _510 = dbg_crc_4_bytes[30:30];
    assign _508 = dbg_crc_4_bytes[29:29];
    assign _506 = dbg_crc_4_bytes[28:28];
    assign _504 = dbg_crc_4_bytes[27:27];
    assign _502 = dbg_crc_4_bytes[26:26];
    assign _500 = dbg_crc_4_bytes[25:25];
    assign _498 = dbg_crc_4_bytes[24:24];
    assign _496 = dbg_crc_4_bytes[23:23];
    assign _494 = dbg_crc_4_bytes[22:22];
    assign _492 = dbg_crc_4_bytes[21:21];
    assign _490 = dbg_crc_4_bytes[20:20];
    assign _488 = dbg_crc_4_bytes[19:19];
    assign _486 = dbg_crc_4_bytes[18:18];
    assign _484 = dbg_crc_4_bytes[17:17];
    assign _482 = dbg_crc_4_bytes[16:16];
    assign _480 = dbg_crc_4_bytes[15:15];
    assign _478 = dbg_crc_4_bytes[14:14];
    assign _476 = dbg_crc_4_bytes[13:13];
    assign _474 = dbg_crc_4_bytes[12:12];
    assign _472 = dbg_crc_4_bytes[11:11];
    assign _470 = dbg_crc_4_bytes[10:10];
    assign _468 = dbg_crc_4_bytes[9:9];
    assign _466 = dbg_crc_4_bytes[8:8];
    assign _464 = dbg_crc_4_bytes[7:7];
    assign _462 = dbg_crc_4_bytes[6:6];
    assign _460 = dbg_crc_4_bytes[5:5];
    assign _458 = dbg_crc_4_bytes[4:4];
    assign _456 = dbg_crc_4_bytes[3:3];
    assign _454 = dbg_crc_4_bytes[2:2];
    assign _452 = dbg_crc_4_bytes[1:1];
    assign _447 = { dbg_stage3,
                    dbg_stage4 };
    assign _448 = { dbg_stage2,
                    _447 };
    assign dbg_crc_4_bytes = { dbg_stage1_val,
                               _448 };
    assign _450 = dbg_crc_4_bytes[0:0];
    assign _445 = dbg_payload_out_delayed[7:7];
    assign _443 = dbg_payload_out_delayed[6:6];
    assign _441 = dbg_payload_out_delayed[5:5];
    assign _439 = dbg_payload_out_delayed[4:4];
    assign _437 = dbg_payload_out_delayed[3:3];
    assign _435 = dbg_payload_out_delayed[2:2];
    assign _433 = dbg_payload_out_delayed[1:1];
    assign _428 = 8'b00000000;
    always @(posedge _100) begin
        if (_110)
            dbg_stage1_val <= _428;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage1_val <= dbg_byte_assembler_out;
    end
    always @(posedge _100) begin
        if (_110)
            dbg_stage2 <= _428;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage2 <= dbg_stage1_val;
    end
    always @(posedge _100) begin
        if (_110)
            dbg_stage3 <= _428;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage3 <= dbg_stage2;
    end
    always @(posedge _100) begin
        if (_110)
            dbg_stage4 <= _428;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage4 <= dbg_stage3;
    end
    always @* begin
        case (_112)
        3'b101:
            _125 <= _113;
        default:
            _125 <= _115;
        endcase
    end
    assign _4 = _125;
    assign _5 = _4;
    assign dbg_payload_out_delayed = _5 ? dbg_stage4 : _428;
    assign _431 = dbg_payload_out_delayed[0:0];
    assign _419 = dbg_eth_type[15:15];
    assign _417 = dbg_eth_type[14:14];
    assign _415 = dbg_eth_type[13:13];
    assign _413 = dbg_eth_type[12:12];
    assign _411 = dbg_eth_type[11:11];
    assign _409 = dbg_eth_type[10:10];
    assign _407 = dbg_eth_type[9:9];
    assign _405 = dbg_eth_type[8:8];
    assign _403 = dbg_eth_type[7:7];
    assign _401 = dbg_eth_type[6:6];
    assign _399 = dbg_eth_type[5:5];
    assign _397 = dbg_eth_type[4:4];
    assign _395 = dbg_eth_type[3:3];
    assign _393 = dbg_eth_type[2:2];
    assign _391 = dbg_eth_type[1:1];
    assign _135 = 16'b0000000000000000;
    assign _146 = { _428,
                    dbg_byte_assembler_out };
    assign _137 = dbg_eth_type[7:0];
    assign _139 = { _137,
                    _428 };
    assign _147 = _139 | _146;
    always @* begin
        case (_112)
        3'b100:
            _129 <= _113;
        default:
            _129 <= _115;
        endcase
    end
    assign _6 = _129;
    always @(posedge _100) begin
        if (_110)
            _131 <= _115;
        else
            _131 <= _6;
    end
    assign _7 = _131;
    assign _134 = _7 & dbg_byte_assembler_valid;
    assign _148 = _134 ? _147 : dbg_eth_type;
    assign _8 = _148;
    always @(posedge _100) begin
        if (_110)
            dbg_eth_type <= _135;
        else
            dbg_eth_type <= _8;
    end
    assign _389 = dbg_eth_type[0:0];
    assign _387 = dbg_src_addr[47:47];
    assign _385 = dbg_src_addr[46:46];
    assign _383 = dbg_src_addr[45:45];
    assign _381 = dbg_src_addr[44:44];
    assign _379 = dbg_src_addr[43:43];
    assign _377 = dbg_src_addr[42:42];
    assign _375 = dbg_src_addr[41:41];
    assign _373 = dbg_src_addr[40:40];
    assign _371 = dbg_src_addr[39:39];
    assign _369 = dbg_src_addr[38:38];
    assign _367 = dbg_src_addr[37:37];
    assign _365 = dbg_src_addr[36:36];
    assign _363 = dbg_src_addr[35:35];
    assign _361 = dbg_src_addr[34:34];
    assign _359 = dbg_src_addr[33:33];
    assign _357 = dbg_src_addr[32:32];
    assign _355 = dbg_src_addr[31:31];
    assign _353 = dbg_src_addr[30:30];
    assign _351 = dbg_src_addr[29:29];
    assign _349 = dbg_src_addr[28:28];
    assign _347 = dbg_src_addr[27:27];
    assign _345 = dbg_src_addr[26:26];
    assign _343 = dbg_src_addr[25:25];
    assign _341 = dbg_src_addr[24:24];
    assign _339 = dbg_src_addr[23:23];
    assign _337 = dbg_src_addr[22:22];
    assign _335 = dbg_src_addr[21:21];
    assign _333 = dbg_src_addr[20:20];
    assign _331 = dbg_src_addr[19:19];
    assign _329 = dbg_src_addr[18:18];
    assign _327 = dbg_src_addr[17:17];
    assign _325 = dbg_src_addr[16:16];
    assign _323 = dbg_src_addr[15:15];
    assign _321 = dbg_src_addr[14:14];
    assign _319 = dbg_src_addr[13:13];
    assign _317 = dbg_src_addr[12:12];
    assign _315 = dbg_src_addr[11:11];
    assign _313 = dbg_src_addr[10:10];
    assign _311 = dbg_src_addr[9:9];
    assign _309 = dbg_src_addr[8:8];
    assign _307 = dbg_src_addr[7:7];
    assign _305 = dbg_src_addr[6:6];
    assign _303 = dbg_src_addr[5:5];
    assign _301 = dbg_src_addr[4:4];
    assign _299 = dbg_src_addr[3:3];
    assign _297 = dbg_src_addr[2:2];
    assign _295 = dbg_src_addr[1:1];
    assign _156 = 48'b000000000000000000000000000000000000000000000000;
    assign _161 = 40'b0000000000000000000000000000000000000000;
    assign _162 = { _161,
                    dbg_byte_assembler_out };
    assign _158 = dbg_src_addr[39:0];
    assign _160 = { _158,
                    _428 };
    assign _163 = _160 | _162;
    always @* begin
        case (_112)
        3'b011:
            _152 <= _113;
        default:
            _152 <= _115;
        endcase
    end
    assign _9 = _152;
    always @(posedge _100) begin
        if (_110)
            dbg_dst_src_reg_en <= _115;
        else
            dbg_dst_src_reg_en <= _9;
    end
    assign _10 = dbg_dst_src_reg_en;
    assign _155 = _10 & dbg_byte_assembler_valid;
    assign _164 = _155 ? _163 : dbg_src_addr;
    assign _11 = _164;
    always @(posedge _100) begin
        if (_110)
            dbg_src_addr <= _156;
        else
            dbg_src_addr <= _11;
    end
    assign _293 = dbg_src_addr[0:0];
    assign _291 = dbg_dst_addr[47:47];
    assign _289 = dbg_dst_addr[46:46];
    assign _287 = dbg_dst_addr[45:45];
    assign _285 = dbg_dst_addr[44:44];
    assign _283 = dbg_dst_addr[43:43];
    assign _281 = dbg_dst_addr[42:42];
    assign _279 = dbg_dst_addr[41:41];
    assign _277 = dbg_dst_addr[40:40];
    assign _275 = dbg_dst_addr[39:39];
    assign _273 = dbg_dst_addr[38:38];
    assign _271 = dbg_dst_addr[37:37];
    assign _269 = dbg_dst_addr[36:36];
    assign _267 = dbg_dst_addr[35:35];
    assign _265 = dbg_dst_addr[34:34];
    assign _263 = dbg_dst_addr[33:33];
    assign _261 = dbg_dst_addr[32:32];
    assign _259 = dbg_dst_addr[31:31];
    assign _257 = dbg_dst_addr[30:30];
    assign _255 = dbg_dst_addr[29:29];
    assign _253 = dbg_dst_addr[28:28];
    assign _251 = dbg_dst_addr[27:27];
    assign _249 = dbg_dst_addr[26:26];
    assign _247 = dbg_dst_addr[25:25];
    assign _245 = dbg_dst_addr[24:24];
    assign _243 = dbg_dst_addr[23:23];
    assign _241 = dbg_dst_addr[22:22];
    assign _239 = dbg_dst_addr[21:21];
    assign _237 = dbg_dst_addr[20:20];
    assign _235 = dbg_dst_addr[19:19];
    assign _233 = dbg_dst_addr[18:18];
    assign _231 = dbg_dst_addr[17:17];
    assign _229 = dbg_dst_addr[16:16];
    assign _227 = dbg_dst_addr[15:15];
    assign _225 = dbg_dst_addr[14:14];
    assign _223 = dbg_dst_addr[13:13];
    assign _221 = dbg_dst_addr[12:12];
    assign _219 = dbg_dst_addr[11:11];
    assign _217 = dbg_dst_addr[10:10];
    assign _215 = dbg_dst_addr[9:9];
    assign _213 = dbg_dst_addr[8:8];
    assign _211 = dbg_dst_addr[7:7];
    assign _209 = dbg_dst_addr[6:6];
    assign _207 = dbg_dst_addr[5:5];
    assign _205 = dbg_dst_addr[4:4];
    assign _203 = dbg_dst_addr[3:3];
    assign _201 = dbg_dst_addr[2:2];
    assign _199 = dbg_dst_addr[1:1];
    assign _178 = { _161,
                    dbg_byte_assembler_out };
    assign _174 = dbg_dst_addr[39:0];
    assign _176 = { _174,
                    _428 };
    assign _179 = _176 | _178;
    always @* begin
        case (_112)
        3'b010:
            _168 <= _113;
        default:
            _168 <= _115;
        endcase
    end
    assign _12 = _168;
    always @(posedge _100) begin
        if (_110)
            dbg_dst_mac_reg_en <= _115;
        else
            dbg_dst_mac_reg_en <= _12;
    end
    assign _13 = dbg_dst_mac_reg_en;
    assign _171 = _13 & dbg_byte_assembler_valid;
    assign _180 = _171 ? _179 : dbg_dst_addr;
    assign _14 = _180;
    always @(posedge _100) begin
        if (_110)
            dbg_dst_addr <= _156;
        else
            dbg_dst_addr <= _14;
    end
    assign _197 = dbg_dst_addr[0:0];
    assign _194 = dbg_byte_assembler_out[7:7];
    assign _192 = dbg_byte_assembler_out[6:6];
    assign _190 = dbg_byte_assembler_out[5:5];
    assign _188 = dbg_byte_assembler_out[4:4];
    assign _186 = dbg_byte_assembler_out[3:3];
    assign _184 = dbg_byte_assembler_out[2:2];
    assign _182 = dbg_byte_assembler_out[1:1];
    assign _181 = dbg_byte_assembler_out[0:0];
    assign _183 = _181 | _182;
    assign _185 = _183 | _184;
    assign _187 = _185 | _186;
    assign _189 = _187 | _188;
    assign _191 = _189 | _190;
    assign _193 = _191 | _192;
    assign _195 = _193 | _194;
    assign _196 = _195 | dbg_byte_assembler_valid;
    assign _198 = _196 | _197;
    assign _200 = _198 | _199;
    assign _202 = _200 | _201;
    assign _204 = _202 | _203;
    assign _206 = _204 | _205;
    assign _208 = _206 | _207;
    assign _210 = _208 | _209;
    assign _212 = _210 | _211;
    assign _214 = _212 | _213;
    assign _216 = _214 | _215;
    assign _218 = _216 | _217;
    assign _220 = _218 | _219;
    assign _222 = _220 | _221;
    assign _224 = _222 | _223;
    assign _226 = _224 | _225;
    assign _228 = _226 | _227;
    assign _230 = _228 | _229;
    assign _232 = _230 | _231;
    assign _234 = _232 | _233;
    assign _236 = _234 | _235;
    assign _238 = _236 | _237;
    assign _240 = _238 | _239;
    assign _242 = _240 | _241;
    assign _244 = _242 | _243;
    assign _246 = _244 | _245;
    assign _248 = _246 | _247;
    assign _250 = _248 | _249;
    assign _252 = _250 | _251;
    assign _254 = _252 | _253;
    assign _256 = _254 | _255;
    assign _258 = _256 | _257;
    assign _260 = _258 | _259;
    assign _262 = _260 | _261;
    assign _264 = _262 | _263;
    assign _266 = _264 | _265;
    assign _268 = _266 | _267;
    assign _270 = _268 | _269;
    assign _272 = _270 | _271;
    assign _274 = _272 | _273;
    assign _276 = _274 | _275;
    assign _278 = _276 | _277;
    assign _280 = _278 | _279;
    assign _282 = _280 | _281;
    assign _284 = _282 | _283;
    assign _286 = _284 | _285;
    assign _288 = _286 | _287;
    assign _290 = _288 | _289;
    assign _292 = _290 | _291;
    assign _294 = _292 | _293;
    assign _296 = _294 | _295;
    assign _298 = _296 | _297;
    assign _300 = _298 | _299;
    assign _302 = _300 | _301;
    assign _304 = _302 | _303;
    assign _306 = _304 | _305;
    assign _308 = _306 | _307;
    assign _310 = _308 | _309;
    assign _312 = _310 | _311;
    assign _314 = _312 | _313;
    assign _316 = _314 | _315;
    assign _318 = _316 | _317;
    assign _320 = _318 | _319;
    assign _322 = _320 | _321;
    assign _324 = _322 | _323;
    assign _326 = _324 | _325;
    assign _328 = _326 | _327;
    assign _330 = _328 | _329;
    assign _332 = _330 | _331;
    assign _334 = _332 | _333;
    assign _336 = _334 | _335;
    assign _338 = _336 | _337;
    assign _340 = _338 | _339;
    assign _342 = _340 | _341;
    assign _344 = _342 | _343;
    assign _346 = _344 | _345;
    assign _348 = _346 | _347;
    assign _350 = _348 | _349;
    assign _352 = _350 | _351;
    assign _354 = _352 | _353;
    assign _356 = _354 | _355;
    assign _358 = _356 | _357;
    assign _360 = _358 | _359;
    assign _362 = _360 | _361;
    assign _364 = _362 | _363;
    assign _366 = _364 | _365;
    assign _368 = _366 | _367;
    assign _370 = _368 | _369;
    assign _372 = _370 | _371;
    assign _374 = _372 | _373;
    assign _376 = _374 | _375;
    assign _378 = _376 | _377;
    assign _380 = _378 | _379;
    assign _382 = _380 | _381;
    assign _384 = _382 | _383;
    assign _386 = _384 | _385;
    assign _388 = _386 | _387;
    assign _390 = _388 | _389;
    assign _392 = _390 | _391;
    assign _394 = _392 | _393;
    assign _396 = _394 | _395;
    assign _398 = _396 | _397;
    assign _400 = _398 | _399;
    assign _402 = _400 | _401;
    assign _404 = _402 | _403;
    assign _406 = _404 | _405;
    assign _408 = _406 | _407;
    assign _410 = _408 | _409;
    assign _412 = _410 | _411;
    assign _414 = _412 | _413;
    assign _416 = _414 | _415;
    assign _418 = _416 | _417;
    assign _420 = _418 | _419;
    assign _432 = _420 | _431;
    assign _434 = _432 | _433;
    assign _436 = _434 | _435;
    assign _438 = _436 | _437;
    assign _440 = _438 | _439;
    assign _442 = _440 | _441;
    assign _444 = _442 | _443;
    assign _446 = _444 | _445;
    assign _451 = _446 | _450;
    assign _453 = _451 | _452;
    assign _455 = _453 | _454;
    assign _457 = _455 | _456;
    assign _459 = _457 | _458;
    assign _461 = _459 | _460;
    assign _463 = _461 | _462;
    assign _465 = _463 | _464;
    assign _467 = _465 | _466;
    assign _469 = _467 | _468;
    assign _471 = _469 | _470;
    assign _473 = _471 | _472;
    assign _475 = _473 | _474;
    assign _477 = _475 | _476;
    assign _479 = _477 | _478;
    assign _481 = _479 | _480;
    assign _483 = _481 | _482;
    assign _485 = _483 | _484;
    assign _487 = _485 | _486;
    assign _489 = _487 | _488;
    assign _491 = _489 | _490;
    assign _493 = _491 | _492;
    assign _495 = _493 | _494;
    assign _497 = _495 | _496;
    assign _499 = _497 | _498;
    assign _501 = _499 | _500;
    assign _503 = _501 | _502;
    assign _505 = _503 | _504;
    assign _507 = _505 | _506;
    assign _509 = _507 | _508;
    assign _511 = _509 | _510;
    assign _513 = _511 | _512;
    assign _514 = _513 | dbg_datapath_fcs_present;
    assign _532 = _514 | _531;
    assign _535 = _532 | pulse;
    assign _536 = 4'b0000;
    assign _540 = 12'b000000000000;
    assign _544 = 14'b00000000000000;
    assign _617 = _560 ? byte_mux : reg_byte_reg;
    assign _618 = reg_high_sent ? reg_byte_reg : _617;
    assign _48 = _618;
    always @(posedge _100) begin
        if (_110)
            reg_byte_reg <= _428;
        else
            reg_byte_reg <= _48;
    end
    assign _717 = reg_byte_reg[7:4];
    assign _706 = _702[31:24];
    assign _705 = _702[23:16];
    assign _704 = _702[15:8];
    assign _699 = 32'b11111111111111111111111111111111;
    assign _696 = _695 ^ _639;
    assign _694 = _689[31:1];
    assign _695 = { _115,
                    _694 };
    assign _691 = byte_mux[7:7];
    assign _688 = _687 ^ _639;
    assign _686 = _681[31:1];
    assign _687 = { _115,
                    _686 };
    assign _683 = byte_mux[6:6];
    assign _680 = _679 ^ _639;
    assign _678 = _673[31:1];
    assign _679 = { _115,
                    _678 };
    assign _675 = byte_mux[5:5];
    assign _672 = _671 ^ _639;
    assign _670 = _665[31:1];
    assign _671 = { _115,
                    _670 };
    assign _667 = byte_mux[4:4];
    assign _664 = _663 ^ _639;
    assign _662 = _657[31:1];
    assign _663 = { _115,
                    _662 };
    assign _659 = byte_mux[3:3];
    assign _656 = _655 ^ _639;
    assign _654 = _649[31:1];
    assign _655 = { _115,
                    _654 };
    assign _651 = byte_mux[2:2];
    assign _648 = _647 ^ _639;
    assign _646 = _641[31:1];
    assign _647 = { _115,
                    _646 };
    assign _643 = byte_mux[1:1];
    assign _639 = 32'b11101101101110001000001100100000;
    assign _640 = _638 ^ _639;
    assign _637 = _632[31:1];
    assign _638 = { _115,
                    _637 };
    assign _634 = byte_mux[0:0];
    assign _633 = _632[0:0];
    assign _635 = _633 ^ _634;
    assign _641 = _635 ? _640 : _638;
    assign _642 = _641[0:0];
    assign _644 = _642 ^ _643;
    assign _649 = _644 ? _648 : _647;
    assign _650 = _649[0:0];
    assign _652 = _650 ^ _651;
    assign _657 = _652 ? _656 : _655;
    assign _658 = _657[0:0];
    assign _660 = _658 ^ _659;
    assign _665 = _660 ? _664 : _663;
    assign _666 = _665[0:0];
    assign _668 = _666 ^ _667;
    assign _673 = _668 ? _672 : _671;
    assign _674 = _673[0:0];
    assign _676 = _674 ^ _675;
    assign _681 = _676 ? _680 : _679;
    assign _682 = _681[0:0];
    assign _684 = _682 ^ _683;
    assign _689 = _684 ? _688 : _687;
    assign _690 = _689[0:0];
    assign _692 = _690 ^ _691;
    assign _697 = _692 ? _696 : _695;
    assign _627 = 3'b110;
    assign _628 = _627 < _557;
    assign _629 = ~ _628;
    assign _624 = 3'b011;
    assign _625 = _557 < _624;
    assign _626 = ~ _625;
    assign _630 = _626 & _629;
    assign _631 = dis_ready & _630;
    assign _698 = _631 ? _697 : _632;
    assign _619 = 3'b000;
    assign _620 = _557 == _619;
    assign _621 = ~ _620;
    assign _622 = ~ _621;
    assign _623 = _110 | _622;
    assign _700 = _623 ? _699 : _698;
    assign _49 = _700;
    always @(posedge _100) begin
        _632 <= _49;
    end
    assign _702 = ~ _632;
    assign _703 = _702[7:0];
    assign _701 = _568[1:0];
    always @* begin
        case (_701)
        0:
            _707 <= _703;
        1:
            _707 <= _704;
        2:
            _707 <= _705;
        default:
            _707 <= _706;
        endcase
    end
    assign _50 = _707;
    always @(posedge _100) begin
        data_before_collision <= _428;
    end
    assign _710 = 7'b0000000;
    assign _708 = 7'b0000001;
    assign WRITE_ADDRESS_NEXT = _51 + _708;
    always @(posedge _100) begin
        if (_110)
            WRITE_ADDRESS <= _710;
        else
            if (_115)
                WRITE_ADDRESS <= WRITE_ADDRESS_NEXT;
    end
    assign _51 = WRITE_ADDRESS;
    always @(posedge _100) begin
        if (_115)
            _609[_51] <= _428;
    end
    assign READ_ADDRESS_NEXT = _52 + _708;
    always @(posedge _100) begin
        if (_110)
            READ_ADDRESS <= _710;
        else
            if (_602)
                READ_ADDRESS <= READ_ADDRESS_NEXT;
    end
    assign _52 = READ_ADDRESS;
    assign _600 = RD_INT ^ WR_INT;
    assign _593 = 8'b00000001;
    assign _598 = _593 < USED_NEXT;
    always @(posedge _100) begin
        if (_110)
            used_gt_one <= _115;
        else
            if (_600)
                used_gt_one <= _598;
    end
    assign _602 = RD_INT & used_gt_one;
    assign RA = _602 ? READ_ADDRESS_NEXT : _52;
    always @(posedge _100) begin
        _606 <= RA;
    end
    assign ram_rbw_data = _609[_606];
    always @(posedge _100) begin
        collision <= _115;
    end
    assign memory = collision ? data_before_collision : ram_rbw_data;
    always @(posedge _100) begin
        if (_110)
            _614 <= _428;
        else
            if (RD_INT)
                _614 <= memory;
    end
    assign _615 = _586 ? _428 : _614;
    assign _584 = 8'b10011001;
    always @* begin
        case (_568)
        0:
            _585 <= _584;
        default:
            _585 <= _584;
        endcase
    end
    assign _576 = 8'b00000010;
    always @* begin
        case (_568)
        0:
            _582 <= _576;
        1:
            _582 <= _428;
        2:
            _582 <= _428;
        3:
            _582 <= _428;
        4:
            _582 <= _428;
        default:
            _582 <= _593;
        endcase
    end
    assign _574 = 8'b11111111;
    assign _568 = reg_byte_counter[2:0];
    always @* begin
        case (_568)
        0:
            _575 <= _574;
        1:
            _575 <= _574;
        2:
            _575 <= _574;
        3:
            _575 <= _574;
        4:
            _575 <= _574;
        default:
            _575 <= _574;
        endcase
    end
    assign _565 = 8'b11010101;
    assign _564 = 8'b01010101;
    always @* begin
        case (_557)
        0:
            byte_mux <= _428;
        1:
            byte_mux <= _564;
        2:
            byte_mux <= _565;
        3:
            byte_mux <= _575;
        4:
            byte_mux <= _582;
        5:
            byte_mux <= _585;
        6:
            byte_mux <= _615;
        default:
            byte_mux <= _50;
        endcase
    end
    assign _715 = byte_mux[3:0];
    assign _716 = _560 ? _715 : _536;
    assign _718 = reg_high_sent ? _717 : _716;
    assign wire_output_nibble = _718;
    assign _800 = _560 ? _113 : _115;
    assign _791 = _773 ? _619 : _557;
    assign _792 = dis_ready ? _791 : _557;
    assign _776 = 3'b111;
    assign _789 = _768 ? _776 : _557;
    assign _790 = _766 ? _789 : _557;
    assign _787 = _757 ? _627 : _557;
    assign _788 = dis_ready ? _787 : _557;
    assign _760 = 3'b101;
    assign _785 = _752 ? _760 : _557;
    assign _786 = dis_ready ? _785 : _557;
    assign _755 = 3'b100;
    assign _783 = _747 ? _755 : _557;
    assign _784 = dis_ready ? _783 : _557;
    assign _782 = dis_ready ? _624 : _557;
    assign _779 = 3'b010;
    assign _738 = 11'b00000000110;
    assign _566 = 11'b00000000000;
    assign _772 = 11'b00000000011;
    assign _773 = reg_byte_counter == _772;
    assign _774 = _773 ? _566 : _741;
    assign _775 = dis_ready ? _774 : reg_byte_counter;
    assign _767 = 11'b00000101101;
    assign _768 = reg_byte_counter == _767;
    assign _769 = _768 ? _566 : _741;
    assign _720 = USED_NEXT - _593;
    always @(posedge _100) begin
        if (_110)
            USED_MINUS_1 <= _574;
        else
            if (_595)
                USED_MINUS_1 <= _720;
    end
    assign _55 = USED_MINUS_1;
    assign _724 = USED_NEXT + _593;
    always @(posedge _100) begin
        if (_110)
            USED_PLUS_1 <= _593;
        else
            if (_595)
                USED_PLUS_1 <= _724;
    end
    assign _56 = USED_PLUS_1;
    assign _596 = RD_INT ? _55 : _56;
    always @(posedge _100) begin
        if (_110)
            USED <= _428;
        else
            if (_595)
                USED <= USED_NEXT;
    end
    assign _57 = USED;
    assign WR_INT = 1'b0;
    assign _58 = _586;
    assign _591 = ~ _58;
    assign _730 = _557 == _627;
    assign _731 = _730 & dis_ready;
    assign _59 = _731;
    assign _60 = _586;
    assign _589 = ~ _60;
    assign _590 = _589 & _59;
    assign RD_INT = _590 & _591;
    assign _595 = RD_INT ^ WR_INT;
    assign USED_NEXT = _595 ? _596 : _57;
    assign _733 = USED_NEXT == _428;
    assign _734 = ~ _733;
    always @(posedge _100) begin
        if (_110)
            not_empty <= _115;
        else
            if (_595)
                not_empty <= _734;
    end
    assign _61 = not_empty;
    assign _586 = ~ _61;
    assign _762 = ~ _586;
    assign _761 = ~ _110;
    assign _763 = _761 & _762;
    assign fifo_empty = ~ _763;
    assign _765 = ~ fifo_empty;
    assign _766 = _765 & dis_ready;
    assign _770 = _766 ? _769 : reg_byte_counter;
    assign _756 = 11'b00000000001;
    assign _757 = reg_byte_counter == _756;
    assign _758 = _757 ? _566 : _741;
    assign _759 = dis_ready ? _758 : reg_byte_counter;
    assign _751 = 11'b00000000101;
    assign _752 = reg_byte_counter == _751;
    assign _753 = _752 ? _566 : _741;
    assign _754 = dis_ready ? _753 : reg_byte_counter;
    assign _747 = reg_byte_counter == _751;
    assign _748 = _747 ? _566 : _741;
    assign _749 = dis_ready ? _748 : reg_byte_counter;
    assign _741 = reg_byte_counter + _756;
    assign _743 = _739 ? _566 : _741;
    assign _744 = dis_ready ? _743 : reg_byte_counter;
    always @* begin
        case (_557)
        3'b000:
            _777 <= reg_byte_counter;
        3'b001:
            _777 <= _744;
        3'b011:
            _777 <= _749;
        3'b100:
            _777 <= _754;
        3'b101:
            _777 <= _759;
        3'b110:
            _777 <= _770;
        3'b111:
            _777 <= _775;
        default:
            _777 <= reg_byte_counter;
        endcase
    end
    assign _62 = _777;
    always @(posedge _100) begin
        if (_110)
            reg_byte_counter <= _566;
        else
            reg_byte_counter <= _62;
    end
    assign _739 = reg_byte_counter == _738;
    assign _780 = _739 ? _779 : _557;
    assign _778 = ~ reg_high_sent;
    assign dis_ready = _778;
    assign _781 = dis_ready ? _780 : _557;
    always @* begin
        case (_557)
        3'b000:
            _793 <= _557;
        3'b001:
            _793 <= _781;
        3'b010:
            _793 <= _782;
        3'b011:
            _793 <= _784;
        3'b100:
            _793 <= _786;
        3'b101:
            _793 <= _788;
        3'b110:
            _793 <= _790;
        3'b111:
            _793 <= _792;
        default:
            _793 <= _557;
        endcase
    end
    assign _64 = _793;
    always @(posedge _100) begin
        if (_110)
            _557 <= _619;
        else
            _557 <= _64;
    end
    assign _559 = _557 == _619;
    assign _560 = ~ _559;
    assign _795 = _560 ? _113 : reg_high_sent;
    assign _797 = reg_high_sent ? _115 : _795;
    assign _65 = _797;
    always @(posedge _100) begin
        if (_110)
            reg_high_sent <= _115;
        else
            reg_high_sent <= _65;
    end
    assign _802 = reg_high_sent ? _113 : _800;
    assign wire_nibble_valid = _802;
    assign vdd = 1'b1;
    assign _805 = 27'b101111101011110000011111111;
    assign _803 = 27'b000000000000000000000000000;
    assign _85 = clk100mhz;
    assign _807 = 27'b000000000000000000000000001;
    assign _808 = cnt + _807;
    assign _810 = _806 ? _803 : _808;
    assign _86 = _810;
    always @(posedge _85) begin
        if (_110)
            cnt <= _803;
        else
            cnt <= _86;
    end
    assign _806 = cnt == _805;
    assign _813 = _806 ? _113 : _115;
    assign _87 = _813;
    always @(posedge _85) begin
        if (_110)
            pulse <= _115;
        else
            pulse <= _87;
    end
    always @(posedge _100) begin
        if (_110)
            _957 <= _115;
        else
            _957 <= _821;
    end
    assign _953 = 32'b11011110101110110010000011100011;
    assign _890 = _889 ^ _639;
    assign _888 = _883[31:1];
    assign _889 = { _115,
                    _888 };
    assign _885 = dbg_byte_assembler_out[7:7];
    assign _882 = _881 ^ _639;
    assign _880 = _875[31:1];
    assign _881 = { _115,
                    _880 };
    assign _877 = dbg_byte_assembler_out[6:6];
    assign _874 = _873 ^ _639;
    assign _872 = _867[31:1];
    assign _873 = { _115,
                    _872 };
    assign _869 = dbg_byte_assembler_out[5:5];
    assign _866 = _865 ^ _639;
    assign _864 = _859[31:1];
    assign _865 = { _115,
                    _864 };
    assign _861 = dbg_byte_assembler_out[4:4];
    assign _858 = _857 ^ _639;
    assign _856 = _851[31:1];
    assign _857 = { _115,
                    _856 };
    assign _853 = dbg_byte_assembler_out[3:3];
    assign _850 = _849 ^ _639;
    assign _848 = _843[31:1];
    assign _849 = { _115,
                    _848 };
    assign _845 = dbg_byte_assembler_out[2:2];
    assign _842 = _841 ^ _639;
    assign _840 = _835[31:1];
    assign _841 = { _115,
                    _840 };
    assign _837 = dbg_byte_assembler_out[1:1];
    assign _834 = _832 ^ _639;
    assign _831 = _826[31:1];
    assign _832 = { _115,
                    _831 };
    assign _828 = dbg_byte_assembler_out[0:0];
    assign _827 = _826[0:0];
    assign _829 = _827 ^ _828;
    assign _835 = _829 ? _834 : _832;
    assign _836 = _835[0:0];
    assign _838 = _836 ^ _837;
    assign _843 = _838 ? _842 : _841;
    assign _844 = _843[0:0];
    assign _846 = _844 ^ _845;
    assign _851 = _846 ? _850 : _849;
    assign _852 = _851[0:0];
    assign _854 = _852 ^ _853;
    assign _859 = _854 ? _858 : _857;
    assign _860 = _859[0:0];
    assign _862 = _860 ^ _861;
    assign _867 = _862 ? _866 : _865;
    assign _868 = _867[0:0];
    assign _870 = _868 ^ _869;
    assign _875 = _870 ? _874 : _873;
    assign _876 = _875[0:0];
    assign _878 = _876 ^ _877;
    assign _883 = _878 ? _882 : _881;
    assign _884 = _883[0:0];
    assign _886 = _884 ^ _885;
    assign _891 = _886 ? _890 : _889;
    assign _892 = dbg_byte_assembler_valid ? _891 : _826;
    assign _820 = ~ _103;
    always @(posedge _100) begin
        if (_110)
            _819 <= _115;
        else
            _819 <= _103;
    end
    assign _821 = _819 & _820;
    assign _822 = _103 | _821;
    always @* begin
        case (_112)
        3'b001:
            _816 <= _113;
        default:
            _816 <= gnd;
        endcase
    end
    assign _88 = _816;
    assign _817 = ~ _88;
    assign _823 = _817 & _822;
    assign _824 = ~ _823;
    assign _825 = _110 | _824;
    assign _894 = _825 ? _699 : _892;
    assign _89 = _894;
    always @(posedge _100) begin
        _826 <= _89;
    end
    assign _954 = _826 == _953;
    always @(posedge _100) begin
        if (_110)
            _958 <= _115;
        else
            if (_957)
                _958 <= _954;
    end
    assign _946 = _103 ? _760 : _913;
    assign _947 = _96 ? _619 : _946;
    assign _944 = _912 ? _760 : _755;
    assign _945 = _896 ? _944 : _619;
    assign _942 = _905 ? _755 : _624;
    assign _943 = _896 ? _942 : _619;
    assign _913 = 3'b001;
    assign _914 = dbg_mac_byte_count + _913;
    assign _912 = dbg_mac_byte_count == _913;
    assign _916 = _912 ? _619 : _914;
    assign _917 = _896 ? _916 : dbg_mac_byte_count;
    assign _907 = dbg_mac_byte_count + _913;
    assign _905 = dbg_mac_byte_count == _760;
    assign _909 = _905 ? _619 : _907;
    assign _910 = _896 ? _909 : dbg_mac_byte_count;
    assign _900 = dbg_mac_byte_count + _913;
    assign _902 = _898 ? _619 : _900;
    assign _903 = _896 ? _902 : dbg_mac_byte_count;
    always @* begin
        case (_112)
        3'b010:
            _918 <= _903;
        3'b011:
            _918 <= _910;
        3'b100:
            _918 <= _917;
        default:
            _918 <= dbg_mac_byte_count;
        endcase
    end
    assign _919 = _106 ? _918 : dbg_mac_byte_count;
    assign _90 = _919;
    always @(posedge _100) begin
        if (_110)
            dbg_mac_byte_count <= _619;
        else
            dbg_mac_byte_count <= _90;
    end
    assign _898 = dbg_mac_byte_count == _760;
    assign _940 = _898 ? _624 : _779;
    assign _941 = _896 ? _940 : _619;
    assign _922 = _921 ? _144 : _93;
    assign _923 = _104 ? _922 : _144;
    assign _91 = _923;
    always @(posedge _100) begin
        if (_110)
            _144 <= _536;
        else
            _144 <= _91;
    end
    assign _93 = eth_rxd;
    assign _924 = _921 ? _93 : _142;
    assign _925 = _104 ? _924 : _142;
    assign _94 = _925;
    always @(posedge _100) begin
        if (_110)
            _142 <= _536;
        else
            _142 <= _94;
    end
    assign dbg_byte_assembler_out = { _142,
                                      _144 };
    always @* begin
        case (dbg_byte_assembler_out)
        8'b01010101:
            _938 <= _913;
        8'b11010101:
            _938 <= _779;
        default:
            _938 <= _112;
        endcase
    end
    assign _939 = _896 ? _938 : _619;
    assign _96 = eth_rxerr;
    assign _895 = ~ _96;
    assign _896 = _103 & _895;
    assign _935 = _896 ? _913 : _619;
    always @* begin
        case (_112)
        3'b000:
            _949 <= _935;
        3'b001:
            _949 <= _939;
        3'b010:
            _949 <= _941;
        3'b011:
            _949 <= _943;
        3'b100:
            _949 <= _945;
        3'b101:
            _949 <= _947;
        3'b110:
            _949 <= _627;
        default:
            _949 <= _112;
        endcase
    end
    assign _98 = btn;
    assign _110 = _98[0:0];
    assign _100 = eth_rx_clk;
    assign _928 = _921 ? _115 : _113;
    assign _929 = _104 ? _928 : _921;
    assign _101 = _929;
    always @(posedge _100) begin
        if (_110)
            _921 <= _115;
        else
            _921 <= _101;
    end
    assign _932 = _921 ? _113 : _115;
    assign _103 = eth_rx_dv;
    assign _104 = _103;
    assign _933 = _104 ? _932 : _115;
    assign _105 = _933;
    always @(posedge _100) begin
        if (_110)
            dbg_byte_assembler_valid <= _115;
        else
            dbg_byte_assembler_valid <= _105;
    end
    assign _106 = dbg_byte_assembler_valid;
    assign _950 = _106 ? _949 : _112;
    assign _107 = _950;
    always @(posedge _100) begin
        if (_110)
            _112 <= _619;
        else
            _112 <= _107;
    end
    always @* begin
        case (_112)
        3'b101:
            _952 <= _113;
        default:
            _952 <= gnd;
        endcase
    end
    assign _108 = _952;
    assign gnd = 1'b0;
    assign _959 = { gnd,
                    _108,
                    _958,
                    pulse };
    assign led = _959;
    assign led0_r = gnd;
    assign led0_g = _108;
    assign led0_b = gnd;
    assign led1_r = gnd;
    assign led1_g = gnd;
    assign led1_b = gnd;
    assign led2_r = gnd;
    assign led2_g = gnd;
    assign led2_b = gnd;
    assign led3_r = gnd;
    assign led3_g = gnd;
    assign led3_b = gnd;
    assign uart_rxd_out = vdd;
    assign eth_mdc = gnd;
    assign eth_rstn = vdd;
    assign eth_ref_clk = gnd;
    assign eth_tx_en = wire_nibble_valid;
    assign eth_txd = wire_output_nibble;
    assign ja_o = _428;
    assign ja_oe = _428;
    assign jb_o = _428;
    assign jb_oe = _428;
    assign jc_o = _428;
    assign jc_oe = _428;
    assign jd_o = _428;
    assign jd_oe = _428;
    assign ck_io_outer_o = _544;
    assign ck_io_outer_oe = _544;
    assign ck_io_inner_o = _135;
    assign ck_io_inner_oe = _135;
    assign ck_a_o = _540;
    assign ck_a_oe = _540;
    assign ck_mosi = gnd;
    assign ck_sck = gnd;
    assign ck_ss = vdd;
    assign ck_scl_o = vdd;
    assign ck_scl_oe = gnd;
    assign ck_sda_o = vdd;
    assign ck_sda_oe = gnd;
    assign scl_pup = gnd;
    assign sda_pup = gnd;
    assign ck_ioa_o = gnd;
    assign ck_ioa_oe = gnd;
    assign ck_rst_o = gnd;
    assign ck_rst_oe = gnd;
    assign eth_mdio_o = gnd;
    assign eth_mdio_oe = gnd;
    assign qspi_cs = vdd;
    assign qspi_dq_o = _536;
    assign qspi_dq_oe = _536;
    assign keep = _535;

endmodule
