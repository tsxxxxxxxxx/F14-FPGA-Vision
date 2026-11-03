`timescale 1ns/1ps
// 3x3 quantized bilateral-like filter. Center16, cardinal2, diagonal1.
// Fixed-point reciprocals; 2 arithmetic stages. Border and bypass aligned.
module range_filter #(parameter WIDTH=1920,HEIGHT=1080,H_TOTAL=2200)(
 input wire clk,rst_n,enhance,iv,ih,id,input wire [7:0] gray,noise,
 output wire ov,oh,od,output wire [7:0] result,noise_o,original_o);
 localparam D=H_TOTAL+5;
 wire valid;wire [23:0] a,b,c,d,e,f,g,h,i;
 window3x3_rgb #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) w(clk,rst_n,iv,id,{16'd0,gray},valid,a,b,c,d,e,f,g,h,i);
 function [3:0] weight(input [7:0] p,q,input cardinal);
 reg [7:0] delta;reg [2:0] rw;
 begin delta=p>q?p-q:q-p;rw=delta<=8?4:delta<=16?2:delta<=32?1:0;
 weight=cardinal?{rw,1'b0}:{1'b0,rw};end endfunction
 wire [3:0] wa=weight(a[7:0],e[7:0],1'b0),wb=weight(b[7:0],e[7:0],1'b1),
 wc=weight(c[7:0],e[7:0],1'b0),wd=weight(d[7:0],e[7:0],1'b1),
 wf=weight(f[7:0],e[7:0],1'b1),wg=weight(g[7:0],e[7:0],1'b0),
 wh=weight(h[7:0],e[7:0],1'b1),wi=weight(i[7:0],e[7:0],1'b0);
 function [11:0] weighted(input [7:0] p,input [3:0] wt);
 begin case(wt)1:weighted={4'd0,p};2:weighted={3'd0,p,1'b0};
 4:weighted={2'd0,p,2'b0};8:weighted={1'd0,p,3'b0};default:weighted=0;endcase end endfunction
 reg [13:0] sum;reg [6:0] count;reg [31:0] product;reg v1,v2;
 reg [12:0] reciprocal;
 always @*case(count)
 16:reciprocal=13'd4096;
 17:reciprocal=13'd3855;
 18:reciprocal=13'd3640;
 19:reciprocal=13'd3449;
 20:reciprocal=13'd3276;
 21:reciprocal=13'd3120;
 22:reciprocal=13'd2978;
 23:reciprocal=13'd2849;
 24:reciprocal=13'd2730;
 25:reciprocal=13'd2621;
 26:reciprocal=13'd2520;
 27:reciprocal=13'd2427;
 28:reciprocal=13'd2340;
 29:reciprocal=13'd2259;
 30:reciprocal=13'd2184;
 31:reciprocal=13'd2114;
 32:reciprocal=13'd2048;
 33:reciprocal=13'd1985;
 34:reciprocal=13'd1927;
 35:reciprocal=13'd1872;
 36:reciprocal=13'd1820;
 37:reciprocal=13'd1771;
 38:reciprocal=13'd1724;
 39:reciprocal=13'd1680;
 40:reciprocal=13'd1638;
 41:reciprocal=13'd1598;
 42:reciprocal=13'd1560;
 43:reciprocal=13'd1524;
 44:reciprocal=13'd1489;
 45:reciprocal=13'd1456;
 46:reciprocal=13'd1424;
 47:reciprocal=13'd1394;
 48:reciprocal=13'd1365;
 49:reciprocal=13'd1337;
 50:reciprocal=13'd1310;
 51:reciprocal=13'd1285;
 52:reciprocal=13'd1260;
 53:reciprocal=13'd1236;
 54:reciprocal=13'd1213;
 55:reciprocal=13'd1191;
 56:reciprocal=13'd1170;
 57:reciprocal=13'd1149;
 58:reciprocal=13'd1129;
 59:reciprocal=13'd1110;
 60:reciprocal=13'd1092;
 61:reciprocal=13'd1074;
 62:reciprocal=13'd1057;
 63:reciprocal=13'd1040;
 64:reciprocal=13'd1024;
 default:reciprocal=0;
 endcase
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin sum<=0;count<=16;product<=0;v1<=0;v2<=0;end
 else begin
  sum<={2'd0,e[7:0],4'd0}+weighted(a[7:0],wa)+weighted(b[7:0],wb)+weighted(c[7:0],wc)
       +weighted(d[7:0],wd)+weighted(f[7:0],wf)+weighted(g[7:0],wg)+weighted(h[7:0],wh)+weighted(i[7:0],wi);
  count<=7'd16+wa+wb+wc+wd+wf+wg+wh+wi;
  product<=sum*reciprocal+32'd32768;v1<=valid;v2<=v1;
 end
 wire [7:0] original;wire [2:0] ctl;reg enable_q;
 video_delay #(.BITS(19),.DELAY(D)) align(clk,rst_n,{iv,ih,id,gray,noise},{ctl,original,noise_o});
 assign {ov,oh,od}=ctl;
 // Reuse this aligned original in the parallel detail path: no duplicate RAM.
 assign original_o=original;
 always @(posedge clk or negedge rst_n)if(!rst_n)enable_q<=1;else if(!ov)enable_q<=enhance;
 assign result=!od?0:enable_q && v2?(product[31:16]>255?8'hff:product[23:16]):original;
endmodule
