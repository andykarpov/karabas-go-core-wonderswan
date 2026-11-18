`timescale 1ps / 1ps
`default_nettype wire

/*
 tb_post.v - iverilog run of sim_top.v with ws_core as the XST netlist (sim/post/build.sh): does the
 synthesised machine start like the ghdl one? Only the last 16 bytes of the ROM go through the loader
 (the header and the reset vector at FFFF:0000 = the last 16 bytes; mask_addr comes out right), the
 rest of the SDRAM is empty: enough to see the boot stub run and the first cartridge reads.

 usage: tb_post +rom=FILE [+cycles=N] [+system=0|1|2]
 Prints every cartridge read (address, data 3 clk_sys later) up to 40, the frames, the end state.
*/

module tb_post;

reg clk_sys = 0, clk_ram = 0;
always #4520 clk_ram = ~clk_ram;      // 110.6 MHz
initial forever begin                 // 36.86 MHz, the rising edges with every third of clk_ram
	clk_sys = 1; #13560; clk_sys = 0; #13560;
end

reg init = 1, file_active = 0, file_wr = 0;
reg [31:0] file_addr = 0;
reg [7:0] file_data = 0;
reg [1:0] sw_system = 0;

wire pixel_we, vertical, cart_ready, hdr_color, ext_read;
wire [14:0] pixel_addr;
wire [11:0] pixel_data;
wire [15:0] snd_l, snd_r, ext_rdata;
wire [31:0] sdram_errors;
wire [24:0] ext_addr;

