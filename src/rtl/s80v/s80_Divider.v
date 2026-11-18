`default_nettype none
module s80_Divider (
	clk,
	reset,
	start,
	is_8_bit,
	is_signed,
	busy,
	complete,
	error,
	dividend,
	divisor,
	quotient,
	remainder
);
	input wire clk;
	input wire reset;
	input wire start;
	input wire is_8_bit;
	input wire is_signed;
	output wire busy;
	output reg complete;
	output reg error;
	input wire [31:0] dividend;
	input wire [15:0] divisor;
	output reg [15:0] quotient;
	output reg [15:0] remainder;
	wire dvd_neg = is_signed & (is_8_bit ? dividend[15] : dividend[31]);
	wire dvs_neg = is_signed & (is_8_bit ? divisor[7] : divisor[15]);
	wire [31:0] dvd_ext = (is_8_bit ? {{16 {dividend[15]}}, dividend[15:0]} : dividend);
	wire [15:0] dvs_ext = (is_8_bit ? {{8 {divisor[7]}}, divisor[7:0]} : divisor);
	wire [31:0] dvd_mag = (dvd_neg ? -dvd_ext : dvd_ext);
	wire [15:0] dvs_mag = (dvs_neg ? -dvs_ext : dvs_ext);
	wire [15:0] dvs_w = (is_8_bit ? {8'd0, dvs_mag[7:0]} : dvs_mag);
	wire [15:0] hi = (is_8_bit ? {8'd0, dvd_mag[15:8]} : dvd_mag[31:16]);
	wire [15:0] lo = (is_8_bit ? {dvd_mag[7:0], 8'd0} : dvd_mag[15:0]);
	wire div_by_zero = dvs_w == 16'd0;
	wire mag_overflow = hi >= dvs_w;
	reg [1:0] state;
	reg [15:0] R;
	reg [15:0] A;
	reg [15:0] D;
	reg [3:0] n;
	reg s8;
	reg q_neg;
	reg r_neg;
	reg sgn;
	wire [16:0] R2 = {R, A[15]};
	wire [16:0] diff = R2 - {1'b0, D};
	wire qbit = !diff[16];
	wire [15:0] q_mag = (s8 ? {8'd0, A[7:0]} : A);
	wire [15:0] q_signed = (q_neg ? -q_mag : q_mag);
	wire signed_range_err = (s8 ? (q_neg ? q_mag[7:0] > 8'h80 : q_mag[7]) : (q_neg ? q_mag > 16'h8000 : q_mag[15]));
	wire [7:0] r8 = (r_neg ? -R[7:0] : R[7:0]);
	assign busy = start || ((state != 2'd0) && !complete);
	always @(posedge clk)
		if (reset) begin
			state <= 2'd0;
			complete <= 1'b0;
			error <= 1'b0;
		end
		else begin
			complete <= 1'b0;
			case (state)
				2'd0: begin
					error <= 1'b0;
					if (start) begin
						if (div_by_zero || mag_overflow) begin
							error <= 1'b1;
							complete <= 1'b1;
						end
						else begin
							R <= hi;
							A <= lo;
							D <= dvs_w;
							n <= (is_8_bit ? 4'd7 : 4'd15);
							s8 <= is_8_bit;
							sgn <= is_signed;
							q_neg <= dvd_neg ^ dvs_neg;
							r_neg <= dvd_neg;
							state <= 2'd1;
						end
					end
				end
				2'd1: begin
					R <= (qbit ? diff[15:0] : R2[15:0]);
					A <= {A[14:0], qbit};
					n <= n - 1'd1;
					if (n == 4'd0)
						state <= 2'd2;
				end
				2'd2: begin
					quotient <= q_signed;
					remainder <= (s8 ? {{8 {r8[7]}}, r8} : (r_neg ? -R : R));
					error <= sgn & signed_range_err;
					complete <= 1'b1;
					state <= 2'd0;
				end
				default: state <= 2'd0;
			endcase
		end
endmodule
