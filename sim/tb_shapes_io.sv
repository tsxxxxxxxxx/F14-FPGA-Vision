`timescale 1ns/1ps
module tb_shapes_io;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,key=1,bvs=1,en=0,vs=1,de=0;reg [7:0] gray=0;reg [23:0] rgb=24'h123456;
 wire enabled,fs,sv;wire [7:0] sg;
 recog_button #(.DEBOUNCE_CYCLES(8)) button(clk,rst,key,bvs,enabled);
 shapes_capture cap(clk,rst,en,vs,de,gray,fs,sv,sg);
 reg [7:0] valid=0;reg [23:0] classes=0;reg [63:0] bx0=0,by0=0,bx1=0,by1=0;
 reg edge_in=0;wire ov,oh,od;wire [23:0] out;
 shapes_osd osd(clk,rst,en,valid,classes,bx0,by0,bx1,by1,edge_in,vs,1'b1,de,rgb,ov,oh,od,out);
 reg [7:0] pixels[0:32399];reg [39:0] expected[0:8];reg [15:0] font[0:287];
 integer x,y,f,n,c,count,fd,seen,idx,tx,ty,dx,dy,row,col,addr,boxidx;
 reg expected_sv,edge_now;reg [23:0] golden,previous_golden;reg previous_de;
 function [23:0] color(input integer i);begin case(i)
  0:color=24'hff4040;1:color=24'h30e060;2:color=24'hffd020;3:color=24'h20d0ff;4:color=24'he050ff;5:color=24'hff9020;default:color=0;
 endcase end endfunction
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task commit;begin bvs=0;ticks(2);bvs=1;ticks(2);end endtask
 initial begin
  $readmemh("sim/shapes_first.hex",pixels);$readmemh("sim/shapes_first_expected.hex",expected);
  $readmemh("src/isp/shapes_font.mem",font);
  ticks(5);rst=1;ticks(5);if(enabled)$fatal(1,"Boot ON");
  key=0;ticks(3);key=1;ticks(12);commit();if(enabled)$fatal(1,"Bounce toggled");
  key=0;ticks(20);if(enabled)$fatal(1,"Midframe toggle");commit();if(!enabled)$fatal(1,"Press did not enable");
  ticks(50);commit();if(!enabled)$fatal(1,"Hold repeated");key=1;ticks(20);key=0;ticks(20);commit();if(enabled)$fatal(1,"Second press failed");
  for(c=0;c<6;c=c+1)begin
   valid[c]=1;classes[c*3+:3]=expected[c+1][34:32];bx0[c*8+:8]=expected[c+1][31:24];by0[c*8+:8]=expected[c+1][23:16];bx1[c*8+:8]=expected[c+1][15:8];by1[c*8+:8]=expected[c+1][7:0];
  end
  fd=$fopen("evidence/six_shapes_rtl.ppm","wb");$fwrite(fd,"P6%c1920 1080%c255%c",10,10,10);seen=0;
  for(f=0;f<2;f=f+1)begin
   en=f==1;count=0;previous_de=0;previous_golden=0;
   vs=0;de=0;ticks(4);vs=1;ticks(2);
   for(y=0;y<1080;y=y+1)begin
    for(x=0;x<1920;x=x+1)begin
     de=1;gray=(x+3*y)&255;idx=(y/8)*240+x/8;rgb={3{pixels[idx]}};
     edge_now=0;
     if(x>0&&x<1919&&y>0&&y<1079)begin
      edge_now=(pixels[idx]<96)&&((pixels[(y/8)*240+(x-1)/8]>=96)||(pixels[(y/8)*240+(x+1)/8]>=96)||(pixels[((y-1)/8)*240+x/8]>=96)||(pixels[((y+1)/8)*240+x/8]>=96));
     end
     edge_in=edge_now;golden=rgb;boxidx=-1;
     if(en)begin
      for(c=0;c<6;c=c+1)begin
       if(x+8>=bx0[c*8+:8]*8&&x<=bx1[c*8+:8]*8+15&&y+8>=by0[c*8+:8]*8&&y<=by1[c*8+:8]*8+15&&edge_now)golden=color(classes[c*3+:3]);
       tx=bx1[c*8+:8]*8+15;ty=by0[c*8+:8]*8;
       if(tx+96>=1920)tx=bx0[c*8+:8]*8-104;
       if(x>=tx&&x<tx+96&&y>=ty&&y<ty+32)begin
        dx=x-tx;dy=y-ty;addr=classes[c*3+:3]*48+(dx/32)*16+dy/2;col=(dx%32)/2;
        golden=font[addr][col]?color(classes[c*3+:3]):24'h181818;
       end
      end
     end
     expected_sv=en&&(x%8==4)&&(y%8==4);
     @(posedge clk);#1;
     if(sv!==expected_sv)$fatal(1,"Sampling mismatch x=%0d y=%0d",x,y);
     if(sv)begin if(sg!==gray)$fatal(1,"Sample data mismatch");count=count+1;end
     if(od!==previous_de)$fatal(1,"OSD DE delay mismatch");
     if(previous_de)begin
      if(out!==previous_golden)$fatal(1,"OSD pixel mismatch f=%0d x=%0d y=%0d got=%h expected=%h",f,x,y,out,previous_golden);
      if(f==1)begin $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);seen=seen+1;end
     end
     previous_golden=golden;previous_de=1;@(negedge clk);
    end
    de=0;@(posedge clk);#1;
    if(!od||out!==previous_golden)$fatal(1,"Last pixel lost");
    if(f==1)begin $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);seen=seen+1;end
    @(negedge clk);previous_de=0;ticks(8);
   end
   if(count!=(en?32400:0))$fatal(1,"Full-frame sample count %0d",count);
  end
  $fclose(fd);if(seen!=1920*1080)$fatal(1,"Preview count");
  $display("PASS F13 IO: full-HD 32400 samples; debounce; six colors; Chinese font; contours; OFF transparency; 4147200 pixels");$finish;
 end
 initial begin #200000000;$fatal(1,"IO watchdog");end
endmodule
