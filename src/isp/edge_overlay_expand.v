`timescale 1ns/1ps
// Display-only centered 3x3 dilation. No new edge detector or frame iteration.
// The original mask is delayed separately for an unchanged grayscale view.
module edge_overlay_expand #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,iv,ih,id,edge_in,
 output wire ov,oh,od,edge_original,edge_wide);
 wire valid,a,b,c,d,e,f,g,h,i;
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BITS(1)) w(
  clk,rst_n,iv,id,edge_in,valid,a,b,c,d,e,f,g,h,i);
 reg wide_q,valid_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin wide_q<=0;valid_q<=0;end
 else begin wide_q<=a|b|c|d|e|f|g|h|i;valid_q<=valid;end
 video_delay #(.BITS(4),.DELAY(H_TOTAL+4)) align(
  clk,rst_n,{iv,ih,id,edge_in},{ov,oh,od,edge_original});
 // At the outer image border preserve the original mask, never stale rows.
 assign edge_wide=od && (valid_q?wide_q:edge_original);
endmodule
