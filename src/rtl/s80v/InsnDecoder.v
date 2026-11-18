`default_nettype none
module InsnDecoder (
	clk,
	reset,
	flush,
	stall,
	nearly_full,
	fifo_rd_en,
	fifo_rd_data,
	fifo_empty,
	instruction,
	complete,
	immed_start,
	immed_complete,
	immed_is_8bit,
	immediate
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	input wire flush;
	input wire stall;
	input wire nearly_full;
	output wire fifo_rd_en;
	input wire [7:0] fifo_rd_data;
	input wire fifo_empty;
	output reg [75:0] instruction;
	output reg complete;
	output reg immed_start;
	input wire immed_complete;
	output reg immed_is_8bit;
	input wire [15:0] immediate;
	reg [2:0] state;
	reg [2:0] next_state;
	reg insn_complete;
	assign fifo_rd_en = ((~reset & ~fifo_empty) & ~immed_start) & (state != 3'd5);
	function has_displacement;
		input reg [7:0] mbyte;
		has_displacement = ((mbyte[2:0] == 3'b110) && (mbyte[7:6] == 2'b00)) || ^mbyte[7:6];
	endfunction
	function is_prefix;
		input reg [7:0] b;
		case (b)
			8'h26, 8'h2e, 8'h36, 8'h3e, 8'hf2, 8'hf3, 8'hf0: is_prefix = 1'b1;
			default: is_prefix = 1'b0;
		endcase
	endfunction
	function [2:0] next_instr;
		input reg _sv2v_unused;
		next_instr = ((nearly_full || stall) && insn_complete ? 3'd5 : 3'd0);
	endfunction
	function automatic insn_has_modrm;
		input reg [7:0] opcode;
		casez (opcode)
			8'hdb: insn_has_modrm = 1'b1;
			8'h82: insn_has_modrm = 1'b1;
			8'h33: insn_has_modrm = 1'b1;
			8'h09: insn_has_modrm = 1'b1;
			8'h31: insn_has_modrm = 1'b1;
			8'h89: insn_has_modrm = 1'b1;
			8'h13: insn_has_modrm = 1'b1;
			8'h8d: insn_has_modrm = 1'b1;
			8'hc7: insn_has_modrm = 1'b1;
			8'h8f: insn_has_modrm = 1'b1;
			8'hd0: insn_has_modrm = 1'b1;
			8'h12: insn_has_modrm = 1'b1;
			8'h10: insn_has_modrm = 1'b1;
			8'h88: insn_has_modrm = 1'b1;
			8'h62: insn_has_modrm = 1'b1;
			8'hc6: insn_has_modrm = 1'b1;
			8'h08: insn_has_modrm = 1'b1;
			8'h83: insn_has_modrm = 1'b1;
			8'hf7: insn_has_modrm = 1'b1;
			8'hd3: insn_has_modrm = 1'b1;
			8'h69: insn_has_modrm = 1'b1;
			8'hc0: insn_has_modrm = 1'b1;
			8'h28: insn_has_modrm = 1'b1;
			8'h23: insn_has_modrm = 1'b1;
			8'h84: insn_has_modrm = 1'b1;
			8'hd8: insn_has_modrm = 1'b1;
			8'h03: insn_has_modrm = 1'b1;
			8'h39: insn_has_modrm = 1'b1;
			8'h00: insn_has_modrm = 1'b1;
			8'h2b: insn_has_modrm = 1'b1;
			8'h11: insn_has_modrm = 1'b1;
			8'h01: insn_has_modrm = 1'b1;
			8'h20: insn_has_modrm = 1'b1;
			8'hfe: insn_has_modrm = 1'b1;
			8'h8b: insn_has_modrm = 1'b1;
			8'h80: insn_has_modrm = 1'b1;
			8'h8c: insn_has_modrm = 1'b1;
			8'h32: insn_has_modrm = 1'b1;
			8'hc1: insn_has_modrm = 1'b1;
			8'h8e: insn_has_modrm = 1'b1;
			8'h21: insn_has_modrm = 1'b1;
			8'hda: insn_has_modrm = 1'b1;
			8'h38: insn_has_modrm = 1'b1;
			8'h19: insn_has_modrm = 1'b1;
			8'h1a: insn_has_modrm = 1'b1;
			8'h02: insn_has_modrm = 1'b1;
			8'h6b: insn_has_modrm = 1'b1;
			8'hc4: insn_has_modrm = 1'b1;
			8'h2a: insn_has_modrm = 1'b1;
			8'h85: insn_has_modrm = 1'b1;
			8'h22: insn_has_modrm = 1'b1;
			8'h8a: insn_has_modrm = 1'b1;
			8'hd9: insn_has_modrm = 1'b1;
			8'h1b: insn_has_modrm = 1'b1;
			8'h3a: insn_has_modrm = 1'b1;
			8'hff: insn_has_modrm = 1'b1;
			8'h30: insn_has_modrm = 1'b1;
			8'hf6: insn_has_modrm = 1'b1;
			8'hdd: insn_has_modrm = 1'b1;
			8'hd1: insn_has_modrm = 1'b1;
			8'h3b: insn_has_modrm = 1'b1;
			8'h0a: insn_has_modrm = 1'b1;
			8'hdc: insn_has_modrm = 1'b1;
			8'h0b: insn_has_modrm = 1'b1;
			8'h86: insn_has_modrm = 1'b1;
			8'hc5: insn_has_modrm = 1'b1;
			8'hde: insn_has_modrm = 1'b1;
			8'hdf: insn_has_modrm = 1'b1;
			8'hd2: insn_has_modrm = 1'b1;
			8'h81: insn_has_modrm = 1'b1;
			8'h18: insn_has_modrm = 1'b1;
			8'h87: insn_has_modrm = 1'b1;
			8'h29: insn_has_modrm = 1'b1;
			default: insn_has_modrm = 1'b0;
		endcase
	endfunction
	function automatic [1:0] insn_immed_count;
		input reg [7:0] opcode;
		input reg [2:0] modrm_reg;
		(* full_case, parallel_case *)
		casez ({opcode, modrm_reg})
			11'o067z: insn_immed_count = 2'd0;
			11'o325z: insn_immed_count = 2'd1;
			11'o324z: insn_immed_count = 2'd1;
			11'o077z: insn_immed_count = 2'd0;
			11'o020z: insn_immed_count = 2'd0;
			11'o021z: insn_immed_count = 2'd0;
			11'o022z: insn_immed_count = 2'd0;
			11'o023z: insn_immed_count = 2'd0;
			11'o024z: insn_immed_count = 2'd1;
			11'o025z: insn_immed_count = 2'd1;
			11'h402: insn_immed_count = 2'd1;
			11'h40a: insn_immed_count = 2'd1;
			11'h412: insn_immed_count = 2'd1;
			11'h41a: insn_immed_count = 2'd1;
			11'o000z: insn_immed_count = 2'd0;
			11'o001z: insn_immed_count = 2'd0;
			11'o002z: insn_immed_count = 2'd0;
			11'o003z: insn_immed_count = 2'd0;
			11'o004z: insn_immed_count = 2'd1;
			11'o005z: insn_immed_count = 2'd1;
			11'h400: insn_immed_count = 2'd1;
			11'h408: insn_immed_count = 2'd1;
			11'h410: insn_immed_count = 2'd1;
			11'h418: insn_immed_count = 2'd1;
			11'o040z: insn_immed_count = 2'd0;
			11'o041z: insn_immed_count = 2'd0;
			11'o042z: insn_immed_count = 2'd0;
			11'o043z: insn_immed_count = 2'd0;
			11'o044z: insn_immed_count = 2'd1;
			11'o045z: insn_immed_count = 2'd1;
			11'h404: insn_immed_count = 2'd1;
			11'h40c: insn_immed_count = 2'd1;
			11'h414: insn_immed_count = 2'd1;
			11'h41c: insn_immed_count = 2'd1;
			11'o142z: insn_immed_count = 2'd0;
			11'o350z: insn_immed_count = 2'd1;
			11'o232z: insn_immed_count = 2'd2;
			11'h7fa: insn_immed_count = 2'd0;
			11'h7fb: insn_immed_count = 2'd0;
			11'o230z: insn_immed_count = 2'd0;
			11'o370z: insn_immed_count = 2'd0;
			11'o374z: insn_immed_count = 2'd0;
			11'o372z: insn_immed_count = 2'd0;
			11'o365z: insn_immed_count = 2'd0;
			11'o070z: insn_immed_count = 2'd0;
			11'o071z: insn_immed_count = 2'd0;
			11'o072z: insn_immed_count = 2'd0;
			11'o073z: insn_immed_count = 2'd0;
			11'o074z: insn_immed_count = 2'd1;
			11'o075z: insn_immed_count = 2'd1;
			11'h407: insn_immed_count = 2'd1;
			11'h40f: insn_immed_count = 2'd1;
			11'h417: insn_immed_count = 2'd1;
			11'h41f: insn_immed_count = 2'd1;
			11'o246z: insn_immed_count = 2'd0;
			11'o247z: insn_immed_count = 2'd0;
			11'o231z: insn_immed_count = 2'd0;
			11'o047z: insn_immed_count = 2'd0;
			11'o057z: insn_immed_count = 2'd0;
			11'h7f1: insn_immed_count = 2'd0;
			11'h7f9: insn_immed_count = 2'd0;
			11'o110z: insn_immed_count = 2'd0;
			11'o111z: insn_immed_count = 2'd0;
			11'o112z: insn_immed_count = 2'd0;
			11'o113z: insn_immed_count = 2'd0;
			11'o114z: insn_immed_count = 2'd0;
			11'o115z: insn_immed_count = 2'd0;
			11'o116z: insn_immed_count = 2'd0;
			11'o117z: insn_immed_count = 2'd0;
			11'h7b6: insn_immed_count = 2'd0;
			11'h7be: insn_immed_count = 2'd0;
			11'o310z: insn_immed_count = 2'd2;
			11'o330z: insn_immed_count = 2'd0;
			11'o331z: insn_immed_count = 2'd0;
			11'o332z: insn_immed_count = 2'd0;
			11'o333z: insn_immed_count = 2'd0;
			11'o334z: insn_immed_count = 2'd0;
			11'o335z: insn_immed_count = 2'd0;
			11'o336z: insn_immed_count = 2'd0;
			11'o337z: insn_immed_count = 2'd0;
			11'o364z: insn_immed_count = 2'd0;
			11'h7b7: insn_immed_count = 2'd0;
			11'h7bf: insn_immed_count = 2'd0;
			11'h7b5: insn_immed_count = 2'd0;
			11'h7bd: insn_immed_count = 2'd0;
			11'o151z: insn_immed_count = 2'd1;
			11'o153z: insn_immed_count = 2'd1;
			11'o344z: insn_immed_count = 2'd1;
			11'o354z: insn_immed_count = 2'd0;
			11'h7f0: insn_immed_count = 2'd0;
			11'h7f8: insn_immed_count = 2'd0;
			11'o100z: insn_immed_count = 2'd0;
			11'o101z: insn_immed_count = 2'd0;
			11'o102z: insn_immed_count = 2'd0;
			11'o103z: insn_immed_count = 2'd0;
			11'o104z: insn_immed_count = 2'd0;
			11'o105z: insn_immed_count = 2'd0;
			11'o106z: insn_immed_count = 2'd0;
			11'o107z: insn_immed_count = 2'd0;
			11'o154z: insn_immed_count = 2'd0;
			11'o155z: insn_immed_count = 2'd0;
			11'o315z: insn_immed_count = 2'd1;
			11'o314z: insn_immed_count = 2'd0;
			11'o316z: insn_immed_count = 2'd0;
			11'o345z: insn_immed_count = 2'd1;
			11'o355z: insn_immed_count = 2'd0;
			11'o317z: insn_immed_count = 2'd0;
			11'o162z: insn_immed_count = 2'd1;
			11'o166z: insn_immed_count = 2'd1;
			11'o343z: insn_immed_count = 2'd1;
			11'o164z: insn_immed_count = 2'd1;
			11'o174z: insn_immed_count = 2'd1;
			11'o176z: insn_immed_count = 2'd1;
			11'o351z: insn_immed_count = 2'd1;
			11'o352z: insn_immed_count = 2'd2;
			11'o353z: insn_immed_count = 2'd1;
			11'h7fc: insn_immed_count = 2'd0;
			11'h7fd: insn_immed_count = 2'd0;
			11'o163z: insn_immed_count = 2'd1;
			11'o167z: insn_immed_count = 2'd1;
			11'o165z: insn_immed_count = 2'd1;
			11'o175z: insn_immed_count = 2'd1;
			11'o177z: insn_immed_count = 2'd1;
			11'o161z: insn_immed_count = 2'd1;
			11'o173z: insn_immed_count = 2'd1;
			11'o171z: insn_immed_count = 2'd1;
			11'o160z: insn_immed_count = 2'd1;
			11'o172z: insn_immed_count = 2'd1;
			11'o170z: insn_immed_count = 2'd1;
			11'o237z: insn_immed_count = 2'd0;
			11'o305z: insn_immed_count = 2'd0;
			11'o215z: insn_immed_count = 2'd0;
			11'o311z: insn_immed_count = 2'd0;
			11'o304z: insn_immed_count = 2'd0;
			11'o254z: insn_immed_count = 2'd0;
			11'o255z: insn_immed_count = 2'd0;
			11'o342z: insn_immed_count = 2'd1;
			11'o341z: insn_immed_count = 2'd1;
			11'o340z: insn_immed_count = 2'd1;
			11'o210z: insn_immed_count = 2'd0;
			11'o211z: insn_immed_count = 2'd0;
			11'o212z: insn_immed_count = 2'd0;
			11'o213z: insn_immed_count = 2'd0;
			11'h630: insn_immed_count = 2'd1;
			11'h638: insn_immed_count = 2'd1;
			11'o260z: insn_immed_count = 2'd1;
			11'o261z: insn_immed_count = 2'd1;
			11'o262z: insn_immed_count = 2'd1;
			11'o263z: insn_immed_count = 2'd1;
			11'o264z: insn_immed_count = 2'd1;
			11'o265z: insn_immed_count = 2'd1;
			11'o266z: insn_immed_count = 2'd1;
			11'o267z: insn_immed_count = 2'd1;
			11'o270z: insn_immed_count = 2'd1;
			11'o271z: insn_immed_count = 2'd1;
			11'o272z: insn_immed_count = 2'd1;
			11'o273z: insn_immed_count = 2'd1;
			11'o274z: insn_immed_count = 2'd1;
			11'o275z: insn_immed_count = 2'd1;
			11'o276z: insn_immed_count = 2'd1;
			11'o277z: insn_immed_count = 2'd1;
			11'h470: insn_immed_count = 2'd0;
			11'h471: insn_immed_count = 2'd0;
			11'h472: insn_immed_count = 2'd0;
			11'h473: insn_immed_count = 2'd0;
			11'h474: insn_immed_count = 2'd0;
			11'h475: insn_immed_count = 2'd0;
			11'h476: insn_immed_count = 2'd0;
			11'h477: insn_immed_count = 2'd0;
			11'h460: insn_immed_count = 2'd0;
			11'h461: insn_immed_count = 2'd0;
			11'h462: insn_immed_count = 2'd0;
			11'h463: insn_immed_count = 2'd0;
			11'h464: insn_immed_count = 2'd0;
			11'h465: insn_immed_count = 2'd0;
			11'h466: insn_immed_count = 2'd0;
			11'h467: insn_immed_count = 2'd0;
			11'o240z: insn_immed_count = 2'd1;
			11'o241z: insn_immed_count = 2'd1;
			11'o242z: insn_immed_count = 2'd1;
			11'o243z: insn_immed_count = 2'd1;
			11'o244z: insn_immed_count = 2'd0;
			11'o245z: insn_immed_count = 2'd0;
			11'h7b4: insn_immed_count = 2'd0;
			11'h7bc: insn_immed_count = 2'd0;
			11'h7b3: insn_immed_count = 2'd0;
			11'h7bb: insn_immed_count = 2'd0;
			11'o220z: insn_immed_count = 2'd0;
			11'h7b2: insn_immed_count = 2'd0;
			11'h7ba: insn_immed_count = 2'd0;
			11'o010z: insn_immed_count = 2'd0;
			11'o011z: insn_immed_count = 2'd0;
			11'o012z: insn_immed_count = 2'd0;
			11'o013z: insn_immed_count = 2'd0;
			11'o014z: insn_immed_count = 2'd1;
			11'o015z: insn_immed_count = 2'd1;
			11'h401: insn_immed_count = 2'd1;
			11'h409: insn_immed_count = 2'd1;
			11'h411: insn_immed_count = 2'd1;
			11'h419: insn_immed_count = 2'd1;
			11'o346z: insn_immed_count = 2'd1;
			11'o356z: insn_immed_count = 2'd0;
			11'o156z: insn_immed_count = 2'd0;
			11'o157z: insn_immed_count = 2'd0;
			11'o347z: insn_immed_count = 2'd1;
			11'o357z: insn_immed_count = 2'd0;
			11'o130z: insn_immed_count = 2'd0;
			11'o131z: insn_immed_count = 2'd0;
			11'o132z: insn_immed_count = 2'd0;
			11'o133z: insn_immed_count = 2'd0;
			11'o134z: insn_immed_count = 2'd0;
			11'o135z: insn_immed_count = 2'd0;
			11'o136z: insn_immed_count = 2'd0;
			11'o137z: insn_immed_count = 2'd0;
			11'o007z: insn_immed_count = 2'd0;
			11'o027z: insn_immed_count = 2'd0;
			11'o037z: insn_immed_count = 2'd0;
			11'o217z: insn_immed_count = 2'd0;
			11'o141z: insn_immed_count = 2'd0;
			11'o235z: insn_immed_count = 2'd0;
			11'h7fe: insn_immed_count = 2'd0;
			11'o006z: insn_immed_count = 2'd0;
			11'o016z: insn_immed_count = 2'd0;
			11'o026z: insn_immed_count = 2'd0;
			11'o036z: insn_immed_count = 2'd0;
			11'o120z: insn_immed_count = 2'd0;
			11'o121z: insn_immed_count = 2'd0;
			11'o122z: insn_immed_count = 2'd0;
			11'o123z: insn_immed_count = 2'd0;
			11'o124z: insn_immed_count = 2'd0;
			11'o125z: insn_immed_count = 2'd0;
			11'o126z: insn_immed_count = 2'd0;
			11'o127z: insn_immed_count = 2'd0;
			11'o150z: insn_immed_count = 2'd1;
			11'o152z: insn_immed_count = 2'd1;
			11'o140z: insn_immed_count = 2'd0;
			11'o234z: insn_immed_count = 2'd0;
			11'h682: insn_immed_count = 2'd0;
			11'h68a: insn_immed_count = 2'd0;
			11'h602: insn_immed_count = 2'd1;
			11'h60a: insn_immed_count = 2'd1;
			11'h692: insn_immed_count = 2'd0;
			11'h69a: insn_immed_count = 2'd0;
			11'h683: insn_immed_count = 2'd0;
			11'h68b: insn_immed_count = 2'd0;
			11'h603: insn_immed_count = 2'd1;
			11'h60b: insn_immed_count = 2'd1;
			11'h693: insn_immed_count = 2'd0;
			11'h69b: insn_immed_count = 2'd0;
			11'o303z: insn_immed_count = 2'd0;
			11'o302z: insn_immed_count = 2'd1;
			11'o313z: insn_immed_count = 2'd0;
			11'o312z: insn_immed_count = 2'd1;
			11'h680: insn_immed_count = 2'd0;
			11'h688: insn_immed_count = 2'd0;
			11'h600: insn_immed_count = 2'd1;
			11'h608: insn_immed_count = 2'd1;
			11'h690: insn_immed_count = 2'd0;
			11'h698: insn_immed_count = 2'd0;
			11'h681: insn_immed_count = 2'd0;
			11'h689: insn_immed_count = 2'd0;
			11'h601: insn_immed_count = 2'd1;
			11'h609: insn_immed_count = 2'd1;
			11'h691: insn_immed_count = 2'd0;
			11'h699: insn_immed_count = 2'd0;
			11'o236z: insn_immed_count = 2'd0;
			11'h686: insn_immed_count = 2'd0;
			11'h68e: insn_immed_count = 2'd0;
			11'h606: insn_immed_count = 2'd1;
			11'h60e: insn_immed_count = 2'd1;
			11'h696: insn_immed_count = 2'd0;
			11'h69e: insn_immed_count = 2'd0;
			11'h687: insn_immed_count = 2'd0;
			11'h68f: insn_immed_count = 2'd0;
			11'h607: insn_immed_count = 2'd1;
			11'h60f: insn_immed_count = 2'd1;
			11'h697: insn_immed_count = 2'd0;
			11'h69f: insn_immed_count = 2'd0;
			11'o030z: insn_immed_count = 2'd0;
			11'o031z: insn_immed_count = 2'd0;
			11'o032z: insn_immed_count = 2'd0;
			11'o033z: insn_immed_count = 2'd0;
			11'o034z: insn_immed_count = 2'd1;
			11'o035z: insn_immed_count = 2'd1;
			11'h403: insn_immed_count = 2'd1;
			11'h40b: insn_immed_count = 2'd1;
			11'h413: insn_immed_count = 2'd1;
			11'h41b: insn_immed_count = 2'd1;
			11'o256z: insn_immed_count = 2'd0;
			11'o257z: insn_immed_count = 2'd0;
			11'o326z: insn_immed_count = 2'd0;
			11'h684: insn_immed_count = 2'd0;
			11'h68c: insn_immed_count = 2'd0;
			11'h604: insn_immed_count = 2'd1;
			11'h60c: insn_immed_count = 2'd1;
			11'h694: insn_immed_count = 2'd0;
			11'h69c: insn_immed_count = 2'd0;
			11'h685: insn_immed_count = 2'd0;
			11'h68d: insn_immed_count = 2'd0;
			11'h605: insn_immed_count = 2'd1;
			11'h60d: insn_immed_count = 2'd1;
			11'h695: insn_immed_count = 2'd0;
			11'h69d: insn_immed_count = 2'd0;
			11'o371z: insn_immed_count = 2'd0;
			11'o375z: insn_immed_count = 2'd0;
			11'o373z: insn_immed_count = 2'd0;
			11'o252z: insn_immed_count = 2'd0;
			11'o253z: insn_immed_count = 2'd0;
			11'o050z: insn_immed_count = 2'd0;
			11'o051z: insn_immed_count = 2'd0;
			11'o052z: insn_immed_count = 2'd0;
			11'o053z: insn_immed_count = 2'd0;
			11'o054z: insn_immed_count = 2'd1;
			11'o055z: insn_immed_count = 2'd1;
			11'h405: insn_immed_count = 2'd1;
			11'h40d: insn_immed_count = 2'd1;
			11'h415: insn_immed_count = 2'd1;
			11'h41d: insn_immed_count = 2'd1;
			11'o204z: insn_immed_count = 2'd0;
			11'o205z: insn_immed_count = 2'd0;
			11'o250z: insn_immed_count = 2'd1;
			11'o251z: insn_immed_count = 2'd1;
			11'h7b0: insn_immed_count = 2'd1;
			11'h7b1: insn_immed_count = 2'd1;
			11'h7b8: insn_immed_count = 2'd1;
			11'h7b9: insn_immed_count = 2'd1;
			11'o233z: insn_immed_count = 2'd0;
			11'o206z: insn_immed_count = 2'd0;
			11'o207z: insn_immed_count = 2'd0;
			11'o221z: insn_immed_count = 2'd0;
			11'o222z: insn_immed_count = 2'd0;
			11'o223z: insn_immed_count = 2'd0;
			11'o224z: insn_immed_count = 2'd0;
			11'o225z: insn_immed_count = 2'd0;
			11'o226z: insn_immed_count = 2'd0;
			11'o227z: insn_immed_count = 2'd0;
			11'o327z: insn_immed_count = 2'd0;
			11'o060z: insn_immed_count = 2'd0;
			11'o061z: insn_immed_count = 2'd0;
			11'o062z: insn_immed_count = 2'd0;
			11'o063z: insn_immed_count = 2'd0;
			11'o064z: insn_immed_count = 2'd1;
			11'o065z: insn_immed_count = 2'd1;
			11'h406: insn_immed_count = 2'd1;
			11'h40e: insn_immed_count = 2'd1;
			11'h416: insn_immed_count = 2'd1;
			11'h41e: insn_immed_count = 2'd1;
			default: insn_immed_count = 2'b00;
		endcase
	endfunction
	always @(flush or reset or stall or insn_complete or stall or nearly_full or immed_complete or immed_complete or insn_complete or stall or nearly_full or instruction[13:11] or instruction[7-:8] or immed_complete or immed_complete or instruction[13:11] or instruction[7-:8] or insn_complete or stall or nearly_full or instruction[13:11] or instruction[7-:8] or immed_complete or instruction[13:11] or instruction[7-:8] or immed_complete or insn_complete or stall or nearly_full or fifo_rd_data[5:3] or instruction[7-:8] or fifo_rd_data or fifo_empty or fifo_rd_data[5:3] or instruction[7-:8] or fifo_rd_data or fifo_empty or insn_complete or stall or nearly_full or insn_complete or fifo_rd_data or fifo_rd_data or fifo_rd_data or fifo_empty or instruction[75] or fifo_rd_data or fifo_rd_data or fifo_rd_data or fifo_empty or state or _sv2v_0) begin
		if (_sv2v_0)
			;
		insn_complete = 1'b0;
		case (state)
			3'd0: begin
				insn_complete = (((!fifo_empty && !is_prefix(fifo_rd_data)) && !insn_has_modrm(fifo_rd_data)) && (insn_immed_count(fifo_rd_data, 3'b000) == 2'b00)) || instruction[75];
				next_state = (fifo_empty ? 3'd0 : (is_prefix(fifo_rd_data) ? 3'd0 : (insn_has_modrm(fifo_rd_data) ? 3'd1 : (insn_immed_count(fifo_rd_data, 3'b000) != 2'b00 ? 3'd3 : (insn_complete ? next_instr(0) : 3'd0)))));
			end
			3'd1: begin
				insn_complete = (!fifo_empty && !has_displacement(fifo_rd_data)) && (insn_immed_count(instruction[7-:8], fifo_rd_data[5:3]) == 2'b00);
				next_state = (fifo_empty ? 3'd1 : (has_displacement(fifo_rd_data) ? 3'd2 : (insn_immed_count(instruction[7-:8], fifo_rd_data[5:3]) != 2'b00 ? 3'd3 : next_instr(0))));
			end
			3'd2: begin
				insn_complete = immed_complete && (insn_immed_count(instruction[7-:8], instruction[13:11]) == 2'b00);
				next_state = (immed_complete ? (insn_immed_count(instruction[7-:8], instruction[13:11]) != 2'b00 ? 3'd3 : next_instr(0)) : 3'd2);
			end
			3'd3: begin
				insn_complete = (insn_immed_count(instruction[7-:8], instruction[13:11]) == 2'b01) && immed_complete;
				next_state = (immed_complete ? (insn_immed_count(instruction[7-:8], instruction[13:11]) == 2'd2 ? 3'd4 : next_instr(0)) : 3'd3);
			end
			3'd4: begin
				insn_complete = immed_complete;
				next_state = (immed_complete ? next_instr(0) : 3'd4);
			end
			3'd5: next_state = (stall ? 3'd5 : 3'd0);
			default: next_state = 3'd0;
		endcase
		if (reset || flush)
			next_state = 3'd0;
	end
	task add_segment_override;
		input reg [1:0] seg;
		begin
			instruction[65] <= 1'b1;
			instruction[67-:2] <= seg;
		end
	endtask
	function automatic insn_immed_is_8bit;
		input reg [7:0] opcode;
		input reg [2:0] modrm_reg;
		input reg immed_num;
		(* full_case, parallel_case *)
		casez ({opcode, modrm_reg})
			11'o067z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o325z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o324z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o077z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o020z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o021z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o022z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o023z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o024z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o025z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h402: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h40a: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h412: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h41a: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o000z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o001z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o002z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o003z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o004z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o005z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h400: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h408: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h410: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h418: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o040z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o041z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o042z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o043z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o044z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o045z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h404: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h40c: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h414: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h41c: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o142z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o350z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o232z: insn_immed_is_8bit = ~|(2'h3 & (2'b01 << immed_num));
			11'h7fa: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7fb: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o230z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o370z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o374z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o372z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o365z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o070z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o071z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o072z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o073z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o074z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o075z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h407: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h40f: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h417: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h41f: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o246z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o247z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o231z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o047z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o057z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7f1: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7f9: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o110z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o111z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o112z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o113z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o114z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o115z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o116z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o117z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b6: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7be: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o310z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o330z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o331z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o332z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o333z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o334z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o335z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o336z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o337z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o364z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b7: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7bf: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b5: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7bd: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o151z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o153z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o344z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o354z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7f0: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7f8: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o100z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o101z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o102z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o103z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o104z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o105z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o106z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o107z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o154z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o155z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o315z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o314z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o316z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o345z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o355z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o317z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o162z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o166z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o343z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o164z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o174z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o176z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o351z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o352z: insn_immed_is_8bit = ~|(2'h3 & (2'b01 << immed_num));
			11'o353z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7fc: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7fd: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o163z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o167z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o165z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o175z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o177z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o161z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o173z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o171z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o160z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o172z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o170z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o237z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o305z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o215z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o311z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o304z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o254z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o255z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o342z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o341z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o340z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o210z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o211z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o212z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o213z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h630: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h638: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o260z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o261z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o262z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o263z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o264z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o265z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o266z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o267z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o270z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o271z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o272z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o273z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o274z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o275z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o276z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o277z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h470: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h471: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h472: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h473: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h474: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h475: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h476: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h477: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h460: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h461: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h462: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h463: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h464: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h465: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h466: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h467: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o240z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o241z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o242z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o243z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o244z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o245z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b4: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7bc: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b3: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7bb: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o220z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b2: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7ba: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o010z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o011z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o012z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o013z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o014z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o015z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h401: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h409: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h411: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h419: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o346z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o356z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o156z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o157z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o347z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o357z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o130z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o131z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o132z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o133z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o134z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o135z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o136z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o137z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o007z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o027z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o037z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o217z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o141z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o235z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7fe: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o006z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o016z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o026z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o036z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o120z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o121z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o122z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o123z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o124z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o125z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o126z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o127z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o150z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o152z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o140z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o234z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h682: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h68a: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h602: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h60a: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h692: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h69a: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h683: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h68b: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h603: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h60b: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h693: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h69b: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o303z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o302z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o313z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o312z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h680: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h688: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h600: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h608: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h690: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h698: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h681: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h689: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h601: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h609: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h691: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h699: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o236z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h686: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h68e: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h606: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h60e: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h696: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h69e: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h687: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h68f: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h607: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h60f: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h697: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h69f: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o030z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o031z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o032z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o033z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o034z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o035z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h403: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h40b: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h413: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h41b: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o256z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o257z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o326z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h684: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h68c: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h604: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h60c: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h694: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h69c: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h685: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h68d: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h605: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h60d: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h695: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h69d: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o371z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o375z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o373z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o252z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o253z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o050z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o051z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o052z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o053z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o054z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o055z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h405: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h40d: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h415: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h41d: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o204z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o205z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o250z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o251z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h7b0: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b1: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h7b8: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h7b9: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'o233z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o206z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o207z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o221z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o222z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o223z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o224z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o225z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o226z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o227z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o327z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o060z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o061z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o062z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o063z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o064z: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'o065z: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h406: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h40e: insn_immed_is_8bit = ~|(2'h1 & (2'b01 << immed_num));
			11'h416: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			11'h41e: insn_immed_is_8bit = ~|(2'h0 & (2'b01 << immed_num));
			default: insn_immed_is_8bit = 1'b0;
		endcase
	endfunction
	always @(posedge clk)
		if (reset) begin
			complete <= 1'b0;
			instruction <= 76'b0000000000000000000000000000000000000000000000000000000000000000000000000000;
			immed_start <= 1'b0;
		end
		else if (flush) begin
			complete <= 1'b0;
			instruction <= 76'b0000000000000000000000000000000000000000000000000000000000000000000000000000;
			immed_start <= 1'b0;
		end
		else begin
			if (complete && !stall) begin
				instruction <= 76'b0000000000000000000000000000000000000000000000000000000000000000000000000000;
				complete <= 1'b0;
			end
			if (insn_complete)
				complete <= 1'b1;
			case (state)
				3'd0:
					if (!fifo_empty) begin
						case (fifo_rd_data)
							8'hf0: instruction[70] <= 1'b1;
							8'hf2: instruction[69-:2] <= 2'd2;
							8'hf3: instruction[69-:2] <= 2'd1;
							8'h26:
								add_segment_override(2'd0);
							8'h2e:
								add_segment_override(2'd1);
							8'h36:
								add_segment_override(2'd2);
							8'h3e:
								add_segment_override(2'd3);
							default: begin
								instruction[7-:8] <= fifo_rd_data;
								instruction[64] <= insn_has_modrm(fifo_rd_data);
							end
						endcase
						if (complete)
							instruction[74-:4] <= 4'b0001;
						else if (!fifo_empty)
							{instruction[75], instruction[74-:4]} <= {instruction[75], instruction[74-:4]} + 5'b00001;
						if (next_state == 3'd3) begin
							immed_start <= 1'b1;
							immed_is_8bit <= insn_immed_is_8bit(fifo_rd_data, 3'b000, 1'b0);
						end
					end
				3'd1: begin
					if (!fifo_empty) begin
						{instruction[75], instruction[74-:4]} <= {instruction[75], instruction[74-:4]} + 5'b00001;
						instruction[15-:8] <= fifo_rd_data;
					end
					if (next_state == 3'd2) begin
						immed_start <= 1'b1;
						immed_is_8bit <= fifo_rd_data[7:6] == 2'b01;
					end
					else if (next_state == 3'd3) begin
						immed_start <= 1'b1;
						immed_is_8bit <= insn_immed_is_8bit(instruction[7-:8], fifo_rd_data[5:3], 1'b0);
					end
				end
				3'd2: begin
					if (immed_complete) begin
						instruction[31-:16] <= immediate;
						{instruction[75], instruction[74-:4]} <= {instruction[75], instruction[74-:4]} + (immed_is_8bit ? 5'd1 : 5'd2);
						immed_start <= 1'b0;
					end
					if (next_state == 3'd3) begin
						immed_start <= 1'b1;
						immed_is_8bit <= insn_immed_is_8bit(instruction[7-:8], instruction[13:11], 1'b0);
					end
				end
				3'd3: begin
					if (immed_complete) begin
						instruction[32+:16] <= immediate;
						{instruction[75], instruction[74-:4]} <= {instruction[75], instruction[74-:4]} + (immed_is_8bit ? 5'd1 : 5'd2);
						immed_start <= 1'b0;
					end
					if (next_state == 3'd4) begin
						immed_start <= 1'b1;
						immed_is_8bit <= insn_immed_is_8bit(instruction[7-:8], instruction[13:11], 1'b1);
					end
				end
				3'd4:
					if (immed_complete) begin
						instruction[48+:16] <= immediate;
						{instruction[75], instruction[74-:4]} <= {instruction[75], instruction[74-:4]} + (immed_is_8bit ? 5'd1 : 5'd2);
						immed_start <= 1'b0;
					end
				default:
					;
			endcase
		end
	always @(posedge clk) state <= next_state;
	initial _sv2v_0 = 0;
endmodule
