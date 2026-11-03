`timescale 1ns/1ps
// Actual silhouette edge input is already aligned with RGB. Bounding boxes
// only select accepted components; boxes themselves are never drawn.
module shapes_osd #(parameter WIDTH=1920,HEIGHT=1080,MAX_OBJECTS=8)(
 input wire clk,rst_n,enabled,input wire [MAX_OBJECTS-1:0] valid,
 input wire [MAX_OBJECTS*3-1:0] classes,
 input wire [MAX_OBJECTS*8-1:0] bx0,by0,bx1,by1,
 input wire contour,input wire in_vsync,in_hsync,in_de,input wire [23:0] in_rgb,
 output reg out_vsync,out_hsync,out_de,output reg [23:0] out_rgb);
 reg [11:0] x,y;reg vs_d,en_q;reg [MAX_OBJECTS-1:0] valid_q;
 reg [2:0] cls_q[0:MAX_OBJECTS-1];
 reg [11:0] x0[0:MAX_OBJECTS-1],y0[0:MAX_OBJECTS-1],x1[0:MAX_OBJECTS-1],y1[0:MAX_OBJECTS-1];
 reg [11:0] tx[0:MAX_OBJECTS-1],ty[0:MAX_OBJECTS-1];integer k;
 function [23:0] color(input [2:0] cls);
 begin case(cls)
  0:color=24'hff4040;1:color=24'h30e060;2:color=24'hffd020;
  3:color=24'h20d0ff;4:color=24'he050ff;5:color=24'hff9020;default:color=24'hffffff;
 endcase end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  x<=0;y<=0;vs_d<=1;en_q<=0;valid_q<=0;
  for(k=0;k<MAX_OBJECTS;k=k+1)begin cls_q[k]<=0;x0[k]<=0;y0[k]<=0;x1[k]<=0;y1[k]<=0;tx[k]<=0;ty[k]<=0;end
 end else begin
  vs_d<=in_vsync;
  if(!in_vsync)begin x<=0;y<=0;end
  else if(in_de)if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
  if(vs_d&&!in_vsync)begin
   en_q<=enabled;valid_q<=valid;
   for(k=0;k<MAX_OBJECTS;k=k+1)begin
    cls_q[k]<=classes[k*3+:3];
    x0[k]<={bx0[k*8+:8],3'b0};y0[k]<={by0[k*8+:8],3'b0};
    x1[k]<={bx1[k*8+:8],3'b0}+12'd7;y1[k]<={by1[k*8+:8],3'b0}+12'd7;
    // 3 glyphs x 32 px. Prefer right, then left, then above/below.
    if({bx1[k*8+:8],3'b0}+12'd111<WIDTH)begin tx[k]<={bx1[k*8+:8],3'b0}+12'd15;ty[k]<={by0[k*8+:8],3'b0};end
    else if({bx0[k*8+:8],3'b0}>=104)begin tx[k]<={bx0[k*8+:8],3'b0}-12'd104;ty[k]<={by0[k*8+:8],3'b0};end
    else begin tx[k]<={bx0[k*8+:8],3'b0};ty[k]<=by0[k*8+:8]>=5?{by0[k*8+:8],3'b0}-12'd36:{by1[k*8+:8],3'b0}+12'd12;end
   end
  end
 end
 reg label_hit,edge_hit;reg [2:0] label_class,edge_class;reg [11:0] dx,dy;
 integer n;
 always @*begin
  label_hit=0;edge_hit=0;label_class=0;edge_class=0;dx=0;dy=0;
  for(n=0;n<MAX_OBJECTS;n=n+1)begin
   if(en_q&&valid_q[n]&&cls_q[n]<6)begin
    if(x+12'd8>=x0[n]&&x<=x1[n]+12'd8&&y+12'd8>=y0[n]&&y<=y1[n]+12'd8)begin edge_hit=1;edge_class=cls_q[n];end
    if(x>=tx[n]&&x<tx[n]+12'd96&&y>=ty[n]&&y<ty[n]+12'd32)begin label_hit=1;label_class=cls_q[n];dx=x-tx[n];dy=y-ty[n];end
   end
  end
 end
 reg [15:0] font[0:287];initial $readmemh("src/isp/shapes_font.mem",font);
 wire [8:0] font_addr=label_class*9'd48+{dx[6:5],4'b0}+{5'b0,dy[4:1]};
 reg [15:0] font_q;reg [3:0] column_q;reg label_q,edge_q;
 reg [23:0] rgb_q,label_color_q,edge_color_q;reg vs_q,hs_q,de_q;
 always @(posedge clk)font_q<=font[font_addr];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  column_q<=0;label_q<=0;edge_q<=0;rgb_q<=0;label_color_q<=0;edge_color_q<=0;vs_q<=1;hs_q<=1;de_q<=0;
  out_vsync<=1;out_hsync<=1;out_de<=0;out_rgb<=0;
 end else begin
  column_q<=dx[4:1];label_q<=label_hit;edge_q<=edge_hit&&contour;
  rgb_q<=in_rgb;label_color_q<=color(label_class);edge_color_q<=color(edge_class);
  vs_q<=in_vsync;hs_q<=in_hsync;de_q<=in_de;
  out_vsync<=vs_q;out_hsync<=hs_q;out_de<=de_q;
  out_rgb<=!de_q?24'd0:label_q?(font_q[column_q]?label_color_q:24'h181818):edge_q?edge_color_q:rgb_q;
 end
endmodule
