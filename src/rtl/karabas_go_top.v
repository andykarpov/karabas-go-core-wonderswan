`timescale 1ns / 1ps
`default_nettype wire

/*
 Bandai WonderSwan / WonderSwan Color core for Karabas Go (VGA, PCM5102). Made by tools/mktops.py
 from karabas_minig_top.v (do not edit: change that one and run it): the same except the pins,
 the MCU link (MCU_SCK not on a clock pin) and the video: 24 bit RGB to the VGA DAC with its pixel
 clock on V_CLK (clk_65), the FT812 off that bus (FT_OE_N = 1). The floppy connector is not used
 (its outputs 0).  the MiSTer WonderSwan core (Robert Peip) with parts of open-pocket-ws (LakoMoor),
 rtl/karabas/ws_core.vhd, and the board glue of karabas-go-modules.

 Clocks (ws_clocks.v): clk_sys 36.864 MHz (the machine, the MCU link, the loader, the SRAM frame
 buffer writes, the audio), clk_ram 110.592 MHz (3 x clk_sys: SwanTop clk_ram and the SDRAM),
 clk_65 (1024 x 768 at 60 Hz, the OSD, VGA on V_CLK; clk_ser / clk_ser_n of HDMI not used here).

 Memory: the cartridge ROM (and its save RAM, as MiSTer: SwanTop maps it into EXTRAM) in the SDRAM
 (ws_sdram.v, the MiSTer controller); the 64 KB RAM of the machine in block RAM; the SRAM holds
 the ring of 8 frame buffers of ws_fb.v. Boot: the open boot stub of open-pocket-ws (no Bandai IPL).
 Saves: kg_bk_ram (.sav of the cartridge SRAM / EEPROM) through ws_bk.v; the cartridge RTC is set
 from the firmware RTC.

 The cartridge: the file of the core (type fileloader: .ws, .wsc in the wonderswan folder) through
 the file loader of kg_mcu2 into the SDRAM (ws_loader.v); its header gives the colour flag (Auto),
 the ROM / save types and the RTC flag. The machine is held in reset until a cartridge is in.

 Soft switches (core.json osd order):
   0 System (Auto / Color / Mono)   1 Orientation (Auto / Horz / Vert / Vert180)
   2 Flickerblend (Off / 2 / 3 frames)   3 Reset
*/

module karabas_go_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	inout wire ESP_RESET_N,
	inout wire ESP_BOOT_N,

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

	output wire [7:0] VGA_R,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_B,
	output wire VGA_HS,
	output wire VGA_VS,
	output wire V_CLK,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	output wire FT_OE_N,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	input wire FDC_INDEX,
	output wire [1:0] FDC_DRIVE,
	output wire FDC_MOTOR,
	output wire FDC_DIR,
	output wire FDC_STEP,
	output wire FDC_WDATA,
	output wire FDC_WGATE,
	input wire FDC_TR00,
	input wire FDC_WPRT,
	input wire FDC_RDATA,
	output wire FDC_SIDE_N,

	output wire TAPE_OUT,
	input wire TAPE_IN,
	output wire BEEPER,

	output wire DAC_LRCK,
	output wire DAC_DAT,
	output wire DAC_BCK,
	output wire DAC_MUTE,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	input wire MCU_SPI_FT_CS_N,
	input wire MCU_SPI_SD2_CS_N,
	inout wire [1:0] MCU_SPI_IO, // [0] INT of link v2 (firmware IO1, GPIO2), [1] unused (IO0, GPIO14)

	output wire MIDI_TX,
	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

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
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;
assign MIDI_TX = 1'b1;
assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign MIDI_CLK = 1'b0;      // the SAM2695 synth: held in reset, no use for it here
assign MIDI_RESET_N = 1'b0;

assign FT_OE_N = 1'b1;     // the FT812 does not drive the video DAC
assign BEEPER = 1'b0;
assign DAC_MUTE = 1'b1;    // soft mute of the PCM5102: 1 = sound on

