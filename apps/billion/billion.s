        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

COUNT_LIMIT     EQU     1000000000
TICKS_PER_SEC   EQU     100             ; Current MAME timer rate (nominal)

START:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Capture the starting tick count.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,START_TICKS

        ; Count upward to one billion.
        MOVEQ   #0,D0
COUNT_LOOP:
        SUBQ.L  #1,D0
        CMP.L   #COUNT_LIMIT,D0
        BNE.S   COUNT_LOOP
        MOVE.L  D0,COUNT_RESULT

        ; Elapsed seconds are whole seconds from the nominal 100 Hz tick count.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        SUB.L   START_TICKS,D0
        MOVE.L  D0,ELAPSED_TICKS
        DIVU.L  #TICKS_PER_SEC,D0
        MOVE.L  D0,ELAPSED_SECONDS

        ; Print the final count.
        LEA     COUNT_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        MOVE.L  COUNT_RESULT,D1
        LEA     DECIMAL_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     DECIMAL_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Print elapsed whole seconds.
        LEA     TIME_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        MOVE.L  ELAPSED_SECONDS,D1
        LEA     DECIMAL_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     DECIMAL_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        LEA     SECONDS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

EXIT:
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0

EXIT_HANG:
        BRA.S   EXIT_HANG

TITLE:
        DC.B    13,10,'COUNTING TO ONE BILLION...',13,10,0
COUNT_TEXT:
        DC.B    'COUNT: ',0
TIME_TEXT:
        DC.B    13,10,'ELAPSED: ',0
SECONDS_TEXT:
        DC.B    ' SECONDS',13,10,0
        EVEN

START_TICKS:
        DS.L    1
ELAPSED_TICKS:
        DS.L    1
ELAPSED_SECONDS:
        DS.L    1
COUNT_RESULT:
        DS.L    1
DECIMAL_BUFFER:
        DS.B    11              ; 10 decimal digits plus NUL
        EVEN

        END     START
