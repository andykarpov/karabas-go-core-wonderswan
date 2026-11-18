`timescale 1ns / 1ps
`default_nettype wire

/*
 ws_fb.v

 The 224 x 144 picture of SwanTop through a frame buffer in the SRAM of the board, out as 1024 x 768
 at 60 Hz (VESA, 65 MHz): every source pixel 4 x 4 (896 x 576), in the middle (64 pixels left and
 right, 96 lines above and below). The output does not follow the 75.47 Hz of the WonderSwan: three
 buffers, the reader shows the last complete frame (some frames are skipped), so no frame is torn
 (the "buffer video" of the MiSTer core). Based on sega_fb.v of karabas-go-core-sega.

 Write side (clk = clk_sys): pixel_we / pixel_addr (y * 224 + x) / pixel_data (RGB 4:4:4, R in [11:8])
 of SwanTop, one SRAM word each at { buffer (2 bits), pixel_addr (15) }; the pixel 32255 ends a frame
 (as the MiSTer top): that buffer becomes the last complete one, the next is the one that is neither
 that nor the one the reader shows. A pixel comes every 12 clocks (the GPU clock enable).

 SRAM (2M x 16, 10 ns, asynchronous) on clk (36.864 MHz, 27 ns): a read holds the address two clocks
 and takes MD at the second edge; a write is four clocks (/OE off with the address, MD driven and /WE
 low, /WE high, MD released). 224 reads of a line take well under the 82 us of a source line.

 Read side (clk_65): the VESA timing 1344 x 806 (1024 + 24 + 136 + 160, 768 + 3 + 6 + 29); at the
 start of every frame the reader takes the last complete buffer. A source line is read from the SRAM
 into a line buffer (block RAM, two lines, the two clocks) while the line before is shown: line 0
 three output lines before the picture, line 1 at its start, line n + 2 after the last output line
 of n. The requests cross to clk with a toggle (the line and buffers held stable meanwhile); the
 buffer numbers cross both ways as two agreeing samples (they change once a frame).

 hs / vs / de are positive (the top inverts the syncs), rgb is 8:8:8 (4 bits doubled). The picture area is
 dark blue (000040) until the first complete frame.
*/

