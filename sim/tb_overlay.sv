`timescale 1ns/1ps
module tb_overlay;
 localparam W=32,H=24,HT=48,VT=56,LAT=10*HT+58,NF=4;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,iv=1,ih=1,id=0,mode=0;
 reg [23:0] rgb=0;
 wire ov,oh,od;wire [23:0] out;
 detail_pipeline #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut(
  clk,rst,mode,11'd80,iv,ih,id,rgb,ov,oh,od,out,,,,1'b0,,);
 reg [23:0] colors[0:LAT-1];
 reg [2:0] controls[0:LAT-1];
 reg modes[0:LAT-1];
 reg edge_now,wide_now;
 reg [23:0] expected;
 integer p=0,cycles=0,seen=0,total=0,red_count=0,color_count=0,gray_count=0;
 integer epoch,frame,x,y,j,source_frame;
 function [7:0] luma(input [23:0] pixel);
  integer sum;
  begin sum=77*pixel[23:16]+150*pixel[15:8]+29*pixel[7:0]+128;luma=sum>>8;end
 endfunction
 function [7:0] gain(input [7:0] value,input integer q8);
  integer result;
  begin result=(value*q8+128)/256;gain=result>255?255:result;end
 endfunction
 function [23:0] balance(input [23:0] pixel);
  begin balance={gain(pixel[23:16],394),pixel[15:8],gain(pixel[7:0],351)};end
 endfunction
 function [23:0] pattern(input integer f,px,py);
  reg [7:0] r,g,b;
  begin
   r=(px*7+py*13+37*f)&255;
   g=(px*3+py*19+61*f)&255;
   b=(px*17+py*5+83*f)&255;
   pattern={r,g,b};
  end
 endfunction
 always @(posedge clk)begin
  if(!rst)begin
   p=0;cycles=0;seen=0;
   for(j=0;j<LAT;j=j+1)begin colors[j]=0;controls[j]=0;modes[j]=0;end
  end else begin
   edge_now=dut.edge_raw;wide_now=dut.edge_wide;
   #1;
   if(cycles>=LAT-1 && {ov,oh,od}!==controls[(p+1)%LAT])$fatal(1,"Overlay raster");
   if(od)begin
    if(modes[(p+1)%LAT])begin
     expected=wide_now?24'h00ffff:balance(colors[(p+1)%LAT]);
     if(wide_now)red_count=red_count+1;else color_count=color_count+1;
    end else if(seen%W<W/2)begin
     expected={3{luma(colors[(p+1)%LAT])}};gray_count=gray_count+1;
    end else expected={24{edge_now}};
    if(out!==expected)$fatal(1,"Overlay pixel %0d got %h expected %h",seen,out,expected);
    seen=seen+1;total=total+1;
   end else if(out!==24'd0)$fatal(1,"Nonzero blanking");
   colors[p]=rgb;controls[p]={iv,ih,id};modes[p]=frame%2;
   p=(p+1)%LAT;cycles=cycles+1;
  end
 end
 initial begin
  for(epoch=0;epoch<2;epoch=epoch+1)begin
   @(negedge clk);rst=0;id=0;iv=1;ih=1;mode=0;rgb=0;
   repeat(5)@(negedge clk);rst=1;
   for(frame=0;frame<NF;frame=frame+1)begin
    source_frame=frame==2?1:frame;
    for(y=0;y<VT;y=y+1)for(x=0;x<HT;x=x+1)begin
     @(negedge clk);
     iv=y>=2;ih=x>=4;id=y>=12&&y<12+H&&x>=8&&x<8+W;
     // Toggle the request inside active output; it must not tear this frame.
     mode=(y>=28&&y<48)?!(frame%2):(frame%2);
     rgb=id?pattern(source_frame,x-8,y-12):24'h123456;
    end
   end
   @(negedge clk);id=0;iv=0;ih=1;rgb=0;
   repeat(LAT+20)@(negedge clk);
   if(seen!=W*H*NF)$fatal(1,"Overlay missing pixels");
  end
  if(red_count==0||color_count==0||gray_count==0)$fatal(1,"Overlay coverage");
  $display("PASS F10 OVERLAY pixels=%0d cyan=%0d color=%0d gray=%0d frame-atomic mode, reset, repeated source, WB RGB888, unchanged raw gray, blanking",total,red_count,color_count,gray_count);
  $finish;
 end
endmodule
