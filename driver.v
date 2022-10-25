module driver (
    input P_CLK,         // pixel clock
    input NRST,          // tang nano 9k has negative-activated reset
    input p1_up,         // among many other inputs :(
    input p1_dn,
    input p2_up,
    input p2_dn,
    input start,
    output DATA_EN,
    output HSYNC,
    output VSYNC,
    output reg [4:0] color_red,
    output reg [5:0] color_green,
    output reg [4:0] color_blue
);

/////////////////////////
// LCD driver

localparam Width = 800;
localparam Height = 480;

localparam HBP = 88;
localparam HFP = 40;
localparam HS = 128; // horizontal sync pulse

localparam VBP = 33;
localparam VFP = 10;
localparam VS = 2;   // vertical sync pulse

localparam H_TOT = Width + HFP + HBP;   // horizontal pixels total
localparam V_TOT = Height + VFP + VBP;  // vertical lines total

reg [10:0] Pixels;
reg [10:0] Lines;

always @ (posedge P_CLK or negedge NRST) begin
    if (!NRST) begin
        Pixels <= 16'd0;
        Lines <= 16'd0;
    end
    else if (Pixels == H_TOT) begin // 0 - (H_TOT-1)
        Pixels <= 16'd0;
        Lines <= Lines + 1'b1;
    end
    else if (Lines == V_TOT) begin // 0 - (V_TOT-1)
        Pixels <= 16'd0;
        Lines <= 16'd0;
    end
    else
        Pixels <= Pixels + 1'b1;
end

assign DATA_EN = ((Pixels <= H_TOT - HFP)&&(Pixels >= HBP)&&
                  (Lines <= V_TOT - VFP)&&(Lines >= VBP));
assign HSYNC = !((Pixels >= HS)&&(Pixels <= H_TOT));
assign VSYNC = !((Lines >= VS)&&(Lines <= V_TOT));

reg refresh;

always @ (*) begin
    if ((Lines == Height + VBP)&&(Pixels == 0))
        refresh <= 1'b1;
    else
        refresh <= 1'b0;
end

////////////////////////
// state machine

reg [1:0] state = RESET;

reg [3:0] score_p1 = 4'd0;
reg [3:0] score_p2 = 4'd0;
reg p1_win = 1'b0;
reg p2_win = 1'b0;

localparam RESET = 0;
localparam GAME_START = 1;
localparam GAME_END = 2;

always @ (posedge P_CLK) begin
    case (state)
        RESET: begin
            state <= (!start) ? GAME_START : RESET;
        end
        GAME_START: begin
            state <= (p1_win || p2_win) ? GAME_END : (!NRST) ? RESET : GAME_START;
        end
        GAME_END: begin
            state <= (!NRST) ? RESET : GAME_END;
        end
        default: state <= RESET;
    endcase
end


////////////////////////////////////
// ball movement

localparam ball_size = 20;
localparam ball_vx_init = 2;
localparam ball_vy_init = 2;

reg [9:0] ball_posx = (Width - 2*ball_size)/2;
reg [9:0] ball_posy = (Height - 2*ball_size)/2;

reg [9:0] ball_vx = ball_vx_init;
reg [9:0] ball_vy = ball_vy_init;

reg ball_dirx = 1'd1;
reg ball_diry = 1'd1;

reg ball_coll = 1'b0;
reg ball_colr = 1'b0;

reg [24:0] ball_restart_timer;
reg ball_restart_flag;
reg ball_timer_start;

