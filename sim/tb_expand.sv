`timescale 1ns/1ps
module tb_expand;
 localparam W=32,H=24,HT=48,VT=40,NF=8,LAT=HT+4;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,iv=1,ih=1,id=0,ei=0,expected_wide=0;
 wire ov,oh,od,raw,wide;
 edge_overlay_expand #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut(clk,rst,iv,ih,id,ei,ov,oh,od,raw,wide);
 integer epoch,frame,x,y,j,p=0,cycles=0,seen=0,total=0,filled=0;
 reg [4:0] queue[0:LAT-1];
 function pixel(input integer f,px,py);
 begin
  pixel=0;
  if(px>=0&&px<W&&py>=0&&py<H)case(f)
   0:pixel=py==12 && px>=4 && px<=27 && px!=12 && px!=20 && px!=21;
   1:pixel=px==16 && py>=3 && py<=20 && py!=10 && py!=11;
   2:pixel=px==py && px>2 && px<21 && px!=10;
   3:pixel=px==0||px==W-1||py==0||py==H-1;
   4:pixel=0;
   5:pixel=1;
   6:pixel=px==16&&py==12;
   7:pixel=((px*13+py*7)%17)==0;
  endcase
 end endfunction
 function expanded(input integer f,px,py);
 integer dx,dy;reg value;
 begin
  value=pixel(f,px,py);
  if(px>0&&px<W-1&&py>0&&py<H-1)
   for(dy=-1;dy<=1;dy=dy+1)for(dx=-1;dx<=1;dx=dx+1)value=value|pixel(f,px+dx,py+dy);
  expanded=value;
 end endfunction
 always @(posedge clk)begin
  if(!rst)begin p=0;cycles=0;seen=0;for(j=0;j<LAT;j=j+1)queue[j]=0;end
  else begin
   #1;
   if(cycles>=LAT-1)begin
    if({ov,oh,od}!==queue[(p+1)%LAT][4:2])$fatal(1,"Expand raster");
    if(od)begin
     if({raw,wide}!==queue[(p+1)%LAT][1:0])$fatal(1,"Expand pixel %0d raw/wide=%b%b expected %b",seen,raw,wide,queue[(p+1)%LAT]);
     seen=seen+1;total=total+1;if(wide&&!raw)filled=filled+1;
    end else if(wide!==0)$fatal(1,"Expand blanking");
   end
   queue[p]={iv,ih,id,ei,expected_wide};
   p=(p+1)%LAT;cycles=cycles+1;
  end
 end
 initial begin
  for(epoch=0;epoch<2;epoch=epoch+1)begin
   @(negedge clk);rst=0;id=0;iv=1;ih=1;ei=0;
   repeat(5)@(negedge clk);rst=1;
   for(frame=0;frame<NF;frame=frame+1)
    for(y=0;y<VT;y=y+1)for(x=0;x<HT;x=x+1)begin
     @(negedge clk);iv=y>=2;ih=x>=4;id=y>=4&&y<4+H&&x>=8&&x<8+W;
     ei=id?pixel(frame,x-8,y-4):1'b1;
     expected_wide=id?expanded(frame,x-8,y-4):1'b0;
    end
   @(negedge clk);id=0;iv=0;ei=0;
   repeat(LAT+5)@(negedge clk);
   if(seen!=W*H*NF)$fatal(1,"Expand count");
  end
  if(filled==0)$fatal(1,"Expand coverage");
  $display("PASS F10 EXPAND pixels=%0d added=%0d exact 3x3, horizontal/vertical/diagonal gaps, image borders, empty/full, reset, no frame carry",total,filled);$finish;
 end
endmodule
