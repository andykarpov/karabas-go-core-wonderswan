#!/usr/bin/env bash
# Generate the s80x86-derived CPU files: instruction decode tables and the microcode ROM.
set -euo pipefail
cd "$(dirname "$0")/.."
PY=${PY:-.venv/Scripts/python}
G=$PWD/rtl/s80x86/gen
mkdir -p "$G"
printf '`define S80X86_PSEUDO_286_INT 0\n' > "$G/config.v"
printf '#pragma once\n#define S80X86_TRAP_ESCAPE 0\n#define S80X86_PSEUDO_286 0\n' > "$G/config.h"
$PY tools/s80x86/gen-instructions-functions "$G/InstructionDefinitions.sv"
US=$(ls rtl/s80x86/microcode/*.us | sed "s#^#$PWD/#")
(cd tools/s80x86 && ../../$PY uasm -I"$G" "$G/microcode.bin" "$G/microcode.mif" "$G/Microcode.sv" \
    "$G/MicrocodeTypes.sv" "$G/MicrocodeTypes.h" $US)
echo "generated: $(ls "$G")"
