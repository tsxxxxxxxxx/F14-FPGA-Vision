`timescale 1ns/1ps
// Six independent active-low inputs. No long-press or button chord functions.
module ddr_controls #(parameter DEBOUNCE_CYCLES=2970000)(
 input wire clk,rst_n,input wire [7:0] keys_n,input wire frame_vsync,
 output reg mode,output reg [10:0] threshold,
 output reg [2:0] request_mode,output reg request_toggle);
 (* async_reg="true" *) reg [7:0] keys_meta,keys_sync;
 reg [7:0] stable,press;reg [21:0] count[0:7];integer i;
 reg pending_mode,vs_d;reg [10:0] pending_threshold;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin keys_meta<=255;keys_sync<=255;stable<=255;press<=0;
  for(i=0;i<8;i=i+1)count[i]<=0;
 end else begin
  keys_meta<=keys_n;keys_sync<=keys_meta;press<=0;
  for(i=0;i<8;i=i+1)begin
   if(keys_sync[i]==stable[i])count[i]<=0;
   else if(count[i]==DEBOUNCE_CYCLES-1)begin
    count[i]<=0;stable[i]<=keys_sync[i];if(!keys_sync[i])press[i]<=1;
   end else count[i]<=count[i]+1'b1;
  end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin mode<=0;threshold<=80;pending_mode<=0;pending_threshold<=80;
  vs_d<=1;request_mode<=0;request_toggle<=0;end
 else begin
  vs_d<=frame_vsync;
  if(press[0]&&!press[1]&&pending_threshold<1024)pending_threshold<=pending_threshold+11'd8;
  if(press[1]&&!press[0]&&pending_threshold>16)pending_threshold<=pending_threshold-11'd8;
  if(press[2])pending_mode<=~pending_mode;
  // Simultaneous command priority is LIVE > HOLD > PLAY; never more than one.
  if(press[5])begin request_mode<=0;request_toggle<=~request_toggle;end
  else if(press[3])begin request_mode<=1;request_toggle<=~request_toggle;end
  else if(press[4])begin request_mode<=2;request_toggle<=~request_toggle;end
  else if(press[6]&&!press[7])begin request_mode<=3;request_toggle<=~request_toggle;end
  else if(press[7]&&!press[6])begin request_mode<=4;request_toggle<=~request_toggle;end
  if(vs_d&&!frame_vsync)begin mode<=pending_mode;threshold<=pending_threshold;end
 end
endmodule
