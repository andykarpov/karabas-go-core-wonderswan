`default_nettype none
module Fifo (
	clk,
	reset,
	flush,
	wr_en,
	wr_data,
	rd_en,
	rd_data,
	empty,
	nearly_full,
	full
);
	input wire clk;
	input wire reset;
	input wire flush;
	input wire wr_en;
	parameter data_width = 32;
	input wire [data_width - 1:0] wr_data;
	input wire rd_en;
	output wire [data_width - 1:0] rd_data;
	output wire empty;
	output wire nearly_full;
	output wire full;
	parameter depth = 6;
	parameter full_threshold = 2;
	function integer kg_clog2;
		input integer v;
		integer n;
		begin
			kg_clog2 = 0;
			for (n = v - 1; n > 0; n = n >> 1)
				kg_clog2 = kg_clog2 + 1;
		end
	endfunction
	localparam ptr_bits = kg_clog2(depth);
	reg [data_width - 1:0] mem [depth - 1:0];
	reg [ptr_bits - 1:0] rd_ptr;
	reg [ptr_bits - 1:0] wr_ptr;
	reg [ptr_bits:0] count;
	assign empty = count == 0;
	assign full = count == depth;
	assign nearly_full = count >= (depth - full_threshold);
	assign rd_data = mem[rd_ptr];
	always @(posedge clk)
		if (reset)
			wr_ptr <= {ptr_bits {1'b0}};
		else if (flush)
			wr_ptr <= {ptr_bits {1'b0}};
		else if (wr_en && !full) begin
			mem[wr_ptr] <= wr_data;
			wr_ptr <= wr_ptr + 1'b1;
			if (wr_ptr == (depth[ptr_bits - 1:0] - 1'b1))
				wr_ptr <= {ptr_bits {1'b0}};
		end
	always @(posedge clk)
		if (reset)
			rd_ptr <= {ptr_bits {1'b0}};
		else if (flush)
			rd_ptr <= {ptr_bits {1'b0}};
		else if (rd_en && !empty) begin
			rd_ptr <= rd_ptr + 1'b1;
			if (rd_ptr == (depth[ptr_bits - 1:0] - 1'b1))
				rd_ptr <= {ptr_bits {1'b0}};
		end
	always @(posedge clk)
		if (reset)
			count <= {ptr_bits + 1 {1'b0}};
		else if (flush)
			count <= {ptr_bits + 1 {1'b0}};
		else if (((wr_en && !full) && rd_en) && !empty)
			;
		else if (wr_en && !full)
			count <= count + 1'b1;
		else if (rd_en && !empty)
			count <= count - 1'b1;
endmodule
