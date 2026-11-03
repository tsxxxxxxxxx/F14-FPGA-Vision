`timescale 1ns/1ps
module tb_canny_fps;
 reg clk=0,reset=1,en=0,pulse=0,all_frames=0;
 always #5 clk=~clk;
 wire [7:0] fps,fps_long;
 canny_fps #(.CLOCK_HZ(8)) a(clk,reset,en,pulse,fps);
 canny_fps #(.CLOCK_HZ(260)) b(clk,reset,en,all_frames,fps_long);
 integer i,windows=0;
 initial begin
  repeat(3)@(negedge clk);reset=0;en=1;all_frames=1;
  for(i=1;i<=520;i=i+1)begin
   pulse=(i<=8)&&(i%2==0);
   @(posedge clk);#1;
   if(i==8&&fps!=4)$fatal(1,"closing-edge event lost: fps=%0d",fps);
   if(i==16&&fps!=0)$fatal(1,"quiet window did not clear");
   if((i==260||i==520)&&fps_long!=255)$fatal(1,"saturation/window error");
   @(negedge clk);
  end
  en=0;pulse=1;@(posedge clk);#1;
  if(fps!=0||fps_long!=0)$fatal(1,"disabled counter not cleared");
  @(negedge clk);en=1;all_frames=0;
  repeat(8)begin @(posedge clk);#1;@(negedge clk);end
  if(fps!=8)$fatal(1,"restart window mismatch");
  $display("PASS CANNY FPS closing-edge publication, quiet window, saturation, disable/re-enable");
  $finish;
 end
endmodule
