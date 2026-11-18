`timescale 1ns / 1ps
`default_nettype wire
/*
 ws_clocks.v

 The clocks of the WonderSwan core from CLK_50MHZ (the pin):

 1. The machine: DCM_CLKGEN 50 * 14 / 19 = 36.842 MHz (36.864 of MiSTer -0.06 %: the WonderSwan at
    75.42 Hz; a PLL alone cannot: PFD >= 19 MHz leaves 50 / 25 MHz in, and no VCO of 400..1080 MHz is
    a multiple of 36.864 there) -> BUFG -> PLL x18 (VCO 663.2 MHz, cleans the jitter of CLKFX).
    (26111820 / 21 had 87 / 118 = 36.8644 MHz, a DFS phase detector of 0.42 MHz: small M / D here
    for a lower CLKFX jitter.)
      clk_sys  /18  36.842 MHz: SwanTop (clk), the MCU link, the loader, the frame buffer writes
                    and the SRAM, the audio
      clk_ram  /6   110.53 MHz: SwanTop (clk_ram) and the SDRAM controller (3 x clk_sys, the rising
                    edges together, as the 36.864 / 110.592 of the MiSTer PLL)
      clk_sdr  /6   110.53 MHz, 330 degrees (-0.75 ns): SDR_CLK only (an ODDR2), the chip a little ahead
                    of the controller as core-sega (MiSTer inverts the clock of the chip; here that puts
                    the read data of CL 3 outside the sample edge of the controller: 26111821 did not
                    start a game on the board, the zero delay model of the simulation did)
    The PLL is held in reset until the DCM locks.
 2. The video: PLL from 50 MHz, VCO 650 MHz (as core-sega):
      clk_65   /10  65.0 MHz: 1024 x 768 at 60 Hz (VESA), the OSD, HDMI; FT_CLK_OUT 8.125 MHz (/8)
      clk_ser, clk_ser_n  /2  325 MHz, 0 and 180 degrees: the HDMI serialiser
 The two groups are not related: the frame buffer crosses with a toggle and a line buffer, the audio
 with a toggle (TIG in the ucf).
*/
module ws_clocks (
	input wire clk_in,
	output wire clk_sys,
	output wire clk_ram,
	output wire clk_sdr,
	output wire clk_65,
	output wire clk_ser,
	output wire clk_ser_n,
	output wire locked_sys,
	output wire locked_vid
);

wire clk_50_ibufg, clk_50_bufg;
IBUFG ibufg_50 (.I(clk_in), .O(clk_50_ibufg));
BUFG bufg_50 (.I(clk_50_ibufg), .O(clk_50_bufg));

wire fx, fx_buf, dcm_locked;
DCM_CLKGEN #(
	.CLKFX_MULTIPLY(14),
	.CLKFX_DIVIDE(19),
	.CLKFXDV_DIVIDE(2),
	.CLKFX_MD_MAX(0.74),
	.CLKIN_PERIOD(20.0),
	.SPREAD_SPECTRUM("NONE"),
	.STARTUP_WAIT("FALSE")
) dcm (
	.CLKIN(clk_50_bufg),
	.RST(1'b0),
	.FREEZEDCM(1'b0),
	.PROGCLK(1'b0),
	.PROGDATA(1'b0),
	.PROGEN(1'b0),
	.CLKFX(fx),
	.CLKFX180(),
	.CLKFXDV(),
	.LOCKED(dcm_locked),
	.PROGDONE(),
	.STATUS()
);
BUFG bufg_fx (.I(fx), .O(fx_buf));

wire [5:0] pll_sys;
kg_pll #(
	.CLKIN_PERIOD(27.143),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(18),
	.CLKOUT0_DIVIDE(18),
	.CLKOUT1_DIVIDE(6),
	.CLKOUT2_DIVIDE(6), .CLKOUT2_PHASE(330.0),
	.IBUFG(0),
	.BUFG_MASK(6'b000111)
) pll_m (
	.clk_in(fx_buf),
	.rst(!dcm_locked),
	.clk_out(pll_sys),
	.locked(locked_sys)
);
assign clk_sys = pll_sys[0];
assign clk_ram = pll_sys[1];
assign clk_sdr = pll_sys[2];

wire [5:0] pll_vid;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(13),
	.CLKOUT0_DIVIDE(10),
	.CLKOUT1_DIVIDE(2),
	.CLKOUT2_DIVIDE(2), .CLKOUT2_PHASE(180.0),
	.IBUFG(0),
	.BUFG_MASK(6'b000111)
) pll_v (
	.clk_in(clk_50_bufg),
	.rst(1'b0),
	.clk_out(pll_vid),
	.locked(locked_vid)
);
assign clk_65 = pll_vid[0];
assign clk_ser = pll_vid[1];
assign clk_ser_n = pll_vid[2];

endmodule
