`timescale 1ns/1ps
// Non-blocking instrumentation. CAM counts sensor EOF, OUT full output frames,
// NEW output frames with a distinct scheduler source ID (not HDMI refresh).
module video_metrics #(parameter SYS_HZ=96000000)(
 input wire sys_clk,sys_rst_n,cam_clk,cam_rst_n,cam_vs,
 input wire clk,rst_n,vs,de,input wire [31:0] source_id,input wire source_update,
 output reg [7:0] fps_cam,fps_out,fps_new,output reg [11:0] width,height);
 reg [31:0] timer;reg tick;
 always @(posedge sys_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin timer<=0;tick<=0;end
 else if(timer==SYS_HZ-1)begin timer<=0;tick<=~tick;end else timer<=timer+1'b1;
 reg cv;reg [15:0] cam_count,cam_gray;
 always @(posedge cam_clk or negedge cam_rst_n)
 if(!cam_rst_n)begin cv<=0;cam_count<=0;cam_gray<=0;end
 else begin cv<=cam_vs;if(cv&&!cam_vs)begin cam_count<=cam_count+1'b1;cam_gray<=((cam_count+16'd1)>>1)^(cam_count+16'd1);end end
 (* ASYNC_REG="TRUE" *) reg [2:0] ticks,updates;
 (* ASYNC_REG="TRUE" *) reg [15:0] cg1,cg2;
 (* ASYNC_REG="TRUE" *) reg [31:0] sid1,sid2;
 reg tick_seen,update_seen;reg [31:0] stable_id,frame_id,last_id;
 reg vd,dd,started;reg [11:0] line_pixels,lines,max_width;reg [15:0] oc,nc,prev_c,prev_o,prev_n;
 function [15:0] ungray(input [15:0] g);integer j;begin ungray[15]=g[15];for(j=14;j>=0;j=j-1)ungray[j]=ungray[j+1]^g[j];end endfunction
 function [7:0] sat(input [15:0] n);begin sat=n>255?255:n[7:0];end endfunction
 wire [15:0] cb=ungray(cg2);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  ticks<=0;updates<=0;cg1<=0;cg2<=0;sid1<=0;sid2<=0;tick_seen<=0;update_seen<=0;stable_id<=0;
  frame_id<=0;last_id<=0;vd<=1;dd<=0;started<=0;line_pixels<=0;lines<=0;max_width<=0;
  oc<=0;nc<=0;prev_c<=0;prev_o<=0;prev_n<=0;fps_cam<=0;fps_out<=0;fps_new<=0;width<=0;height<=0;
 end else begin
  ticks<={ticks[1:0],tick};updates<={updates[1:0],source_update};cg1<=cam_gray;cg2<=cg1;sid1<=source_id;sid2<=sid1;
  if(updates[2]!=update_seen)begin stable_id<=sid2;update_seen<=updates[2];end
  vd<=vs;dd<=de;
  if(de)begin line_pixels<=line_pixels+1'b1;if(!started)begin started<=1;frame_id<=stable_id;end end
  if(dd&&!de)begin if(line_pixels>max_width)max_width<=line_pixels;line_pixels<=0;lines<=lines+1'b1;end
  if(vd&&!vs)begin
    if(started&&lines!=0)begin
      oc<=oc+1'b1;width<=max_width;height<=lines;
      if(frame_id!=0&&frame_id!=last_id)nc<=nc+1'b1;
      last_id<=frame_id;
    end
    started<=0;line_pixels<=0;lines<=0;max_width<=0;
  end
  if(ticks[2]!=tick_seen)begin
    tick_seen<=ticks[2];fps_cam<=sat(cb-prev_c);fps_out<=sat(oc-prev_o);fps_new<=sat(nc-prev_n);
    prev_c<=cb;prev_o<=oc;prev_n<=nc;
  end
 end
endmodule
