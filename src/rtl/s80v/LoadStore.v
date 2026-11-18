`default_nettype none
module LoadStore (
	clk,
	reset,
	write_mar,
	segment,
	mar_in,
	mar_out,
	mdr_out,
	write_mdr,
	mdr_in,
	m_addr,
	m_data_in,
	m_data_out,
	m_access,
	m_ack,
	m_wr_en,
	m_bytesel,
	io,
	start,
	is_8bit,
	wr_en,
	busy,
	complete
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire write_mar;
	input wire [15:0] segment;
	input [15:0] mar_in;
	output wire [15:0] mar_out;
	output wire [15:0] mdr_out;
	input wire write_mdr;
	input [15:0] mdr_in;
	output wire [19:1] m_addr;
	input wire [15:0] m_data_in;
	output reg [15:0] m_data_out;
	output wire m_access;
	input wire m_ack;
	output wire m_wr_en;
	output reg [1:0] m_bytesel;
	input wire io;
	input wire start;
	input wire is_8bit;
	input wire wr_en;
	output wire busy;
	output reg complete;
	reg [15:0] mar;
	reg [15:0] mdr;
	reg fetching;
	reg second_byte;
	assign busy = ((start | fetching) | second_byte) & ~complete;
	assign m_access = (((start | fetching) | second_byte) & ~complete) & ~m_ack;
	assign m_addr = (!io ? ({segment, 3'b000} + {3'b000, mar[15:1]}) + {18'b000000000000000000, second_byte} : {3'b000, mar[15:1]} + {18'b000000000000000000, second_byte});
	assign m_wr_en = wr_en;
	assign mdr_out = mdr;
	assign mar_out = mar;
	wire unaligned = mar[0];
	always @(*) begin
		if (_sv2v_0)
			;
		if (unaligned && !second_byte)
			m_data_out = {mdr[7:0], 8'b00000000};
		else if (unaligned && second_byte)
			m_data_out = {8'b00000000, mdr[15:8]};
		else
			m_data_out = mdr;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (!is_8bit && !unaligned)
			m_bytesel = 2'b11;
		else if (unaligned && !second_byte)
			m_bytesel = 2'b10;
		else
			m_bytesel = 2'b01;
	end
	always @(posedge clk)
		if (reset)
			fetching <= 1'b0;
		else
			fetching <= (start ? 1'b1 : (complete ? 1'b0 : fetching));
	always @(posedge clk)
		if (reset)
			mar <= 16'b0000000000000000;
		else
			mar <= (write_mar ? mar_in : mar);
	always @(posedge clk) complete <= m_ack && ((is_8bit || (unaligned && second_byte)) || !unaligned);
	always @(posedge clk)
		if (reset)
			second_byte <= 1'b0;
		else if (((m_ack && unaligned) && !second_byte) && !is_8bit)
			second_byte <= 1'b1;
		else if ((start && !fetching) || complete)
			second_byte <= 1'b0;
	always @(posedge clk)
		if (reset)
			mdr <= 16'b0000000000000000;
		else if ((start && !fetching) && !wr_en)
			mdr <= 16'b0000000000000000;
		else if (write_mdr)
			mdr <= mdr_in;
		else if ((!wr_en && m_ack) && !unaligned)
			mdr <= (is_8bit ? {8'b00000000, m_data_in[7:0]} : m_data_in);
		else if (((!wr_en && m_ack) && unaligned) && !second_byte)
			mdr[7:0] <= (unaligned ? m_data_in[15:8] : m_data_in[7:0]);
		else if (((!wr_en && m_ack) && unaligned) && second_byte)
			mdr[15:8] <= (unaligned ? m_data_in[7:0] : m_data_in[15:8]);
	initial _sv2v_0 = 0;
endmodule
