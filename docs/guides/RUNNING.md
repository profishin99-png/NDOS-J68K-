# Build and run NDOS

Open NDOS.code-workspace in VS Code and edit ndos.s or files under c/.
- Ctrl+Shift+B compiles the freestanding C code, assembles NDOS and generates
  the boot ROM.
- Terminal > Run Task > NDOS: Run in MAME builds and opens the terminal.
- NDOS: Debug in MAME opens MAME's native debugger, not a VS Code debug adapter.
- NDOS: Registers in MAME stops at NDOS START with the CPU register pane ready.

Outside VS Code, double-click Run-NDOS.cmd. Build errors stop the launch.
Click the terminal and type HELP, VERSION, DIR, TYPE or RUN, then Enter.
Commands are ASCII case-insensitive. The supplied banner still says PRE-ALPHA 0.01.
Type KDR for the protected RAM monitor; see DEBUGGING.md for syntax and register
debugger instructions.

`Run-NDOS.cmd` mounts `disk/j68k/sdcard.img` as MAME's raw SD image. The BIOS loads root-level `NDOS.SYS` from FAT12 on that card and falls back to the ROM copy if needed. With a card present, filesystem commands such as `DIR`, `TYPE`, `RUN`, `WRITE`, `DELETE`, and `ATTRIB` use its FAT12 volume; without one, they use the 512 KiB RAM disk. `FORMAT` remains restricted to the RAM disk. The first launch creates the persistent card from the build output. After rebuilding NDOS, close MAME and run `Install-SD-Card.cmd` to back up and replace the card with the current generated image. The mounted card is directly writable by MAME; close MAME before Windows-side editing. This is a MAME-only sector interface, not the future physical SPI or CPLD2 protocol. See [MAME-SD-BOOT.md](../MAME-SD-BOOT.md).

## Rebuild and mount the benchmark

Close MAME, then run `Build-Mount-Bench.cmd` from Explorer or from the VS Code
terminal:

```bat
Build-Mount-Bench.cmd
```

It uses the normal build, then replaces only `BENCH.NEX` on the persistent
live FAT12 image at `disk/j68k/ramdisk`.  It does not install the newly
generated full system disk or overwrite unrelated files.  Start NDOS and run
`RUN BENCH.NEX`.  The import is intentionally rejected if MAME is open, since
MAME owns an in-memory copy of the RAM disk until it exits normally.

RAM-disk commands are FORMAT, FATINFO and DIR. FORMAT prints a destructive-operation
warning and then asks for a separate `YES` confirmation line before it creates the
1024-sector FAT12 volume. FATINFO validates its BPB. DIR lists visible 8.3 entries in the FAT12
root directory and skips deleted entries, long-filename records and the volume
label. MAME's `disk/j68k/ramdisk` file retains its 8.5 MiB legacy NVRAM layout:
the first 512 KiB is the NDOS FAT12 RAM disk, while the old 8 MiB virtual-card
tail is retained for compatibility and is no longer used as the active SD
image. The separate mounted raw card is `disk/j68k/sdcard.img`; see
[MAME-SD-BOOT.md](../MAME-SD-BOOT.md). The disk manager reads and installs the
512 KiB FAT12 RAM-disk portion and preserves the legacy NVRAM tail. Use FORMAT,
then enter YES only when you intentionally want to erase the FAT12 RAM disk.

The portable FAT12 layer now provides case-insensitive 8.3 root-file lookup
and complete bounded reads through FAT12 cluster chains. The NDOS bridge is
`ndos_read_file(name, destination, capacity, bytes_read)`. It validates the
destination capacity, cluster range, end-of-chain marker, traversal length and
agreement between all FAT copies. FTEST is the diagnostic command used by
test-file-read.lua with its checked non-contiguous CHAIN.BIN fixture.

Use `TYPE FILE.EXT` to display a root-directory file. TYPE accepts a normal
case-insensitive 8.3 name, loads at most the FAT12 volume's 516,608-byte data
capacity into scratch SRAM beginning at `$00110200`, and writes exactly the
directory file size to the DUART. `TYPE` without a name prints usage; a missing
entry prints `TYPE: FILE NOT FOUND`. Long filenames and subdirectories are not
supported. `test-type.lua` covers a 576-byte non-contiguous text file and both
user-error paths.

The portable write API is `fat12_create_file`, exposed to NDOS as
`ndos_create_file(name, source, size)`. It creates a new root-directory 8.3
file, finds free clusters, links them in every FAT copy, writes and zero-pads
the data sectors, and publishes the directory entry last. Existing names are
rejected with `FAT12_ERR_ALREADY_EXISTS`; replacement and deletion are not yet
defined. WTEST is the diagnostic command used by test-file-create.lua. It
creates and reads back a 700-byte CREATE.BIN file. The destructive test uses
an isolated disk; the project disk is not changed.

