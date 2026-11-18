# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Bandai WonderSwan / WonderSwan Color core for the Karabas Go, Mini and Mini G boards (Xilinx Spartan-6 XC6SLX25, ISE 14.7, XST): a port of [MiSTer-devel/WonderSwan_MiSTer](https://github.com/MiSTer-devel/WonderSwan_MiSTer) (Robert Peip, c964245) with parts of [LakoMoor/open-pocket-ws](https://github.com/LakoMoor/open-pocket-ws) (287b601): the compact sprite unit, the open boot stub, the s80x86-based V30MZ. Docs, in Russian: `docs/PLAN.md` (research, decisions, phases, the Ф0 fit numbers). Follow the phases; record a changed decision in PLAN.md.

User decisions (2026-11-18): hybrid (MiSTer master + open-pocket-ws parts, the CPU picked by the Ф0 XST measure), the open boot stub built into the `.kg` (no Bandai IPL), core id `wonderswan`, repo private for now (to be made public later).

## Layout

- `src/rtl/ws/`: the upstream MiSTer `rtl/` (VHDL-2008 + sdram.sv).
- `src/rtl/opws/`: the open-pocket-ws copies of the MiSTer files it changed (sprites, gpu, memorymux, dpram, eeprom, boot stub ROMs, stubs of rtc / serial / savestates) and its `ws_core.vhd`. `swanTop.vhd` here has the generic `KG_CPU_S80` (0 = the MiSTer V30MZ, the default and the user's pick after Ф0; 1 = s80x86, the fallback).
- `src/rtl/s80x86/`, `src/rtl/cpu/`: the s80x86 CPU (SystemVerilog) and its V30MZ wrapper `cpu_s80.sv` + timing table.
- `src/tools/vhdl93.py`: VHDL-2008 -> VHDL-93 for XST (process (all), reads of out ports, boolean std_logic conditions), applied once, in git. Run it again on any newly imported VHDL.
- `src/tools/sv2v.sh measure`: sv2v of the CPU -> `src/measure/sv2v_s80/` and the `.prj` lists; `make measure-mister|measure-s80|measure-v30`, `make measure-report`.
- `upstream/`: README, LICENSE, docs, MiSTer top and test ROMs (reference, not built).

## Rules of the core

The rules of the other karabas-go cores apply: standard video timing with syncs always present, `FT_CLK_OUT` about 8 MHz on Mini / Mini G, Go `FDC_*` outputs 0 when unused, Mini / Mini G drive T3 (`FLASH_CS_N`) = 0, OSD switch index = item position unless `"index"`, an OSD value shows 10 characters at most, FL slots 0..7 only, Verilog-2001 for XST (`sv2v` for SV), VHDL-93 for XST, imported code marked `karabas:`.

- XST is case-insensitive across VHDL and Verilog: s80x86 `Divider` was renamed `s80_Divider` (MiSTer has a VHDL `divider`).
- **Ask the user before every check on the board** (and the HDMI capture). Ask before a firmware flash.
- One branch per phase of `docs/PLAN.md`, one PR at its end.
- Heavy builds: Mini G only while working on one feature, all boards for a release; map with cost table 2 first.

## Memory

The Claude Code memory of this repo is shared with all karabas-go repos: `~/.claude/projects/<this project>/memory` is a symlink to `../karabas-go-notes` (private repo `andykarpov/karabas-go-notes`). Its `MEMORY.md` is split by repo; commit and push it after every memory change.
