        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0
START:
        LEA     PROMPT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     LINE_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_LINE,D0
        TRAP    #0
        TST.L   D0
        BNE     .FAIL
        CMPI.L  #3,D1
        BNE     .FAIL
        LEA     LINE_BUFFER(PC),A1
        CMPI.W  #3,NDOS_LINE_LENGTH(A1)
        BNE     .FAIL
        CMPI.L  #$61626400,NDOS_LINE_DATA(A1) ; "abd\0"
        BNE     .FAIL
        LEA     PASS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D1
        BRA     .EXIT
.FAIL:
        LEA     FAIL_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #1,D1
.EXIT:
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
        BRA     .EXIT
PROMPT: DC.B 13,10,'TYPE AC, BACKSPACE, BD, ENTER: ',0
PASS_TEXT: DC.B 'SYSCALL 12 BUFFERED INPUT PASSED',13,10,0
FAIL_TEXT: DC.B 'SYSCALL 12 BUFFERED INPUT FAILED',13,10,0
        EVEN
LINE_BUFFER:
        DC.W 8,0
        DS.B 9
        EVEN
        END START
