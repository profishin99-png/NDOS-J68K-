# NDOS Virtual Addressing and CPLD1 Region-MMU Plan

**Status date:** 2026-09-28  
**Scope:** J68K Rev-A, NDOS, CPLD1, and the reduced MAME target.

## The important distinction

The present CPLD1 RTL has a **region permission framework**, not a virtual-memory implementation. Its `j68k_protection` block can deny user cycles outside a fixed compile-time base/mask region and always protects the supervisor core aperture. It does not translate CPU addresses into different SRAM addresses.

The MC68020 does not supply an integrated PMMU. The current J68K architecture also does not include an MC68851, page-table RAM, a TLB, or a page-fault handler. Therefore a Unix-style demand-paged virtual-memory system is outside Rev-A CPLD1 scope.

## Current status

| Capability | Current evidence | Status |
|---|---|---|
| 2 MiB physical SRAM | `$00000000-$001FFFFF` | VERIFIED |
| NDOS kernel at low SRAM | Kernel/vector/static areas currently use low SRAM | VERIFIED in NDOS source |
| NEX user load region | `$00010000-$0001FFFFF`, 64 KiB including image and stack | VERIFIED in NDOS source |
| User mode launch | NDOS creates a format-0 frame and uses `RTE` | VERIFIED in NDOS source/MAME workflow |
| Supervisor core aperture protection | User cycles to `$F0000000-$F0000FFF` are denied by current CPLD RTL | VERIFIED RTL/framework regression |
| Optional fixed user permission region | Compile-time base/mask/R/W/X hook, default disabled | VERIFIED framework; not a runtime ABI |
| Address translation | No translation, descriptors, page table, TLB, or run-time region register | DEFERRED |
| MAME region translation | No translation model | DEFERRED |
| Successful ATF1508AS target fit | Existing fit attempts failed | UNRESOLVED |

## The right Rev-A goal: region mapping, not paging

NDOS should use **fixed-size region mapping** if CPLD1 proves it can support it. Each user task sees the same small virtual range. CPLD1 selects a physical SRAM slot for the currently scheduled task.

```text
User-visible virtual address       Physical SRAM after region mapping
-----------------------------       ---------------------------------
$00010000-$0001FFFF                active task's 64 KiB physical slot
```

Example only ? physical slot addresses are deliberately not assigned yet:

```text
Task A sees $00010000-$0001FFFF  -> physical slot A
Task B sees $00010000-$0001FFFF  -> physical slot B
Kernel runs supervisor cycles     -> identity-mapped physical SRAM
```

This lets both tasks use the same link/load address and stack model. A context switch changes the active slot along with the saved register context.

## Larger programs and multi-slot allocation

**Planned, not implemented:** the current 64 KiB NEX region is an initial allocation unit, not a permanent per-program size limit. A later loader may reserve multiple adjacent 64 KiB units for one program and give that process a contiguous program/data allocation with a separately bounded stack. The allocator must check the whole requested extent before loading and reject overlaps with the kernel, other processes, RAM disk, I/O buffers, ROM aliases, and any active large-program/Doom reservation.

Until address translation exists, this is physical placement bookkeeping only. It prevents the loader from assigning overlapping ranges; it does not stop a running program from writing beyond its assigned extent. Keep the current two fixed NEX slots unchanged until the multi-slot allocator and its failure/reclamation tests are added.

## Why this is a later CPLD1 feature

The SRAM address pins are currently driven from CPU A2..A20. A true region map would need CPLD1 to produce an alternate SRAM address value for user SRAM cycles, conceptually:

```text
physical_sram_address = active_user_slot_base +
                        (cpu_address - USER_VIRTUAL_BASE)
```

It must do that for instruction fetches, reads, and writes while preserving:

- four independent SRAM byte lanes,
- ROM overlay behavior,
- SRAM CE#/OE#/WE#/BHE#/BLE# timing,
- DSACK/BERR timing,
- user/supervisor function-code checks,
- supervisor identity access to kernel, disk, and device memory,
- no translated access to the core-control aperture, ROM, DUART, FPU, or future ISA/DMA windows.

