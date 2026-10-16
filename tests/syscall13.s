        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG 0
START:
        LEA     NAME(PC),A1
        LEA     FILE_DATA_TEST(PC),A2
        MOVEQ   #4,D1
        MOVEQ   #NDOS_SYS_CREATE_FILE,D0
        TRAP    #0
        TST.L   D0
        BNE     .FAIL
        LEA     NAME(PC),A1
        MOVEQ   #NDOS_SYS_DELETE_FILE,D0
        TRAP    #0
        TST.L   D0
        BNE     .FAIL
        LEA     NAME(PC),A1
        LEA     BUFFER(PC),A2
        MOVEQ   #8,D1
        LEA     COUNT(PC),A3
        MOVEQ   #NDOS_SYS_READ_FILE,D0
        TRAP    #0
        CMPI.L  #NDOS_ERR_NOT_FOUND,D0
        BNE     .FAIL
        LEA     PASS(PC),A1
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
NAME: DC.B 'DELETE.TMP',0
FILE_DATA_TEST: DC.B 'TEST'
PASS: DC.B 13,10,'SYSCALL 13 DELETE PASSED',13,10,0
FAIL_TEXT: DC.B 13,10,'SYSCALL 13 DELETE FAILED',13,10,0
        EVEN
COUNT: DC.L 0
BUFFER: DS.B 8
        END START
