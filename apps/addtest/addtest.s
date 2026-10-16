        ORG     0
START:
        MOVEQ   #23,D1
        MOVEQ   #19,D2
        MOVEQ   #1,D0
        TRAP    #0
        CMPI.L  #42,D0
        BNE     TEST_FAIL

        MOVEQ   #42,D1
        MOVEQ   #19,D2
        MOVEQ   #2,D0
        TRAP    #0
        CMPI.L  #23,D0
        BNE     TEST_FAIL

        LEA     PASS_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #0,D1
        BRA     EXIT
TEST_FAIL:
        LEA     FAIL_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #1,D1
EXIT:
        MOVEQ   #4,D0
        TRAP    #0
        BRA     EXIT
PASS_TEXT:
        DC.B    13,10,'ADD/SUB SYSCALL TEST: PASS',13,10,0
FAIL_TEXT:
        DC.B    13,10,'ADD/SUB SYSCALL TEST: FAIL',13,10,0
        EVEN
        END     START
