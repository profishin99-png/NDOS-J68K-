        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

START:
        MOVEQ   #0,D1
        MOVEQ   #0,D2

.NEXT:
        LEA     DIRECTORY_ENTRY(PC),A1
        MOVEQ   #NDOS_SYS_READ_DIR,D0
        TRAP    #0
        TST.L   D0
        BMI     .FAIL
        CMPI.L  #1,D0
        BEQ     .END

        TST.L   D2
        BNE     .COUNTED
        CMPI.L  #$48454C4C,(A1)                  ; HELL
        BNE     .FAIL
        CMPI.L  #$4F2E4E45,4(A1)                 ; O.NE
        BNE     .FAIL
        CMPI.W  #$5800,8(A1)                     ; X\0
        BNE     .FAIL
        CMPI.L  #104,NDOS_DIR_SIZE(A1)
        BNE     .FAIL
        CMPI.W  #2,NDOS_DIR_FIRST_CLUSTER(A1)
        BNE     .FAIL
.COUNTED:
        ADDQ.L  #1,D2
        BRA     .NEXT

.END:
        CMPI.L  #8,D2             ; seven system files plus this test app
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

PASS_TEXT:
        DC.B    13,10,'SYSCALL 10 DIRECTORY ENUMERATION PASSED',13,10,0
FAIL_TEXT:
        DC.B    13,10,'SYSCALL 10 DIRECTORY ENUMERATION FAILED',13,10,0
        EVEN
DIRECTORY_ENTRY:
        DS.B    NDOS_DIR_ENTRY_SIZE
        END     START
