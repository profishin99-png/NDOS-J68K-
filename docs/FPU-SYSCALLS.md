# NDOS floating-point syscall ABI

Syscalls 16 and 17 provide binary32 add/subtract in the current MAME development target.

## Proposed only: binary32 text formatting

`NDOS_SYS_FORMAT_F32` is a **PROPOSED** future service for converting a raw
IEEE-754 binary32 value into decimal text. It is not implemented or allocated:
there is no active syscall number, assembly include definition, C declaration,
or trap-dispatch entry. The candidate calling convention and open design choices
are recorded in [NDOS-SYSCALL-ABI.md](NDOS-SYSCALL-ABI.md#proposed-future-floating-point-formatting-service).

| Number | Name | Input | Output |
| ---: | --- | --- | --- |
| 16 | `NDOS_SYS_FADD_S` | `D1.L + D2.L` raw IEEE-754 single precision | `D0.L` raw IEEE-754 single precision sum |
| 17 | `NDOS_SYS_FSUB_S` | `D1.L - D2.L` raw IEEE-754 single precision | `D0.L` raw IEEE-754 single precision difference |

The values are bit patterns, not integer values. For example, `1.5` is `$3FC00000`, `2.25` is `$40100000`, and `3.75` is `$40700000`.

`FPUTEST.NEX` validates `1.5 + 2.25 = 3.75` and `3.75 - 2.25 = 1.5`.

**VERIFIED:** VASM accepts the MC68882 instructions and MAME is configured with `M68020FPU`.

**UNRESOLVED:** This does not validate an external physical MC68882 bus interface, its timing, exception wiring, or CPLD1 FPU-cycle support.
