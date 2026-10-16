        ORG     0

START:
        ; NEX startup ABI: D0=argc and A0=the optional zero-terminated
        ; argument.  Keep RUN CAT.NEX useful by defaulting to README.TXT.
        TST.L   D0
        BEQ     .USE_DEFAULT_NAME
        MOVEA.L A0,A1
        BRA     .HAVE_NAME
.USE_DEFAULT_NAME:
        LEA     FILE_NAME(PC),A1
.HAVE_NAME:
        MOVEQ   #9,D0
        LEA     FILE_BUFFER(PC),A2
        MOVE.L  #FILE_BUFFER_END-FILE_BUFFER,D1
        LEA     BYTES_READ(PC),A3
        TRAP    #0

        TST.L   D0
        BNE     READ_FAILED

        LEA     NEWLINE(PC),A1
        MOVEQ   #7,D0
        TRAP    #0

        LEA     FILE_BUFFER(PC),A2
        MOVE.L  BYTES_READ(PC),D2
.PRINT:
        TST.L   D2
        BEQ     SUCCESS
        MOVEQ   #0,D1
        MOVE.B  (A2)+,D1
        MOVEQ   #5,D0
        TRAP    #0
        SUBQ.L  #1,D2
        BRA     .PRINT

SUCCESS:
        LEA     NEWLINE(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #0,D1
        BRA     EXIT

READ_FAILED:
        LEA     ERROR_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #1,D1

EXIT:
        MOVEQ   #4,D0
        TRAP    #0
        BRA     EXIT

FILE_NAME:
        DC.B    'README.TXT',0
NEWLINE:
        DC.B    13,10,0
ERROR_TEXT:
        DC.B    13,10,'CAT: FILE READ FAILED',13,10,0
        EVEN
BYTES_READ:
        DC.L    0
FILE_BUFFER:
        DS.B    512
FILE_BUFFER_END:
        END     START
