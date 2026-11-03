`timescale 1ns/1ps
module tb_shapes_safety;
 reg clk=0;always #5 clk=~clk;reg rst=0,en=0,fs=0,sv=0;reg [7:0] gray=255;
 wire busy,update,overflow;wire [7:0] valid;wire [23:0] cls;wire [63:0] x0,y0,x1,y1;
 shapes_core dut(clk,rst,en,fs,sv,gray,busy,update,valid,cls,x0,y0,x1,y1,overflow);
 integer x,y,f,n,cycles;reg [7:0] pixel;
 task capture(input integer which);
 begin
  @(negedge clk);fs=1;@(negedge clk);fs=0;
  for(y=0;y<135;y=y+1)for(x=0;x<240;x=x+1)begin
   pixel=240;
   case(which)
    0:if(x>=40&&x<72&&y>=40&&y<72)pixel=20;
    1:if(x>=160&&x<192&&y>=60&&y<92)pixel=20;
    2:if(x%15>=5&&x%15<8&&y%15>=5&&y%15<8)pixel=20;
    3:if(x>=10&&x<160&&y>=10&&y<130&&(x-10)%50<24&&(y-10)%40<24)pixel=20;
    5:if((y<30&&x%10>=3&&x%10<6&&y%10>=3&&y%10<6)||(x>=100&&x<132&&y>=60&&y<92))pixel=20;
   endcase
   sv=1;gray=pixel;@(negedge clk);
  end
  sv=0;cycles=0;
  while(!update&&cycles<2000000)begin @(negedge clk);cycles=cycles+1;end
  if(!update)$fatal(1,"Safety timeout");
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;en=1;
  for(f=0;f<3;f=f+1)capture(0);
  if(!valid||cls[2:0]!=1)$fatal(1,"Initial square failed");
  capture(1);if(valid)$fatal(1,"Moved target inherited stability");capture(1);if(valid)$fatal(1,"Stabilized too early");capture(1);if(!valid)$fatal(1,"Moved target never stabilized");
  capture(2);if(valid||!overflow)$fatal(1,"Label overflow must clear all results");
  capture(3);if(valid||!overflow)$fatal(1,"Object overflow must clear all results");
  for(f=0;f<3;f=f+1)capture(0);if(!valid||overflow)$fatal(1,"Recovery after overflow failed");
  for(f=0;f<3;f=f+1)capture(5);
  if(overflow||valid!==8'h01||cls[2:0]!=1||x0[7:0]!=100||y0[7:0]!=60)$fatal(1,"Target after 72 clutter labels failed");
  // Restart an incomplete frame. White prefix must not leak into new capture.
  @(negedge clk);fs=1;@(negedge clk);fs=0;sv=1;gray=0;repeat(95)@(negedge clk);sv=0;
  capture(4);if(valid)$fatal(1,"Incomplete frame retained stale target");
  // Cancel during capture, then demand three fresh matching results.
  @(negedge clk);fs=1;@(negedge clk);fs=0;sv=1;gray=0;repeat(95)@(negedge clk);en=0;sv=0;
  repeat(3)@(negedge clk);if(valid||busy)$fatal(1,"Disable failed");en=1;
  capture(0);if(valid)$fatal(1,"Stale stability after enable");capture(0);capture(0);if(!valid)$fatal(1,"Enable recovery failed");
  $display("PASS F13 SAFETY: spatial stability; 72 clutter labels before target; >95 labels; >8 targets; incomplete frame; OFF cancel; recovery");$finish;
 end
 initial begin #600000000;$fatal(1,"Safety watchdog");end
endmodule

