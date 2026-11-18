`default_nettype none
module Microcode (
	clk,
	reset,
	nmi_pulse,
	intr,
	inta,
	irq_to_mdr,
	start_interrupt,
	do_escape_fault,
	starting_instruction,
	stall,
	hold,
	at_dispatch,
	divide_error,
	rm_is_reg,
	modrm_reg,
	int_enabled,
	zf,
	tf,
	microcode_immediate,
	update_flags,
	modrm_start,
	use_microcode_immediate,
	opcode,
	jump_taken,
	rb_zero,
	lock,
	multibit_shift,
	is_hlt,
	next_microinstruction,
	a_sel,
	alu_op,
	b_sel,
	ext_int_yield,
	io,
	load_ip,
	mar_wr_sel,
	mar_write,
	mdr_write,
	mem_read,
	mem_write,
	next_instruction,
	ra_modrm_rm_reg,
	ra_sel,
	rb_cl,
	rd_sel,
	rd_sel_source,
	reg_wr_source,
	segment,
	segment_force,
	segment_wr_en,
	tmp_wr_en,
	tmp_wr_sel,
	width,
	reg_wr_en,
	fifo_rd_en,
	next_instruction_value,
	cur_instruction,
	fifo_empty,
	fifo_resetting,
	loop_next,
	loop_done,
	debug_stopped,
	debug_seize,
	debug_addr,
	debug_run
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire nmi_pulse;
	input wire intr;
	output reg inta;
	output wire irq_to_mdr;
	output wire start_interrupt;
	output wire do_escape_fault;
	output wire starting_instruction;
	input wire stall;
	input wire hold;
	output wire at_dispatch;
	input wire divide_error;
	input wire rm_is_reg;
	input wire [2:0] modrm_reg;
	input wire int_enabled;
	input wire zf;
	input wire tf;
	output reg [15:0] microcode_immediate;
	output reg [8:0] update_flags;
	output wire modrm_start;
	output wire use_microcode_immediate;
	output wire [7:0] opcode;
	input wire jump_taken;
	input wire rb_zero;
	output wire lock;
	output wire multibit_shift;
	output wire is_hlt;
	output wire next_microinstruction;
	output wire [1:0] a_sel;
	output wire [5:0] alu_op;
	output wire [2:0] b_sel;
	output wire ext_int_yield;
	output wire io;
	output wire load_ip;
	output wire mar_wr_sel;
	output wire mar_write;
	output wire mdr_write;
	output wire mem_read;
	output wire mem_write;
	output wire next_instruction;
	output wire ra_modrm_rm_reg;
	output wire [2:0] ra_sel;
	output wire rb_cl;
	output wire [2:0] rd_sel;
	output wire [1:0] rd_sel_source;
	output wire [1:0] reg_wr_source;
	output wire [1:0] segment;
	output wire segment_force;
	output wire segment_wr_en;
	output wire tmp_wr_en;
	output wire tmp_wr_sel;
	output reg width;
	output wire reg_wr_en;
	output wire fifo_rd_en;
	input wire [75:0] next_instruction_value;
	output reg [75:0] cur_instruction;
	input wire fifo_empty;
	input wire fifo_resetting;
	output wire loop_next;
	input wire loop_done;
	output wire debug_stopped;
	input wire debug_seize;
	input wire [7:0] debug_addr;
	input wire debug_run;
	localparam num_instructions = 1204;
	localparam addr_bits = 11;
	localparam reset_address = 11'h129;
	localparam nmi_address = 11'h12a;
	localparam irq_address = 11'h12b;
	localparam single_step_address = 11'h12c;
	localparam divide_error_address = 11'h101;
	localparam next_instruction_address = 11'h100;
	localparam modrm_wait_address = 11'h12e;
	localparam bad_opcode_address = 11'h12f;
	localparam debug_wait_address = 11'h102;
	localparam do_int_address = 11'h12d;
	reg [64:0] mem [0:1203];
	reg [64:0] current;
	reg [10:0] addr;
	reg [10:0] next_addr;
	reg [10:0] jump_target;
	assign use_microcode_immediate = |current[40-:4];
	assign opcode = cur_instruction[7-:8];
	always @(*) begin
		if (_sv2v_0)
			;
		case (current[40-:4])
			2: microcode_immediate = 16'h0000;
			1: microcode_immediate = 16'h000a;
			3: microcode_immediate = 16'h0018;
			4: microcode_immediate = 16'h0002;
			5: microcode_immediate = 16'h0014;
			6: microcode_immediate = 16'h0001;
			7: microcode_immediate = 16'hffff;
			8: microcode_immediate = 16'h000c;
			9: microcode_immediate = 16'h00ff;
			10: microcode_immediate = 16'h0004;
			11: microcode_immediate = 16'h0010;
			12: microcode_immediate = 16'h0008;
			default: microcode_immediate = 16'h0000;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (current[6-:5])
			0: update_flags = 9'h000;
			1: update_flags = 9'h005;
			2: update_flags = 9'h00a;
			3: update_flags = 9'h010;
			4: update_flags = 9'h11f;
			5: update_flags = 9'h001;
			6: update_flags = 9'h01f;
			7: update_flags = 9'h1ff;
			8: update_flags = 9'h008;
			9: update_flags = 9'h040;
			10: update_flags = 9'h080;
			11: update_flags = 9'h11e;
			12: update_flags = 9'h060;
			13: update_flags = 9'h109;
			14: update_flags = 9'h101;
			15: update_flags = 9'h11b;
			16: update_flags = 9'h01b;
			default: update_flags = 9'h000;
		endcase
	end
	assign a_sel = current[53-:2];
	assign alu_op = current[51-:6];
	assign b_sel = current[45-:3];
	assign ext_int_yield = current[41];
	assign io = current[36];
	assign load_ip = current[31];
	assign mar_wr_sel = current[30];
	assign mar_write = current[29];
	assign mdr_write = current[28];
	assign mem_read = current[27];
	assign mem_write = current[26];
	assign next_instruction = current[25];
	assign ra_modrm_rm_reg = current[24];
	assign ra_sel = current[23-:3];
	assign rb_cl = current[20];
	assign rd_sel = current[19-:3];
	assign rd_sel_source = current[16-:2];
	assign reg_wr_source = current[14-:2];
	assign segment = current[12-:2];
	assign segment_force = current[10];
	assign segment_wr_en = current[9];
	assign tmp_wr_en = current[8];
	assign tmp_wr_sel = current[7];
	assign fifo_rd_en = starting_instruction;
	assign at_dispatch = addr == next_instruction_address;
	assign starting_instruction = !stall && (next_addr == {{3 {1'b0}}, next_instruction_value[7-:8]});
	assign modrm_start = (addr == modrm_wait_address) || ((((addr == next_instruction_address) && !fifo_empty) && !hold) && next_instruction_value[64]);
	wire has_rep_prefix = cur_instruction[69-:2] != 2'd0;
	reg rep_complete;
	assign debug_stopped = addr == debug_wait_address;
	assign multibit_shift = (((cur_instruction[7-:8] == 8'hd2) || (cur_instruction[7-:8] == 8'hd3)) || (cur_instruction[7-:8] == 8'hc0)) || (cur_instruction[7-:8] == 8'hc1);
	assign do_escape_fault = (cur_instruction[7:3] == 5'b11011) && (next_addr == do_int_address);
	reg nmi_pending;
	reg ext_int_inhibit;
	wire take_nmi = ((nmi_pending | nmi_pulse) & !ext_int_inhibit) & !current[42];
	wire take_irq = ((intr & int_enabled) & !ext_int_inhibit) & !current[42];
	reg trap_flag_set;
	wire do_single_step = (((current[25] & !ext_int_inhibit) & trap_flag_set) & (current[64-:11] != debug_wait_address)) & !current[42];
	assign start_interrupt = (next_addr == nmi_address) || (next_addr == irq_address);
	assign irq_to_mdr = next_addr == irq_address;
	assign is_hlt = cur_instruction[7-:8] == 8'hf4;
	reg seized;
	wire seizing = debug_seize & ~seized;
	assign loop_next = !stall && (current[35-:4] == 4'd9);
	assign reg_wr_en = (current[16-:2] != 2'd0) & ~segment_wr_en;
	assign next_microinstruction = addr != next_addr;
	assign lock = cur_instruction[70];
	always @(*) begin
		if (_sv2v_0)
			;
		case (current[1-:2])
			2'd1: width = 1'b1;
			2'd0: width = 1'b0;
			2'd2: width = ~cur_instruction[0];
			default: width = 1'b0;
		endcase
	end
	always @(posedge clk) inta <= (next_addr == irq_address) && (addr != irq_address);
	always @(posedge clk)
		if (reset)
			trap_flag_set <= 1'b0;
		else if (next_addr == single_step_address)
			trap_flag_set <= 1'b0;
		else if (starting_instruction)
			trap_flag_set <= tf;
	always @(posedge clk)
		if (reset)
			ext_int_inhibit <= 1'b0;
		else if (current[42] && (current[64-:11] != debug_wait_address))
			ext_int_inhibit <= 1'b1;
		else if (starting_instruction && !stall)
			ext_int_inhibit <= 1'b0;
	initial $readmemb({"rtl/s80x86/gen", "/microcode.bin"}, mem);
	always @(*) begin
		if (_sv2v_0)
			;
		case (cur_instruction[69-:2])
			2'd1: rep_complete = ~zf;
			2'd2: rep_complete = zf;
			default: rep_complete = 1'b0;
		endcase
	end
	always @(posedge clk)
		if (reset)
			nmi_pending <= 1'b0;
		else if (next_addr == nmi_address)
			nmi_pending <= 1'b0;
		else if (nmi_pulse)
			nmi_pending <= 1'b1;
	always @(posedge clk)
		if (reset)
			seized <= 1'b0;
		else if (debug_stopped)
			seized <= 1'b1;
		else if (!debug_seize)
			seized <= 1'b0;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (current[35-:4])
			4'd1: jump_target = current[64-:11] + {{10 {1'b0}}, ~rm_is_reg};
			4'd2: jump_target = (!fifo_empty && !hold ? {{3 {1'b0}}, next_instruction_value[7-:8]} : addr);
			4'd3: jump_target = current[64-:11] + {{8 {1'b0}}, modrm_reg};
			4'd4: jump_target = (~has_rep_prefix ? current[64-:11] : addr + 1'b1);
			4'd5: jump_target = (zf ? current[64-:11] : addr + 1'b1);
			4'd6: jump_target = (!rep_complete ? current[64-:11] : addr + 1'b1);
			4'd8: jump_target = (rb_zero ? current[64-:11] : addr + 1'b1);
			4'd9: jump_target = (loop_done ? current[64-:11] : addr + 1'b1);
			4'd7: jump_target = (jump_taken ? current[64-:11] : addr + 1'b1);
			default: jump_target = current[64-:11];
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (reset)
			next_addr = reset_address;
		else if (debug_stopped && debug_run)
			next_addr = {{2 {1'b0}}, 1'b1, debug_addr};
		else if (stall)
			next_addr = addr;
		else if (current[41] && seizing)
			next_addr = debug_wait_address;
		else if (current[41] && take_nmi)
			next_addr = nmi_address;
		else if (current[41] && take_irq)
			next_addr = irq_address;
		else if (((((addr == next_instruction_address) && !fifo_empty) && !fifo_resetting) && !hold) && next_instruction_value[75])
			next_addr = bad_opcode_address;
		else if (current[35-:4] != 4'd0)
			next_addr = jump_target;
		else if (divide_error)
			next_addr = divide_error_address;
		else if (current[25] && take_nmi)
			next_addr = nmi_address;
		else if (current[25] && take_irq)
			next_addr = irq_address;
		else if ((current[25] && do_single_step) || (is_hlt && trap_flag_set))
			next_addr = single_step_address;
		else if (current[25] && debug_seize)
			next_addr = debug_wait_address;
		else if ((current[25] || (is_hlt && intr)) && hold)
			next_addr = next_instruction_address;
		else if (current[25] || (is_hlt && intr))
			next_addr = (!fifo_empty && !fifo_resetting ? (next_instruction_value[64] ? modrm_wait_address : {{3 {1'b0}}, next_instruction_value[7-:8]}) : next_instruction_address);
		else
			next_addr = current[64-:11];
	end
	always @(posedge clk) addr <= next_addr;
	always @(posedge clk) current <= mem[next_addr];
	always @(posedge clk)
		if (fifo_rd_en)
			cur_instruction <= next_instruction_value;
	initial _sv2v_0 = 0;
endmodule
