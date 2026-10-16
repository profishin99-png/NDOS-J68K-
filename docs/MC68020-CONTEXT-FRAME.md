# MC68020 cooperative-task context layout

**Purpose:** exact context layout proposed for NDOS Scheduler Rev. 1 after a normal user-mode `TRAP #1`.

**Scope:** This applies only to the normal four-word format-0 trap frame. It is not a bus-error, address-error, or coprocessor exception-frame format.

## MC68020 frame created by `TRAP #1`

`TRAP #1` uses vector number 33. The vector-table offset is therefore `$84` (`33 * 4`). The MC68020 saves the address of the instruction following the `TRAP #1` instruction, enters supervisor mode, and creates this normal format-0 exception frame.

Let `F` be the active supervisor stack pointer immediately on entry to `SCHEDULER`, before scheduler code writes anything.

| Address | Size | Contents |
|---|---:|---|
| `F + $00` | word | Saved SR from Task A |
| `F + $02` | long | Saved PC: instruction immediately after `TRAP #1` |
| `F + $06` | word | Format/vector-offset word: `$0084` for a real `TRAP #1` frame (`format = $0`, vector offset = `$084`) |

The frame is 8 bytes total. `RTE` uses the format nibble to identify its size, restores SR and PC, and removes the frame.

For a normal task yield, Scheduler Rev. 1 depends on this exact layout:

```text
F + $00  saved SR
F + $02  saved PC
F + $06  format/vector word = $0084
```

## Full saved task context

The proposed scheduler save instruction is:

```asm
        MOVEM.L D0-D7/A0-A6,-(A7)
```

It is executed with `A7 = F`, directly below the CPU-created frame. It saves 15 longwords, or 60 bytes. For predecrement register-to-memory `MOVEM`, Motorola defines the physical write order as address registers descending, then data registers descending. The resulting memory layout below is in the useful restore order: `D0` at the lowest address through `A6` at the highest.

| Address | Size | Saved value |
|---|---:|---|
| `F - $3C` | long | `D0` |
| `F - $38` | long | `D1` |
| `F - $34` | long | `D2` |
| `F - $30` | long | `D3` |
| `F - $2C` | long | `D4` |
| `F - $28` | long | `D5` |
| `F - $24` | long | `D6` |
| `F - $20` | long | `D7` |
| `F - $1C` | long | `A0` |
| `F - $18` | long | `A1` |
| `F - $14` | long | `A2` |
| `F - $10` | long | `A3` |
| `F - $0C` | long | `A4` |
| `F - $08` | long | `A5` |
| `F - $04` | long | `A6` |
| `F + $00` | word | CPU-saved SR |
| `F + $02` | long | CPU-saved PC |
| `F + $06` | word | CPU format/vector word |

After this `MOVEM`, active `A7` equals `F - $3C`. Store that exact value in the current PCB as `PCB_SAVED_SSP`.

The full suspended-stack image is therefore 68 bytes:

```text
PCB_SAVED_SSP -> D0 .. D7, A0 .. A6       60 bytes, software saved
                  saved SR, saved PC, F/V   8 bytes, CPU saved
```

`A7` is intentionally not included in the `MOVEM` list. Its required value is represented by `PCB_SAVED_SSP`. The user stack pointer is a separate register and must be stored independently as `PCB_SAVED_USP`.

## Reserved MC68881 state in each PCB

Each PCB now has a 296-byte FPU area after the existing 68-byte CPU PCB:

| PCB offset | Size | Purpose |
|---:|---:|---|
| 68 | 4 | FPU state flags |
| 72 | 184 | Variable-length `FSAVE` frame buffer, sized for the MC68881 BUSY frame |
| 256 | 96 | FP0–FP7 extended registers for `FMOVEM` |
| 352 | 12 | FPCR, FPSR, and FPIAR for `FMOVEM` |

The complete PCB is 364 bytes. The FPU frame buffer is only reserved storage at this stage: the scheduler does **not** yet execute `FSAVE`, save the visible FP registers, or restore them. The MC68881 can emit NULL, IDLE, or BUSY frames, so save/restore code must preserve the format word and use the exact frame produced rather than assuming every save is the maximum size. If an MC68882 is selected later, increase the reserved frame to its 216-byte maximum and update the following offsets and `PCB_SIZEOF`.

