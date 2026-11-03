`timescale 1ns/1ps
`include "sim/shapes_case_count.vh"
module tb_shapes;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=0,fs=0,sv=0;reg [7:0] gray=0;
 wire busy,update,overflow;wire [7:0] valid;wire [23:0] cls;wire [63:0] x0,y0,x1,y1;
 shapes_core dut(clk,rst,en,fs,sv,gray,busy,update,valid,cls,x0,y0,x1,y1,overflow);
 localparam N=`SHAPE_CASES,PIX=32400;
 reg [7:0] pixels[0:N*PIX-1];reg [39:0] expected[0:N*9-1];
 integer first_case=0,last_case=N-1,arg_ok;
 integer c,p,f,cycles,max_cycles=0,i,j,n;reg matched;reg [7:0] consumed;
 task capture(input integer index);
 begin
  @(negedge clk);fs=1;@(negedge clk);fs=0;
  for(p=0;p<PIX;p=p+1)begin sv=1;gray=pixels[index*PIX+p];@(negedge clk);end
  sv=0;cycles=0;
  while(!update&&cycles<2000000)begin @(negedge clk);cycles=cycles+1;end
  if(!update)$fatal(1,"Timeout case=%0d state=%0d",index,dut.state);
  if(cycles>max_cycles)max_cycles=cycles;
  if(overflow)$fatal(1,"Unexpected overflow case=%0d",index);
 end endtask
 task check(input integer index);
 begin
  n=0;consumed=0;
  for(i=0;i<8;i=i+1)if(valid[i])begin
   n=n+1;matched=0;
   for(j=0;j<expected[index*9];j=j+1)begin
    if(!consumed[j]&&{5'd0,cls[i*3+:3],x0[i*8+:8],y0[i*8+:8],x1[i*8+:8],y1[i*8+:8]}===expected[index*9+1+j])begin matched=1;consumed[j]=1;end
   end
   if(!matched)$fatal(1,"Unexpected detection case=%0d class=%0d box=%0d,%0d,%0d,%0d",index,cls[i*3+:3],x0[i*8+:8],y0[i*8+:8],x1[i*8+:8],y1[i*8+:8]);
  end
  if(n!=expected[index*9])$fatal(1,"Wrong count case=%0d got=%0d expected=%0d",index,n,expected[index*9]);
 end endtask
 initial begin
  $readmemh("sim/shapes_input.hex",pixels);$readmemh("sim/shapes_expected.hex",expected);
  repeat(4)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  if(valid||busy)$fatal(1,"Boot must be OFF");
  arg_ok=$value$plusargs("START=%d",first_case);arg_ok=$value$plusargs("END=%d",last_case);
  for(c=first_case;c<=last_case;c=c+1)begin
   en=0;repeat(3)@(negedge clk);en=1;
   for(f=0;f<3;f=f+1)begin capture(c);if(f<2&&valid)$fatal(1,"Premature stability");end
   check(c);$display("CASE %0d objects=%0d compute_cycles=%0d",c,expected[c*9],cycles);
  end
  // Previous targets must disappear at the next empty result.
  capture(15);if(valid)$fatal(1,"Blank frame retained stale result");
  en=0;repeat(3)@(negedge clk);if(valid||busy)$fatal(1,"OFF failed to clear");
  $display("PASS F13 SHAPES cases=%0d stable_frames=3 max_compute_cycles=%0d",last_case-first_case+1,max_cycles);$finish;
 end
 initial begin #3000000000;$fatal(1,"Watchdog");end
endmodule
