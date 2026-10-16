# NDOS-J68K

NDOS is a custom MC68020 development operating system for the J68K Rev-A
machine. It is a work in progress, developed as a UNIX-inspired 68020 homebrew
system. The current target is the reduced J68K MAME machine; a successful MAME
build or test does not imply physical-hardware validation.

The project builds a high-ROM BIOS image, a 512 KiB FAT12 fallback RAM disk, a
1.44 MiB FAT12 MAME SD-card image, and a collection of NEX applications. The
scheduler and context-switching code remain experimental. Temporary MAME video
support is optional and is not required for the NDOS shell.

## Build and run

On the original Windows development setup, open `NDOS.code-workspace` in VS
Code and use **Ctrl+Shift+B** to build. Run `Run-NDOS.cmd` to build and launch
the J68K MAME target. The command wrappers expect the adjacent J68K toolchain
and MAME workspace layout documented in
[`docs/guides/RUNNING.md`](docs/guides/RUNNING.md); this repository does not
include those external tools.

At the NDOS prompt, try `HELP`, `DIR`, `TYPE README.TXT`, or `RUN BILLION.NEX`.
The billion-count program reports its count and whole elapsed seconds using the
current nominal 100 Hz MAME tick service.

## Included project areas

- `ndos.s`, `boot.s`, and `kernel/`: operating-system and boot assembly.
- `apps/`: assembly NEX applications, including `BILLION.NEX` source.
- `c/`: freestanding C code and FAT12 implementation.
- `sdk/`: public assembly and C system-call interfaces.
- `tests/` and `luatests/`: host-side and MAME regression tests.
- `docs/`: user and engineering documentation.
- `tools/`: disk-image, NEX, import, and development utilities.
- `third_party/`: bundled external code with its included license files.
- `snap/`: development screenshots.
- `disk/system.json` and `disk/files/`: source inputs used to generate the
  system disk image.

See [`docs/WORKSPACE-LAYOUT.md`](docs/WORKSPACE-LAYOUT.md) for project
organization and [`docs/guides/RUNNING.md`](docs/guides/RUNNING.md) for the
current build and emulator workflow.
