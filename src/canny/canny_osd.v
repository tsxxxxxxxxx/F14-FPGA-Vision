module canny_osd #(parameter WIDTH=1920)(
 input wire clk,rst_n,vs,de,edge_bit,valid,input wire [10:0] threshold,
 input wire [7:0] fps,input wire [15:0] passes,input wire [3:0] errors,
 output wire [23:0] rgb);
 reg [11:0] x,y;reg vd;
 reg [15:0] binary;reg [19:0] work;reg [19:0] numbers[0:2];
 reg [15:0] snapshots[0:2];reg [4:0] step;reg [1:0] field;reg busy;
 reg [19:0] adjusted,shifted;integer i,k;
 always @*begin adjusted=work;
  for(i=0;i<5;i=i+1)if(work[i*4+:4]>=5)adjusted[i*4+:4]=work[i*4+:4]+4'd3;
  shifted={adjusted[18:0],binary[15]};
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;vd<=1;binary<=0;work<=0;step<=0;field<=0;busy<=0;
  for(k=0;k<3;k=k+1)begin numbers[k]<=0;snapshots[k]<=0;end
 end else begin
  vd<=vs;
  if(!vs)begin x<=0;y<=0;end
  else if(de)begin if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
  if(vd&&!vs)begin snapshots[0]<={5'd0,threshold};snapshots[1]<={8'd0,fps};snapshots[2]<=passes;
   binary<={5'd0,threshold};work<=0;step<=0;field<=0;busy<=1;
  end else if(busy)begin
   work<=shifted;binary<={binary[14:0],1'b0};step<=step+1'b1;
   if(step==15)begin numbers[field]<=shifted;
    if(field==2)busy<=0;else begin field<=field+1'b1;binary<=snapshots[field+1'b1];work<=0;step<=0;end
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
 wire [5:0] ch=tx/12;wire [3:0] col=(tx%12)>>1;wire [2:0] row=ty[3:1];
 reg [7:0] c;reg [34:0] bits;reg ink;
 always @*begin
  c=" ";
  case(ty[6:4])
   0:case(ch)0:c="F";1:c="1";2:c="4";4:c="C";5:c="A";6:c="N";7:c="N";8:c="Y";
      10:c=valid?"R":"W";11:c=valid?"E":"A";12:c=valid?"A":"I";13:c=valid?"D":"T";14:c=valid?"Y":" ";endcase
   1:case(ch)0:c="R";1:c="E";2:c="S";3:c=":";4:c="1";5:c="9";6:c="2";7:c="0";
      8:c="X";9:c="1";10:c="0";11:c="8";12:c="0";endcase
   2:case(ch)0:c="C";1:c="N";2:c="Y";3:c=":";
      4:c=48+numbers[1][11:8];5:c=48+numbers[1][7:4];6:c=48+numbers[1][3:0];8:c="F";9:c="P";10:c="S";endcase
   3:case(ch)0:c="T";1:c="H";2:c=":";3:c=48+numbers[0][15:12];4:c=48+numbers[0][11:8];
      5:c=48+numbers[0][7:4];6:c=48+numbers[0][3:0];8:c="E";9:c="R";10:c="R";11:c=":";
      12:c=errors<10?48+errors:55+errors;endcase
   4:case(ch)0:c="P";1:c="A";2:c="S";3:c="S";4:c=":";5:c=48+numbers[2][19:16];6:c=48+numbers[2][15:12];
      7:c=48+numbers[2][11:8];8:c=48+numbers[2][7:4];9:c=48+numbers[2][3:0];endcase
  endcase
  bits=glyph(c);ink=x>=20&&x<212&&y>=20&&y<100&&col<5&&row<7&&bits[(6-row)*5+4-col];
 end
 assign rgb=!de?24'd0:(x>=16&&x<224&&y>=16&&y<104)?(ink?(errors!=0?24'hff4040:24'h00ffff):24'h101820):{24{edge_bit}};
endmodule
