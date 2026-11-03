`timescale 1ns/1ps
// Fixed-cycle delay, including blanking. RAM version avoids a large FF chain.
module video_delay #(parameter BITS=27, DELAY=3)(
 input wire clk, rst_n, input wire [BITS-1:0] din,
 output wire [BITS-1:0] dout);
 generate if(DELAY==0) begin: direct_path
   assign dout=din;
 end else if(DELAY<=16) begin: registers
   reg [BITS-1:0] pipe[0:DELAY-1]; integer i;
   always @(posedge clk or negedge rst_n)
    if(!rst_n) for(i=0;i<DELAY;i=i+1) pipe[i]<=0;
    else begin pipe[0]<=din; for(i=1;i<DELAY;i=i+1) pipe[i]<=pipe[i-1]; end
   assign dout=pipe[DELAY-1];
 end else begin: ring
   reg [BITS-1:0] mem[0:DELAY-1]; reg [BITS-1:0] q;
   reg [15:0] wp,rp,fill; reg ready;
   always @(posedge clk) if(rst_n) begin mem[wp]<=din; q<=mem[rp]; end
   always @(posedge clk or negedge rst_n)
    if(!rst_n) begin wp<=0; rp<=1; fill<=0; ready<=0; end
    else begin
     wp<=wp==DELAY-1 ? 0 : wp+1'b1;
     rp<=rp==DELAY-1 ? 0 : rp+1'b1;
     if(fill<DELAY-1) fill<=fill+1'b1;
     ready<=fill==DELAY-1;
    end
   assign dout=ready?q:{BITS{1'b0}};
 end endgenerate
endmodule
