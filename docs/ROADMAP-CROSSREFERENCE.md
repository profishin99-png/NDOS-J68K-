# NDOS Roadmap Cross-Reference

This tracks the earlier NDOS roadmap against the current source, generated system disk, MAME behavior, and the newer scheduler/virtual-region decisions.

## Earlier roadmap status

| Earlier roadmap item | Current disposition | Evidence / next action |
|---|---|---|
| Finish and test syscall 9 file read | COMPLETE | `SYS_READ_FILE` exists; `CAT.NEX` uses it. Retain regression coverage. |
| Build `CAT.NEX` | COMPLETE | Built and included on the system disk. |
| Add one NEX command-line argument | COMPLETE | `RUN FILE.NEX ARGUMENT` has a one-string argument ABI. Multiple argument parsing is later work. |
| Add syscall 10 directory enumeration | COMPLETE | `SYS_READ_DIR` exists; `LS.NEX` uses it. |
| Build `LS.NEX` | COMPLETE | Built and included on the system disk. |
| Add syscall 11 file creation | COMPLETE | `SYS_CREATE_FILE` exists; `WRITE.NEX` uses it. |
| Build `WRITE.NEX` | COMPLETE | Built and included on the system disk. It creates one short text line. |
| Define stable NDOS error numbers | COMPLETE | Public C and assembly headers define errors `-1` through `-11`. Improve user-facing decoded messages later. |
| Add delete | COMPLETE | Syscall 13 exists. `DELETE.NEX` is built, installed, and MAME-tested against `README.TXT`. |
| Add file handles and streaming I/O | NEXT FILESYSTEM MILESTONE | Current calls read or create whole files. Design an `OPEN/READ/WRITE/CLOSE` ABI before adding larger tools. |
| Add a kernel memory allocator | NOT STARTED | First define static kernel ranges, user physical slots, allocator metadata, and allocation/free ownership. Do this after the two-task scheduler basic test. |
| Harden process-failure recovery | PARTIALLY COMPLETE | Current `KERNAL_PANIC` recovers one faulting user process to the shell. Add malformed-NEX, illegal-instruction, privilege, and process-cleanup regressions. |
| Add two-process cooperative scheduler | COMPLETE | Shared PCB layout, private contexts, A -> B -> A switching, Task B exit recovery, and the isolated MAME regression pass. |
| Add BIOS loader for NDOS | COMPLETE | High-ROM BIOS POST, overlay clear, SRAM validation, NDOS copy, DUART initialization, and handoff are in the current build/MAME workflow. |
| Return to CPLD1/CPLD2 and physical storage | LATER, IN PARALLEL WITH ABI DESIGN | NDOS now needs timer/IRQ/region requirements documented before CPLD register ABI/fitting work resumes. |

## Earlier storage roadmap status

| Earlier storage item | Current disposition |
|---|---|
| 64 KiB RAM disk | SUPERSEDED by the current 512 KiB persistent FAT12 RAM disk (`1024 x 512-byte sectors`) |
| BLOCK_READ / BLOCK_WRITE | COMPLETE in the portable C/platform adapter and filesystem path |
| 512-byte sector tests | COMPLETE for the current 512 KiB disk model |
| Full RAM-disk verification | PARTIALLY COMPLETE; block/FAT operations are covered, but add a capacity sweep and long-run create/delete test later |
| FAT12 | COMPLETE baseline; retain for the RAM disk |
| FAT16 for larger storage | DEFERRED until an SD-card or larger virtual disk needs it |
| FAT32 mount | DEFERRED; it is not needed by the present RAM-disk design |
| Root directory iterator | COMPLETE through syscall 10 / `LS.NEX` |
| `DIR` | COMPLETE as a shell command; `LS.NEX` proves the user-program path |
| `TYPE` | COMPLETE for `.TXT` files |
| File allocation and cluster chain read/write | COMPLETE for current create/read/delete path; streaming API still needed |
| Store/run NEX from disk | COMPLETE; system disk contains NEX programs and `RUN` loads them |

## New work added after the earlier roadmap

| New item | Why it was added | Status |
|---|---|---|
| `DELETE.NEX` | Completes the core create/read/list/delete tool loop | COMPLETE |
| Scheduler Rev. 1 contract | Defines two-task cooperative multitasking before timer preemption | PROPOSED; documented |
| 100 Hz timer contract | Gives NDOS a common time base for scheduling, sleep, and benchmarks | PROPOSED; source has a vector/counter stub only |
| Signal/wait model | Lets keyboard, timer, disk, and later ISA IRQs wake tasks safely | PROPOSED |
| `VBENCH.NEX` | Measures functional performance regressions in MAME | DEFERRED until a real MAME tick source exists |
| Region virtual addressing | Supports two task-local 64 KiB views without pretending to have paging | PROPOSED; depends on future CPLD1 feasibility |
| MAME virtual-region mapper | Functional model for later CPLD1 mapping ABI | DEFERRED |
| Two copies of one NEX image | Validates separate physical slots and independent PCB contexts | COMPLETE prototype; `RUN2 FILE.NEX` passes the two-instance `YIELD.NEX` regression |
| General multi-NEX spawning / two different filenames | Extends the prototype to a general process loader | DEFERRED; finish active-PCB validation and per-process arguments first |

## Current priority order

```text
1. Brian’s Brain NEX worker with left/right display ownership
2. Active-PCB pointer validation for Slot B system calls
3. Timer-integrated scheduler regression without timer preemption
4. Generalize `RUN2` into multi-NEX spawning and per-process arguments
5. Harden user-process failure recovery
6. MAME 100 Hz tick accounting, 50 ms quantum, NEED_RESCHED
7. VBENCH INT and VBENCH MEM
8. Signals, WAIT, SLEEP, keyboard wakeup
9. File-handle and streaming I/O ABI
10. Kernel allocator and physical process-slot allocation
11. CPLD1 timer/IRQ/region-register ABI review
12. MAME region-mapping model
13. CPLD1 target-fit/timing/pin work
14. CPLD2 ISA, arbitration, DMA, then graphics
```

## What remains deliberately out of scope for now

- Demand-paged virtual memory
- Page tables, TLBs, MC68851/68030 PMMU behavior
- FAT16/FAT32 before a larger storage device exists
- CPLD2 implementation before ISA/DMA ownership contracts are defined
- ISA VGA emulation before the kernel timer/process and device-driver model are stable
- Declaring CPLD1 frozen or fitted
