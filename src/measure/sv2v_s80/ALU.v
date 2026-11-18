`default_nettype none
module ALU (
	a,
	b,
	out,
	is_8_bit,
	op,
	flags_in,
	flags_out,
	multibit_shift,
	shift_count,
	busy
);
	reg _sv2v_0;
	input wire [15:0] a;
	input wire [15:0] b;
	output reg [31:0] out;
	input wire is_8_bit;
	input wire [5:0] op;
	input wire [15:0] flags_in;
	output reg [15:0] flags_out;
	input wire multibit_shift;
	input wire [4:0] shift_count;
	output reg busy;
	task automatic do_aaa;
		output reg [15:0] out;
		input [15:0] a;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		reg [7:0] lo;
		reg [7:0] hi;
		begin
			flags_out = flags_in;
			lo = a[7:0];
			hi = a[15:8];
			if ((a[3:0] > 4'd9) || flags_in[4'd4]) begin
				lo = lo + 8'd6;
				hi = hi + 8'd1;
				flags_out[4'd0] = 1'b1;
				flags_out[4'd4] = 1'b1;
			end
			else begin
				flags_out[4'd0] = 1'b0;
				flags_out[4'd4] = 1'b0;
			end
			out = {hi, 4'b0000, lo[3:0]};
		end
	endtask
	task automatic do_aas;
		output reg [15:0] out;
		input [15:0] a;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		reg [7:0] lo;
		reg [7:0] hi;
		begin
			flags_out = flags_in;
			lo = a[7:0];
			hi = a[15:8];
			if ((a[3:0] > 4'd9) || flags_in[4'd4]) begin
				lo = lo - 8'd6;
				hi = hi - 8'd1;
				flags_out[4'd0] = 1'b1;
				flags_out[4'd4] = 1'b1;
			end
			else begin
				flags_out[4'd0] = 1'b0;
				flags_out[4'd4] = 1'b0;
			end
			out = {hi, 4'b0000, lo[3:0]};
		end
	endtask
	function automatic [15:0] common_flags;
		input [15:0] flags_in;
		input is_8_bit;
		input [15:0] out;
		input [15:0] a;
		input [15:0] b;
		reg [15:0] flags;
		begin
			flags = flags_in;
			flags[4'd2] = ~^out[7:0];
			flags[4'd4] = (a[4] ^ b[4]) ^ out[4];
			flags[4'd7] = out[(is_8_bit ? 7 : 15)];
			flags[4'd6] = (is_8_bit ? ~|out[7:0] : ~|out);
			common_flags = flags;
		end
	endfunction
	task automatic do_adc;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			if (!is_8_bit) begin
				{flags_out[4'd0], out} = (a + b) + {15'b000000000000000, flags_in[4'd0]};
				flags_out[4'd11] = ~(a[15] ^ b[15]) & (out[15] ^ b[15]);
			end
			else begin
				out = (a + b) + {15'b000000000000000, flags_in[4'd0]};
				flags_out[4'd0] = (a[8] ^ b[8]) ^ out[8];
				flags_out[4'd11] = ~(a[7] ^ b[7]) & (out[7] ^ b[7]);
			end
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
		end
	endtask
	task automatic do_add;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			if (!is_8_bit) begin
				{flags_out[4'd0], out} = a + b;
				flags_out[4'd11] = ~(a[15] ^ b[15]) & (out[15] ^ b[15]);
			end
			else begin
				out = a + b;
				flags_out[4'd0] = (a[8] ^ b[8]) ^ out[8];
				flags_out[4'd11] = ~(a[7] ^ b[7]) & (out[7] ^ b[7]);
			end
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
		end
	endtask
	task automatic do_and;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			out = a & b;
			{flags_out[4'd0], flags_out[4'd11]} = 2'b00;
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
			flags_out[4'd4] = 1'b0;
		end
	endtask
	task automatic do_bound;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			flags_out[4'd0] = $signed(a) < $signed(b);
		end
	endtask
	task automatic do_daa;
		output reg [15:0] out;
		input [15:0] a;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		reg [7:0] r;
		begin
			flags_out = flags_in;
			r = a[7:0];
			if ((a[3:0] > 4'd9) || flags_in[4'd4]) begin
				r = r + 8'h06;
				flags_out[4'd4] = 1'b1;
			end
			if ((a[7:0] > 8'h99) || flags_in[4'd0]) begin
				r = r + 8'h60;
				flags_out[4'd0] = 1'b1;
			end
			out = {a[15:8], r};
			flags_out[4'd2] = ~^r;
			flags_out[4'd7] = r[7];
			flags_out[4'd6] = ~|r;
		end
	endtask
	task automatic do_das;
		output reg [15:0] out;
		input [15:0] a;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		reg [7:0] r;
		begin
			flags_out = flags_in;
			r = a[7:0];
			if ((a[3:0] > 4'd9) || flags_in[4'd4]) begin
				r = r - 8'h06;
				flags_out[4'd4] = 1'b1;
			end
			if ((a[7:0] > 8'h99) || flags_in[4'd0]) begin
				r = r - 8'h60;
				flags_out[4'd0] = 1'b1;
			end
			out = {a[15:8], r};
			flags_out[4'd2] = ~^r;
			flags_out[4'd7] = r[7];
			flags_out[4'd6] = ~|r;
		end
	endtask
	task automatic do_enter_frame_temp_addr;
		output reg [15:0] out;
		input [15:0] a;
		input [4:0] b;
		out = a - {10'b0000000000, b, 1'b0};
	endtask
	task automatic do_extend;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		out = (is_8_bit ? {16 {a[7]}} : {16 {a[15]}});
	endtask
	task automatic do_mul;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		input is_signed;
		begin
			flags_out = flags_in;
			out = 32'b00000000000000000000000000000000;
			if (!is_8_bit) begin
				if (is_signed)
					out[31:0] = {{16 {a[15]}}, a} * {{16 {b[15]}}, b};
				else
					out[31:0] = {16'b0000000000000000, a} * {16'b0000000000000000, b};
				flags_out[4'd0] = |out[31:16];
				flags_out[4'd11] = |out[31:16];
			end
			else begin
				if (is_signed)
					out = {16'b0000000000000000, {{8 {a[7]}}, a[7:0]} * {{8 {b[7]}}, b[7:0]}};
				else
					out = {16'b0000000000000000, {8'b00000000, a[7:0]} * {8'b00000000, b[7:0]}};
				flags_out[4'd0] = |out[15:8];
				flags_out[4'd11] = |out[15:8];
			end
		end
	endtask
	task automatic do_not;
		output reg [15:0] out;
		input [15:0] a;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			out = ~a;
		end
	endtask
	task automatic do_or;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			out = a | b;
			{flags_out[4'd0], flags_out[4'd11]} = 2'b00;
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
			flags_out[4'd4] = 1'b0;
		end
	endtask
	function automatic [15:0] shift_flags;
		input [15:0] flags_in;
		input is_8_bit;
		input [15:0] out;
		input [15:0] a;
		reg [15:0] flags;
		begin
			flags = flags_in;
			flags[4'd2] = ~^out[7:0];
			flags[4'd7] = out[(is_8_bit ? 7 : 15)];
			flags[4'd6] = (is_8_bit ? ~|out[7:0] : ~|out);
			shift_flags = flags;
		end
	endfunction
	task automatic do_rcl;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				if (!is_8_bit)
					{flags_out[4'd0], out[15:0]} = {a[15:0], flags_out[4'd0]};
				else
					{flags_out[4'd0], out[7:0]} = {a[7:0], flags_out[4'd0]};
				flags_out[4'd11] = (is_8_bit ? a[7] ^ a[6] : a[15] ^ a[14]);
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_rcr;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				if (!is_8_bit)
					{out[15:0], flags_out[4'd0]} = {flags_out[4'd0], a[15:0]};
				else
					{out[7:0], flags_out[4'd0]} = {flags_out[4'd0], a[7:0]};
				flags_out[4'd11] = (is_8_bit ? a[7] ^ flags_in[4'd0] : a[15] ^ flags_in[4'd0]);
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_rol;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				if (!is_8_bit) begin
					flags_out[4'd0] = a[15];
					out[15:0] = {a[14:0], a[15]};
				end
				else begin
					flags_out[4'd0] = a[7];
					out[7:0] = {a[6:0], a[7]};
				end
				flags_out[4'd11] = (is_8_bit ? a[7] ^ a[6] : a[15] ^ a[14]);
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_ror;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				if (!is_8_bit) begin
					flags_out[4'd0] = a[0];
					out[15:0] = {a[0], out[15:1]};
				end
				else begin
					flags_out[4'd0] = a[0];
					out[7:0] = {a[0], out[7:1]};
				end
				flags_out[4'd11] = (is_8_bit ? a[7] ^ a[0] : a[15] ^ a[0]);
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_sar;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				if (!is_8_bit)
					{out[15:0], flags_out[4'd0]} = $signed({a, 1'b0}) >>> 1'b1;
				else
					{out[7:0], flags_out[4'd0]} = $signed({a[7:0], 1'b0}) >>> 1'b1;
				flags_out[4'd11] = 0;
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_sbb;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			if (!is_8_bit) begin
				{flags_out[4'd0], out} = (a - b) - {15'b000000000000000, flags_in[4'd0]};
				flags_out[4'd11] = (a[15] ^ b[15]) & (out[15] ^ a[15]);
			end
			else begin
				out = (a - b) - {15'b000000000000000, flags_in[4'd0]};
				flags_out[4'd0] = (a[8] ^ b[8]) ^ out[8];
				flags_out[4'd11] = (a[7] ^ b[7]) & (out[7] ^ a[7]);
			end
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
		end
	endtask
	task automatic do_shl;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				if (!is_8_bit) begin
					{flags_out[4'd0], out[15:0]} = {1'b0, a} << 1'b1;
					flags_out[4'd11] = a[15] ^ out[15];
				end
				else begin
					{flags_out[4'd0], out[7:0]} = {1'b0, a[7:0]} << 1'b1;
					flags_out[4'd11] = a[7] ^ out[7];
				end
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_shr;
		output reg [31:0] out;
		input is_8_bit;
		input [15:0] a;
		input [4:0] shift_count;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		output reg busy;
		input multibit_shift;
		begin
			flags_out = flags_in;
			out = {11'b00000000000, shift_count, a};
			if (|shift_count || !multibit_shift) begin
				{out[15:0], flags_out[4'd0]} = {a, 1'b0} >> 1'b1;
				flags_out = shift_flags(flags_out, is_8_bit, out[15:0], a);
				if (is_8_bit)
					flags_out[4'd11] = a[7] ^ out[7];
				else
					flags_out[4'd11] = a[15] ^ out[15];
				out[31:16] = {11'b00000000000, shift_count - 1'b1};
			end
			busy = multibit_shift && |out[20:16];
		end
	endtask
	task automatic do_sub;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			if (!is_8_bit) begin
				{flags_out[4'd0], out} = a - b;
				flags_out[4'd11] = (a[15] ^ b[15]) & (out[15] ^ a[15]);
			end
			else begin
				out = a - b;
				flags_out[4'd0] = (a[8] ^ b[8]) ^ out[8];
				flags_out[4'd11] = (a[7] ^ b[7]) & (out[7] ^ a[7]);
			end
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
		end
	endtask
	task automatic do_xor;
		output reg [15:0] out;
		input is_8_bit;
		input [15:0] a;
		input [15:0] b;
		input [15:0] flags_in;
		output reg [15:0] flags_out;
		begin
			flags_out = flags_in;
			out = a ^ b;
			{flags_out[4'd0], flags_out[4'd11]} = 2'b00;
			flags_out = common_flags(flags_out, is_8_bit, out, a, b);
			flags_out[4'd4] = 1'b0;
		end
	endtask
	always @(*) begin
		if (_sv2v_0)
			;
		flags_out = flags_in;
		out = 32'b00000000000000000000000000000000;
		busy = 1'b0;
		case (op)
			6'd0: out[15:0] = a;
			6'd1: out[15:0] = b;
			6'd2:
				do_add(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd3:
				do_adc(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd4:
				do_and(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd5:
				do_xor(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd6:
				do_or(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd34:
				do_bound(a, b, flags_in, flags_out);
			6'd33:
				do_bound(b, a, flags_in, flags_out);
			6'd7:
				do_sub(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd8:
				do_sub(out[15:0], is_8_bit, b, a, flags_in, flags_out);
			6'd9:
				do_sbb(out[15:0], is_8_bit, a, b, flags_in, flags_out);
			6'd10:
				do_sbb(out[15:0], is_8_bit, b, a, flags_in, flags_out);
			6'd35:
				do_enter_frame_temp_addr(out[15:0], a, b[4:0]);
			6'd11: out[15:0] = flags_in;
			6'd13: flags_out = a;
			6'd12: flags_out = b;
			6'd14: flags_out[4'd0] = ~flags_in[4'd0];
			6'd15:
				do_shr(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd16:
				do_shl(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd17:
				do_sar(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd18:
				do_ror(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd19:
				do_rol(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd20:
				do_rcl(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd21:
				do_rcr(out, is_8_bit, a, shift_count, flags_in, flags_out, busy, multibit_shift);
			6'd22:
				do_not(out[15:0], a, flags_in, flags_out);
			6'd24:
				do_aaa(out[15:0], a, flags_in, flags_out);
			6'd25:
				do_aas(out[15:0], a, flags_in, flags_out);
			6'd26:
				do_daa(out[15:0], a, flags_in, flags_out);
			6'd27:
				do_das(out[15:0], a, flags_in, flags_out);
			6'd28:
				do_mul(out, is_8_bit, a, b, flags_in, flags_out, 1'b0);
			6'd29:
				do_mul(out, is_8_bit, a, b, flags_in, flags_out, 1'b1);
			6'd32:
				do_extend(out[15:0], is_8_bit, a);
			6'd30:
				;
			6'd31:
				;
			6'd23:
				if (flags_in[4'd10])
					do_sub(out[15:0], 1'b0, a, b, flags_in, flags_out);
				else
					do_add(out[15:0], 1'b0, a, b, flags_in, flags_out);
			default:
				;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
