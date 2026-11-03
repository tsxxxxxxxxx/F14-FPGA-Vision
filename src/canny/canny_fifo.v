// Small Gray-pointer asynchronous FIFO. Asynchronous read deliberately uses
// flip-flops/muxes, not additional RAM10 blocks. Data precedes synchronized
// pointer publication by at least two receiving-clock edges.
module canny_fifo #(parameter BITS=128, AW=4)(
 input wire reset, wclk, wen, input wire [BITS-1:0] wdata,
 output reg full, output wire [AW:0] wlevel,
 input wire rclk, ren, output wire [BITS-1:0] rdata,
 output reg empty, output wire [AW:0] rlevel);
 reg [BITS-1:0] mem[0:(1<<AW)-1];
 (* async_reg="true" *) reg [1:0] wrst_pipe,rrst_pipe;
 always @(posedge wclk or posedge reset)
 if(reset)wrst_pipe<=2'b11;else wrst_pipe<={wrst_pipe[0],1'b0};
 always @(posedge rclk or posedge reset)
 if(reset)rrst_pipe<=2'b11;else rrst_pipe<={rrst_pipe[0],1'b0};
 wire wrst=wrst_pipe[1],rrst=rrst_pipe[1];
 reg [AW:0] wb,rb,wg,rg;
 (* async_reg="true" *) reg [AW:0] rm,rs,wm,ws;
 wire [AW:0] wn=wb+(wen&&!full),rn=rb+(ren&&!empty);
 wire [AW:0] wgn=(wn>>1)^wn,rgn=(rn>>1)^rn;
 function [AW:0] binary(input [AW:0] gray);
 integer i;begin binary[AW]=gray[AW];
 for(i=AW-1;i>=0;i=i-1)binary[i]=binary[i+1]^gray[i];end endfunction
 assign rdata=mem[rb[AW-1:0]];
 assign wlevel=wb-binary(rs);assign rlevel=binary(ws)-rb;
 always @(posedge wclk)if(wen&&!full&&!wrst)mem[wb[AW-1:0]]<=wdata;
 always @(posedge wclk or posedge wrst)
 if(wrst)begin wb<=0;wg<=0;rm<=0;rs<=0;full<=0;end
 else begin rm<=rg;rs<=rm;wb<=wn;wg<=wgn;
 full<=wgn=={~rs[AW:AW-1],rs[AW-2:0]};end
 always @(posedge rclk or posedge rrst)
 if(rrst)begin rb<=0;rg<=0;wm<=0;ws<=0;empty<=1;end
 else begin wm<=wg;ws<=wm;rb<=rn;rg<=rgn;empty<=rgn==ws;end
endmodule
