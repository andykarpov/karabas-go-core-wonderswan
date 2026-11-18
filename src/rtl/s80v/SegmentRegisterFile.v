`default_nettype none
module SegmentRegisterFile (
	clk,
	reset,
	rd_sel,
	rd_val,
	wr_en,
	wr_sel,
	wr_val,
	cs
);
	input wire clk;
	input wire reset;
	input wire [1:0] rd_sel;
	output reg [15:0] rd_val;
	input wire wr_en;
	input wire [1:0] wr_sel;
	input wire [15:0] wr_val;
	output wire [15:0] cs;
	reg [15:0] registers [0:3];
	wire rd_bypass = wr_en && (wr_sel == rd_sel);
	assign cs = registers[2'd1];
	always @(posedge reset)
		;
	always @(posedge clk)
		if (wr_en)
			registers[wr_sel] <= wr_val;
	always @(posedge clk) rd_val <= (rd_bypass ? wr_val : registers[rd_sel]);
endmodule
