`timescale 1ns / 1ps
`default_nettype wire

/*
 tb_fb.v - iverilog check of ws_fb.v (sim/run_checks.sh, a few seconds each): three pattern frames
 (frame f, pixel x, y -> RGB { x[3:0] + f, y[3:0] + 2f, (x + y)[3:0] + 3f }) written as SwanTop does
 it (one pixel every 12 clk_sys, pixel 32255 last), an asynchronous SRAM model (10 ns), then the
 1024 x 768 output of the next whole frame compared pixel by pixel with the mode (-DROT=0/1/2,
 -DBLEND=0/1/2): horizontal 4 x 4 blocks at (64, 96), turned 3 x 3 at (296, 48), the mean of the
 last 1..3 frames, black around; de 1024 x 768.
*/

`ifndef ROT
`define ROT 0
`endif
`ifndef BLEND
`define BLEND 0
`endif
`ifndef GAP
`define GAP 10      // clocks between pixels after the two of pixel_we (SwanTop: 12 a pixel)
`endif

module tb_fb;

reg clk = 0, clk_65 = 0;
always #13.563 clk = ~clk;      // 36.864 MHz
always #7.692 clk_65 = ~clk_65; // 65 MHz

reg pixel_we = 0;
reg [14:0] pixel_addr = 0;
reg [11:0] pixel_data = 0;

wire [20:0] MA;
wire [15:0] MD;
wire [1:0] MWR_N, MRD_N;
wire [23:0] rgb;
wire hs, vs, de;

ws_fb dut (
	.clk(clk), .pixel_we(pixel_we), .pixel_addr(pixel_addr), .pixel_data(pixel_data),
	.rot(2'd`ROT), .blend(2'd`BLEND),
	.MA(MA), .MD(MD), .MWR_N(MWR_N), .MRD_N(MRD_N),
	.clk_65(clk_65), .rgb(rgb), .hs(hs), .vs(vs), .de(de)
);

// the SRAM: 2M x 16, asynchronous
reg [15:0] sram [0:(1 << 21) - 1];
assign #10 MD = (MRD_N == 2'b00 && MWR_N == 2'b11) ? sram[MA] : 16'bzzzzzzzzzzzzzzzz;
always @(posedge MWR_N[0]) sram[MA] <= MD;

function [11:0] pat;
	input integer x, y, f;
	reg [3:0] r, g, b;
	begin
		r = x[3:0] + f[3:0]; g = y[3:0] + 2 * f[3:0]; b = x[3:0] + y[3:0] + 3 * f[3:0];
		pat = { r, g, b };
	end
endfunction

// a channel of the mean of the last n frames (as ws_fb: 17 v, 17 s / 2, 91 s / 16)
function [7:0] mixc;
	input integer s, n;
	integer m;
	begin
		if (n == 1) m = s * 17; else if (n == 2) m = (s * 17) / 2; else m = (s * 91) / 16;
		mixc = m[7:0];
	end
endfunction

function [23:0] want_px;
	input integer sx, sy;
	integer f, n, sr, sg, sb;
	reg [11:0] q;
	begin
		n = `BLEND + 1; sr = 0; sg = 0; sb = 0;
		for (f = 3 - n; f < 3; f = f + 1) begin
			q = pat(sx, sy, f);
			sr = sr + q[11:8]; sg = sg + q[7:4]; sb = sb + q[3:0];
		end
		want_px = { mixc(sr, n), mixc(sg, n), mixc(sb, n) };
	end
endfunction

// the writer: one frame
integer x, y, k;
task write_frame(input integer f);
	begin
		for (y = 0; y < 144; y = y + 1)
			for (x = 0; x < 224; x = x + 1) begin
				@(posedge clk);
				pixel_we <= 1;
				pixel_addr <= y * 224 + x;
				pixel_data <= pat(x, y, f);
				@(posedge clk);
				pixel_we <= 0;
				for (k = 0; k < `GAP; k = k + 1) @(posedge clk);
			end
	end
endtask

// the output: counted in clk_65 on de; checked in the frame after the one where the writer finished
integer ox = 0, oy = 0, errors = 0, checked = 0, frames = 0;
reg de_d = 0, vs_d = 0;
reg check = 0;
reg [23:0] want;
integer sx, sy;
always @(posedge clk_65) begin
	de_d <= de;
	vs_d <= vs;
	if (vs && !vs_d) begin
		frames = frames + 1;
		oy = 0;
	end
	if (de) begin
		if (check) begin
			if (`ROT == 0 && ox >= 64 && ox < 64 + 896 && oy >= 96 && oy < 96 + 576)
				want = want_px((ox - 64) / 4, (oy - 96) / 4);
			else if (`ROT == 1 && ox >= 296 && ox < 296 + 432 && oy >= 48 && oy < 48 + 672)
				want = want_px((oy - 48) / 3, 143 - (ox - 296) / 3);
			else if (`ROT == 2 && ox >= 296 && ox < 296 + 432 && oy >= 48 && oy < 48 + 672)
				want = want_px(223 - (oy - 48) / 3, (ox - 296) / 3);
			else
				want = 24'd0;
			if (rgb !== want) begin
				if (errors < 10) $display("pixel %0d,%0d: %06x, want %06x", ox, oy, rgb, want);
				errors = errors + 1;
			end
			checked = checked + 1;
		end
		ox = ox + 1;
	end
	if (!de && de_d) begin
		if (ox != 1024) begin $display("line %0d: %0d pixels of de", oy, ox); errors = errors + 1; end
		ox = 0;
		oy = oy + 1;
	end
end

integer f0;
initial begin
	write_frame(0);
	write_frame(1);
	write_frame(2);
	// the reader takes the buffer at the next frame start: check the frame after that
	f0 = frames;
	wait (frames == f0 + 1);
	check = 1;
	wait (frames == f0 + 2);
	check = 0;
	if (checked != 1024 * 768) begin $display("checked %0d pixels, want %0d", checked, 1024 * 768); errors = errors + 1; end
	if (errors == 0) $display("PASS rot %0d blend %0d", `ROT, `BLEND); else $display("FAIL rot %0d blend %0d: %0d errors", `ROT, `BLEND, errors);
	$finish;
end

endmodule
