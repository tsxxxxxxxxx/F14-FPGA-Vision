`timescale 1ns/1ps
// Full active image, 8x spatial sampling: 1920x1080 -> 240x135.
// No video ready/backpressure. The classifier ignores complete frames while busy.
module shapes_capture #(parameter WIDTH=1920,HEIGHT=1080,STRIDE=8)(
 input wire clk,rst_n,enabled,vs,de,input wire [7:0] gray,
 output reg frame_start,sample_valid,output reg [7:0] sample_gray);
 reg [11:0] x,y;reg vs_d;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;vs_d<=1;frame_start<=0;sample_valid<=0;sample_gray<=0;end
 else begin
  vs_d<=vs;frame_start<=enabled&&vs_d&&!vs;sample_valid<=0;
  if(!vs)begin x<=0;y<=0;end
  else if(de)begin
   if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
   if(enabled&&y<HEIGHT&&(x%STRIDE)==STRIDE/2&&(y%STRIDE)==STRIDE/2)begin
    sample_valid<=1;sample_gray<=gray;
   end
  end
 end
endmodule
