// Copyright Jamie Iles, 2017 (original non-restoring divider)
// Tang Nano 20K port: rewritten as a compact restoring divider (17-bit remainder instead of
// a 64-bit partial remainder), same interface and divide-error semantics.
//
// This file is part of s80x86.
//
// s80x86 is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// s80x86 is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with s80x86.  If not, see <http://www.gnu.org/licenses/>.

`default_nettype none
module s80_Divider( // karabas: renamed, the MiSTer VHDL divider has the same name (XST is case-insensitive)
input logic clk,
               input logic reset,
               input logic start,
               input logic is_8_bit,
               input logic is_signed,
               output logic busy,
               output logic complete,
               output logic error,
               input logic [31:0] dividend,
               input logic [15:0] divisor,
               output logic [15:0] quotient,
               output logic [15:0] remainder);

// ---------------------------------------------------------------- operand magnitudes
wire        dvd_neg = is_signed & (is_8_bit ? dividend[15] : dividend[31]);
wire        dvs_neg = is_signed & (is_8_bit ? divisor[7] : divisor[15]);
wire [31:0] dvd_ext = is_8_bit ? {{16{dividend[15]}}, dividend[15:0]} : dividend;
wire [15:0] dvs_ext = is_8_bit ? {{8{divisor[7]}}, divisor[7:0]} : divisor;
wire [31:0] dvd_mag = dvd_neg ? -dvd_ext : dvd_ext;
wire [15:0] dvs_mag = dvs_neg ? -dvs_ext : dvs_ext;
wire [15:0] dvs_w   = is_8_bit ? {8'd0, dvs_mag[7:0]} : dvs_mag;

// high / low halves of the magnitude dividend (low half left aligned)
wire [15:0] hi = is_8_bit ? {8'd0, dvd_mag[15:8]} : dvd_mag[31:16];
wire [15:0] lo = is_8_bit ? {dvd_mag[7:0], 8'd0}  : dvd_mag[15:0];

// the quotient of the magnitudes must fit in 8 / 16 bits
wire div_by_zero  = dvs_w == 16'd0;
wire mag_overflow = hi >= dvs_w;

// ---------------------------------------------------------------- iteration
typedef enum bit [1:0] { D_IDLE, D_WORK, D_FIX, D_CHK } DivState_t;
DivState_t state;

reg  [15:0] R;           // partial remainder
reg  [15:0] A;           // remaining dividend bits; quotient bits enter at the bottom
reg  [15:0] D;
reg   [3:0] n;
reg         s8, q_neg, r_neg, sgn;

wire [16:0] R2   = {R, A[15]};
wire [16:0] diff = R2 - {1'b0, D};
wire        qbit = !diff[16];

wire [15:0] q_mag    = s8 ? {8'd0, A[7:0]} : A;
wire [15:0] q_signed = q_neg ? -q_mag : q_mag;
// signed range: -2^(n-1) .. 2^(n-1)-1
wire signed_range_err = s8 ? (q_neg ? (q_mag[7:0] > 8'h80) : q_mag[7])
                           : (q_neg ? (q_mag > 16'h8000) : q_mag[15]);
wire [7:0]  r8 = r_neg ? -R[7:0] : R[7:0];

assign busy = start || (state != D_IDLE && !complete);

always_ff @(posedge clk) begin
    if (reset) begin
        state    <= D_IDLE;
        complete <= 1'b0;
        error    <= 1'b0;
    end else begin
        complete <= 1'b0;
        case (state)
        D_IDLE: begin
            error <= 1'b0;
            if (start) begin
                // karabas: operands are latched first, the zero / overflow
                // check runs on the registers in D_CHK (one more clock):
                // microcode -> divisor -> check -> n CE did not meet 27 ns
                R     <= hi;
                A     <= lo;
                D     <= dvs_w;
                n     <= is_8_bit ? 4'd7 : 4'd15;
                s8    <= is_8_bit;
                sgn   <= is_signed;
                q_neg <= dvd_neg ^ dvs_neg;
                r_neg <= dvd_neg;
                state <= D_CHK;
            end
        end
        D_CHK: begin
            if (D == 16'd0 || R >= D) begin
                error    <= 1'b1;
                complete <= 1'b1;
                state    <= D_IDLE;
            end else
                state    <= D_WORK;
        end
        D_WORK: begin
            R <= qbit ? diff[15:0] : R2[15:0];
            A <= {A[14:0], qbit};
            n <= n - 1'd1;
            if (n == 4'd0) state <= D_FIX;
        end
        D_FIX: begin
            quotient  <= q_signed;
            remainder <= s8 ? {{8{r8[7]}}, r8} : (r_neg ? -R : R);
            error     <= sgn & signed_range_err;
            complete  <= 1'b1;
            state     <= D_IDLE;
        end
        default: state <= D_IDLE;
        endcase
    end
end

endmodule
