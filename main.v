module main (
    input CLK,
    input NRST,
    input b1,
    input b2,
    input b3,
    input b4,
    input b5,
    output P_CLK,
    output HSYNC,
    output VSYNC,
    output DATA_EN,
    output [4:0] RED,
    output [5:0] GREEN,
    output [4:0] BLUE
);

wire CLK_400;
wire CLK_EN;

wire b1_deb;
wire b2_deb;
wire b3_deb;
wire b4_deb;
wire b5_deb;

Gowin_rPLL PLL(
        .clkout (CLK_400),
        .clkoutd(P_CLK), //output clkoutd
        .clkin(CLK) //input clkin
    );

driver driver_inst(
        .P_CLK (P_CLK),
        .NRST (NRST),
        .p1_dn (b1_deb),
        .p1_up (b2_deb),
        .p2_dn (b3_deb),
        .p2_up (b4_deb),
        .start (b5_deb),
        .DATA_EN (DATA_EN),
        .HSYNC (HSYNC),
        .VSYNC (VSYNC),
        .color_red (RED),
        .color_green (GREEN),
        .color_blue (BLUE)
    );

visible_clock SCK(
    .P_CLK (P_CLK),
    .NRST (NRST),
    .CLK_EN (CLK_EN)
);

debouncer p1_up(
    .CLK (P_CLK),
    .NRST (NRST),
    .CLK_EN (CLK_EN),
    .key_in (b1),
    .key_out (b1_deb)
);

debouncer p1_down(
    .CLK (P_CLK),
    .NRST (NRST),
    .CLK_EN (CLK_EN),
    .key_in (b2),
    .key_out (b2_deb)
);

debouncer p2_up(
    .CLK (P_CLK),
    .NRST (NRST),
    .CLK_EN (CLK_EN),
    .key_in (b3),
    .key_out (b3_deb)
);

debouncer p2_down(
    .CLK (P_CLK),
    .NRST (NRST),
    .CLK_EN (CLK_EN),
    .key_in (b4),
    .key_out (b4_deb)
);

debouncer start(
    .CLK (P_CLK),
    .NRST (NRST),
    .CLK_EN (CLK_EN),
    .key_in (b5),
    .key_out (b5_deb)
);

endmodule