## Required save and restore sequence

Save a task:

```asm
        ; Entry: active A7 is F, the normal CPU frame.
        MOVEM.L D0-D7/A0-A6,-(A7)
        ; A7 is now F - $3C.

        ; Save A7 into PCB_SAVED_SSP.
        ; Save USP into PCB_SAVED_USP.
        ; Mark this PCB READY.
```

Restore a task:

```asm
        ; Load USP from PCB_SAVED_USP.
        ; Load A7 from PCB_SAVED_SSP.
        MOVEM.L (A7)+,D0-D7/A0-A6
        ; A7 is now F, pointing at the CPU frame.
        RTE
```

Because postincrement `MOVEM` restores `D0` through `D7`, then `A0` through `A6`, the final `A7` after the restore points exactly at the saved SR. `RTE` then restores SR and PC.

## Stack-pointer rule for this NDOS revision

For a user task, the saved SR used by current NDOS launch is `$0000`: user mode, interrupt mask clear, master bit clear. On the MC68020, the active supervisor A7 in this path is the interrupt-stack-pointer view (`ISP`). In the scheduler source we use `A7` operationally, but the PCB field name `PCB_SAVED_SSP` means the saved active supervisor stack context for this task.

Rev. 1 must keep its task-return SR values in this simple user-mode configuration. Do not introduce master-mode (`M=1`) task returns or nested master/interrupt-stack transitions yet; those can create an additional throwaway frame and require a different restore design.

## Initial context for a never-run Task B

Task B has never executed `TRAP #1`, so it has no CPU-created frame yet. Scheduler initialization must create an equivalent initial 68-byte image on Task B's private supervisor stack:

```text
lowest address
    initial D0 .. D7 values
    initial A0 .. A6 values
    initial SR       normally $0000 for user mode
    initial PC       Task_B entry label
    initial F/V word format $0
highest address
```

Set Task B's `PCB_SAVED_SSP` to the initial `D0` location and set `PCB_SAVED_USP` to Task B's private user-stack top. The initial frame's format nibble must be `$0`.

The existing NDOS launch code builds a valid format-0 first-run frame with an F/V word of `$0000`. A manually prepared Task B may likewise use `$0000`, because it is an initial synthetic frame rather than an actual trap frame. `$0084` is useful only if you intentionally want the synthetic frame to look like a real `TRAP #1` return frame. In either case, the format nibble must remain zero.

## Do not use this image for these cases

| Event | Why this layout is not sufficient |
|---|---|
| Bus error / address error | MC68020 may create a short or long bus-fault frame, not the 8-byte format-0 frame. |
| Coprocessor exception | It can use a different format and additional state. |
| Nested exception with master-mode use | It can involve a throwaway frame and a second frame on a different supervisor stack. |
| Timer interrupt | The MAME DUART timer path has a separate passing preemption regression for normal user-mode frames. Do not generalize this result to nested interrupts, supervisor-mode switching, bus/address errors, coprocessor frames, or physical hardware. |

NDOS fault handling should keep discarding/recovering from fault frames as it does today. Scheduler Rev. 1 switches only clean, normal `TRAP #1` frames.

## Validation history and limits

The reduced-MAME regressions cover cooperative `TRAP #1` yields, Task B's synthetic initial context, and timer preemption between two busy NEX copies. `luatests/test-timer-preempt.lua` confirms timer-driven switches occur with no `TRAP #1` yields. These are emulator checks; they do not prove physical MC68020 interrupt-stack timing or electrical behavior.

## References

- [Motorola / Freescale MC68020 User's Manual - trap processing and stacked next PC](https://www.nxp.com/docs/en/data-sheet/MC68020UM.pdf)
- [Motorola M68000 Family Programmer's Reference Manual - MOVEM ordering](https://www.nxp.com/docs/en/reference-manual/M68000PRM.pdf)
