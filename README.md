# WonderSwan core for Karabas Go / Mini / Mini G

Bandai WonderSwan and WonderSwan Color for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). A port of the [MiSTer WonderSwan core](https://github.com/MiSTer-devel/WonderSwan_MiSTer) by Robert Peip, with parts of [Open Pocket WS](https://github.com/LakoMoor/open-pocket-ws) by LakoMoor (compact sprite unit, open boot stub, and the CPU: the [s80x86](https://github.com/jamieiles/80x86)-based V30MZ; the MiSTer V30MZ is kept as an option, it does not fit the board with HDMI audio).

Status: work in progress, nothing to run yet. The plan is in `docs/PLAN.md` (Russian).

The Bandai boot ROMs are not needed: an open boot stub starts the cartridge (no boot logo and no owner-name screen). Game images are not included.

## Licence

GPL-3.0 (see [LICENSE](LICENSE)). The MiSTer core is GPL-2.0-or-later, s80x86 and Open Pocket WS are GPL-3.0.

WonderSwan is a trademark of Bandai. This project is not affiliated with Bandai.
