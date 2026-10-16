# Enhanced 68k BASIC 3.54 NDOS port plan

## Status

**EXPERIMENTAL — EBASIC.NEX builds, boots under NDOS/MAME, accepts commands,
and returns to its READY prompt. Filesystem LOAD/SAVE and unsafe memory/code
commands still need work before this is a generally safe BASIC environment.**

This port will produce `EBASIC.NEX`, an ordinary NDOS user application. It is
not a ROM, BIOS, kernel component, or privileged monitor.

## First run

Build the normal NDOS image, start the emulator with `Run-NDOS.cmd`, then enter:

```text
RUN EBASIC.NEX
```

EhBASIC's keyword tables are uppercase, so enter BASIC commands in uppercase.
The verified smoke sequence is:

```basic
PRINT 2+2
10 PRINT "J68K BASIC"
LIST
RUN
```

It prints `4`, stores and lists the numbered line, runs it, prints `J68K BASIC`,
and returns to `Ready`. Type `EXIT` at the BASIC prompt to return to the NDOS
shell. `LOAD` and `SAVE` still return EhBASIC's existing “Not implemented”
error.

## Upstream source preserved

The unmodified supplied source is stored under
`third_party/ehbasic-v354/original/`:

- `basic68k.asm` — TS2 target source supplied by Jeff Tranter, version 3.54.
- `basic68k.inc` — runtime RAM layout used by the interpreter.
- `README.md` — supplied target map and license notice.
- `EhBASICv354.txt` — supplied byte-image text.

The upstream header attributes Enhanced BASIC to Lee Davison, copyright
2002–2012, for personal use, with commercial rights reserved. Preserve that
notice and the original files in every J68K derivative distribution.

## NDOS user-process boundary

| Item | Contract |
| --- | --- |
| Application form | `EBASIC.NEX`, launched with `RUN EBASIC.NEX` |
| Slot A range | `$00010000–$0001FFFF` inclusive |
| Total slot size | 64 KiB |
| Stack top | `$00020000`, as assigned by the existing NEX loader |
| Image rule | NEX image size + requested stack size must not exceed 64 KiB |
| RAM disk | `$00100000–$0017FFFF`; not BASIC workspace |
| Sector buffer | `$00180000`; not BASIC workspace |

The interpreter must receive only a workspace base and workspace length that
are inside its Slot A allocation. Its code, runtime vectors, BASIC program,
variables, arrays, and string storage must remain inside that workspace.

The upstream core is promising for this model: its cold-start interface already
accepts a RAM address in `A0` and a RAM length in `D0`, then holds the runtime
base in `A3`. Do not reuse the upstream fixed `ram_addr=$08000` or
`ram_size=$02000` values.

## Required platform replacements

The supplied TS2 platform layer is incompatible with NDOS and must be replaced
without rewriting the interpreter core.

| Upstream item | Supplied behavior | J68K port behavior |
| --- | --- | --- |
| `VEC_OUT` | Polls ACIA `$E001` then writes `$E000` | Call `NDOS_SYS_PUTCHAR` |
| `VEC_IN` | Polls ACIA `$E001/$E000` | Poll NDOS syscall 20; return the received byte with the carry flag indicating availability |
| `VEC_LD` / `VEC_SV` | Currently reports upstream “not implemented” | Remain disabled for EBASIC 0.1 |
| reset vectors / `code_start` | Bare-metal reset and fixed RAM setup | `.NEX` `START` wrapper invokes `LAB_COLD` with bounded workspace |
| `CPU 68000`, `SUPMODE ON` | Easy68K directives | Remove or replace for VASM MC68020 assembly |

The source probe with the project VASM confirms the first toolchain issue:
VASM rejects Easy68K directives `CPU 68000` and `SUPMODE ON`. No source file
was changed by that probe.

## Disabled unsafe language features

**DECIDED for EBASIC 0.1: do not expose raw memory or arbitrary code entry.**

The upstream source includes direct arbitrary-address operations. They must be
removed from keyword dispatch or redirected to the interpreter's normal
function-call/unsupported error path:

- `PEEK`, `DEEK`, `LEEK`
- `POKE`, `DOKE`, `LOKE`
- `CALL`, `USR`
- `WAIT`
- `BITSET`, `BITCLR`, `BTST`
- `VARPTR`, `SADD` if they expose addresses outside documented BASIC data

Future J68K BASIC hardware support must use named, checked services such as
`TIMER`, `FILES`, `SCREEN`, or `KEY$`, not raw physical addresses.

## Port order

1. Create a VASM-compatible assembly copy under `apps/ebasic/`, leaving the
   preserved upstream source unchanged.
2. Replace the bare-metal vector block with the NDOS NEX entry wrapper.
3. Create the bounded runtime workspace and stack-size calculation.
4. Replace console vectors with NDOS syscall adapters.
5. Disable unsafe tokens and verify they cannot reach raw memory operations.
6. Build `EBASIC.NEX`; prove `PRINT 2+2`, line entry, `LIST`, and `RUN`.
7. Verify clean return to NDOS with a BASIC `SYSTEM`/`EXIT` command or a
   documented control-key path.
8. Design NDOS filesystem-backed `LOAD` and `SAVE` separately after the core
   interpreter is stable.

## Verification status

| Item | Status |
| --- | --- |
| Upstream source obtained and preserved | VERIFIED |
| Upstream license notice preserved | VERIFIED |
| RAM-base/length cold-start interface present | VERIFIED from source |
| Source is already VASM-compatible | VERIFIED for the separate `apps/ebasic/` working copy |
| NDOS console adapter | IMPLEMENTED — output uses syscall 5; polling input uses syscall 20 and preserves EhBASIC's A0/D1 working state |
| Bounded Slot A workspace wrapper | IMPLEMENTED — code starts at `$00010000`; workspace is `$0001D000–$0001FFFF` |
| Unsafe commands disabled | DEFERRED — the port is currently marked experimental until keyword dispatch is hardened |
| `EBASIC.NEX` builds | VERIFIED — 13,710-byte NEX image |
| Interpreter installed in generated FAT12 disk | VERIFIED — `EBASIC.NEX` is imported by `build.py` |
| Interpreter startup and READY prompt | VERIFIED — isolated MAME run with full-size persistent storage |
| BASIC command input/output | VERIFIED — `PRINT 2+2` returned `4` |
| Program entry, `LIST`, and `RUN` | VERIFIED — entered `10 PRINT "J68K BASIC"`, listed it, ran it, and returned to `Ready` |
| `EXIT` returns to NDOS | VERIFIED — isolated MAME test returned from the BASIC program to the NDOS command loop |
| Human typing in the MAME terminal | PROPOSED FOR USER CHECK — the automated test injects the same uppercase bytes into NDOS's receive queue; the emulator test does not replace a hands-on keyboard check |