module ws_fb (
	input  wire        clk,
	input  wire        pixel_we,
	input  wire [14:0] pixel_addr,
	input  wire [11:0] pixel_data,

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

reg [1:0] wbuf = 2'd0;
reg [1:0] last = 2'd0;
reg       have = 1'b0;                 // a complete frame exists

// the reader's buffer, from clk_65 (two agreeing samples)
reg [1:0] rd_s1 = 2'd0, rd_s2 = 2'd0, rd_cur = 2'd0;
wire [1:0] rbuf_65;

// line requests from clk_65 (the toggle and the line / buffers it asks for)
wire       req_t_65;
wire [7:0] req_line_65;
wire       req_lbuf_65;
wire [1:0] req_fbuf_65;

// pending pixel
reg        pw = 1'b0;
reg [16:0] pw_addr = 17'd0;
reg [11:0] pw_data = 12'd0;

localparam S_IDLE = 3'd0, S_W1 = 3'd1, S_W2 = 3'd2, S_W3 = 3'd3, S_R1 = 3'd4;
reg [2:0]  st = S_IDLE;
reg        md_oe = 1'b0;
reg [15:0] md_out = 16'd0;
assign MD = md_oe ? md_out : 16'bzzzzzzzzzzzzzzzz;
wire sram_wr_take = st == S_IDLE && pw;

always @(posedge clk) begin
	rd_s1 <= rbuf_65;
	rd_s2 <= rd_s1;
	if (rd_s1 == rd_s2) rd_cur <= rd_s2;

	if (sram_wr_take) pw <= 1'b0;
	if (pixel_we) begin
		pw <= 1'b1;
		pw_addr <= { wbuf, pixel_addr };
		pw_data <= pixel_data;
		if (pixel_addr == 15'd32255) begin
			last <= wbuf;
			have <= 1'b1;
			// the next buffer: not the one just completed, not the one the reader shows
			if (wbuf != rd_cur)
				wbuf <= 2'd3 - wbuf - rd_cur;
			else
				wbuf <= wbuf == 2'd2 ? 2'd0 : wbuf + 2'd1;
		end
	end
end

// ------------------------------------------------------------------ line requests, SRAM

reg [2:0]  req_s = 3'd0;
reg        job = 1'b0;
reg [14:0] job_a = 15'd0;          // line * 224 + x
reg [7:0]  job_x = 8'd0;
reg        job_lbuf = 1'b0;
reg [1:0]  job_fbuf = 2'd0;

reg        lb_we = 1'b0;
reg [8:0]  lb_wa = 9'd0;
reg [11:0] lb_wd = 12'd0;
reg [7:0]  rd_x = 8'd0;
reg        rd_lbuf = 1'b0;
reg        lb_rd_pend = 1'b0;
reg [7:0]  rd_x_d = 8'd0;
reg        rd_lbuf_d = 1'b0;

always @(posedge clk) begin
	req_s <= { req_s[1:0], req_t_65 };
	if (req_s[2] != req_s[1]) begin
		job <= 1'b1;
		job_a <= { req_line_65, 7'd0 } + { 1'b0, req_line_65, 6'd0 } + { 2'b0, req_line_65, 5'd0 }; // * 224
		job_lbuf <= req_lbuf_65;
		job_fbuf <= req_fbuf_65;
		job_x <= 8'd0;
	end

	lb_we <= 1'b0;
	case (st)
	S_IDLE:
		if (pw) begin
			MRD_N <= 2'b11;
			MA <= { 4'b0000, pw_addr };
			md_out <= { 4'd0, pw_data };
			st <= S_W1;
		end
		else if (job) begin
			MRD_N <= 2'b00;
			MA <= { 4'b0000, job_fbuf, job_a };
			rd_x <= job_x;
			rd_lbuf <= job_lbuf;
			if (job_x == 8'd223) job <= 1'b0;
			job_x <= job_x + 8'd1;
			job_a <= job_a + 15'd1;
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
	lb_rd_pend <= st == S_R1;
	if (lb_rd_pend) begin
		lb_we <= 1'b1;
		lb_wa <= { rd_lbuf_d, rd_x_d };
		lb_wd <= MD[11:0];
	end
	rd_x_d <= rd_x;
	rd_lbuf_d <= rd_lbuf;
end

// ================================================================== line buffer

wire [11:0] lb_q;
reg  [8:0]  lb_ra = 9'd0;
kg_sdpram #(.DW(12), .AW(9)) line_buf (
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
localparam X0 = 11'd64, XW = 11'd896;      // 224 x 4
localparam Y0 = 10'd96;                    // (768 - 576) / 2
localparam VC_REQ0 = Y0 - 10'd3, VC_START = Y0 - 10'd1;
localparam [7:0] H = 8'd144;

reg [10:0] hc = 11'd0;
reg [9:0]  vc = 10'd0;

// the frame of the writer, two agreeing samples
wire [2:0] pub = { have, last };
reg  [2:0] pub_s1 = 3'd0, pub_s2 = 3'd0, pub_cur = 3'd0;
reg  [1:0] rbuf = 2'd0;
reg        rhave = 1'b0;
assign rbuf_65 = rbuf;

reg        req_t = 1'b0;
reg [7:0]  req_line = 8'd0;
reg        req_lbuf = 1'b0;
assign req_t_65 = req_t;
assign req_line_65 = req_line;
assign req_lbuf_65 = req_lbuf;
assign req_fbuf_65 = rbuf;

reg        in_img = 1'b0;
reg [7:0]  sy = 8'd0;
reg [1:0]  sub = 2'd0;
reg [9:0]  px = 10'd0;          // the output pixel in the picture: source x = px >> 2

reg p1_de = 1'b0, p1_hs = 1'b0, p1_vs = 1'b0, p1_pic = 1'b0;
reg p2_de = 1'b0, p2_hs = 1'b0, p2_vs = 1'b0, p2_pic = 1'b0;
reg p1_have = 1'b0, p2_have = 1'b0;

always @(posedge clk_65) begin
	pub_s1 <= pub;
	pub_s2 <= pub_s1;
	if (pub_s1 == pub_s2) pub_cur <= pub_s2;

	if (hc == H_TOTAL - 11'd1) begin
		hc <= 11'd0;
		vc <= vc == V_TOTAL - 10'd1 ? 10'd0 : vc + 10'd1;
	end
	else
		hc <= hc + 11'd1;

	// the start of a frame: the last complete buffer
	if (hc == 11'd0 && vc == V_SYNC1) begin
		rhave <= pub_cur[2];
		rbuf <= pub_cur[1:0];
	end

	// lines: at the end of the line before (hc = H_SYNC0, the picture of the line is out)
	if (hc == H_SYNC0) begin
		if (vc == VC_REQ0) begin
			req_line <= 8'd0;
			req_lbuf <= 1'b0;
			req_t <= ~req_t;
		end
		if (vc == VC_START) begin
			in_img <= 1'b1;
			sy <= 8'd0;
			sub <= 2'd0;
			req_line <= 8'd1;
			req_lbuf <= 1'b1;
			req_t <= ~req_t;
		end
		else if (in_img) begin
			if (sub == 2'd3) begin
				sub <= 2'd0;
				if (sy + 8'd1 == H)
					in_img <= 1'b0;
				else begin
					sy <= sy + 8'd1;
					if (sy + 8'd2 < H) begin
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
	if (hc == X0 - 11'd1)
		px <= 10'd0;
	else if (hc >= X0 && hc < X0 + XW)
		px <= px + 10'd1;
	lb_ra <= { sy[0], px[9:2] };
	p1_de <= hc < 11'd1024 && vc < 10'd768;
	p1_hs <= hc >= H_SYNC0 && hc < H_SYNC1;
	p1_vs <= vc >= V_SYNC0 && vc < V_SYNC1;
	p1_pic <= in_img && hc >= X0 && hc < X0 + XW;
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
	// the picture; dark blue there until the machine has finished a frame (diagnostic of the bring-up)
	rgb <= !p2_pic ? 24'd0 : !p2_have ? 24'h000040 :
		{ lb_q[11:8], lb_q[11:8], lb_q[7:4], lb_q[7:4], lb_q[3:0], lb_q[3:0] };
end

endmodule
