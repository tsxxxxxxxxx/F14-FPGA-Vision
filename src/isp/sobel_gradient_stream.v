`timescale 1ns/1ps
// Center-aligned streaming Sobel, one pixel/clock, fixed raster timing.
// 8-bit input; signed 11-bit gradients; 11-bit |Gx|+|Gy|; black 1-pixel border.
// VS is active low in the vendor HDMI path. H_TOTAL includes blanking.
// Requires WIDTH>=3, HEIGHT>=3, contiguous DE per line, and vertical blanking.
module sobel_gradient_stream #(
    parameter WIDTH = 1920,
    parameter HEIGHT = 1080,
    parameter H_TOTAL = 2200,
    parameter [10:0] THRESHOLD = 11'd80
)(
    input wire clk, input wire rst_n,
    input wire in_vsync, input wire in_hsync, input wire in_de,
    input wire [7:0] in_gray,
    output wire out_vsync, output wire out_hsync, output wire out_de,
    output wire [13:0] out_gradient,
    output wire [21:0] out_vector,
    output wire out_silhouette
);
    // Alternate row banks. Read current address first, write the previous
    // pixel's address one cycle later: no same-address read/write collision.
    reg [7:0] row_even [0:WIDTH-1];
    reg [7:0] row_odd  [0:WIDTH-1];
    reg [7:0] even_q, odd_q, pixel_q;
    reg [11:0] x, y, x_q, y_q;
    reg de_q;
    always @(posedge clk) begin
        if (rst_n && in_de) begin
            even_q <= row_even[x];
            odd_q  <= row_odd[x];
        end
        if (rst_n && de_q) begin
            if (y_q[0]) row_odd[x_q] <= pixel_q;
            else        row_even[x_q] <= pixel_q;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 0; y <= 0; x_q <= 0; y_q <= 0; pixel_q <= 0; de_q <= 0;
        end else begin
            de_q <= in_de;
            x_q <= x; y_q <= y; pixel_q <= in_gray;
            if (!in_vsync) begin
                x <= 0; y <= 0;
            end else if (in_de) begin
                if (x == WIDTH-1) begin
                    x <= 0;
                    if (y < HEIGHT) y <= y + 1'b1;
                end else x <= x + 1'b1;
            end
        end
    end

    // Registered 3x3 window (stage 2, following synchronous RAM read stage).
    wire [7:0] old_row = y_q[0] ? odd_q : even_q;
    wire [7:0] prev_row = y_q[0] ? even_q : odd_q;
    reg [7:0] p11,p12,p13,p21,p22,p23,p31,p32,p33;
    reg window_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {p11,p12,p13,p21,p22,p23,p31,p32,p33} <= 0;
            window_valid <= 0;
        end else begin
            window_valid <= de_q && (x_q >= 2) && (y_q >= 2) && (y_q < HEIGHT);
            if (de_q) begin
                if (x_q == 0) begin
                    {p11,p12,p13} <= {16'd0,old_row};
                    {p21,p22,p23} <= {16'd0,prev_row};
                    {p31,p32,p33} <= {16'd0,pixel_q};
                end else begin
                    {p11,p12,p13} <= {p12,p13,old_row};
                    {p21,p22,p23} <= {p22,p23,prev_row};
                    {p31,p32,p33} <= {p32,p33,pixel_q};
                end
            end
        end
    end

    // Stages 3/4/5/6: positive partial sums, signed difference, L1, compare.
    reg [9:0] left_sum,right_sum,top_sum,bottom_sum;
    reg signed [10:0] gx,gy;
    wire [10:0] ax = gx[10] ? -gx : gx;
    wire [10:0] ay = gy[10] ? -gy : gy;
    reg [10:0] magnitude;
    reg partial_valid,gradient_valid,magnitude_valid;
    // Four orientation bins using tan(22.5deg) ~= 424/1024; no division.
    // Image coordinates: +x right, +y down. Same-sign gradients -> NW/SE.
    wire [20:0] ax1024={ax,10'b0},ay1024={ay,10'b0};
    wire [20:0] ax424=ax*21'd424,ay424=ay*21'd424;
    reg [1:0] direction;
    // F2 adds the signed orientation half-plane; old low 13 bits unchanged.
    reg polarity;
    reg [13:0] gradient_q;
    reg [21:0] vector_d,vector_q;
    always @(posedge clk or negedge rst_n)
      if(!rst_n)begin vector_d<=0;vector_q<=0;end
      else begin vector_d<={gx,gy};vector_q<=magnitude_valid?vector_d:22'd0;end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_sum<=0; right_sum<=0; top_sum<=0; bottom_sum<=0;
            gx<=0; gy<=0; magnitude<=0; direction<=0; polarity<=0; gradient_q<=0;
            partial_valid<=0; gradient_valid<=0; magnitude_valid<=0;
        end else begin
            left_sum   <= {2'b0,p11}+{1'b0,p21,1'b0}+{2'b0,p31};
            right_sum  <= {2'b0,p13}+{1'b0,p23,1'b0}+{2'b0,p33};
            top_sum    <= {2'b0,p11}+{1'b0,p12,1'b0}+{2'b0,p13};
            bottom_sum <= {2'b0,p31}+{1'b0,p32,1'b0}+{2'b0,p33};
            partial_valid <= window_valid;
            gx <= $signed({1'b0,right_sum}) - $signed({1'b0,left_sum});
            gy <= $signed({1'b0,bottom_sum}) - $signed({1'b0,top_sum});
            gradient_valid <= partial_valid;
            magnitude <= ax + ay;
            if(ay1024<=ax424)begin direction<=0;polarity<=gx[10];end
            else if(ax1024<=ay424)begin direction<=2;polarity<=gy[10];end
            else begin
                direction<=(gx[10]^gy[10])?2'd3:2'd1;
                polarity<=(gx[10]^gy[10])?~gx[10]:gx[10];
            end
            magnitude_valid <= gradient_valid;
            gradient_q <= magnitude_valid?{polarity,direction,magnitude}:14'd0;
        end
    end

    // Reuse the existing gray window for a true black silhouette boundary.
    reg [3:0] silhouette_pipe;
    wire any_black=p11<96||p12<96||p13<96||p21<96||p22<96||p23<96||p31<96||p32<96||p33<96;
    wire any_light=p11>=96||p12>=96||p13>=96||p21>=96||p22>=96||p23>=96||p31>=96||p32>=96||p33>=96;
    always @(posedge clk or negedge rst_n)
    if(!rst_n)silhouette_pipe<=0;else silhouette_pipe<={silhouette_pipe[2:0],window_valid&&any_black&&any_light};
    assign out_silhouette=out_de&&silhouette_pipe[3];

    // The window center is one row+one pixel behind the newest input.
    // Delay the *entire* raster control stream by that amount plus six stages.
    // RAM ring read pointer is one ahead of write: read/write never collide.
    localparam CTRL_STAGES = H_TOTAL + 1 + 6;
    reg [2:0] ctrl_mem [0:CTRL_STAGES-1];
    reg [2:0] ctrl_q;
    reg [12:0] wr_ptr,rd_ptr,fill;
    reg ctrl_ready;
    always @(posedge clk) begin
        if (rst_n) begin
            ctrl_mem[wr_ptr] <= {in_vsync,in_hsync,in_de};
            ctrl_q <= ctrl_mem[rd_ptr];
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr<=0; rd_ptr<=1; fill<=0; ctrl_ready<=0;
        end else begin
            wr_ptr <= wr_ptr == CTRL_STAGES-1 ? 0 : wr_ptr+1'b1;
            rd_ptr <= rd_ptr == CTRL_STAGES-1 ? 0 : rd_ptr+1'b1;
            if (fill < CTRL_STAGES-1) fill <= fill+1'b1;
            ctrl_ready <= (fill == CTRL_STAGES-1);
        end
    end
    assign {out_vsync,out_hsync,out_de} = ctrl_ready ? ctrl_q : 3'b110;
    assign out_gradient = out_de?gradient_q:14'd0;
    assign out_vector = out_de?vector_q:22'd0;
endmodule
