# Temporary MAME display and input ABI

**PROPOSED / MAME-only.** This is not an ISA VGA implementation and not a PS/2 electrical model. It exists so NDOS C applications can start using graphics and input without becoming tied to the eventual CPLD2/ISA implementation.

## Virtual display

- 320 x 200 pixels, one byte per pixel, fixed RGB332 palette.
- Framebuffer: `$00E00000-$00E0FFFF`; the usable image is the first 64,000 bytes.
- Public C API: `c/platform/ndos_video.h`.

## Temporary input

- Control area: `$00E10000-$00E1000F`.
- Longword at offset 0: status; bit 31 means a byte is ready.
- Longword at offset 4: read pops one host-keyboard translated character from a 16-byte queue; byte is returned in bits 31:24.
- Public C API: `c/platform/ndos_input.h`.

The input device is deliberately *not called real PS/2*: MAME supplies translated characters, not PS/2 make/break scan codes. A later PS/2 controller backend can preserve `ndos_input_get_char` for programs while exposing a lower-level scan-code API for drivers.

When CPLD2/ISA VGA or PS/2 becomes defined, replace `ndos_video.c` and the input backend; applications should keep using these headers.