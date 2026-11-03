// Preserve local paper brightness; exclude saturated dark colored distractors.
module shapes_pixel_gate(input wire [23:0] rgb,output wire [7:0] gray);
 wire [7:0] r=rgb[23:16],g=rgb[15:8],b=rgb[7:0];
 wire [7:0] hi_rg=r>g?r:g,lo_rg=r<g?r:g;
 wire [7:0] hi=hi_rg>b?hi_rg:b,lo=lo_rg<b?lo_rg:b;
 wire [9:0] sum={2'b0,r}+{1'b0,g,1'b0}+{2'b0,b};
 wire [7:0] luma=sum[9:2];
 assign gray=(hi-lo>8'd48&&luma<8'd96)?8'd128:luma;
endmodule
