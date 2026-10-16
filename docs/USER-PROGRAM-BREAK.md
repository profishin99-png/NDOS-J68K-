# Stopping a runaway user program

Press **Ctrl+C** in the MAME serial terminal while a NEX program is running.
NDOS handles that byte in the MC68681 receive interrupt and redirects the
interrupted exception frame to a supervisor-only recovery path. A normal
foreground NEX returns to the shell with process exit code `3`; if the
experimental Task B is current, NDOS marks it exited and restores Task A.

This works even if the program is in a tight loop or repeatedly calling the
blocking character-output syscall. It does not rely on the program polling the
keyboard, checking the tick count, or yielding. The 100 Hz MC68681 development
timer continues to interrupt user programs and drive `NDOS_SYS_GET_TICKS` while
they run. The timer is not itself the break signal; Ctrl+C arrives on the
DUART receive interrupt that shares the same level-2 handler.

`BRKLOOP.NEX` is a deliberate endless-print test. Run it with:

```text
RUN BRKLOOP.NEX
```

Then press Ctrl+C and confirm the NDOS prompt returns. The automated MAME
regression is `tools/test_user_abort.py`; it checks that ticks advance while
`BRKLOOP.NEX` is running and that Ctrl+C returns to the shell with exit code 3.

This is an emulator/kernel development feature. The final CPLD1 timer source,
interrupt wiring, and physical serial-terminal behavior still require hardware
verification.
