        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; Noninteractive ATTRIB syscall regression.  The runner imports ATTEST.TXT
; into a private SD image before launching this program.
START:
        ; Set every supported bit, then verify unsupported volume-label bit
        ; is rejected without changing the existing attributes.
        MOVEQ   #$27,D1
        BSR     SET_ATTRIBUTES
        TST.L   D0
        BNE     .FAIL_1

        MOVEQ   #$08,D1
        BSR     SET_ATTRIBUTES
        CMPI.L  #NDOS_ERR_ARGUMENT,D0
        BNE     .FAIL_2

        ; Hidden files must not appear in the public root-directory iterator.
        BSR     SCAN_FOR_TARGET
        CMPI.L  #1,D0
        BNE     .FAIL_3

        ; Read-only files remain enumerable with their attributes intact,
        ; but deletion must be denied.
        MOVEQ   #$21,D1
        BSR     SET_ATTRIBUTES
        TST.L   D0
        BNE     .FAIL_4
        BSR     SCAN_FOR_TARGET
        TST.L   D0
        BNE     .FAIL_5
        CMPI.B  #$21,D2
        BNE     .FAIL_5
        BSR     DELETE_TARGET
        CMPI.L  #NDOS_ERR_ACCESS_DENIED,D0
        BNE     .FAIL_6

        ; System files are also hidden from enumeration and protected from
        ; deletion, even after the hidden bit is cleared.
        MOVEQ   #$24,D1
        BSR     SET_ATTRIBUTES
        TST.L   D0
        BNE     .FAIL_7
        BSR     SCAN_FOR_TARGET
        CMPI.L  #1,D0
        BNE     .FAIL_8
        BSR     DELETE_TARGET
        CMPI.L  #NDOS_ERR_ACCESS_DENIED,D0
        BNE     .FAIL_9

        ; Clear read-only/system and leave archive set.  The entry should be
        ; visible again, then deletion should succeed and lookup should fail.
        MOVEQ   #$20,D1
        BSR     SET_ATTRIBUTES
        TST.L   D0
        BNE     .FAIL_10
        BSR     SCAN_FOR_TARGET
        TST.L   D0
        BNE     .FAIL_11
        CMPI.B  #$20,D2
        BNE     .FAIL_11
        BSR     DELETE_TARGET
        TST.L   D0
        BNE     .FAIL_12

        LEA     TARGET_NAME(PC),A1
        LEA     READ_BUFFER(PC),A2
        MOVEQ   #8,D1
        LEA     READ_COUNT(PC),A3
        MOVEQ   #NDOS_SYS_READ_FILE,D0
        TRAP    #0
        CMPI.L  #NDOS_ERR_NOT_FOUND,D0
        BNE     .FAIL_13

        MOVEQ   #0,D1
        BRA.S   EXIT_TEST
.FAIL_1:  MOVEQ   #1,D1
        BRA.S   EXIT_TEST
.FAIL_2:  MOVEQ   #2,D1
        BRA.S   EXIT_TEST
.FAIL_3:  MOVEQ   #3,D1
        BRA.S   EXIT_TEST
.FAIL_4:  MOVEQ   #4,D1
        BRA.S   EXIT_TEST
.FAIL_5:  MOVEQ   #5,D1
        BRA.S   EXIT_TEST
.FAIL_6:  MOVEQ   #6,D1
        BRA.S   EXIT_TEST
.FAIL_7:  MOVEQ   #7,D1
        BRA.S   EXIT_TEST
.FAIL_8:  MOVEQ   #8,D1
        BRA.S   EXIT_TEST
.FAIL_9:  MOVEQ   #9,D1
        BRA.S   EXIT_TEST
.FAIL_10: MOVEQ   #10,D1
        BRA.S   EXIT_TEST
.FAIL_11: MOVEQ   #11,D1
        BRA.S   EXIT_TEST
.FAIL_12: MOVEQ   #12,D1
        BRA.S   EXIT_TEST
.FAIL_13: MOVEQ   #13,D1

EXIT_TEST:
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

SET_ATTRIBUTES:
        LEA     TARGET_NAME(PC),A1
        MOVEQ   #NDOS_SYS_SET_ATTRIBUTES,D0
        TRAP    #0
        RTS

DELETE_TARGET:
        LEA     TARGET_NAME(PC),A1
        MOVEQ   #NDOS_SYS_DELETE_FILE,D0
        TRAP    #0
        RTS

; Returns D0=0 and D2=attributes when found; D0=1 when the entry is absent.
; Negative D0 values from READ_DIR are passed through as errors.
SCAN_FOR_TARGET:
        MOVEQ   #0,D3
.NEXT_ENTRY:
        MOVE.L  D3,D1
        LEA     ENTRY_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_DIR,D0
        TRAP    #0
        CMPI.L  #1,D0
        BEQ.S   .NOT_FOUND
        TST.L   D0
        BMI.S   .SCAN_DONE
        MOVE.L  D1,D3

        LEA     TARGET_NAME(PC),A0
        LEA     ENTRY_BUFFER(PC),A2
        MOVEQ   #9,D4              ; ten characters in ATTEST.TXT
.COMPARE_NAME:
        MOVE.B  (A0)+,D5
        CMP.B   (A2)+,D5
        BNE.S   .NEXT_ENTRY
        DBRA    D4,.COMPARE_NAME

        MOVEQ   #0,D0
        MOVEQ   #0,D2
        MOVE.B  ENTRY_BUFFER+NDOS_DIR_ATTRIBUTES(PC),D2
        RTS
.NOT_FOUND:
        MOVEQ   #1,D0
.SCAN_DONE:
        RTS

TARGET_NAME:
        DC.B    'ATTEST.TXT',0
        EVEN
ENTRY_BUFFER:
        DS.B    NDOS_DIR_ENTRY_SIZE
READ_COUNT:
        DC.L    0
READ_BUFFER:
        DS.B    8
        END     START
