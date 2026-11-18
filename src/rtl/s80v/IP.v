`default_nettype none
module IP (
	clk,
	reset,
	start_instruction,
	next_instruction,
	rollback,
	inc,
	wr_en,
	wr_val,
	val
);
	input wire clk;
	input wire reset;
	input wire start_instruction;
	input wire next_instruction;
	input wire rollback;
	input wire [3:0] inc;
	input wire wr_en;
	input wire [15:0] wr_val;
	output wire [15:0] val;
	reg [15:0] cur_val;
	reg [15:0] instruction_start_addr;
	assign val = cur_val;
	always @(posedge clk)
		if (reset)
			instruction_start_addr <= 16'b0000000000000000;
		else if (start_instruction || next_instruction)
			instruction_start_addr <= (wr_en ? wr_val : cur_val);
		else if (next_instruction)
			instruction_start_addr <= cur_val;
	always @(posedge clk)
		if (reset)
			cur_val <= 16'b0000000000000000;
		else if (wr_en)
			cur_val <= wr_val;
		else if (rollback)
			cur_val <= instruction_start_addr;
		else if (start_instruction)
			cur_val <= cur_val + {12'b000000000000, inc};
endmodule
