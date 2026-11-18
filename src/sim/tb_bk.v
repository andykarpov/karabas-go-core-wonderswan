`timescale 1ns / 1ps
`default_nettype wire

/*
 tb_bk.v - iverilog check of ws_bk.v (sim/run_checks.sh, a few seconds): the memory port of
 kg_bk_ram as it drives it (mem_req held until mem_ack, a sector byte by byte from offset 0),
 ws_bk, ws_sdram on sdram_model, a model of the EEPROM block RAM (port b of eeprom.vhd on clk_ram).
 Checked:
 - SRAM: a sector written byte by byte at offset 0x1200 (sector 9) and read back; a word the CPU
   writes through ch3 (EXTRAM byte 0x1000000 + 0x2468, byte enables) read as bytes 0x2468 / 0x2469
   (the same place in the SDRAM); ch3 reads back the sector bytes (0x1001200);
 - EEPROM: 1024 bytes written and read back, and the words in the block RAM (low byte = even).
 Prints "tb_bk: 0 errors".
*/

module tb_bk;

reg clk_ram = 1'b0, clk = 1'b0;
always #3 clk_ram = ~clk_ram;   // clk_sys = clk_ram / 3, rising edges aligned
always #9 clk = ~clk;

integer errors = 0;
task check(input [255:0] what, input [31:0] got, input [31:0] want);
	if (got !== want) begin
		$display("ERROR %0s: got %h, want %h", what, got, want);
		errors = errors + 1;
	end
endtask

reg init = 1'b1, sram = 1'b1;
reg mem_req = 1'b0, mem_we = 1'b0;
reg [18:0] mem_addr = 19'd0;
reg [7:0] mem_din = 8'd0;
wire mem_ack;
wire [7:0] mem_dout;
wire [25:1] sdr_addr;
wire [15:0] sdr_din, sdr_dout, ee_din;
wire sdr_req, sdr_rnw, sdr_ready, ee_req, ee_rnw;
wire [9:0] ee_addr;
reg [15:0] ee_dout = 16'd0;

ws_bk dut (
	.clk(clk), .clk_ram(clk_ram), .sram(sram),
	.mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_din(mem_din),
	.mem_ack(mem_ack), .mem_dout(mem_dout),
	.sdr_addr(sdr_addr), .sdr_din(sdr_din), .sdr_req(sdr_req), .sdr_rnw(sdr_rnw),
	.sdr_dout(sdr_dout), .sdr_ready(sdr_ready),
	.ee_addr(ee_addr), .ee_din(ee_din), .ee_req(ee_req), .ee_rnw(ee_rnw), .ee_dout(ee_dout)
);

// the EEPROM block RAM, port b (eeprom.vhd: wren_b = req and not rnw)
reg [15:0] ee [0:1023];
always @(posedge clk_ram) begin
	if (ee_req && !ee_rnw) ee[ee_addr] <= ee_din;
	ee_dout <= ee[ee_addr];
end

// ch3: the CPU (EXTRAM)
reg [24:0] ext_addr = 25'd0;
reg [15:0] ext_wdata = 16'd0;
reg [1:0] ext_be = 2'b11;
reg ext_read = 1'b0, ext_write = 1'b0;
wire [15:0] ext_rdata;
wire ext_ready;

