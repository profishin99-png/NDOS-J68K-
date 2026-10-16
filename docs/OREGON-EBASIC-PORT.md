# OREGON BASIC conversion audit

## Status

**PROPOSED — source preserved and audited; EBASIC.NEX does not yet build.**

The supplied program identifies itself as a QuickBASIC conversion of the
published 1 January 1978 CDC BASIC listing. It preserves original line numbers,
game logic, and printed text. It is a suitable future program for Enhanced 68k
BASIC on NDOS, after the interpreter port is working.

The unmodified supplied file is preserved at:

`third_party/oregon-trail-1978/original/oregon-quickbasic.bas`

Keep its existing historical authorship comments and establish the distribution
rights of the exact source before redistributing a converted version.

## What is already compatible in principle

The program's normal gameplay uses standard line-numbered BASIC constructs that
Enhanced 68k BASIC implements or is designed to implement:

- `REM`, `PRINT`, `INPUT`, `IF ... THEN`, `GOTO`, `GOSUB`, `RETURN`
- `ON ... GOTO`, `FOR`/`NEXT`, `DATA`, `READ`, `RESTORE`
- numeric arithmetic, comparisons, `INT`, `RND`, `CHR$`, and `TAB()`
- string variables and a one-dimensional string array

No graphics, direct port I/O, direct memory access, SD access, DMA, ISA device,
or temporary MAME video interface is required by the game.

## Required source conversion

| Supplied line(s) | Current form | NDOS EBASIC action | Status |
| --- | --- | --- | --- |
| 4 | `DEFDBL A-Z` | Remove. Enhanced BASIC uses its own numeric representation and does not expose QuickBASIC `DEFDBL`. | Required |
| 5 | `DIM S$(1 TO 5)` | Convert to `DIM S$(4)`. Enhanced BASIC dimensions use an inclusive upper bound; Oregon uses only `S$(1)` through `S$(4)`, so indices zero-through-four are sufficient without changing game logic. | Required |
| 180 | `RANDOMIZE TIMER` | Remove for the first test. Add a safe NDOS tick-derived seed only after EBASIC core works. | Required |
| 5410, 6120, 6800 | `SYSTEM` | Convert to `END` initially, returning to the BASIC prompt. A later safe `SYSTEM` extension may call `NDOS_SYS_EXIT`. | Required |
| 6210, 6230, 6235, 6240 | `TIMER` shooting-response timing | Do not emulate QuickBASIC wall-clock semantics. Later add a documented NDOS tick function or convert the game to a `TICKS`-based calculation at nominal 100 Hz. | Deferred |

## Input/timing note

The game measures the time between displaying a gunshot word and the player
pressing Enter. This is its only requirement beyond ordinary blocking line
input. The existing NDOS tick counter is a development interface sourced from
the virtual DUART timer at nominal 100 Hz. It may become a BASIC extension, but
it must not be called `TIMER` until its units, wrap behavior, and precision are
defined.

## Port order

1. Complete the bounded `EBASIC.NEX` user-program port.
2. Verify a manually entered BASIC test program: `PRINT`, strings, `INPUT`,
   `GOSUB`, `DIM`, `DATA`, `READ`, and `RND`.
3. Verify `DIM S$(4)` with a six-line string-array test after EBASIC runs.
4. Create a derivative `OREGON.BAS` that retains the historical attribution and
   applies only the documented syntax changes.
5. Run it by entering/loading it into EBASIC; no filesystem dependency is
   required for the first test.
6. Add a safe tick-based shooting-time extension after the core game reaches
   the purchase, hunting, and event loops.
7. Add NDOS filesystem-backed BASIC `LOAD`/`SAVE` later.

## Explicit non-goals for the first port

- No raw `PEEK`, `POKE`, `DEEK`, `DOKE`, `LEEK`, or `LOKE`.
- No `CALL` or `USR` arbitrary-address execution.
- No direct DUART, RAM-disk, video, CPLD, ISA, DMA, or SD access.
- No dependence on the temporary MAME framebuffer.