Use `RUN FILE.NEX` to launch a NEX executable from FAT12. NDOS reads the file
into scratch SRAM, validates the 16-byte big-endian NEX header, checks the
payload/entry/stack bounds, copies the payload to `$00010000`, enters user mode,
and returns through syscall 4. `build/HELLO.NEX` is generated from hello-nex.s
and is installed in the project disk as HELLO.NEX. The old embedded program
copy has been removed. `test-nex-run.lua` verifies the filesystem load, copied
payload, user execution, output and exit path.

To copy a file from Windows into the J68K disk:

1. Close MAME.
2. Double-click `Import-File.cmd`.
3. Pick the PC file.
4. If its name is already valid FAT 8.3, it imports immediately.
5. If necessary, enter a shorter name when prompted.
6. Start MAME and use DIR, TYPE, or RUN.

You can also drag a file from Explorer directly onto `Import-File.cmd`. A
valid 8.3 name requires no typing. The graphical importer refuses to work while
J68K MAME is open and shows a normal Windows success or error dialog.

The command-line form is still available when an explicit destination is
useful:

```bat
Import-File.cmd "C:\path\to\host-file.txt" FILE.TXT
```

The destination must be a valid 8.3 name. The importer replaces an existing destination, allocates a new
chain in every FAT copy, writes the root entry, and atomically replaces the
524,288-byte host image. Keep MAME closed during import because a running MAME
process owns an in-memory copy and may overwrite external changes when it
exits. VS Code also exposes `NDOS: Import PC File`, which opens the same file
picker.

Current outputs are build/ndos_c.elf, build/ndos_c.bin, build/ndos.bin,
build/ndos.lst, build/boot.bin, build/HELLO.NEX and build/roms/j68k/*.bin. Root ndos.bin and
ndos.lst are earlier snapshots. Type CTEST at the NDOS prompt to execute the
compiled C integration test.

Type `FREE` to report exact byte counts for the 2 MiB physical SRAM, the
statically reserved ranges, currently unreserved SRAM, and live FAT12 free
space. The disk value is calculated by scanning every usable FAT12 cluster and
checking that both FAT copies agree. `UNRESERVED RAM` is static address-map
accounting; NDOS does not yet have a heap or page allocator, so it is not an
allocation counter.
Build uses the adjacent j68k-vasm installation and Python under the workspace
work/mame-build/msys64/ucrt64/bin directory. The project-local GCC 14.2
m68k-elf toolchain is under ../j68k-gcc. Keep the current directory layout.

See C-DEVELOPMENT.md for the C memory region, ABI boundary, compiler flags and
the current freestanding-runtime limits.

boot.s jumps explicitly from the reset alias to the J68K BIOS in high ROM.  The
BIOS initializes the DUART, compares the reset alias with permanent ROM, tests
representative SRAM locations and all four byte lanes, clears and verifies the
overlay, reports POST status, emits a terminal BEL code, pauses, and clears the
screen.  It then copies NDOS into SRAM with DUART interrupts still masked,
sets VBR to zero, loads SSP $8000 and enters NDOS at $100. NDOS then programs
DUART vector $1A, enables channel-A receive-ready interrupts at level 2, and
receives characters through a 256-byte software queue.  RTS deasserts at 224
queued bytes and reasserts at 128 bytes for a physical peer that honors serial
hardware flow control.  Its constants come
from the existing MAME map. No hardware addresses or DMA behavior were added.

The permanent ROM contains signature J68KBIOS at $FFF00020, version $0100 at
$FFF0002A, and a service-pointer table at $FFF00040 for putchar, puts, beep,
POST and DUART initialization.  Success is one BEL.  Repeating failure codes
are 1=ROM alias, 2=SRAM/byte lanes and 3=overlay/low SRAM.  BEL uses the serial
terminal; no physical board speaker interface has been assigned.

Verified in MAME: NDOS banner and prompt, interrupt-driven keyboard input,
level-2 IACK returning vector $1A, HELP output, DISKTEST across all 128 sectors,
and filesystem-backed `RUN HELLO.NEX`, which prints its success messages and
returns to the prompt. CTEST also executes the GCC-built function at $0000C000. FORMAT YES,
FATINFO and DIR were exercised against the physical 512 KiB RAM-disk model; DIR
reported both an empty root and a decoded HELLO.NEX test entry. A second MAME
process restored the exact boot sector, FAT and root entry from the 65,536-byte
backing file. The tests logged no J68K BERR. See test-boot.lua, test-c.lua,
test-format.lua, test-persistence-read.lua, test-file-read.lua, test-type.lua,
test-file-create.lua, test-file-create-reopen.lua, test-nex-run.lua,
boot-result.txt, c-test-result.txt, format-result.txt, persistence-result.txt,
file-read-result.txt, type-result.txt, file-create-result.txt,
nex-run-result.txt and the images under build/snap.
This does not verify all NDOS features or physical hardware.

MAME reports WRONG CHECKSUMS because its executable identifies the original
diagnostic ROM hashes. These separately generated NDOS development ROMs differ
and were successfully loaded. The original diagnostic files remain unchanged.
The existing machine-status warning remains. Editing NDOS needs no MAME rebuild.
