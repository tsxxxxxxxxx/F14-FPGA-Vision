`timescale 1ns/1ps
module tb_buttons;
 reg clk=0,rst=0,vs=1;always #5 clk=~clk;
 reg [7:0] keys=255;wire mode,toggle;wire [10:0] threshold;wire [2:0] cmd;
 ddr_controls #(.DEBOUNCE_CYCLES(4))dut(clk,rst,keys,vs,mode,threshold,cmd,toggle);
 task press(input integer n);begin @(negedge clk);keys[n]=0;repeat(20)@(negedge clk);keys[n]=1;repeat(12)@(negedge clk);end endtask
 task frame;begin vs=0;repeat(3)@(negedge clk);vs=1;repeat(3)@(negedge clk);end endtask
 reg old;
 initial begin #30;rst=1;repeat(6)@(negedge clk);
  press(0);if(threshold!=80)$fatal;frame();if(threshold!=88)$fatal;
  press(1);frame();if(threshold!=80)$fatal;
  keys[0]=0;repeat(200)@(negedge clk);keys[0]=1;repeat(12)@(negedge clk);frame();if(threshold!=88)$fatal(1,"long hold repeat");
  press(2);frame();if(mode!=1)$fatal;
  old=toggle;press(3);if(cmd!=1||toggle==old)$fatal;
  old=toggle;press(4);if(cmd!=2||toggle==old)$fatal;
  old=toggle;press(5);if(cmd!=0||toggle==old)$fatal;
  old=toggle;press(6);if(cmd!=3||toggle==old)$fatal;
  old=toggle;press(7);if(cmd!=4||toggle==old)$fatal;
  // Contact bounce does not pass the stable interval.
  repeat(8)begin keys[1]=0;@(negedge clk);keys[1]=1;@(negedge clk);end
  repeat(12)@(negedge clk);frame();if(threshold!=88)$fatal;
  $display("PASS DDR BUTTONS eight independent functions, hold-once, bounce, frame commit");$finish;
 end
endmodule
