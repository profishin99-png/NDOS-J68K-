# NDOS application SDK

Build a flat MC68020 assembly application and package it as NEX:

```bat
tools\\cmd\\Build-App.cmd apps\template\app.s build\apps\MYAPP.NEX
```

The default entry offset is zero and the default requested stack is 1024
bytes. Optional third and fourth arguments select another entry offset and
stack size. `tools/nexpack.py` validates that the entry is even and inside the
payload and that payload plus stack fit the 64 KiB NEX region.

Programs may be launched with one argument using `RUN FILE.NEX ARG`.  At NEX
entry, D0 is zero or one (`argc`).  When D0 is one, A0 points to a
zero-terminated copy of the argument in user memory.  A0 is zero when no
argument was supplied.  The kernel reserves the argument at the top of the
requested NEX stack before setting USP, so applications may read it for their
entire lifetime but must not modify memory above their initial stack pointer.

Copy the resulting file to the working MAME disk with `Import-File.cmd`, or
add it to `disk/system.json` and run `tools\\cmd\\Build-Disk.cmd` to create a reproducible
system image. Run `Install-Disk.cmd` to back up the current working image and
install the generated image. Close MAME before importing or installing.

The complete syscall reference is [`../NDOS-SYSCALL-ABI.md`](../NDOS-SYSCALL-ABI.md).
Public C ABI constants are in `c/include/syscall.h`. Assembly constants and
the 20-byte disk-information layout are in `sdk/asm/ndos_syscall.inc`.
Syscall 8 accepts the destination address in A1 and returns zero on success or
a negative error in D0. The destination must lie wholly inside the current NEX
program region.

The development disk is 512 KiB: 1024 sectors, 512 bytes per sector, two FATs,
128 root entries, three sectors per FAT, and 1009 usable data clusters. It is
a MAME-persistent RAM-backed FAT12 volume, not yet a bootable SD-card image.

`CAT.NEX` is the syscall-9 reference application. `RUN CAT.NEX README.TXT`
reads the named file into its own user buffer through `NDOS_SYS_READ_FILE`,
prints exactly the returned byte count through `NDOS_SYS_PUTCHAR`, and exits
through `NDOS_SYS_EXIT`.  With no argument it defaults to `README.TXT`.

Syscall 10 enumerates decoded FAT12 root-directory entries.  Set D1 to the
visible entry index and A1 to a writable 24-byte `ndos_directory_entry`, then
execute `TRAP #0` with D0 set to `NDOS_SYS_READ_DIR`.  D0 returns zero with an
entry, one at end of directory, or a negative error.  On success D1 advances
to the next visible index.  Deleted entries, long-filename records, volume
labels, and directories are filtered by the portable C FAT12 layer.

Syscall 11 creates a new root-directory file. Pass the zero-terminated 8.3
name in A1, source bytes in A2, and the byte count in D1. It returns zero on
success or a negative FAT12 status. Existing files are never overwritten.
For a zero-length file, D1 is zero and A2 may be zero.

Syscall 12 reads an edited line from the interrupt-fed console queue. A1
points to a native-endian word capacity, a native-endian word returned length,
and `capacity+1` writable data bytes. Enter completes the call, Backspace and
Delete erase one character, and the returned data is zero terminated without
the Enter character. D0 returns zero and D1 returns the length.

The stable negative error values are: `-1` argument, `-2` I/O, `-3` invalid
filesystem, `-4` unsupported, `-5` not found, `-6` already exists, `-7` no
space, `-8` directory full, `-9` invalid name, `-10` corrupt chain, and `-11`
buffer too small.

Syscall 13 deletes a regular root-directory file. Pass its zero-terminated
8.3 name in A1. It returns zero on success or a stable negative error. The
directory entry is marked deleted and its complete FAT12 cluster chain is
released in both FAT copies.

Syscall 14 returns the current 32-bit NDOS development tick counter in D0.
The current MAME build feeds it from the MC68681 timer/counter at 100 Hz.
It is intended for relative delays and virtual benchmarks; it is not evidence
of physical MC68020 or final CPLD1 timer timing.
