module visible_clock (
    input P_CLK,
    input NRST,
    
    output CLK_EN
);

reg [19:0] timer;

always @ (posedge P_CLK) begin
    if (!NRST)
        timer <= 20'd0;
    else if (timer > 20'd555500)
        timer <= 20'd0;
    else
        timer <= timer + 1'b1;
end

assign CLK_EN = (timer == 20'd555500) ? 1'b1 : 1'b0; // 60Hz for P_CLK

endmodule