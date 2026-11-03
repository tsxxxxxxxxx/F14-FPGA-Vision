`timescale 1ns/1ps
module tb_shapes_pipeline;
 localparam W=96,H=64,HT=120,VT=100,NF=4,LAT=10*HT+58;
 reg clk=0;always #5 clk=~clk;reg rst=0,iv=1,ih=1,id=0;reg [23:0] rgb=0;
 wire ov,oh,od,contour;wire [23:0] out,clean;
 detail_pipeline #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut(
 .clk(clk),.rst_n(rst),.mode(1'b0),.threshold(11'd80),.in_vsync(iv),.in_hsync(ih),.in_de(id),.in_rgb(rgb),
 .out_vsync(ov),.out_hsync(oh),.out_de(od),.out_rgb(out),.recognition_enabled(1'b1),.shape_contour(contour),.clean_rgb(clean));
 reg [7:0] filtered[0:W*H-1];reg edge_gold[0:W*H-1];
 reg [23:0] colors[0:LAT-1];reg [2:0] controls[0:LAT-1];
 integer x,y,f,j,p=0,cycle=0,seen=0,fi=0,edges=0,ax,ay,dx,dy;reg black,light;reg [23:0] expected_rgb;
 function [7:0] gain(input [7:0] a,input integer g);integer v;begin v=(a*g+128)/256;gain=v>255?255:v;end endfunction
 function [23:0] wb(input [23:0] a);begin wb={gain(a[23:16],394),a[15:8],gain(a[7:0],351)};end endfunction
 always @(posedge clk)if(rst)begin #1;
  if(dut.fd)begin
   filtered[fi]=dut.filtered;
   if(fi==W*H-1)begin
    for(ay=0;ay<H;ay=ay+1)for(ax=0;ax<W;ax=ax+1)begin
     black=0;light=0;
     if(ax>0&&ax<W-1&&ay>0&&ay<H-1)begin
      for(dy=-1;dy<=1;dy=dy+1)for(dx=-1;dx<=1;dx=dx+1)begin
       if(filtered[(ay+dy)*W+ax+dx]<96)black=1;else light=1;
      end
     end
     edge_gold[ay*W+ax]=black&&light;
    end
   end
   fi=fi==W*H-1?0:fi+1;
  end
  if(cycle>=LAT-1&&{ov,oh,od}!==controls[(p+1)%LAT])$fatal(1,"Pipeline raster alignment");
  if(od)begin
   expected_rgb=wb(colors[(p+1)%LAT]);
   if(out!==expected_rgb||clean!==expected_rgb)$fatal(1,"Recognition did not force clean color pixel=%0d got=%h expected=%h",seen,out,expected_rgb);
   ax=seen%W;ay=(seen/W)%H;black=0;light=0;
   if(ax>0&&ax<W-1&&ay>0&&ay<H-1)begin
    for(dy=-1;dy<=1;dy=dy+1)for(dx=-1;dx<=1;dx=dx+1)begin
     if(filtered[(ay+dy)*W+ax+dx]<96)black=1;else light=1;
    end
   end
   if(contour!==(black&&light))$fatal(1,"Silhouette alignment pixel=%0d x=%0d y=%0d got=%b expected=%b",seen,ax,ay,contour,black&&light);
   if(contour)edges=edges+1;seen=seen+1;
  end
  colors[p]=rgb;controls[p]={iv,ih,id};p=(p+1)%LAT;cycle=cycle+1;
 end
 initial begin
  for(j=0;j<LAT;j=j+1)begin colors[j]=0;controls[j]=0;end
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<NF;f=f+1)for(y=0;y<VT;y=y+1)for(x=0;x<HT;x=x+1)begin
   @(negedge clk);iv=y>=2;ih=x>=4;id=y>=12&&y<12+H&&x>=8&&x<8+W;rgb=24'hc0e0d0;
   if(id&&x-8>=20&&x-8<70&&y-12>=16&&y-12<48)rgb=24'h101010;
  end
  @(negedge clk);id=0;iv=0;repeat(LAT+20)@(negedge clk);
  if(seen!=NF*W*H||edges<200)$fatal(1,"Missing pixels/contours");
  $display("PASS F13 PIPELINE clean color forced from gray mode; silhouette pixel timing; pixels=%0d edges=%0d",seen,edges);$finish;
 end
endmodule
