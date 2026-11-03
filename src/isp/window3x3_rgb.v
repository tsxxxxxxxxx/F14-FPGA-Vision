`timescale 1ns/1ps
// Adapted from our tested SC2210 sobel3x3_stream row-bank/window logic.
// Data width extended to RGB24; Sobel arithmetic removed, not reimplemented.
// Fixed raster, active-low VS, contiguous DE, WIDTH>=3; 2 registered stages.
module window3x3_rgb #(parameter WIDTH=1280,HEIGHT=720,BITS=24)(
 input wire clk,rst_n,vs_i,de_i,input wire [BITS-1:0] rgb_i,
 output reg valid_o,
 output reg [BITS-1:0] p11,p12,p13,p21,p22,p23,p31,p32,p33);
 reg [BITS-1:0] row_even[0:WIDTH-1],row_odd[0:WIDTH-1];
 reg [BITS-1:0] even_q,odd_q,pixel_q;
 reg [11:0] x,y,x_q,y_q; reg de_q;
 always @(posedge clk) begin
  if(rst_n && de_i) begin even_q<=row_even[x];odd_q<=row_odd[x];end
  if(rst_n && de_q) if(y_q[0]) row_odd[x_q]<=pixel_q; else row_even[x_q]<=pixel_q;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin x<=0;y<=0;x_q<=0;y_q<=0;pixel_q<=0;de_q<=0;end
 else begin
  de_q<=de_i;x_q<=x;y_q<=y;pixel_q<=rgb_i;
  if(!vs_i) begin x<=0;y<=0;end
  else if(de_i) if(x==WIDTH-1) begin x<=0;if(y<HEIGHT)y<=y+1'b1;end else x<=x+1'b1;
 end
 wire [BITS-1:0] old_row=y_q[0]?odd_q:even_q;
 wire [BITS-1:0] prev_row=y_q[0]?even_q:odd_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin {p11,p12,p13,p21,p22,p23,p31,p32,p33}<=0;valid_o<=0;end
 else begin
  valid_o<=de_q && x_q>=2 && y_q>=2 && y_q<HEIGHT;
  if(de_q) begin
   if(x_q==0) begin
    {p11,p12,p13}<={{(2*BITS){1'b0}},old_row};{p21,p22,p23}<={{(2*BITS){1'b0}},prev_row};{p31,p32,p33}<={{(2*BITS){1'b0}},pixel_q};
   end else begin
    {p11,p12,p13}<={p12,p13,old_row};{p21,p22,p23}<={p22,p23,prev_row};{p31,p32,p33}<={p32,p33,pixel_q};
   end
  end
 end
endmodule
