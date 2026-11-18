#!/bin/bash
# The save test ROMs (nasm, the V30 runs 8086 code): savetest.ws (SRAM 512 KB) and eeptest.ws
# (EEPROM 2 KB). Each start adds 1 to counters in the save memory: copy a ROM to the SD card, start
# it, press F12, start it again from the browser: <dir>/saves/<name>.sav then has 3 at offset 0 and
# at the end (0x7FFFE / 0x7FE), "KARABAS!" (SRAM) or "KARA" (EEPROM) after the first word.
# rtctest.ws (SRAM 8 KB, RTC): bytes 0..6 of its .sav = the RTC time at the start (BCD year month
# day weekday hour minute second), 8..14 = the time of the last save.
set -e
cd "$(dirname "$0")"
mkdir -p build
for r in savetest eeptest rtctest; do nasm -f bin -o build/$r.ws $r.asm; done
ls -l build/*.ws
