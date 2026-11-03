`timescale 1ns/1ps
module tb_white_balance;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=1,hs=1,de=0;reg [23:0] rgb=0;
 wire [4:0] ov,oh,od;wire [23:0] pixels[0:4];
 rgb_white_balance a(clk,rst,vs,hs,de,rgb,ov[0],oh[0],od[0],pixels[0]);
 rgb_white_balance #(.GAIN_R_Q8(384),.GAIN_G_Q8(256),.GAIN_B_Q8(512)) b(clk,rst,vs,hs,de,rgb,ov[1],oh[1],od[1],pixels[1]);
 rgb_white_balance #(.GAIN_R_Q8(64),.GAIN_G_Q8(128),.GAIN_B_Q8(1024)) c(clk,rst,vs,hs,de,rgb,ov[2],oh[2],od[2],pixels[2]);
 rgb_white_balance #(.GAIN_R_Q8(1024),.GAIN_G_Q8(1024),.GAIN_B_Q8(1024)) d(clk,rst,vs,hs,de,rgb,ov[3],oh[3],od[3],pixels[3]);
 rgb_white_balance #(.GAIN_R_Q8(394),.GAIN_G_Q8(256),.GAIN_B_Q8(351)) e(clk,rst,vs,hs,de,rgb,ov[4],oh[4],od[4],pixels[4]);
 reg [26:0] expected[0:4];reg [23:0] previous;reg [2:0] ctrl;
 integer i,k,n=0;integer gr[0:4],gg[0:4],gb[0:4];
 function [7:0] ref_gain(input integer v,input integer gain);
  integer q;begin q=(v*gain+128)/256;ref_gain=q>255?255:q;end
 endfunction
 always @(posedge clk)begin
  if(!rst)begin ctrl=3'b110;previous=0;end
  else begin
   for(k=0;k<5;k=k+1)expected[k]={ctrl,ctrl[0]?{ref_gain(previous[23:16],gr[k]),ref_gain(previous[15:8],gg[k]),ref_gain(previous[7:0],gb[k])}:24'd0};
   ctrl={vs,hs,de};previous=rgb;
   #1;
   for(k=0;k<5;k=k+1)if({ov[k],oh[k],od[k],pixels[k]}!==expected[k])$fatal(1,"WB mismatch case%0d sample%0d",k,n);
   n+=1;
  end
 end
 initial begin
  gr[0]=256;gg[0]=256;gb[0]=256;
  gr[1]=384;gg[1]=256;gb[1]=512;
  gr[2]=64;gg[2]=128;gb[2]=1024;
  gr[3]=1024;gg[3]=1024;gb[3]=1024;
  gr[4]=394;gg[4]=256;gb[4]=351;
  repeat(5)@(negedge clk);rst=1;
  for(i=0;i<4096;i+=1)begin
   @(negedge clk);de=(i%17)!=0;vs=(i%137)>3;hs=(i%31)>2;
   rgb={8'(i),8'(i*73),8'(255-i)};
  end
  // Known green-cast neutral (80,120,60) -> (120,120,120) in instance b.
  @(negedge clk);de=1;vs=1;hs=1;rgb=24'h50783c;
  repeat(3)@(negedge clk);
  if(pixels[1]!==24'h787878)$fatal(1,"known neutral correction");
  // Approximate raw levels inferred from F8 screenshot neutral regions.
  @(negedge clk);rgb={8'd93,8'd147,8'd104};
  repeat(3)@(negedge clk);
  if(pixels[4]!=={8'd143,8'd147,8'd143})$fatal(1,"F9 checker white correction");
  @(negedge clk);rgb={8'd87,8'd131,8'd98};
  repeat(3)@(negedge clk);
  if(pixels[4]!=={8'd134,8'd131,8'd134})$fatal(1,"F9 paper white correction");
  @(negedge clk);rgb=24'hffffff;
  repeat(3)@(negedge clk);
  if(pixels[4]!==24'hffffff)$fatal(1,"F9 highlight saturation");
  rst=0;repeat(5)@(negedge clk);
  if(od!=0)$fatal(1,"reset de");
  rst=1;repeat(5)@(negedge clk);
  $display("PASS WHITE BALANCE: unity, 0.25x..4x, all 256 channel inputs, rounding, saturation, F9 394/256/351, checker/paper estimated neutrals, controls, reset");$finish;
 end
endmodule
