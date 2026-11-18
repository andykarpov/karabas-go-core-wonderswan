`timescale 1ns / 1ps
`default_nettype wire

/*
 sim_top.v - the machine part of karabas_minig_top.v for the verilator simulation: ws_loader (the
 file bytes from the harness), ws_core (the VHDL through ghdl --synth), ws_sdram on sdram_model,
 ws_kbd-less keys from the harness. The frame buffer and the board video are left out: the harness
 takes the pixels of SwanTop (pixel_we / addr / data) directly.

 clk_sys and clk_ram (3 x) are driven by the harness, rising together.
*/

module sim_top (
	input  wire        clk_sys,
	input  wire        clk_ram,
	input  wire        init,

	input  wire        file_active,
	input  wire        file_wr,
	input  wire [31:0] file_addr,
	input  wire [7:0]  file_data,

	input  wire [1:0]  sw_system,      // 0 Auto, 1 Color, 2 Mono
	input  wire [10:0] keys,

	output wire        pixel_we,
	output wire [14:0] pixel_addr,
	output wire [11:0] pixel_data,
	output wire        vertical,
	output wire [15:0] snd_l,
	output wire [15:0] snd_r,
	output wire        cart_ready,
	output wire        hdr_color,
	output wire [31:0] sdram_errors,
	output wire        ext_read,
	output wire [24:0] ext_addr,
	output wire [15:0] ext_rdata
);

wire [25:1] ld_sdr_addr;
wire [15:0] ld_sdr_din;
wire ld_sdr_req, loading, has_rtc;
wire [23:0] mask_addr;
wire [7:0] romtype, ramtype;
ws_loader loader (
	.clk(clk_sys),
	.file_active(file_active), .file_wr(file_wr), .file_addr(file_addr), .file_data(file_data),
	.sdr_addr(ld_sdr_addr), .sdr_din(ld_sdr_din), .sdr_req(ld_sdr_req),
	.loading(loading), .cart_ready(cart_ready), .mask_addr(mask_addr), .hdr_color(hdr_color),
	.romtype(romtype), .ramtype(ramtype), .has_rtc(has_rtc)
);

reg is_color = 1'b1;
always @(posedge clk_sys)
	is_color <= sw_system == 2'd0 ? hdr_color : sw_system == 2'd1;

reg [7:0] rst_cnt = 8'd0;
reg ws_reset = 1'b1;
always @(posedge clk_sys) begin
	if (init || loading || !cart_ready)
		rst_cnt <= 8'd0;
	else if (rst_cnt != 8'hFF)
		rst_cnt <= rst_cnt + 8'd1;
	ws_reset <= rst_cnt != 8'hFF;
end

wire ext_refresh, ext_write, ext_ready;
wire [1:0] ext_be;
wire [15:0] ext_wdata;

ws_core ws (
	.clk(clk_sys), .clk_ram(clk_ram), .reset_in(ws_reset), .pause_in(1'b0),
	.EXTRAM_doRefresh(ext_refresh), .EXTRAM_read(ext_read), .EXTRAM_write(ext_write),
	.EXTRAM_be(ext_be), .EXTRAM_addr(ext_addr), .EXTRAM_datawrite(ext_wdata),
	.EXTRAM_dataread(ext_rdata), .EXTRAM_ready(ext_ready),
	.eepromWrite(), .eeprom_addr(10'd0), .eeprom_din(16'd0), .eeprom_dout(), .eeprom_req(1'b0), .eeprom_rnw(1'b1),
	.RTC_savedtimeIn({ 8'h26, 5'h11, 6'h18, 3'd3, 6'h22, 7'h30, 7'h00 }), .RTC_saveLoaded(~ws_reset),
	.maskAddr(mask_addr), .romtype(romtype), .ramtype(ramtype), .hasRTC(has_rtc),
	.vertical(vertical), .pixel_out_addr(pixel_addr), .pixel_out_data(pixel_data),
	.pixel_out_we(pixel_we), .audio_l(snd_l), .audio_r(snd_r),
	.isColor(is_color), .keys(keys)
);

wire [15:0] dq;
wire [12:0] a;
wire [1:0] ba;
wire ras_n, cas_n, we_n, cs_n, dqml, dqmh;
ws_sdram sdram (
	.init(init), .clk(clk_ram), .doRefresh(ext_refresh),
	.SDRAM_DQ(dq), .SDRAM_A(a), .SDRAM_DQML(dqml), .SDRAM_DQMH(dqmh), .SDRAM_BA(ba),
	.SDRAM_nCS(cs_n), .SDRAM_nWE(we_n), .SDRAM_nRAS(ras_n), .SDRAM_nCAS(cas_n),
	.ch1_addr(ld_sdr_addr), .ch1_dout(), .ch1_din(ld_sdr_din), .ch1_req(ld_sdr_req), .ch1_rnw(1'b0), .ch1_ready(),
	.ch2_addr(25'd0), .ch2_dout(), .ch2_din(16'd0), .ch2_req(1'b0), .ch2_rnw(1'b1), .ch2_ready(),
	.ch3_addr({ 1'b0, ext_addr[24:1] }), .ch3_dout(ext_rdata), .ch3_din(ext_wdata), .ch3_be(ext_be),
	.ch3_req(~loading & (ext_read | ext_write)), .ch3_rnw(ext_read), .ch3_ready(ext_ready)
);

sdram_model chip (
	.clk(clk_ram), .dq(dq), .a(a), .ba(ba), .cs_n(cs_n), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n),
	.dqml(dqml), .dqmh(dqmh), .errors(sdram_errors)
);

endmodule
