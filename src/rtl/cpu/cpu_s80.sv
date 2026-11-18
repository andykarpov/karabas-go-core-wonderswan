// V30MZ replacement for the MiSTer WonderSwan "cpu" entity, built around the s80x86 core
// (microcoded 80186, GPL-3.0, modified for V30MZ behaviour in rtl/s80x86).
//
// Bus: the s80x86 instruction and data buses are merged onto the WonderSwan CPU bus. One
// access is started per ce_4x period (like the original core); internal RAM / boot ROM data is
// taken at the next ce_4x, cartridge space (SDRAM) one period later.
// Timing: the s80x86 executes much faster than a V30MZ (12 clocks per CPU cycle), so each
// instruction is padded to its V30MZ cycle count (rtl/cpu/v30mz_timing.hex, measured on the
// MiSTer core) by holding the core at the next instruction boundary.
module cpu_s80 (
    input             clk,
    input             ce,              // CPU cycle (3.072 MHz), already gated by dma_active
    input             ce_4x,
    input             reset,
    input             turbo,

    output            cpu_idle,
    output            cpu_halt,
    output            cpu_irqrequest,
    output            cpu_prefix,
    input             dma_active,
    input             sdma_request,
    output            canSpeedup,

    output reg        bus_read,
    output reg        bus_write,
    output reg  [1:0] bus_be,
    output reg [19:0] bus_addr,
    output reg [15:0] bus_datawrite,
    input      [15:0] bus_dataread,

    input             irqrequest_in,
    input       [9:0] irqvector_in,

    output reg  [7:0] RegBus_Din,
    output reg  [7:0] RegBus_Adr,
    output reg        RegBus_wren,
    output reg        RegBus_rden,
    output reg        RegBus_word,
    input       [7:0] RegBus_Dout,

    input             ext_req,         // the current bus access went to cartridge space (EXTRAM)
    input             ext_ready        // cartridge space (SDRAM): read data valid / write done
);

assign cpu_halt       = 1'b0;
assign cpu_irqrequest = 1'b0;
assign cpu_prefix     = 1'b0;
assign canSpeedup     = 1'b1;

// ------------------------------------------------------------------ core
wire [19:1] i_addr, d_addr;
wire        i_access, d_access, d_wr, d_io;
wire  [1:0] d_sel;
wire [15:0] d_out;
reg  [15:0] i_in, d_in;
reg         i_ack, d_ack;
wire        hold;
wire        insn_start, insn_has_modrm, insn_rep, at_boundary, flow_change, flow_odd;
wire  [7:0] insn_opcode, insn_modrm;
wire  [1:0] insn_prefixes;

