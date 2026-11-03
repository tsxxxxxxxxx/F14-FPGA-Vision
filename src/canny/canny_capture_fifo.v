// 64 x 128-bit asynchronous capture queue using one 512 x 16 RAM10.
// Each input word is serialized into eight synchronous RAM writes. Commit
// the Gray write pointer only after all eight chunks are stored. The reader
// prefetches eight chunks into a stable output word before exposing !empty.
// The upstream packs one word every 64 pixel clocks, leaving ample time for
// eight writes. Input full also covers the short serialization interval.
module canny_capture_fifo(
 input wire reset,wclk,wen,input wire [127:0] wdata,
 output wire full,output wire [4:0] wlevel,
 input wire rclk,ren,output wire [127:0] rdata,
 output wire empty,output wire [4:0] rlevel);
 reg [15:0] memory[0:511];
 reg [127:0] write_shift,read_word;
 reg writing,word_valid;reg [2:0] wi,ri,read_pos;
 reg [1:0] rstate;reg read_pipe;
 reg [6:0] wb,rb,wg,rg;
 (* async_reg="true" *) reg [6:0] rm,rs,wm,ws;
 (* async_reg="true" *) reg [1:0] wrst_pipe,rrst_pipe;
 always @(posedge wclk or posedge reset)
 if(reset)wrst_pipe<=2'b11;else wrst_pipe<={wrst_pipe[0],1'b0};
 always @(posedge rclk or posedge reset)
 if(reset)rrst_pipe<=2'b11;else rrst_pipe<={rrst_pipe[0],1'b0};
 wire wrst=wrst_pipe[1],rrst=rrst_pipe[1];
 function [6:0] binary(input [6:0] gray);
 integer i;begin binary[6]=gray[6];
 for(i=5;i>=0;i=i-1)binary[i]=binary[i+1]^gray[i];end endfunction
 wire [6:0] wn=wb+7'd1,rn=rb+7'd1;
 wire [6:0] used_w=wb-binary(rs),used_r=binary(ws)-rb;
 assign full=writing||(wg=={~rs[6:5],rs[4:0]})||wrst;
 assign empty=!word_valid||rrst;assign rdata=read_word;
 assign wlevel=used_w>31?5'd31:used_w[4:0];
 assign rlevel=used_r>31?5'd31:used_r[4:0];
 // No reset on RAM contents/output: inference requires a synchronous read.
 always @(posedge wclk)if(writing&&!wrst)
  memory[{wb[5:0],wi}]<=write_shift[15:0];
 reg [15:0] ram_q;
 always @(posedge rclk)if(rstate==1&&!rrst)
  ram_q<=memory[{rb[5:0],ri}];
 always @(posedge wclk or posedge wrst)
 if(wrst)begin wb<=0;wg<=0;rm<=0;rs<=0;writing<=0;wi<=0;write_shift<=0;end
 else begin
  rm<=rg;rs<=rm;
  if(wen&&!full)begin write_shift<=wdata;wi<=0;writing<=1;end
  if(writing)begin
   write_shift<={16'd0,write_shift[127:16]};
   if(wi==7)begin wb<=wn;wg<=(wn>>1)^wn;writing<=0;end
   else wi<=wi+1'b1;
  end
 end
 always @(posedge rclk or posedge rrst)
 if(rrst)begin rb<=0;rg<=0;wm<=0;ws<=0;word_valid<=0;
  read_word<=0;ri<=0;read_pos<=0;read_pipe<=0;rstate<=0;end
 else begin
  wm<=wg;ws<=wm;read_pipe<=rstate==1;
  if(rstate==1)begin
   read_pos<=ri;
   if(ri==7)rstate<=2;else ri<=ri+1'b1;
  end
  if(read_pipe)begin
   read_word[read_pos*16+:16]<=ram_q;
   if(read_pos==7)begin word_valid<=1;rstate<=3;end
  end
  if(rstate==0&&used_r!=0)begin ri<=0;rstate<=1;end
  if(ren&&!empty)begin rb<=rn;rg<=(rn>>1)^rn;word_valid<=0;rstate<=0;end
 end
endmodule
