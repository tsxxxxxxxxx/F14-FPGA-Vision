`timescale 1ns/1ps
module tb_canny_capture_fifo;
 reg wc=0,rc=0,rst=1,wen=0,ren=0;reg [127:0] wd=0;
 always #3.367 wc=~wc;always #5.208 rc=~rc;
 wire full,empty;wire [4:0] wl,rl;wire [127:0] rd;
 canny_capture_fifo dut(rst,wc,wen,wd,full,wl,rc,ren,rd,empty,rl);
 integer sent=0,received=0,gap=0,rclocks=0;reg saw_capacity_full=0;
 reg [127:0] expected[0:511];reg [31:0] rng=32'h27f14c01;
 function [127:0] pattern(input [31:0] n);
 reg [31:0] a,b,c,d;
 begin a=n;b=~n;c=n*32'd1664525+32'd1013904223;d=c^32'h8badf00d;
  pattern={a,b,c,d};end
 endfunction
 always @(negedge wc)begin
  wen=0;
  if(!rst)begin
   if(gap>0)gap=gap-1;
   if(gap==0&&!full&&sent<512)begin wd=pattern(sent);wen=1;gap=64;end
   if(full&&!dut.writing)saw_capacity_full=1;
  end
 end
 always @(posedge wc)if(!rst&&wen&&!full)begin expected[sent]=wd;sent=sent+1;end
 always @(negedge rc)begin
  rclocks=rclocks+1;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  ren=!rst&&rclocks>4000&&!empty&&rng[0];
 end
 always @(posedge rc)if(!rst&&ren&&!empty)begin
  if(received>=sent||rd!==expected[received])
   $fatal(1,"capture FIFO ordering word=%0d got=%h expected=%h",received,rd,expected[received]);
  received=received+1;
 end
 initial begin
  repeat(10)@(negedge wc);rst=0;
  wait(received==512);repeat(20)@(negedge rc);
  if(sent!=512||!saw_capacity_full||!empty||wl!=0||rl!=0)
   $fatal(1,"capacity/drain sent=%0d full_seen=%b empty=%b levels=%0d/%0d",sent,saw_capacity_full,empty,wl,rl);
  $display("PASS CANNY CAPTURE FIFO words=512 full-capacity stall, exact 128-bit order, pointer wrap, clean drain");
  $finish;
 end
 initial begin repeat(100000)@(posedge wc);$fatal(1,"capture FIFO timeout");end
endmodule