always @ (posedge P_CLK) begin
    case(state)
    RESET: begin
        score_p1 <= 4'd0;
        score_p2 <= 4'd0;
        p1_win <= 1'd0;
        p2_win <= 1'd0;

        ball_vx <= ball_vx_init;
        ball_vy <= ball_vy_init;
        ball_posx <= (Width - 2*ball_size)/2;
        ball_posy <= (Height - 2*ball_size)/2;
        ball_dirx <= 1'b1;
        ball_dirx <= 1'b1;
        ball_coll <= 1'b0;
        ball_colr <= 1'b0;
        
        ball_restart_timer <= 25'd0;
        ball_restart_flag <= 1'b0;
        ball_timer_start <= 1'b0;

    end
    GAME_START: begin
        if (refresh) begin
            if (ball_dirx == 1'b1) begin // x movement
                if (ball_posx + ball_size + ball_vx < Width)
                    ball_posx <= ball_posx + ball_vx; // right
                else begin
                    ball_posx <= Width - ball_size;
                    ball_colr <= 1'b1;
                end
            end
            else begin
                if (ball_posx < ball_vx) begin
                    ball_posx <= 10'd0;
                    ball_coll <= 1'b1;
                
                end
                else
                    ball_posx <= ball_posx - ball_vx; // left
            end

            if (ball_diry == 1'b1) begin // y movement
                if (ball_posy + ball_size + ball_vy < Height)
                    ball_posy <= ball_posy + ball_vy; // down
                else begin
                    ball_posy <= Height - ball_size;
                    ball_diry <= 1'b0;
                    ball_vy <= ball_vy + 1'b1;
                end
            end
            else begin
                if (ball_posy < ball_vy) begin
                    ball_posy <= 10'd0;
                    ball_diry <= 1'b1;
                end
                else
                    ball_posy <= ball_posy - ball_vy; // up
            end
        end

        if (ball_restart_flag) begin
                ball_timer_start <= 1'b0;
                ball_vx <= ball_vx_init;
                ball_vy <= ball_vy_init;
                ball_restart_flag <= 1'b0;
                ball_restart_timer <= 25'd0;
        end

        if (ball_model && barl_model && ball_dirx == 1'b0) begin // left bar collision
            ball_dirx <= 1'b1;
            ball_vx <= ball_vx + 1'b1;
        end
        else if (ball_model && barr_model && ball_dirx == 1'b1) begin // right bar collision
            ball_dirx <= 1'b0;
            ball_vx <= ball_vx + 1'b1;
        end
        else if (ball_model && ball_coll) begin // left border collision
            ball_posx <= (Width/2) + ball_size - HBP/2;
            ball_posy <= (Height/2) + ball_size - VBP;
            ball_dirx <= 1'b0;
            ball_vx <= 0;
            ball_vy <= 0;
            ball_coll <= 1'b0;
            score_p2 <= score_p2 + 1'b1;
            ball_timer_start <= 1'b1;
        end
        else if (ball_model && ball_colr) begin // right border collision
            ball_posx <= (Width/2) + ball_size - HBP/2;
            ball_posy <= (Height/2) + ball_size - VBP;
            ball_dirx <= 1'b1;
            ball_vx <= 0;
            ball_vy <= 0;
            ball_colr <= 1'b0;
            score_p1 <= score_p1 + 1'b1;
            ball_timer_start <= 1'b1;
        end
        if (score_p1 > 4'd9) begin
            p1_win <= 1'b1;
            score_p1 <= 4'd0;
        end
        else if (score_p2 > 4'd9) begin
            p2_win <= 1'b1;
            score_p2 <= 4'd0;
        end
        ///////////////////
        // time until the ball starts moving after a score
        if (!NRST)
            ball_restart_timer <= 25'd0;
        else if (ball_restart_timer >= 25'd33330000)
            ball_restart_flag <= 1'b1;
        else if (ball_timer_start)
            ball_restart_timer <= ball_restart_timer + 1'b1;
        else
            ball_restart_timer <= 24'd0;
    end

    GAME_END: begin
        if (refresh) begin
            ball_posx <= (Width - ball_size)/2;
            ball_posy <= (Height - ball_size)/2;
            if (p1_win) begin
                score_p1 <= 4'd1;
                score_p2 <= 4'd0;
            end
            else if (p2_win) begin
                score_p1 <= 4'd0;
                score_p2 <= 4'd1;
            end
        end
    end
    endcase
end

//////////////////////////
// bar movement

localparam bar_speed = 5;
localparam bar_height = 100;
localparam bar_width = 10;

reg [9:0] barl_posy = (Height - 2*bar_height)/2;
reg [9:0] barr_posy = (Height - 2*bar_height)/2;

reg [9:0] bar_vy = bar_speed;

always @ (posedge P_CLK) begin // player 1
    case (state)
    RESET:
        barl_posy <= (Height - 2*bar_height)/2;
    GAME_START: begin
        if (refresh) begin
            if (!p1_dn) begin // down
                if (barl_posy + bar_height + bar_vy < Height)
                    barl_posy <= barl_posy + bar_vy;
                else
                    barl_posy <= Height - bar_height;
            end
            else if (!p1_up) begin // up
                if (barl_posy < bar_vy)
                    barl_posy <= 10'd0;
                else
                    barl_posy <= barl_posy - bar_vy;
            end
        end
    end
    GAME_END: begin
        if (refresh)
            barl_posy <= (Height - bar_height)/2;
    end
    endcase
end

always @ (posedge P_CLK) begin // player 2
    case (state)
    RESET:
        barr_posy <= (Height - 2*bar_height)/2;
    GAME_START: begin
        if (refresh) begin
            if (!p2_dn) begin // down
                if (barr_posy + bar_height + bar_vy < Height)
                    barr_posy <= barr_posy + bar_vy;
                else
                    barr_posy <= Height - bar_height;
            end
            else if (!p2_up) begin // up
                if (barr_posy < bar_vy)
                    barr_posy <= 10'd0;
                else
                    barr_posy <= barr_posy - bar_vy;
            end
        end
    end
    GAME_END: begin
        if (refresh)
            barr_posy <= (Height - bar_height)/2;
    end
    endcase
end

//////////////////////////
// player score display

wire [0:7] digit_data; // inverted data read (left to right)
wire [7:0] digit_addr;

digit_rom digit_rom(
    .P_CLK (P_CLK),
    .rom_addr (digit_addr),
    .rom_data (digit_data)
);


wire [3:0] char_addr; // address of a character 
wire [3:0] current_row_addr; // address of a character's currently printed row
wire [2:0] bit_inrow_addr; // address of a certain bit from the current row being printed
wire bit_display;  // digit currently being printed

assign current_row_addr = Lines[4:1];  // each character pixels is scaled  
assign bit_inrow_addr = Pixels[3:1]; // to four pixels on LCD, by ommitting LSB

assign char_addr = (p1_digit_area) ? score_p1 : (p2_digit_area) ? score_p2 : score_p2;

assign digit_addr = {char_addr, current_row_addr}; // concatenation of the char address 7'h[x]x
                                                   // and the row address 7'hx[x] to select
                                                   // the desired row of digits for display

assign bit_display = digit_data[bit_inrow_addr];

///////////////////////////
// drawing models on lcd

wire ball_model;

assign ball_model = (Pixels >= ball_posx + HBP)&&(Pixels < ball_posx + ball_size + HBP)
                    &&(Lines >= ball_posy + VBP)&&(Lines < ball_posy + ball_size + VBP);

wire barl_model;
wire barr_model;

assign barl_model = (Pixels < 30 + bar_width + HBP)&&(Pixels >= 30 + HBP)
                    &&(Lines < barl_posy + bar_height + VBP)&&(Lines >= barl_posy + VBP);
assign barr_model = (Pixels < 760 + bar_width + HBP)&&(Pixels >= 760 + HBP)
                    &&(Lines < barr_posy + bar_height + VBP)&&(Lines >= barr_posy + VBP);

wire p1_digit_area; 
wire p2_digit_area;

assign p1_digit_area = (Pixels < 40 + HBP)&&(Pixels >= 23 + HBP)
                        &&(Lines < 64 + VBP)&&(Lines >= 32 + VBP); // beginning from (24 - 1,32), 8x16 (quasi-ascii 1-9)                    
assign p2_digit_area = (Pixels < Width + HBP - 24)&&(Pixels >= (Width + HBP - 40))
                        &&(Lines < 64 + VBP)&&(Lines >= 32 + VBP);

always @ (posedge P_CLK) begin
    if (state == GAME_START) begin
        if (ball_model) begin // ball
            color_red <= 5'b10000;
            color_green <= 6'b100000;
            color_blue <= 5'b10000;
        end
        else if (barl_model || barr_model) begin // ball
            color_red <= 5'b10000;
            color_green <= 6'b100000;
            color_blue <= 5'b10000;
        end
        else if ((p1_digit_area || p2_digit_area) && bit_display) begin
            color_red <= 5'b10000;
            color_green <= 6'b100000;
            color_blue <= 5'b10000;
        end
        else begin
            color_red <= 5'b00000;
            color_green <= 6'b000000;
            color_blue <= 5'b00000;
        end
    end
    else if (state == GAME_END) begin
        if (ball_model) begin // ball
            color_red <= 5'b10000;
            color_green <= 6'b100000;
            color_blue <= 5'b00000;
        end
        else if (barl_model || barr_model) begin // ball
            color_red <= 5'b10000;
            color_green <= 6'b100000;
            color_blue <= 5'b00000;
        end
        else if ((p1_digit_area || p2_digit_area) && bit_display) begin
            color_red <= 5'b10000;
            color_green <= 6'b100000;
            color_blue <= 5'b00000;
        end
        else begin
            color_red <= 5'b00000;
            color_green <= 6'b000000;
            color_blue <= 5'b00000;
        end
    end
end

endmodule


