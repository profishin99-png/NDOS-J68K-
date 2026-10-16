;-----------------------------------------------------------
; Kernel unsigned-32-bit decimal conversion helpers
;
; U32_TO_PACKED_BCD uses fixed-work shift/add-3 conversion.
; It never uses DIVU or DIVS.
;-----------------------------------------------------------

; Input:  D0.L = unsigned binary value
;         A0   = writable five-byte BCD buffer
; Output: buffer = ten packed-BCD digits, most-significant byte first
; Clobbers: D0-D2, D6-D7, A1
U32_TO_PACKED_BCD:
        MOVEQ   #0,D1
        MOVE.L  D1,(A0)
        MOVE.B  D1,4(A0)
        MOVEQ   #31,D7
KDEC_ROUND:
        MOVEA.L A0,A1
        MOVEQ   #4,D6
KDEC_ADJUST_BYTE:
        MOVEQ   #0,D1
        MOVE.B  (A1),D1
        MOVE.B  D1,D2
        ANDI.B  #$0F,D2
        CMPI.B  #5,D2
        BLO.W   KDEC_LOW_DONE
        ADDI.B  #3,D1
KDEC_LOW_DONE:
        MOVE.B  D1,D2
        ANDI.B  #$F0,D2
        CMPI.B  #$50,D2
        BLO.W   KDEC_HIGH_DONE
        ADDI.B  #$30,D1
KDEC_HIGH_DONE:
        MOVE.B  D1,(A1)+
        DBRA    D6,KDEC_ADJUST_BYTE

        ; X receives the next source bit.  Predecrement addressing leaves X
        ; alone between ROXL operations, so the carry moves through all bytes.
        ADD.L   D0,D0
        LEA     5(A0),A1
        MOVEQ   #4,D6
KDEC_SHIFT_BCD:
        MOVE.B  -(A1),D1
        ROXL.B  #1,D1
        MOVE.B  D1,(A1)
        DBRA    D6,KDEC_SHIFT_BCD
        DBRA    D7,KDEC_ROUND
        RTS

; Input:  A0 = five packed BCD bytes from U32_TO_PACKED_BCD
;         A2 = output buffer, at least 11 bytes
; Output: D0.L = decimal length (1 through 10), output is NUL terminated
; Clobbers: D0-D1, D6-D7, A1-A2
PACKED_BCD_TO_ASCII:
        MOVEA.L A0,A1
        MOVEQ   #9,D7
        MOVEQ   #4,D6
        MOVEQ   #0,D0
KDEC_NEXT_BYTE:
        MOVEQ   #0,D1
        MOVE.B  (A1)+,D1
        MOVE.B  D1,D2
        LSR.B   #4,D2
        BSR.W   KDEC_DIGIT
        MOVE.B  D1,D2
        ANDI.B  #$0F,D2
        BSR.W   KDEC_DIGIT
        DBRA    D6,KDEC_NEXT_BYTE
        CLR.B   (A2)
        RTS
KDEC_DIGIT:
        TST.B   D2
        BNE.W   KDEC_EMIT
        TST.W   D7
        BEQ.W   KDEC_EMIT
        BRA.W   KDEC_DONE
KDEC_EMIT:
        ADDI.B  #'0',D2
        MOVE.B  D2,(A2)+
        ADDQ.L  #1,D0
KDEC_DONE:
        SUBQ.W  #1,D7
        RTS
