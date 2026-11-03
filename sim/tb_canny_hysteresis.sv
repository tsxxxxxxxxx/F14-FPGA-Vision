module tb_canny_hysteresis;
`ifdef FULL_HD
 localparam W=1920,H=1080,CASES=6;
`else
 localparam W=256,H=64,CASES=30;
`endif
 localparam WORDS=W*H/64,BASE=32'h08000000;
 reg clk=0,reset=1,start=0,cancel=0;always #2.604 clk=~clk;
 wire busy,done,error,mvalid,mwrite;wire [15:0] passes;wire [31:0] cycles,ma;wire [127:0] mw;
 reg ready=0,mdone=0,merror=0;reg [127:0] mr=0;
 canny_hysteresis #(.WIDTH(W),.HEIGHT(H)) dut(clk,reset,start,cancel,BASE,busy,done,error,passes,cycles,mvalid,mwrite,ma,mw,ready,mdone,merror,mr);
 reg [127:0] inputs[0:WORDS*CASES-1],gold[0:WORDS*CASES-1],memory[0:WORDS-1];
 reg [31:0] rng=32'h1080cafe;reg outstanding=0;
 integer delay=0,idx=0,i,c,checks=0,limit=0;reg write_saved;reg [127:0] data_saved;
 integer maxcycles=0,maxpasses=0;
 always @(negedge clk)begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  ready=!outstanding&&!mdone&&rng[0];mdone=0;
  if(outstanding)begin
   if(delay==0)begin
    if(write_saved)memory[idx]=data_saved;else mr=memory[idx];
    mdone=1;outstanding=0;
   end else delay=delay-1;
  end
 end
 always @(posedge clk)if(!reset&&mvalid&&ready)begin
  if(ma<BASE||ma>=BASE+WORDS*16||ma[3:0]!=0)$fatal(1,"bad address %h",ma);
  if(outstanding)$fatal(1,"overlap");
  outstanding=1;idx=(ma-BASE)/16;write_saved=mwrite;data_saved=mw;delay=2+rng[3:1];
 end
 initial begin
`ifdef FULL_HD
  $readmemh("sim/canny_input_full.hex",inputs);$readmemh("sim/canny_expected_full.hex",gold);
`else
  $readmemh("sim/canny_input_small.hex",inputs);$readmemh("sim/canny_expected_small.hex",gold);
`endif
  repeat(5)@(negedge clk);reset=0;
  for(c=0;c<CASES;c=c+1)begin
   for(i=0;i<WORDS;i=i+1)memory[i]=inputs[c*WORDS+i];
   @(negedge clk);start=1;@(negedge clk);start=0;limit=0;
   while(!done)begin @(negedge clk);limit=limit+1;
    if(error||limit>1000000000)$fatal(1,"error/timeout case %0d state %0d",c,dut.state);
   end
   for(i=0;i<WORDS;i=i+1)begin
    if(memory[i]!==gold[c*WORDS+i])$fatal(1,"case %0d word %0d got %h expected %h",c,i,memory[i],gold[c*WORDS+i]);
    checks=checks+64;
   end
   if(cycles>maxcycles)maxcycles=cycles;if(passes>maxpasses)maxpasses=passes;
   $display("CASE %0d exact_pixels=%0d passes=%0d cycles=%0d",c,W*H,passes,cycles);
   @(negedge clk);
  end
  $display("PASS CANNY HYSTERESIS %0dx%0d cases=%0d pixels=%0d max_passes=%0d max_cycles=%0d",W,H,CASES,checks,maxpasses,maxcycles);$finish;
 end
endmodule
