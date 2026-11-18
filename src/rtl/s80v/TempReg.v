`default_nettype none
module TempReg (
	clk,
	reset,
	wr_val,
	wr_en,
	val
);
	input wire clk;
	input wire reset;
	input wire [15:0] wr_val;
	input wire wr_en;
	output wire [15:0] val;
	reg [15:0] r;
	assign val = r;
	always @(posedge clk)
		if (reset)
			r <= 16'b0000000000000000;
		else if (wr_en)
			r <= wr_val;
endmodule