Core u_core (
    .clk(clk), .reset(reset),
    .nmi(1'b0), .intr(irqrequest_in), .irq(irqvector_in[9:2]), .inta(),
    .instr_m_addr(i_addr), .instr_m_data_in(i_in), .instr_m_access(i_access), .instr_m_ack(i_ack),
    .data_m_addr(d_addr), .data_m_data_in(d_in), .data_m_data_out(d_out), .data_m_access(d_access),
    .data_m_ack(d_ack), .data_m_wr_en(d_wr), .data_m_bytesel(d_sel), .d_io(d_io), .lock(),
    .debug_stopped(), .debug_seize(1'b0), .debug_addr(8'd0), .debug_run(1'b0), .debug_val(),
    .debug_wr_val(16'd0), .debug_wr_en(1'b0),
    .hold(hold), .insn_start(insn_start), .insn_opcode(insn_opcode), .insn_modrm(insn_modrm),
    .insn_has_modrm(insn_has_modrm), .insn_prefixes(insn_prefixes), .insn_rep(insn_rep),
    .at_boundary(at_boundary), .flow_change(flow_change), .flow_target_odd(flow_odd)
);

assign cpu_idle = at_boundary;

// ------------------------------------------------------------------ bus
localparam S_IDLE = 2'd0, S_RUN = 2'd1, S_IO2 = 2'd2;
reg  [1:0] st;
reg        cur_data, cur_io, cur_wr, cur_hi, cur_slow, ext_seen;
reg  [1:0] wait_n;
reg  [7:0] io_lo;
reg        i_pend_done, d_pend_done;   // ack given, wait for the core to drop the request

wire d_req = d_access & ~d_ack & ~d_pend_done;
wire i_req = i_access & ~i_ack & ~i_pend_done;

// cartridge space (ROM / SRAM in SDRAM) is slower than internal RAM and the boot ROM; whether
// an access went there is taken from memorymux (ext_req, in the cycle the access starts), as the
// boot ROM window at FF000 disappears once the boot code locks it.
reg run_1;   // first cycle of an access

always @(posedge clk) begin
    bus_read  <= 1'b0;
    bus_write <= 1'b0;
    i_ack     <= 1'b0;
    d_ack     <= 1'b0;
    if (ce) begin
        RegBus_wren <= 1'b0;
        RegBus_rden <= 1'b0;
        RegBus_word <= 1'b0;
    end
    if (ext_ready) ext_seen <= 1'b1;
    run_1 <= 1'b0;
    if (run_1 && ext_req) cur_slow <= 1'b1;
    if (!i_access) i_pend_done <= 1'b0;
    if (!d_access) d_pend_done <= 1'b0;

    if (reset) begin
        st <= S_IDLE;
        RegBus_wren <= 1'b0; RegBus_rden <= 1'b0; RegBus_word <= 1'b0;
        i_pend_done <= 1'b0; d_pend_done <= 1'b0;
    end else begin
        // memory accesses start on any clock (block RAM data after 2 clocks, cartridge space
        // when the SDRAM is ready); IO register accesses stay on the ce_4x grid like the original
        case (st)
        S_IDLE: if (!dma_active) begin
            if (d_req && (!d_io || ce_4x)) begin
                cur_data <= 1'b1;
                cur_io   <= d_io;
                cur_wr   <= d_wr;
                cur_hi   <= (d_sel == 2'b10);
                if (d_io) begin
                    RegBus_Adr  <= {d_addr[7:1], d_sel == 2'b10};
                    RegBus_Din  <= (d_sel == 2'b10) ? d_out[15:8] : d_out[7:0];
                    RegBus_word <= d_wr && d_sel == 2'b11;
                    if (d_wr) RegBus_wren <= 1'b1; else RegBus_rden <= 1'b1;
                    wait_n <= 2'd0;
                end else begin
                    bus_addr      <= {d_addr, d_sel == 2'b10};
                    bus_be        <= (d_sel == 2'b11) ? 2'b11 : 2'b01;
                    bus_datawrite <= (d_sel == 2'b10) ? {8'h00, d_out[15:8]} : d_out;
                    bus_write     <= d_wr;
                    bus_read      <= ~d_wr;
                    wait_n        <= 2'd1;
                    ext_seen      <= 1'b0;
                    run_1         <= 1'b1;
                end
                cur_slow <= 1'b0;
                st <= S_RUN;
            end else if (i_req && !d_req) begin
                cur_data <= 1'b0;
                cur_io   <= 1'b0;
                cur_wr   <= 1'b0;
                cur_hi   <= 1'b0;
                bus_addr <= {i_addr, 1'b0};
                bus_be   <= 2'b11;
                bus_read <= 1'b1;
                wait_n   <= 2'd1;
                cur_slow <= 1'b0;
                ext_seen <= 1'b0;
                run_1    <= 1'b1;
                st       <= S_RUN;
            end
        end
        S_RUN: if (wait_n != 0 || (cur_slow && !ext_seen && !ext_ready) || (cur_io && !ce_4x)) begin
            if (wait_n != 0) wait_n <= wait_n - 1'd1;
        end else if (cur_io && d_sel == 2'b11) begin
            // word IO: second byte at port + 1
            io_lo       <= RegBus_Dout;
            RegBus_Adr  <= RegBus_Adr + 1'd1;
            RegBus_Din  <= d_out[15:8];
            if (cur_wr) RegBus_wren <= 1'b1; else RegBus_rden <= 1'b1;
            RegBus_word <= cur_wr;
            st          <= S_IO2;
        end else begin
            if (cur_data) begin
                if (cur_io) d_in <= cur_hi ? {RegBus_Dout, 8'h00} : {8'h00, RegBus_Dout};
                else        d_in <= cur_hi ? {bus_dataread[7:0], 8'h00} : bus_dataread;
                d_ack <= 1'b1; d_pend_done <= 1'b1;
            end else begin
                i_in  <= bus_dataread;
                i_ack <= 1'b1; i_pend_done <= 1'b1;
            end
            st <= S_IDLE;
        end
        S_IO2: if (ce_4x) begin
            d_in  <= {RegBus_Dout, io_lo};
            d_ack <= 1'b1; d_pend_done <= 1'b1;
            st    <= S_IDLE;
        end
        default: st <= S_IDLE;
        endcase
    end
end

// ------------------------------------------------------------------ V30MZ timing
reg  [5:0] timing_rom [0:1023];
initial $readmemh("rtl/cpu/v30mz_timing.hex", timing_rom);

reg  [7:0] t_op;
reg  [7:0] t_modrm;
reg        t_memf, t_rep, t_taken, t_odd;   // t_odd: jump to an odd address (+1 cycle)
reg  [1:0] t_pre;
reg  [7:0] t_iter;            // REP iterations seen (saturating)
reg  [9:0] t_idx;
reg  [5:0] t_base;
reg  [7:0] ticks;             // CPU cycles since the instruction started
reg        cmps_half;

// group opcodes with a ModR/M reg sub-function, and conditional jumps / loops
reg        g_is, j_is;
reg  [3:0] g_ix;
reg  [4:0] j_ix;
always @* begin
    g_is = 1'b1;
    case (t_op)
        8'h80: g_ix = 4'd0;  8'h81: g_ix = 4'd1;  8'h82: g_ix = 4'd2;  8'h83: g_ix = 4'd3;
        8'hC0: g_ix = 4'd4;  8'hC1: g_ix = 4'd5;  8'hD0: g_ix = 4'd6;  8'hD1: g_ix = 4'd7;
        8'hD2: g_ix = 4'd8;  8'hD3: g_ix = 4'd9;  8'hF6: g_ix = 4'd10; 8'hF7: g_ix = 4'd11;
        8'hFE: g_ix = 4'd12; 8'hFF: g_ix = 4'd13;
        default: begin g_ix = 4'd0; g_is = 1'b0; end
    endcase
    j_is = (t_op[7:4] == 4'h7) || (t_op[7:2] == 6'b111000);
    j_ix = (t_op[7:4] == 4'h7) ? {1'b0, t_op[3:0]} : {3'b100, t_op[1:0]};
    if (j_is && t_taken)  t_idx = 10'd768 + {5'd0, j_ix};
    else if (g_is)        t_idx = 10'd512 + {2'd0, g_ix, t_modrm[5:3], t_memf};
    else                  t_idx = {1'b0, t_op, t_memf};
end
always @(posedge clk) t_base <= timing_rom[t_idx];

// string op iteration events: writes for MOVS/STOS/INS, reads for LODS/SCAS/OUTS, every
// second read for CMPS
wire op_writes = (t_op[7:1] == 7'b1010010) || (t_op[7:1] == 7'b1010101) || (t_op[7:1] == 7'b0110110);
wire op_cmps   = (t_op[7:1] == 7'b1010011);

// total cycles of the running instruction (REP: 5 + iterations * single cost)
wire [13:0] rep_cost = 14'd5 + t_iter * t_base;
wire [13:0] cost = (t_rep ? rep_cost : {8'd0, t_base}) + {13'd0, t_odd};   // prefixes are free on the V30MZ

always @(posedge clk) begin
    if (reset) begin
        ticks <= 8'hFF; t_op <= 8'h90; t_modrm <= 8'd0; t_memf <= 1'b0; t_rep <= 1'b0;
        t_pre <= 2'd0; t_taken <= 1'b0; t_iter <= 8'd0; cmps_half <= 1'b0;
    end else if (insn_start) begin
        t_op      <= insn_opcode;
        t_modrm   <= insn_modrm;
        t_memf    <= insn_has_modrm && insn_modrm[7:6] != 2'b11;
        t_rep     <= insn_rep;
        t_pre     <= insn_prefixes;
        t_taken   <= 1'b0;
        t_odd     <= 1'b0;
        t_iter    <= 8'd0;
        cmps_half <= 1'b0;
        ticks     <= 8'd0;
    end else begin
        if (ce && ticks != 8'hFF) ticks <= ticks + 1'd1;
        if (flow_change) begin t_taken <= 1'b1; t_odd <= flow_odd; end
        if (d_ack && !cur_io && t_rep && t_iter != 8'hFF) begin
            if (op_writes ? cur_wr : (!cur_wr && (!op_cmps || cmps_half))) t_iter <= t_iter + 1'd1;
            if (!cur_wr) cmps_half <= ~cmps_half;
        end
    end
end

// hold the core at the next boundary until the V30MZ cycle count is reached; also while a DMA
// owns the bus or a sound DMA request is pending (like the original core)
assign hold = reset | dma_active | sdma_request |
              (!turbo && ticks != 8'hFF && {6'd0, ticks} < cost);

endmodule
