        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

START:
        LEA     TITLE_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        LEA     FILENAME_PROMPT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     FILENAME_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_LINE,D0
        TRAP    #0
        TST.L   D0
        BNE     INPUT_FAILED

        LEA     CONTENT_PROMPT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     CONTENT_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_READ_LINE,D0
        TRAP    #0
        TST.L   D0
        BNE     INPUT_FAILED

        ; D1 is the entered content length.  Both data fields are
        ; zero-terminated user buffers; syscall 11 uses the explicit size.
        LEA     FILENAME_BUFFER+NDOS_LINE_DATA(PC),A1
        LEA     CONTENT_BUFFER+NDOS_LINE_DATA(PC),A2
        MOVEQ   #NDOS_SYS_CREATE_FILE,D0
        TRAP    #0
        TST.L   D0
        BNE     CREATE_FAILED

        LEA     CREATED_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D1
        BRA     EXIT

INPUT_FAILED:
        LEA     INPUT_ERROR_TEXT(PC),A1
        BRA     PRINT_ERROR
CREATE_FAILED:
        LEA     CREATE_ERROR_TEXT(PC),A1
PRINT_ERROR:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #1,D1
EXIT:
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA     .HANG

TITLE_TEXT:
        DC.B    13,10,'NDOS WRITE 0.1',13,10,0
FILENAME_PROMPT:
        DC.B    'FILENAME (8.3): ',0
CONTENT_PROMPT:
        DC.B    'TEXT: ',0
CREATED_TEXT:
        DC.B    'FILE CREATED',13,10,0
INPUT_ERROR_TEXT:
        DC.B    'INPUT ERROR',13,10,0
CREATE_ERROR_TEXT:
        DC.B    'CREATE FAILED',13,10,0
        EVEN

; Up to twelve filename characters, for example "NOTES.TXT".
FILENAME_BUFFER:
        DC.W    12,0
        DS.B    13
        EVEN

; First WRITE version stores one text line of up to 240 bytes.
CONTENT_BUFFER:
        DC.W    240,0
        DS.B    241
        EVEN

        END     START
