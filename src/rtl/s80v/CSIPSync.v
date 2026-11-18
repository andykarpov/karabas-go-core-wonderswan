`default_nettype none
module CSIPSync (
	clk,
	reset,
	cs_update,
	ip_update,
	ip_in,
	new_ip,
	propagate,
	ip_out,
	update_out
);
	input wire clk;
	input wire reset;
	input wire cs_update;
	input wire ip_update;
	input wire [15:0] ip_in;
	input wire [15:0] new_ip;
	input wire propagate;
	output wire [15:0] ip_out;
	output wire update_out;
	reg [15:0] ip;
	reg ip_updated;
	reg cs_updated;
	assign ip_out = (ip_updated ? ip : (ip_update ? new_ip : ip_in));
	assign update_out = propagate & (((ip_updated | cs_updated) | cs_update) | ip_update);
	always @(posedge clk)
		if (reset) begin
			ip_updated <= 1'b0;
			cs_updated <= 1'b0;
		end
		else begin
			if (propagate) begin
				ip_updated <= 1'b0;
				cs_updated <= 1'b0;
			end
			if ((ip_update && !ip_updated) && !propagate) begin
				ip <= new_ip;
				ip_updated <= 1'b1;
			end
			if (cs_update && !propagate)
				cs_updated <= 1'b1;
		end
endmodule
