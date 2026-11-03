`timescale 1ns/1ps
// Detail NMS locates edges. Stable magnitude (normal-axis +/-1 pixel) supplies
// confidence without requiring exact peak co-location. Thresholds fixed/frame.
// Token: polarity[6], robust[5], direction[4:3], agree[2], strong[1], weak[0].
module dual_detail_nms #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,iv,ih,id,input wire [13:0] detail,stable,
 input wire [10:0] threshold,output wire ov,oh,od,output wire [6:0] token);
 localparam D=H_TOTAL+5;
 wire valid;wire [24:0] a,b,c,d,e,f,g,h,i;
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BITS(25)) w(clk,rst_n,iv,id,{stable[10:0],detail},valid,a,b,c,d,e,f,g,h,i);
 reg [11:0] x,y;
 always @(posedge clk or negedge rst_n)if(!rst_n)begin x<=0;y<=0;end
 else if(!iv)begin x<=0;y<=0;end else if(id)if(x==WIDTH-1)begin x<=0;if(y<HEIGHT)y<=y+1'b1;end else x<=x+1'b1;
 wire inside_d;
 video_delay #(.BITS(1),.DELAY(2)) mask(clk,rst_n,id && x>=3 && x<WIDTH-1 && y>=3 && y<HEIGHT-1,inside_d);
 reg [10:0] before_mag,after_mag,sb,sa;
 always @*case(e[12:11])
 0:begin before_mag=d[10:0];after_mag=f[10:0];sb=d[24:14];sa=f[24:14];end
 1:begin before_mag=a[10:0];after_mag=i[10:0];sb=a[24:14];sa=i[24:14];end
 2:begin before_mag=b[10:0];after_mag=h[10:0];sb=b[24:14];sa=h[24:14];end
 3:begin before_mag=c[10:0];after_mag=g[10:0];sb=c[24:14];sa=g[24:14];end endcase
 wire [10:0] side=sb>sa?sb:sa;
 wire [10:0] best=e[24:14]>side?e[24:14]:side;
 reg [10:0] active_threshold,mag,support_mag,th;
 reg peak;reg [2:0] orientation;reg [6:0] token_q;
 wire [10:0] low=(th>>1)+(th>>2);
 wire is_weak=peak && mag>=low && support_mag>=(low>>1);
 wire is_strong=mag>=th && support_mag>=th;
 wire robust={1'b0,mag}>={th,1'b0} && {1'b0,support_mag}>=({1'b0,th}+{2'b00,th[10:1]});
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin active_threshold<=80;mag<=0;support_mag<=0;th<=80;peak<=0;orientation<=0;token_q<=0;end
 else begin
  if(!iv)active_threshold<=threshold;
  peak<=valid && inside_d && e[10:0]>before_mag && e[10:0]>=after_mag;
  mag<=e[10:0];support_mag<=best;th<=active_threshold;orientation<=e[13:11];
  token_q<=is_weak?{orientation[2],robust,orientation[1:0],(support_mag>=low),is_strong,1'b1}:7'd0;
 end
 video_delay #(.BITS(3),.DELAY(D)) align(clk,rst_n,{iv,ih,id},{ov,oh,od});
 assign token=od?token_q:7'd0;
endmodule
