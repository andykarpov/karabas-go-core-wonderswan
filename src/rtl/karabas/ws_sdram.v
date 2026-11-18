`timescale 1ns / 1ps
`default_nettype wire
/*
 ws_sdram.v

 The SDRAM controller of the MiSTer WonderSwan core (rtl/sdram.sv, Robert Peip, GPL), in
 Verilog-2001 for XST with the same states and timing: SwanTop counts on its fixed latency (it has no
 ready input, its clock state machine leaves the CPU its cycles), so nothing in the order of the
 commands is changed.

 32 MB, one chip (13 rows, 9 columns, 4 banks, 16 bits; nCS always 0), CAS latency 3 at 110.592 MHz
 (clk = clk_ram = 3 x clk_sys), single accesses with auto precharge (A10 of the column address), the
 byte masks on A12 / A11 of the column cycle. Address = word address [25:1]: bank [24:23],
 row [22:10], column [9:1].

 Three channels, each started by the rising edge of its req (taken in clk), priority 1 > 2 > 3:
   ch1  the loader (ROM words, and the save file later);  ch2  the save RAM (Ф2);
   ch3  SwanTop EXTRAM (ROM / cartridge SRAM; byte enables on writes).
 Refresh: doRefresh of SwanTop when idle, or an emergency refresh after 500 clocks without one.

 Board: the outputs are registered (into the IOBs by map -pr b); SDRAM_CLK is made by the top (an
 ODDR2 on clk, inverted as altddio_out of MiSTer: datain_h 0, datain_l 1).
*/
module ws_sdram (
	input  wire        init,
	input  wire        clk,
	input  wire        doRefresh,

	inout  wire [15:0] SDRAM_DQ,
	output reg  [12:0] SDRAM_A = 13'd0,
	output wire        SDRAM_DQML,
	output wire        SDRAM_DQMH,
	output reg  [1:0]  SDRAM_BA = 2'd0,
	output wire        SDRAM_nCS,
	output wire        SDRAM_nWE,
	output wire        SDRAM_nRAS,
	output wire        SDRAM_nCAS,

	input  wire [25:1] ch1_addr,
	output reg  [15:0] ch1_dout = 16'd0,
	input  wire [15:0] ch1_din,
	input  wire        ch1_req,
	input  wire        ch1_rnw,
	output reg         ch1_ready = 1'b0,

	input  wire [25:1] ch2_addr,
	output reg  [15:0] ch2_dout = 16'd0,
	input  wire [15:0] ch2_din,
	input  wire        ch2_req,
	input  wire        ch2_rnw,
	output reg         ch2_ready = 1'b0,

	input  wire [25:1] ch3_addr,
	output reg  [15:0] ch3_dout = 16'd0,
	input  wire [15:0] ch3_din,
	input  wire [1:0]  ch3_be,
	input  wire        ch3_req,
	input  wire        ch3_rnw,
	output wire        ch3_ready
);

localparam CAS_LATENCY = 3;

