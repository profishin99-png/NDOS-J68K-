        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; BRAIN.NEX -- first Brian's Brain display worker.
; D7=0 selects the left display region; D7=1 selects the right region.
; The finite frame count gives the first test a clean way back to NDOS.

START:
        ; Task A clears the terminal once; Task B must not erase its peer.
        CMPI.L  #1,D7
        BEQ.S   .NO_CLEAR
        LEA     CLEAR_SCREEN(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
.NO_CLEAR:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D4
        MOVE.W  #300,D5
        CLR.L   D6
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D3

.FRAME:
        CMPI.L  #1,D7
        BNE.S   .LEFT_PANEL
        LEA     TITLE_RIGHT(PC),A1
        BRA.S   .TITLE
.LEFT_PANEL:
        LEA     TITLE_LEFT(PC),A1
.TITLE:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        CMPI.L  #1,D7
        ADDQ.L  #1,D6
        BSR.S   PRINT_STATS
        CMPI.L  #1,D7
        BEQ.S   .RIGHT_FRAME
        TST.W   D4
        BEQ.S   .DRAW_LEFT_A
        LEA     FRAME_LEFT_B(PC),A1
        BRA.S   .DRAW
.DRAW_LEFT_A:
        LEA     FRAME_LEFT_A(PC),A1
        BRA.S   .DRAW
.RIGHT_FRAME:
        TST.W   D4
        BEQ.S   .DRAW_RIGHT_A
        LEA     FRAME_RIGHT_B(PC),A1
        BRA.S   .DRAW
.DRAW_RIGHT_A:
        LEA     FRAME_RIGHT_A(PC),A1
.DRAW:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        EORI.W  #1,D4
        SUBQ.W  #1,D5
        BEQ.S   .EXIT
        ; Render at 10 Hz.  Yield while waiting so the other worker runs.
        ADDI.L  #10,D3
.WAIT_NEXT_FRAME:
        TRAP    #1
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        CMP.L   D3,D0
        BLO.S   .WAIT_NEXT_FRAME
        BRA.S   .FRAME
.EXIT:
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

; D6 = this worker's generation count.  D7 chooses the fixed status line.
PRINT_STATS:
        CMPI.L  #1,D7
        BNE.S   .LEFT_STATS
        LEA     STATS_RIGHT(PC),A1
        BRA.S   .STATS_CURSOR
.LEFT_STATS:
        LEA     STATS_LEFT(PC),A1
.STATS_CURSOR:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     STATS_PREFIX(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D6,D1
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     TICK_PREFIX(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D1
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        RTS

TITLE:
        DC.B    27,'[1;1H','BRIAN''S BRAIN / TWO WORKERS',0
CLEAR_SCREEN:
        DC.B    27,'[2J',27,'[H',0
TITLE_LEFT:
        DC.B    27,'[2;1H','TASK A / LEFT',0
TITLE_RIGHT:
        DC.B    27,'[2;42H','TASK B / RIGHT',0
STATS_LEFT:
        DC.B    27,'[3;1H',0
STATS_RIGHT:
        DC.B    27,'[3;42H',0
STATS_PREFIX:
        DC.B    'GEN:',0
TICK_PREFIX:
        DC.B    ' TICK:',0
; Every row is positioned independently.  CR/LF would reset a right-side
; row back to column 1 on the serial terminal.
FRAME_LEFT_A:
        DC.B 27,'[4;1H        ',27,'[5;1H   ##   ',27,'[6;1H  ####  ',27,'[7;1H ##  ## '
        DC.B 27,'[8;1H ##  ## ',27,'[9;1H  ####  ',27,'[10;1H   ##   ',27,'[11;1H        ',0
FRAME_LEFT_B:
        DC.B 27,'[4;1H        ',27,'[5;1H    #   ',27,'[6;1H   ###  ',27,'[7;1H  ##### '
        DC.B 27,'[8;1H   ###  ',27,'[9;1H    #   ',27,'[10;1H        ',27,'[11;1H        ',0
FRAME_RIGHT_A:
        DC.B 27,'[4;42H        ',27,'[5;42H   ##   ',27,'[6;42H  ####  ',27,'[7;42H ##  ## '
        DC.B 27,'[8;42H ##  ## ',27,'[9;42H  ####  ',27,'[10;42H   ##   ',27,'[11;42H        ',0
FRAME_RIGHT_B:
        DC.B 27,'[4;42H        ',27,'[5;42H    #   ',27,'[6;42H   ###  ',27,'[7;42H  ##### '
        DC.B 27,'[8;42H   ###  ',27,'[9;42H    #   ',27,'[10;42H        ',27,'[11;42H        ',0
NUMBER_BUFFER:
        DS.B    11

        END     START
