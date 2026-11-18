// sim_ws.cpp - harness of sim_top.v (the WonderSwan on the SDRAM model).
//
// Clocks: one clk_sys period = 6 steps, clk_ram = 3 x clk_sys rising together with it (two outputs of
// one PLL). Inputs change on the falling edge of clk_sys, the outputs of SwanTop are sampled there.
//
// The cartridge goes through ws_loader as the file loader of kg_mcu2 gives it: file_active high, one
// byte (file_wr one clock) every 9 clocks (250 ns), file_active low at the end.
//
// usage: Vsim_ws --rom FILE [--frames N] [--ppm PREFIX] [--ppm-every K] [--system 0|1|2]
//                [--keys HEX@F,...] [--expect-sum F,HEX]...
//   --frames N        run N frames after the boot (default 3); a frame ends with pixel 32255
//   --ppm PREFIX      write PREFIX_NNN.ppm of the frames (every K-th with --ppm-every)
//   --system          0 Auto (the header), 1 Color, 2 Mono
//   --keys HEX@F      from frame F on, the keys (ws_kbd order: Start B A Y4 Y3 Y2 Y1 X4 X3 X2 X1)
//   --expect-sum F,HEX  the checksum of frame F
//   --trace N         print the first N cartridge (EXTRAM) reads: address, data
// Prints one line per frame (checksum, non-black pixels) and "PASS" / "FAIL: ..." at the end.

#include "Vsim_top.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>

static Vsim_top *top;

static void step(int sys, int ram) {
	top->clk_sys = sys;
	top->clk_ram = ram;
	top->eval();
}

template <class F> static void sys_cycle(F fall) {
	step(1, 1);
	step(1, 0);
	step(1, 1);
	step(0, 0);
	fall();
	step(0, 1);
	step(0, 0);
}

