        ORG     0
START:
        MOVEQ   #8,D0
        LEA     INFO(PC),A1
        TRAP    #0
        TST.L   D0
        BNE     INFO_FAIL

        LEA     HEADER(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        LEA     TOTAL_LABEL(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVE.L  INFO(PC),D2
        BSR     PRINT_HEX
        LEA     FREE_LABEL(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVE.L  INFO+4(PC),D2
        BSR     PRINT_HEX
        LEA     CLUSTER_LABEL(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVE.L  INFO+12(PC),D2
        BSR     PRINT_HEX
        LEA     NEWLINE(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #0,D1
        BRA     EXIT
INFO_FAIL:
        LEA     FAIL_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #1,D1
EXIT:
        MOVEQ   #4,D0
        TRAP    #0
        BRA     EXIT

PRINT_HEX:
        MOVEQ   #7,D4
.DIGIT:
        ROL.L   #4,D2
        MOVEQ   #0,D1
        MOVE.B  D2,D1
        ANDI.B  #$0F,D1
        ADDI.B  #'0',D1
        CMPI.B  #'9',D1
        BLS     .OUT
        ADDQ.B  #7,D1
.OUT:
        MOVEQ   #5,D0
        TRAP    #0
        DBRA    D4,.DIGIT
        RTS

HEADER:        DC.B 13,10,'NDOS DISK INFORMATION',13,10,0
TOTAL_LABEL:   DC.B 'TOTAL BYTES:   $',0
FREE_LABEL:    DC.B 13,10,'FREE BYTES:    $',0
CLUSTER_LABEL: DC.B 13,10,'FREE CLUSTERS: $',0
NEWLINE:       DC.B 13,10,0
FAIL_TEXT:     DC.B 13,10,'DISK INFO SYSCALL FAILED',13,10,0
        EVEN
INFO:   DS.B 20
        END     START
