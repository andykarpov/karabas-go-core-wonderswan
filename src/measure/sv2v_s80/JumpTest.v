`default_nettype none
module JumpTest (
	opcode,
	flags,
	taken
);
	reg _sv2v_0;
	input wire [7:0] opcode;
	input wire [15:0] flags;
	output reg taken;
	always @(*) begin
		if (_sv2v_0)
			;
		taken = 1'b0;
		(* full_case, parallel_case *)
		casez (opcode)
			8'b01100010: taken = flags[4'd0];
			8'b01110000: taken = flags[4'd11];
			8'b01110001: taken = ~flags[4'd11];
			8'b01110010: taken = flags[4'd0];
			8'b01110011: taken = ~flags[4'd0];
			8'b01110100: taken = flags[4'd6];
			8'b01110101: taken = ~flags[4'd6];
			8'b01110110: taken = flags[4'd0] | flags[4'd6];
			8'b01110111: taken = ~(flags[4'd0] | flags[4'd6]);
			8'b01111000: taken = flags[4'd7];
			8'b01111001: taken = ~flags[4'd7];
			8'b01111010: taken = flags[4'd2];
			8'b01111011: taken = ~flags[4'd2];
			8'b01111100: taken = flags[4'd11] ^ flags[4'd7];
			8'b01111101: taken = ~(flags[4'd7] ^ flags[4'd11]);
			8'b01111110: taken = (flags[4'd11] ^ flags[4'd7]) | flags[4'd6];
			8'b01111111: taken = ~((flags[4'd7] ^ flags[4'd11]) | flags[4'd6]);
			8'b11001110: taken = flags[4'd11];
			default: taken = 1'b0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
