`timescale 1ns/1ps
// Fixed neutral-reference gains, Q8. Reuses multiply/round/saturate method
// from A2020_Algorithm_Lab/rtl/white_reference_awb.v, without its timed
// startup calibration (a scene is NOT assumed to be a neutral reference).
// Two registered stages. All synchronization signals follow the RGB path.
// Defaults are IDENTITY, not measured/calibrated SC2210 coefficients.
module rgb_white_balance #(
 parameter [10:0] GAIN_R_Q8=11'd256,
 parameter [10:0] GAIN_G_Q8=11'd256,
 parameter [10:0] GAIN_B_Q8=11'd256
)(
 input wire clk,rst_n,
 input wire in_vsync,in_hsync,in_de,input wire [23:0] in_rgb,
 output reg out_vsync,out_hsync,out_de,output reg [23:0] out_rgb
);
 reg [18:0] pr,pg,pb;
 reg [2:0] sync_stage;
 function [7:0] rounded_sat(input [18:0] p);
  begin rounded_sat=(|p[18:16])?8'hff:p[15:8];end
 endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  pr<=0;pg<=0;pb<=0;sync_stage<=3'b110;
  out_vsync<=1;out_hsync<=1;out_de<=0;out_rgb<=0;
 end else begin
  pr<=in_rgb[23:16]*GAIN_R_Q8+19'd128;
  pg<=in_rgb[15:8]*GAIN_G_Q8+19'd128;
  pb<=in_rgb[7:0]*GAIN_B_Q8+19'd128;
  sync_stage<={in_vsync,in_hsync,in_de};
  {out_vsync,out_hsync,out_de}<=sync_stage;
  out_rgb<=sync_stage[0]?{rounded_sat(pr),rounded_sat(pg),rounded_sat(pb)}:24'd0;
 end
endmodule
