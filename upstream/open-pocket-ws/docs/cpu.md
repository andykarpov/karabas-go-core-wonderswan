# The CPU: a compact V30MZ from s80x86

## Why

On the GW2AR-18 (20 736 LUT4) the MiSTer WonderSwan core alone took about 21 900 LUTs, and about 12 100 of those were its V30MZ CPU.

[s80x86](https://github.com/jamieiles/80x86) is a GPL-3.0 microcoded 80186. Most of its logic is a microcode ROM (6 block RAMs, 1204 × 65 bit). Synthesised for Gowin it is about 5 000 LUTs, which made the port possible.

## Changes to s80x86 (`rtl/s80x86`)

**Toolchain and size:**

| Change | Why |
|---|---|
| Tasks with `inout` arguments → functions; ALU tasks `automatic` | yosys-slang / Verilator |
| asynchronous → synchronous resets | yosys-slang |
| microcode ROM loaded with `$readmemb` for synthesis | was simulation-only |
| new restoring divider (17-bit remainder) | −500 LUT |

**Instruction-set fixes:**

| Change | Why |
|---|---|
| `CALL FAR` with a segment prefix pushed the overridden segment instead of CS | s80x86 bug, found by the V20 tests |
| DAA/DAS never updated SF/ZF/PF | s80x86 bug |
| logic ops clear AF | V30MZ behaviour |
| MUL leaves ZF unchanged | V30MZ |
| AAM/AAD always use base 10 (AAM 0 still raises a divide error), V30MZ flags | V30MZ |
| AAA/AAS always clear the high nibble of AL | V30MZ |
| `PUSH SP` pushes the value before the decrement (also `FF /6`) | V30MZ |

**Additions for the port:**

- `hold` input: the sequencer waits at the instruction dispatch;
- boundary / opcode / taken-jump outputs for the timing model.

## Verification

1. **NEC V20 hardware tests.** `sim/cpu_tb.cpp` (Verilator) runs the [SingleStepTests/v20](https://github.com/SingleStepTests/v20) suite: 200 tests per opcode form, about 63 600 in total.
   - The register state is loaded through the s80x86 debug interface.
   - One instruction is executed, then registers, flags and written memory are compared.
2. **Lock-step against MiSTer.** `sim/ref_tb.cpp` runs the same inputs on the MiSTer V30MZ CPU: its VHDL is converted to Verilog with GHDL, and the state is loaded through its savestate registers. The MiSTer results become the expected values for s80x86.
   - **Result:** 58 010 of 62 238 match.
   - **The rest is known and accepted:**
     - undefined OF/AF/CF after shifts with count 0 or ≥ width;
     - MiSTer quirks inherited from the MAME NEC core: JL/JGE also test ZF, opcode `82` computes CF from a sign-extended immediate, an extra push in `ENTER` with nesting levels, `REP IDIV`;
     - undefined opcodes `63`, `FF /7`.
3. **Whole core in simulation.** `sim/ws_tb.cpp` runs the complete WonderSwan core with the new CPU and a ROM file; the SDRAM latency is random.
   ![simulation](img/sim.png)
4. **Real-hardware timing.** The MiSTer `timingtest` ROM runs on the board. On every page all opcodes match the timings measured on a real WonderSwan, except POPA (2 cycles slow, see below).

## Timing model (`rtl/cpu/cpu_s80.sv`)

The s80x86 runs at clk_sys, 12 clocks per V30MZ cycle, so it is almost always faster than a V30MZ. After each instruction the core is held at the next boundary until the V30MZ cycle count has passed.

**Cycle counts come from `rtl/cpu/v30mz_timing.hex`** (1024 × 6 bit):

- the opcode / memory-form table, the ModR/M group table and taken-jump values;
- first measured in the MiSTer core in steady state (`tools/gen_timing.py`);
- then calibrated with the hardware values of `timingtest` (`tools/calib_timing.py`).

**Rules:**

- a jump to an odd address costs +1 cycle;
- prefixes are free;
- `REP` string ops cost 5 + n × the single cost.

**Memory:**

- Block RAM accesses take 2 clocks.
- Cartridge accesses wait for the SDRAM controller. It reads bursts of 2 words and keeps the last 8 bytes in a cache, so sequential code fetches rarely wait.

**Remaining difference:** POPA needs about 11 cycles on s80x86 against 9 on the V30MZ: eight stack reads in microcode.
