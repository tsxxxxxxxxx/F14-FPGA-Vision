// Independent read/write round-robin transaction ownership. The original
// frame store is master A, new Canny is master B. Never cancel accepted AXI
// traffic, and route every response only to its originating master.
module canny_axi_arbiter(
 input wire clk,reset,
 input wire [31:0] a_awaddr,input wire [7:0] a_awlen,input wire a_awvalid,output wire a_awready,
 input wire [127:0] a_wdata,input wire [15:0] a_wstrb,input wire a_wlast,a_wvalid,output wire a_wready,
 output wire [3:0] a_bid,output wire [1:0] a_bresp,output wire a_bvalid,
 input wire [3:0] a_arid,input wire [31:0] a_araddr,input wire [7:0] a_arlen,input wire a_arvalid,output wire a_arready,
 output wire [3:0] a_rid,output wire [127:0] a_rdata,output wire [1:0] a_rresp,
 output wire a_rlast,a_rvalid,input wire a_rready,
 input wire [31:0] b_awaddr,input wire [7:0] b_awlen,input wire b_awvalid,output wire b_awready,
 input wire [127:0] b_wdata,input wire [15:0] b_wstrb,input wire b_wlast,b_wvalid,output wire b_wready,
 output wire [3:0] b_bid,output wire [1:0] b_bresp,output wire b_bvalid,
 input wire [31:0] b_araddr,input wire [7:0] b_arlen,input wire b_arvalid,output wire b_arready,
 output wire [3:0] b_rid,output wire [127:0] b_rdata,output wire [1:0] b_rresp,
 output wire b_rlast,b_rvalid,input wire b_rready,
 output wire [31:0] m_awaddr,output wire [7:0] m_awlen,output wire m_awvalid,input wire m_awready,
 output wire [127:0] m_wdata,output wire [15:0] m_wstrb,output wire m_wlast,m_wvalid,input wire m_wready,
 input wire [3:0] m_bid,input wire [1:0] m_bresp,input wire m_bvalid,
 output wire [3:0] m_arid,output wire [31:0] m_araddr,output wire [7:0] m_arlen,output wire m_arvalid,input wire m_arready,
 input wire [3:0] m_rid,input wire [127:0] m_rdata,input wire [1:0] m_rresp,
 input wire m_rlast,m_rvalid,output wire m_rready);
 reg [1:0] ws,rs;reg wo,ro,wlast_owner,rlast_owner;
 assign m_awaddr=wo?b_awaddr:a_awaddr;assign m_awlen=wo?b_awlen:a_awlen;
 assign m_awvalid=ws==1&&(wo?b_awvalid:a_awvalid);
 assign a_awready=ws==1&&!wo&&m_awready;assign b_awready=ws==1&&wo&&m_awready;
 assign m_wdata=wo?b_wdata:a_wdata;assign m_wstrb=wo?b_wstrb:a_wstrb;
 assign m_wlast=wo?b_wlast:a_wlast;assign m_wvalid=ws==2&&(wo?b_wvalid:a_wvalid);
 assign a_wready=ws==2&&!wo&&m_wready;assign b_wready=ws==2&&wo&&m_wready;
 assign a_bid=m_bid;assign b_bid=m_bid;assign a_bresp=m_bresp;assign b_bresp=m_bresp;
 assign a_bvalid=ws==3&&!wo&&m_bvalid;assign b_bvalid=ws==3&&wo&&m_bvalid;
 assign m_arid=ro?4'd0:a_arid;assign m_araddr=ro?b_araddr:a_araddr;assign m_arlen=ro?b_arlen:a_arlen;
 assign m_arvalid=rs==1&&(ro?b_arvalid:a_arvalid);
 assign a_arready=rs==1&&!ro&&m_arready;assign b_arready=rs==1&&ro&&m_arready;
 assign a_rid=m_rid;assign b_rid=m_rid;assign a_rdata=m_rdata;assign b_rdata=m_rdata;
 assign a_rresp=m_rresp;assign b_rresp=m_rresp;assign a_rlast=m_rlast;assign b_rlast=m_rlast;
 assign a_rvalid=rs==2&&!ro&&m_rvalid;assign b_rvalid=rs==2&&ro&&m_rvalid;
 assign m_rready=rs==2&&(ro?b_rready:a_rready);
 always @(posedge clk)
 if(reset)begin ws<=0;rs<=0;wo<=0;ro<=0;wlast_owner<=1;rlast_owner<=1;end
 else begin
  case(ws)
   0:if(a_awvalid||b_awvalid)begin wo<=b_awvalid&&(!a_awvalid||!wlast_owner);ws<=1;end
   1:if(m_awvalid&&m_awready)ws<=2;
   2:if(m_wvalid&&m_wready&&m_wlast)ws<=3;
   3:if(m_bvalid)begin wlast_owner<=wo;ws<=0;end
  endcase
  case(rs)
   0:if(a_arvalid||b_arvalid)begin ro<=b_arvalid&&(!a_arvalid||!rlast_owner);rs<=1;end
   1:if(m_arvalid&&m_arready)rs<=2;
   2:if(m_rvalid&&m_rready&&m_rlast)begin rlast_owner<=ro;rs<=0;end
  endcase
 end
endmodule
