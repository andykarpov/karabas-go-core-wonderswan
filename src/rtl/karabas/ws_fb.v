`timescale 1ns / 1ps
`default_nettype wire

/*
 ws_fb.v

 The 224 x 144 picture of SwanTop through a frame buffer in the SRAM of the board, out as 1024 x 768
 at 60 Hz (VESA, 65 MHz). The output does not follow the 75.47 Hz of the WonderSwan: the writer goes
 round a ring of 8 frame buffers, the reader shows the last complete frame (some frames are skipped),
 so no frame is torn (the "buffer video" of the MiSTer core). Based on sega_fb.v of
 karabas-go-core-sega.

 Modes (rot, blend: taken at the start of an output frame):
 - rot 0: horizontal, every source pixel 4 x 4 (896 x 576) at (64, 96);
 - rot 1 (MiSTer "Vert") / 2 ("Vert180"): the picture turned to 144 x 224, every pixel 3 x 3
   (432 x 672) at (296, 48); an output line is a source column: rot 1 shows source (x = line,
   y = 143 - column), rot 2 (x = 223 - line, y = column), as px_addr of the MiSTer top;
 - blend 0: the last frame; 1: the mean of the last two (flickerblend 2 frames); 2: of the last three.

 Write side (clk = clk_sys): pixel_we / pixel_addr (y * 224 + x) / pixel_data (RGB 4:4:4, R in [11:8])
 of SwanTop, one SRAM word each at { buffer (3 bits), pixel_addr (15) }; the pixel 32255 ends a frame
 (as the MiSTer top): that buffer becomes the last complete one, the writer takes the next of the
 ring. The reader uses the last one and the two before it: in one output frame (1/60 s) the writer
 completes at most two frames, so it never reaches them. A pixel comes every 12 clocks.

 SRAM (2M x 16, 10 ns, asynchronous) on clk (36.864 MHz, 27 ns): a read holds the address two clocks
 and takes MD at the second edge (reads go back to back, two clocks each); a write is four clocks
 (/OE off with the address, MD driven and /WE low, /WE high, MD released). A source line (224 pixels,
 or 144 of a column) takes 1..3 reads a pixel: at most 1344 clocks of the 3000 of 4 output lines.

 Read side (clk_65): the VESA timing 1344 x 806 (1024 + 24 + 136 + 160, 768 + 3 + 6 + 29); at the
 start of every frame the reader takes the last complete buffer and the mode. A source line is read
 from the SRAM into a line buffer (block RAM, two lines of 24-bit pixels, the frames already mixed)
 while the line before is shown: line 0 three output lines before the picture, line 1 at its start,
 line n + 2 after the last output line of n. The requests cross to clk with a toggle (the line,
 buffer and mode held stable meanwhile); the frame number crosses as two agreeing samples.

 hs / vs / de are positive (the top inverts the syncs), rgb is 8:8:8. The picture area is black until
 the first complete frame.
*/

module ws_fb (
	input  wire        clk,
	input  wire        pixel_we,
	input  wire [14:0] pixel_addr,
	input  wire [11:0] pixel_data,
	input  wire [1:0]  rot,             // 0 horizontal, 1 Vert, 2 Vert180
	input  wire [1:0]  blend,           // frames mixed - 1

	output reg  [20:0] MA = 21'd0,
	inout  wire [15:0] MD,
	output reg  [1:0]  MWR_N = 2'b11,
	output reg  [1:0]  MRD_N = 2'b11,

	input  wire        clk_65,
	output reg  [23:0] rgb = 24'd0,
	output reg         hs = 1'b0,
	output reg         vs = 1'b0,
	output reg         de = 1'b0
);

// ================================================================== write side (clk)

reg [2:0] wbuf = 3'd0;
reg [2:0] last = 3'd0;
reg       have = 1'b0;                 // a complete frame exists

// line requests from clk_65 (the toggle and the line / buffer / mode it asks for)
wire       req_t_65;
wire [7:0] req_line_65;
wire       req_lbuf_65;
wire [2:0] req_fbuf_65;
wire [1:0] req_rot_65, req_n_65;

