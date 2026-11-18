`timescale 1ns / 1ps
`default_nettype wire

/*
 tb_fb.v - iverilog check of ws_fb.v (sim/run_fb.sh, a few seconds): a pattern frame (pixel x, y ->
 RGB { x[3:0], y[3:0], (x + y)[3:0] }) written as SwanTop does it (one pixel every 12 clk_sys, pixel
 32255 last), an asynchronous SRAM model (10 ns), then the 1024 x 768 output of the next whole frame
 compared pixel by pixel: the 4 x 4 blocks of the picture at (64, 96), black around, de 1024 x 768.
*/

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
	.MA(MA), .MD(MD), .MWR_N(MWR_N), .MRD_N(MRD_N),
	.clk_65(clk_65), .rgb(rgb), .hs(hs), .vs(vs), .de(de)
);

// the SRAM: 2M x 16, asynchronous
reg [15:0] sram [0:(1 << 21) - 1];
assign #10 MD = (MRD_N == 2'b00 && MWR_N == 2'b11) ? sram[MA] : 16'bzzzzzzzzzzzzzzzz;
always @(posedge MWR_N[0]) sram[MA] <= MD;

function [11:0] pat;
	input integer x, y;
	pat = { x[3:0], y[3:0], x[3:0] + y[3:0] };
endfunction

// the writer: one frame
integer x, y, k;
task write_frame;
	begin
		for (y = 0; y < 144; y = y + 1)
			for (x = 0; x < 224; x = x + 1) begin
				@(posedge clk);
				pixel_we <= 1;
				pixel_addr <= y * 224 + x;
				pixel_data <= pat(x, y);
				@(posedge clk);
				pixel_we <= 0;
				for (k = 0; k < 10; k = k + 1) @(posedge clk);
			end
	end
endtask

// the output: counted in clk_65 on de; checked in the frame after the one where the writer finished
integer ox = 0, oy = 0, errors = 0, checked = 0, frames = 0;
reg de_d = 0, vs_d = 0;
reg check = 0;
reg [23:0] want;
reg [11:0] p;
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
			if (ox >= 64 && ox < 64 + 896 && oy >= 96 && oy < 96 + 576) begin
				sx = (ox - 64) / 4; sy = (oy - 96) / 4;
				p = pat(sx, sy);
				want = { p[11:8], p[11:8], p[7:4], p[7:4], p[3:0], p[3:0] };
			end
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
	write_frame;
	// the reader takes the buffer at the next frame start: check the frame after that
	f0 = frames;
	wait (frames == f0 + 1);
	check = 1;
	wait (frames == f0 + 2);
	check = 0;
	if (checked != 1024 * 768) begin $display("checked %0d pixels, want %0d", checked, 1024 * 768); errors = errors + 1; end
	if (errors == 0) $display("PASS"); else $display("FAIL: %0d errors", errors);
	$finish;
end

endmodule