// karabas: ch3_ready for the s80x86 CPU (cpu_s80 waits for EXTRAM_ready; the V30MZ does not use it).
// The controller makes a one-clk pulse; its reader runs on clk_sys = clk / 3 (rising edges together)
// and saw it once in three: the CPU hung on its first cartridge read. Held 3 clocks it is seen by
// exactly one clk_sys edge (ch3_dout keeps its value until the next ch3 read).
reg ch3_rdy_p = 1'b0;
reg [1:0] ch3_rdy_n = 2'd0;
always @(posedge clk)
	if (ch3_rdy_p) ch3_rdy_n <= 2'd3;
	else if (ch3_rdy_n != 2'd0) ch3_rdy_n <= ch3_rdy_n - 2'd1;
assign ch3_ready = ch3_rdy_n != 2'd0;
localparam BURST_LENGTH = 1;
localparam [12:0] MODE = { 3'b000, 1'b1, 2'b00, 3'd3, 1'b0, 3'b000 }; // single write, CL3, sequential, BL1
localparam [13:0] sdram_startup_cycles = 14'd12100;
localparam [13:0] cycles_per_refresh = 14'd500;
localparam [13:0] startup_refresh_max = 14'b11111111111111;

localparam [2:0] CMD_NOP = 3'b111, CMD_ACTIVE = 3'b011, CMD_READ = 3'b101, CMD_WRITE = 3'b100,
	CMD_PRECHARGE = 3'b010, CMD_AUTO_REFRESH = 3'b001, CMD_LOAD_MODE = 3'b000;

localparam [3:0] STATE_STARTUP = 4'd0, STATE_WAIT = 4'd1, STATE_RW1 = 4'd2, STATE_IDLE = 4'd4,
	STATE_IDLE_1 = 4'd5, STATE_IDLE_2 = 4'd6, STATE_IDLE_3 = 4'd7, STATE_IDLE_4 = 4'd8,
	STATE_IDLE_5 = 4'd9, STATE_RFSH = 4'd10;

reg [13:0] refresh_count = startup_refresh_max - sdram_startup_cycles;
reg [2:0]  command = CMD_NOP;

assign SDRAM_nCS = 1'b0;
assign SDRAM_nRAS = command[2];
assign SDRAM_nCAS = command[1];
assign SDRAM_nWE = command[0];
assign { SDRAM_DQMH, SDRAM_DQML } = SDRAM_A[12:11];

reg [15:0] dq_out = 16'd0;
reg        dq_oe = 1'b0;
assign SDRAM_DQ = dq_oe ? dq_out : 16'bzzzzzzzzzzzzzzzz;

localparam DRW = CAS_LATENCY + BURST_LENGTH + 2;   // [CAS_LATENCY+BURST_LENGTH+1:0] of the original
reg [DRW-1:0] data_ready_delay1 = 0, data_ready_delay2 = 0, data_ready_delay3 = 0;
reg        saved_wr = 1'b0;
reg [12:0] cas_addr = 13'd0;
reg [15:0] saved_data = 16'd0;
reg [15:0] dq_reg = 16'd0;
reg [3:0]  state = STATE_STARTUP;
reg        ch1_req_1 = 1'b0, ch2_req_1 = 1'b0, ch3_req_1 = 1'b0;
reg        ch1_rq = 1'b0, ch2_rq = 1'b0, ch3_rq = 1'b0;
reg [1:0]  ch = 2'd0;
reg        ch3_rnw_1 = 1'b1;
reg [25:1] ch3_addr_1 = 25'd0;
reg [15:0] ch3_din_1 = 16'd0;
reg [1:0]  ch3_be_1 = 2'b00;
reg        doRefresh_1 = 1'b0;

always @(posedge clk) begin
	ch1_req_1 <= ch1_req;
	ch2_req_1 <= ch2_req;
	ch3_req_1 <= ch3_req;
	// karabas: the ch3 request is latched at its rising edge (the original copies it every clock and
	// uses the copy of the clock before IDLE: right when IDLE takes it at once, as the fixed slots of
	// the V30MZ do; the s80x86 starts its accesses on any clock, a request that came while the
	// controller was busy was taken after the 1-clk_sys pulse had ended: rnw 0 = a WRITE of garbage)
	if (ch3_req & ~ch3_req_1) begin
		ch3_rnw_1 <= ch3_rnw;
		ch3_addr_1 <= ch3_addr;
		ch3_din_1 <= ch3_din;
		ch3_be_1 <= ch3_be;
	end
	doRefresh_1 <= doRefresh;

	if (ch1_req & ~ch1_req_1) ch1_rq <= 1'b1;
	if (ch2_req & ~ch2_req_1) ch2_rq <= 1'b1;
	if (ch3_req & ~ch3_req_1) ch3_rq <= 1'b1;

	ch1_ready <= 1'b0;
	ch2_ready <= 1'b0;
	ch3_rdy_p <= 1'b0;

	refresh_count <= refresh_count + 1'b1;

	data_ready_delay1 <= data_ready_delay1 >> 1;
	data_ready_delay2 <= data_ready_delay2 >> 1;
	data_ready_delay3 <= data_ready_delay3 >> 1;

	dq_reg <= SDRAM_DQ;

	if (data_ready_delay1[1]) begin ch1_dout <= dq_reg; ch1_ready <= 1'b1; end
	if (data_ready_delay2[1]) begin ch2_dout <= dq_reg; ch2_ready <= 1'b1; end
	if (data_ready_delay3[1]) begin ch3_dout <= dq_reg; ch3_rdy_p <= 1'b1; end

	dq_oe <= 1'b0;
	command <= CMD_NOP;
	case (state)
	STATE_STARTUP: begin
		SDRAM_A <= 13'd0;
		SDRAM_BA <= 2'd0;
		// the original initialises two chips one after the other (chip = 0, then 1): here the one chip twice
		if (refresh_count == startup_refresh_max - 14'd63 || refresh_count == startup_refresh_max - 14'd31) begin
			command <= CMD_PRECHARGE;
			SDRAM_A[10] <= 1'b1;   // all banks
			SDRAM_BA <= 2'b00;
		end
		if (refresh_count == startup_refresh_max - 14'd55 || refresh_count == startup_refresh_max - 14'd23)
			command <= CMD_AUTO_REFRESH;
		if (refresh_count == startup_refresh_max - 14'd47 || refresh_count == startup_refresh_max - 14'd15)
			command <= CMD_AUTO_REFRESH;
		if (refresh_count == startup_refresh_max - 14'd39 || refresh_count == startup_refresh_max - 14'd7) begin
			command <= CMD_LOAD_MODE;
			SDRAM_A <= MODE;
		end
		if (refresh_count == 14'd0) begin
			state <= STATE_IDLE;
			refresh_count <= 14'd0;
		end
	end

	STATE_IDLE_5: state <= STATE_IDLE_4;
	STATE_IDLE_4: state <= STATE_IDLE_3;
	STATE_IDLE_3: state <= STATE_IDLE_2;
	STATE_IDLE_2: state <= STATE_IDLE_1;
	STATE_IDLE_1: state <= STATE_IDLE;

	STATE_RFSH: begin
		// the original refreshes its second chip here (chip = 1); one chip: no second command (a second
		// AUTO REFRESH one clock after the first would break tRC), the same 6 idle clocks after it
		state <= STATE_IDLE_5;
	end

	STATE_IDLE: begin
		if (refresh_count > cycles_per_refresh) begin
			// emergency refresh, mainly while a ROM loads or the core is held
			state <= STATE_RFSH;
			command <= CMD_AUTO_REFRESH;
			refresh_count <= refresh_count - cycles_per_refresh + 14'd1;
		end
		else if (ch1_rq) begin
			{ cas_addr[12:9], SDRAM_BA, SDRAM_A, cas_addr[8:0] } <= { 3'b001, ch1_addr[25:1] };
			saved_data <= ch1_din;
			saved_wr <= ~ch1_rnw;
			ch <= 2'd0;
			ch1_rq <= 1'b0;
			command <= CMD_ACTIVE;
			state <= STATE_WAIT;
		end
		else if (ch2_rq) begin
			{ cas_addr[12:9], SDRAM_BA, SDRAM_A, cas_addr[8:0] } <= { 3'b001, ch2_addr[25:1] };
			saved_data <= ch2_din;
			saved_wr <= ~ch2_rnw;
			ch <= 2'd1;
			ch2_rq <= 1'b0;
			command <= CMD_ACTIVE;
			state <= STATE_WAIT;
		end
		else if (ch3_rq) begin
			saved_data <= ch3_din_1;
			saved_wr <= ~ch3_rnw_1;
			ch <= 2'd2;
			ch3_rq <= 1'b0;
			if (ch3_rnw_1)
				{ cas_addr[12:9], SDRAM_BA, SDRAM_A, cas_addr[8:0] } <= { 3'b001, ch3_addr_1[25:1] };
			else
				{ cas_addr[12:9], SDRAM_BA, SDRAM_A, cas_addr[8:0] } <= { ~ch3_be_1, 1'b1, ch3_addr_1[25:1] };
			command <= CMD_ACTIVE;
			state <= STATE_WAIT;
		end
		else if (doRefresh_1) begin
			state <= STATE_RFSH;
			command <= CMD_AUTO_REFRESH;
			refresh_count <= 14'd0;
		end
	end

	STATE_WAIT: state <= STATE_RW1;

	STATE_RW1: begin
		SDRAM_A <= cas_addr;
		if (saved_wr) begin
			command <= CMD_WRITE;
			dq_out <= saved_data;
			dq_oe <= 1'b1;
			if (ch == 2'd0) ch1_ready <= 1'b1;
			if (ch == 2'd1) ch2_ready <= 1'b1;
			if (ch == 2'd2) ch3_rdy_p <= 1'b1;
			state <= STATE_IDLE_2;
		end
		else begin
			command <= CMD_READ;
			state <= STATE_IDLE_5;
			if (ch == 2'd0) data_ready_delay1[DRW-1] <= 1'b1;
			else if (ch == 2'd1) data_ready_delay2[DRW-1] <= 1'b1;
			else data_ready_delay3[DRW-1] <= 1'b1;
		end
	end

	default: state <= STATE_IDLE;
	endcase

	if (init) begin
		state <= STATE_STARTUP;
		refresh_count <= startup_refresh_max - sdram_startup_cycles;
	end
end

endmodule
