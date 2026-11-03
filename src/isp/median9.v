`timescale 1ns/1ps
// Exact nine-value median. Nine pipelined odd/even compare-exchange passes.
// One window/clock after filling; duplicates and 0/255 included.
module median9(input wire clk,rst_n,input wire [71:0] samples_i,
 output wire [7:0] median_o);
 wire [71:0] stage[0:9]; assign stage[0]=samples_i;
 genvar s,k;
 generate for(s=0;s<9;s=s+1) begin: pass
   reg [71:0] q;
   for(k=0;k<9;k=k+1) begin: element
     if((k%2)==(s%2) && k<8) begin: lo
       always @(posedge clk or negedge rst_n)
       if(!rst_n) q[k*8+:8]<=0;
       else q[k*8+:8]<=stage[s][k*8+:8]<stage[s][(k+1)*8+:8]?stage[s][k*8+:8]:stage[s][(k+1)*8+:8];
     end else if(k>0 && ((k-1)%2)==(s%2)) begin: hi
       always @(posedge clk or negedge rst_n)
       if(!rst_n) q[k*8+:8]<=0;
       else q[k*8+:8]<=stage[s][k*8+:8]>stage[s][(k-1)*8+:8]?stage[s][k*8+:8]:stage[s][(k-1)*8+:8];
     end else begin: hold
       always @(posedge clk or negedge rst_n)
       if(!rst_n) q[k*8+:8]<=0; else q[k*8+:8]<=stage[s][k*8+:8];
     end
   end
   assign stage[s+1]=q;
 end endgenerate
 assign median_o=stage[9][4*8+:8];
endmodule
