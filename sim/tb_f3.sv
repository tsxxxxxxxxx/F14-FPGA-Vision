`timescale 1ns/1ps
module tb_f3;
`ifdef FULL_HD
 localparam W=1920,H=1080,HT=2200,VT=1125,NF=2;
`else
 localparam W=96,H=64,HT=120,VT=100,NF=8;
`endif
 localparam PIX=W*H*NF,LAT=10*HT+58;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,iv=1,ih=1,id=0,mode=0;reg [10:0] threshold=80;reg [23:0] rgb=0;
 wire ov,oh,od;wire [23:0] out;
 detail_pipeline #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut(clk,rst,mode,threshold,iv,ih,id,rgb,ov,oh,od,out,,,,1'b0,,);
 reg [23:0] inp[0:PIX-1],gold[0:PIX-1];reg [2:0] queue[0:LAT-1];
 integer p=0,seen=0,cycles=0,frame,x,y,j;
`ifndef FULL_HD
 wire [7:0] stage_de={dut.de[4],dut.de[3],dut.de[2],dut.de[1],dut.de[0],dut.fd,dut.md,dut.gd};
 wire [23:0] value[0:7];
 assign value[0]=dut.gray;assign value[1]=dut.median;assign value[2]=dut.filtered;
 genvar s;generate for(s=0;s<5;s=s+1)begin:v assign value[s+3]=dut.tokens[s];end
 for(s=0;s<8;s=s+1)begin:stages
  reg [23:0] expected[0:PIX-1];integer count=0;
  initial case(s)
   0:$readmemh("sim/gray_small.hex",expected);1:$readmemh("sim/median_small.hex",expected);
   2:$readmemh("sim/filtered_small.hex",expected);3:$readmemh("sim/candidate_small.hex",expected);
   4:$readmemh("sim/qualified_small.hex",expected);5:$readmemh("sim/seed_small.hex",expected);
   6:$readmemh("sim/link1_small.hex",expected);7:$readmemh("sim/linked_small.hex",expected);
  endcase
  always @(posedge clk)if(rst)begin #1;if(stage_de[s])begin
   if(count>=PIX || value[s]!==expected[count])$fatal(1,"STAGE %0d pixel %0d got %h expected %h",s,count,value[s],expected[count]);count=count+1;
  end end
 end endgenerate
`endif
 always @(posedge clk)begin
  if(!rst)begin p=0;cycles=0;for(j=0;j<LAT;j=j+1)queue[j]=0;end
  else begin #1;
   if(cycles>=LAT-1 && {ov,oh,od}!==queue[(p+1)%LAT])$fatal(1,"Raster mismatch cycle %0d",cycles);
   queue[p]={iv,ih,id};p=(p+1)%LAT;cycles=cycles+1;
   if(od)begin
    if(seen>=PIX || out!==gold[seen])$fatal(1,"VIDEO pixel %0d got %h expected %h",seen,out,gold[seen]);
    seen=seen+1;if(seen%(W*128)==0)$display("F10 pixels %0d/%0d",seen,PIX);
   end
  end
 end
 initial begin
`ifdef FULL_HD
  $readmemh("sim/input_1080p.hex",inp);$readmemh("sim/output_1080p.hex",gold);
`else
  $readmemh("sim/input_small.hex",inp);$readmemh("sim/output_small.hex",gold);
`endif
  repeat(5)@(negedge clk);rst=1;
  for(frame=0;frame<NF;frame=frame+1)begin
   mode=frame%2;threshold=frame==2?16:frame==3?1024:80;
   for(y=0;y<VT;y=y+1)for(x=0;x<HT;x=x+1)begin
    @(negedge clk);iv=y>=2;ih=x>=4;id=y>=12&&y<12+H&&x>=8&&x<8+W;
    rgb=id?inp[frame*W*H+(y-12)*W+x-8]:24'd0;
   end
  end
  @(negedge clk);id=0;iv=0;ih=1;rgb=0;
  repeat(LAT+100)@(negedge clk);
  if(seen!=PIX)$fatal(1,"Missing pixels");
  $display("PASS F10 VIDEO %0dx%0d frames=%0d pixels=%0d latency=%0d CYAN_OVERLAY",W,H,NF,seen,LAT);$finish;
 end
endmodule