The existing implementation has neither the run-time slot register nor verified spare pin/resource/timing capacity for that work. The current failed ATF1508AS fit cannot be treated as proof that it fits.

## Proposed software ABI, before hardware exists

NDOS should create abstractions now, without claiming hardware mapping yet.

```asm
USER_VIRTUAL_BASE       EQU     $00010000
USER_VIRTUAL_LIMIT      EQU     $0001FFFF
USER_VIRTUAL_SIZE       EQU     $00010000
```

A PCB should later contain:

| PCB field | Purpose | Status |
|---|---|---|
| `physical_slot_base` | Physical SRAM base allocated to the process | PROPOSED |
| `virtual_base` | Normally `$00010000` for Rev. 1 tasks | PROPOSED |
| `region_size` | Initially 64 KiB | PROPOSED |
| `region_id` | Small slot number programmed during a context switch | PROPOSED |
| `permissions` | User R/W/X policy | PROPOSED |
| `signals`, `wait_mask`, `wake_tick` | Scheduler event state | PROPOSED |

For now, single-process NDOS keeps an **identity mapping**:

```text
virtual address == physical SRAM address
```

Do not alter the NEX file format yet. The NEX loader already assumes the fixed `$00010000` link/load address. With eventual region mapping, that same format can remain valid because every user task still sees `$00010000`.

## Context-switch requirement

A future context switch has two separate jobs:

```text
1. Save outgoing CPU context into outgoing PCB.
2. While in supervisor mode, select incoming process region/slot in CPLD1.
3. Restore incoming CPU context.
4. Return to user mode.
```

The region-selection write must be supervisor-only. User code must not choose another process's physical slot, disable protection, or re-enable the ROM overlay.

The exact core-control register offset, descriptor format, number of regions, fault-status format, and error/interrupt semantics remain **UNRESOLVED**. They must be centrally defined in the CPLD1 system-control ABI, not hard-coded through NDOS source files.

## Protection behavior needed when implemented

| User cycle target | Required result | Status |
|---|---|---|
| Inside active user virtual region with allowed access | Translate to active physical SRAM slot and complete normally | PROPOSED |
| Outside active user virtual region | No RAM select/write enable; return BERR through controlled CPLD path | PROPOSED |
| Core-control aperture `$F0000000-$F0000FFF` | Deny access | VERIFIED current RTL guard |
| DUART/FPU/future ISA/DMA windows | Deny unless a reviewed user ABI specifically authorizes it | PROPOSED |
| High ROM | Deny user writes; user reads/execution policy needs review | PROPOSED |
| Supervisor cycle | Preserve required kernel physical map | PROPOSED |

## MAME stages

1. Keep the present identity map while Scheduler Rev. 1 is built and tested.
2. Add MAME tests for user versus supervisor access denial before enabling any translation.
3. After a reviewed CPLD1 register contract exists, emulate a small fixed-region map in MAME.
4. Test Task A and Task B at the same virtual address and prove they read/write separate physical data.
5. Only then let NDOS program the MAME region selector during a context switch.
6. Treat this as a functional model until target fitting, timing, pin routing, and physical board testing prove it.

## Explicit non-goals for Rev. 1

- No demand paging.
- No page faults that load from disk.
- No TLB.
- No MC68030-style PMMU emulation.
- No arbitrary per-page protection.
- No copy-on-write or `fork()`.
- No user-mode access to CPLD1 system registers.

## Recommended order

1. Finish `DELETE.NEX` and filesystem-tool regression.
2. Implement two-task cooperative scheduling on the existing identity map.
3. Add the proposed 100 Hz timer model and virtual benchmarks.
4. Define and review the CPLD1 system-control/region register ABI.
5. Determine whether region remapping can fit, route, and meet timing on ATF1508AS-10AU100.
6. Add MAME fixed-region translation and tests.
7. Add the NDOS region-selector step to context switching.

This plan gives NDOS a consistent process ABI today while keeping the physical implementation honest: it is a compact region mapper if feasible, not a claimed full virtual-memory MMU.
