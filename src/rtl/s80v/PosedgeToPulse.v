`default_nettype none
module PosedgeToPulse (
	clk,
	reset,
	d,
	q
);
	input wire clk;
	input wire reset;
	input wire d;
	output reg q;
	reg d_prev;
	always @(posedge clk) d_prev <= d;
	always @(posedge clk)
		if (reset)
			q <= 1'b0;
		else
			q <= (d ^ d_prev) & d;
endmodule
