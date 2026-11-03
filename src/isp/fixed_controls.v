`timescale 1ns/1ps
// Two keys only. K1 short +8; K1 long -8/repeat. K2 short overlay,
// K2 long does nothing. Mixed/chord gestures are rejected until full release.
// There is no adaptive enable or filter bypass in this project.
module fixed_controls #(
 parameter DEBOUNCE_CYCLES=3000000,LONG_CYCLES=89286000,REPEAT_CYCLES=22321500
)(input wire clk,rst_n,input wire [1:0] keys_n,input wire frame_vsync,
 output reg mode,output reg [10:0] threshold);
 (* ASYNC_REG="TRUE" *) reg [1:0] keys_meta,keys_sync,keys_clean;
 reg [1:0] stable,previous,gesture;
 reg [31:0] debounce_count,hold_count,repeat_count;
 reg long_sent,vs_d,request_overlay;
 reg [10:0] request_high;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin keys_meta<=3;keys_sync<=3;keys_clean<=3;end
 else begin keys_meta<=keys_n;keys_sync<=keys_meta;keys_clean<=keys_sync;end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin stable<=3;debounce_count<=0;end
 else if(keys_clean==stable)debounce_count<=0;
 else if(debounce_count==DEBOUNCE_CYCLES-1)begin stable<=keys_clean;debounce_count<=0;end
 else debounce_count<=debounce_count+1'b1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  previous<=3;gesture<=3;hold_count<=0;repeat_count<=0;long_sent<=0;
  vs_d<=1;request_overlay<=0;request_high<=80;
  mode<=0;threshold<=80;
 end else begin
  previous<=stable;vs_d<=frame_vsync;
  if(vs_d && !frame_vsync)begin
   mode<=request_overlay;threshold<=request_high;
  end
  if(previous==3 && stable!=3)begin
   gesture<=stable;hold_count<=0;repeat_count<=0;long_sent<=0;
  end else if(stable==3 && previous!=3)begin
   if(!long_sent && gesture==2 && request_high<1024)request_high<=request_high+11'd8;
   if(!long_sent && gesture==1)request_overlay<=~request_overlay;
   gesture<=3;hold_count<=0;
  end else if(stable!=3 && gesture!=3)begin
   if(stable!=gesture)begin gesture<=0;long_sent<=1;end
   else if(gesture!=0)begin
    if(!long_sent)begin
     if(hold_count==LONG_CYCLES-1)begin
      long_sent<=1;repeat_count<=0;
      if(gesture==2 && request_high>16)request_high<=request_high-11'd8;
     end else hold_count<=hold_count+1'b1;
    end else if(gesture==2)begin
     if(repeat_count==REPEAT_CYCLES-1)begin
      repeat_count<=0;if(request_high>16)request_high<=request_high-11'd8;
     end else repeat_count<=repeat_count+1'b1;
    end
   end
  end
 end
endmodule