// pending pixel
reg        pw = 1'b0;
reg [17:0] pw_addr = 18'd0;
reg [11:0] pw_data = 12'd0;

localparam S_IDLE = 3'd0, S_W1 = 3'd1, S_W2 = 3'd2, S_W3 = 3'd3, S_R1 = 3'd4;
reg [2:0]  st = S_IDLE;
reg        md_oe = 1'b0;
reg [15:0] md_out = 16'd0;
assign MD = md_oe ? md_out : 16'bzzzzzzzzzzzzzzzz;
wire sram_wr_take = st == S_IDLE && pw;

always @(posedge clk) begin
	if (sram_wr_take) pw <= 1'b0;
	if (pixel_we) begin
		pw <= 1'b1;
		pw_addr <= { wbuf, pixel_addr };
		pw_data <= pixel_data;
		if (pixel_addr == 15'd32255) begin
			last <= wbuf;
			have <= 1'b1;
			wbuf <= wbuf + 3'd1;
		end
	end
end

// ------------------------------------------------------------------ line requests, SRAM

reg [2:0]  req_s = 3'd0;
reg        job = 1'b0;
reg [14:0] job_a = 15'd0;          // the source address of the pixel
reg [14:0] job_step = 15'd0;       // +1, -224, +224 (mod 2^15)
reg [7:0]  job_x = 8'd0;
reg [7:0]  job_last = 8'd0;        // 223 or 143
reg [1:0]  job_k = 2'd0;           // the frame of the pixel being read: last - k
reg [1:0]  job_n = 2'd0;           // frames - 1
reg        job_lbuf = 1'b0;
reg [2:0]  job_fbuf = 3'd0;

// the tags of a read, two stages (the data comes two edges after the address)
reg        t_v = 1'b0, t_v_d = 1'b0;
reg [1:0]  t_k = 2'd0, t_k_d = 2'd0;
reg        t_end = 1'b0, t_end_d = 1'b0;   // the last frame of the pixel
reg [8:0]  t_wa = 9'd0, t_wa_d = 9'd0;
reg [1:0]  t_n = 2'd0, t_n_d = 2'd0;

reg [5:0]  acc_r = 6'd0, acc_g = 6'd0, acc_b = 6'd0;
reg        lb_we = 1'b0;
reg [8:0]  lb_wa = 9'd0;
reg [23:0] lb_wd = 24'd0;

wire [11:0] md12 = MD[11:0];
wire [5:0] s_r = (t_k_d == 2'd0 ? 6'd0 : acc_r) + { 2'd0, md12[11:8] };
wire [5:0] s_g = (t_k_d == 2'd0 ? 6'd0 : acc_g) + { 2'd0, md12[7:4] };
wire [5:0] s_b = (t_k_d == 2'd0 ? 6'd0 : acc_b) + { 2'd0, md12[3:0] };

// a channel to 8 bits: 1 frame v * 17, 2 frames s * 17 / 2, 3 frames s * 91 / 16 (as 255 / 45)
function [7:0] mix;
	input [5:0] v;
	input [1:0] n;
	reg [11:0] m;
	begin
		case (n)
			2'd0: m = { 6'd0, v } * 12'd17;
			2'd1: m = ({ 6'd0, v } * 12'd17) >> 1;
			default: m = ({ 6'd0, v } * 12'd91) >> 4;
		endcase
		mix = m[7:0];
	end
endfunction

always @(posedge clk) begin
	req_s <= { req_s[1:0], req_t_65 };
	if (req_s[2] != req_s[1]) begin
		job <= 1'b1;
		job_lbuf <= req_lbuf_65;
		job_fbuf <= req_fbuf_65;
		job_n <= req_n_65;
		job_x <= 8'd0;
		job_k <= 2'd0;
		case (req_rot_65)
			2'd1: begin   // column: x = line, y = 143 .. 0
				job_a <= 15'd32032 + { 7'd0, req_line_65 };
				job_step <= 15'h7F20;        // -224
				job_last <= 8'd143;
			end
			2'd2: begin   // column: x = 223 - line, y = 0 .. 143
				job_a <= 15'd223 - { 7'd0, req_line_65 };
				job_step <= 15'd224;
				job_last <= 8'd143;
			end
			default: begin
				job_a <= { req_line_65, 7'd0 } + { 1'b0, req_line_65, 6'd0 } + { 2'b0, req_line_65, 5'd0 }; // * 224
				job_step <= 15'd1;
				job_last <= 8'd223;
			end
		endcase
	end

	t_v <= 1'b0;
	case (st)
	S_IDLE:
		if (pw) begin
			MRD_N <= 2'b11;
			MA <= { 3'b000, pw_addr };
			md_out <= { 4'd0, pw_data };
			st <= S_W1;
		end
		else if (job) begin
			MRD_N <= 2'b00;
			MA <= { 3'b000, job_fbuf - { 1'b0, job_k }, job_a };
			t_v <= 1'b1;
			t_k <= job_k;
			t_end <= job_k == job_n;
			t_wa <= { job_lbuf, job_x };
			t_n <= job_n;
			if (job_k == job_n) begin
				job_k <= 2'd0;
				if (job_x == job_last) job <= 1'b0;
				job_x <= job_x + 8'd1;
				job_a <= job_a + job_step;
			end
			else
				job_k <= job_k + 2'd1;
			st <= S_R1;
		end
		else
			MRD_N <= 2'b11;
	S_W1: begin
		md_oe <= 1'b1;
		MWR_N <= 2'b00;
		st <= S_W2;
	end
	S_W2: begin
		MWR_N <= 2'b11;
		st <= S_W3;
	end
	S_W3: begin
		md_oe <= 1'b0;
		st <= S_IDLE;
	end
	S_R1: st <= S_IDLE;
	default: st <= S_IDLE;
	endcase

	// the read data: the address was set two edges ago (S_IDLE -> S_R1 -> here)
	t_v_d <= t_v;
	t_k_d <= t_k;
	t_end_d <= t_end;
	t_wa_d <= t_wa;
	t_n_d <= t_n;
	lb_we <= 1'b0;
	if (t_v_d) begin
		acc_r <= s_r;
		acc_g <= s_g;
		acc_b <= s_b;
		if (t_end_d) begin
			lb_we <= 1'b1;
			lb_wa <= t_wa_d;
			lb_wd <= { mix(s_r, t_n_d), mix(s_g, t_n_d), mix(s_b, t_n_d) };
		end
	end
end

// ================================================================== line buffer

wire [23:0] lb_q;
reg  [8:0]  lb_ra = 9'd0;
kg_sdpram #(.DW(24), .AW(9)) line_buf (
	.clka(clk),
	.wea(lb_we),
	.addra(lb_wa),
	.dina(lb_wd),
	.clkb(clk_65),
	.enb(1'b1),
	.addrb(lb_ra),
	.doutb(lb_q)
);

// ================================================================== read side (clk_65)

localparam H_TOTAL = 11'd1344, H_SYNC0 = 11'd1048, H_SYNC1 = 11'd1184;
localparam V_TOTAL = 10'd806,  V_SYNC0 = 10'd771,  V_SYNC1 = 10'd777;

reg [10:0] hc = 11'd0;
reg [9:0]  vc = 10'd0;

// the frame of the writer, two agreeing samples
wire [3:0] pub = { have, last };
reg  [3:0] pub_s1 = 4'd0, pub_s2 = 4'd0, pub_cur = 4'd0;
reg  [2:0] rbuf = 3'd0;
reg        rhave = 1'b0;

// the mode of the frame (rot / blend from clk, sampled twice; quasi-static)
reg  [3:0] mode_s1 = 4'd0, mode_s2 = 4'd0;
reg  [1:0] f_rot = 2'd0, f_n = 2'd0;
wire       vert = f_rot != 2'd0;
wire [10:0] X0 = vert ? 11'd296 : 11'd64;
wire [10:0] XE = vert ? 11'd728 : 11'd960;     // X0 + 432 / 896
wire [9:0]  Y0 = vert ? 10'd48 : 10'd96;
wire [1:0]  SC = vert ? 2'd2 : 2'd3;            // scale - 1
wire [7:0]  NL = vert ? 8'd224 : 8'd144;        // source lines

reg        req_t = 1'b0;
reg [7:0]  req_line = 8'd0;
reg        req_lbuf = 1'b0;
assign req_t_65 = req_t;
assign req_line_65 = req_line;
assign req_lbuf_65 = req_lbuf;
assign req_fbuf_65 = rbuf;
assign req_rot_65 = f_rot;
assign req_n_65 = f_n;

reg        in_img = 1'b0;
reg [7:0]  sy = 8'd0;
reg [1:0]  sub = 2'd0;
reg [7:0]  pidx = 8'd0;         // the source pixel of the line
reg [1:0]  pxs = 2'd0;

reg p1_de = 1'b0, p1_hs = 1'b0, p1_vs = 1'b0, p1_pic = 1'b0;
reg p2_de = 1'b0, p2_hs = 1'b0, p2_vs = 1'b0, p2_pic = 1'b0;
reg p1_have = 1'b0, p2_have = 1'b0;

always @(posedge clk_65) begin
	pub_s1 <= pub;
	pub_s2 <= pub_s1;
	if (pub_s1 == pub_s2) pub_cur <= pub_s2;
	mode_s1 <= { rot, blend };
	mode_s2 <= mode_s1;

	if (hc == H_TOTAL - 11'd1) begin
		hc <= 11'd0;
		vc <= vc == V_TOTAL - 10'd1 ? 10'd0 : vc + 10'd1;
	end
	else
		hc <= hc + 11'd1;

	// the start of a frame: the last complete buffer, the mode
	if (hc == 11'd0 && vc == V_SYNC1) begin
		rhave <= pub_cur[3];
		rbuf <= pub_cur[2:0];
		f_rot <= mode_s2[3:2] == 2'd3 ? 2'd0 : mode_s2[3:2];
		f_n <= mode_s2[1:0] == 2'd3 ? 2'd2 : mode_s2[1:0];
	end

	// lines: at the end of the line before (hc = H_SYNC0, the picture of the line is out)
	if (hc == H_SYNC0) begin
		if (vc == Y0 - 10'd3) begin
			req_line <= 8'd0;
			req_lbuf <= 1'b0;
			req_t <= ~req_t;
		end
		if (vc == Y0 - 10'd1) begin
			in_img <= 1'b1;
			sy <= 8'd0;
			sub <= 2'd0;
			req_line <= 8'd1;
			req_lbuf <= 1'b1;
			req_t <= ~req_t;
		end
		else if (in_img) begin
			if (sub == SC) begin
				sub <= 2'd0;
				if (sy + 8'd1 == NL)
					in_img <= 1'b0;
				else begin
					sy <= sy + 8'd1;
					if (sy + 8'd2 < NL) begin
						req_line <= sy + 8'd2;
						req_lbuf <= sy[0];       // = (sy + 2) & 1
						req_t <= ~req_t;
					end
				end
			end
			else
				sub <= sub + 2'd1;
		end
	end

	// stage 1: the address of the source pixel
	if (hc == X0 - 11'd1) begin
		pidx <= 8'd0;
		pxs <= 2'd0;
	end
	else if (hc >= X0 && hc < XE) begin
		if (pxs == SC) begin
			pxs <= 2'd0;
			pidx <= pidx + 8'd1;
		end
		else
			pxs <= pxs + 2'd1;
	end
	lb_ra <= { sy[0], pidx };
	p1_de <= hc < 11'd1024 && vc < 10'd768;
	p1_hs <= hc >= H_SYNC0 && hc < H_SYNC1;
	p1_vs <= vc >= V_SYNC0 && vc < V_SYNC1;
	p1_pic <= in_img && hc >= X0 && hc < XE;
	p1_have <= rhave;

	// stage 2: the pixel (lb_q is the data of lb_ra of the clock before)
	p2_de <= p1_de;
	p2_hs <= p1_hs;
	p2_vs <= p1_vs;
	p2_pic <= p1_pic;
	p2_have <= p1_have;

	de <= p2_de;
	hs <= p2_hs;
	vs <= p2_vs;
	// the picture; black there until the machine has finished a frame
	rgb <= !p2_pic || !p2_have ? 24'd0 : lb_q;
end

endmodule