// the floppy connector is not used: its outputs 0 (the board inverts them: high = active)
assign FDC_DRIVE = 2'b00;
assign FDC_MOTOR = 1'b0;
assign FDC_DIR = 1'b0;
assign FDC_STEP = 1'b0;
assign FDC_WDATA = 1'b0;
assign FDC_WGATE = 1'b0;
assign FDC_SIDE_N = 1'b0;

// the SDRAM /CS is hard wired on Go; FLASH_CS_N is the flash chip
assign FLASH_CS_N = 1'b1;
assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_sys, clk_ram, clk_sdr, clk_65, clk_ser, clk_ser_n, locked_sys, locked_vid;
ws_clocks clocks (
	.clk_in(CLK_50MHZ),
	.clk_sys(clk_sys),
	.clk_ram(clk_ram),
	.clk_sdr(clk_sdr),
	.clk_65(clk_65),
	.clk_ser(clk_ser),
	.clk_ser_n(clk_ser_n),
	.locked_sys(locked_sys),
	.locked_vid(locked_vid)
);
wire areset_async = ~(locked_sys & locked_vid);
wire areset_vid = ~locked_vid;   // the video group (HDMI) only: the OSD even when the machine clock fails
wire areset;
kg_sync #(.W(1), .STAGES(3), .INIT(1'b1)) sync_rst (.clk(clk_sys), .d(areset_async), .q(areset));

