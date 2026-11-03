`timescale 1ns/1ps
// F10: unchanged F9 detection/WB, display-only thick cyan contour.
module detail_pipeline #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,mode,input wire [10:0] threshold,
 input wire in_vsync,in_hsync,in_de,input wire [23:0] in_rgb,
 output reg out_vsync,out_hsync,out_de,output reg [23:0] out_rgb,
 output wire recog_vs,recog_de,output wire [7:0] recog_gray,
 input wire recognition_enabled,output reg shape_contour,output reg [23:0] clean_rgb);
 wire gv,gh,gd,mv,mh,md,fv,fh,fd,sv,sh,sd;
 wire [7:0] gray,median,filtered;wire [13:0] gradient;wire [21:0] vector;
 wire silhouette_s, silhouette_aligned;
 wire f1v,f1h,f1d;wire [7:0] smooth1;
 rgb888_to_gray g(clk,rst_n,in_vsync,in_hsync,in_de,in_rgb[23:16],in_rgb[15:8],in_rgb[7:0],gv,gh,gd,gray);
 detail_median #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) m(clk,rst_n,gv,gh,gd,gray,mv,mh,md,median);
 gray_gaussian #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) f(clk,rst_n,mv,mh,md,median,f1v,f1h,f1d,smooth1);
 gray_gaussian #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) f2(clk,rst_n,f1v,f1h,f1d,smooth1,fv,fh,fd,filtered);
 assign recog_vs=fv;assign recog_de=fd;assign recog_gray=filtered;
 sobel_gradient_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) s(clk,rst_n,fv,fh,fd,filtered,sv,sh,sd,gradient,vector,silhouette_s);
 wire [4:0] v,h,de;wire [6:0] tokens[0:4];
 interp_nms #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) n(clk,rst_n,sv,sh,sd,gradient,vector,threshold,v[0],h[0],de[0],tokens[0]);
 directional_support #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL),.MODE(1)) qual(clk,rst_n,v[0],h[0],de[0],tokens[0],v[1],h[1],de[1],tokens[1]);
 directional_support #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL),.MODE(2)) seed(clk,rst_n,v[1],h[1],de[1],tokens[1],v[2],h[2],de[2],tokens[2]);
 genvar k;generate for(k=0;k<2;k=k+1)begin:links
 directional_support #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) link(clk,rst_n,v[k+2],h[k+2],de[k+2],tokens[k+2],v[k+3],h[k+3],de[k+3],tokens[k+3]);
 end endgenerate
 wire ev,eh,ed,edge_raw,edge_wide;
 edge_overlay_expand #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) expand(
  clk,rst_n,v[4],h[4],de[4],tokens[4][1],ev,eh,ed,edge_raw,edge_wide);
 // Sobel -> NMS (H+5) -> four support (4H+16) -> expand (H+4).
 video_delay #(.BITS(1),.DELAY(6*H_TOTAL+25)) silhouette_delay(clk,rst_n,silhouette_s,silhouette_aligned);
 wire [7:0] original;
 video_delay #(.BITS(8),.DELAY(10*H_TOTAL+54)) gray_align(clk,rst_n,gray,original);
 // WB is display-only. Raw RGB above still drives the exact F7 edge pipeline.
 wire wb_v,wb_h,wb_de;wire [23:0] wb_rgb;
 rgb_white_balance #(.GAIN_R_Q8(11'd394),.GAIN_G_Q8(11'd256),.GAIN_B_Q8(11'd351)) wb(
  clk,rst_n,in_vsync,in_hsync,in_de,in_rgb,wb_v,wb_h,wb_de,wb_rgb);
 // Extend the existing RGB delay by H_TOTAL+4 to match centered expansion.
 wire [23:0] original_rgb;
 video_delay #(.BITS(24),.DELAY(10*H_TOTAL+55)) rgb_align(clk,rst_n,wb_rgb,original_rgb);
 reg [11:0] x;reg mode_q,recognition_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;mode_q<=0;recognition_q<=0;shape_contour<=0;clean_rgb<=0;out_vsync<=1;out_hsync<=1;out_de<=0;out_rgb<=0;end
 else begin
  if(!ev)begin x<=0;mode_q<=mode;recognition_q<=(recognition_enabled===1'b1);end else if(ed)x<=x==WIDTH-1?0:x+1'b1;
  out_vsync<=ev;out_hsync<=eh;out_de<=ed;
  shape_contour<=ed&&silhouette_aligned;clean_rgb<=ed?original_rgb:24'd0;
  out_rgb<=!ed?24'd0:recognition_q?original_rgb:
           (!mode_q && x<WIDTH/2)?{3{original}}:
           (mode_q ? (edge_wide ? 24'h00ffff : original_rgb) : {24{edge_raw}});
 end
endmodule
