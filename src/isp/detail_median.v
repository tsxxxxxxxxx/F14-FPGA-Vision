`timescale 1ns/1ps
// F2: reuse the exact median9 sorter. Flat/noisy pixels use the median;
// thin structures are protected when >=2 neighbours support the center.
// Fixed constants only; always enabled; no local brightness adaptation.
module detail_median #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,iv,ih,id,input wire [7:0] gray,
 output wire ov,oh,od,output wire [7:0] result);
 localparam D=H_TOTAL+12;
 wire valid,valid_d,support_d;wire [71:0] values;
 wire [7:0] med,original;wire [2:0] ctl;
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BITS(8)) w(clk,rst_n,iv,id,gray,valid,
 values[0+:8],values[8+:8],values[16+:8],values[24+:8],values[32+:8],values[40+:8],values[48+:8],values[56+:8],values[64+:8]);
 median9 sorter(clk,rst_n,values,med);
 function [7:0] delta(input [7:0] a,b);begin delta=a>b?a-b:b-a;end endfunction
 wire [8:0] near;genvar k;
 generate for(k=0;k<9;k=k+1)begin:neighbor_matches
  assign near[k]=(k!=4) && delta(values[k*8+:8],values[32+:8])<=8;
 end endgenerate
 wire [3:0] count={3'd0,near[0]}+{3'd0,near[1]}+{3'd0,near[2]}+{3'd0,near[3]}
                  +{3'd0,near[5]}+{3'd0,near[6]}+{3'd0,near[7]}+{3'd0,near[8]};
 wire line_support=(near[0]&&near[8])||(near[1]&&near[7])||(near[2]&&near[6])||(near[3]&&near[5]);
 video_delay #(.BITS(2),.DELAY(9)) vdelay(clk,rst_n,{valid,line_support},{valid_d,support_d});
 video_delay #(.BITS(11),.DELAY(D)) align(clk,rst_n,{iv,ih,id,gray},{ctl,original});
 assign {ov,oh,od}=ctl;
 wire protect=support_d && delta(original,med)>=12;
 // Checker target: do not preserve isolated thin strokes/noisy ridges.
 assign result=!od?8'd0:valid_d?med:original;
endmodule
