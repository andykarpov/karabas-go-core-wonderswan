`default_nettype none
module RegisterFile (
	clk,
	reset,
	is_8_bit,
	si,
	di,
	bp,
	bx,
	rd_sel,
	rd_val,
	wr_sel,
	wr_val,
	wr_en
);
	input wire clk;
	input wire reset;
	input wire is_8_bit;
	output reg [15:0] si;
	output reg [15:0] di;
	output reg [15:0] bp;
	output reg [15:0] bx;
	input wire [5:0] rd_sel;
	output reg [31:0] rd_val;
	input wire [2:0] wr_sel;
	input wire [15:0] wr_val;
	input wire wr_en;
	reg [15:0] gprs [0:7];
	wire wr_sel_low_byte = ~wr_sel[2];
	wire [2:0] wr_8_bit_sel = {1'b0, wr_sel[1:0]};
	always @(posedge reset)
		;
	always @(posedge clk)
		if (wr_en) begin
			if (is_8_bit) begin
				if (wr_sel_low_byte)
					gprs[wr_8_bit_sel][7:0] <= wr_val[7:0];
				else
					gprs[wr_8_bit_sel][15:8] <= wr_val[7:0];
			end
			else
				gprs[wr_sel] <= wr_val;
		end
	always @(posedge clk) begin
		si <= ((wr_en && !is_8_bit) && (wr_sel == 3'd6) ? wr_val : gprs[3'd6]);
		di <= ((wr_en && !is_8_bit) && (wr_sel == 3'd7) ? wr_val : gprs[3'd7]);
		bp <= ((wr_en && !is_8_bit) && (wr_sel == 3'd5) ? wr_val : gprs[3'd5]);
		bx <= gprs[3'd3];
		if ((wr_en && !is_8_bit) && (wr_sel == 3'd3))
			bx <= wr_val;
		if ((wr_en && is_8_bit) && (wr_sel == 3'd3))
			bx <= {gprs[3'd3][15:8], wr_val[7:0]};
		if ((wr_en && is_8_bit) && (wr_sel == 3'd7))
			bx <= {wr_val[7:0], gprs[3'd3][7:0]};
	end
	genvar _gv_rd_port_1;
	generate
		for (_gv_rd_port_1 = 0; _gv_rd_port_1 < 2; _gv_rd_port_1 = _gv_rd_port_1 + 1) begin : read_port
			localparam rd_port = _gv_rd_port_1;
			wire rd_sel_low_byte = ~rd_sel[((1 - rd_port) * 3) + 2];
			wire [2:0] rd_8_bit_sel = {1'b0, rd_sel[((1 - rd_port) * 3) + 1-:2]};
			wire bypass = wr_en && (wr_sel == rd_sel[(1 - rd_port) * 3+:3]);
			always @(posedge clk)
				if (is_8_bit)
					rd_val[(1 - rd_port) * 16+:16] <= (bypass ? {8'b00000000, wr_val[7:0]} : {8'b00000000, (rd_sel_low_byte ? gprs[rd_8_bit_sel][7:0] : gprs[rd_8_bit_sel][15:8])});
				else
					rd_val[(1 - rd_port) * 16+:16] <= (bypass ? wr_val : gprs[rd_sel[(1 - rd_port) * 3+:3]]);
		end
	endgenerate
endmodule
