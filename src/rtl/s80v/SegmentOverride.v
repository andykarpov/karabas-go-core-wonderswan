`default_nettype none
module SegmentOverride (
	clk,
	reset,
	next_instruction,
	flush,
	update,
	force_segment,
	bp_is_base,
	segment_override,
	override_in,
	microcode_sr_rd_sel,
	sr_rd_sel
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire next_instruction;
	input wire flush;
	input wire update;
	input wire force_segment;
	input wire bp_is_base;
	input wire segment_override;
	input wire [1:0] override_in;
	input wire [1:0] microcode_sr_rd_sel;
	output reg [1:0] sr_rd_sel;
	reg [1:0] override;
	reg override_active;
	always @(*) begin
		if (_sv2v_0)
			;
		if (force_segment)
			sr_rd_sel = microcode_sr_rd_sel;
		else if (update && segment_override)
			sr_rd_sel = override_in;
		else if (override_active)
			sr_rd_sel = override;
		else if (bp_is_base)
			sr_rd_sel = 2'd2;
		else
			sr_rd_sel = microcode_sr_rd_sel;
	end
	always @(posedge clk)
		if (reset) begin
			override_active <= 1'b0;
			override <= 2'b00;
		end
		else begin
			if (next_instruction || flush) begin
				override_active <= 1'b0;
				override <= 2'b00;
			end
			if (update && segment_override) begin
				override <= override_in;
				override_active <= 1'b1;
			end
		end
	initial _sv2v_0 = 0;
endmodule
