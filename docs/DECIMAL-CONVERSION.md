# NDOS unsigned decimal syscall

`TRAP #0` syscall 15, `NDOS_SYS_FORMAT_U32`, converts an unsigned 32-bit binary number to decimal text.

| Register | On entry | On return |
| --- | --- | --- |
| `D0` | syscall number 15 | decimal text length, 1 to 10 |
| `D1.L` | unsigned value, 0 to 4,294,967,295 | unspecified |
| `A1` | writable output buffer of at least 11 bytes | unspecified |

The buffer holds decimal ASCII without leading zeroes followed by a zero byte. `0` becomes `"0",0`.

The current kernel implementation is a fixed 32-round binary shift/add-3 conversion. It contains no `DIVU` or `DIVS`; this gives predictable conversion work and avoids a repeated divide-by-ten loop. The service converts to five packed-BCD bytes internally, then emits ASCII directly, so applications do not need an `UNPK` step or a BCD table. This is the verified baseline implementation, not yet a measured claim that it is the fastest possible 68020 conversion routine. The syscall ABI stays stable while we benchmark a reciprocal-long-multiply implementation as a possible faster internal replacement.

## Assembly call

```asm
        MOVE.L  #4294967295,D1
        LEA     DECIMAL_TEXT(PC),A1     ; reserve 11 bytes
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        ; D0 = 10, DECIMAL_TEXT = "4294967295",0

        LEA     DECIMAL_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

DECIMAL_TEXT:
        DC.B    0,0,0,0,0,0,0,0,0,0,0
```

`BENCH.NEX` now uses this service for both its integer-loop count and elapsed tick count.

The build verifies assembly, linking, NEX creation, ROM creation, and the system-disk image. Running `BENCH.NEX` in MAME after installing the rebuilt disk is the remaining functional console check; it is not an MC68020 physical timing measurement.
