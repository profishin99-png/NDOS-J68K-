# MHZ benchmark NEX

`MHZ.NEX` is an NDOS adaptation of the supplied Lee Davison / EASy68K MHz
benchmark. The original `MHz.x68` remains unchanged in Downloads; this working
copy is under `apps/mhz/`.

The port replaces Easy68K `TRAP #15` calls with NDOS syscall 14
(`NDOS_SYS_GET_TICKS`, nominally 100 Hz in the current MAME configuration) and
syscall 5 (`NDOS_SYS_PUTCHAR`). After one result or timing error it exits through
NDOS syscall 4, returning to the shell.

Build with `Build.cmd`, then run:

```text
RUN MHZ.NEX
```

Treat the printed MHz value as a rough emulator benchmark only. Tick resolution,
interrupt overhead, the syscall path, MAME execution mode, and host load affect
the result. It does not verify the physical MC68020 clock or CPLD timing.
