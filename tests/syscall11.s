        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0
START:
        LEA     FILE_NAME(PC),A1
        LEA     FILE_DATA(PC),A2
        MOVE.L  #FILE_DATA_END-FILE_DATA,D1
        MOVEQ   #NDOS_SYS_CREATE_FILE,D0
        TRAP    #0
        TST.L   D0
        BNE     .FAIL

        LEA     FILE_NAME(PC),A1
        LEA     READ_BUFFER(PC),A2
        MOVE.L  #64,D1
        LEA     BYTES_READ(PC),A3
        MOVEQ   #NDOS_SYS_READ_FILE,D0
        TRAP    #0
        TST.L   D0
        BNE     .FAIL
        CMPI.L  #FILE_DATA_END-FILE_DATA,BYTES_READ(PC)
        BNE     .FAIL

        LEA     FILE_DATA(PC),A2
        LEA     READ_BUFFER(PC),A3
        MOVE.L  #FILE_DATA_END-FILE_DATA,D2
.COMPARE:
        CMPM.B  (A2)+,(A3)+
        BNE     .FAIL
        SUBQ.L  #1,D2
        BNE     .COMPARE
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

FILE_NAME: DC.B 'ELEVEN.TXT',0
FILE_DATA: DC.B 'CREATED THROUGH SYSCALL 11',13,10
FILE_DATA_END:
PASS_TEXT: DC.B 13,10,'SYSCALL 11 CREATE/READBACK PASSED',13,10,0
FAIL_TEXT: DC.B 13,10,'SYSCALL 11 CREATE/READBACK FAILED',13,10,0
        EVEN
BYTES_READ: DC.L 0
READ_BUFFER: DS.B 64
        END START
