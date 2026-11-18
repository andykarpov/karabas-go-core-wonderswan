`default_nettype none
module Prefetch (
	clk,
	reset,
	new_cs,
	new_ip,
	load_new_ip,
	fifo_wr_en,
	fifo_wr_data,
	fifo_reset,
	fifo_full,
	mem_access,
	mem_ack,
	mem_address,
	mem_data
);
	input wire clk;
	input wire reset;
	input wire [15:0] new_cs;
	input wire [15:0] new_ip;
	input wire load_new_ip;
	output wire fifo_wr_en;
	output wire [7:0] fifo_wr_data;
	output wire fifo_reset;
	input wire fifo_full;
	output wire mem_access;
	input wire mem_ack;
	output reg [19:1] mem_address;
	input wire [15:0] mem_data;
	reg [15:0] next_fetch_address;
	reg [15:0] fetch_address;
	reg [15:0] next_cs;
	reg [15:0] cs;
	reg abort_cur;
	reg [7:0] fetched_high_byte;
	reg write_second;
	reg [15:0] next_sequential_fetch;
	wire should_write_second_byte = ((mem_ack && !abort_cur) && !fetch_address[0]) && !fifo_reset;
	wire [15:0] next_address = (mem_ack ? next_sequential_fetch : fetch_address);
	wire [19:1] _mem_address = {cs, 3'b000} + {4'b0000, next_address[15:1]};
	wire _mem_access = (((!reset && !fifo_full) && !mem_ack) && !write_second) && ~(~mem_access && load_new_ip);
	reg mem_access2;
	assign mem_access = mem_access2 & !mem_ack;
	always @(posedge clk) begin
		mem_address <= _mem_address;
		mem_access2 <= _mem_access;
	end
	assign fifo_wr_en = (!abort_cur && !load_new_ip) && (mem_ack || write_second);
	assign fifo_reset = load_new_ip | (abort_cur & mem_ack);
	assign fifo_wr_data = (mem_ack ? (fetch_address[0] ? mem_data[15:8] : mem_data[7:0]) : fetched_high_byte);
	always @(posedge clk)
		if (reset)
			abort_cur <= 1'b0;
		else if (abort_cur && mem_ack)
			abort_cur <= 1'b0;
		else if (mem_access && load_new_ip)
			abort_cur <= 1'b1;
	always @(posedge clk) write_second <= (reset ? 1'b0 : should_write_second_byte);
	always @(posedge clk)
		if (reset)
			cs <= 16'hffff;
		else if (abort_cur && mem_ack)
			cs <= next_cs;
		else if (load_new_ip && !mem_access)
			cs <= new_cs;
	always @(posedge clk)
		if (reset)
			next_cs <= 16'hffff;
		else if (load_new_ip)
			next_cs <= new_cs;
	always @(posedge clk)
		if (reset)
			fetch_address <= 16'b0000000000000000;
		else if (abort_cur && mem_ack)
			fetch_address <= next_fetch_address;
		else if (load_new_ip && !mem_access)
			fetch_address <= new_ip;
		else if ((!abort_cur && !load_new_ip) && (mem_ack || write_second))
			fetch_address <= fetch_address + 1'b1;
	always @(posedge clk)
		if (reset)
			next_fetch_address <= 16'b0000000000000000;
		else if (load_new_ip)
			next_fetch_address <= new_ip;
	always @(posedge clk)
		if (mem_ack)
			fetched_high_byte <= mem_data[15:8];
	always @(posedge clk) next_sequential_fetch <= fetch_address + 1'b1;
endmodule
