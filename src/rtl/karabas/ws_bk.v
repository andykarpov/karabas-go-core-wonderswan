`timescale 1ns / 1ps
`default_nettype none

/*
 ws_bk.v

 The memory port of kg_bk_ram (bytes, clk_sys) on the save memory of the cartridge (words, clk_ram):
 - sram 1: the SRAM in the SDRAM (SwanTop EXTRAM bytes 0x1000000 + offset = SDRAM word
   0x800000 + offset / 2), on channel ch2 of ws_sdram (a request edge, ready one clk_ram);
 - sram 0: the EEPROM of the cartridge, port b of its block RAM in eeprom.vhd (eeprom_addr in
   words, eeprom_req with eeprom_rnw 0 writes in that clk_ram, eeprom_dout a clock later).
 Both take whole words: kg_bk_ram loads a sector byte by byte from offset 0 up, so an even byte is
 kept here (acked at once) and written with the odd byte after it; a read takes the word and gives
 its byte. clk_ram = 3 x clk_sys from one PLL, the edges aligned: the requests cross as toggles
 without synchronisers (the ucf FROM-TO clk_sys <-> clk_ram, 9 ns).
*/

module ws_bk (
	input  wire        clk,          // clk_sys
	input  wire        clk_ram,
	input  wire        sram,

	input  wire        mem_req,
	input  wire        mem_we,
	input  wire [18:0] mem_addr,
	input  wire [7:0]  mem_din,
	output reg         mem_ack = 1'b0,
	output reg  [7:0]  mem_dout = 8'd0,

	output reg  [25:1] sdr_addr = 25'd0,
	output reg  [15:0] sdr_din = 16'd0,
	output reg         sdr_req = 1'b0,
	output reg         sdr_rnw = 1'b1,
	input  wire [15:0] sdr_dout,
	input  wire        sdr_ready,

	output reg  [9:0]  ee_addr = 10'd0,
	output reg  [15:0] ee_din = 16'd0,
	output reg         ee_req = 1'b0,
	output reg         ee_rnw = 1'b1,
	input  wire [15:0] ee_dout
);

// ---------------- clk_sys ----------------

reg pend = 1'b0, req_t = 1'b0, done_seen = 1'b0;
reg [7:0] lo = 8'd0;
reg [18:0] a_r = 19'd0;
reg we_r = 1'b0;
reg [15:0] wd = 16'd0;
reg done_t = 1'b0;
reg [15:0] rd = 16'd0;

always @(posedge clk) begin
	mem_ack <= 1'b0;
	if (!pend && mem_req && !mem_ack) begin
		if (mem_we && !mem_addr[0]) begin
			lo <= mem_din;
			mem_ack <= 1'b1;
		end
		else begin
			a_r <= mem_addr;
			we_r <= mem_we;
			wd <= { mem_din, lo };
			pend <= 1'b1;
			req_t <= ~req_t;
		end
	end
	if (pend && done_t != done_seen) begin
		done_seen <= done_t;
		pend <= 1'b0;
		mem_ack <= 1'b1;
		mem_dout <= a_r[0] ? rd[15:8] : rd[7:0];
	end
end

// ---------------- clk_ram ----------------

localparam S_IDLE = 3'd0, S_SDR = 3'd1, S_EE = 3'd2, S_EE1 = 3'd3, S_EE2 = 3'd4, S_DONE = 3'd5;
reg [2:0] st = S_IDLE;
reg req_seen = 1'b0;

always @(posedge clk_ram) begin
	case (st)
		S_IDLE:
			if (req_t != req_seen) begin
				req_seen <= req_t;
				if (sram) begin
					sdr_addr <= { 1'b0, 1'b1, 5'd0, a_r[18:1] };
					sdr_din <= wd;
					sdr_rnw <= ~we_r;
					sdr_req <= 1'b1;
					st <= S_SDR;
				end
				else begin
					ee_addr <= a_r[10:1];
					ee_din <= wd;
					ee_rnw <= ~we_r;
					ee_req <= 1'b1;
					st <= S_EE;
				end
			end
		S_SDR:
			if (sdr_ready) begin
				sdr_req <= 1'b0;
				rd <= sdr_dout;
				st <= S_DONE;
			end
		S_EE: begin          // the block RAM takes the address (and the write) at this edge
			ee_req <= 1'b0;
			ee_rnw <= 1'b1;
			st <= S_EE1;
		end
		S_EE1: st <= S_EE2;
		S_EE2: begin
			rd <= ee_dout;
			st <= S_DONE;
		end
		default: begin       // S_DONE
			done_t <= ~done_t;
			st <= S_IDLE;
		end
	endcase
end

endmodule
