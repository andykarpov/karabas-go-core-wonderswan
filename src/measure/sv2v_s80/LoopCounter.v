`default_nettype none
module LoopCounter (
	clk,
	count_in,
	load,
	next,
	done
);
	input wire clk;
	input wire [4:0] count_in;
	input wire load;
	input wire next;
	output wire done;
	reg [4:0] count;
	assign done = ~|count;
	always @(posedge clk)
		if (load)
			count <= count_in;
		else if (next && |count)
			count <= count - 1'b1;
endmodule
