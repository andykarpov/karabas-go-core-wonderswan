`default_nettype none
module ModRMDecode (
	clk,
	reset,
	start,
	clear,
	modrm,
	displacement,
	si,
	di,
	bp,
	bx,
	effective_address,
	regnum,
	rm_is_reg,
	rm_regnum,
	bp_as_base
);
	input wire clk;
	input wire reset;
	input wire start;
	input wire clear;
	input wire [7:0] modrm;
	input wire [15:0] displacement;
	input wire [15:0] si;
	input wire [15:0] di;
	input wire [15:0] bp;
	input wire [15:0] bx;
	output reg [15:0] effective_address;
	output reg [2:0] regnum;
	output reg rm_is_reg;
	output reg [2:0] rm_regnum;
	output reg bp_as_base;
	wire [1:0] _mod = modrm[7:6];
	wire [2:0] _reg = modrm[5:3];
	wire [2:0] _rm = modrm[2:0];
	always @(posedge clk)
		if (reset) begin
			bp_as_base <= 1'b0;
			rm_is_reg <= 1'b0;
			regnum <= 3'b000;
			rm_regnum <= 3'b000;
		end
		else begin
			if (clear)
				bp_as_base <= 1'b0;
			if (start) begin
				regnum <= _reg;
				rm_regnum <= _rm;
				rm_is_reg <= _mod == 2'b11;
				case (_mod)
					2'b00: bp_as_base <= (_rm == 3'b010) || (_rm == 3'b011);
					2'b01: bp_as_base <= ((_rm == 3'b010) || (_rm == 3'b011)) || (_rm == 3'b110);
					2'b10: bp_as_base <= ((_rm == 3'b010) || (_rm == 3'b011)) || (_rm == 3'b110);
					default: bp_as_base <= 1'b0;
				endcase
			end
		end
	always @(posedge clk)
		if (reset)
			effective_address <= 16'b0000000000000000;
		else if (start) begin
			effective_address <= 16'b0000000000000000;
			case (_mod)
				2'b00:
					case (_rm)
						3'd0: effective_address <= bx + si;
						3'd1: effective_address <= bx + di;
						3'd2: effective_address <= bp + si;
						3'd3: effective_address <= bp + di;
						3'd4: effective_address <= si;
						3'd5: effective_address <= di;
						3'd6: effective_address <= displacement;
						3'd7: effective_address <= bx;
					endcase
				2'b01, 2'b10:
					case (_rm)
						3'd0: effective_address <= (bx + si) + displacement;
						3'd1: effective_address <= (bx + di) + displacement;
						3'd2: effective_address <= (bp + si) + displacement;
						3'd3: effective_address <= (bp + di) + displacement;
						3'd4: effective_address <= si + displacement;
						3'd5: effective_address <= di + displacement;
						3'd6: effective_address <= bp + displacement;
						3'd7: effective_address <= bx + displacement;
					endcase
				2'b11: effective_address <= 16'b0000000000000000;
			endcase
		end
endmodule
