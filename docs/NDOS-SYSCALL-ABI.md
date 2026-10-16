# NDOS system-call ABI

This is the single reference for the implemented NDOS application ABI.  It is
derived from the `SYSCALL_TABLE` in `ndos.s` and the public headers in
`sdk/asm/ndos_syscall.inc` and `c/include/syscall.h`.

## Calling convention

An application invokes a system call with `TRAP #0`:

```asm
        MOVEQ   #NDOS_SYS_PUTS,D0
        LEA     MESSAGE(PC),A1
        TRAP    #0
```

| Item | Rule |
|---|---|
| Trap | `TRAP #0` (vector `$80`) |
| Call number | `D0.L` before `TRAP #0` |
| Normal result | `D0.L = 0` or another non-negative result |
| Error result | `D0.L < 0`, using the stable error numbers below |
| Pointer validity | File and buffer pointers must point wholly inside the running NEX program region.  The kernel checks this for the calls documented as checked. |
| Register discipline | Preserve any register whose value you still need across a call, unless the call explicitly documents it as an output.  This is the safe rule while the ABI is still developing. |
| `TRAP #1` | Cooperative yield entry. It is **not** an NDOS `TRAP #0` syscall. It saves the current task context, selects the next `READY` task in round-robin PCB-table order (wrapping at the end), and returns to that task. |

`SYS_EXIT` does not return to the calling application. It records the exit
code and marks the task exited. In the current two-task `RUN2` model, if the
other task is `READY`, NDOS restores that task; when no task remains to run,
NDOS restores its kernel stack and returns to the command shell. The scheduler
and process model remain experimental: the 16 PCB records are reserved, but
general NEX allocation/launch across all 16 slots is not implemented.

### Task switching and exit

`TRAP #1` saves `D0-D7/A0-A6`, the task's `USP` and supervisor stack/context,
and its MC68881 state (`FSAVE` frame, `FP0-FP7`, `FPCR`, `FPSR`, and `FPIAR`)
in the current PCB. It marks the outgoing task `READY`, then scans forward for
the next `READY` PCB and wraps at the end of the table. The selected task is
restored and resumed with `RTE`. If no other task is ready, the outgoing task
can be selected again. This is an experimental scheduler contract, verified
in the reduced MAME target; it is not a hardware timing guarantee.

The MC68681 timer path can also preempt a task when an interrupt arrives from
user mode. It saves the same task CPU/FPU context and uses the same selector;
an interrupt while NDOS is already in supervisor mode updates the timer and
returns without switching tasks. Timer preemption is separate from invoking
`TRAP #1` and does not make `TRAP #1` a syscall.

## Implemented calls