// the pixel clock of the VGA DAC, inverted: the DAC takes the pixel on the rising V_CLK, the middle of the pixel
ODDR2 oddr_v_clk (.Q(V_CLK), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;

// MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1
wire mcu_int;
// INT of link v2 on MCU_SPI_IO[0] (N9, the IO1 line of the firmware)
assign MCU_SPI_IO[0] = mcu_int;
assign MCU_SPI_IO[1] = 1'bz;

wire [55:0] hid_kbd;
wire [15:0] joy_l16, joy_r16;
wire [1:0] ld_kind;
wire [7:0] ld_data;
wire [31:0] ld_addr;
wire ld_active, ld_wr;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [4*8-1:0] sw;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

// the .sav file of kg_bk_ram (slot 0) on the mounter of kg_mcu2
wire [7:0] img_flush, sdc_img_mounted, sdc_rd, sdc_wr, sdc_byte_in_data, sdc_byte_out_data, bk_kind, bk_result;
wire [63:0] sdc_img_size;
wire [31:0] sdc_sector, bk_size;
wire sdc_busy, sdc_done, sdc_error, sdc_byte_in_strobe, bk_mount, bk_flushed;
wire [2:0] sdc_slot;
wire [8:0] sdc_byte_addr;

wire [7:0] rtc_a, rtc_do;

kg_mcu2 #(
	.CAPS(16'h0002),     // backup RAM: the firmware flushes the .sav before a new game
	.SW_N(4),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_IMG(1),      // the .sav file of kg_bk_ram
	.IMG_OUT_LATENCY(2), // the sector buffer of kg_bk_ram
	.ENABLE_RTC(1),      // the firmware clock for the cartridge RTC
	.ENABLE_AUX(0),
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
	.MCU_SPI_FT_SS(MCU_SPI_FT_CS_N),
	.MCU_SPI_SD2_SS(MCU_SPI_SD2_CS_N),

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

	.SDC_IMG_MOUNTED(sdc_img_mounted), .SDC_IMG_SIZE(sdc_img_size),
	.SDC_RD(sdc_rd), .SDC_WR(sdc_wr), .SDC_SECTOR(sdc_sector),
	.SDC_BUSY(sdc_busy), .SDC_DONE(sdc_done), .SDC_ERROR(sdc_error), .SDC_SLOT(sdc_slot),
	.SDC_BYTE_IN_STROBE(sdc_byte_in_strobe), .SDC_BYTE_ADDR(sdc_byte_addr),
	.SDC_BYTE_IN_DATA(sdc_byte_in_data), .SDC_BYTE_OUT_DATA(sdc_byte_out_data),
	.IMG_WP(), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(img_flush), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0),
	.BK_MOUNT(bk_mount), .BK_FLUSHED(bk_flushed), .BK_SLOT(3'd0), .BK_SIZE(bk_size),
	.BK_KIND(bk_kind), .BK_RESULT(bk_result),
	.IMG_ACTIVE(),

	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'b1111), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_CFG(128'd0), .PORT_IN_FULL(), .PORT_STAT(), .PORT_STAT_WR(),
	.RTC_A(rtc_a), .RTC_DI(8'd0), .RTC_CS(1'b0), .RTC_WR_N(1'b1), .RTC_DO(rtc_do),
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
wire [1:0] sw_orient = sw[1*8 +: 2]; // 0 Auto, 1 Horz, 2 Vert, 3 Vert180
wire [1:0] sw_blend = sw[2*8 +: 2];  // 0 Off, 1 2 frames, 2 3 frames
wire sw_reset = sw[3*8];

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

// ------------------------------------------------------------------ save memory (.sav)

// kg_bk_ram on img slot 0: started when a cartridge is in (loading falls) with the size of its
// save memory (header byte -5: SRAM 01..05 = 8 / 32 / 128 / 256 / 512 KB in the SDRAM, EEPROM
// 10 / 50 / 20 = 128 B / 1 KB / 2 KB, as one sector at least); the CPU is held in reset until the
// file is in. A new file resets it (the firmware flushes the old one before it loads another game).
// SRAM writes of the CPU mark their sector; an EEPROM write (eepromWrite, no address) marks all its
// sectors (at most 4). Over 64 sectors kg_bk_ram saves blocks (512 KB: 8 KB).
reg [10:0] sav_sectors = 11'd0;
reg sav_sram = 1'b1;
always @(posedge clk_sys) begin
	sav_sram <= ramtype[7:4] == 4'd0;
	case (ramtype)
		8'h01: sav_sectors <= 11'd16;
		8'h02: sav_sectors <= 11'd64;
		8'h03: sav_sectors <= 11'd256;
		8'h04: sav_sectors <= 11'd512;
		8'h05: sav_sectors <= 11'd1024;
		8'h10: sav_sectors <= 11'd1;
		8'h50: sav_sectors <= 11'd2;
		8'h20: sav_sectors <= 11'd4;
		default: sav_sectors <= 11'd0;
	endcase
end

reg file_active_d = 1'b0, loading_d = 1'b0, bk_reset = 1'b0, bk_start = 1'b0;
always @(posedge clk_sys) begin
	file_active_d <= file_active;
	loading_d <= loading;
	bk_reset <= file_active && !file_active_d;
	bk_start <= loading_d && !loading;
end

wire ext_write, eeprom_written;
wire [24:0] ext_addr;
reg sav_wr = 1'b0;
reg [18:0] sav_a = 19'd0;
reg [2:0] ee_mark = 3'd0;          // EEPROM sectors still to mark
always @(posedge clk_sys) begin
	sav_wr <= 1'b0;
	if (eeprom_written)
		ee_mark <= sav_sectors[2:0] == 3'd0 ? 3'd4 : sav_sectors[2:0];
	if (sav_sram) begin
		sav_wr <= ext_write && ext_addr[24];
		sav_a <= ext_addr[18:0];
	end
	else if (ee_mark != 3'd0) begin
		sav_wr <= 1'b1;
		sav_a <= { 7'd0, ee_mark - 3'd1, 9'd0 };
		ee_mark <= ee_mark - 3'd1;
	end
end

wire bk_busy, bk_mem_req, bk_mem_we, bk_mem_ack;
wire [18:0] bk_mem_addr;
wire [7:0] bk_mem_din, bk_mem_dout;
kg_bk_ram #(
	.SLOT(3'd0),
	.IDLE_CLOCKS(27'd36864000),    // ~1 s at 36.864 MHz: save after the last write
	.MAX_CLOCKS(27'd73728000),     // ~2 s: at the latest after the first write
	.MOUNT_CLOCKS(27'd36864000),   // ~1 s: no answer to the mount, go on without a save
	.GRACE_CLOCKS(27'd368640),     // ~10 ms: no file
	.LINK(2),                      // on the mounter of kg_mcu2
	.SBITS(10)                     // up to 512 KB
) bk_ram (
	.clk(clk_sys),
	.reset(bk_reset),
	.start(bk_start),
	.size(sav_sectors),
	.kind(8'h00),
	.busy(bk_busy),
	.mounted(),
	.saving(),
	.save_error(),
	.wr(sav_wr),
	.wr_addr(sav_a),
	.mem_req(bk_mem_req),
	.mem_we(bk_mem_we),
	.mem_addr(bk_mem_addr),
	.mem_din(bk_mem_din),
	.mem_ack(bk_mem_ack),
	.mem_dout(bk_mem_dout),
	.img_mounted(8'd0), .img_size(64'd0), .img_data_wr(1'b0), .img_data_addr(9'd0), .img_data(8'd0),
	.img_result_wr(1'b0), .img_result(8'd0), .img_sum(16'd0), .img_flush(img_flush),
	.img_q_wr(), .img_q_di(), .img_q_ack(1'b0),
	.sdc_img_mounted_i(sdc_img_mounted), .sdc_img_size_i(sdc_img_size), .sdc_rd_o(sdc_rd),
	.sdc_wr_o(sdc_wr), .sdc_sector_o(sdc_sector), .sdc_busy_i(sdc_busy), .sdc_done_i(sdc_done),
	.sdc_error_i(sdc_error), .sdc_slot_i(sdc_slot), .sdc_byte_in_strobe_i(sdc_byte_in_strobe),
	.sdc_byte_addr_i(sdc_byte_addr), .sdc_byte_in_data_i(sdc_byte_in_data),
	.sdc_byte_out_data_o(sdc_byte_out_data),
	.bk_mount(bk_mount), .bk_flushed(bk_flushed), .bk_size(bk_size), .bk_kind(bk_kind),
	.bk_result(bk_result)
);

wire [25:1] bk_sdr_addr;
wire [15:0] bk_sdr_din, bk_sdr_dout, ee_din, ee_dout;
wire bk_sdr_req, bk_sdr_rnw, bk_sdr_ready, ee_req, ee_rnw;
wire [9:0] ee_addr;
ws_bk bk (
	.clk(clk_sys), .clk_ram(clk_ram), .sram(sav_sram),
	.mem_req(bk_mem_req), .mem_we(bk_mem_we), .mem_addr(bk_mem_addr), .mem_din(bk_mem_din),
	.mem_ack(bk_mem_ack), .mem_dout(bk_mem_dout),
	.sdr_addr(bk_sdr_addr), .sdr_din(bk_sdr_din), .sdr_req(bk_sdr_req), .sdr_rnw(bk_sdr_rnw),
	.sdr_dout(bk_sdr_dout), .sdr_ready(bk_sdr_ready),
	.ee_addr(ee_addr), .ee_din(ee_din), .ee_req(ee_req), .ee_rnw(ee_rnw), .ee_dout(ee_dout)
);

// ------------------------------------------------------------------ cartridge RTC

// the time of the firmware RTC (core.json rtc_mode 2: MC146818 registers, BCD): seconds 0,
// minutes 2, hours 4 (24 h), day of the week 6 (1 = Sunday), day 7, month 8, year 9. Read round
// and round while the machine is in reset; RTC_saveLoaded rises with the reset end and the MiSTer
// rtc.vhd takes the time (its week day 0 = Sunday). A time the game sets is lost on the next start.
reg [2:0] rtc_i = 3'd0;
reg [2:0] rtc_q = 3'd0;      // the register of rtc_do (rtc_a a clock before)
reg [41:0] rtc_time = 42'd0;
reg rtc_loaded = 1'b0;
wire ws_reset_w;
assign rtc_a = rtc_i == 3'd0 ? 8'h00 : rtc_i == 3'd1 ? 8'h02 : rtc_i == 3'd2 ? 8'h04 :
	{ 5'd0, rtc_i } + 8'h03;   // 3..6 -> 6..9
always @(posedge clk_sys) begin
	rtc_q <= rtc_i;
	rtc_i <= rtc_i == 3'd6 ? 3'd0 : rtc_i + 3'd1;
	if (ws_reset_w) begin
		rtc_loaded <= 1'b0;
		case (rtc_q)
			3'd0: rtc_time[6:0] <= rtc_do[6:0];
			3'd1: rtc_time[13:7] <= rtc_do[6:0];
			3'd2: rtc_time[19:14] <= rtc_do[5:0];
			3'd3: rtc_time[22:20] <= rtc_do[2:0] - 3'd1;
			3'd4: rtc_time[28:23] <= rtc_do[5:0];
			3'd5: rtc_time[33:29] <= rtc_do[4:0];
			default: rtc_time[41:34] <= rtc_do;
		endcase
	end
	else
		rtc_loaded <= 1'b1;
end

// reset: the PLLs, the Reset item, while a cartridge loads, until the first one is in, while the
// .sav file loads
reg [7:0] rst_cnt = 8'd0;
reg ws_reset = 1'b1;
always @(posedge clk_sys) begin
	if (areset || sw_reset || loading || !cart_ready || bk_busy)
		rst_cnt <= 8'd0;
	else if (rst_cnt != 8'hFF)
		rst_cnt <= rst_cnt + 8'd1;
	ws_reset <= rst_cnt != 8'hFF;
end
assign ws_reset_w = ws_reset;

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

wire ext_refresh, ext_read;
wire [1:0] ext_be;
wire [15:0] ext_wdata, ext_rdata;
wire ext_ready;
wire vertical, pixel_we;
wire [14:0] pixel_addr;
wire [11:0] pixel_data;
wire [15:0] snd_l, snd_r;

ws_core #(.KG_CPU_S80(1)) ws (
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

	.eepromWrite(eeprom_written),
	.eeprom_addr(ee_addr),
	.eeprom_din(ee_din),
	.eeprom_dout(ee_dout),
	.eeprom_req(ee_req),
	.eeprom_rnw(ee_rnw),

	.RTC_savedtimeIn(rtc_time),
	.RTC_saveLoaded(rtc_loaded),

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

	.ch2_addr(bk_sdr_addr),
	.ch2_dout(bk_sdr_dout),
	.ch2_din(bk_sdr_din),
	.ch2_req(bk_sdr_req),
	.ch2_rnw(bk_sdr_rnw),
	.ch2_ready(bk_sdr_ready),

	.ch3_addr({ 1'b0, ext_addr[24:1] }),
	.ch3_dout(ext_rdata),
	.ch3_din(ext_wdata),
	.ch3_be(ext_be),
	.ch3_req(~loading & (ext_read | ext_write)),
	.ch3_rnw(ext_read),
	.ch3_ready(ext_ready)
);
// the clock of the chip: clk_sdr (clk_ram at 330 degrees, ws_clocks.v), not inverted
ODDR2 oddr_sdr_clk (.Q(SDR_CLK), .C0(clk_sdr), .C1(~clk_sdr), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ video

wire [23:0] vid_rgb;
wire vid_hs, vid_vs, vid_de;
// the picture turned: Auto = Vert180 when the game says vertical (as the MiSTer top)
reg [1:0] fb_rot = 2'd0;
always @(posedge clk_sys)
	fb_rot <= sw_orient == 2'd0 ? (vertical ? 2'd2 : 2'd0) : sw_orient - 2'd1;

ws_fb fb (
	.clk(clk_sys),
	.rot(fb_rot),
	.blend(sw_blend),
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
	.lrck(DAC_LRCK)
);

// ------------------------------------------------------------------ VGA

// the syncs of the overlay output go with osd_rgb
reg vga_hs = 1'b1, vga_vs = 1'b1;
always @(posedge clk_65) begin
	vga_hs <= ~osd_hs;   // 1024 x 768 at 60 Hz: negative syncs (VESA)
	vga_vs <= ~osd_vs;
end
reg [23:0] vga_rgb = 24'd0;
always @(posedge clk_65)
	vga_rgb <= osd_de ? osd_rgb : 24'd0;
assign VGA_R = vga_rgb[23:16];
assign VGA_G = vga_rgb[15:8];
assign VGA_B = vga_rgb[7:0];
assign VGA_HS = vga_hs;
assign VGA_VS = vga_vs;

endmodule
