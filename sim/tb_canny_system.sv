`timescale 1ns/1ps
module tb_canny_system;
`ifdef FULL_HD
 localparam W=1920,H=1080,HB=280,VB=99000,FIRST=1,LAST=2;
`else
 localparam W=128,H=16,HB=32,VB=800,FIRST=3,LAST=5;
`endif
 localparam WORDS=W*H/64,BASE=32'h08000000;
 reg pc=0,ac=0,rst=1,en=0,nv=1,de=0;reg [1:0] tok=0;
 always #3.367 pc=~pc;always #5.208 ac=~ac;
 wire edge_bit,valid,busy;wire [7:0] fps;wire [15:0] passes;wire [3:0] errors;
 wire [31:0] aa,ra;wire [7:0] al,rl;wire av,wv,wl,rv,rr;wire [127:0] wd;wire [15:0] strb;
 reg aready=0,wready=0,rready=0,bvalid=0,rvalid=0,rlast=0;
 reg [127:0] rdata=0;reg [1:0] bresp=0,rresp=0;
 canny_system #(.WIDTH(W),.HEIGHT(H)) dut(pc,!rst,ac,rst,en,nv,de,tok,nv,de,
  edge_bit,valid,fps,passes,errors,busy,aa,al,av,aready,wd,strb,wl,wv,wready,
  4'd0,bresp,bvalid,ra,rl,rv,rready,4'd0,rdata,rresp,rlast,rvalid,rr);
 reg [127:0] mem[0:WORDS*2-1];integer wp=0,rp=0,delay_r=0,delay_b=0,wi=0,ri=0,wlen=0,rlen=0;
 integer bus_clock=0;
 reg writing=0,reading=0;reg [31:0] rng=32'hc314feed;
 function integer index(input [31:0] addr);
 begin
  if(addr<BASE||addr>=BASE+32'h00200000||(addr&32'h000fffff)>=WORDS*16||addr[3:0]!=0)
   $fatal(1,"Canny DDR outside private buffers %h",addr);
  index=((addr-BASE)>>20)*WORDS+((addr&32'h000fffff)>>4);
 end endfunction
 always @(negedge ac)begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  bus_clock=bus_clock+1;
  // Model periodic long F13 bursts occupying the shared DDR address path.
  aready=!writing&&!bvalid&&delay_b==0&&rng[0]&&(bus_clock%1024>=128);
  wready=writing&&rng[1];rready=!reading&&!rvalid&&rng[2]&&(bus_clock%1024>=128);
 end
 always @(posedge ac)if(!rst)begin
  if(av&&aready)begin
   if(al>3||(aa&4095)+16*(al+1)>4096)$fatal(1,"write len/boundary");
   wp=index(aa);writing=1;wi=0;wlen=al;
  end
  if(wv&&wready)begin
   if(!writing||wl!=(wi==wlen)||strb!=16'hffff)$fatal(1,"write protocol");
   mem[wp+wi]=wd;wi=wi+1;
   if(wl)begin writing=0;delay_b=4;end
  end
  if(bvalid)bvalid<=0;
  if(delay_b>0)begin delay_b=delay_b-1;if(delay_b==0)bvalid<=1;end
  if(rv&&rready)begin
   if(rl>3||(ra&4095)+16*(rl+1)>4096)$fatal(1,"read len/boundary");
   rp=index(ra);reading=1;delay_r=8;ri=0;rlen=rl;
  end
  if(reading&&delay_r>0)begin delay_r=delay_r-1;if(delay_r==0)begin rvalid<=1;rlast<=ri==rlen;rdata<=mem[rp+ri];end end
  if(rvalid&&rr)begin
   rvalid<=0;rlast<=0;
   if(ri==rlen)reading=0;else begin ri=ri+1;delay_r=1;end
  end
 end
 integer x,y,frames=0,checked=0,publications=0;reg lastpub=0;
 reg change_scene=0;
 always @(posedge ac)if(!rst&&dut.publish_toggle!=lastpub)begin
  lastpub<=dut.publish_toggle;publications=publications+1;
  $display("CANNY result=%0d time_ns=%0d compute_cycles=%0d passes=%0d",publications,$time,dut.eng_cycles,dut.published_passes);
 end
 initial begin
  repeat(10)@(negedge pc);rst=0;en=1;
  forever begin
   @(negedge pc);nv=0;de=0;repeat(8)@(negedge pc);nv=1;
   repeat(VB)@(negedge pc);
`ifdef SAFETY
   for(y=0;y<(frames<4?H-3:H);y=y+1)begin
`else
   for(y=0;y<H;y=y+1)begin
`endif
    for(x=0;x<W;x=x+1)begin
     @(negedge pc);de=1;
     tok=(y==H/2&&x>0&&x<W-1)?((x==W/2)?3:1):0;
     #0.1;
     if(en&&valid)begin
      if(edge_bit!==(y==H/2&&x>0&&x<W-1))$fatal(1,"pixel f=%0d x=%0d y=%0d edge=%b",frames,x,y,edge_bit);
      checked=checked+1;
     end
    end
    @(negedge pc);de=0;repeat(HB)@(negedge pc);
   end
`ifdef SAFETY
   if(frames<4&&publications!=0)$fatal(1,"incomplete frame published");
`endif
   frames=frames+1;
  end
 end
 initial begin
  wait(publications>=FIRST&&checked>=W*H*FIRST);
`ifdef FULL_HD
  if(errors)$fatal(1,"full-HD Canny errors %h",errors);
  $display("PASS CANNY SYSTEM 1920x1080 checked=%0d publications=%0d passes=%0d 96MHz DDR, burst contention, exact full frame, no FIFO/DDR errors",checked,publications,passes);$finish;
`endif
  @(negedge pc);en=0;
  repeat(100)@(negedge pc);
  if(valid)$fatal(1,"Canny visible after disable");
  wait(dut.phase==0);repeat(1000)@(negedge pc);en=1;
  wait(publications>=LAST&&checked>=W*H*LAST);
`ifdef SAFETY
  if(errors!==4'b0001)$fatal(1,"expected incomplete-frame rejection only, errors=%h",errors);
  $display("PASS CANNY SAFETY incomplete frames rejected, recovery, disable/re-enable");
`else
  if(errors)$fatal(1,"Canny errors %h",errors);
`endif
  $display("PASS CANNY SYSTEM %0dx%0d checked=%0d publications=%0d passes=%0d, disable/re-enable, no FIFO/DDR errors",W,H,checked,publications,passes);$finish;
 end
 initial begin
  repeat(200000000)@(posedge ac);$fatal(1,"timeout phase=%0d tx=%0d cap=%0d pubs=%0d checked=%0d error=%h",dut.phase,dut.tx,dut.written_words,publications,checked,errors);
 end
endmodule
