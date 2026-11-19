# Ядро WonderSwan для Karabas Go / Mini / Mini G

[English version](README.md)

Bandai WonderSwan и WonderSwan Color для плат семейства Karabas Go (Xilinx Spartan-6 XC6SLX25). Порт [ядра WonderSwan для MiSTer](https://github.com/MiSTer-devel/WonderSwan_MiSTer) Роберта Пайпа (Robert Peip) с частями [Open Pocket WS](https://github.com/LakoMoor/open-pocket-ws) от LakoMoor: компактный блок спрайтов, открытый загрузчик и процессор — V30MZ на основе [s80x86](https://github.com/jamieiles/80x86). V30MZ из MiSTer остался в исходниках как вариант, но вместе со звуком по HDMI в плату не помещается.

| Плата | Файл ядра | Видео | Звук |
|---|---|---|---|
| Karabas Go | `wonderswan.kg` | VGA | I2S ЦАП (PCM5102) |
| Karabas Mini | `wonderswan.kg` | HDMI | HDMI, аналоговый выход (сигма-дельта) |
| Karabas Mini G | `wonderswan.kg` | HDMI | HDMI, I2S ЦАП |

Файл ядра лежит в `src/`. Загрузочные ROM Bandai не нужны: картридж запускает открытый загрузчик, поэтому нет заставки и экрана с именем владельца. Образов игр в комплекте нет: положите свои файлы `.ws` / `.wsc` на SD-карту в `/wonderswan`. Свободные homebrew-игры для проверки: игры SwanSong из [Open Pocket WS](https://github.com/LakoMoor/open-pocket-ws/tree/main/games/swansong) (лицензия MIT). Среди них `mote_sound_terminal.wsc` хорошо подходит для проверки звука.

Состояние: проверено на Mini G. Сборки для Go и Mini на плате ещё не запускались.

## Возможности

- **Машины:** WonderSwan (монохромный) и WonderSwan Color. Модель выбирается по заголовку картриджа или задаётся в OSD.
- **Видео:** картинка 224 × 144 с масштабом 4 × 4 в 1024 × 768 при 60 Гц. Машина работает на своих 75,47 Гц: буфер кадра в SRAM показывает последний готовый кадр, поэтому кадры не рвутся. Вертикальные игры можно повернуть (Vert / Vert180, масштаб 3 × 3). Flickerblend смешивает 2 или 3 последних кадра — для игр с мерцающими спрайтами.
- **Звук:** стерео по HDMI и на ЦАП / аналоговом выходе.
- **Сохранения:** SRAM (от 8 КБ до 512 КБ) или EEPROM (от 128 байт до 2 КБ) картриджа хранится в `/wonderswan/saves/<игра>.sav` на SD-карте. Это сырой дамп, как у MiSTer и эмуляторов; он записывается через секунду после того, как игра его изменила.
- **Часы:** RTC картриджа стартует со временем часов платы. Время, выставленное в игре, не сохраняется.

Не сделано: внутренний EEPROM консоли (имя владельца, настройки) не сохраняется; кабель связи, сохранение состояния и ускорение.

## Как начать

1. Скопируйте `wonderswan.kg` (один файл для Go, Mini и Mini G) в корень SD-карты.
2. Положите игры в `/wonderswan` на SD-карте.
3. Выберите WonderSwan в меню ядер, откройте файловый браузер (**Menu+Esc**) и выберите игру. В следующий раз ядро снова запустит последнюю игру.

«Menu» — клавиша Windows на клавиатуре.

## Меню OSD

| Пункт | Значения | Клавиша |
|---|---|---|
| System | Auto (по заголовку) / Color / Mono | Menu+S |
| Orientation | Auto (поворот, если игра вертикальная) / Horz / Vert / Vert180 | Menu+R |
| Flickerblend | Off / 2 frames / 3 frames | |
| Reset | сброс машины | F12 |

## Управление

У WonderSwan две крестовины: X (для горизонтальных игр) и Y (для вертикальных), плюс A, B и Start.

| WonderSwan | Клавиатура | USB-геймпад |
|---|---|---|
| Крестовина X (вверх, вправо, вниз, влево) | стрелки | крестовина |
| Крестовина Y: Y1 вверх, Y2 вправо, Y3 вниз, Y4 влево | W, D, S, A | X, C, Y, Z |
| A | X | A |
| B | Z | B |
| Start | Enter | Start |

Клавиатура и оба геймпада управляют одной и той же машиной.

## Сборка

Клонируйте с `--recursive` (подмодуль `modules`). ISE 14.7: `cd src && make` для всех плат или `make minig` для одной. Верхние модули Mini и Go (и временна́я часть их ucf) делаются из модуля Mini G скриптом `src/tools/mktops.py`. VHDL-2008 ядра MiSTer переводится для XST скриптом `src/tools/vhdl93.py`, s80x86 в Verilog — `src/tools/sv2v.sh core` (в `src/rtl/s80v`).

Проверки: `src/sim/run_checks.sh` (около 1,5 мин). Он прогоняет буфер кадра (`tb_fb`, попиксельно), мост памяти сохранений (`tb_bk`) и всю машину в Verilator на тестовом ROM таймингов из MiSTer. `src/sim/post` сравнивает список соединений XST с моделью ghdl. Тестовые ROM сохранений (nasm): `src/tests`. План и заметки по устройству — в [docs/PLAN.md](docs/PLAN.md).

## Лицензия

GPL-3.0 (см. [LICENSE](LICENSE)). Ядро MiSTer — GPL-2.0-or-later, s80x86 и Open Pocket WS — GPL-3.0.

WonderSwan — товарный знак Bandai. Проект не связан с Bandai.
