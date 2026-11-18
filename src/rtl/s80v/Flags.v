`default_nettype none
module Flags (
	clk,
	reset,
	flags_in,
	update_flags,
	flags_out
);
	input wire clk;
	input wire reset;
	input wire [15:0] flags_in;
	input wire [8:0] update_flags;
	output wire [15:0] flags_out;
	reg C;
	reg P;
	reg A;
	reg Z;
	reg S;
	reg T;
	reg I;
	reg D;
	reg O;
	generate
		if (1) begin : genblk1
			assign flags_out = {4'b1111, O, D, I, T, S, Z, 1'b0, A, 1'b0, P, 1'b1, C};
		end
	endgenerate
	always @(posedge clk)
		if (reset) begin
			C <= 1'b0;
			P <= 1'b0;
			A <= 1'b0;
			Z <= 1'b0;
			S <= 1'b0;
			T <= 1'b0;
			I <= 1'b0;
			D <= 1'b0;
			O <= 1'b0;
		end
		else begin
			C <= (update_flags[4'd0] ? flags_in[4'd0] : C);
			P <= (update_flags[4'd1] ? flags_in[4'd2] : P);
			A <= (update_flags[4'd2] ? flags_in[4'd4] : A);
			Z <= (update_flags[4'd3] ? flags_in[4'd6] : Z);
			S <= (update_flags[4'd4] ? flags_in[4'd7] : S);
			T <= (update_flags[4'd5] ? flags_in[4'd8] : T);
			I <= (update_flags[4'd6] ? flags_in[4'd9] : I);
			D <= (update_flags[4'd7] ? flags_in[4'd10] : D);
			O <= (update_flags[4'd8] ? flags_in[4'd11] : O);
		end
endmodule
