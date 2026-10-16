# NDOS workspace layout

This project keeps handwritten sources, generated artifacts, MAME regressions, and engineering notes separate so a build or emulator test never overwrites development work.

| Location | Contents |
| --- | --- |
| `ndos.s`, `boot.s`, `hello-nex.s` | Top-level kernel, boot, and standalone assembly sources |
| `apps/<app-name>/` | Handwritten `.s` source for each NEX application |
| `kernel/` | Assembly include files and kernel-only definitions, including PCB definitions |
| `c/` | Freestanding portable C code, FAT12 implementation, and platform adapters |
| `sdk/asm/`, `c/include/` | Public NDOS syscall and C-facing SDK headers |
| `disk/` | Disk manifest and source files used to create the system image |
| `docs/` | Architecture, scheduler, timer, and engineering documentation |
| `luatests/` | MAME Lua functional-regression scripts |
| `tests/` | Host-side unit and integration tests |
| `tools/` | Image, NEX, import, and developer tooling |
| `build/` | Generated objects, ROMs, NEX files, disk images, listings, maps, and test output only |
| `build/test-results/` | Result summaries produced by newer Lua regressions |
| `build/test-nvram/<test-name>/` | Disposable, isolated MAME NVRAM copies used by a regression |
| `snap/` | Saved screenshots or machine snapshots |

## Rules for new work

1. Put a new application source in `apps/<name>/<name>.s`; the build creates its `.bin`, `.lst`, and `.NEX` under `build/apps/`.
2. Put a new MAME Lua test in `luatests/`, and have it write its result to `build/test-results/`.
3. Keep all generated files under `build/`. Do not place a new handwritten source file there.
4. Keep disk inputs in `disk/`; rebuild `build/disks/ndos-system.img` from the manifest rather than editing a generated image by hand.
5. Keep older root-level logs and result files as historical evidence. New work follows this layout; they do not need to be moved for the project to remain buildable.
6. Use a separate path below `build/test-nvram/` for every MAME test. Never point an automated test at `disk/j68k/ramdisk`, which is the live development disk used by the interactive emulator.

The existing `build/apps/delete/delete.s` is retained untouched because it may be an earlier user copy. The canonical DELETE application source is `apps/delete/delete.s`.
