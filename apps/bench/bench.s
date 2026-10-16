        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; -----------------------------------------------------------
; BENCH.NEX
; Counts a fixed integer/branch workload over 100 NDOS timer
; ticks.  Results compare virtual NDOS builds only; they are
; not a physical MC68020 MHz measurement.
; -----------------------------------------------------------

BENCH_TICKS     EQU     100
COUNT_LIMIT     EQU     100000

START:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D6                   ; start tick
        MOVE.L  D0,D4
        ADDI.L  #BENCH_TICKS,D4          ; target tick
        CLR.L   D3                       ; completed integer operations
        trap #1

.OUTER:
        MOVE.W  #255,D5
.INNER:

        ; Start time.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D6           ; start tick

        CLR.L   D1              ; current count
        MOVE.L  #COUNT_LIMIT,D2 ; count target

.COUNT:
        ADDQ.L  #1,D1
        CMP.L   D2,D1
        BLO.S   .COUNT

        MOVE.L  D1,D7           ; final count, should be 10000

        ; End time.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        SUB.L   D6,D0
        MOVE.L  D0,D5           
        trap #1
        ; The MC68681 development timer is 100 Hz, so one tick is one
        ; hundredth of a second.  Derive elapsed seconds and hundredths
        ; without assuming the benchmark ended on exactly 100 ticks.
        MOVE.L  D5,D0
        CLR.L   D2                       ; whole elapsed seconds
.SECONDS:
        CMPI.L  #100,D0
        BLO.S   .SECONDS_DONE
        SUBI.L  #100,D0
        ADDQ.L  #1,D2
        BRA.S   .SECONDS
.SECONDS_DONE:
        MOVE.L  D0,D4                    ; remaining hundredths, 0..99

        LEA     LOOPS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D3,D0
        BSR     PRINT_U32_DEC

        LEA     TICKS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D5,D0
        BSR     PRINT_U32_DEC

        LEA     TIME_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D2,D0
        BSR     PRINT_U32_DEC
        MOVE.B  #'.',D1
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0
        MOVE.L  D4,D0
        BSR     PRINT_TWO_DIGITS
        LEA     SECONDS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        LEA     CHECKSUM_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D7,D0
        BSR     PRINT_U32_DEC

        LEA     NOTE_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

; D0.L = unsigned value.  Converts locally so benchmark reporting does not
; depend on the still-unverified kernel formatting syscall.
PRINT_U32_DEC:
        MOVEM.L D0-D7/A0-A2,-(A7)
        LEA     BCD_BUFFER(PC),A0
        BSR     BENCH_U32_TO_PACKED_BCD
        LEA     DECIMAL_BUFFER(PC),A2
        BSR     BENCH_PACKED_BCD_TO_ASCII
        LEA     DECIMAL_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEM.L (A7)+,D0-D7/A0-A2
        RTS

; D0.L = 0..99.  Prints exactly two decimal digits.
PRINT_TWO_DIGITS:
        MOVE.L  D0,D3
        CMPI.L  #10,D0
        BHS.S   .OUTPUT_VALUE
        MOVE.B  #'0',D1
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0
.OUTPUT_VALUE:
        MOVE.L  D3,D0
        BSR     PRINT_U32_DEC
        RTS
        

; D0.L = elapsed 100 Hz tick count.
; Output: D2.L = whole seconds, D4.L = remaining hundredths (0..99).
SPLIT_TICKS:
        CLR.L   D2
.SECONDS:
        CMPI.L  #100,D0
        BLO.S   .DONE
        SUBI.L  #100,D0
        ADDQ.L  #1,D2
        BRA.S   .SECONDS
.DONE:
        MOVE.L  D0,D4
        RTS

; D0.L = unsigned binary value; A0 = five-byte BCD buffer.
; Fixed-work shift/add-3 conversion, with no division instruction.
BENCH_U32_TO_PACKED_BCD:
        MOVEQ   #0,D1
        MOVE.L  D1,(A0)
        MOVE.B  D1,4(A0)
        MOVEQ   #31,D7
.ROUND:
        MOVEA.L A0,A1
        MOVEQ   #4,D6
.ADJUST_BYTE:
        MOVEQ   #0,D1
        MOVE.B  (A1),D1
        MOVE.B  D1,D2
        ANDI.B  #$0F,D2
        CMPI.B  #5,D2
        BLO.S   .LOW_DONE
        ADDI.B  #3,D1
.LOW_DONE:
        MOVE.B  D1,D2
        ANDI.B  #$F0,D2
        CMPI.B  #$50,D2
        BLO.S   .HIGH_DONE
        ADDI.B  #$30,D1
.HIGH_DONE:
        MOVE.B  D1,(A1)+
        DBRA    D6,.ADJUST_BYTE

        ADD.L   D0,D0
        LEA     5(A0),A1
        MOVEQ   #4,D6
.SHIFT_BCD:
        MOVE.B  -(A1),D1
        ROXL.B  #1,D1
        MOVE.B  D1,(A1)
        DBRA    D6,.SHIFT_BCD
        DBRA    D7,.ROUND
        RTS

; A0 = five packed BCD bytes; A2 = 11-byte ASCII destination.
BENCH_PACKED_BCD_TO_ASCII:
        MOVEA.L A0,A1
        MOVEQ   #9,D7
        MOVEQ   #4,D6
        MOVEQ   #0,D0
.NEXT_BYTE:
        MOVEQ   #0,D1
        MOVE.B  (A1)+,D1
        MOVE.B  D1,D2
        LSR.B   #4,D2
        BSR.S   .DIGIT
        MOVE.B  D1,D2
        ANDI.B  #$0F,D2
        BSR.S   .DIGIT
        DBRA    D6,.NEXT_BYTE
        CLR.B   (A2)
        RTS
.DIGIT:
        TST.B   D2
        BNE.S   .EMIT
        TST.W   D7
        BEQ.S   .EMIT
        BRA.S   .DONE
.EMIT:
        ADDI.B  #'0',D2
        MOVE.B  D2,(A2)+
        ADDQ.L  #1,D0
.DONE:
        SUBQ.W  #1,D7
        RTS

TITLE:
        DC.B    13,10,'NDOS VIRTUAL BENCH 0.1',13,10,0
LOOPS_TEXT:
        DC.B    'INTEGER LOOPS: ',0
TICKS_TEXT:
        DC.B    13,10,'ELAPSED TICKS: ',0
TIME_TEXT:
        DC.B    13,10,'ELAPSED TIME: ',0
SECONDS_TEXT:
        DC.B    ' SECONDS',0
CHECKSUM_TEXT:
        DC.B    13,10,'CHECKSUM: ',0
NOTE_TEXT:
        DC.B    13,10,'100 HZ DUART TIMER / NOT PHYSICAL MHZ',13,10,0
DECIMAL_BUFFER:
        DC.B    0,0,0,0,0,0,0,0,0,0,0
BCD_BUFFER:
        DC.B    0,0,0,0,0
        END     START
