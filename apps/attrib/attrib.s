        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; ATTRIB.NEX: set FAT12 READ_ONLY/HIDDEN/SYSTEM/ARCHIVE bits on one root file.
; Input is exactly two plain hexadecimal digits: 00 through 27.
START:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        LEA     FILENAME_PROMPT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     FILENAME_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_LINE,D0
        TRAP    #0
        TST.L   D0
        BNE.S   INPUT_FAILED
        LEA     FILENAME_BUFFER(PC),A0
        TST.W   NDOS_LINE_LENGTH(A0)
        BEQ.S   INPUT_FAILED

        LEA     ATTRIBUTE_PROMPT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     ATTRIBUTE_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_LINE,D0
        TRAP    #0
        TST.L   D0
        BNE.S   INPUT_FAILED
        LEA     ATTRIBUTE_BUFFER(PC),A0
        CMPI.W  #2,NDOS_LINE_LENGTH(A0)
        BNE.S   INPUT_FAILED

        ; Convert two ASCII hex characters into D1.B.
        LEA     ATTRIBUTE_BUFFER+NDOS_LINE_DATA(PC),A0
        MOVEQ   #0,D1
        MOVE.B  (A0)+,D1
        BSR.S   HEX_DIGIT_TO_NIBBLE
        TST.L   D0
        BNE.S   INPUT_FAILED
        LSL.L   #4,D1
        MOVE.L  D1,D2

        MOVEQ   #0,D1
        MOVE.B  (A0),D1
        BSR.S   HEX_DIGIT_TO_NIBBLE
        TST.L   D0
        BNE.S   INPUT_FAILED
        OR.L    D2,D1

        LEA     FILENAME_BUFFER+NDOS_LINE_DATA(PC),A1
        MOVEQ   #NDOS_SYS_SET_ATTRIBUTES,D0
        TRAP    #0
        TST.L   D0
        BNE.S   ATTRIBUTE_FAILED

        LEA     SUCCESS_TEXT(PC),A1
        MOVEQ   #0,D1
        BRA.S   PRINT_AND_EXIT

INPUT_FAILED:
        LEA     INPUT_ERROR_TEXT(PC),A1
        MOVEQ   #1,D1
        BRA.S   PRINT_AND_EXIT

ATTRIBUTE_FAILED:
        LEA     ATTRIBUTE_ERROR_TEXT(PC),A1
        MOVEQ   #1,D1

PRINT_AND_EXIT:
        MOVE.L  D1,D2
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D2,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

; D1.B = ASCII 0-9, A-F, or a-f.
; D1.B = binary nibble and D0.L = 0 when valid; D0.L = -1 when invalid.
HEX_DIGIT_TO_NIBBLE:
        CMPI.B  #'0',D1
        BLO.S   .INVALID
        CMPI.B  #'9',D1
        BLS.S   .DECIMAL
        CMPI.B  #'A',D1
        BLO.S   .LOWERCASE
        CMPI.B  #'F',D1
        BLS.S   .UPPERCASE
.LOWERCASE:
        CMPI.B  #'a',D1
        BLO.S   .INVALID
        CMPI.B  #'f',D1
        BHI.S   .INVALID
        SUBI.B  #'a'-10,D1
        BRA.S   .VALID
.UPPERCASE:
        SUBI.B  #'A'-10,D1
        BRA.S   .VALID
.DECIMAL:
        SUBI.B  #'0',D1
.VALID:
        MOVEQ   #0,D0
        RTS
.INVALID:
        MOVEQ   #-1,D0
        RTS

TITLE:
        DC.B    13,10,'NDOS ATTRIB 0.1',13,10,0
FILENAME_PROMPT:
        DC.B    'FILE (8.3): ',0
ATTRIBUTE_PROMPT:
        DC.B    'ATTRIBUTES ($00-$27): ',0
SUCCESS_TEXT:
        DC.B    13,10,'ATTRIBUTES UPDATED',13,10,0
INPUT_ERROR_TEXT:
        DC.B    13,10,'INPUT MUST BE A FILE NAME AND TWO HEX DIGITS',13,10,0
ATTRIBUTE_ERROR_TEXT:
        DC.B    13,10,'ATTRIBUTE UPDATE FAILED',13,10,0
        EVEN

FILENAME_BUFFER:
        DC.W    12,0
        DS.B    13
        EVEN
ATTRIBUTE_BUFFER:
        DC.W    2,0
        DS.B    3
        EVEN

        END     START
