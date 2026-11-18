// Copyright Jamie Iles, 2017
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

task automatic do_aas;
    output [15:0] out;
    input [15:0] a;
    input [15:0] flags_in;
    output [15:0] flags_out;

    // V30MZ: the high nibble of AL is always cleared
    reg [7:0] lo, hi;
    begin
        flags_out = flags_in;
        lo = a[7:0];
        hi = a[15:8];
        if (a[3:0] > 4'd9 || flags_in[AF_IDX]) begin
            lo = lo - 8'd6;
            hi = hi - 8'd1;
            flags_out[CF_IDX] = 1'b1;
            flags_out[AF_IDX] = 1'b1;
        end else begin
            flags_out[CF_IDX] = 1'b0;
            flags_out[AF_IDX] = 1'b0;
        end
        out = {hi, 4'b0, lo[3:0]};
    end
endtask
