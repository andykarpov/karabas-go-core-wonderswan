`timescale 1ns / 1ps
`default_nettype wire

/*
 Bandai WonderSwan / WonderSwan Color core for Karabas Mini rev.G (HDMI, PCM5102): the MiSTer
 WonderSwan core (Robert Peip) with parts of open-pocket-ws (LakoMoor), rtl/karabas/ws_core.vhd,
 and the board glue of karabas-go-modules.

 Clocks (ws_clocks.v): clk_sys 36.864 MHz (the machine, the MCU link, the loader, the SRAM frame
 buffer writes, the audio), clk_ram 110.592 MHz (3 x clk_sys: SwanTop clk_ram and the SDRAM),
 clk_65 (1024 x 768 at 60 Hz, the OSD, HDMI; FT_CLK_OUT 8.125 MHz), clk_ser / clk_ser_n 325 MHz.

 Memory: the cartridge ROM (and its save RAM, as MiSTer: SwanTop maps it into EXTRAM) in the SDRAM
 (ws_sdram.v, the MiSTer controller); the 64 KB RAM of the machine in block RAM; the SRAM holds
 the three frame buffers of ws_fb.v. Boot: the open boot stub of open-pocket-ws (no Bandai IPL).

 The cartridge: the file of the core (type fileloader: .ws, .wsc in the wonderswan folder) through
 the file loader of kg_mcu2 into the SDRAM (ws_loader.v); its header gives the colour flag (Auto),
 the ROM / save types and the RTC flag. The machine is held in reset until a cartridge is in.

 Soft switches (core.json osd order):
   0 System (Auto / Color / Mono)   1 Reset
*/

module karabas_minig_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,

	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [5:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign TAPE_OUT = 1'b0;
assign ESP32_SPI_CS_N = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;
assign MIDI_TX = 1'b1;

assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;

// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board): 0
assign FLASH_CS_N = 1'b0;
assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_sys, clk_ram, clk_65, clk_ser, clk_ser_n, locked_sys, locked_vid;
ws_clocks clocks (
	.clk_in(CLK_50MHZ),
	.clk_sys(clk_sys),
	.clk_ram(clk_ram),
	.clk_65(clk_65),
	.clk_ser(clk_ser),
	.clk_ser_n(clk_ser_n),
	.locked_sys(locked_sys),
	.locked_vid(locked_vid)
);
wire areset_async = ~(locked_sys & locked_vid);
wire areset;
kg_sync #(.W(1), .STAGES(3), .INIT(1'b1)) sync_rst (.clk(clk_sys), .d(areset_async), .q(areset));

// the clock of the FT812 (it must always have one): 65 / 8 = 8.125 MHz
reg [1:0] ft_div = 2'd0;
reg ft_q = 1'b0;
always @(posedge clk_65) begin
	ft_div <= ft_div + 2'd1;
	if (ft_div == 2'd3) ft_q <= ~ft_q;
end
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(ft_q), .D1(ft_q), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

// MCU_SCK on a global buffer (as tsconf and the menu: on local routing the flip-flops of the SPI
// receiver had several ns of clock skew); the FT812 and SD2 get the IBUFG output (a BUFG drives no pad)
wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));

// MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire [55:0] hid_kbd;
wire [15:0] joy_l16, joy_r16;
wire [1:0] ld_kind;
wire [7:0] ld_data;
wire [31:0] ld_addr;
wire ld_active, ld_wr;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [2*8-1:0] sw;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

