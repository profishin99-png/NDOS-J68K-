# Seeing the 68020 registers in MAME

In VS Code run Terminal > Run Task > NDOS: Registers in MAME.  The task rebuilds
the current source, opens MAME's debugger and runs through the reset alias and
high-ROM loader.  It stops at NDOS START, address $00000100.

The debugger's register pane shows D0-D7, A0-A7, PC, SR, USP and VBR.  If that
pane is hidden, use the debugger window's View menu to show processor state.
The terminal and debugger are separate MAME windows.  Select the maincpu device
if another device has focus.

Useful commands in the debugger command box:

  g                    continue execution
  step                 execute one instruction
  over                 step over a subroutine call
  out                  run until the current subroutine returns
  bpset 00000100       set an execution breakpoint
  bplist               list breakpoints
  bpclear              clear breakpoints
  print d0             print D0
  print a7             print the active stack pointer
  print pc             print the program counter
  print sr             print the status register

Use build/ndos.lst to translate source labels to addresses.  Set a breakpoint
at a routine's listed address, type g, exercise the command in the terminal,
then inspect registers or step through it.  MAME is the debugger; VS Code runs
the build and launch tasks but does not provide source-level register panels.

# KDR RAM monitor

At the NDOS prompt type KDR.  Hexadecimal input may optionally start with `$`.

  100000               show 16 bytes starting at $00100000
  100000.10003F        show an inclusive range
  100000: DE AD BE EF  deposit bytes in the RAM disk
  Q                    return to NDOS

KDR reads only $00000000-$001FFFFF.  Deposits are limited to the RAM disk and
its 512-byte sector buffer at $00100000-$001101FF, protecting NDOS, its vectors,
stack and NEX program area.  KDR deliberately has no R/run command; NDOS RUN
remains the only program-launch command.
