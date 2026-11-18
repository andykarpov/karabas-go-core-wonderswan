# Open Pocket WS

**WonderSwan / WonderSwan Color на Sipeed Tang Nano 20K: HDMI, меню в стиле Analogue Pocket, новый компактный процессор V30MZ. Собирается только открытыми инструментами.**

[English version](../README.md) · Сайт: https://lakomoor.github.io/open-pocket-ws/ · Соседний проект: [Open Pocket GBC](https://github.com/LakoMoor/open-pocket-gbc)

![One Last Lap на Tang Nano 20K](img/lap.gif)

Одно только ядро WonderSwan из MiSTer занимает около 22 тысяч LUT, а во всей FPGA платы их 20,7 тысячи. Чтобы влезть:

- **Процессор.** Процессор MiSTer (~12 тыс. LUT) заменён микрокодным 80186 на основе [s80x86](https://github.com/jamieiles/80x86), около 5 тыс. LUT.
  - Он сверен на ~62 тыс. тестов отдельных инструкций: набор, снятый с реального NEC V20, и сравнение в режиме lockstep с процессором MiSTer.
  - Где s80x86 вёл себя иначе, добавлено поведение V30MZ, и исправлены найденные баги s80x86.
  - Такты подогнаны под V30MZ и откалиброваны по тестам с настоящей WonderSwan.
- **Спрайты.** Модуль переписан на строковый буфер: 4,7 тыс. → 0,5 тыс. LUT. В симуляции он даёт пиксель в пиксель то же, что оригинал.
- **Итог.** Система занимает 75% логики и 45 из 46 блоков памяти, тайминги на 37,125 МГц проходят.

| Игры (всё снято с платы через HDMI) | timingtest: такты процессора на железе |
|---|---|
| ![игры](img/games.png) | ![timingtest](img/timingtest.png) |

## Что умеет

- **WonderSwan Color и монохромная WonderSwan:** режим берётся из заголовка картриджа или задаётся в меню. До 15 игр во flash.
- **HDMI:** 720×480p со звуком, картинка увеличена в 3 раза, режимы LCD grid и Scanlines.
- **Меню:** продолжить, сброс, выбор игры, экран, система (Auto / Color / Mono).
- **Управление:**
  - DualShock 2;
  - 8 кнопок на пинах;
  - **USB-пульт с ПК** (`tools/remote.py`).
- **Свой открытый загрузчик** на 42 байта вместо фирменного BIOS Bandai.
- **Игры в комплекте:** [SwanSong Originals](https://github.com/RegionallyFamous/SwanSong-Originals) (MIT, распространение разрешено автором) и тестовые ROM из MiSTer.

## Демо

| Загрузка игры из меню | Rotate Dungeon | Harpoon Moon | Orbital Courier |
|---|---|---|---|
| ![меню](img/menu.gif) | ![rotate](img/rotate.gif) | ![harpoon](img/harpoon.gif) | ![courier](img/courier.gif) |

## Быстрый старт

```sh
./build.sh                  # ~10 минут
./flash.sh flash            # прошивка во flash
python tools/make_games.py build/games.bin games/swansong/one_last_lap.wsc="One Last Lap" ...
./flash.sh games            # игры во flash с адреса 0x200000
```

Подробности (на английском): [build.md](build.md) · [hardware.md](hardware.md) · [cpu.md](cpu.md) · [architecture.md](architecture.md)

## Ограничения

- **Нет часов реального времени (RTC) и порта link-кабеля.** Внутренний EEPROM урезан до 64 слов.
- **Сохранения пропадают при выключении:** SRAM и EEPROM картриджа пока не пишутся во flash.
- **Нет поворота экрана:** вертикальные игры выводятся повёрнутыми, как их отдаёт WonderSwan.
- **POPA на 2 такта медленнее,** чем на V30MZ.
- **Флаги:** неопределённые флаги сдвигов отличаются, особенности MiSTer, похожие на баги, не копировались ([cpu.md](cpu.md)).

## Лицензия

GPL-3.0. Ядро WonderSwan из MiSTer (Robert Peip, GPL-2.0-or-later), s80x86 (Jamie Iles, GPL-3.0), игры SwanSong Originals (MIT).
