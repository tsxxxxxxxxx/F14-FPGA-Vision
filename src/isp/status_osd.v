`timescale 1ns/1ps
// 5x7 font at 2x scale, 3 rows. Decimal conversion is sequential in vblank.
// Outside the small panel RGB is preserved exactly; all outputs registered.
module status_osd #(parameter WIDTH=1920)(
 input wire clk,rst_n,mode,input wire [10:0] threshold,
 input wire [7:0] fps_cam,fps_out,fps_new,input wire [11:0] width,height,
 input wire [1:0] ddr_mode,input wire [6:0] ddr_count,
 input wire [5:0] ddr_index,input wire [3:0] ddr_error,
 input wire [6:0] ddr_position,
 input wire in_vsync,in_hsync,in_de,input wire [23:0] in_rgb,
 output reg out_vsync,out_hsync,out_de,output reg [23:0] out_rgb);
 reg [11:0] x,y;reg vs_d,mode_q,busy;
 reg [11:0] binary;reg [15:0] work,bcd;reg [3:0] step;reg [2:0] field;
 reg [11:0] snapshot[0:7];reg [15:0] numbers[0:7];integer k;
 (* async_reg="true" *) reg [19:0] ddr_meta,ddr_sync;
 reg [1:0] ddr_mode_q;reg [3:0] ddr_error_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin ddr_meta<=0;ddr_sync<=0;end
 else begin ddr_meta<={ddr_mode,ddr_count,ddr_position,ddr_error};ddr_sync<=ddr_meta;end
 reg [15:0] adjusted,shifted;integer i;
 always @*begin
  adjusted=work;
  for(i=0;i<4;i=i+1)if(work[i*4+:4]>=5)adjusted[i*4+:4]=work[i*4+:4]+4'd3;
  shifted={adjusted[14:0],binary[11]};
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;vs_d<=1;mode_q<=0;busy<=0;binary<=0;work<=0;bcd<=16'h0080;step<=0;field<=0;ddr_mode_q<=3;ddr_error_q<=0;for(k=0;k<8;k=k+1)begin numbers[k]<=0;snapshot[k]<=0;end end
 else begin
  vs_d<=in_vsync;
  if(!in_vsync)begin x<=0;y<=0;end
  else if(in_de)if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
  if(vs_d && !in_vsync)begin binary<={1'b0,threshold};work<=0;step<=0;busy<=1;mode_q<=mode;field<=0;
   snapshot[0]<={1'b0,threshold};snapshot[1]<=width;snapshot[2]<=height;snapshot[3]<={4'd0,fps_cam};snapshot[4]<={4'd0,fps_out};snapshot[5]<={4'd0,fps_new};
   snapshot[6]<={5'd0,ddr_sync[17:11]};snapshot[7]<={5'd0,ddr_sync[10:4]};
   ddr_mode_q<=ddr_sync[19:18];ddr_error_q<=ddr_sync[3:0];end
  else if(busy)begin
   work<=shifted;binary<={binary[10:0],1'b0};step<=step+1'b1;
   if(step==11)begin numbers[field]<=shifted;
    if(field==7)busy<=0;else begin field<=field+1'b1;binary<=snapshot[field+1'b1];work<=0;step<=0;end
   end
  end
 end
 function [34:0] glyph(input [7:0] c);
 begin case(c)
  "/":glyph={5'b00001,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b10000};
  "0":glyph={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
  "1":glyph={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
  "2":glyph={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
  "3":glyph={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
  "4":glyph={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
  "5":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
  "6":glyph={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
  "7":glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
  "8":glyph={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
  "9":glyph={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
  "T":glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
  "B":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
  "X":glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
  "C":glyph={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
  "U":glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
  "G":glyph={5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
  "H":glyph={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
  "M":glyph={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
  "E":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
  "D":glyph={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
  "O":glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
  "N":glyph={5'b10001,5'b11001,5'b11001,5'b10101,5'b10011,5'b10011,5'b10001};
  "F":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
  "V":glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
  "I":glyph={5'b01110,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
  "W":glyph={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
  "S":glyph={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
  "P":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
  "L":glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
  "R":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
  "A":glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
  "Y":glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
  ":":glyph={5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000};
  default:glyph=0;
 endcase end
 endfunction
 wire [8:0] tx=x-12'd20;wire [6:0] ty=y-12'd20;
 wire [4:0] ch=tx/9'd12;wire [3:0] col=(tx%9'd12)>>1;wire [2:0] row=ty[3:1];
 wire panel=x>=16 && x<224 && y>=16 && y<152;
 reg [7:0] character;reg [34:0] bits;reg ink;
 always @*begin
  character=" ";
  case(ty[6:4])
   0:case(ch)
    0:character="T";1:character="H";2:character=":";
    3:character=8'd48+numbers[0][15:12];4:character=8'd48+numbers[0][11:8];
    5:character=8'd48+numbers[0][7:4];6:character=8'd48+numbers[0][3:0];
    9:character="F";10:character="1";11:character="3";default:;
   endcase
   1:case(ch)
    0:character="R";1:character="E";2:character="S";3:character=":";
    4:character=48+numbers[1][15:12];5:character=48+numbers[1][11:8];6:character=48+numbers[1][7:4];7:character=48+numbers[1][3:0];
    8:character=" ";9:character=48+numbers[2][15:12];10:character=48+numbers[2][11:8];11:character=48+numbers[2][7:4];12:character=48+numbers[2][3:0];default:;
   endcase
   2:case(ch)
    0:character="C";1:character="A";2:character="M";3:character=":";
    4:character=48+numbers[3][11:8];5:character=48+numbers[3][7:4];6:character=48+numbers[3][3:0];
    9:character="O";10:character="U";11:character="T";12:character=":";
    13:character=48+numbers[4][11:8];14:character=48+numbers[4][7:4];15:character=48+numbers[4][3:0];default:;
   endcase
   3:case(ch)
    0:character="N";1:character="E";2:character="W";3:character=":";
    4:character=48+numbers[5][11:8];5:character=48+numbers[5][7:4];6:character=48+numbers[5][3:0];
    8:character="F";9:character="P";10:character="S";default:;
   endcase
   4:case(ch)
    0:character="M";1:character="E";2:character="D";3:character=":";4:character="O";5:character="N";
    8:character=mode_q?"C":"S";9:character=mode_q?"O":"P";10:character=mode_q?"L":"L";11:character=mode_q?"O":"I";12:character=mode_q?"R":"T";default:;
   endcase
   5:case(ch)
    0:character="D";1:character="D";2:character="R";3:character=":";
    4:case(ddr_mode_q)0:character="L";1:character="H";2:character="P";default:character="W";endcase
    5:case(ddr_mode_q)0:character="I";1:character="O";2:character="L";default:character="A";endcase
    6:case(ddr_mode_q)0:character="V";1:character="L";2:character="A";default:character="I";endcase
    7:case(ddr_mode_q)0:character="E";1:character="D";2:character="Y";default:character="T";endcase
    default:;
   endcase
   6:case(ch)
    0:character="F";1:character="R";2:character=":";
    3:character=48+numbers[7][7:4];4:character=48+numbers[7][3:0];
    5:character="/";
    6:character=48+numbers[6][7:4];7:character=48+numbers[6][3:0];default:;
   endcase
   7:case(ch)
    0:character="E";1:character="R";2:character="R";3:character=":";
    4:character=ddr_error_q<10?48+ddr_error_q:55+ddr_error_q;default:;
   endcase
   default:;
  endcase
  bits=glyph(character);
  ink=x>=20 && x<212 && y>=20 && y<148 && row<7 && col<5 && bits[(6-row)*5+4-col];
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin out_vsync<=1;out_hsync<=1;out_de<=0;out_rgb<=0;end
 else begin
  out_vsync<=in_vsync;out_hsync<=in_hsync;out_de<=in_de;
  out_rgb<=!in_de?24'd0:panel?(ink?24'hffffff:24'h101010):in_rgb;
 end
endmodule
