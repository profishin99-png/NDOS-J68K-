# NDOS Alpha 0.02 assembly

UPDATED: The assembly-only status below is historical. Boot integration is now
complete and tested. See RUNNING.md for current build/run instructions.

Input: C:\Users\jvkow\Downloads\NDOS ALPHA 0.02.s
The original is preserved as ndos-original.s and was not changed in Downloads.

Working source: ndos.s
Changes needed by vasm:
- Removed the second, consecutive NEX_END label.
- Changed two references from lowercase bs to the defined uppercase BS symbol.

Assembly succeeded with vasm 2.0f using -m68020 -m68882 -Fbin.
Run Build.cmd to rebuild using the adjacent j68k-vasm installation.
Output: ndos.bin, 2074 bytes, load address zero.
Reset SSP: 0x00008000. Reset PC: 0x00000100.
Listing: ndos.lst. Build output: assembly.log.

This is a RAM-resident image, not a complete J68K boot ROM. The source writes
variables in the low 64 KiB immediately on entry and has no overlay-clear or
DUART initialization sequence. The J68K MAME target resets with ROM overlay
enabled there. A high-ROM loader must clear the overlay, copy this image from
ROM to RAM address zero, initialize the DUART, and enter with the intended
stack/vector state. Clearing overlay must precede copying into the alias area,
because the existing driver rejects writes there while overlay is enabled.

The source's DUART base 0x00F00000 and register stride four match the current
proposed emulator interface. Assembly and reset vector bytes were checked;
NDOS execution, command handling and scheduler behavior have not been tested.
Do not replace the diagnostic split ROM files with this unpadded RAM image.
