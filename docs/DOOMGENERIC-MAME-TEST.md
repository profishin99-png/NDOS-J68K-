# DoomGeneric MAME test status

This is an experimental MAME-only track.  It does not define the Rev-A SPI SD
controller, CPLD2 interface, ISA ABI, DMA engine, or physical hardware timing.

The MAME target mounts a separate writable raw SD image (`disk/j68k/sdcard.img`)
of up to 8 MiB, using a 512-byte PIO staging buffer. The default generated card
is 1.44 MiB FAT12; larger test images must be mounted explicitly. The card is
separate from the existing NDOS RAM disk. `SDTEST.NEX` writes a pattern to test
LBA 16, clears the staging buffer, reads the sector back, and verifies all 512
bytes.

The temporary register block is `$00E30000` and the staging buffer is
`$00E31000`.  Commands are `1` for read card-to-buffer and `2` for write
buffer-to-card.  This address map is MAME-only and may not be copied into
physical CPLD/SD hardware design documents.

DoomGeneric source is in `third_party/doomgeneric`.  It requires a larger
application loader than the current 64 KiB NEX ABI, a Doom-specific freestanding
C runtime/file adapter, and a user-provided IWAD or freely licensed equivalent
before it can become a runnable J68K test.

## 64 KiB contiguous-loader experiment

`tools/doomchunk.py` now splits one flat experimental executable into FAT 8.3
files named `DOOM00.BIN`, `DOOM01.BIN`, and so on.  Each is at most 64 KiB.
The accompanying `DOOMLOAD.JSON` is a host-side manifest that records the
ordered files, load base, entry point, total byte count, and SHA-256 checksum.

For example, once a freestanding Doom test image exists:

```text
python tools/doomchunk.py build/doom/doom.bin build/doom/chunks --base 0x30000
```

The planned `DOOMLOAD.NEX` bootstrap will remain an ordinary <=64 KiB NEX.  It
will read the listed files **in order** into one contiguous high-RAM range,
starting at `$00030000`, and then jump to the manifest entry point.  It will not
swap arbitrary chunks while the program executes: ordinary compiled MC68020
code contains direct branches and data references that require all loaded code
to remain at fixed addresses.

The current test reservation is `$00030000-$000FFFFF` (832 KiB).  It is only a
MAME/NDOS experiment and must be revisited before any permanent ABI or physical
board decision.  Existing `RUN` and the 64 KiB NEX format remain unchanged.

`NDOS_SYS_READ_LARGE` (syscall 19) is reserved for the future `DOOMLOAD.NEX`
bootstrap. It accepts the same arguments as syscall 9 but permits a destination
only in the experimental high-RAM range and caps one transfer at 64 KiB. It is
MAME-only and experimental; ordinary applications must keep using syscall 9.

## Packaging a future flat test image

Once the freestanding MC68020 image exists, run:

```text
python tools/doompackage.py build/doom/doom.bin --entry 0x30000
```

This writes `DOOM00.BIN` and later chunks below `disk/files/doom/`, generates
`apps/doomload/doomload.s`, and creates the `DOOMLOAD` app metadata. A normal
`Build.cmd` then assembles `DOOMLOAD.NEX` and includes its listed chunks on the
generated NDOS disk. The package is intentionally opt-in: no Doom files are
added unless that packager has run.