kg_mcu2 #(
	.CAPS(16'h0000),
	.SW_N(2),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_IMG(0),
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_sys),
	.N_RESET(~areset),

	.MCU_SCK(mcu_sck),
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SS(MCU_CS_N),
	.MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(MCU_IO[2]),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(dvi_only), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD(hid_kbd), .KBD_WR(), .PS2_CODE(), .PS2_KIND(), .PS2_WR(),
	.MS_X(), .MS_Y(), .MS_Z(), .MS_B(), .MS_WR(),
	.JOY_L(joy_l16), .JOY_R(joy_r16), .JOY_WR(),
	.PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(ld_kind), .LD_SLOT(), .LD_SIZE(), .LD_START(), .LD_ACTIVE(ld_active), .LD_END(),
	.LD_ADDR(ld_addr), .LD_DATA(ld_data), .LD_WR(ld_wr), .LD_READY(1'b1),

	.OSD_WR(osd_wr), .OSD_WADDR(osd_waddr), .OSD_WDATA(osd_wdata), .OSD_EN(osd_en),
	.OSD_FG(osd_fg), .OSD_BG(osd_bg), .OSD_ALPHA(osd_alpha), .OSD_PX(osd_px), .OSD_PY(osd_py),
	.OSD_PW(osd_pw), .OSD_PH(osd_ph), .OSD_PLACE(osd_place), .OSD_ZOOM(osd_zoom),

	.SDC_IMG_MOUNTED(), .SDC_IMG_SIZE(),
	.SDC_RD(8'd0), .SDC_WR(8'd0), .SDC_SECTOR(32'd0),
	.SDC_BUSY(), .SDC_DONE(), .SDC_ERROR(), .SDC_SLOT(),
	.SDC_BYTE_IN_STROBE(), .SDC_BYTE_ADDR(),
	.SDC_BYTE_IN_DATA(), .SDC_BYTE_OUT_DATA(8'd0),
	.IMG_WP(), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0),
	.BK_MOUNT(), .BK_FLUSHED(), .BK_SLOT(3'd0), .BK_SIZE(32'd0),
	.BK_KIND(8'd0), .BK_RESULT(),
	.IMG_ACTIVE(),

	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'b1111), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_CFG(128'd0), .PORT_IN_FULL(), .PORT_STAT(), .PORT_STAT_WR(),
	.RTC_A(8'd0), .RTC_DI(8'd0), .RTC_CS(1'b0), .RTC_WR_N(1'b1), .RTC_DO(),
	.MATRIX_CMD(24'd0), .MATRIX_CMD_WR(1'b0), .DEBUG_ADDR(16'd0), .DEBUG_DATA(16'd0),

	.FT_SPI_ON(ft_spi_on), .FT_VGA_ON(), .FT_RESET(), .FT_SCK(), .FT_MOSI(ft_mosi), .FT_MISO(FT_SPI_MISO),
	.FT_CS_N(ft_cs_n),
	.SD2_SCK(), .SD2_MOSI(sd2_mosi), .SD2_MISO(SD_DO), .SD2_CS_N(sd2_cs_n)
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches (the SW registers of kg_mcu2)

wire [1:0] sw_system = sw[0*8 +: 2];   // 0 Auto, 1 Color, 2 Mono
wire sw_reset = sw[1*8];

// ------------------------------------------------------------------ cartridge

wire file_active = ld_active && ld_kind == 2'd1;
wire file_wr = ld_wr && ld_kind == 2'd1;

wire [25:1] ld_sdr_addr;
wire [15:0] ld_sdr_din;
wire ld_sdr_req, loading, cart_ready, hdr_color, has_rtc;
wire [23:0] mask_addr;
wire [7:0] romtype, ramtype;
ws_loader loader (
	.clk(clk_sys),
	.file_active(file_active),
	.file_wr(file_wr),
	.file_addr(ld_addr),
	.file_data(ld_data),
	.sdr_addr(ld_sdr_addr),
	.sdr_din(ld_sdr_din),
	.sdr_req(ld_sdr_req),
	.loading(loading),
	.cart_ready(cart_ready),
	.mask_addr(mask_addr),
	.hdr_color(hdr_color),
	.romtype(romtype),
	.ramtype(ramtype),
	.has_rtc(has_rtc)
);

// colour: the header in Auto (MiSTer: status[40:39] == 0 -> the header, 2 -> colour)
reg is_color = 1'b1;
always @(posedge clk_sys)
	is_color <= sw_system == 2'd0 ? hdr_color : sw_system == 2'd1;

// reset: the PLLs, the Reset item, while a cartridge loads, until the first one is in
reg [7:0] rst_cnt = 8'd0;
reg ws_reset = 1'b1;
always @(posedge clk_sys) begin
	if (areset || sw_reset || loading || !cart_ready)
		rst_cnt <= 8'd0;
	else if (rst_cnt != 8'hFF)
		rst_cnt <= rst_cnt + 8'd1;
	ws_reset <= rst_cnt != 8'hFF;
end

// ------------------------------------------------------------------ keys

wire [10:0] keys;
ws_kbd kbd (
	.clk(clk_sys),
	.kb_dat0(hid_kbd[15:8]), .kb_dat1(hid_kbd[23:16]), .kb_dat2(hid_kbd[31:24]),
	.kb_dat3(hid_kbd[39:32]), .kb_dat4(hid_kbd[47:40]), .kb_dat5(hid_kbd[55:48]),
	.joy_l(joy_l16[12:0]), .joy_r(joy_r16[12:0]),
	.keys(keys)
);

// ------------------------------------------------------------------ WonderSwan

wire ext_refresh, ext_read, ext_write;
wire [1:0] ext_be;
wire [24:0] ext_addr;
wire [15:0] ext_wdata, ext_rdata;
wire ext_ready;
wire vertical, pixel_we;
wire [14:0] pixel_addr;
wire [11:0] pixel_data;
wire [15:0] snd_l, snd_r;

ws_core #(.KG_CPU_S80(0)) ws (
	.clk(clk_sys),
	.clk_ram(clk_ram),
	.reset_in(ws_reset),
	.pause_in(1'b0),

	.EXTRAM_doRefresh(ext_refresh),
	.EXTRAM_read(ext_read),
	.EXTRAM_write(ext_write),
	.EXTRAM_be(ext_be),
	.EXTRAM_addr(ext_addr),
	.EXTRAM_datawrite(ext_wdata),
	.EXTRAM_dataread(ext_rdata),
	.EXTRAM_ready(ext_ready),

	.maskAddr(mask_addr),
	.romtype(romtype),
	.ramtype(ramtype),
	.hasRTC(has_rtc),

	.vertical(vertical),
	.pixel_out_addr(pixel_addr),
	.pixel_out_data(pixel_data),
	.pixel_out_we(pixel_we),

	.audio_l(snd_l),
	.audio_r(snd_r),

	.isColor(is_color),
	.keys(keys)
);

// ------------------------------------------------------------------ SDRAM

wire [1:0] sdr_dqm;
ws_sdram sdram (
	.init(areset),
	.clk(clk_ram),
	.doRefresh(ext_refresh),

	.SDRAM_DQ(SDR_DQ),
	.SDRAM_A(SDR_A),
	.SDRAM_DQML(SDR_DQM[0]),
	.SDRAM_DQMH(SDR_DQM[1]),
	.SDRAM_BA(SDR_BA),
	.SDRAM_nCS(),
	.SDRAM_nWE(SDR_WE_N),
	.SDRAM_nRAS(SDR_RAS_N),
	.SDRAM_nCAS(SDR_CAS_N),

	.ch1_addr(ld_sdr_addr),
	.ch1_dout(),
	.ch1_din(ld_sdr_din),
	.ch1_req(ld_sdr_req),
	.ch1_rnw(1'b0),
	.ch1_ready(),

	.ch2_addr(25'd0),
	.ch2_dout(),
	.ch2_din(16'd0),
	.ch2_req(1'b0),
	.ch2_rnw(1'b1),
	.ch2_ready(),

	.ch3_addr({ 1'b0, ext_addr[24:1] }),
	.ch3_dout(ext_rdata),
	.ch3_din(ext_wdata),
	.ch3_be(ext_be),
	.ch3_req(~loading & (ext_read | ext_write)),
	.ch3_rnw(ext_read),
	.ch3_ready(ext_ready)
);
// the clock of the chip: clk_ram inverted (altddio_out of MiSTer: datain_h 0, datain_l 1)
ODDR2 oddr_sdr_clk (.Q(SDR_CLK), .C0(clk_ram), .C1(~clk_ram), .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ video

wire [23:0] vid_rgb;
wire vid_hs, vid_vs, vid_de;
ws_fb fb (
	.clk(clk_sys),
	.pixel_we(pixel_we),
	.pixel_addr(pixel_addr),
	.pixel_data(pixel_data),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N),
	.clk_65(clk_65),
	.rgb(vid_rgb),
	.hs(vid_hs),
	.vs(vid_vs),
	.de(vid_de)
);

// the bitmap OSD of link v2 (kg_l2_osd_overlay): written in clk_sys, drawn in clk_65
wire [23:0] osd_rgb;
wire osd_hs, osd_vs, osd_de;
kg_l2_osd_overlay osd (
	.wclk(clk_sys),
	.osd_wr(osd_wr), .osd_waddr(osd_waddr), .osd_wdata(osd_wdata), .osd_en(osd_en),
	.osd_fg(osd_fg), .osd_bg(osd_bg), .osd_alpha(osd_alpha), .osd_px(osd_px), .osd_py(osd_py),
	.osd_pw(osd_pw), .osd_ph(osd_ph), .osd_place(osd_place), .osd_zoom(osd_zoom),
	.icon_on(8'd0), .icon_act(8'd0),
	.clk(clk_65),
	.rgb_i(vid_rgb), .hs_i(vid_hs), .vs_i(vid_vs), .de_i(vid_de),
	.rgb_o(osd_rgb), .hs_o(osd_hs), .vs_o(osd_vs), .de_o(osd_de)
);

// ------------------------------------------------------------------ audio

// SwanTop audio (signed 16 bits, clk_sys) at 48 kHz: 36.864 MHz / 48 kHz = 768 clocks exactly
reg [9:0] aud_div = 10'd0;
reg [15:0] aud_l = 16'd0, aud_r = 16'd0;
reg aud_t = 1'b0;
always @(posedge clk_sys) begin
	if (aud_div == 10'd767) begin
		aud_div <= 10'd0;
		aud_l <= snd_l;
		aud_r <= snd_r;
		aud_t <= ~aud_t;
	end
	else
		aud_div <= aud_div + 10'd1;
end

kg_pcm5102 #(.DIV_BITS(2)) dac (
	.clk(clk_sys),
	.reset(areset),
	.left(aud_l),
	.right(aud_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);

// into clk_65 for HDMI: the toggle of a new sample (the samples hold for 768 clk_sys)
reg [2:0] aud_ts = 3'd0;
reg aud_stb = 1'b0;
reg [23:0] hdmi_l = 24'd0, hdmi_r = 24'd0;
always @(posedge clk_65) begin
	aud_ts <= { aud_ts[1:0], aud_t };
	aud_stb <= aud_ts[2] != aud_ts[1];
	if (aud_ts[2] != aud_ts[1]) begin
		hdmi_l <= { aud_l, 8'd0 };
		hdmi_r <= { aud_r, 8'd0 };
	end
end

// ------------------------------------------------------------------ HDMI

wire dvi_only_65;
kg_sync #(.W(1), .STAGES(3)) sync_dvi (.clk(clk_65), .d(dvi_only), .q(dvi_only_65));

hdmi_tx #(.SAMPLE_FREQ(48000), .INPUT_REG(1)) hdmi (
	.clk(clk_65),
	.sclk(clk_ser),
	.sclk_n(clk_ser_n),
	// the reset straight from the PLLs, as core-sega: 26111820 had it through a kg_sync in clk_65 (fanout
	// ~140 into the 325 MHz serialisers, -0.13 ns) and gave no picture on the board: the mod5 counters of
	// the channels must leave the reset at the same serial clock
	.reset(areset_async),
	.rgb(osd_rgb),
	.vsync(~osd_vs),     // 1024 x 768 at 60 Hz: negative syncs (VESA)
	.hsync(~osd_hs),
	.de(osd_de),
	.audio_en(~dvi_only_65),
	.audio_l(hdmi_l),
	.audio_r(hdmi_r),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

endmodule
