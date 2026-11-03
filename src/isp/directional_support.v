`timescale 1ns/1ps
// MODE 1: qualify same-direction/same-polarity support on both tangent sides.
// MODE 2: form seeds from repeated support OR robust response with strong neighbour.
// MODE 0: one bounded local link step, only along existing NMS candidates.
// No loops across frames and no synthesis of new edge pixels. H_TOTAL+4 cycles.
module directional_support #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200,MODE=0)(
 input wire clk,rst_n,iv,ih,id,input wire [6:0] token_i,
 output wire ov,oh,od,output wire [6:0] token_o);
 localparam D=H_TOTAL+4;
 wire valid;wire [6:0] p[0:8];
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BITS(7)) w(clk,rst_n,iv,id,token_i,valid,
 p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8]);
 wire [2:0] ori={p[4][6],p[4][4:3]};
 wire [8:0] aligned,accepted;genvar k;
 generate for(k=0;k<9;k=k+1)begin:neighbours
  wire [2:0] ndir={p[k][6],p[k][4:3]};
  wire [2:0] diff=ndir-ori;
  wire good=p[k][0] && (diff==0 || diff==1 || diff==7);
  assign aligned[k]=good && p[k][2];
  assign accepted[k]=good && p[k][1];
 end endgenerate
 reg [8:0] forward_mask,backward_mask;
 always @*case(p[4][4:3])
 0:begin forward_mask=9'h007;backward_mask=9'h1c0;end
 1:begin forward_mask=9'h026;backward_mask=9'h0c8;end
 2:begin forward_mask=9'h049;backward_mask=9'h124;end
 3:begin forward_mask=9'h00b;backward_mask=9'h1a0;end endcase
 wire coherent=p[4][2] && (|(aligned&forward_mask)) && (|(aligned&backward_mask));
 wire link=|(accepted&(forward_mask|backward_mask));
 wire seed=(p[4][1] && link) || coherent;
 reg [6:0] result;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)result<=0;
 else if(!valid || !p[4][0])result<=0;
 else if(MODE==1)result<={p[4][6:3],coherent,p[4][1:0]};
 else if(MODE==2)result<={p[4][6:2],seed,p[4][0]};
 else result<={p[4][6:2],(p[4][1] || link),p[4][0]};
 video_delay #(.BITS(3),.DELAY(D)) align(clk,rst_n,{iv,ih,id},{ov,oh,od});
 assign token_o=od?result:7'd0;
endmodule
