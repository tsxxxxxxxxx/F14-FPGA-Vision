`timescale 1ns/1ps
// Division-free interpolated NMS; registered products, asymmetric ties.
module interp_nms #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,iv,ih,id,input wire [13:0] gradient,input wire [21:0] vector,
 input wire [10:0] threshold,output wire ov,oh,od,output wire [6:0] token);
 wire valid;wire [35:0] a,b,c,d,e,f,g,h,i;
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BITS(36)) w(clk,rst_n,iv,id,{vector,gradient},valid,a,b,c,d,e,f,g,h,i);
 wire signed [10:0] gx=e[35:25],gy=e[24:14];
 wire [10:0] ax=gx[10]?-gx:gx,ay=gy[10]?-gy:gy;
 wire horizontal=ax>=ay,same=gx[10]==gy[10];
 wire [10:0] major=horizontal?ax:ay,minor=horizontal?ay:ax;
 wire [10:0] bm=horizontal?d[10:0]:b[10:0],am=horizontal?f[10:0]:h[10:0];
 wire [10:0] bd=same?a[10:0]:horizontal?g[10:0]:c[10:0];
 wire [10:0] ad=same?i[10:0]:horizontal?c[10:0]:g[10:0];
 reg [11:0] x,y;wire inside_d;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;end
 else if(!iv)begin x<=0;y<=0;end
 else if(id)if(x==WIDTH-1)begin x<=0;if(y<HEIGHT)y<=y+1'b1;end else x<=x+1'b1;
 video_delay #(.BITS(1),.DELAY(2)) mask(clk,rst_n,id&&x>=3&&x<WIDTH-1&&y>=3&&y<HEIGHT-1,inside_d);
 reg [21:0] pc,pb0,pb1,pa0,pa1;reg vq;reg [10:0] mag,th,active_th;reg [2:0] ori;reg [6:0] q;
 wire [10:0] low=(th>>1)<8?11'd8:(th>>1);
 wire peak=vq && {1'b0,pc}>({1'b0,pb0}+{1'b0,pb1}) && {1'b0,pc}>=({1'b0,pa0}+{1'b0,pa1});
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pc<=0;pb0<=0;pb1<=0;pa0<=0;pa1<=0;vq<=0;mag<=0;th<=80;active_th<=80;ori<=0;q<=0;end
 else begin
  if(!iv)active_th<=threshold;
  pc<=e[10:0]*major;pb0<=bm*(major-minor);pb1<=bd*minor;pa0<=am*(major-minor);pa1<=ad*minor;
  mag<=e[10:0];ori<=e[13:11];th<=active_th;vq<=valid&&inside_d;
  q<=peak&&mag>=low?{ori[2],({1'b0,mag}>={th,1'b0}),ori[1:0],(mag>=((th>>1)+(th>>2))),(mag>=th),1'b1}:7'd0;
 end
 video_delay #(.BITS(3),.DELAY(H_TOTAL+5)) align(clk,rst_n,{iv,ih,id},{ov,oh,od});
 assign token=od?q:7'd0;
endmodule
