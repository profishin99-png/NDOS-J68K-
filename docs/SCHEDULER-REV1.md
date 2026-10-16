# NDOS Scheduler Rev. 1 status

**Scope:** experimental cooperative and timer-driven switching in the reduced MAME target. This is not a physical-hardware timing or interrupt-compatibility claim.

## Current behavior

- `TRAP #1` saves `D0-D7/A0-A6`, the current `USP`, and supervisor context in the current PCB, then selects the next `READY` PCB in table order, wrapping at the end of the 16-record PCB table.
- The MC68681 counter/timer runs at the configured nominal 100 Hz. Its interrupt shares vector `$68` / IVR `$1A` with DUART receive.
- When a DUART timer interrupt interrupted user mode, NDOS now saves the interrupted process context and enters the same round-robin selector. An IRQ during supervisor/kernel execution only updates the tick and returns.
- The handler services RX and Ctrl+C redirection before attempting a timer switch. Background `PUTS`/`PUTCHAR` output remains suppressed so two tasks do not interleave text on the single console.
- `TM` prints tick, yield, real-switch counts, and active PCB records. It is a status view, not yet a complete process manager.
- The current runnable demonstration is still limited to Task A and Task B in separate NEX load regions. Sixteen PCB records are reserved; general process creation and allocation across all 16 slots are not implemented.

## Saved-context contract

Read [MC68020-CONTEXT-FRAME.md](MC68020-CONTEXT-FRAME.md) before changing save/restore code. The switch path expects the MC68020 format-0 exception frame below the software-saved `D0-D7/A0-A6` image, plus a per-task `USP` and saved supervisor stack pointer. The initial Task B frame is synthesized to match this layout.

## Verification completed

`build.py` assembles the kernel and applications and rebuilds the SD image and ROM successfully.

| Test | Result |
|---|---|
| `luatests/test-duart-timer.lua` | PASS; tick counter advanced by 600 during the measured interval. |
| `luatests/test-run2.lua` | PASS; both NEX copies completed their 8 cooperative yields, Task B PC remained inside its own load region, console writes from Task B were suppressed, scheduler recorded switches, and `TM` dispatched. |
| `tools/test_exit_order.py` + `luatests/test-exit-order.lua` | PASS; Task A yielded and became READY, Task B exited, Task A resumed and exited, and NDOS returned to the shell with the current-PCB pointer re-anchored. |
| `tools/test_timer_preempt.py` + `luatests/test-timer-preempt.lua` | PASS; the test replaces `BRKLOOP.NEX` on an isolated image with a two-byte CPU-only spin payload. Two copies switched with zero `TRAP #1` yields (`TICK_DELTA=1000`, `YIELD_DELTA=0`, `SWITCH_DELTA=654`). One task was RUNNING and one READY at inspection. |

MAME emits its expected checksum warning for the locally rebuilt diagnostic ROMs. The tests still completed and their assertions passed. All tests used disposable disk-image and NVRAM copies.

## What you can extend next

The round-robin selector currently scans the 16 PCB slots and recognizes `UNUSED`, `READY`, `RUNNING`, `WAITING`, and `EXITED`, but only the two demonstration slots are populated as runnable tasks. The next assembly work is yours: extend process creation/reclamation and the selection policy in `kernel/scheduler.s`, one behavior at a time, and add a regression for each new state transition. Run the timer test with `python tools/test_timer_preempt.py` after rebuilding.

Before treating this as stable, add tests for killing a background task, no runnable tasks, all PCB slots occupied, and timer/RX arriving together. Task A exiting while Task B is READY is also covered by the updated `RUN2` regression: Task B resumes, exits, and returns to the shell. Timer preemption is presently limited to normal user-mode format-0 frames; it does not switch during kernel execution or handle bus/address-error or coprocessor frames. MMU protection, sleep/wakeup, file-handle blocking, real hardware IRQ timing, and CPLD timer behavior remain out of scope.
