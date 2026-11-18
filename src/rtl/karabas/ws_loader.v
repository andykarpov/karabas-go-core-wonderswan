`timescale 1ns / 1ps
`default_nettype wire
/*
 ws_loader.v

 The cartridge: the bytes of the file loader of kg_mcu2 (LD kind 1, a .ws / .wsc file) into the
 SDRAM from address 0 as 16-bit words (little endian: the even byte low), as the ioctl download
 of the MiSTer top: one write per odd byte on ch1 of ws_sdram (req = one clk pulse, the address and
 data held until the next word; a byte comes every 250 ns at most, a write takes about 60 ns).

 The header (the last 10 bytes of the file, as lastdata[] of WonderSwan.sv) when the file ends:
   -9 bit 0  colour cartridge (isColor in Auto)       -6  ROM size (romtype)
   -5        save type (ramtype)                      -3 bit 0  RTC present (hasRTC)
 maskAddr = the last byte address (MiSTer: ioctl_addr - 1 at the end of the download).
 cart_ready from the end of the first file on; loading while a file comes (the core is held in
 reset by the top).
*/
module ws_loader (
	input  wire        clk,

	input  wire        file_active,
	input  wire        file_wr,
	input  wire [31:0] file_addr,
	input  wire [7:0]  file_data,

	output reg  [25:1] sdr_addr = 25'd0,
	output reg  [15:0] sdr_din = 16'd0,
	output reg         sdr_req = 1'b0,

	output reg         loading = 1'b0,
	output reg         cart_ready = 1'b0,
	output reg  [23:0] mask_addr = 24'd0,
	output reg         hdr_color = 1'b0,
	output reg  [7:0]  romtype = 8'd0,
	output reg  [7:0]  ramtype = 8'd0,
	output reg         has_rtc = 1'b0
);

reg [7:0]  lo = 8'd0;
reg [79:0] last = 80'd0;      // the last 10 bytes, the newest in [7:0]
reg [24:0] last_addr = 25'd0;
reg        active_d = 1'b0;

always @(posedge clk) begin
	sdr_req <= 1'b0;
	active_d <= file_active;
	loading <= file_active;

	if (file_active && !active_d)
		last_addr <= 25'd0;

	if (file_wr) begin
		last <= { last[71:0], file_data };
		last_addr <= file_addr[24:0];
		if (!file_addr[0])
			lo <= file_data;
		else begin
			sdr_addr <= file_addr[25:1];
			sdr_din <= { file_data, lo };
			sdr_req <= 1'b1;
		end
	end

	if (!file_active && active_d) begin
		// the end of the file: bytes -1 .. -10 are last[7:0] .. last[79:72]
		cart_ready <= 1'b1;
		mask_addr <= last_addr[23:0];
		hdr_color <= last[64];        // -9
		romtype <= last[47:40];       // -6
		ramtype <= last[39:32];       // -5
		has_rtc <= last[16];          // -3
	end
end

endmodule
