`timescale 1ns/1ps
module tb_ddr_osd;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=1,hs=1,de=0;wire ov,oh,od;wire [23:0] rgb;
 status_osd #(.WIDTH(256)) dut(.clk(clk),.rst_n(rst),.mode(1'b0),.threshold(11'd80),
 .ddr_mode(2'd2),.ddr_count(7'd64),.ddr_index(6'd37),.ddr_error(4'd0),
 .ddr_position(7'd37),
 .fps_cam(8'd60),.fps_out(8'd60),.fps_new(8'd30),.width(12'd1920),.height(12'd1080),
 .in_vsync(vs),.in_hsync(hs),.in_de(de),.in_rgb(24'h555555),.out_vsync(ov),.out_hsync(oh),.out_de(od),.out_rgb(rgb));
 integer x,y,white=0,seen=0,version_seen=0;
 initial begin
 repeat(5)@(negedge clk);rst=1;repeat(10)@(negedge clk);
 for(y=0;y<170;y=y+1)for(x=0;x<280;x=x+1)begin
  @(negedge clk);vs=y>=2;de=y>=4&&y<164&&x>=4&&x<260;hs=x>=2;
  #1;
  if(de && x-4==140 && y-4==20)begin
   if(dut.character!=="1")$fatal(1,"OSD version is not F11");
   version_seen=version_seen+1;
  end
  if(de && x-4==152 && y-4==20)begin
   if(dut.character!=="3")$fatal(1,"OSD F13 final digit missing");
   version_seen=version_seen+1;
  end
  @(posedge clk);#1;
  if({ov,oh,od}!=={vs,hs,de})$fatal(1,"OSD control");
  if(od)begin
   seen=seen+1;
   if(y-4>=16&&y-4<152&&x-4>=16&&x-4<224)begin
    if(rgb===24'hffffff)white=white+1;else if(rgb!==24'h101010)$fatal(1,"OSD color");
   end else if(rgb!==24'h555555)$fatal(1,"OSD damaged image");
  end
 end
 if(dut.numbers[0]!==16'h0080||dut.numbers[1]!==16'h1920||dut.numbers[2]!==16'h1080||dut.numbers[5]!==16'h0030||dut.numbers[6]!==16'h0064||dut.numbers[7]!==16'h0037||dut.ddr_mode_q!=2)$fatal(1,"BCD/status conversion");
 if(white<400||seen!=40960||version_seen!=2)$fatal(1,"OSD panel/version missing");
 $display("PASS DDR OSD: BCD, frame status, exact outside pixels, raster, F13 version");$finish;
 end
endmodule
