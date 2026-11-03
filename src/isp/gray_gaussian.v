`timescale 1ns/1ps
module gray_gaussian #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,iv,ih,id,input wire [7:0] gray,
 output wire ov,oh,od,output wire [7:0] filtered);
 wire valid;wire [7:0] a,b,c,d,e,f,g,h,i;
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BITS(8)) w(clk,rst_n,iv,id,gray,valid,a,b,c,d,e,f,g,h,i);
 function ridge(input [7:0] center,t0,t1,n0,n1);
 reg [7:0] da,db,dc,dd;
 begin da=center>t0?center-t0:t0-center;db=center>t1?center-t1:t1-center;
 dc=center>n0?center-n0:n0-center;dd=center>n1?center-n1:n1-center;
 ridge=da<=8&&db<=8&&dc>=12&&dd>=12&&((center>n0)==(center>n1));end endfunction
 wire protect=ridge(e,b,h,d,f)||ridge(e,d,f,b,h)||ridge(e,a,i,c,g)||ridge(e,c,g,a,i);
 reg [11:0] sum;reg [7:0] result,center_q;reg v1,v2,protect_q;
 wire [12:0] mixed={1'b0,sum}+{1'b0,center_q,4'b0}+13'd8;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin sum<=0;result<=0;v1<=0;v2<=0;center_q<=0;protect_q<=0;end
 else begin
  sum<={4'd0,a}+{3'd0,b,1'b0}+{4'd0,c}+{3'd0,d,1'b0}+{2'd0,e,2'b0}+{3'd0,f,1'b0}+{4'd0,g}+{3'd0,h,1'b0}+{4'd0,i}+12'd8;
  result<=sum[11:4];v1<=valid;v2<=v1;center_q<=e;protect_q<=protect;
 end
 wire [7:0] original;
 video_delay #(.BITS(11),.DELAY(H_TOTAL+5)) align(clk,rst_n,{iv,ih,id,gray},{ov,oh,od,original});
 assign filtered=!od?0:v2?result:original;
endmodule