wire [15:0] dq;
wire [12:0] a;
wire [1:0] ba;
wire ras_n, cas_n, we_n, cs_n, dqml, dqmh;
wire [31:0] sdram_errors;
ws_sdram sdram (
	.init(init), .clk(clk_ram), .doRefresh(1'b0),
	.SDRAM_DQ(dq), .SDRAM_A(a), .SDRAM_DQML(dqml), .SDRAM_DQMH(dqmh), .SDRAM_BA(ba),
	.SDRAM_nCS(cs_n), .SDRAM_nWE(we_n), .SDRAM_nRAS(ras_n), .SDRAM_nCAS(cas_n),
	.ch1_addr(25'd0), .ch1_dout(), .ch1_din(16'd0), .ch1_req(1'b0), .ch1_rnw(1'b1), .ch1_ready(),
	.ch2_addr(sdr_addr), .ch2_dout(sdr_dout), .ch2_din(sdr_din), .ch2_req(sdr_req), .ch2_rnw(sdr_rnw),
	.ch2_ready(sdr_ready),
	.ch3_addr({ 1'b0, ext_addr[24:1] }), .ch3_dout(ext_rdata), .ch3_din(ext_wdata), .ch3_be(ext_be),
	.ch3_req(ext_read | ext_write), .ch3_rnw(ext_read), .ch3_ready(ext_ready)
);
sdram_model chip (
	.clk(clk_ram), .dq(dq), .a(a), .ba(ba), .cs_n(cs_n), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n),
	.dqml(dqml), .dqmh(dqmh), .errors(sdram_errors)
);

// a byte through the memory port, as kg_bk_ram: the request held until the ack
task mem(input we, input [18:0] ad, input [7:0] d, output [7:0] q);
	begin
		@(posedge clk); mem_req <= 1'b1; mem_we <= we; mem_addr <= ad; mem_din <= d;
		@(posedge clk); while (!mem_ack) @(posedge clk);
		q = mem_dout; mem_req <= 1'b0;
	end
endtask

// a word of the CPU through ch3: the request held until ready (clk_sys as SwanTop)
task ext(input wr, input [24:0] ad, input [15:0] d, output [15:0] q);
	begin
		@(posedge clk); ext_addr <= ad; ext_wdata <= d; ext_read <= !wr; ext_write <= wr;
		@(posedge clk); while (!ext_ready) @(posedge clk);
		q = ext_rdata; ext_read <= 1'b0; ext_write <= 1'b0;
		repeat (2) @(posedge clk);
	end
endtask

function [7:0] pat(input integer i);
	pat = i[7:0] ^ 8'h5A ^ { i[9:8], 6'd0 };
endfunction

integer i, bad;
reg [7:0] q;
reg [15:0] w;
initial begin
	repeat (20) @(posedge clk_ram);
	init = 1'b0;
	repeat (13000) @(posedge clk_ram);   // the SDRAM start (12100 clocks)

	// ---- SRAM: a sector at 0x1200 ----
	for (i = 0; i < 512; i = i + 1) mem(1'b1, 19'h1200 + i, pat(i), q);
	bad = 0;
	for (i = 0; i < 512; i = i + 1) begin
		mem(1'b0, 19'h1200 + i, 8'd0, q);
		if (q !== pat(i)) bad = bad + 1;
	end
	check("SRAM sector read back", bad, 0);
	ext(1'b0, 25'h1001200, 16'd0, w);
	check("ch3 sees the sector (word 0)", w, { pat(1), pat(0) });
	ext(1'b0, 25'h10013FE, 16'd0, w);
	check("ch3 sees the sector (last word)", w, { pat(511), pat(510) });
	ext(1'b1, 25'h1002468, 16'hC3A5, w);
	mem(1'b0, 19'h2468, 8'd0, q); check("CPU word, low byte", q, 8'hA5);
	mem(1'b0, 19'h2469, 8'd0, q); check("CPU word, high byte", q, 8'hC3);

	// ---- EEPROM: 1024 bytes ----
	sram = 1'b0;
	for (i = 0; i < 1024; i = i + 1) mem(1'b1, i, pat(i + 3), q);
	bad = 0;
	for (i = 0; i < 1024; i = i + 1) begin
		mem(1'b0, i, 8'd0, q);
		if (q !== pat(i + 3)) bad = bad + 1;
	end
	check("EEPROM read back", bad, 0);
	check("EEPROM word 5 in the RAM", ee[5], { pat(11 + 3), pat(10 + 3) });

	check("sdram model errors", sdram_errors, 0);
	$display("tb_bk: %0d errors", errors);
	$finish;
end

initial begin
	#20000000;
	$display("ERROR: timeout");
	$display("tb_bk: %0d errors", errors + 1);
	$finish;
end

endmodule
