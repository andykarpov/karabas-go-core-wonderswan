# WonderSwan / WonderSwan Color для Karabas Go / Mini / Mini G — план

## Исследование (2026-11-18)

Готовые ядра на FPGA (проверено на GitHub в этот день):

| Ядро | Платформа | Состояние |
|---|---|---|
| [MiSTer-devel/WonderSwan_MiSTer](https://github.com/MiSTer-devel/WonderSwan_MiSTer) (Robert Peip) | Cyclone V | живое (c964245, 2026-10-13: кабель связи #33), GPL-2.0, VHDL-2008; WS + WSC, savestates, rewind, ffwd, поворот, flickerblend; DDRAM только под них и кадровый буфер; clk_sys 36.864 МГц; нужны IPL Bandai (boot.rom 4K, boot1.rom 8K) |
| [LakoMoor/open-pocket-ws](https://github.com/LakoMoor/open-pocket-ws) | Tang Nano 20K (GW2AR-18, 20 736 LUT4) | один коммит (287b601, 2026-10-19), GPL-3.0; rtl/ws = MiSTer с правками + процессор s80x86 вместо V30MZ MiSTer; 15 685 LUT4 и 45/46 BSRAM на всю систему, 37.125 МГц |
| agg23/openfpga-wonderswan | Analogue Pocket | 2023, старая база MiSTer, не берём |
| RegionallyFamous/swansong-core | Analogue Pocket | 2026-07, обвязка на Python, под homebrew, не берём |
| MiST | — | порта нет |

Что сделал open-pocket-ws (его docs/architecture.md, цифры yosys LUT4): ядро MiSTer само ~21 900 LUT4, из них V30MZ ~12 100; s80x86 (микрокодный 80186 Jamie Iles, доработан под V30MZ, проверен на ~63 тыс. тестов SingleStepTests v20 и в ногу с процессором MiSTer, timingtest проходит кроме POPA +2 такта) ~5 000 LUT4 + 6 BSRAM микрокода; спрайты на строчном буфере 4.7k → 0.5k LUT4 (в симуляции попиксельно как оригинал); заглушки RTC / serial / savestates; EEPROM 64 слова; открытый загрузчик 42 байта вместо IPL Bandai.

Отличия процессора s80x86 от V30MZ (docs/cpu.md у них): неопределённые флаги после многобитных сдвигов, POPA на 2 такта медленнее, не повторены несколько странностей MiSTer (JL/JGE с ZF, флаги опкода 82, уровни ENTER).

## Решения пользователя (2026-11-18)

- Гибрид: основа MiSTer master, из open-pocket-ws компактные спрайты и загрузчик; процессор выбираем по замеру XST на Ф0 (V30MZ MiSTer или s80x86).
- Загрузка: открытый stub в `.kg`, IPL Bandai не нужен (нет логотипа и экрана имени владельца).
- Процессор (после замера Ф0): V30MZ MiSTer, s80x86 — запасной. **Ф1 (2026-11-18): на s80x86** — с V30MZ и звуком HDMI Mini G занята на 98 % slices и не разводится; V30MZ остаётся за `KG_CPU_S80=0`.
- Имя ядра `wonderswan`, репозиторий karabas-go-core-wonderswan, пока приватный.

## Плата (XC6SLX25)

15 032 LUT6, 30 064 FF, 52 RAMB16 (по 2 КБ). SDRAM 32 МБ (картридж до 16 МБ), SRAM 4 МБ. 64 КБ RAM WSC = 32 RAMB16.

Видео WonderSwan: 224×144, 75.47 Гц. Вывод: кадровый буфер в SRAM, 1024×768@60 (масштаб 4 = 896×576), как у sega. Вертикальные игры: поворот на 90° в буфере (позже).

## Фазы

### Ф0 — импорт и замер (ветка f0-measure)

- [x] Импорт MiSTer c964245 в `src/rtl/ws`, open-pocket-ws 287b601 в `src/rtl/opws`, `src/rtl/s80x86`, `src/rtl/cpu`.
- [x] VHDL-2008 → VHDL-93 для XST: `src/tools/vhdl93.py` (process (all), чтение out-портов, условия на std_logic) + ручная таблица условий.
- [x] s80x86 через sv2v (`src/tools/sv2v.sh measure`); `$clog2` в localparam → константная функция; `Divider` → `s80_Divider` (XST не различает регистр, у MiSTer есть VHDL `divider`).
- [x] XST: три варианта SwanTop (MiSTer как есть / гибрид с s80x86 / гибрид с V30MZ MiSTer), цифры ниже.
- [x] Выбор процессора: **V30MZ MiSTer** (пользователь, 2026-11-18). `KG_CPU_S80` по умолчанию 0; s80x86 остаётся запасным, если Mini G не разведётся.

### Ф1 — Mini G, первый запуск

Верх платы на kg_* из karabas-go-modules (kg_mcu2: загрузка ROM в SDRAM через file loader, OSD, клавиатура / геймпады), SDRAM (sdram.sv MiSTer через sv2v или модуль modules), кадровый буфер в SRAM на 60 Гц, HDMI со звуком, загрузчик-stub. Цель: тестовые ROM MiSTer (`upstream/mister/testroms`) и homebrew SwanSong Originals на плате.

- [x] Верх `karabas_minig_top.v`: kg_mcu2 (file loader, OSD, клавиатура / геймпады), `ws_clocks` (DCM_CLKGEN 50·14/19 → PLL: clk_sys 36,84 / clk_ram 110,5 МГц; видео 65 / 325 МГц), `ws_sdram` (sdram.sv MiSTer вручную в Verilog-2001), `ws_loader`, `ws_fb` (3 буфера в SRAM, 1024×768 @ 60, ×4), `ws_kbd`, HDMI со звуком 48 кГц (+ DAC).
- [x] Быстрые проверки `src/sim/run_checks.sh` (~1 мин): tb_fb + timingtest через открытый загрузчик (s80x86 по умолчанию, `S80=0` — V30MZ); `sim/post` — XST + netgen + iverilog против ghdl.
- [x] XST: `fsm_extract no` на `opcodeNext` cpu.vhd (V30MZ висел на 2-й команде на плате, найдено post-synth симуляцией).
- [x] Процессор s80x86 на плате (`rtl/s80v` из sv2v); `ws_sdram` ch3: ready растянут на 3 такта clk_ram, запрос защёлкивается по фронту (иначе чтение во время занятости становилось записью мусора в ROM). timingtest: все 16 тестов, итоговая таблица попиксельно как у V30MZ.
- [x] Тайминг: `hdmi_tx` OUTPUT_REG, регистр геометрии в `kg_l2_osd_overlay` (modules `fix/osd-geom-reg`).
- [x] Плата (26111824/25): One Last Lap и другие SwanSong, управление, звук HDMI (Mote Sound Terminal — гамма, снято с аудиовхода захвата). 9,2k LUT (61 %), 79 % slices, 42 RAMB16, тайминг сходится, PAR ~1,5 мин.

### Ф2 — сохранения

EEPROM / SRAM картриджа в `.sav` через kg_bk_ram, внутренний EEPROM, RTC картриджа через RTC прошивки.

- [x] SRAM (8–512 КБ, в SDRAM) и EEPROM картриджа (128 Б–2 КБ) в `<папка игр>/saves/<игра>.sav`: kg_bk_ram (SBITS 10, блоки по 2^g секторов сверх 64, modules feat/bk-ram-blocks), мост ws_bk.v; на Mini G проверено тестовыми ROM `src/tests` (26111826).
- [x] RTC картриджа (rtl/ws/rtc.vhd) со временем часов прошивки (rtc_mode 2, kg_mcu2 ENABLE_RTC), 26111828 на Mini G.
- Внутренний EEPROM консоли не сохраняется (решение 2026-11-18: открытый загрузчик, игры его почти не используют); время, выставленное в игре, не сохраняется.

### Ф3 — режимы и остальные платы

OSD: Color / Mono / Auto, поворот (авто по запросу игры / 90 / 270), flickerblend; сборки Go и Mini, релиз в karabas-go.

### Ф4 — по желанию

Кабель связи (EXT-порт), savestates, ускорение (fast forward).

## Ф0: замеры XST

XST 14.7, xc6slx25-2, верх SwanTop, `-iobuf NO` (`make measure-mister|measure-s80|measure-v30`, по 4–6 мин). Гибрид = MiSTer rtl/ws + из open-pocket-ws спрайты, gpu, memorymux (палитра в LUT RAM), eeprom 64 слова, загрузчик, заглушки rtc / serial / savestates.

| Сборка | LUT | FF | RAMB16 | DSP48 | XST, МГц |
|---|---|---|---|---|---|
| MiSTer как есть (savestates, rtc, serial) | 14 051 (93 %) | 7 833 | 42 | 6 | 53,3 |
| Гибрид, V30MZ MiSTer (`KG_CPU_S80=0`) | 10 560 (70 %) | 3 430 | 37 | 6 | 56,1 |
| Гибрид, s80x86 (`KG_CPU_S80=1`) | 7 554 (50 %) | 3 107 | 45 | 6 | 51,0 |

Нужно 36,864 МГц: все три с запасом (худший путь V30MZ: MODRM_value -> FlagPar внутри процессора).

RAMB16: 32 — RAM WSC 64 КБ; s80x86 добавляет 8 под микрокод (1204×65, XST кладёт 2K×9 ×8; можно ужать до 6 как у open-pocket-ws: 1K×18 ×4 + 512×36 ×2) и 1 под таблицу тактов.

Оценка всей платы (Mini G): обвязка тестового ядра ~3,2k LUT + 4 RAMB16 + 1 RAMB8; у CPC замер XST 10 170 -> плата 13 413 LUT (+3,2k). Плюс кадровый буфер / масштаб / SDRAM WonderSwan ~1k.
- V30MZ: ~14,0–14,8k LUT (93–98 %), ~43 RAMB16 — впритык по LUT, как sega / snes (там 98–99 % slices, работают).
- s80x86: ~11–12k LUT (75–80 %), ~51 RAMB16 из 52 (49 с ужатым микрокодом) — впритык по BRAM, но с запасом логики под RTC / кабель связи / поворот.

MiSTer как есть (93 % без платы) не влезает: только гибрид.
