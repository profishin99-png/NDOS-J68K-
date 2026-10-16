# Dual-M68000 graphics playground

**Status: EXPERIMENTAL / MAME-only / not physical J68K hardware.**

This optional experiment adds two independent 8 MHz M68000 devices to the
reduced MAME target.  Each executes a small private-RAM heartbeat loop.  A
simple command mailbox renders into the existing temporary `$00E00000`
320x200 RGB332 framebuffer, with worker A owning the left half and worker B
owning the right half.

It is deliberately **not** an MC68360 QUICC model.  The MC68360 is a CPU32
communications processor; this is only a fun dual-68000 graphics experiment.
It creates no Rev-A register commitment, no CPLD1/CPLD2 requirement, no ISA
definition, and no DMA claim.

## MAME-only register block

Base: `$00E20000`; all registers are 32-bit and four bytes apart.

| Offset | Register | Read/write | Meaning |
|---:|---|---|---|
| `$00` | `COMMAND` | W | `1` clear, `2` fill rectangle, `3` line, `4` checkerboard |
| `$04` | `STATUS` | R | bit 31 ready; bits 1:0 enabled workers |
| `$08` | `COLOUR` | R/W | RGB332 colour in low byte |
| `$0C` | `X0` | R/W | first X coordinate |
| `$10` | `Y0` | R/W | first Y coordinate |
| `$14` | `X1` | R/W | second X coordinate |
| `$18` | `Y1` | R/W | second Y coordinate |
| `$1C` | `WORKERS` | R/W | bit 0 left worker; bit 1 right worker |
| `$20` | `COMMAND_COUNT` | R | accepted graphics commands |
| `$24` | `HEARTBEAT_A` | R | worker A M68000 heartbeat |
| `$28` | `HEARTBEAT_B` | R | worker B M68000 heartbeat |

`c/platform/ndos_quicc_play.h` is the small C layer.  It has clear,
rectangle, line, checkerboard, status, command-count, and heartbeat calls.

## Minimal graphics experiment

```c
#include "ndos_quicc_play.h"

ndos_quicc_play_clear(0x00, NDOS_QUICC_PLAY_BOTH_WORKERS);
ndos_quicc_play_fill_rect(0, 0, 159, 199, 0xe0,
                          NDOS_QUICC_PLAY_LEFT_WORKER);
ndos_quicc_play_fill_rect(160, 0, 319, 199, 0x1c,
                          NDOS_QUICC_PLAY_RIGHT_WORKER);
ndos_quicc_play_line(0, 0, 319, 199, 0xff,
                     NDOS_QUICC_PLAY_BOTH_WORKERS);
```

The two workers are visible through their heartbeat registers.  The command
engine is deliberately synchronous and simple: it is for NDOS graphics fun,
not a performance measurement or a DMA model.
