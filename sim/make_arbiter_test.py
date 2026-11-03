from pathlib import Path
import re
R=Path(__file__).resolve().parent
t=(R/'tb_store.sv').read_text().replace('module tb_store;','module tb_store_arbiter;')
s=t.index(' ddr_frame_store #');e=t.index(' reg [127:0] mem',s)
b=t[s:e]
ports={'awaddr':32,'awlen':8,'awvalid':1,'awready':1,'wdata':128,'wstrb':16,'wlast':1,'wvalid':1,'wready':1,
 'bid':4,'bresp':2,'bvalid':1,'arid':4,'araddr':32,'arlen':8,'arvalid':1,'arready':1,
 'rid':4,'rdata':128,'rresp':2,'rlast':1,'rvalid':1,'rready':1}
for n in ports:
 b=re.sub(r'\.axi_'+n+r'\([^)]*\)',f'.axi_{n}(a_{n})',b)
t=t[:s]+b+t[e:]
t=t.replace('mem[0:(SLOTS*(1<<SB)/16)-1]','mem[0:(SLOTS*(1<<SB)/16)]')
t=t.replace('if(awaddr+16*(awlen+1)>SLOTS*(1<<SB))','if(awaddr!=DUMMY_ADDR&&awaddr+16*(awlen+1)>SLOTS*(1<<SB))')
t=t.replace('if(dut.read_enabled&&','if(awaddr!=DUMMY_ADDR&&dut.read_enabled&&')
t=t.replace('wp=awaddr/16;','wp=awaddr==DUMMY_ADDR?DUMMY:awaddr/16;')
t=t.replace('if(wdata[127-byte_lane*8 -: 8]!==','if(wp!=DUMMY&&wdata[127-byte_lane*8 -: 8]!==')
t=t.replace('burst_writes=burst_writes+1;','if(wp!=DUMMY)burst_writes=burst_writes+1;')
t=t.replace('bresp<=inject_b?2:0','bresp<=(inject_b&&wp!=DUMMY)?2:0')
t=t.replace('rp=araddr/16;','rp=araddr==DUMMY_ADDR?DUMMY:araddr/16;')
t=t.replace('if(!dut.valid_slots[dut.read_slot])','if(araddr!=DUMMY_ADDR&&!dut.valid_slots[dut.read_slot])')
t=t.replace('PASS DDR STORE','PASS F14 SHARED DDR STORE').replace('PASS DDR FULLHD','PASS F14 SHARED DDR FULLHD')
t=t.replace('$finish;','if(b_checks<100)$fatal(1,"too little concurrent Canny traffic");$display("CANNY concurrent read/write checks=%0d",b_checks);$finish;')
decl=['localparam DUMMY=SLOTS*(1<<SB)/16,DUMMY_ADDR=32\'h08000000;']
for prefix in ['a','b']:
 for n,w in ports.items():
  decl.append(f'wire {("["+str(w-1)+":0] ") if w>1 else ""}{prefix}_{n};')
m={'awaddr':'awaddr','awlen':'awlen','awvalid':'awvalid','awready':'awready',
   'wdata':'wdata','wstrb':'strb','wlast':'wlast','wvalid':'wvalid','wready':'wready',
   'bid':"4'd0",'bresp':'bresp','bvalid':'bvalid','arid':'unused_arid','araddr':'araddr','arlen':'arlen',
   'arvalid':'arvalid','arready':'arready','rid':"4'd0",'rdata':'rdata','rresp':"2'd0",'rlast':'rlast','rvalid':'rvalid','rready':'rready'}
decl+=['wire [3:0] unused_arid;','canny_axi_arbiter arb(.clk(clk),.reset(rst),']
conn=[]
for side in ['a','b','m']:
 for n in ports:
  if side=='b' and n=='arid':continue
  conn.append(f'.{side}_{n}({m[n] if side=="m" else side+"_"+n})')
decl.append(','.join(conn)+');')
decl+=['''
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
''']
t=t.replace('endmodule','\n'.join(decl)+'\nendmodule')
(R/'tb_store_arbiter.sv').write_text(t)
print('Generated concurrent F13 DDR/Canny arbiter regression')