| No. | Assembly name | Inputs | Outputs / behavior | Status |
|---:|---|---|---|---|
| 0 | `NDOS_SYS_INVALID` | none | `D0.L = -1` | Reserved invalid-call handler |
| 1 | `NDOS_SYS_ADD` | `D1.L`, `D2.L` | `D0.L = D1 + D2` modulo 32 bits | Implemented |
| 2 | `NDOS_SYS_SUB` | `D1.L`, `D2.L` | `D0.L = D1 - D2` modulo 32 bits | Implemented |
| 3 | `NDOS_SYS_VERSION` | none | `D0.L = $312E3031`, ASCII `"1.01"` | Implemented |
| 4 | `NDOS_SYS_EXIT` | `D1.L = application exit code` | Marks the active task exited and records its exit code. Resumes the other `READY` demo task if present; otherwise restores the kernel stack and returns to the command shell. Never returns to the caller. | Implemented for the current foreground/background two-task model; general process management is not implemented |
| 5 | `NDOS_SYS_PUTCHAR` | `D1.B = character` | Sends one character to the DUART console; `D0.L = 0` | Implemented |
| 6 | `NDOS_SYS_GETCHAR` | none | Waits for console input; `D0.L = 0` for an ordinary character, `2` after Enter, or `1` if the legacy 127-byte line buffer is full.  Console input is echoed and stored in the legacy line buffer. | Legacy compatibility call; prefer syscall 12 for new programs |
| 7 | `NDOS_SYS_PUTS` | `A1 = zero-terminated string` | Prints bytes through the terminating zero; `D0.L = 0` | Implemented |
| 8 | `NDOS_SYS_DISK_INFO` | `A1 = writable 20-byte `ndos_disk_info` | Fills disk capacity and free-space fields; `D0.L = 0`, or `-2` for an invalid destination | Implemented |
| 9 | `NDOS_SYS_READ_FILE` | `A1 = zero-terminated 8.3 name`; `A2 = destination`; `D1.L = destination capacity`; `A3 = writable longword byte-count result` | Reads one entire file.  On success `D0.L = 0` and `*(uint32_t *)A3` is bytes read. | Implemented |
| 10 | `NDOS_SYS_READ_DIR` | `D1.L = visible root-entry index`; `A1 = writable 24-byte `ndos_directory_entry` | `D0.L = 0` and `D1.L = next index` for an entry; `D0.L = 1` at end; negative error on failure | Implemented |
| 11 | `NDOS_SYS_CREATE_FILE` | `A1 = zero-terminated 8.3 name`; `A2 = source bytes` or zero for an empty file; `D1.L = byte count` | Creates a regular root-directory file.  Existing names are rejected.  `D0.L = 0` or a negative error. | Implemented |
| 12 | `NDOS_SYS_READ_LINE` | `A1 = writable `ndos_line_buffer` | Waits for Enter, edits the line, zero terminates it, and returns `D0.L = 0`, `D1.L = character count` | Implemented |
| 13 | `NDOS_SYS_DELETE_FILE` | `A1 = zero-terminated 8.3 name` | Deletes a regular root file and releases its FAT12 chain; `D0.L = 0` or a negative error | Implemented |
| 14 | `NDOS_SYS_GET_TICKS` | none | `D0.L =` monotonic 32-bit development tick count | MAME development interface; sourced by MC68681 timer at nominal 100 Hz |
| 15 | `NDOS_SYS_FORMAT_U32` | `D1.L = unsigned 32-bit value`; `A1 = writable buffer of at least 11 bytes` | Stores a zero-terminated decimal representation; `D0.L = decimal character count` | Implemented; keep ordinary values as initial use cases until dedicated runtime regression exists |
| 16 | `NDOS_SYS_FADD_S` | `D1.L`, `D2.L` are raw IEEE-754 binary32 bit patterns | `D0.L = D1 + D2` as raw binary32; uses `FP0` internally | MAME development target verified |
| 17 | `NDOS_SYS_FSUB_S` | `D1.L`, `D2.L` are raw IEEE-754 binary32 bit patterns | `D0.L = D1 - D2` as raw binary32; uses `FP0` internally | MAME development target verified |
| 18 | `NDOS_SYS_SET_ATTRIBUTES` | `A1 = zero-terminated 8.3 root-file name`; `D1.L = attribute mask` | Replaces the file's attributes. Allowed bits: read-only `$01`, hidden `$02`, system `$04`, archive `$20`. `D0.L = 0` on success; negative error on failure. | Implemented |
| 19 | `NDOS_SYS_READ_LARGE` | MAME-only large-loader service | Reads a chunk outside the standard 64 KiB NEX slot | Experimental; DOOMLOAD-only |
| 20 | `NDOS_SYS_POLLCHAR` | none | `D0.L = 1`, `D1.B = received byte` when a byte is queued; `D0.L = 0` when no byte is queued. It does not echo or update the legacy line buffer. | Implemented for nonblocking console clients |

## Proposed future floating-point formatting service

**PROPOSED — not implemented, not allocated, and not part of the current ABI.**

NDOS may later add a service tentatively named `NDOS_SYS_FORMAT_F32` so an
application can convert a raw IEEE-754 binary32 value to printable text. This
is needed for examples such as printing elapsed time after dividing a tick
count by the nominal 100 Hz development timer rate.

The following is a design candidate only. It is deliberately absent from the
active assembly include, C header, trap dispatcher, and syscall-number table:

| Candidate input/output | Proposed meaning |
| --- | --- |
| `D1.L` | Raw IEEE-754 binary32 bit pattern to format |
| `D2.L` | Requested digits after the decimal point |
| `A1` | Writable output buffer; a 32-byte minimum is proposed |
| `D0.L` | Decimal character count on success, or a documented negative error |

The first version is proposed to support ordinary finite values in fixed-point
notation. The rounding rule, accepted precision range, negative zero, NaN,
infinity, exponent notation, exact error numbers, and syscall number all need
review before this becomes an implemented NDOS contract. Applications must not
call a guessed number for this service.

## Structures and layouts

All multi-byte fields below use native MC68020 big-endian representation.
Applications do not need to interpret FAT12 on-disk little-endian structures.

### `ndos_disk_info` - syscall 8, 20 bytes

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | `total_bytes` - usable data-cluster bytes |
| 4 | 4 | `free_bytes` |
| 8 | 4 | `total_clusters` |
| 12 | 4 | `free_clusters` |
| 16 | 4 | `bytes_per_cluster` |

Assembly offsets: `NDOS_DISK_TOTAL_BYTES`, `NDOS_DISK_FREE_BYTES`,
`NDOS_DISK_TOTAL_CLUSTERS`, `NDOS_DISK_FREE_CLUSTERS`, and
`NDOS_DISK_BYTES_PER_CLUSTER`.

### `ndos_directory_entry` - syscall 10, 24 bytes

| Offset | Size | Field |
|---:|---:|---|
| 0 | 13 | `name` - zero-terminated canonical `NAME.EXT` |
| 13 | 1 | `attributes` |
| 14 | 2 | `first_cluster` |
| 16 | 4 | `size` in bytes |
| 20 | 4 | reserved, currently zero |

Assembly offsets: `NDOS_DIR_NAME`, `NDOS_DIR_ATTRIBUTES`,
`NDOS_DIR_FIRST_CLUSTER`, `NDOS_DIR_SIZE`, `NDOS_DIR_RESERVED`, and
`NDOS_DIR_ENTRY_SIZE`.

### `ndos_line_buffer` - syscall 12

| Offset | Size | Field |
|---:|---:|---|
| 0 | 2 | `capacity` - maximum characters, excluding the terminating zero |
| 2 | 2 | `length` - kernel-written character count |
| 4 | `capacity + 1` | `data` - zero-terminated result |

Enter completes the call.  Backspace and Delete remove one character.  Only
printable ASCII `$20` through `$7E` is accepted by the current implementation.

### FAT12 root-file attributes - syscall 18

`NDOS_SYS_SET_ATTRIBUTES` replaces the selected regular root file's attribute
byte; it does not merge the new mask with the old one. The only accepted bits
are read-only (`$01`), hidden (`$02`), system (`$04`), and archive (`$20`).
The volume-label (`$08`) and directory (`$10`) bits, long-name entries, and
other unsupported bits cannot be assigned through this syscall. A name that
does not identify a regular root file returns the corresponding FAT12 error.

The root-directory iterator (syscall 10) omits hidden and system files.
Deletion (syscall 13) returns `NDOS_ERR_ACCESS_DENIED` for files marked
read-only or system. Clear those bits with syscall 18 before deleting a file.
The dedicated regression exercises setting/clearing these bits, unsupported
bit rejection, enumeration filtering, and read-only/system deletion checks:

```text
python tools/test_attrib.py
```

The test builds a temporary NEX, imports it and an `ATTEST.TXT` fixture onto a
private copy of the generated SD image, and runs it in reduced MAME. It does
not modify the generated or live user disk image.

## Stable negative errors

| Value | Assembly constant | Meaning |
|---:|---|---|
| -1 | `NDOS_ERR_ARGUMENT` | Invalid argument |
| -2 | `NDOS_ERR_IO` | I/O failure or invalid checked user pointer |
| -3 | `NDOS_ERR_INVALID_FILESYSTEM` | FAT12 volume is invalid |
| -4 | `NDOS_ERR_UNSUPPORTED` | Operation is unsupported |
| -5 | `NDOS_ERR_NOT_FOUND` | File was not found |
| -6 | `NDOS_ERR_ALREADY_EXISTS` | A file with that name already exists |
| -7 | `NDOS_ERR_NO_SPACE` | No free data clusters remain |
| -8 | `NDOS_ERR_DIRECTORY_FULL` | No free root-directory entry remains |
| -9 | `NDOS_ERR_INVALID_NAME` | Invalid 8.3 filename |
| -10 | `NDOS_ERR_CORRUPT_CHAIN` | Invalid or corrupt FAT12 cluster chain |
| -11 | `NDOS_ERR_BUFFER_TOO_SMALL` | Caller-supplied buffer is too small |
|-12|    `NDOS_ERR_NDOS_ACCESS_DENIED`| file is unable to be acssesed  |

## Practical examples

Print a string:

```asm
        LEA     HELLO(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
```

Get the current timer tick count:

```asm
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D6                 ; preserve it before another syscall
```

Exit successfully:

```asm
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
```

## Source of truth and update rule

When adding a syscall, update these files in the same change:

1. `ndos.s`: dispatcher limit, table entry, and handler.
2. `sdk/asm/ndos_syscall.inc`: assembly number and any layout constants.
3. `c/include/syscall.h`: C number and public structure declarations.
4. This document: contract, inputs, outputs, errors, and status.
5. At least one application or regression that exercises the call.

Do not renumber existing calls.  Allocate the next free number after 17.


