`timescale 1ns/1ps
// F13: full-frame 8-connected components, local paper/ink contrast checks,
// 32x32 six-class template match, and spatially associated 3-result stability.
// Scratch only; never accesses DDR or stalls video. Invalid/overflow frames
// publish no detections. Memory arrays have synchronous read ports, no reset.
module shapes_core #(parameter W=240,H=135,MAX_OBJECTS=8)(
 input wire clk,rst_n,enabled,frame_start,sample_valid,input wire [7:0] sample_gray,
 output wire busy,output reg result_update,output reg [MAX_OBJECTS-1:0] result_valid,
 output reg [MAX_OBJECTS*3-1:0] result_class,
 output reg [MAX_OBJECTS*8-1:0] result_x0,result_y0,result_x1,result_y1,
 output reg overflow);
 localparam IDLE=0,CAPTURE=1,CLEAR=2,SCAN_REQ=3,SCAN_WAIT=4,SCAN_USE=5,
  ROOT_LEFT=6,ROOT_TOP=7,ASSIGN=8,NEXT_PIXEL=9,MERGE_START=10,MERGE_ROOT=11,MERGE_USE=12,
  OBJECT=13,OBJECT_CHECK=14,RING_REQ=15,RING_WAIT=16,RING_USE=17,
  NORM_REQ=18,NORM_WAIT=19,NORM_USE=20,MATCH_REQ=21,MATCH_WAIT=22,MATCH_POP=23,
  MATCH_SUM=24,MATCH_ADD=25,CLASSIFY=26,ASSOC=27,SAVE=28,NEXT_OBJECT=29,PUBLISH=30,REDUCE=31,
  FILTER_REQ=32,FILTER_WAIT=33,FILTER_USE=34,SELECT_ROOT=35;
 reg [5:0] state;reg [2:0] image_mem[0:W*H-1];reg mask_mem[0:W*H-1];reg black_q;
 reg [3:0] filter_probe,filter_votes;reg filter_center;
 reg [6:0] line_labels[0:W-1];
 reg [31:0] normalized[0:31],templates[0:1343];
 initial $readmemh("src/isp/shapes_templates.mem",templates);
 reg [14:0] write_addr,read_addr,scan_addr;reg [2:0] gray_q;reg [6:0] top_q,right_q,top_previous;
 reg [7:0] x,y;reg [6:0] parent[0:95];
 reg [7:0] xmin[0:95],ymin[0:95],xmax[0:95],ymax[0:95];reg [15:0] area[0:95];
 reg [6:0] left_label,left_root,top_root,right_root,diagonal_root,assigned,next_label,idx,root;
 reg [1:0] root_phase;
 reg labels_full,frame_overflow;reg [7:0] bx0,by0,bx1,by1,bw,bh;reg [15:0] object_area;
 reg [7:0] rx,ry;reg [15:0] ring_total,ring_white;
 reg [4:0] nx,ny;reg [1:0] probe;reg [2:0] votes;reg [31:0] norm_row,norm_q,template_q;
 reg norm_seen;reg [5:0] norm_gap;reg [10:0] hole_count;
 reg [1:0] rotation;reg [10:0] class_score[0:5];
 reg [12:0] ring_sum;reg [8:0] center_sum;
 reg [5:0] tid;reg [2:0] cls,variant;reg [4:0] match_row;
 reg [10:0] score,class_best,best,second;reg [2:0] best_class;
 reg [3:0] pop0,pop1,pop2,pop3;reg [5:0] pop_total;
 reg [3:0] count;reg [3:0] assoc_index;reg [1:0] stable;
 reg [MAX_OBJECTS-1:0] pending_valid,previous_valid;
 reg [2:0] pending_class[0:MAX_OBJECTS-1],previous_class[0:MAX_OBJECTS-1];
 reg [7:0] pending_x0[0:MAX_OBJECTS-1],pending_y0[0:MAX_OBJECTS-1],pending_x1[0:MAX_OBJECTS-1],pending_y1[0:MAX_OBJECTS-1];
 reg [7:0] previous_x0[0:MAX_OBJECTS-1],previous_y0[0:MAX_OBJECTS-1],previous_x1[0:MAX_OBJECTS-1],previous_y1[0:MAX_OBJECTS-1];
 reg [1:0] previous_stable[0:MAX_OBJECTS-1],pending_stable[0:MAX_OBJECTS-1];
 integer i;
 function [6:0] minlabel(input [6:0] a,b);begin minlabel=a==0?b:b==0?a:a<b?a:b;end endfunction
 reg [6:0] selected;
 wire [8:0] px={nx,2'b00}+(probe[0]?9'd3:9'd1),py={ny,2'b00}+(probe[1]?9'd3:9'd1);
 wire [8:0] rotated_px=rotation==0?px:rotation==1?(9'd127-py):rotation==2?(9'd127-px):py;
 wire [8:0] rotated_py=rotation==0?py:rotation==1?px:rotation==2?(9'd127-py):(9'd127-px);
 wire [16:0] mx=rotated_px*bw,my=rotated_py*bh;
 wire [7:0] sx=bx0+mx[14:7],sy=by0+my[14:7];
 wire [31:0] xor_row=norm_q^template_q;wire [10:0] new_score=score+pop_total;
 wire [10:0] variant_score=new_score<class_best?new_score:class_best;
 wire [15:0] box_area=bw*bh;
 wire ring_border=rx==bx0-2||rx==bx1+2||ry==by0-2||ry==by1+2;
 wire [7:0] aspect_w=rotation[0]?bh:bw,aspect_h=rotation[0]?bw:bh;
 wire aspect_ok=(cls==0||cls==1)?({2'b0,aspect_w}*4>=({2'b0,aspect_h}*3)&&({2'b0,aspect_w}*4<=({2'b0,aspect_h}*5))):
  ({2'b0,aspect_w}*4>=({2'b0,aspect_h}*3)&&({2'b0,aspect_w}*4<=({2'b0,aspect_h}*6)));
 wire [24:0] paper_contrast_left={ring_sum,6'b0};
 wire [24:0] paper_contrast_right=({1'b0,center_sum}+10'd128)*ring_total;
 wire [1:0] filter_col=filter_probe%3,filter_row=filter_probe/3;
 wire [7:0] filter_x=filter_col==0?(x==0?x:x-1'b1):filter_col==2?(x==W-1?x:x+1'b1):x;
 wire [7:0] filter_y=filter_row==0?(y==0?y:y-1'b1):filter_row==2?(y==H-1?y:y+1'b1):y;
 function [3:0] pop8(input [7:0] v);integer b;begin pop8=0;for(b=0;b<8;b=b+1)pop8=pop8+v[b];end endfunction
 function near(input [7:0] a,b);begin near=({1'b0,a}+9'd4>={1'b0,b})&&({1'b0,b}+9'd4>={1'b0,a});end endfunction
 assign busy=state!=IDLE&&state!=CAPTURE;
 always @(posedge clk)begin
  if(enabled&&state==CAPTURE&&sample_valid&&!frame_start)image_mem[write_addr]<=sample_gray[7:5];
  gray_q<=image_mem[read_addr];black_q<=mask_mem[read_addr];top_q<=line_labels[x];right_q<=line_labels[x==W-1?x:x+1'b1];
  if(state==FILTER_USE&&filter_probe==8)mask_mem[scan_addr]<=filter_center&&(filter_votes+(gray_q<3))>=4;
  if(state==NEXT_PIXEL)line_labels[x]<=assigned;
  if(state==NORM_USE&&probe==3)normalized[ny]<={((votes+black_q)>=2),norm_row[31:1]};
  norm_q<=normalized[match_row];template_q<=templates[{tid,5'b0}+match_row];
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=IDLE;write_addr<=0;read_addr<=0;scan_addr<=0;x<=0;y<=0;left_label<=0;left_root<=0;top_root<=0;assigned<=0;next_label<=1;idx<=0;root<=0;
  labels_full<=0;frame_overflow<=0;result_update<=0;result_valid<=0;result_class<=0;result_x0<=0;result_y0<=0;result_x1<=0;result_y1<=0;overflow<=0;right_root<=0;diagonal_root<=0;root_phase<=0;top_previous<=0;
  bx0<=0;by0<=0;bx1<=0;by1<=0;bw<=0;bh<=0;object_area<=0;rx<=0;ry<=0;ring_total<=0;ring_white<=0;nx<=0;ny<=0;probe<=0;votes<=0;norm_row<=0;
  tid<=0;cls<=0;variant<=0;match_row<=0;score<=0;class_best<=2047;best<=2047;second<=2047;best_class<=7;pop0<=0;pop1<=0;pop2<=0;pop3<=0;pop_total<=0;
  count<=0;assoc_index<=0;stable<=0;pending_valid<=0;previous_valid<=0;norm_seen<=0;norm_gap<=0;hole_count<=0;rotation<=0;ring_sum<=0;center_sum<=0;
  filter_probe<=0;filter_votes<=0;filter_center<=0;selected<=0;
  for(i=0;i<6;i=i+1)class_score[i]<=2047;
  for(i=0;i<MAX_OBJECTS;i=i+1)begin previous_stable[i]<=0;pending_stable[i]<=0;previous_class[i]<=7;pending_class[i]<=7;previous_x0[i]<=0;previous_y0[i]<=0;previous_x1[i]<=0;previous_y1[i]<=0;pending_x0[i]<=0;pending_y0[i]<=0;pending_x1[i]<=0;pending_y1[i]<=0;end
 end else begin
  result_update<=0;
  if(!enabled)begin state<=IDLE;result_valid<=0;previous_valid<=0;pending_valid<=0;overflow<=0;end
  else case(state)
   IDLE:if(frame_start)begin state<=CAPTURE;write_addr<=0;end
   CAPTURE:if(frame_start)write_addr<=0;else if(sample_valid)begin
    write_addr<=write_addr+1'b1;if(write_addr==W*H-1)begin state<=FILTER_REQ;x<=0;y<=0;scan_addr<=0;filter_probe<=0;filter_votes<=0;idx<=0;count<=0;pending_valid<=0;frame_overflow<=0;labels_full<=0;end
   end
   FILTER_REQ:begin read_addr<=filter_y*W+filter_x;state<=FILTER_WAIT;end
   FILTER_WAIT:state<=FILTER_USE;
   FILTER_USE:begin
    if(filter_probe==4)filter_center<=gray_q<3;
    if(filter_probe==8)begin
     filter_probe<=0;filter_votes<=0;scan_addr<=scan_addr+1'b1;
     if(x==W-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
     if(scan_addr==W*H-1)state<=CLEAR;else state<=FILTER_REQ;
    end else begin filter_probe<=filter_probe+1'b1;filter_votes<=filter_votes+(gray_q<3);state<=FILTER_REQ;end
   end
   CLEAR:begin
    parent[idx]<=idx;xmin[idx]<=255;ymin[idx]<=255;xmax[idx]<=0;ymax[idx]<=0;area[idx]<=0;
    if(idx==95)begin x<=0;y<=0;scan_addr<=0;read_addr<=0;left_label<=0;next_label<=1;state<=SCAN_REQ;end else idx<=idx+1'b1;
   end
   SCAN_REQ:begin read_addr<=scan_addr;state<=SCAN_WAIT;end
   SCAN_WAIT:state<=SCAN_USE;
   SCAN_USE:if(!black_q)begin assigned<=0;state<=NEXT_PIXEL;end else begin
    left_root<=x==0?0:left_label;top_root<=y==0?0:top_q;right_root<=y==0||x==W-1?0:right_q;diagonal_root<=y==0||x==0?0:top_previous;root_phase<=0;state<=ROOT_LEFT;
   end
   ROOT_LEFT:if(left_root!=0&&parent[left_root]!=left_root)left_root<=parent[left_root];else state<=ROOT_TOP;
   ROOT_TOP:case(root_phase)
    0:if(top_root!=0&&parent[top_root]!=top_root)top_root<=parent[top_root];else root_phase<=1;
    1:if(right_root!=0&&parent[right_root]!=right_root)right_root<=parent[right_root];else root_phase<=2;
    2:if(diagonal_root!=0&&parent[diagonal_root]!=diagonal_root)diagonal_root<=parent[diagonal_root];else state<=SELECT_ROOT;
   endcase
   SELECT_ROOT:begin selected<=minlabel(minlabel(left_root,top_root),minlabel(right_root,diagonal_root));state<=ASSIGN;end
   ASSIGN:begin
    if(selected==0)begin
     if(labels_full)begin assigned<=0;frame_overflow<=1;end
     else begin assigned<=next_label;xmin[next_label]<=x;xmax[next_label]<=x;ymin[next_label]<=y;ymax[next_label]<=y;area[next_label]<=1;
      if(next_label==95)labels_full<=1;else next_label<=next_label+1'b1;end
    end else begin
     assigned<=selected;area[selected]<=area[selected]+1'b1;
     if(x<xmin[selected])xmin[selected]<=x;if(x>xmax[selected])xmax[selected]<=x;
     if(y<ymin[selected])ymin[selected]<=y;if(y>ymax[selected])ymax[selected]<=y;
     if(left_root!=0&&left_root!=selected)parent[left_root]<=selected;
     if(top_root!=0&&top_root!=selected)parent[top_root]<=selected;
     if(right_root!=0&&right_root!=selected)parent[right_root]<=selected;
     if(diagonal_root!=0&&diagonal_root!=selected)parent[diagonal_root]<=selected;
    end
    state<=NEXT_PIXEL;
   end
   NEXT_PIXEL:begin
    left_label<=assigned;scan_addr<=scan_addr+1'b1;top_previous<=top_q;
    if(x==W-1)begin x<=0;y<=y+1'b1;left_label<=0;end else x<=x+1'b1;
    if(scan_addr==W*H-1)begin idx<=1;state<=MERGE_START;end else state<=SCAN_REQ;
   end
   MERGE_START:begin root<=idx;state<=MERGE_ROOT;end
   MERGE_ROOT:if(parent[root]!=root)root<=parent[root];else state<=MERGE_USE;
   MERGE_USE:begin
    if(root!=idx&&area[idx]!=0)begin
     area[root]<=area[root]+area[idx];area[idx]<=0;
     if(xmin[idx]<xmin[root])xmin[root]<=xmin[idx];if(xmax[idx]>xmax[root])xmax[root]<=xmax[idx];
     if(ymin[idx]<ymin[root])ymin[root]<=ymin[idx];if(ymax[idx]>ymax[root])ymax[root]<=ymax[idx];
    end
    if(idx==95)begin idx<=1;state<=OBJECT;end else begin idx<=idx+1'b1;state<=MERGE_START;end
   end
   OBJECT:begin
    bx0<=xmin[idx];by0<=ymin[idx];bx1<=xmax[idx];by1<=ymax[idx];
    bw<=xmax[idx]-xmin[idx]+1'b1;bh<=ymax[idx]-ymin[idx]+1'b1;object_area<=area[idx];state<=OBJECT_CHECK;
   end
   OBJECT_CHECK:begin
    if(!frame_overflow&&object_area>=64&&bw>=10&&bh>=10&&bx0>=3&&by0>=3&&bx1<W-3&&by1<H-3&&
      {1'b0,object_area}*4>={1'b0,box_area}&&{1'b0,bw}<=({1'b0,bh}*2)&&{1'b0,bh}<=({1'b0,bw}*2))begin
     rx<=bx0-2;ry<=by0-2;ring_total<=0;ring_white<=0;ring_sum<=0;center_sum<=0;rotation<=0;
     for(i=0;i<6;i=i+1)class_score[i]<=2047;
     state<=RING_REQ;
    end else state<=NEXT_OBJECT;
   end
   RING_REQ:begin read_addr<=ry*W+rx;state<=RING_WAIT;end
   RING_WAIT:state<=RING_USE;
   RING_USE:begin
    if(ring_border)begin ring_total<=ring_total+1'b1;ring_sum<=ring_sum+gray_q;if(gray_q>=3)ring_white<=ring_white+1'b1;end
    if(rx==bx1+2)begin rx<=bx0-2;ry<=ry+1'b1;end else rx<=rx+1'b1;
    if(rx==bx1+2&&ry==by1+2)begin
     nx<=0;ny<=0;probe<=0;votes<=0;norm_row<=0;norm_seen<=0;norm_gap<=0;hole_count<=0;state<=NORM_REQ;
    end else state<=RING_REQ;
   end
   NORM_REQ:begin read_addr<=sy*W+sx;state<=NORM_WAIT;end
   NORM_WAIT:state<=NORM_USE;
   NORM_USE:begin
    if(rotation==0&&nx>=14&&nx<18&&ny>=14&&ny<18)center_sum<=center_sum+gray_q;
    if(probe==3)begin
     norm_row<={((votes+black_q)>=2),norm_row[31:1]};probe<=0;votes<=0;
     if((votes+black_q)>=2)begin norm_seen<=1;norm_gap<=0;if(rotation==0)hole_count<=hole_count+norm_gap;end
     else if(norm_seen)norm_gap<=norm_gap+1'b1;
     if(nx==31)begin nx<=0;ny<=ny+1'b1;norm_row<=0;norm_seen<=0;norm_gap<=0;
      if(ny==31)begin tid<=0;cls<=0;variant<=0;match_row<=0;score<=0;class_best<=2047;best<=2047;second<=2047;best_class<=7;state<=MATCH_REQ;end else state<=NORM_REQ;
     end else begin nx<=nx+1'b1;state<=NORM_REQ;end
    end else begin votes<=votes+black_q;probe<=probe+1'b1;state<=NORM_REQ;end
   end
   MATCH_REQ:state<=MATCH_WAIT;
   MATCH_WAIT:state<=MATCH_POP;
   MATCH_POP:begin pop0<=pop8(xor_row[7:0]);pop1<=pop8(xor_row[15:8]);pop2<=pop8(xor_row[23:16]);pop3<=pop8(xor_row[31:24]);state<=MATCH_SUM;end
   MATCH_SUM:begin pop_total<={2'b0,pop0}+{2'b0,pop1}+{2'b0,pop2}+{2'b0,pop3};state<=MATCH_ADD;end
   MATCH_ADD:begin
    if(match_row==31)begin
     if(variant==6)begin
      if(aspect_ok&&variant_score<class_score[cls])class_score[cls]<=variant_score;
      cls<=cls+1'b1;variant<=0;class_best<=2047;
     end else begin variant<=variant+1'b1;class_best<=variant_score;end
     tid<=tid+1'b1;match_row<=0;score<=0;
     if(tid==41)begin
      if(rotation==3)begin cls<=0;best<=2047;second<=2047;best_class<=7;state<=REDUCE;end
      else begin rotation<=rotation+1'b1;nx<=0;ny<=0;probe<=0;votes<=0;norm_row<=0;norm_seen<=0;norm_gap<=0;state<=NORM_REQ;end
     end else state<=MATCH_REQ;
    end else begin score<=new_score;match_row<=match_row+1'b1;state<=MATCH_REQ;end
   end
   REDUCE:begin
    if(class_score[cls]<best)begin second<=best;best<=class_score[cls];best_class<=cls;end
    else if(class_score[cls]<second)second<=class_score[cls];
    if(cls==5)state<=CLASSIFY;else cls<=cls+1'b1;
   end
   CLASSIFY:begin
    if(hole_count<=12&&best<=112&&second>=best+16&&best_class<6&&ring_white*8>=ring_total*7&&paper_contrast_left>=paper_contrast_right)begin
     if(count==MAX_OBJECTS)begin frame_overflow<=1;state<=NEXT_OBJECT;end
     else begin assoc_index<=0;stable<=1;state<=ASSOC;end
    end else state<=NEXT_OBJECT;
   end
   ASSOC:begin
    if(previous_valid[assoc_index]&&previous_class[assoc_index]==best_class&&
      near(previous_x0[assoc_index],bx0)&&near(previous_y0[assoc_index],by0)&&near(previous_x1[assoc_index],bx1)&&near(previous_y1[assoc_index],by1))
      stable<=previous_stable[assoc_index]<3?previous_stable[assoc_index]+1'b1:2'd3;
    if(assoc_index==MAX_OBJECTS-1)state<=SAVE;else assoc_index<=assoc_index+1'b1;
   end
   SAVE:begin
    pending_valid[count]<=1;pending_class[count]<=best_class;pending_x0[count]<=bx0;pending_y0[count]<=by0;pending_x1[count]<=bx1;pending_y1[count]<=by1;pending_stable[count]<=stable;count<=count+1'b1;state<=NEXT_OBJECT;
   end
   NEXT_OBJECT:if(idx==95)state<=PUBLISH;else begin idx<=idx+1'b1;state<=OBJECT;end
   PUBLISH:begin
    overflow<=frame_overflow;result_update<=1;previous_valid<=frame_overflow?0:pending_valid;
    for(i=0;i<MAX_OBJECTS;i=i+1)begin
     result_valid[i]<=!frame_overflow&&pending_valid[i]&&pending_stable[i]>=3;
     result_class[i*3+:3]<=pending_class[i];result_x0[i*8+:8]<=pending_x0[i];result_y0[i*8+:8]<=pending_y0[i];result_x1[i*8+:8]<=pending_x1[i];result_y1[i*8+:8]<=pending_y1[i];
     previous_class[i]<=pending_class[i];previous_stable[i]<=pending_stable[i];previous_x0[i]<=pending_x0[i];previous_y0[i]<=pending_y0[i];previous_x1[i]<=pending_x1[i];previous_y1[i]<=pending_y1[i];
    end
    state<=IDLE;
   end
   default:state<=IDLE;
  endcase
 end
endmodule
