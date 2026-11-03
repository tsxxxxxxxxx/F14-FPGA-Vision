`timescale 1ns / 1ps
// Full-range 8-bit luma approximation: (77*R + 150*G + 29*B + 128) >> 8.
// Three register stages, one pixel per clock; NEVER stall during blanking.
// All video controls travel through the same three stages as their pixel.
module rgb888_to_gray (
    input wire clk,
    input wire rst_n,
    input wire in_vsync,
    input wire in_hsync,
    input wire in_de,
    input wire [7:0] in_r,
    input wire [7:0] in_g,
    input wire [7:0] in_b,
    output wire out_vsync,
    output wire out_hsync,
    output wire out_de,
    output wire [7:0] out_gray
);
    wire [15:0] r16 = {8'b0, in_r};
    wire [15:0] g16 = {8'b0, in_g};
    wire [15:0] b16 = {8'b0, in_b};
    reg [15:0] r_weight, g_weight, b_weight;
    reg [15:0] rg_sum, b_round;
    reg [7:0] gray;
    reg [2:0] vs_pipe, hs_pipe, de_pipe;
    // Maximum including rounding = 255*256+128 = 65408; 16 bits suffice.
    wire [15:0] total = rg_sum + b_round;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_weight <= 0;
            g_weight <= 0;
            b_weight <= 0;
            rg_sum <= 0;
            b_round <= 0;
            gray <= 0;
            vs_pipe <= 0;
            hs_pipe <= 0;
            de_pipe <= 0;
        end else begin
            // Constant coefficients implemented with shifts/adds, no divider.
            r_weight <= (r16 << 6) + (r16 << 3) + (r16 << 2) + r16;
            g_weight <= (g16 << 7) + (g16 << 4) + (g16 << 2) + (g16 << 1);
            b_weight <= (b16 << 4) + (b16 << 3) + (b16 << 2) + b16;
            rg_sum <= r_weight + g_weight;
            b_round <= b_weight + 16'd128;
            gray <= total[15:8];
            vs_pipe <= {vs_pipe[1:0], in_vsync};
            hs_pipe <= {hs_pipe[1:0], in_hsync};
            de_pipe <= {de_pipe[1:0], in_de};
        end
    end

    assign out_vsync = vs_pipe[2];
    assign out_hsync = hs_pipe[2];
    assign out_de = de_pipe[2];
    assign out_gray = out_de ? gray : 8'd0;
endmodule
