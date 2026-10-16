# C development for NDOS

The NDOS build contains a project-local GCC 14.2 cross-compiler for `m68k-elf`.
No system-wide installation or PATH change is required. Open
`NDOS.code-workspace` and press Ctrl+Shift+B. The default task compiles C,
links it, converts it to a flat image, assembles NDOS and builds both ROM
halves. Build failures stop the process.

The first C source is `c/ndos_c.c`. Its `ndos_c_selftest` function is linked at
`$0000C000`; the generated `build/c-map.inc` gives assembly the actual symbol
address. NDOS calls it with `JSR` and receives the signed result in D0. Type
`CTEST` at the NDOS prompt. A zero return prints `C ABI/ENDIAN TEST PASSED`.

The C allocation is `$0000C000-$0000FFFF`, at most 16 KiB. The linker rejects
an image that reaches the NEX area at `$00010000`. It also rejects `.bss`
because NDOS does not yet have C runtime startup code to zero it. Initialized
data is included in the image. The existing NDOS supervisor stack starts at
`$00008000` and grows down.

Current compiler options target the MC68020 and a freestanding environment:

```text
-mcpu=68020 -msoft-float -Os -std=c11 -ffreestanding
-fno-builtin -fno-stack-protector -fno-common -fno-pic -fno-pie
-ffunction-sections -fdata-sections -Wall -Wextra -Werror
```

There is currently no libc, heap, C startup routine or floating-point runtime.
Keep early filesystem code independent of host libraries and pass block-device
operations through small NDOS functions.

Current portable read APIs are `fat12_make_short_name`,
`fat12_find_root_file`, and `fat12_read_file`. The final function reads a
complete file into a caller-owned buffer and never allocates memory. It checks
both FAT copies and rejects out-of-range, reserved, prematurely terminated,
overlong/cyclic, or unterminated chains. `tests/fat12_file_test.c` is the native
unit test; `test-file-read.lua` executes the reader as MC68020 code in MAME.

`fat12_create_file` is the first portable write operation. It supports new
root-directory files, including zero-byte files and multi-cluster allocation.
It mirrors every FAT update, pads the unused tail of the last cluster with
zeroes, and does not make the directory entry visible until data writes finish.
On an allocation or data-write failure it attempts to release the partial
chain. Existing-file replacement, deletion, subdirectories, timestamps and
long filenames remain separate work.

Generated files are:

- `build/ndos_c.o`: compiled object
- `build/ndos_c.elf`: linked image with symbols
- `build/ndos_c.map`: linker map
- `build/ndos_c.bin`: flat bytes embedded in NDOS
- `build/c-map.inc`: assembly-visible exported addresses

The cross-compiler binaries are in
`../j68k-gcc/toolchain/m68k-elf/bin`. To inspect the emitted instructions, run:

```bat
..\j68k-gcc\toolchain\m68k-elf\bin\m68k-elf-objdump.exe -d build\ndos_c.elf
```