struct KeyAt { int f; unsigned keys; };
struct ExpSum { int f; uint32_t sum; };

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	std::string rom_name, ppm;
	int frames = 3, ppm_every = 1, sys = 0, trace = 0;
	std::vector<KeyAt> key_at;
	std::vector<ExpSum> exp_sum;
	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		auto next = [&]() -> const char * { if (i + 1 >= argc) { fprintf(stderr, "%s: value missing\n", a.c_str()); exit(2); } return argv[++i]; };
		if (a == "--rom") rom_name = next();
		else if (a == "--frames") frames = atoi(next());
		else if (a == "--ppm") ppm = next();
		else if (a == "--ppm-every") ppm_every = atoi(next());
		else if (a == "--system") sys = atoi(next());
		else if (a == "--keys") { unsigned k; int f; if (sscanf(next(), "%x@%d", &k, &f) != 2) exit(2); key_at.push_back({f, k}); }
		else if (a == "--trace") trace = atoi(next());
		else if (a == "--expect-sum") { unsigned s; int f; if (sscanf(next(), "%d,%x", &f, &s) != 2) exit(2); exp_sum.push_back({f, s}); }
		else { fprintf(stderr, "unknown option %s\n", a.c_str()); return 2; }
	}
	if (rom_name.empty()) { fprintf(stderr, "--rom missing\n"); return 2; }
	FILE *f = fopen(rom_name.c_str(), "rb");
	if (!f) { perror(rom_name.c_str()); return 2; }
	std::vector<uint8_t> rom;
	for (int c; (c = fgetc(f)) != EOF; ) rom.push_back((uint8_t)c);
	fclose(f);

	top = new Vsim_top;
	top->init = 1;
	top->file_active = 0;
	top->file_wr = 0;
	top->sw_system = sys;
	top->keys = 0;
	for (int i = 0; i < 64; i++) sys_cycle([] {});
	top->init = 0;
	// the SDRAM start-up: 12100 clk_ram
	for (int i = 0; i < 4200; i++) sys_cycle([] {});

	// the file
	size_t pos = 0;
	int gap = 0;
	top->file_active = 1;
	while (pos < rom.size()) {
		sys_cycle([&] {
			top->file_wr = 0;
			if (++gap == 9) {
				gap = 0;
				top->file_addr = (uint32_t)pos;
				top->file_data = rom[pos];
				top->file_wr = 1;
				pos++;
			}
		});
	}
	sys_cycle([] { top->file_wr = 0; });
	for (int i = 0; i < 16; i++) sys_cycle([] {});
	top->file_active = 0;
	for (int i = 0; i < 4; i++) sys_cycle([] {});
	printf("rom %zu bytes, colour %d\n", rom.size(), (int)top->hdr_color);

	std::vector<uint16_t> fb(224 * 144, 0);
	int frame = 0;
	uint64_t cycles = 0, frame_start = 0;
	bool fail = false;
	std::string why;
	const uint64_t limit = (uint64_t)(frames + 4) * 600000;
	int prev_rd = 0, n_rd = 0, pend = 0;
	int snd_max = 0;   // the largest |snd_l| / |snd_r| of the frame (signed 16 bits)
	unsigned pend_a = 0;
	while (frame < frames && cycles < limit) {
		sys_cycle([&] {
			// cartridge reads: the address at the start, the data 3 clocks later (the fixed latency)
			if (pend && --pend == 0 && n_rd <= trace) printf("  ext read %06x -> %04x\n", pend_a, (unsigned)top->ext_rdata);
			if (top->ext_read && !prev_rd) { n_rd++; if (n_rd <= trace) { pend_a = top->ext_addr; pend = 3; } }
			prev_rd = top->ext_read;
			{ int l = (int16_t)top->snd_l, r = (int16_t)top->snd_r; if (l < 0) l = -l; if (r < 0) r = -r;
			  if (l > snd_max) snd_max = l; if (r > snd_max) snd_max = r; }
			for (auto &k : key_at) if (frame >= k.f) top->keys = k.keys;
			if (top->pixel_we) {
				unsigned a = top->pixel_addr;
				if (a < 224 * 144) fb[a] = top->pixel_data;
				if (a == 224 * 144 - 1) {
					uint32_t sum = 0;
					int lit = 0;
					for (size_t i = 0; i < fb.size(); i++) { sum = sum * 31 + fb[i]; if (fb[i]) lit++; }
					printf("frame %d: %llu clocks, sum %08x, %d pixels not black, vertical %d, %d cartridge reads, sound max %d\n", frame,
					       (unsigned long long)(cycles - frame_start), sum, lit, (int)top->vertical, n_rd, snd_max);
					snd_max = 0;
					for (auto &e : exp_sum)
						if (e.f == frame && e.sum != sum) { fail = true; char b[80]; snprintf(b, sizeof b, "frame %d sum %08x != %08x; ", frame, sum, e.sum); why += b; }
					if (!ppm.empty() && frame % ppm_every == 0) {
						char name[512];
						snprintf(name, sizeof name, "%s_%03d.ppm", ppm.c_str(), frame);
						FILE *o = fopen(name, "wb");
						fprintf(o, "P6\n224 144\n255\n");
						for (size_t i = 0; i < fb.size(); i++) {
							uint8_t px[3] = { (uint8_t)(((fb[i] >> 8) & 15) * 17), (uint8_t)(((fb[i] >> 4) & 15) * 17), (uint8_t)((fb[i] & 15) * 17) };
							fwrite(px, 1, 3, o);
						}
						fclose(o);
					}
					frame++;
					frame_start = cycles;
				}
			}
		});
		cycles++;
	}
	if (frame < frames) { fail = true; why += "no frames (" + std::to_string(frame) + " of " + std::to_string(frames) + "); "; }
	if (top->sdram_errors) { fail = true; why += "sdram model errors " + std::to_string(top->sdram_errors) + "; "; }
	if (fail) printf("FAIL: %s\n", why.c_str()); else printf("PASS\n");
	delete top;
	return fail ? 1 : 0;
}
