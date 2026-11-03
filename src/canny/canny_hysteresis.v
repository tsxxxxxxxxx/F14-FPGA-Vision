// Full-frame 8-connected hysteresis, not a fixed number of local links.
// Pixel states: 00 rejected, 01 weak, 11 strong/connected. Forward and reverse
// in-place sweeps repeat until a COMPLETE PAIR makes no changes. Therefore
// arbitrarily long weak paths connected to a strong seed are retained.
// No spatial decimation; 64 consecutive full-resolution pixels / DDR beat.
// A cancelled frame is never published. No partial-convergence fallback.
module canny_hysteresis #(parameter WIDTH=1920, HEIGHT=1080)(
 input wire clk,reset,start,cancel,input wire [31:0] base,
 output reg busy,done,error,output reg [15:0] passes,
 output reg [31:0] cycles,
 output wire mem_valid,mem_write,output wire [31:0] mem_addr,
 output wire [127:0] mem_wdata,input wire mem_ready,mem_done,mem_error,
 input wire [127:0] mem_rdata);
 localparam ROW_WORDS=WIDTH/64, ROW_BYTES=WIDTH/4, WORDS=WIDTH*HEIGHT/64;
 localparam IDLE=0,CR=1,CW=2,LR=3,LW=4,TR=5,TW=6,RR=7,RW=8,
 PREP=9,RUN=10,WR=11,WW=12,NEXT=13;
 reg [3:0] state;
 reg [31:0] bank,addr;
 reg [11:0] row;reg [6:0] col;reg [5:0] pixel;
 reg reverse,pair_changed,word_changed,previous;
 reg [127:0] current,above,left,right,result;
 reg [65:0] neighbors;
 wire boundary=reverse?(row==HEIGHT-1):(row==0);
 wire [31:0] above_addr=reverse?addr+ROW_BYTES:addr-ROW_BYTES;
 wire [1:0] old_pixel=reverse?current[127:126]:current[1:0];
 wire support=previous|(reverse?(|neighbors[65:63]):(|neighbors[2:0]));
 wire promote=(old_pixel==2'b01)&&support;
 wire [1:0] new_pixel=promote?2'b11:old_pixel;
 assign mem_valid=(state==CR)||(state==LR&&!boundary&&col!=0)||
  (state==TR&&!boundary)||(state==RR&&!boundary&&col!=ROW_WORDS-1)||(state==WR&&word_changed);
 assign mem_write=state==WR;
 assign mem_addr=(state==LR)?above_addr-16:(state==TR)?above_addr:
                 (state==RR)?above_addr+16:addr;
 assign mem_wdata=result;
 integer i;
 always @(posedge clk)
 if(reset)begin state<=IDLE;busy<=0;done<=0;error<=0;passes<=0;cycles<=0;
  bank<=0;addr<=0;row<=0;col<=0;pixel<=0;reverse<=0;pair_changed<=0;
  word_changed<=0;previous<=0;current<=0;above<=0;left<=0;right<=0;
  result<=0;neighbors<=0;
 end else begin
  done<=0;
  if(busy&&cycles!=32'hffffffff)cycles<=cycles+1'b1;
  case(state)
   IDLE:if(start)begin bank<=base;addr<=base;row<=0;col<=0;reverse<=0;
    pair_changed<=0;previous<=0;passes<=0;cycles<=0;error<=0;busy<=1;state<=CR;end
   CR:if(mem_ready)state<=CW;
   CW:if(mem_done)begin current<=mem_rdata;state<=LR;if(mem_error)begin error<=1;state<=IDLE;busy<=0;end end
   LR:if(boundary||col==0)begin left<=0;state<=TR;end else if(mem_ready)state<=LW;
   LW:if(mem_done)begin left<=mem_rdata;state<=TR;if(mem_error)begin error<=1;state<=IDLE;busy<=0;end end
   TR:if(boundary)begin above<=0;state<=RR;end else if(mem_ready)state<=TW;
   TW:if(mem_done)begin above<=mem_rdata;state<=RR;if(mem_error)begin error<=1;state<=IDLE;busy<=0;end end
   RR:if(boundary||col==ROW_WORDS-1)begin right<=0;state<=PREP;end else if(mem_ready)state<=RW;
   RW:if(mem_done)begin right<=mem_rdata;state<=PREP;if(mem_error)begin error<=1;state<=IDLE;busy<=0;end end
   PREP:begin
    neighbors[0]<=left[127];neighbors[65]<=right[1];
    for(i=0;i<64;i=i+1)neighbors[i+1]<=above[2*i+1];
    pixel<=0;result<=0;word_changed<=0;state<=RUN;
   end
   RUN:begin
    current<=reverse?{current[125:0],2'b00}:{2'b00,current[127:2]};
    result<=reverse?{result[125:0],new_pixel}:{new_pixel,result[127:2]};
    neighbors<=reverse?{neighbors[64:0],1'b0}:{1'b0,neighbors[65:1]};
    previous<=new_pixel[1];
    if(promote)begin pair_changed<=1;word_changed<=1;end
    if(pixel==63)state<=WR;else pixel<=pixel+1'b1;
   end
   WR:if(!word_changed)state<=NEXT;else if(mem_ready)state<=WW;
   WW:if(mem_done)begin state<=NEXT;if(mem_error)begin error<=1;state<=IDLE;busy<=0;end end
   NEXT:begin
    if((!reverse&&row==HEIGHT-1&&col==ROW_WORDS-1)||
       (reverse&&row==0&&col==0))begin
     if(passes!=65535)passes<=passes+1'b1;
     previous<=0;
     if(!reverse)begin reverse<=1;state<=CR;end
     else if(!pair_changed)begin done<=1;busy<=0;state<=IDLE;end
     else begin reverse<=0;pair_changed<=0;state<=CR;end
    end else begin
     addr<=reverse?addr-16:addr+16;
     if(!reverse)begin
      if(col==ROW_WORDS-1)begin col<=0;row<=row+1'b1;previous<=0;end else col<=col+1'b1;
     end else begin
      if(col==0)begin col<=ROW_WORDS-1;row<=row-1'b1;previous<=0;end else col<=col-1'b1;
     end
     state<=CR;
    end
   end
   default:begin error<=1;busy<=0;state<=IDLE;end
  endcase
  // Once a transaction has been accepted it is always drained first.
  // Do not cancel a request in the same cycle it is accepted.
  if(cancel&&busy&&((state==RUN)||(state==PREP)||(state==NEXT)))begin
   busy<=0;state<=IDLE;
  end
 end
endmodule
