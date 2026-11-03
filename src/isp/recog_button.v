`timescale 1ns/1ps
// Independent active-low toggle; commit only at a video frame boundary.
module recog_button #(parameter DEBOUNCE_CYCLES=2970000)(
 input wire clk,rst_n,key_n,frame_vsync,output reg enabled);
 (* async_reg="true" *) reg meta,sync;
 reg stable,pending,vs_d;reg [21:0] count;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin meta<=1;sync<=1;stable<=1;pending<=0;enabled<=0;vs_d<=1;count<=0;end
 else begin
  meta<=key_n;sync<=meta;vs_d<=frame_vsync;
  if(sync==stable)count<=0;
  else if(count==DEBOUNCE_CYCLES-1)begin
   count<=0;stable<=sync;if(!sync)pending<=~pending;
  end else count<=count+1'b1;
  if(vs_d&&!frame_vsync)enabled<=pending;
 end
endmodule
