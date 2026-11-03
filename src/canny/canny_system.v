// DDR-backed full-resolution Canny add-on. F13 owns DDR [0,128 MiB).
// Two private 1 MiB slots at 0x08000000/0x08100000 contain 2-bit edge maps.
// Never modify the displayed bank. Publish only fully converged complete
// frames, and recycle the previous bank only after a vblank acknowledgement.
module canny_system #(parameter WIDTH=1920,HEIGHT=1080,BASE=32'h08000000)(
 input wire pclk,prst_n,aclk,areset,enabled,
 input wire nvs,nde,input wire [1:0] token,
 input wire dvs,dde,
 output wire edge_pixel,output wire picture_valid,
 output wire [7:0] fps,output wire [15:0] passes,
 output wire [3:0] errors,output wire processing,
 output wire [31:0] awaddr,output wire [7:0] awlen,output wire awvalid,input wire awready,
 output wire [127:0] wdata,output wire [15:0] wstrb,output wire wlast,wvalid,input wire wready,
 input wire [3:0] bid,input wire [1:0] bresp,input wire bvalid,
 output wire [31:0] araddr,output wire [7:0] arlen,output wire arvalid,input wire arready,
 input wire [3:0] rid,input wire [127:0] rdata,input wire [1:0] rresp,input wire rlast,rvalid,
 output wire rready);
 localparam PIXELS=WIDTH*HEIGHT,WORDS=PIXELS/64;
 wire reset=areset|!prst_n;
 reg capture_request,publish_toggle,publish_bank;
 reg capture_done,capture_bad,publish_ack;
 (* async_reg="true" *) reg [2:0] cq,cdq,eq,paq,pq,epochq;
 (* async_reg="true" *) reg [1:0] cbq,pbq,dm,ds;
 reg nvs_d,capture_armed,capture_active,cap_bad;
 reg [5:0] cap_phase;reg [21:0] cap_pixels;
 reg [127:0] cap_shift;
 wire cap_full,cap_empty;wire [4:0] cap_wlevel,cap_rlevel;
 wire [127:0] cap_data;
 wire cap_push=nde&&(capture_active||capture_armed)&&cap_phase==63;
 wire cap_pop;
 canny_capture_fifo capture_fifo(reset,pclk,cap_push,{token,cap_shift[127:2]},cap_full,cap_wlevel,
                         aclk,cap_pop,cap_data,cap_empty,cap_rlevel);
 always @(posedge pclk or posedge reset)
 if(reset)begin cq<=0;capture_done<=0;capture_bad<=0;nvs_d<=1;
  capture_armed<=0;capture_active<=0;cap_bad<=0;cap_phase<=0;cap_pixels<=0;cap_shift<=0;end
 else begin
  cq<={cq[1:0],capture_request};nvs_d<=nvs;
  if(nvs_d&&!nvs)begin
   if(capture_active)begin capture_active<=0;capture_done<=cq[2];
    capture_bad<=cap_bad||(cap_pixels!=PIXELS)||(cap_phase!=0);end
   else if(cq[2]!=capture_done)begin
    capture_armed<=1;cap_bad<=0;cap_phase<=0;cap_pixels<=0;cap_shift<=0;
   end
  end
  if(nde&&(capture_active||capture_armed))begin
   capture_active<=1;capture_armed<=0;cap_pixels<=cap_pixels+1'b1;
   cap_shift<={token,cap_shift[127:2]};cap_phase<=cap_phase+1'b1;
   if(cap_pixels>=PIXELS||(cap_push&&cap_full))cap_bad<=1;
  end
 end
 // Display-side mailbox, blanking handoff and consumption of 64 pixels/word.
 reg dvs_d,display_bank,display_valid,display_epoch,display_permit;
 reg [5:0] display_phase;reg [127:0] display_shift;
 reg display_bad,underflow,pixel_started;
 reg reader_epoch,reader_ready;
 (* async_reg="true" *) reg [1:0] rq,readyq;
 wire display_full,display_empty;wire [4:0] display_wlevel,display_rlevel;
 wire [127:0] display_data,display_write_data;wire display_push;
 reg display_fifo_reset;
 wire reader_matches=readyq[1]&&(rq[1]==display_epoch);
 wire visible=display_valid&&enabled&&reader_matches&&!display_bad;
 wire display_pop=dde&&visible&&display_phase==0&&!display_empty;
 canny_fifo display_fifo(reset|display_fifo_reset,aclk,display_push,display_write_data,
  display_full,display_wlevel,pclk,display_pop,display_data,display_empty,display_rlevel);
 assign edge_pixel=visible&&dde&&((display_phase==0)?(!display_empty&&display_data[1]):display_shift[1]);
 assign picture_valid=visible;
 wire [7:0] fps_q;
 wire result_visible_now=dvs_d&&!dvs&&(pq[2]!=publish_ack);
 canny_fps rate_meter(pclk,reset,enabled,result_visible_now,fps_q);
 // Count completed, visible Canny result publications, not HDMI refreshes.
 always @(posedge pclk or posedge reset)
 if(reset)begin pq<=0;pbq<=0;publish_ack<=0;dvs_d<=1;display_bank<=0;display_valid<=0;
  display_epoch<=0;display_permit<=0;display_phase<=0;display_shift<=0;display_bad<=0;
  underflow<=0;pixel_started<=0;rq<=0;readyq<=0;
 end else begin
  pq<={pq[1:0],publish_toggle};pbq<={pbq[0],publish_bank};dvs_d<=dvs;rq<={rq[0],reader_epoch};readyq<={readyq[0],reader_ready};
  if(!enabled)display_valid<=0;
  if(dvs_d&&!dvs)begin
   display_epoch<=~display_epoch;display_phase<=0;display_bad<=0;pixel_started<=0;
   display_permit<=enabled&&((pq[2]!=publish_ack)||display_valid);
   if(pq[2]!=publish_ack)begin
    publish_ack<=pq[2];display_bank<=pbq[1];display_valid<=enabled;
   end
  end
  if(dde&&display_valid&&enabled)begin
   pixel_started<=1;
   if(!reader_matches||(display_phase==0&&display_empty))begin display_bad<=1;underflow<=1;end
   else if(!display_bad)begin
    display_phase<=display_phase+1'b1;
    display_shift<=display_phase==0?{2'b0,display_data[127:2]}:{2'b0,display_shift[127:2]};
   end
  end
 end
 // Main frame controller. No artificial frame-rate divider: new frames start
 // as soon as the previous result has converged and been accepted by display.
 reg [2:0] phase;reg work_bank;
 reg [15:0] written_words;reg [4:0] settle;
 reg [3:0] error_q;
 reg [15:0] published_passes;
 wire eng_busy,eng_done,eng_error,eng_valid,eng_write,eng_ready,eng_mem_done,eng_mem_error;
 wire [31:0] eng_addr,eng_cycles;wire [127:0] eng_wdata;wire [15:0] eng_passes;
 wire [31:0] work_base=BASE+(work_bank?32'h00100000:32'd0);
 canny_hysteresis #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) hysteresis(
  aclk,reset,phase==2,!eq[2],work_base,eng_busy,eng_done,eng_error,eng_passes,eng_cycles,
  eng_valid,eng_write,eng_addr,eng_wdata,eng_ready,eng_mem_done,eng_mem_error,rdata);
 reg [2:0] tx;
 reg [7:0] tx_len,tx_beat;
 reg [1:0] owner;reg [31:0] address_q;reg [127:0] write_q;
 reg transaction_bad;
 wire write_complete=tx==5&&bvalid;
 wire read_complete=tx==2&&rvalid&&rready&&rlast;
 wire cap_complete=write_complete&&owner==1;
 always @(posedge aclk or posedge reset)
 if(reset)begin eq<=0;cdq<=0;cbq<=0;paq<=0;capture_request<=0;publish_toggle<=0;publish_bank<=0;
  phase<=0;work_bank<=0;written_words<=0;settle<=0;error_q<=0;published_passes<=0;end
 else begin
  eq<={eq[1:0],enabled};cdq<={cdq[1:0],capture_done};cbq<={cbq[0],capture_bad};paq<={paq[1:0],publish_ack};
  if((read_complete&&(rresp!=0||rid!=0||transaction_bad))||
     (write_complete&&(bresp!=0||bid!=0)))error_q[1]<=1;
  case(phase)
   0:if(eq[2]&&cap_empty)begin
    capture_request<=~capture_request;written_words<=0;settle<=0;phase<=1;
   end
   1:begin
    if(cap_complete)written_words<=written_words+{8'd0,tx_len}+16'd1;
    if(cdq[2]==capture_request&&cap_empty&&tx==0)begin
     if(settle<15)settle<=settle+1'b1;
     else if(cbq[1]||written_words!=WORDS)begin error_q[0]<=1;phase<=0;end
     else if(!eq[2]||error_q[1])phase<=0;else phase<=2;
    end else settle<=0;
   end
   2:phase<=3;
   3:if(eng_done&&eq[2]&&!eng_error)begin
    publish_bank<=work_bank;publish_toggle<=~publish_toggle;
    published_passes<=eng_passes;phase<=4;
   end else if(!eng_busy)begin if(eng_error)error_q[2]<=1;phase<=0;end
   4:if(paq[2]==publish_toggle)begin work_bank<=~work_bank;phase<=0;end
   default:phase<=0;
  endcase
 end
 // Reader flushes only between single-beat transactions. Bank/permit payload
 // remains stable for the complete display frame, after a synchronized epoch.
 reg epoch_seen,restart_pending;reg [1:0] reader_state;
 reg [5:0] reset_count;reg [15:0] read_words;
 reg selected_bank,selected_permit;
 always @(posedge aclk or posedge reset)
 if(reset)begin epochq<=0;dm<=0;ds<=0;epoch_seen<=0;restart_pending<=0;reader_state<=0;
  reset_count<=0;display_fifo_reset<=1;read_words<=0;selected_bank<=0;
  selected_permit<=0;reader_epoch<=0;reader_ready<=0;end
 else begin
  epochq<={epochq[1:0],display_epoch};dm<={display_bank,display_permit};ds<=dm;
  if(epochq[2]!=epoch_seen)begin epoch_seen<=epochq[2];restart_pending<=1;end
  if(restart_pending&&!(tx!=0&&owner==0))begin
   restart_pending<=0;reader_state<=1;display_fifo_reset<=1;reset_count<=0;
   reader_ready<=0;read_words<=0;
  end else case(reader_state)
   1:begin
    if(reset_count==31)begin display_fifo_reset<=0;reader_state<=2;
     selected_bank<=ds[1];selected_permit<=ds[0];reader_epoch<=epoch_seen;
    end else reset_count<=reset_count+1'b1;
   end
   2:begin
    if(read_complete&&owner==0)read_words<=read_words+{8'd0,tx_len}+16'd1;
    if(display_wlevel>=8||(WORDS<8&&read_words==WORDS))reader_ready<=selected_permit;
   end
   default:;
  endcase
 end
 wire display_request=reader_state==2&&selected_permit&&!restart_pending&&
  epochq[2]==epoch_seen&&read_words<WORDS&&display_wlevel<=8;
 wire capture_write=phase==1&&!cap_empty&&written_words<WORDS&&
                    (cap_rlevel>=4||cdq[2]==capture_request);
 wire [15:0] cap_remaining=WORDS-written_words;
 wire [4:0] cap_available=cap_rlevel>=4?5'd4:cap_rlevel;
 wire [4:0] cap_beats=cap_remaining<cap_available?cap_remaining[4:0]:cap_available;
 wire [15:0] display_remaining=WORDS-read_words;
 wire capture_discard=phase==1&&!cap_empty&&written_words>=WORDS;
 assign cap_pop=(tx==4&&owner==1&&wready&&!cap_empty)||
                (tx==0&&!display_request&&capture_discard);
 assign eng_ready=tx==0&&!display_request&&!capture_write&&eng_valid;
 assign eng_mem_done=(read_complete||write_complete)&&owner==2;
 assign eng_mem_error=transaction_bad||(tx==2?(rresp!=0||rid!=0):(bresp!=0||bid!=0));
 assign display_push=tx==2&&rvalid&&rready&&owner==0&&!display_fifo_reset;
 assign display_write_data=(rresp!=0||rid!=0||transaction_bad)?128'd0:rdata;
 assign awaddr=address_q;assign awlen=tx_len;assign awvalid=tx==3;
 assign wdata=owner==1?cap_data:write_q;assign wstrb=16'hffff;
 assign wlast=tx_beat==tx_len;assign wvalid=tx==4&&(owner!=1||!cap_empty);
 assign araddr=address_q;assign arlen=tx_len;assign arvalid=tx==1;
 assign rready=owner!=0||!display_full;
 always @(posedge aclk or posedge reset)
 if(reset)begin tx<=0;owner<=0;address_q<=0;write_q<=0;transaction_bad<=0;tx_len<=0;tx_beat<=0;end
 else case(tx)
  0:begin
   transaction_bad<=0;tx_beat<=0;
   if(display_request)begin owner<=0;address_q<=BASE+(selected_bank?32'h00100000:0)+({16'd0,read_words}<<4);
    tx_len<=display_remaining>=4?8'd3:display_remaining[7:0]-1'b1;tx<=1;end
   else if(capture_write)begin owner<=1;address_q<=work_base+({16'd0,written_words}<<4);
    tx_len<={3'd0,cap_beats}-1'b1;tx<=3;end
   else if(eng_valid)begin owner<=2;address_q<=eng_addr;write_q<=eng_wdata;tx_len<=0;tx<=eng_write?3:1;end
  end
  1:if(arready)tx<=2;
  2:if(rvalid&&rready)begin
   if(rlast!=(tx_beat==tx_len)||rresp!=0||rid!=0)transaction_bad<=1;
   if(rlast)tx<=0;else tx_beat<=tx_beat+1'b1;
  end
  3:if(awready)tx<=4;
  4:if(wvalid&&wready)begin if(wlast)tx<=5;else tx_beat<=tx_beat+1'b1;end
  5:if(bvalid)tx<=0;
  default:tx<=0;
 endcase
 // Status buses remain stable between result publications. Double sampling
 // is for OSD only; no image ownership or control depends on these samples.
 (* async_reg="true" *) reg [20:0] sm,ss;
 always @(posedge pclk or posedge reset)
 if(reset)begin sm<=0;ss<=0;end
 else begin sm<={phase!=0,published_passes,error_q};ss<=sm;end
 assign errors=ss[3:0]|{underflow,3'b000};
 assign passes=ss[19:4];assign processing=ss[20];assign fps=fps_q;
endmodule
