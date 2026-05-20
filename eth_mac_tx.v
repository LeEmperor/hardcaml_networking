module eth_mac_tx (
    s_axis_tdata,
    s_axis_tvalid,
    tx_start,
    rx_data,
    rx_er,
    reset,
    clock,
    rx_dv,
    en,
    m_axis_tready,
    s_axis_tuser,
    m_axis_tdata,
    m_axis_tkeep,
    m_axis_tlast,
    m_axis_tvalid,
    m_axis_tuser,
    in_preamble,
    in_dst_mac,
    in_payload,
    frame_crc_ok,
    frame_done,
    tx_d,
    tx_en,
    s_axis_tready,
    keep
);

    input [7:0] s_axis_tdata;
    input s_axis_tvalid;
    input tx_start;
    input [3:0] rx_data;
    input rx_er;
    input reset;
    input clock;
    input rx_dv;
    input en;
    input m_axis_tready;
    input s_axis_tuser;
    output [7:0] m_axis_tdata;
    output m_axis_tkeep;
    output m_axis_tlast;
    output m_axis_tvalid;
    output m_axis_tuser;
    output in_preamble;
    output in_dst_mac;
    output in_payload;
    output frame_crc_ok;
    output frame_done;
    output [3:0] tx_d;
    output tx_en;
    output s_axis_tready;
    output keep;

    wire _502;
    wire _500;
    wire [2:0] state_vec;
    wire _498;
    wire _494;
    wire _492;
    wire _491;
    wire _493;
    wire _495;
    wire _496;
    wire _497;
    wire _499;
    wire _501;
    wire _503;
    wire _504;
    wire _505;
    wire _98;
    reg _95;
    wire _96;
    wire _97;
    reg dbg_fcs_present;
    wire dbg_datapath_fcs_present;
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
    wire _450;
    wire _448;
    wire _446;
    wire _444;
    wire _442;
    wire _440;
    wire _438;
    wire _436;
    wire _434;
    wire _432;
    wire _430;
    wire _428;
    wire _426;
    wire [15:0] _421;
    wire [23:0] _422;
    wire [31:0] dbg_crc_4_bytes;
    wire _424;
    wire _419;
    wire _417;
    wire _415;
    wire _413;
    wire _411;
    wire _409;
    wire _407;
    wire _405;
    wire _393;
    wire _391;
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
    wire [15:0] _109;
    wire [7:0] _114;
    wire [15:0] _120;
    wire [7:0] _111;
    wire [15:0] _113;
    wire [15:0] _121;
    wire _100;
    reg _103;
    wire _3;
    reg _105;
    wire _4;
    wire _108;
    wire [15:0] _122;
    wire [15:0] _5;
    reg [15:0] dbg_eth_type;
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
    wire [47:0] _130;
    wire [39:0] _135;
    wire [47:0] _136;
    wire [39:0] _132;
    wire [47:0] _134;
    wire [47:0] _137;
    reg _126;
    wire _6;
    reg dbg_dst_src_reg_en;
    wire _7;
    wire _129;
    wire [47:0] _138;
    wire [47:0] _8;
    reg [47:0] dbg_src_addr;
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
    wire _197;
    wire _195;
    wire _193;
    wire _191;
    wire _189;
    wire _187;
    wire _185;
    wire _183;
    wire _181;
    wire _179;
    wire _177;
    wire _175;
    wire _173;
    wire [47:0] _152;
    wire [39:0] _148;
    wire [47:0] _150;
    wire [47:0] _153;
    reg _142;
    wire _9;
    reg dbg_dst_mac_reg_en;
    wire _10;
    wire _145;
    wire [47:0] _154;
    wire [47:0] _11;
    reg [47:0] dbg_dst_addr;
    wire _171;
    wire _168;
    wire _166;
    wire _164;
    wire _162;
    wire _160;
    wire _158;
    wire _156;
    wire _155;
    wire _157;
    wire _159;
    wire _161;
    wire _163;
    wire _165;
    wire _167;
    wire _169;
    wire _170;
    wire _172;
    wire _174;
    wire _176;
    wire _178;
    wire _180;
    wire _182;
    wire _184;
    wire _186;
    wire _188;
    wire _190;
    wire _192;
    wire _194;
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
    wire _406;
    wire _408;
    wire _410;
    wire _412;
    wire _414;
    wire _416;
    wire _418;
    wire _420;
    wire _425;
    wire _427;
    wire _429;
    wire _431;
    wire _433;
    wire _435;
    wire _437;
    wire _439;
    wire _441;
    wire _443;
    wire _445;
    wire _447;
    wire _449;
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
    wire _488;
    wire _506;
    wire _507;
    wire _517;
    wire _519;
    wire wire_nibble_valid;
    wire [7:0] _595;
    wire [7:0] _596;
    wire [7:0] _16;
    reg [7:0] reg_byte_reg;
    wire [3:0] _784;
    wire [7:0] _684;
    wire [7:0] _683;
    wire [7:0] _682;
    wire [31:0] _677;
    wire [31:0] _674;
    wire [30:0] _672;
    wire [31:0] _673;
    wire _669;
    wire [31:0] _666;
    wire [30:0] _664;
    wire [31:0] _665;
    wire _661;
    wire [31:0] _658;
    wire [30:0] _656;
    wire [31:0] _657;
    wire _653;
    wire [31:0] _650;
    wire [30:0] _648;
    wire [31:0] _649;
    wire _645;
    wire [31:0] _642;
    wire [30:0] _640;
    wire [31:0] _641;
    wire _637;
    wire [31:0] _634;
    wire [30:0] _632;
    wire [31:0] _633;
    wire _629;
    wire [31:0] _626;
    wire [30:0] _624;
    wire [31:0] _625;
    wire _621;
    wire [31:0] _617;
    wire [31:0] _618;
    wire [30:0] _615;
    wire [31:0] _616;
    wire _612;
    wire _611;
    wire _613;
    wire [31:0] _619;
    wire _620;
    wire _622;
    wire [31:0] _627;
    wire _628;
    wire _630;
    wire [31:0] _635;
    wire _636;
    wire _638;
    wire [31:0] _643;
    wire _644;
    wire _646;
    wire [31:0] _651;
    wire _652;
    wire _654;
    wire [31:0] _659;
    wire _660;
    wire _662;
    wire [31:0] _667;
    wire _668;
    wire _670;
    wire [31:0] _675;
    wire [2:0] _605;
    wire _606;
    wire _607;
    wire [2:0] _602;
    wire _603;
    wire _604;
    wire _608;
    wire _609;
    wire [31:0] _676;
    wire [2:0] _597;
    wire _598;
    wire _599;
    wire _600;
    wire _601;
    wire [31:0] _678;
    wire [31:0] _17;
    reg [31:0] _610;
    wire [31:0] _680;
    wire [7:0] _681;
    wire [1:0] _679;
    reg [7:0] _685;
    wire [7:0] _18;
    wire _591;
    reg [7:0] data_before_collision;
    wire [7:0] _20;
    (* RAM_STYLE="registers" *)
    reg [7:0] _585[0:127];
    reg [6:0] _584;
    wire [7:0] ram_rbw_data;
    wire [6:0] _686;
    wire [6:0] _578;
    wire [6:0] READ_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [6:0] READ_ADDRESS;
    wire [6:0] _21;
    wire _577;
    wire [6:0] RA;
    wire [6:0] WRITE_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [6:0] WRITE_ADDRESS;
    wire [6:0] _22;
    wire _581;
    wire _573;
    wire _574;
    wire _571;
    wire [7:0] _568;
    wire _569;
    reg used_gt_one;
    wire _575;
    wire _576;
    wire _582;
    reg collision;
    wire [7:0] memory;
    wire _563;
    wire _561;
    reg used_is_one;
    wire _565;
    wire _566;
    wire _552;
    wire bypass_cond;
    wire [7:0] _589;
    reg [7:0] _592;
    wire [7:0] _593;
    wire [7:0] _543;
    reg [7:0] _544;
    wire [7:0] _535;
    reg [7:0] _541;
    wire [7:0] _533;
    wire [2:0] _527;
    reg [7:0] _534;
    wire [7:0] _524;
    wire [7:0] _523;
    reg [7:0] byte_mux;
    wire [3:0] _782;
    wire [3:0] _781;
    wire [3:0] _783;
    wire [2:0] _774;
    wire [2:0] _775;
    wire [2:0] _735;
    wire [2:0] _772;
    wire [2:0] _773;
    wire [2:0] _770;
    wire [2:0] _771;
    wire [2:0] _723;
    wire [2:0] _768;
    wire [2:0] _769;
    wire [2:0] _718;
    wire [2:0] _766;
    wire [2:0] _767;
    wire [2:0] _765;
    wire [2:0] _762;
    wire [10:0] _702;
    wire [10:0] _525;
    wire [10:0] _731;
    wire _732;
    wire [10:0] _733;
    wire [10:0] _734;
    wire [10:0] _726;
    wire _727;
    wire [10:0] _728;
    wire _724;
    wire _725;
    wire [10:0] _729;
    wire [10:0] _719;
    wire _720;
    wire [10:0] _721;
    wire [10:0] _722;
    wire [10:0] _714;
    wire _715;
    wire [10:0] _716;
    wire [10:0] _717;
    wire _710;
    wire [10:0] _711;
    wire [10:0] _712;
    wire [10:0] _705;
    wire [10:0] _706;
    wire [10:0] _707;
    wire [10:0] _699;
    wire [10:0] _700;
    reg [10:0] _736;
    wire [10:0] _23;
    reg [10:0] reg_byte_counter;
    wire _703;
    wire [2:0] _763;
    wire [2:0] _764;
    wire [2:0] _708;
    wire [7:0] _738;
    reg [7:0] USED_MINUS_1 = 8'b11111111;
    wire [7:0] _24;
    wire [7:0] _742;
    reg [7:0] USED_PLUS_1 = 8'b00000001;
    wire [7:0] _25;
    wire [7:0] _558;
    reg [7:0] USED;
    wire [7:0] _26;
    wire [7:0] _747;
    wire _748;
    reg full;
    wire _27;
    wire _28;
    wire _550;
    wire _547;
    wire _546;
    wire _548;
    wire _30;
    wire _549;
    wire WR_INT;
    wire _31;
    wire _555;
    wire _751;
    wire dis_ready;
    wire _753;
    wire _754;
    wire _33;
    wire _34;
    wire _553;
    wire _554;
    wire RD_INT;
    wire _557;
    wire [7:0] USED_NEXT;
    wire _756;
    wire _757;
    reg not_empty;
    wire _35;
    wire _545;
    wire _693;
    wire _694;
    wire _692;
    wire _695;
    wire fifo_empty;
    wire _697;
    wire [2:0] _760;
    wire _37;
    wire [2:0] _761;
    reg [2:0] _776;
    wire [2:0] _38;
    (* fsm_encoding="one_hot" *)
    reg [2:0] _511;
    wire _513;
    wire _514;
    wire _778;
    wire _780;
    wire _39;
    reg reg_high_sent;
    wire [3:0] _785;
    wire [3:0] wire_output_nibble;
    reg _793;
    reg _798;
    reg _802;
    wire _44;
    reg _804;
    wire _46;
    wire _872;
    wire _873;
    wire _875;
    wire _876;
    wire _874;
    wire _877;
    wire _878;
    wire _879;
    wire _880;
    wire _881;
    wire _870;
    reg [10:0] data_before_collision_1;
    reg [7:0] dbg_stage1_val;
    reg [7:0] dbg_stage2;
    reg [7:0] dbg_stage3;
    reg [7:0] dbg_stage4;
    reg _884;
    wire _53;
    wire _54;
    wire [7:0] dbg_payload_out_delayed;
    reg [7:0] _862;
    wire vdd;
    wire [31:0] _795;
    wire [31:0] _957;
    wire [30:0] _955;
    wire [31:0] _956;
    wire _952;
    wire [31:0] _949;
    wire [30:0] _947;
    wire [31:0] _948;
    wire _944;
    wire [31:0] _941;
    wire [30:0] _939;
    wire [31:0] _940;
    wire _936;
    wire [31:0] _933;
    wire [30:0] _931;
    wire [31:0] _932;
    wire _928;
    wire [31:0] _925;
    wire [30:0] _923;
    wire [31:0] _924;
    wire _920;
    wire [31:0] _917;
    wire [30:0] _915;
    wire [31:0] _916;
    wire _912;
    wire [31:0] _909;
    wire [30:0] _907;
    wire [31:0] _908;
    wire _904;
    wire [31:0] _901;
    wire [30:0] _898;
    wire [31:0] _899;
    wire _895;
    wire _894;
    wire _896;
    wire [31:0] _902;
    wire _903;
    wire _905;
    wire [31:0] _910;
    wire _911;
    wire _913;
    wire [31:0] _918;
    wire _919;
    wire _921;
    wire [31:0] _926;
    wire _927;
    wire _929;
    wire [31:0] _934;
    wire _935;
    wire _937;
    wire [31:0] _942;
    wire _943;
    wire _945;
    wire [31:0] _950;
    wire _951;
    wire _953;
    wire [31:0] _958;
    wire [31:0] _959;
    wire _889;
    reg _887;
    wire _55;
    wire _888;
    wire _890;
    wire _891;
    wire _892;
    wire _893;
    wire [31:0] _961;
    wire [31:0] _56;
    reg [31:0] _794;
    wire _796;
    wire _858;
    wire gnd;
    wire _788;
    reg _787;
    wire _789;
    reg _791;
    wire _857;
    wire _859;
    wire [10:0] _863;
    (* RAM_STYLE="registers" *)
    reg [10:0] _864[0:127];
    reg [6:0] _856;
    wire [10:0] ram_rbw_data_1;
    wire [6:0] READ_ADDRESS_NEXT_1;
    (* extract_reset="FALSE" *)
    reg [6:0] READ_ADDRESS_1;
    wire [6:0] _57;
    wire _849;
    wire [6:0] RA_1;
    wire [6:0] WRITE_ADDRESS_NEXT_1;
    (* extract_reset="FALSE" *)
    reg [6:0] WRITE_ADDRESS_1;
    wire [6:0] _58;
    wire _853;
    wire _845;
    wire _846;
    wire _843;
    wire _841;
    reg used_gt_one_1;
    wire _847;
    wire _848;
    wire _854;
    reg collision_1;
    wire [10:0] memory_1;
    wire _835;
    wire _833;
    reg used_is_one_1;
    wire _837;
    wire _838;
    wire _824;
    wire bypass_cond_1;
    wire [10:0] _868;
    reg [10:0] _871;
    wire [7:0] _1048;
    wire [7:0] _969;
    reg [7:0] USED_MINUS_1_1 = 8'b11111111;
    wire [7:0] _59;
    wire [7:0] _973;
    reg [7:0] USED_PLUS_1_1 = 8'b00000001;
    wire [7:0] _60;
    wire [7:0] _830;
    reg [7:0] USED_1;
    wire [7:0] _61;
    wire _979;
    reg full_1;
    wire _62;
    wire _63;
    wire _822;
    wire _819;
    wire _818;
    wire _820;
    reg valid_stage1;
    reg valid_stage2;
    reg valid_stage3;
    reg dbg_delayed_valid_raw;
    wire valid_stage4;
    wire [2:0] _1035;
    wire [2:0] _1036;
    wire [2:0] _1033;
    wire [2:0] _1034;
    wire [2:0] _1031;
    wire [2:0] _1032;
    wire [2:0] _1002;
    wire _1000;
    wire [2:0] _1004;
    wire [2:0] _1005;
    wire [2:0] _995;
    wire _993;
    wire [2:0] _997;
    wire [2:0] _998;
    wire [2:0] _988;
    wire [2:0] _990;
    wire [2:0] _991;
    reg [2:0] _1006;
    wire [2:0] _1007;
    wire [2:0] _64;
    reg [2:0] dbg_mac_byte_count;
    wire _986;
    wire [2:0] _1029;
    wire [2:0] _1030;
    wire [3:0] _1010;
    wire [3:0] _1011;
    wire [3:0] _65;
    reg [3:0] _118;
    wire [3:0] _67;
    wire [3:0] _1012;
    wire [3:0] _1013;
    wire [3:0] _68;
    reg [3:0] _116;
    wire [7:0] dbg_byte_assembler_out;
    reg [2:0] _1027;
    wire [2:0] _1028;
    wire _70;
    wire _982;
    wire _983;
    wire _984;
    wire [2:0] _1024;
    reg [2:0] _1038;
    wire _72;
    wire _74;
    wire _1016;
    wire _1017;
    wire _75;
    reg _1009;
    wire _1021;
    wire _77;
    wire _79;
    wire _1018;
    wire _80;
    wire _1022;
    wire _81;
    reg dbg_byte_assembler_valid;
    wire _82;
    wire [2:0] _1039;
    wire [2:0] _83;
    (* fsm_encoding="one_hot" *)
    reg [2:0] _93;
    reg _1042;
    wire dbg_emit_payload_controller;
    wire _85;
    wire dbg_payload_out_valid_delayed;
    wire _815;
    reg _817;
    wire _821;
    wire WR_INT_1;
    wire _86;
    wire _827;
    wire _88;
    wire _89;
    wire _825;
    wire _826;
    wire RD_INT_1;
    wire _829;
    wire [7:0] USED_NEXT_1;
    wire _1044;
    wire _1045;
    reg not_empty_1;
    wire _90;
    wire _805;
    wire [7:0] _1049;
    assign _502 = state_vec[2:2];
    assign _500 = state_vec[1:1];
    assign state_vec = _93;
    assign _498 = state_vec[0:0];
    assign _494 = dbg_mac_byte_count[2:2];
    assign _492 = dbg_mac_byte_count[1:1];
    assign _491 = dbg_mac_byte_count[0:0];
    assign _493 = _491 | _492;
    assign _495 = _493 | _494;
    assign _496 = _495 | dbg_dst_mac_reg_en;
    assign _497 = _496 | dbg_dst_src_reg_en;
    assign _499 = _497 | _498;
    assign _501 = _499 | _500;
    assign _503 = _501 | _502;
    assign _504 = _503 | dbg_emit_payload_controller;
    assign _505 = _504 | dbg_fcs_present;
    assign _98 = 1'b0;
    always @(posedge _74) begin
        if (_72)
            _95 <= _98;
        else
            _95 <= _77;
    end
    assign _96 = ~ _95;
    assign _97 = _96 & _77;
    always @(posedge _74) begin
        if (_72)
            dbg_fcs_present <= _98;
        else
            dbg_fcs_present <= _97;
    end
    assign dbg_datapath_fcs_present = dbg_fcs_present;
    assign _486 = dbg_crc_4_bytes[31:31];
    assign _484 = dbg_crc_4_bytes[30:30];
    assign _482 = dbg_crc_4_bytes[29:29];
    assign _480 = dbg_crc_4_bytes[28:28];
    assign _478 = dbg_crc_4_bytes[27:27];
    assign _476 = dbg_crc_4_bytes[26:26];
    assign _474 = dbg_crc_4_bytes[25:25];
    assign _472 = dbg_crc_4_bytes[24:24];
    assign _470 = dbg_crc_4_bytes[23:23];
    assign _468 = dbg_crc_4_bytes[22:22];
    assign _466 = dbg_crc_4_bytes[21:21];
    assign _464 = dbg_crc_4_bytes[20:20];
    assign _462 = dbg_crc_4_bytes[19:19];
    assign _460 = dbg_crc_4_bytes[18:18];
    assign _458 = dbg_crc_4_bytes[17:17];
    assign _456 = dbg_crc_4_bytes[16:16];
    assign _454 = dbg_crc_4_bytes[15:15];
    assign _452 = dbg_crc_4_bytes[14:14];
    assign _450 = dbg_crc_4_bytes[13:13];
    assign _448 = dbg_crc_4_bytes[12:12];
    assign _446 = dbg_crc_4_bytes[11:11];
    assign _444 = dbg_crc_4_bytes[10:10];
    assign _442 = dbg_crc_4_bytes[9:9];
    assign _440 = dbg_crc_4_bytes[8:8];
    assign _438 = dbg_crc_4_bytes[7:7];
    assign _436 = dbg_crc_4_bytes[6:6];
    assign _434 = dbg_crc_4_bytes[5:5];
    assign _432 = dbg_crc_4_bytes[4:4];
    assign _430 = dbg_crc_4_bytes[3:3];
    assign _428 = dbg_crc_4_bytes[2:2];
    assign _426 = dbg_crc_4_bytes[1:1];
    assign _421 = { dbg_stage3,
                    dbg_stage4 };
    assign _422 = { dbg_stage2,
                    _421 };
    assign dbg_crc_4_bytes = { dbg_stage1_val,
                               _422 };
    assign _424 = dbg_crc_4_bytes[0:0];
    assign _419 = dbg_payload_out_delayed[7:7];
    assign _417 = dbg_payload_out_delayed[6:6];
    assign _415 = dbg_payload_out_delayed[5:5];
    assign _413 = dbg_payload_out_delayed[4:4];
    assign _411 = dbg_payload_out_delayed[3:3];
    assign _409 = dbg_payload_out_delayed[2:2];
    assign _407 = dbg_payload_out_delayed[1:1];
    assign _405 = dbg_payload_out_delayed[0:0];
    assign _393 = dbg_eth_type[15:15];
    assign _391 = dbg_eth_type[14:14];
    assign _389 = dbg_eth_type[13:13];
    assign _387 = dbg_eth_type[12:12];
    assign _385 = dbg_eth_type[11:11];
    assign _383 = dbg_eth_type[10:10];
    assign _381 = dbg_eth_type[9:9];
    assign _379 = dbg_eth_type[8:8];
    assign _377 = dbg_eth_type[7:7];
    assign _375 = dbg_eth_type[6:6];
    assign _373 = dbg_eth_type[5:5];
    assign _371 = dbg_eth_type[4:4];
    assign _369 = dbg_eth_type[3:3];
    assign _367 = dbg_eth_type[2:2];
    assign _365 = dbg_eth_type[1:1];
    assign _109 = 16'b0000000000000000;
    assign _114 = 8'b00000000;
    assign _120 = { _114,
                    dbg_byte_assembler_out };
    assign _111 = dbg_eth_type[7:0];
    assign _113 = { _111,
                    _114 };
    assign _121 = _113 | _120;
    assign _100 = 1'b1;
    always @* begin
        case (_93)
        3'b100:
            _103 <= _100;
        default:
            _103 <= _98;
        endcase
    end
    assign _3 = _103;
    always @(posedge _74) begin
        if (_72)
            _105 <= _98;
        else
            _105 <= _3;
    end
    assign _4 = _105;
    assign _108 = _4 & dbg_byte_assembler_valid;
    assign _122 = _108 ? _121 : dbg_eth_type;
    assign _5 = _122;
    always @(posedge _74) begin
        if (_72)
            dbg_eth_type <= _109;
        else
            dbg_eth_type <= _5;
    end
    assign _363 = dbg_eth_type[0:0];
    assign _361 = dbg_src_addr[47:47];
    assign _359 = dbg_src_addr[46:46];
    assign _357 = dbg_src_addr[45:45];
    assign _355 = dbg_src_addr[44:44];
    assign _353 = dbg_src_addr[43:43];
    assign _351 = dbg_src_addr[42:42];
    assign _349 = dbg_src_addr[41:41];
    assign _347 = dbg_src_addr[40:40];
    assign _345 = dbg_src_addr[39:39];
    assign _343 = dbg_src_addr[38:38];
    assign _341 = dbg_src_addr[37:37];
    assign _339 = dbg_src_addr[36:36];
    assign _337 = dbg_src_addr[35:35];
    assign _335 = dbg_src_addr[34:34];
    assign _333 = dbg_src_addr[33:33];
    assign _331 = dbg_src_addr[32:32];
    assign _329 = dbg_src_addr[31:31];
    assign _327 = dbg_src_addr[30:30];
    assign _325 = dbg_src_addr[29:29];
    assign _323 = dbg_src_addr[28:28];
    assign _321 = dbg_src_addr[27:27];
    assign _319 = dbg_src_addr[26:26];
    assign _317 = dbg_src_addr[25:25];
    assign _315 = dbg_src_addr[24:24];
    assign _313 = dbg_src_addr[23:23];
    assign _311 = dbg_src_addr[22:22];
    assign _309 = dbg_src_addr[21:21];
    assign _307 = dbg_src_addr[20:20];
    assign _305 = dbg_src_addr[19:19];
    assign _303 = dbg_src_addr[18:18];
    assign _301 = dbg_src_addr[17:17];
    assign _299 = dbg_src_addr[16:16];
    assign _297 = dbg_src_addr[15:15];
    assign _295 = dbg_src_addr[14:14];
    assign _293 = dbg_src_addr[13:13];
    assign _291 = dbg_src_addr[12:12];
    assign _289 = dbg_src_addr[11:11];
    assign _287 = dbg_src_addr[10:10];
    assign _285 = dbg_src_addr[9:9];
    assign _283 = dbg_src_addr[8:8];
    assign _281 = dbg_src_addr[7:7];
    assign _279 = dbg_src_addr[6:6];
    assign _277 = dbg_src_addr[5:5];
    assign _275 = dbg_src_addr[4:4];
    assign _273 = dbg_src_addr[3:3];
    assign _271 = dbg_src_addr[2:2];
    assign _269 = dbg_src_addr[1:1];
    assign _130 = 48'b000000000000000000000000000000000000000000000000;
    assign _135 = 40'b0000000000000000000000000000000000000000;
    assign _136 = { _135,
                    dbg_byte_assembler_out };
    assign _132 = dbg_src_addr[39:0];
    assign _134 = { _132,
                    _114 };
    assign _137 = _134 | _136;
    always @* begin
        case (_93)
        3'b011:
            _126 <= _100;
        default:
            _126 <= _98;
        endcase
    end
    assign _6 = _126;
    always @(posedge _74) begin
        if (_72)
            dbg_dst_src_reg_en <= _98;
        else
            dbg_dst_src_reg_en <= _6;
    end
    assign _7 = dbg_dst_src_reg_en;
    assign _129 = _7 & dbg_byte_assembler_valid;
    assign _138 = _129 ? _137 : dbg_src_addr;
    assign _8 = _138;
    always @(posedge _74) begin
        if (_72)
            dbg_src_addr <= _130;
        else
            dbg_src_addr <= _8;
    end
    assign _267 = dbg_src_addr[0:0];
    assign _265 = dbg_dst_addr[47:47];
    assign _263 = dbg_dst_addr[46:46];
    assign _261 = dbg_dst_addr[45:45];
    assign _259 = dbg_dst_addr[44:44];
    assign _257 = dbg_dst_addr[43:43];
    assign _255 = dbg_dst_addr[42:42];
    assign _253 = dbg_dst_addr[41:41];
    assign _251 = dbg_dst_addr[40:40];
    assign _249 = dbg_dst_addr[39:39];
    assign _247 = dbg_dst_addr[38:38];
    assign _245 = dbg_dst_addr[37:37];
    assign _243 = dbg_dst_addr[36:36];
    assign _241 = dbg_dst_addr[35:35];
    assign _239 = dbg_dst_addr[34:34];
    assign _237 = dbg_dst_addr[33:33];
    assign _235 = dbg_dst_addr[32:32];
    assign _233 = dbg_dst_addr[31:31];
    assign _231 = dbg_dst_addr[30:30];
    assign _229 = dbg_dst_addr[29:29];
    assign _227 = dbg_dst_addr[28:28];
    assign _225 = dbg_dst_addr[27:27];
    assign _223 = dbg_dst_addr[26:26];
    assign _221 = dbg_dst_addr[25:25];
    assign _219 = dbg_dst_addr[24:24];
    assign _217 = dbg_dst_addr[23:23];
    assign _215 = dbg_dst_addr[22:22];
    assign _213 = dbg_dst_addr[21:21];
    assign _211 = dbg_dst_addr[20:20];
    assign _209 = dbg_dst_addr[19:19];
    assign _207 = dbg_dst_addr[18:18];
    assign _205 = dbg_dst_addr[17:17];
    assign _203 = dbg_dst_addr[16:16];
    assign _201 = dbg_dst_addr[15:15];
    assign _199 = dbg_dst_addr[14:14];
    assign _197 = dbg_dst_addr[13:13];
    assign _195 = dbg_dst_addr[12:12];
    assign _193 = dbg_dst_addr[11:11];
    assign _191 = dbg_dst_addr[10:10];
    assign _189 = dbg_dst_addr[9:9];
    assign _187 = dbg_dst_addr[8:8];
    assign _185 = dbg_dst_addr[7:7];
    assign _183 = dbg_dst_addr[6:6];
    assign _181 = dbg_dst_addr[5:5];
    assign _179 = dbg_dst_addr[4:4];
    assign _177 = dbg_dst_addr[3:3];
    assign _175 = dbg_dst_addr[2:2];
    assign _173 = dbg_dst_addr[1:1];
    assign _152 = { _135,
                    dbg_byte_assembler_out };
    assign _148 = dbg_dst_addr[39:0];
    assign _150 = { _148,
                    _114 };
    assign _153 = _150 | _152;
    always @* begin
        case (_93)
        3'b010:
            _142 <= _100;
        default:
            _142 <= _98;
        endcase
    end
    assign _9 = _142;
    always @(posedge _74) begin
        if (_72)
            dbg_dst_mac_reg_en <= _98;
        else
            dbg_dst_mac_reg_en <= _9;
    end
    assign _10 = dbg_dst_mac_reg_en;
    assign _145 = _10 & dbg_byte_assembler_valid;
    assign _154 = _145 ? _153 : dbg_dst_addr;
    assign _11 = _154;
    always @(posedge _74) begin
        if (_72)
            dbg_dst_addr <= _130;
        else
            dbg_dst_addr <= _11;
    end
    assign _171 = dbg_dst_addr[0:0];
    assign _168 = dbg_byte_assembler_out[7:7];
    assign _166 = dbg_byte_assembler_out[6:6];
    assign _164 = dbg_byte_assembler_out[5:5];
    assign _162 = dbg_byte_assembler_out[4:4];
    assign _160 = dbg_byte_assembler_out[3:3];
    assign _158 = dbg_byte_assembler_out[2:2];
    assign _156 = dbg_byte_assembler_out[1:1];
    assign _155 = dbg_byte_assembler_out[0:0];
    assign _157 = _155 | _156;
    assign _159 = _157 | _158;
    assign _161 = _159 | _160;
    assign _163 = _161 | _162;
    assign _165 = _163 | _164;
    assign _167 = _165 | _166;
    assign _169 = _167 | _168;
    assign _170 = _169 | dbg_byte_assembler_valid;
    assign _172 = _170 | _171;
    assign _174 = _172 | _173;
    assign _176 = _174 | _175;
    assign _178 = _176 | _177;
    assign _180 = _178 | _179;
    assign _182 = _180 | _181;
    assign _184 = _182 | _183;
    assign _186 = _184 | _185;
    assign _188 = _186 | _187;
    assign _190 = _188 | _189;
    assign _192 = _190 | _191;
    assign _194 = _192 | _193;
    assign _196 = _194 | _195;
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
    assign _406 = _394 | _405;
    assign _408 = _406 | _407;
    assign _410 = _408 | _409;
    assign _412 = _410 | _411;
    assign _414 = _412 | _413;
    assign _416 = _414 | _415;
    assign _418 = _416 | _417;
    assign _420 = _418 | _419;
    assign _425 = _420 | _424;
    assign _427 = _425 | _426;
    assign _429 = _427 | _428;
    assign _431 = _429 | _430;
    assign _433 = _431 | _432;
    assign _435 = _433 | _434;
    assign _437 = _435 | _436;
    assign _439 = _437 | _438;
    assign _441 = _439 | _440;
    assign _443 = _441 | _442;
    assign _445 = _443 | _444;
    assign _447 = _445 | _446;
    assign _449 = _447 | _448;
    assign _451 = _449 | _450;
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
    assign _488 = _487 | dbg_datapath_fcs_present;
    assign _506 = _488 | _505;
    assign _507 = ~ _27;
    assign _517 = _514 ? _100 : _98;
    assign _519 = reg_high_sent ? _100 : _517;
    assign wire_nibble_valid = _519;
    assign _595 = _514 ? byte_mux : reg_byte_reg;
    assign _596 = reg_high_sent ? reg_byte_reg : _595;
    assign _16 = _596;
    always @(posedge _74) begin
        if (_72)
            reg_byte_reg <= _114;
        else
            reg_byte_reg <= _16;
    end
    assign _784 = reg_byte_reg[7:4];
    assign _684 = _680[31:24];
    assign _683 = _680[23:16];
    assign _682 = _680[15:8];
    assign _677 = 32'b11111111111111111111111111111111;
    assign _674 = _673 ^ _617;
    assign _672 = _667[31:1];
    assign _673 = { _98,
                    _672 };
    assign _669 = byte_mux[7:7];
    assign _666 = _665 ^ _617;
    assign _664 = _659[31:1];
    assign _665 = { _98,
                    _664 };
    assign _661 = byte_mux[6:6];
    assign _658 = _657 ^ _617;
    assign _656 = _651[31:1];
    assign _657 = { _98,
                    _656 };
    assign _653 = byte_mux[5:5];
    assign _650 = _649 ^ _617;
    assign _648 = _643[31:1];
    assign _649 = { _98,
                    _648 };
    assign _645 = byte_mux[4:4];
    assign _642 = _641 ^ _617;
    assign _640 = _635[31:1];
    assign _641 = { _98,
                    _640 };
    assign _637 = byte_mux[3:3];
    assign _634 = _633 ^ _617;
    assign _632 = _627[31:1];
    assign _633 = { _98,
                    _632 };
    assign _629 = byte_mux[2:2];
    assign _626 = _625 ^ _617;
    assign _624 = _619[31:1];
    assign _625 = { _98,
                    _624 };
    assign _621 = byte_mux[1:1];
    assign _617 = 32'b11101101101110001000001100100000;
    assign _618 = _616 ^ _617;
    assign _615 = _610[31:1];
    assign _616 = { _98,
                    _615 };
    assign _612 = byte_mux[0:0];
    assign _611 = _610[0:0];
    assign _613 = _611 ^ _612;
    assign _619 = _613 ? _618 : _616;
    assign _620 = _619[0:0];
    assign _622 = _620 ^ _621;
    assign _627 = _622 ? _626 : _625;
    assign _628 = _627[0:0];
    assign _630 = _628 ^ _629;
    assign _635 = _630 ? _634 : _633;
    assign _636 = _635[0:0];
    assign _638 = _636 ^ _637;
    assign _643 = _638 ? _642 : _641;
    assign _644 = _643[0:0];
    assign _646 = _644 ^ _645;
    assign _651 = _646 ? _650 : _649;
    assign _652 = _651[0:0];
    assign _654 = _652 ^ _653;
    assign _659 = _654 ? _658 : _657;
    assign _660 = _659[0:0];
    assign _662 = _660 ^ _661;
    assign _667 = _662 ? _666 : _665;
    assign _668 = _667[0:0];
    assign _670 = _668 ^ _669;
    assign _675 = _670 ? _674 : _673;
    assign _605 = 3'b110;
    assign _606 = _605 < _511;
    assign _607 = ~ _606;
    assign _602 = 3'b011;
    assign _603 = _511 < _602;
    assign _604 = ~ _603;
    assign _608 = _604 & _607;
    assign _609 = dis_ready & _608;
    assign _676 = _609 ? _675 : _610;
    assign _597 = 3'b000;
    assign _598 = _511 == _597;
    assign _599 = ~ _598;
    assign _600 = ~ _599;
    assign _601 = _72 | _600;
    assign _678 = _601 ? _677 : _676;
    assign _17 = _678;
    always @(posedge _74) begin
        _610 <= _17;
    end
    assign _680 = ~ _610;
    assign _681 = _680[7:0];
    assign _679 = _527[1:0];
    always @* begin
        case (_679)
        0:
            _685 <= _681;
        1:
            _685 <= _682;
        2:
            _685 <= _683;
        default:
            _685 <= _684;
        endcase
    end
    assign _18 = _685;
    assign _591 = bypass_cond | RD_INT;
    always @(posedge _74) begin
        data_before_collision <= _20;
    end
    assign _20 = s_axis_tdata;
    always @(posedge _74) begin
        if (_576)
            _585[_22] <= _20;
    end
    always @(posedge _74) begin
        _584 <= RA;
    end
    assign ram_rbw_data = _585[_584];
    assign _686 = 7'b0000000;
    assign _578 = 7'b0000001;
    assign READ_ADDRESS_NEXT = _21 + _578;
    always @(posedge _74) begin
        if (_72)
            READ_ADDRESS <= _686;
        else
            if (_577)
                READ_ADDRESS <= READ_ADDRESS_NEXT;
    end
    assign _21 = READ_ADDRESS;
    assign _577 = RD_INT & used_gt_one;
    assign RA = _577 ? READ_ADDRESS_NEXT : _21;
    assign WRITE_ADDRESS_NEXT = _22 + _578;
    always @(posedge _74) begin
        if (_72)
            WRITE_ADDRESS <= _686;
        else
            if (_576)
                WRITE_ADDRESS <= WRITE_ADDRESS_NEXT;
    end
    assign _22 = WRITE_ADDRESS;
    assign _581 = _22 == RA;
    assign _573 = ~ RD_INT;
    assign _574 = used_is_one & _573;
    assign _571 = RD_INT ^ WR_INT;
    assign _568 = 8'b00000001;
    assign _569 = _568 < USED_NEXT;
    always @(posedge _74) begin
        if (_72)
            used_gt_one <= _98;
        else
            if (_571)
                used_gt_one <= _569;
    end
    assign _575 = used_gt_one | _574;
    assign _576 = WR_INT & _575;
    assign _582 = _576 & _581;
    always @(posedge _74) begin
        collision <= _582;
    end
    assign memory = collision ? data_before_collision : ram_rbw_data;
    assign _563 = RD_INT ^ WR_INT;
    assign _561 = USED_NEXT == _568;
    always @(posedge _74) begin
        if (_72)
            used_is_one <= _98;
        else
            if (_563)
                used_is_one <= _561;
    end
    assign _565 = used_is_one & WR_INT;
    assign _566 = _565 & RD_INT;
    assign _552 = _545 & WR_INT;
    assign bypass_cond = _552 | _566;
    assign _589 = bypass_cond ? _20 : memory;
    always @(posedge _74) begin
        if (_72)
            _592 <= _114;
        else
            if (_591)
                _592 <= _589;
    end
    assign _593 = _545 ? _20 : _592;
    assign _543 = 8'b10011001;
    always @* begin
        case (_527)
        0:
            _544 <= _543;
        default:
            _544 <= _543;
        endcase
    end
    assign _535 = 8'b00000010;
    always @* begin
        case (_527)
        0:
            _541 <= _535;
        1:
            _541 <= _114;
        2:
            _541 <= _114;
        3:
            _541 <= _114;
        4:
            _541 <= _114;
        default:
            _541 <= _568;
        endcase
    end
    assign _533 = 8'b11111111;
    assign _527 = reg_byte_counter[2:0];
    always @* begin
        case (_527)
        0:
            _534 <= _533;
        1:
            _534 <= _533;
        2:
            _534 <= _533;
        3:
            _534 <= _533;
        4:
            _534 <= _533;
        default:
            _534 <= _533;
        endcase
    end
    assign _524 = 8'b11010101;
    assign _523 = 8'b01010101;
    always @* begin
        case (_511)
        0:
            byte_mux <= _114;
        1:
            byte_mux <= _523;
        2:
            byte_mux <= _524;
        3:
            byte_mux <= _534;
        4:
            byte_mux <= _541;
        5:
            byte_mux <= _544;
        6:
            byte_mux <= _593;
        default:
            byte_mux <= _18;
        endcase
    end
    assign _782 = byte_mux[3:0];
    assign _781 = 4'b0000;
    assign _783 = _514 ? _782 : _781;
    assign _774 = _732 ? _597 : _511;
    assign _775 = dis_ready ? _774 : _511;
    assign _735 = 3'b111;
    assign _772 = _727 ? _735 : _511;
    assign _773 = _725 ? _772 : _511;
    assign _770 = _720 ? _605 : _511;
    assign _771 = dis_ready ? _770 : _511;
    assign _723 = 3'b101;
    assign _768 = _715 ? _723 : _511;
    assign _769 = dis_ready ? _768 : _511;
    assign _718 = 3'b100;
    assign _766 = _710 ? _718 : _511;
    assign _767 = dis_ready ? _766 : _511;
    assign _765 = dis_ready ? _602 : _511;
    assign _762 = 3'b010;
    assign _702 = 11'b00000000110;
    assign _525 = 11'b00000000000;
    assign _731 = 11'b00000000011;
    assign _732 = reg_byte_counter == _731;
    assign _733 = _732 ? _525 : _705;
    assign _734 = dis_ready ? _733 : reg_byte_counter;
    assign _726 = 11'b00000101101;
    assign _727 = reg_byte_counter == _726;
    assign _728 = _727 ? _525 : _705;
    assign _724 = ~ fifo_empty;
    assign _725 = _724 & dis_ready;
    assign _729 = _725 ? _728 : reg_byte_counter;
    assign _719 = 11'b00000000001;
    assign _720 = reg_byte_counter == _719;
    assign _721 = _720 ? _525 : _705;
    assign _722 = dis_ready ? _721 : reg_byte_counter;
    assign _714 = 11'b00000000101;
    assign _715 = reg_byte_counter == _714;
    assign _716 = _715 ? _525 : _705;
    assign _717 = dis_ready ? _716 : reg_byte_counter;
    assign _710 = reg_byte_counter == _714;
    assign _711 = _710 ? _525 : _705;
    assign _712 = dis_ready ? _711 : reg_byte_counter;
    assign _705 = reg_byte_counter + _719;
    assign _706 = _703 ? _525 : _705;
    assign _707 = dis_ready ? _706 : reg_byte_counter;
    assign _699 = _697 ? _525 : reg_byte_counter;
    assign _700 = _37 ? _699 : reg_byte_counter;
    always @* begin
        case (_511)
        3'b000:
            _736 <= _700;
        3'b001:
            _736 <= _707;
        3'b011:
            _736 <= _712;
        3'b100:
            _736 <= _717;
        3'b101:
            _736 <= _722;
        3'b110:
            _736 <= _729;
        3'b111:
            _736 <= _734;
        default:
            _736 <= reg_byte_counter;
        endcase
    end
    assign _23 = _736;
    always @(posedge _74) begin
        if (_72)
            reg_byte_counter <= _525;
        else
            reg_byte_counter <= _23;
    end
    assign _703 = reg_byte_counter == _702;
    assign _763 = _703 ? _762 : _511;
    assign _764 = dis_ready ? _763 : _511;
    assign _708 = 3'b001;
    assign _738 = USED_NEXT - _568;
    always @(posedge _74) begin
        if (_72)
            USED_MINUS_1 <= _533;
        else
            if (_557)
                USED_MINUS_1 <= _738;
    end
    assign _24 = USED_MINUS_1;
    assign _742 = USED_NEXT + _568;
    always @(posedge _74) begin
        if (_72)
            USED_PLUS_1 <= _568;
        else
            if (_557)
                USED_PLUS_1 <= _742;
    end
    assign _25 = USED_PLUS_1;
    assign _558 = RD_INT ? _24 : _25;
    always @(posedge _74) begin
        if (_72)
            USED <= _114;
        else
            if (_557)
                USED <= USED_NEXT;
    end
    assign _26 = USED;
    assign _747 = 8'b10000001;
    assign _748 = USED_NEXT == _747;
    always @(posedge _74) begin
        if (_72)
            full <= _98;
        else
            if (_557)
                full <= _748;
    end
    assign _27 = full;
    assign _28 = _27;
    assign _550 = ~ _28;
    assign _547 = ~ _33;
    assign _546 = ~ _34;
    assign _548 = _546 | _547;
    assign _30 = s_axis_tvalid;
    assign _549 = _30 & _548;
    assign WR_INT = _549 & _550;
    assign _31 = _545;
    assign _555 = ~ _31;
    assign _751 = ~ reg_high_sent;
    assign dis_ready = _751;
    assign _753 = _511 == _605;
    assign _754 = _753 & dis_ready;
    assign _33 = _754;
    assign _34 = _545;
    assign _553 = ~ _34;
    assign _554 = _553 & _33;
    assign RD_INT = _554 & _555;
    assign _557 = RD_INT ^ WR_INT;
    assign USED_NEXT = _557 ? _558 : _26;
    assign _756 = USED_NEXT == _114;
    assign _757 = ~ _756;
    always @(posedge _74) begin
        if (_72)
            not_empty <= _98;
        else
            if (_557)
                not_empty <= _757;
    end
    assign _35 = not_empty;
    assign _545 = ~ _35;
    assign _693 = ~ _545;
    assign _694 = _693 | _30;
    assign _692 = ~ _72;
    assign _695 = _692 & _694;
    assign fifo_empty = ~ _695;
    assign _697 = ~ fifo_empty;
    assign _760 = _697 ? _708 : _511;
    assign _37 = tx_start;
    assign _761 = _37 ? _760 : _511;
    always @* begin
        case (_511)
        3'b000:
            _776 <= _761;
        3'b001:
            _776 <= _764;
        3'b010:
            _776 <= _765;
        3'b011:
            _776 <= _767;
        3'b100:
            _776 <= _769;
        3'b101:
            _776 <= _771;
        3'b110:
            _776 <= _773;
        3'b111:
            _776 <= _775;
        default:
            _776 <= _511;
        endcase
    end
    assign _38 = _776;
    always @(posedge _74) begin
        if (_72)
            _511 <= _597;
        else
            _511 <= _38;
    end
    assign _513 = _511 == _597;
    assign _514 = ~ _513;
    assign _778 = _514 ? _100 : reg_high_sent;
    assign _780 = reg_high_sent ? _98 : _778;
    assign _39 = _780;
    always @(posedge _74) begin
        if (_72)
            reg_high_sent <= _98;
        else
            reg_high_sent <= _39;
    end
    assign _785 = reg_high_sent ? _784 : _783;
    assign wire_output_nibble = _785;
    always @(posedge _74) begin
        if (_72)
            _793 <= _98;
        else
            _793 <= _791;
    end
    always @(posedge _74) begin
        if (_72)
            _798 <= _98;
        else
            if (_791)
                _798 <= _796;
    end
    always @* begin
        case (_93)
        3'b101:
            _802 <= _100;
        default:
            _802 <= gnd;
        endcase
    end
    assign _44 = _802;
    always @* begin
        case (_93)
        3'b010:
            _804 <= _100;
        default:
            _804 <= gnd;
        endcase
    end
    assign _46 = _804;
    assign _872 = _871[10:10];
    assign _873 = _805 ? _859 : _872;
    assign _875 = ~ _805;
    assign _876 = _875 | _817;
    assign _874 = ~ _72;
    assign _877 = _874 & _876;
    assign _878 = _871[8:8];
    assign _879 = _805 ? _857 : _878;
    assign _880 = _871[9:9];
    assign _881 = _805 ? vdd : _880;
    assign _870 = bypass_cond_1 | RD_INT_1;
    always @(posedge _74) begin
        data_before_collision_1 <= _863;
    end
    always @(posedge _74) begin
        if (_72)
            dbg_stage1_val <= _114;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage1_val <= dbg_byte_assembler_out;
    end
    always @(posedge _74) begin
        if (_72)
            dbg_stage2 <= _114;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage2 <= dbg_stage1_val;
    end
    always @(posedge _74) begin
        if (_72)
            dbg_stage3 <= _114;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage3 <= dbg_stage2;
    end
    always @(posedge _74) begin
        if (_72)
            dbg_stage4 <= _114;
        else
            if (dbg_byte_assembler_valid)
                dbg_stage4 <= dbg_stage3;
    end
    always @* begin
        case (_93)
        3'b101:
            _884 <= _100;
        default:
            _884 <= _98;
        endcase
    end
    assign _53 = _884;
    assign _54 = _53;
    assign dbg_payload_out_delayed = _54 ? dbg_stage4 : _114;
    always @(posedge _74) begin
        if (_72)
            _862 <= _114;
        else
            _862 <= dbg_payload_out_delayed;
    end
    assign vdd = 1'b1;
    assign _795 = 32'b11011110101110110010000011100011;
    assign _957 = _956 ^ _617;
    assign _955 = _950[31:1];
    assign _956 = { _98,
                    _955 };
    assign _952 = dbg_byte_assembler_out[7:7];
    assign _949 = _948 ^ _617;
    assign _947 = _942[31:1];
    assign _948 = { _98,
                    _947 };
    assign _944 = dbg_byte_assembler_out[6:6];
    assign _941 = _940 ^ _617;
    assign _939 = _934[31:1];
    assign _940 = { _98,
                    _939 };
    assign _936 = dbg_byte_assembler_out[5:5];
    assign _933 = _932 ^ _617;
    assign _931 = _926[31:1];
    assign _932 = { _98,
                    _931 };
    assign _928 = dbg_byte_assembler_out[4:4];
    assign _925 = _924 ^ _617;
    assign _923 = _918[31:1];
    assign _924 = { _98,
                    _923 };
    assign _920 = dbg_byte_assembler_out[3:3];
    assign _917 = _916 ^ _617;
    assign _915 = _910[31:1];
    assign _916 = { _98,
                    _915 };
    assign _912 = dbg_byte_assembler_out[2:2];
    assign _909 = _908 ^ _617;
    assign _907 = _902[31:1];
    assign _908 = { _98,
                    _907 };
    assign _904 = dbg_byte_assembler_out[1:1];
    assign _901 = _899 ^ _617;
    assign _898 = _794[31:1];
    assign _899 = { _98,
                    _898 };
    assign _895 = dbg_byte_assembler_out[0:0];
    assign _894 = _794[0:0];
    assign _896 = _894 ^ _895;
    assign _902 = _896 ? _901 : _899;
    assign _903 = _902[0:0];
    assign _905 = _903 ^ _904;
    assign _910 = _905 ? _909 : _908;
    assign _911 = _910[0:0];
    assign _913 = _911 ^ _912;
    assign _918 = _913 ? _917 : _916;
    assign _919 = _918[0:0];
    assign _921 = _919 ^ _920;
    assign _926 = _921 ? _925 : _924;
    assign _927 = _926[0:0];
    assign _929 = _927 ^ _928;
    assign _934 = _929 ? _933 : _932;
    assign _935 = _934[0:0];
    assign _937 = _935 ^ _936;
    assign _942 = _937 ? _941 : _940;
    assign _943 = _942[0:0];
    assign _945 = _943 ^ _944;
    assign _950 = _945 ? _949 : _948;
    assign _951 = _950[0:0];
    assign _953 = _951 ^ _952;
    assign _958 = _953 ? _957 : _956;
    assign _959 = dbg_byte_assembler_valid ? _958 : _794;
    assign _889 = _77 | _789;
    always @* begin
        case (_93)
        3'b001:
            _887 <= _100;
        default:
            _887 <= gnd;
        endcase
    end
    assign _55 = _887;
    assign _888 = ~ _55;
    assign _890 = _888 & _889;
    assign _891 = _890 & _79;
    assign _892 = ~ _891;
    assign _893 = _72 | _892;
    assign _961 = _893 ? _677 : _959;
    assign _56 = _961;
    always @(posedge _74) begin
        _794 <= _56;
    end
    assign _796 = _794 == _795;
    assign _858 = ~ _796;
    assign gnd = 1'b0;
    assign _788 = ~ _77;
    always @(posedge _74) begin
        if (_72)
            _787 <= _98;
        else
            _787 <= _77;
    end
    assign _789 = _787 & _788;
    always @(posedge _74) begin
        if (_72)
            _791 <= _98;
        else
            _791 <= _789;
    end
    assign _857 = _791 & _817;
    assign _859 = _857 ? _858 : gnd;
    assign _863 = { _859,
                    vdd,
                    _857,
                    _862 };
    always @(posedge _74) begin
        if (_848)
            _864[_58] <= _863;
    end
    always @(posedge _74) begin
        _856 <= RA_1;
    end
    assign ram_rbw_data_1 = _864[_856];
    assign READ_ADDRESS_NEXT_1 = _57 + _578;
    always @(posedge _74) begin
        if (_72)
            READ_ADDRESS_1 <= _686;
        else
            if (_849)
                READ_ADDRESS_1 <= READ_ADDRESS_NEXT_1;
    end
    assign _57 = READ_ADDRESS_1;
    assign _849 = RD_INT_1 & used_gt_one_1;
    assign RA_1 = _849 ? READ_ADDRESS_NEXT_1 : _57;
    assign WRITE_ADDRESS_NEXT_1 = _58 + _578;
    always @(posedge _74) begin
        if (_72)
            WRITE_ADDRESS_1 <= _686;
        else
            if (_848)
                WRITE_ADDRESS_1 <= WRITE_ADDRESS_NEXT_1;
    end
    assign _58 = WRITE_ADDRESS_1;
    assign _853 = _58 == RA_1;
    assign _845 = ~ RD_INT_1;
    assign _846 = used_is_one_1 & _845;
    assign _843 = RD_INT_1 ^ WR_INT_1;
    assign _841 = _568 < USED_NEXT_1;
    always @(posedge _74) begin
        if (_72)
            used_gt_one_1 <= _98;
        else
            if (_843)
                used_gt_one_1 <= _841;
    end
    assign _847 = used_gt_one_1 | _846;
    assign _848 = WR_INT_1 & _847;
    assign _854 = _848 & _853;
    always @(posedge _74) begin
        collision_1 <= _854;
    end
    assign memory_1 = collision_1 ? data_before_collision_1 : ram_rbw_data_1;
    assign _835 = RD_INT_1 ^ WR_INT_1;
    assign _833 = USED_NEXT_1 == _568;
    always @(posedge _74) begin
        if (_72)
            used_is_one_1 <= _98;
        else
            if (_835)
                used_is_one_1 <= _833;
    end
    assign _837 = used_is_one_1 & WR_INT_1;
    assign _838 = _837 & RD_INT_1;
    assign _824 = _805 & WR_INT_1;
    assign bypass_cond_1 = _824 | _838;
    assign _868 = bypass_cond_1 ? _863 : memory_1;
    always @(posedge _74) begin
        if (_72)
            _871 <= _525;
        else
            if (_870)
                _871 <= _868;
    end
    assign _1048 = _871[7:0];
    assign _969 = USED_NEXT_1 - _568;
    always @(posedge _74) begin
        if (_72)
            USED_MINUS_1_1 <= _533;
        else
            if (_829)
                USED_MINUS_1_1 <= _969;
    end
    assign _59 = USED_MINUS_1_1;
    assign _973 = USED_NEXT_1 + _568;
    always @(posedge _74) begin
        if (_72)
            USED_PLUS_1_1 <= _568;
        else
            if (_829)
                USED_PLUS_1_1 <= _973;
    end
    assign _60 = USED_PLUS_1_1;
    assign _830 = RD_INT_1 ? _59 : _60;
    always @(posedge _74) begin
        if (_72)
            USED_1 <= _114;
        else
            if (_829)
                USED_1 <= USED_NEXT_1;
    end
    assign _61 = USED_1;
    assign _979 = USED_NEXT_1 == _747;
    always @(posedge _74) begin
        if (_72)
            full_1 <= _98;
        else
            if (_829)
                full_1 <= _979;
    end
    assign _62 = full_1;
    assign _63 = _62;
    assign _822 = ~ _63;
    assign _819 = ~ _88;
    assign _818 = ~ _89;
    assign _820 = _818 | _819;
    always @(posedge _74) begin
        if (_72)
            valid_stage1 <= _98;
        else
            if (dbg_byte_assembler_valid)
                valid_stage1 <= _85;
    end
    always @(posedge _74) begin
        if (_72)
            valid_stage2 <= _98;
        else
            if (dbg_byte_assembler_valid)
                valid_stage2 <= valid_stage1;
    end
    always @(posedge _74) begin
        if (_72)
            valid_stage3 <= _98;
        else
            if (dbg_byte_assembler_valid)
                valid_stage3 <= valid_stage2;
    end
    always @(posedge _74) begin
        if (_72)
            dbg_delayed_valid_raw <= _98;
        else
            if (dbg_byte_assembler_valid)
                dbg_delayed_valid_raw <= valid_stage3;
    end
    assign _1035 = _77 ? _723 : _708;
    assign _1036 = _70 ? _597 : _1035;
    assign _1033 = _1000 ? _723 : _718;
    assign _1034 = _984 ? _1033 : _597;
    assign _1031 = _993 ? _718 : _602;
    assign _1032 = _984 ? _1031 : _597;
    assign _1002 = dbg_mac_byte_count + _708;
    assign _1000 = dbg_mac_byte_count == _708;
    assign _1004 = _1000 ? _597 : _1002;
    assign _1005 = _984 ? _1004 : dbg_mac_byte_count;
    assign _995 = dbg_mac_byte_count + _708;
    assign _993 = dbg_mac_byte_count == _723;
    assign _997 = _993 ? _597 : _995;
    assign _998 = _984 ? _997 : dbg_mac_byte_count;
    assign _988 = dbg_mac_byte_count + _708;
    assign _990 = _986 ? _597 : _988;
    assign _991 = _984 ? _990 : dbg_mac_byte_count;
    always @* begin
        case (_93)
        3'b010:
            _1006 <= _991;
        3'b011:
            _1006 <= _998;
        3'b100:
            _1006 <= _1005;
        default:
            _1006 <= dbg_mac_byte_count;
        endcase
    end
    assign _1007 = _82 ? _1006 : dbg_mac_byte_count;
    assign _64 = _1007;
    always @(posedge _74) begin
        if (_72)
            dbg_mac_byte_count <= _597;
        else
            dbg_mac_byte_count <= _64;
    end
    assign _986 = dbg_mac_byte_count == _723;
    assign _1029 = _986 ? _602 : _762;
    assign _1030 = _984 ? _1029 : _597;
    assign _1010 = _1009 ? _118 : _67;
    assign _1011 = _80 ? _1010 : _118;
    assign _65 = _1011;
    always @(posedge _74) begin
        if (_72)
            _118 <= _781;
        else
            _118 <= _65;
    end
    assign _67 = rx_data;
    assign _1012 = _1009 ? _67 : _116;
    assign _1013 = _80 ? _1012 : _116;
    assign _68 = _1013;
    always @(posedge _74) begin
        if (_72)
            _116 <= _781;
        else
            _116 <= _68;
    end
    assign dbg_byte_assembler_out = { _116,
                                      _118 };
    always @* begin
        case (dbg_byte_assembler_out)
        8'b01010101:
            _1027 <= _708;
        8'b11010101:
            _1027 <= _762;
        default:
            _1027 <= _93;
        endcase
    end
    assign _1028 = _984 ? _1027 : _597;
    assign _70 = rx_er;
    assign _982 = ~ _70;
    assign _983 = _77 & _982;
    assign _984 = _983 & _79;
    assign _1024 = _984 ? _708 : _597;
    always @* begin
        case (_93)
        3'b000:
            _1038 <= _1024;
        3'b001:
            _1038 <= _1028;
        3'b010:
            _1038 <= _1030;
        3'b011:
            _1038 <= _1032;
        3'b100:
            _1038 <= _1034;
        3'b101:
            _1038 <= _1036;
        3'b110:
            _1038 <= _605;
        default:
            _1038 <= _93;
        endcase
    end
    assign _72 = reset;
    assign _74 = clock;
    assign _1016 = _1009 ? _98 : _100;
    assign _1017 = _80 ? _1016 : _1009;
    assign _75 = _1017;
    always @(posedge _74) begin
        if (_72)
            _1009 <= _98;
        else
            _1009 <= _75;
    end
    assign _1021 = _1009 ? _100 : _98;
    assign _77 = rx_dv;
    assign _79 = en;
    assign _1018 = _79 & _77;
    assign _80 = _1018;
    assign _1022 = _80 ? _1021 : _98;
    assign _81 = _1022;
    always @(posedge _74) begin
        if (_72)
            dbg_byte_assembler_valid <= _98;
        else
            dbg_byte_assembler_valid <= _81;
    end
    assign _82 = dbg_byte_assembler_valid;
    assign _1039 = _82 ? _1038 : _93;
    assign _83 = _1039;
    always @(posedge _74) begin
        if (_72)
            _93 <= _597;
        else
            _93 <= _83;
    end
    always @* begin
        case (_93)
        3'b101:
            _1042 <= _100;
        default:
            _1042 <= _98;
        endcase
    end
    assign dbg_emit_payload_controller = _1042;
    assign _85 = dbg_emit_payload_controller;
    assign dbg_payload_out_valid_delayed = _85 & dbg_delayed_valid_raw;
    assign _815 = dbg_payload_out_valid_delayed & dbg_byte_assembler_valid;
    always @(posedge _74) begin
        if (_72)
            _817 <= _98;
        else
            _817 <= _815;
    end
    assign _821 = _817 & _820;
    assign WR_INT_1 = _821 & _822;
    assign _86 = _805;
    assign _827 = ~ _86;
    assign _88 = m_axis_tready;
    assign _89 = _805;
    assign _825 = ~ _89;
    assign _826 = _825 & _88;
    assign RD_INT_1 = _826 & _827;
    assign _829 = RD_INT_1 ^ WR_INT_1;
    assign USED_NEXT_1 = _829 ? _830 : _61;
    assign _1044 = USED_NEXT_1 == _114;
    assign _1045 = ~ _1044;
    always @(posedge _74) begin
        if (_72)
            not_empty_1 <= _98;
        else
            if (_829)
                not_empty_1 <= _1045;
    end
    assign _90 = not_empty_1;
    assign _805 = ~ _90;
    assign _1049 = _805 ? _862 : _1048;
    assign valid_stage4 = dbg_delayed_valid_raw;
    assign m_axis_tdata = _1049;
    assign m_axis_tkeep = _881;
    assign m_axis_tlast = _879;
    assign m_axis_tvalid = _877;
    assign m_axis_tuser = _873;
    assign in_preamble = _55;
    assign in_dst_mac = _46;
    assign in_payload = _44;
    assign frame_crc_ok = _798;
    assign frame_done = _793;
    assign tx_d = wire_output_nibble;
    assign tx_en = wire_nibble_valid;
    assign s_axis_tready = _507;
    assign keep = _506;

endmodule
