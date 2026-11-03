`timescale 1ns/1ps
module tb_store_arbiter;
`ifdef FULL_HD
 localparam BYTES=1920*1080,SB=21,IB=2,SLOTS=1<<IB,CAM_BLANK=650000,PIX_BLANK=700000;
`else
 localparam BYTES=3072,SB=12,IB=3,SLOTS=1<<IB,CAM_BLANK=1000,PIX_BLANK=1600;
`endif
 reg clk=0,cam=0,pix=0,rst=1;always #5 clk=~clk;always #7 cam=~cam;always #3 pix=~pix;
 reg cv=0,cd=0,rv=1,rd=0;reg [31:0] camdata=0;
 reg [2:0] mode=0;reg toggle=0;
 wire [31:0] awaddr,araddr,id;wire [7:0] awlen,arlen,pixel;
 wire awvalid,wvalid,wlast,arvalid,rready,update;wire [127:0] wdata;wire [15:0] strb;
 wire [1:0] state;wire [6:0] count;wire [5:0] index;wire [3:0] error;
 wire [6:0] position;
 reg awready=0,wready=0,arready=0,bvalid=0,rvalid=0,rlast=0;reg [1:0] bresp=0;reg [127:0] rdata=0;
 ddr_frame_store #(.FRAME_BYTES(BYTES),.SLOT_BITS(SB),.INDEX_BITS(IB)) dut(
 .axi_clk(clk),.axi_reset(rst),.axi_awaddr(a_awaddr),.axi_awlen(a_awlen),.axi_awvalid(a_awvalid),.axi_awready(a_awready),
 .axi_wdata(a_wdata),.axi_wstrb(a_wstrb),.axi_wlast(a_wlast),.axi_wvalid(a_wvalid),.axi_wready(a_wready),
 .axi_bid(a_bid),.axi_bresp(a_bresp),.axi_bvalid(a_bvalid),
 .axi_araddr(a_araddr),.axi_arlen(a_arlen),.axi_arvalid(a_arvalid),.axi_arready(a_arready),
 .axi_rid(a_rid),.axi_rdata(a_rdata),.axi_rresp(a_rresp),.axi_rlast(a_rlast),.axi_rvalid(a_rvalid),.axi_rready(a_rready),
 .wframe_pclk(cam),.wframe_vsync(cv),.wframe_data_en(cd),.wframe_data(camdata),
 .rframe_pclk(pix),.rframe_vsync(rv),.rframe_data_en(rd),.rframe_data(pixel),
 .request_mode(mode),.request_toggle(toggle),.monitor_frame_id(id),.monitor_update(update),
 .status_mode(state),.status_count(count),.status_index(index),.status_error(error),.status_position(position));
 reg [127:0] mem[0:(SLOTS*(1<<SB)/16)];
 integer wp,wl,wi,rp,rl,ri,delay_b=0,burst_writes=0,checks=0,frames=0;
 integer byte_lane;reg [7:0] capture_tag;
 always @(posedge cam)if(cd&&dut.cam_start)capture_tag=camdata[31:24];
 reg writing=0,reading=0;reg inject_b=0;reg [31:0] rng=32'h108060;
 always @(negedge clk)begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  awready=!writing&&!bvalid&&delay_b==0&&rng[0];wready=writing&&rng[1];arready=!reading&&rng[2];
  rvalid=reading&&rng[3];rdata=reading?mem[rp+ri]:0;rlast=reading&&ri==rl;
 end
 always @(posedge clk)if(!rst)begin
  if(awvalid&&awready)begin
   if(writing)$fatal(1,"overlapping writes");
   if(awaddr!=DUMMY_ADDR&&awaddr+16*(awlen+1)>SLOTS*(1<<SB))$fatal(1,"write out of range");
   if(awaddr!=DUMMY_ADDR&&dut.read_enabled&&(awaddr>>SB)==dut.read_slot)$fatal(1,"reader overwritten");
   if((awaddr&4095)+16*(awlen+1)>4096)$fatal(1,"4K boundary crossed");
   wp=awaddr==DUMMY_ADDR?DUMMY:awaddr/16;wl=awlen;wi=0;writing=1;
  end
  if(wvalid&&wready)begin
   if(!writing || wlast!=(wi==wl)||strb!=16'hffff)$fatal(1,"write protocol");
   for(byte_lane=0;byte_lane<16;byte_lane=byte_lane+1)
    if(wp!=DUMMY&&wdata[127-byte_lane*8 -: 8]!==8'(capture_tag+((wp+wi)%(1<<(SB-4)))*16+byte_lane))
     $fatal(1,"camera-to-DDR byte order/data mismatch");
   mem[wp+wi]=wdata;wi=wi+1;
   if(wlast)begin writing=0;delay_b=9;if(wp!=DUMMY)burst_writes=burst_writes+1;end
  end
  if(bvalid)begin bvalid<=0;bresp<=0;end
  if(delay_b>0)begin delay_b=delay_b-1;if(delay_b==0)begin bvalid<=1;bresp<=(inject_b&&wp!=DUMMY)?2:0;end end
  if(arvalid&&arready)begin rp=araddr==DUMMY_ADDR?DUMMY:araddr/16;rl=arlen;ri=0;reading=1;
   if(araddr!=DUMMY_ADDR&&!dut.valid_slots[dut.read_slot])$fatal(1,"uncommitted frame read");
  end
  if(rvalid&&rready)begin if(rlast)reading=0;else ri=ri+1;end
 end
 // Camera: changing byte pattern, asynchronous clocks, active frame + blanking.
 integer cf=0,c;
 initial begin
  wait(!rst);repeat(10)@(negedge cam);cv=1;repeat(10)@(negedge cam);cv=0;
  forever begin
   repeat(CAM_BLANK)@(negedge cam);cv=1;
   for(c=0;c<BYTES/4;c=c+1)begin @(negedge cam);cd=1;
    camdata={8'(cf+c*4),8'(cf+c*4+1),8'(cf+c*4+2),8'(cf+c*4+3)};
   end
   @(negedge cam);cd=0;repeat(20)@(negedge cam);cv=0;cf=cf+1;
  end
 end
 integer p,slot;reg [7:0] expected;reg enabled;
 initial begin
  wait(!rst);
  forever begin
   @(negedge pix);rv=0;repeat(20)@(negedge pix);rv=1;
   repeat(PIX_BLANK)@(negedge pix);slot=dut.read_slot;enabled=dut.read_enabled;
   for(p=0;p<BYTES;p=p+1)begin
    @(negedge pix);rd=1;#0.1;
    if(enabled)begin
     expected=mem[(slot*(1<<SB)+p)/16]>>(8*(15-p%16));
     if(pixel!==expected)$fatal(1,"pixel mismatch frame=%0d p=%0d got=%h expected=%h slot=%0d",frames,p,pixel,expected,slot);
     checks=checks+1;
    end
   end
   @(negedge pix);rd=0;frames=frames+1;repeat(600)@(negedge pix);
  end
 end
 task command(input [2:0] m);begin @(negedge pix);mode=m;toggle=~toggle;end endtask
 task step_frame(input [2:0] m);begin
  command(m);wait(dut.step_pending!=0);wait(dut.step_pending==0);#1;
 end endtask
 integer saved_w,seen_id,changes;
 initial begin
  #100;rst=0;
`ifdef FULL_HD
  wait(checks>=2*BYTES);command(1);wait(state==1);saved_w=burst_writes;seen_id=id;
  @(posedge update or negedge update);#1;
  if(burst_writes!=saved_w || id!=seen_id || dut.errors || dut.read_error || dut.underflow)$fatal(1,"1080p freeze/error");
  step_frame(3);if(id!=seen_id-1||position!=count-1)$fatal(1,"1080p previous");
  step_frame(4);if(id!=seen_id||position!=count)$fatal(1,"1080p next");
  @(posedge update or negedge update);#1;
  if(burst_writes!=saved_w||dut.read_error||dut.underflow)$fatal(1,"1080p step integrity");
  $display("PASS F14 SHARED DDR FULLHD checks=%0d complete RAW8 frames=%0d exact 1080p tail and freeze",checks,dut.sequence_id);if(b_checks<100)$fatal(1,"too little concurrent Canny traffic");$display("CANNY concurrent read/write checks=%0d",b_checks);$finish;
`else
  // Commands with no stored image must never issue reads of an invalid slot.
  step_frame(3);if(position!=0||count!=0||dut.read_enabled)$fatal(1,"empty cache step");
  command(0);wait(dut.sequence_id==1);command(1);wait(state==1);#1;
  if(count!=1||position!=1)$fatal(1,"single frame setup");
  step_frame(3);if(position!=1)$fatal(1,"single previous");
  step_frame(4);if(position!=1)$fatal(1,"single next");
  command(0);
  wait(dut.sequence_id>=14);command(1);wait(state==1);saved_w=burst_writes;seen_id=id;
  repeat(4)begin @(posedge update or negedge update);#1;
   if(id!=seen_id || burst_writes!=saved_w)$fatal(1,"freeze not immutable");
  end
  if(count!=SLOTS)$fatal(1,"ring did not retain complete history count=%0d",count);
  if(position!=SLOTS)$fatal(1,"latest ordinal");
  step_frame(3);if(position!=SLOTS-1||id!=seen_id-1)$fatal(1,"previous frame");
  step_frame(4);if(position!=SLOTS||id!=seen_id)$fatal(1,"next frame");
  step_frame(4);if(position!=SLOTS||id!=seen_id)$fatal(1,"last boundary");
  repeat(SLOTS+2)step_frame(3);
  if(position!=1||id!=seen_id-SLOTS+1)$fatal(1,"first boundary/wrap ordinal");
  if(burst_writes!=saved_w)$fatal(1,"stepping overwrote history");
  command(2);wait(state==2);changes=0;seen_id=id;
  repeat(24)begin @(posedge update or negedge update);#1;
   if(burst_writes!=saved_w)$fatal(1,"playback overwrote history");
   if(id!=seen_id)changes=changes+1;seen_id=id;
  end
  if(changes<10)$fatal(1,"replay stalled");
  step_frame(3);if(state!=1)$fatal(1,"step must pause replay");
  command(1);wait(state==1);seen_id=id;
  repeat(3)begin @(posedge update or negedge update);#1;if(id!=seen_id)$fatal(1,"freeze playback failed");end
  command(0);wait(state==0);wait(dut.sequence_id>=18);
  inject_b=1;wait(dut.errors[1]);inject_b=0;wait(dut.sequence_id>=20);
  step_frame(3);if(state!=1||position!=count-1)$fatal(1,"LIVE to previous");
  if(dut.read_error||dut.underflow)$fatal(1,"read error/underflow");
  if(checks<100000)$fatal(1,"too few pixel checks");
  $display("PASS F14 SHARED DDR STORE checks=%0d frames=%0d commits=%0d randomized AXI, exact tail, wrap, freeze, replay, resume, BRESP reject, PREV/NEXT and 1-based ordinal boundaries",checks,frames,dut.sequence_id);if(b_checks<100)$fatal(1,"too little concurrent Canny traffic");$display("CANNY concurrent read/write checks=%0d",b_checks);$finish;
`endif
 end
 initial begin #1000000000;$fatal(1,"timeout ws=%0d bytes=%0d count=%0d req=%b ack=%b camactive=%b",dut.ws,dut.write_bytes,dut.fifo_count,dut.capture_request,dut.cap_ack,dut.cam_active);end
localparam DUMMY=SLOTS*(1<<SB)/16,DUMMY_ADDR=32'h08000000;
wire [31:0] a_awaddr;
wire [7:0] a_awlen;
wire a_awvalid;
wire a_awready;
wire [127:0] a_wdata;
wire [15:0] a_wstrb;
wire a_wlast;
wire a_wvalid;
wire a_wready;
wire [3:0] a_bid;
wire [1:0] a_bresp;
wire a_bvalid;
wire [3:0] a_arid;
wire [31:0] a_araddr;
wire [7:0] a_arlen;
wire a_arvalid;
wire a_arready;
wire [3:0] a_rid;
wire [127:0] a_rdata;
wire [1:0] a_rresp;
wire a_rlast;
wire a_rvalid;
wire a_rready;
wire [31:0] b_awaddr;
wire [7:0] b_awlen;
wire b_awvalid;
wire b_awready;
wire [127:0] b_wdata;
wire [15:0] b_wstrb;
wire b_wlast;
wire b_wvalid;
wire b_wready;
wire [3:0] b_bid;
wire [1:0] b_bresp;
wire b_bvalid;
wire [3:0] b_arid;
wire [31:0] b_araddr;
wire [7:0] b_arlen;
wire b_arvalid;
wire b_arready;
wire [3:0] b_rid;
wire [127:0] b_rdata;
wire [1:0] b_rresp;
wire b_rlast;
wire b_rvalid;
wire b_rready;
wire [3:0] unused_arid;
canny_axi_arbiter arb(.clk(clk),.reset(rst),
.a_awaddr(a_awaddr),.a_awlen(a_awlen),.a_awvalid(a_awvalid),.a_awready(a_awready),.a_wdata(a_wdata),.a_wstrb(a_wstrb),.a_wlast(a_wlast),.a_wvalid(a_wvalid),.a_wready(a_wready),.a_bid(a_bid),.a_bresp(a_bresp),.a_bvalid(a_bvalid),.a_arid(a_arid),.a_araddr(a_araddr),.a_arlen(a_arlen),.a_arvalid(a_arvalid),.a_arready(a_arready),.a_rid(a_rid),.a_rdata(a_rdata),.a_rresp(a_rresp),.a_rlast(a_rlast),.a_rvalid(a_rvalid),.a_rready(a_rready),.b_awaddr(b_awaddr),.b_awlen(b_awlen),.b_awvalid(b_awvalid),.b_awready(b_awready),.b_wdata(b_wdata),.b_wstrb(b_wstrb),.b_wlast(b_wlast),.b_wvalid(b_wvalid),.b_wready(b_wready),.b_bid(b_bid),.b_bresp(b_bresp),.b_bvalid(b_bvalid),.b_araddr(b_araddr),.b_arlen(b_arlen),.b_arvalid(b_arvalid),.b_arready(b_arready),.b_rid(b_rid),.b_rdata(b_rdata),.b_rresp(b_rresp),.b_rlast(b_rlast),.b_rvalid(b_rvalid),.b_rready(b_rready),.m_awaddr(awaddr),.m_awlen(awlen),.m_awvalid(awvalid),.m_awready(awready),.m_wdata(wdata),.m_wstrb(strb),.m_wlast(wlast),.m_wvalid(wvalid),.m_wready(wready),.m_bid(4'd0),.m_bresp(bresp),.m_bvalid(bvalid),.m_arid(unused_arid),.m_araddr(araddr),.m_arlen(arlen),.m_arvalid(arvalid),.m_arready(arready),.m_rid(4'd0),.m_rdata(rdata),.m_rresp(2'd0),.m_rlast(rlast),.m_rvalid(rvalid),.m_rready(rready));

reg [2:0] bstate=0;integer b_checks=0;reg [31:0] btag=1;
assign b_awaddr=DUMMY_ADDR;assign b_awlen=0;assign b_awvalid=bstate==0;
assign b_wdata={btag,btag^32'hc0ffee,btag+32'd1,~btag};
assign b_wstrb=16'hffff;assign b_wlast=1;assign b_wvalid=bstate==1;
assign b_araddr=DUMMY_ADDR;assign b_arlen=0;assign b_arvalid=bstate==3;assign b_rready=1;
always @(posedge clk)if(!rst)case(bstate)
 0:if(b_awready)bstate<=1;
 1:if(b_wready)bstate<=2;
 2:if(b_bvalid)begin if(b_bresp!=0)$fatal(1,"B response misrouted");bstate<=3;end
 3:if(b_arready)bstate<=4;
 4:if(b_rvalid)begin
  if(b_rdata!==b_wdata||!b_rlast||b_rresp!=0)$fatal(1,"B read misrouted/data corrupt");
  b_checks<=b_checks+1;btag<=btag+1'b1;bstate<=0;
 end
endcase

endmodule
