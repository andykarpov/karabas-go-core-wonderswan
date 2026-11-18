`timescale 1ns / 1ps
`default_nettype wire

/*
 ws_kbd.v

 The keys of the WonderSwan from the USB keyboard (the 6 key codes of the HID report, KB_DAT0..5 of
 kg_mcu2) and the pads of kg_mcu2 (JOY_L / JOY_R: [1] up, [2] down, [3] left, [4] right, [5] start,
 [6] A, [7] B, [8] C, [9] X, [10] Y, [11] Z, 1 = pressed), ORed.

 keys = { Start, B, A, Y4, Y3, Y2, Y1, X4, X3, X2, X1 }, 1 = pressed. The X pad (X1 up, X2 right,
 X3 down, X4 left) is the d-pad; the Y pad (the second cross, the d-pad of vertical games) is:
   keyboard: arrows = X pad, W D S A = Y1 Y2 Y3 Y4, X = A, Z = B, Enter = Start
   pads:     d-pad = X pad, X = Y1, C = Y2, Y = Y3, Z = Y4, A = A, B = B, start = Start
 Both pads and the keyboard drive the one machine.
*/

module ws_kbd (
	input  wire        clk,
	input  wire [7:0]  kb_dat0,
	input  wire [7:0]  kb_dat1,
	input  wire [7:0]  kb_dat2,
	input  wire [7:0]  kb_dat3,
	input  wire [7:0]  kb_dat4,
	input  wire [7:0]  kb_dat5,
	input  wire [12:0] joy_l,
	input  wire [12:0] joy_r,
	output reg  [10:0] keys = 11'd0
);

function [10:0] key;
	input [7:0] k;
	begin
		key = 11'd0;
		case (k)
		8'h52: key[0] = 1'b1;          // up: X1
		8'h4F: key[1] = 1'b1;          // right: X2
		8'h51: key[2] = 1'b1;          // down: X3
		8'h50: key[3] = 1'b1;          // left: X4
		8'h1A: key[4] = 1'b1;          // W: Y1
		8'h07: key[5] = 1'b1;          // D: Y2
		8'h16: key[6] = 1'b1;          // S: Y3
		8'h04: key[7] = 1'b1;          // A: Y4
		8'h1B: key[8] = 1'b1;          // X: A
		8'h1D: key[9] = 1'b1;          // Z: B
		8'h28: key[10] = 1'b1;         // Enter: Start
		default: ;
		endcase
	end
endfunction

function [10:0] pad;
	input [12:0] j;
	begin
		pad = { j[5], j[7], j[6], j[11], j[10], j[8], j[9], j[3], j[2], j[4], j[1] };
	end
endfunction

wire [10:0] kb = key(kb_dat0) | key(kb_dat1) | key(kb_dat2) | key(kb_dat3) | key(kb_dat4) | key(kb_dat5);

always @(posedge clk)
	keys <= kb | pad(joy_l) | pad(joy_r);

endmodule
