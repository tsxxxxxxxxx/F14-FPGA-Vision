// Count completed result publications in exact one-second windows.
// A publication on the closing clock belongs to that window, never lost.
module canny_fps #(parameter CLOCK_HZ=148500000)(
 input wire clk,reset,enabled,new_frame,output reg [7:0] fps);
 localparam CW=$clog2(CLOCK_HZ);
 reg [CW-1:0] cycles;reg [7:0] count;
 wire [7:0] including_now=(new_frame&&count!=255)?count+8'd1:count;
 always @(posedge clk or posedge reset)
 if(reset)begin cycles<=0;count<=0;fps<=0;end
 else if(!enabled)begin cycles<=0;count<=0;fps<=0;end
 else if(cycles==CLOCK_HZ-1)begin cycles<=0;count<=0;fps<=including_now;end
 else begin cycles<=cycles+1'b1;count<=including_now;end
endmodule