sim_top top (
	.clk_sys(clk_sys), .clk_ram(clk_ram), .init(init),
	.file_active(file_active), .file_wr(file_wr), .file_addr(file_addr), .file_data(file_data),
	.sw_system(sw_system), .keys(11'd0),
	.pixel_we(pixel_we), .pixel_addr(pixel_addr), .pixel_data(pixel_data), .vertical(vertical),
	.snd_l(snd_l), .snd_r(snd_r), .cart_ready(cart_ready), .hdr_color(hdr_color),
	.sdram_errors(sdram_errors), .ext_read(ext_read), .ext_addr(ext_addr), .ext_rdata(ext_rdata)
);

reg [7:0] rom [0:(1 << 24) - 1];
integer size, fd, i, cycles, n_rd, frames, pend, last_we;
reg [24:0] pend_a;
reg prev_rd;
reg [1023:0] name;

initial begin
	if (!$value$plusargs("rom=%s", name)) begin $display("+rom= missing"); $finish; end
	if (!$value$plusargs("cycles=%d", cycles)) cycles = 20000;
	if (!$value$plusargs("system=%d", i)) i = 0;
	sw_system = i;
	fd = $fopen(name, "rb");
	if (fd == 0) begin $display("cannot open the rom"); $finish; end
	size = $fread(rom, fd);
	$fclose(fd);
	$display("rom %0d bytes", size);
	repeat (64) @(negedge clk_sys);
	init = 0;
	repeat (4200) @(negedge clk_sys);
	file_active = 1;
	for (i = size - 16; i < size; i = i + 1) begin
		repeat (8) @(negedge clk_sys);
		file_addr = i; file_data = rom[i]; file_wr = 1;
		@(negedge clk_sys);
		file_wr = 0;
	end
	repeat (16) @(negedge clk_sys);
	file_active = 0;
	repeat (4) @(negedge clk_sys);
	$display("loaded: cart_ready %b colour %b mask %06x", cart_ready, hdr_color, top.mask_addr);
	n_rd = 0; frames = 0; pend = 0; prev_rd = 0; last_we = 0;
	for (i = 0; i < cycles; i = i + 1) begin
		@(negedge clk_sys);
		if (pend > 0) begin
			pend = pend - 1;
`ifndef S80
			if (pend == 0) $display("  read %06x -> %04x", pend_a, ext_rdata);
`else
			if (pend == 0) pend = 1;   // the s80x86 waits for the SDRAM: the data at its ready
			if (top.ext_ready) begin $display("  read %06x -> %04x", pend_a, ext_rdata); pend = 0; end
`endif
		end
		if (ext_read && !prev_rd) begin
			n_rd = n_rd + 1;
			if (n_rd <= 40) begin pend_a = ext_addr; pend = 3; end
		end
		prev_rd = ext_read;
		if (pixel_we) last_we = i;
		if (pixel_we && pixel_addr == 15'd32255) begin
			frames = frames + 1;
			$display("frame %0d at cycle %0d", frames, i);
		end
		if (i % 5000 == 0) $display("cycle %0d: reset %b, %0d reads, pixel_we last %0d", i, top.ws_reset, n_rd, last_we);
	end
	$display("end: %0d cartridge reads, %0d frames, sdram errors %0d", n_rd, frames, sdram_errors);
	$finish;
end

// the CPU bus of the netlist (sim/post/taps.py): the first accesses after the reset (V30MZ only)
`ifndef S80
`ifdef GHDL
// the same through the ghdl Verilog (sim/build/ws_core_ghdl.v, the reference)
`define CPU top.ws.iswantop.gcpu_v30_icpu
wire [19:0] cpu_addr = `CPU.bus_addr;
wire cpu_rd = `CPU.bus_read;
wire cpu_wr = `CPU.bus_write;
wire [15:0] tap_ip = `CPU.cpu_export_reg_ip, tap_cs = `CPU.cpu_export_reg_cs;
wire [4:0] tap_opcode = `CPU.opcode, tap_delay = 0, tap_stage = `CPU.cpustage;
wire [1:0] tap_opstep = `CPU.opstep;
wire [3:0] tap_pfcount = 0;
wire tap_halt = 0;
`else
wire [19:0] cpu_addr = top.ws.tap_cpu_addr;
wire cpu_rd = top.ws.tap_cpu_rd;
wire cpu_wr = top.ws.tap_cpu_wr;
// cpustage: one-hot of XST (the .syr table), FFd19 = bit 0 -> the index of tCPUSTAGE
wire [18:0] oh = { top.ws.tap_stage[1], top.ws.tap_stage[2], top.ws.tap_stage[3], top.ws.tap_stage[4], top.ws.tap_stage[5],
	top.ws.tap_stage[6], top.ws.tap_stage[7], top.ws.tap_stage[8], top.ws.tap_stage[9], top.ws.tap_stage[10], top.ws.tap_stage[11],
	top.ws.tap_stage[12], top.ws.tap_stage[13], top.ws.tap_stage[14], top.ws.tap_stage[15], top.ws.tap_stage[16], top.ws.tap_stage[17],
	top.ws.tap_stage[18], top.ws.tap_stage[19] };
reg [4:0] tap_stage;
always @* case (1'b1)
	oh[0]: tap_stage = 0;  oh[1]: tap_stage = 1;  oh[3]: tap_stage = 2;  oh[6]: tap_stage = 3;
	oh[9]: tap_stage = 4;  oh[10]: tap_stage = 5; oh[4]: tap_stage = 6;  oh[5]: tap_stage = 7;
	oh[12]: tap_stage = 8; oh[13]: tap_stage = 9; oh[14]: tap_stage = 10; oh[2]: tap_stage = 11;
	oh[15]: tap_stage = 12; oh[16]: tap_stage = 13; oh[8]: tap_stage = 14; oh[11]: tap_stage = 15;
	oh[17]: tap_stage = 16; oh[18]: tap_stage = 17; oh[7]: tap_stage = 18; default: tap_stage = 31;
endcase
// opstep: gray of XST (00 01 11 10 = 0 1 2 3)
wire [1:0] tap_opstep = top.ws.tap_opstep == 2'b11 ? 2'd2 : top.ws.tap_opstep == 2'b10 ? 2'd3 : top.ws.tap_opstep;
wire [15:0] tap_ip = top.ws.tap_ip, tap_cs = top.ws.tap_cs;
wire [4:0] tap_opcode = top.ws.tap_opcode, tap_delay = top.ws.tap_delay;
wire [3:0] tap_pfcount = top.ws.tap_pfcount;
wire tap_halt = top.ws.tap_halt;
`endif
reg cpu_wr_d = 0;
reg cpu_rd_d = 0;
integer n_cpu = 0;
always @(negedge clk_sys) begin
	cpu_rd_d <= cpu_rd;
	cpu_wr_d <= cpu_wr;
	if (!top.ws_reset && cpu_wr && !cpu_wr_d && n_cpu <= 60) $display("  cpu write %05x (cycle %0d)", cpu_addr, i);
	if (!top.ws_reset && cpu_rd && !cpu_rd_d) begin
		n_cpu = n_cpu + 1;
		if (n_cpu <= 60) $display("  cpu read %05x (cycle %0d)", cpu_addr, i);
	end
end

// the CPU state on every change (up to 120 lines)
reg [63:0] st_d = 0;
integer n_st = 0;
wire [63:0] st = { tap_ip, tap_cs, tap_stage, tap_opstep, tap_opcode, tap_pfcount };
always @(negedge clk_sys) if (!top.ws_reset && st != st_d && n_st < 120) begin
	st_d <= st;
	n_st = n_st + 1;
	$display("  cs:ip %04x:%04x stage %0d opstep %0d opcode %0d delay %0d pf %0d (cycle %0d)", tap_cs, tap_ip,
		tap_stage, tap_opstep, tap_opcode, tap_delay, tap_pfcount, i);
end

`endif

endmodule
