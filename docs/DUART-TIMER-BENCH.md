# NDOS MC68681 Development Timer and Virtual Benchmarks

## Purpose

The current reduced MAME target uses the MC68681 counter/timer as the NDOS development tick source. It enables scheduler experiments and repeatable relative benchmarks before a final CPLD1 timer/IRQ ABI exists.

## Configuration

| Item | Value | Status |
|---|---:|---|
| MAME DUART clock | 3,686,400 Hz | PROPOSED MAME board choice |
| C/T mode | Timer mode, X1 divided by 16 | VERIFIED source configuration |
| Timer input | 230,400 Hz | Derived from configured MAME clock |
| Preload | `$0480` / 1152 | VERIFIED source configuration |
| Interrupt cadence | `230400 / (2 * 1152) = 100 Hz` | VERIFIED calculation for the MAME configuration |
| DUART ISR/IMR bit | bit 3, C/T-ready | VERIFIED device-manual behavior |
| IRQ vector | `$1A`, shared with DUART receive | VERIFIED MAME/NDOS configuration |
| Timer acknowledgement | Read C/T stop-command register; timer mode continues running | VERIFIED device-manual behavior and MAME regression |
| Final CPLD1 timer | Separate future device; vector `$70` remains reserved | UNRESOLVED / DEFERRED |

The MC68681 timer-mode interrupt is generated every second terminal count. The firmware writes ACR `$70`, CTUR `$04`, CTLR `$80`, reads the start-command address, and enables RX-ready plus C/T-ready in IMR (`$0A`). The common DUART IRQ handler acknowledges C/T-ready and increments `tick_counter`, drains any available channel-A receive bytes, then preempts only if the saved frame returns to user mode and the current PCB is RUNNING.

## Public NDOS interface

Syscall 14 is `NDOS_SYS_GET_TICKS`:

```text
Input:  D0 = 14
Output: D0 = monotonically increasing 32-bit development tick count
```

It provides a relative time base for programs. It is not a wall-clock API and not physical-board timing proof.

The timer interrupt remains enabled when NDOS enters user mode, so tick-based
programs can measure elapsed development ticks. `DUART_IRQ` owns the shared
interrupt. A timer IRQ that interrupted a normal user-mode NEX now saves its
context and runs the same round-robin selector used by `TRAP #1`; an IRQ during
supervisor/kernel code returns without switching. The shared DUART receive
path also recognizes Ctrl+C and can return a runaway NEX to the shell; see
`USER-PROGRAM-BREAK.md`.

## BENCH.NEX

`BENCH.NEX` runs a fixed integer add/branch workload until 100 ticks have elapsed and prints:

```text
INTEGER LOOPS: $xxxxxxxx
ELAPSED TICKS: $xxxxxxxx
100 HZ DUART TIMER / NOT PHYSICAL MHZ
```

Use it to compare changes to the same NDOS/MAME build configuration. Do not interpret loop count as a direct MC68020 MHz measurement: cache configuration, MAME execution behavior, firmware code generation, timer configuration, and host execution conditions all affect it.

## Regression evidence

`luatests/test-duart-timer.lua` confirms that `tick_counter` advances under the configured MC68681 timer. Run `python tools/test_timer_preempt.py` to replace `BRKLOOP.NEX` on an isolated SD image with a CPU-only spin and verify two instances switch without `TRAP #1` yields. `luatests/test-run2.lua` covers cooperative switching and the `TM` shell command. `tools/test_user_abort.py` verifies that ticks advance while `BRKLOOP.NEX` is active and Ctrl+C returns to the shell with exit code 3. These tests run on isolated copies of the generated disk, leaving the user's live MAME disk untouched.

## Next benchmark additions

1. Integer workload with decimal result formatting.
2. SRAM copy/verify workload at 4 KiB, 16 KiB, and 64 KiB.
3. FAT12 create/read/delete workload.
4. Cooperative yield/context-switch workload after Scheduler Rev. 1 is real.
5. Terminal throughput test, explicitly marked host-dependent.
