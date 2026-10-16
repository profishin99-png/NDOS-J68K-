        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; -----------------------------------------------------------
; YIELDTEST.NEX
; -----------------------------------------------------------

START:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        MOVEQ   #8,D2
.LOOP:
        MOVEQ   #'A',D1
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0
        TRAP    #1

        LEA     GAME(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
      

        SUBQ.W  #1,D2
        BNE.S   .LOOP

        LEA     DONE_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

TITLE:
        DC.B    13,10,'NDOS YIELD TEST 0.1',13,10,0
DONE_TEXT:
        DC.B    13,10,'YIELD TEST COMPLETE',13,10,0
    GAME:
        DC.B    13,10,'GAME',13,10,0

        END     START
 
