# NDOS temporary graphics reference

The current MAME graphics target is a development device for NDOS. It is not
the final CPLD2/ISA video card.

## Framebuffer

| Property | Value |
|---|---:|
| Base | `$00E00000` |
| Width | 320 pixels |
| Height | 200 pixels |
| Bytes per pixel | 1 |
| Row stride | 320 bytes |
| Active image | 64,000 bytes |

Pixel address is `base + (y * 320) + x`. Valid coordinates are `x=0..319`
and `y=0..199`.

## Pixel format

The temporary format is RGB332: bits 7..5 red, 4..2 green, and 1..0 blue.
Useful values are `$00` black, `$03` blue, `$1C` green, `$E0` red, `$FC`
yellow, and `$FF` white.

## Input and termination

The temporary MAME keyboard queue uses `$00E10000` for status and `$00E10004`
for data. Status bit 31 means that a translated character is ready. Reading
the data register consumes one byte. A graphics program should check this
queue once per frame and call `NDOS_SYS_EXIT` when the user presses a key.

## Recommended program structure

1. Clear the framebuffer.
2. Draw the background or floor.
3. Draw objects into the framebuffer.
4. Delay or wait for a timer tick.
5. Check input and exit if requested.
6. Repeat.

Use direct framebuffer writes in inner rendering loops. Reserve future NDOS
video syscalls for setup, capability discovery, safe primitive operations, and
input. When CPLD2 and ISA video are defined, the backend can change while the
application API remains stable.

`apps/juggler/juggler.s` is an original framebuffer demonstration inspired by
the visual ideas of the historic Amiga Juggler. It does not contain the
original Amiga source, frames, or assets.
