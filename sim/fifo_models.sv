// Simulation-only behavioral adapters. NOT substitutes for vendor IP in build.
module W0_FIFO_32(input wr_clk_i,rd_clk_i,a_rst_i,wr_en_i,rd_en_i,input [31:0] wdata,
 output full_o,empty_o,output [127:0] rdata,output [8:0] rd_datacount_o);
 reg [31:0] mem[0:2047];integer wp=0,rp=0;
 assign full_o=(wp-rp*4)>=2048;assign empty_o=(wp/4)==rp;
 assign rd_datacount_o=(wp/4)-rp;
 // Official IP ENDIANESS=0: earliest word/byte occupies the most significant lane.
 assign rdata={mem[rp*4%2048],mem[(rp*4+1)%2048],mem[(rp*4+2)%2048],mem[(rp*4+3)%2048]};
 always @(posedge wr_clk_i or posedge a_rst_i)if(a_rst_i)wp<=0;else if(wr_en_i&&!full_o)begin mem[wp%2048]<=wdata;wp<=wp+1;end
 always @(posedge rd_clk_i or posedge a_rst_i)if(a_rst_i)rp<=0;else if(rd_en_i&&!empty_o)rp<=rp+1;
endmodule
module R0_FIFO_8(input wr_clk_i,rd_clk_i,a_rst_i,wr_en_i,rd_en_i,input [127:0] wdata,
 output full_o,prog_full_o,empty_o,output [7:0] rdata);
 reg [127:0] mem[0:511];integer wp=0,rp=0;
 assign full_o=wp-(rp/16)>=512;assign prog_full_o=wp-(rp/16)>=256;
 assign empty_o=wp*16==rp;assign rdata=mem[(rp/16)%512] >> (8*(15-rp%16));
 always @(posedge wr_clk_i or posedge a_rst_i)if(a_rst_i)wp<=0;else if(wr_en_i&&!full_o)begin mem[wp%512]<=wdata;wp<=wp+1;end
 always @(posedge rd_clk_i or posedge a_rst_i)if(a_rst_i)rp<=0;else if(rd_en_i&&!empty_o)rp<=rp+1;
endmodule
