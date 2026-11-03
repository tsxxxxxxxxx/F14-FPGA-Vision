`timescale 1ns/1ps
module tb_canny_cancel;
 localparam W=128,H=8,WORDS=W*H/64,BASE=32'h08000000;
 reg clk=0,reset=1,start=0,cancel=0;
 always #5.208 clk=~clk;
 wire busy,done,error,mvalid,mwrite;
 wire [15:0] passes;wire [31:0] cycles,ma;wire [127:0] mw;
 reg ready=0,mdone=0,merror=0;reg [127:0] mr=0;
 canny_hysteresis #(.WIDTH(W),.HEIGHT(H)) dut(
  clk,reset,start,cancel,BASE,busy,done,error,passes,cycles,
  mvalid,mwrite,ma,mw,ready,mdone,merror,mr);
 reg [127:0] memory[0:WORDS-1],saved;
 reg outstanding=0,writing=0;
 integer addr=0,delay=0,mode=0,i,j,checks=0;reg observed_done=0;
 always @(posedge clk)if(done)observed_done=1;
 always @(negedge clk)begin
  ready=!outstanding&&!mdone;mdone=0;merror=0;
  if(outstanding)begin
   if(delay>0)delay=delay-1;
   else begin
    outstanding=0;mdone=1;
    merror=(mode==2&&!writing)||(mode==3&&writing);
    if(writing)memory[addr]=saved;else mr=memory[addr];
   end
  end
 end
 always @(posedge clk)if(!reset&&mvalid&&ready)begin
  if(outstanding)$fatal(1,"overlapping memory transaction");
  if(ma<BASE||ma>=BASE+WORDS*16||ma[3:0])$fatal(1,"private map bounds");
  addr=(ma-BASE)>>4;writing=mwrite;saved=mw;outstanding=1;delay=7;
 end
 task launch;
 begin
  if(outstanding||busy)$fatal(1,"restart before transaction drain");
  for(i=0;i<WORDS;i=i+1)memory[i]=0;
  for(i=0;i<W;i=i+1)memory[4+i/64][(i%64)*2+:2]=(i==0)?2'b11:2'b01;
  observed_done=0;cancel=0;
  @(negedge clk);start=1;@(negedge clk);start=0;
  wait(busy);
 end
 endtask
 initial begin
  repeat(6)@(negedge clk);reset=0;
  mode=1;launch();wait(outstanding);@(negedge clk);cancel=1;
  wait(!busy);#1;
  if(outstanding||observed_done||error)$fatal(1,"cancel did not drain safely");
  checks=checks+1;cancel=0;repeat(3)@(negedge clk);
  mode=2;launch();wait(!busy);#1;
  if(!error||outstanding||observed_done)$fatal(1,"read error published or stuck");
  checks=checks+1;repeat(3)@(negedge clk);
  mode=3;launch();wait(!busy);#1;
  if(!error||outstanding||observed_done)$fatal(1,"write error published or stuck");
  checks=checks+1;repeat(3)@(negedge clk);
  mode=0;launch();wait(!busy);#1;
  if(error||outstanding||!done)$fatal(1,"clean restart failed");
  for(i=0;i<WORDS;i=i+1)for(j=0;j<64;j=j+1)begin
   if(memory[i][2*j+:2]!==((i==4||i==5)?2'b11:2'b00))$fatal(1,"restart data mismatch");
   checks=checks+1;
  end
  $display("PASS CANNY CANCEL checks=%0d accepted-read drain, read/write errors, clean restart",checks);
  $finish;
 end
 initial begin repeat(100000)@(posedge clk);$fatal(1,"cancel test timeout");end
endmodule
