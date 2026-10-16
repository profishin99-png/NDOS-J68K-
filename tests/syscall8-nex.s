        ORG     $00000000

        DC.L    $4E444F53
        DC.L    IMAGE_END-IMAGE_START
        DC.L    NEX_ENTRY-IMAGE_START
        DC.L    1024

IMAGE_START:
NEX_ENTRY:
        MOVE.L  #$12345678,D3
        MOVEQ   #8,D0
        LEA     DISK_INFO(PC),A1
        TRAP    #0
        TST.L   D0
        BNE     TEST_FAIL

        CMPI.L  #$0007E200,0(A1)
        BNE     TEST_FAIL
        CMPI.L  #$000003F1,8(A1)
        BNE     TEST_FAIL
        CMPI.L  #$00000200,16(A1)
        BNE     TEST_FAIL
        MOVE.L  12(A1),D1
        LSL.L   #8,D1
        LSL.L   #1,D1
        CMP.L   4(A1),D1
        BNE     TEST_FAIL
        CMPI.L  #$12345678,D3
        BNE     TEST_FAIL

        ; A destination outside the NEX region must be rejected safely.
        MOVEQ   #8,D0
        SUBA.L  A1,A1
        TRAP    #0
        CMPI.L  #-2,D0
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
        DC.B    13,10,'SYSCALL 8 DISK INFO: PASS',13,10,0
FAIL_TEXT:
        DC.B    13,10,'SYSCALL 8 DISK INFO: FAIL',13,10,0
        EVEN
DISK_INFO:
        DS.B    20
IMAGE_END:
        END     NEX_ENTRY
