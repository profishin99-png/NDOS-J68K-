        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; -----------------------------------------------------------
; DELETE.NEX
; Deletes one FAT12 8.3 file through NDOS syscall 13.
; -----------------------------------------------------------

START:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        LEA     PROMPT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Read an 8.3 filename through syscall 12.
        LEA     FILENAME_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_LINE,D0
        TRAP    #0
        TST.L   D0
        BNE.S   INPUT_FAILED

        ; Reject an empty line before asking the filesystem to delete it.
        LEA     FILENAME_BUFFER(PC),A0
        TST.W   NDOS_LINE_LENGTH(A0)
        BEQ.S   INPUT_FAILED

        ; Syscall 13 receives a zero-terminated name in A1.
        LEA     FILENAME_BUFFER+NDOS_LINE_DATA(PC),A1
        MOVEQ   #NDOS_SYS_DELETE_FILE,D0
        TRAP    #0
        TST.L   D0
        BNE.S   DELETE_FAILED

        LEA     DELETED_TEXT(PC),A1
        BRA.S   PRINT_AND_EXIT

INPUT_FAILED:
        LEA     INPUT_ERROR_TEXT(PC),A1
        BRA.S   PRINT_AND_EXIT

DELETE_FAILED:
        LEA     DELETE_ERROR_TEXT(PC),A1

PRINT_AND_EXIT:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

TITLE:
        DC.B    13,10,'NDOS DELETE 0.1',13,10,0
PROMPT:
        DC.B    'FILE TO DELETE (8.3): ',0
DELETED_TEXT:
        DC.B    13,10,'FILE DELETED',13,10,0
INPUT_ERROR_TEXT:
        DC.B    13,10,'NO FILENAME ENTERED',13,10,0
DELETE_ERROR_TEXT:
        DC.B    13,10,'DELETE FAILED',13,10,0
        EVEN

; Syscall 12 buffer: capacity, returned length, then input plus terminator.
FILENAME_BUFFER:
        DC.W    12,0
        DS.B    13
        EVEN

        END     START
