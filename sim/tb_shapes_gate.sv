`timescale 1ns/1ps
module tb_shapes_gate;
 reg [23:0] rgb;wire [7:0] gray;
 shapes_pixel_gate dut(rgb,gray);
 integer r,g,b,hi,lo,luma,expect_gray,n=0;
 task check;
 begin
  #1;r=rgb[23:16];g=rgb[15:8];b=rgb[7:0];
  hi=r>g?r:g;if(b>hi)hi=b;lo=r<g?r:g;if(b<lo)lo=b;
  luma=(r+2*g+b)/4;expect_gray=hi-lo>48&&luma<96?128:luma;
  if(gray!==expect_gray[7:0])$fatal(1,"Pixel gate rgb=%h got=%d expected=%d",rgb,gray,expect_gray);
  n=n+1;
 end endtask
 integer i,j,k;
 initial begin
  for(i=0;i<256;i=i+1)begin rgb={i[7:0],i[7:0],i[7:0]};check;end
  for(i=0;i<256;i=i+7)for(j=0;j<256;j=j+7)for(k=0;k<256;k=k+7)begin rgb={i[7:0],j[7:0],k[7:0]};check;end
  rgb=24'hffffff;check;rgb=24'h000000;check;rgb=24'h909090;check;
  for(i=0;i<10000;i=i+1)begin rgb=$random;check;end
  $display("PASS F13 PIXEL GATE cases=%0d shaded paper preserved; saturated dark exclusion; sized RGB arithmetic",n);$finish;
 end
endmodule
