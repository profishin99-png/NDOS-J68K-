        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'
        ORG     0

SCREEN_W        EQU     320
SCREEN_H        EQU     200
BALL_SIZE       EQU     5
PADDLE_W        EQU     40
PADDLE_H        EQU     5
PADDLE_Y        EQU     190
PADDLE_ACCEL    EQU     5       ; pixels/tick^2 while a direction is held
PADDLE_TAP_IMPULSE EQU  4       ; initial speed for a one-shot A/D press
PADDLE_FRICTION EQU     1       ; speed lost each tick after release
PADDLE_MAX_SPEED EQU    90      ; 700 pixels/second at the 100 Hz game tick
COURT_TOP       EQU     30

BALL_X_OFF      EQU     0
BALL_Y_OFF      EQU     2
BALL_DX_OFF     EQU     4
BALL_DY_OFF     EQU     6
PADDLE_X_OFF    EQU     8
LAST_TICK_OFF   EQU     10
SCORE_OFF       EQU     14
MISSES_OFF      EQU     18

COLOR_BLACK     EQU     $00
COLOR_GREEN     EQU     $1C
COLOR_YELLOW    EQU     $FC
COLOR_RED       EQU     $E0

KBD_STAT        EQU     VIRTUAL_INPUT_BASE
KBD_DATA        EQU     VIRTUAL_INPUT_BASE+4

; Small single-player Pong/Squash demo for the temporary MAME framebuffer.
; A/D works in the serial terminal; held A/D or arrow keys work in the MAME
; game window. Q returns to the NDOS shell.
START:
        LEA     GAME_STATE(PC),A5
        LEA     TITLE_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        BSR.W   CLEAR_SCREEN
        BSR.W   DRAW_COURT
        BSR.W   DRAW_HUD
        BSR.W   DRAW_BALL
        BSR.W   DRAW_PADDLE

        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,LAST_TICK_OFF(A5)

MAIN_LOOP:
        BSR.W   WAIT_TICK
        BSR.W   ERASE_BALL
        BSR.W   ERASE_PADDLE
        BSR.W   HANDLE_INPUT
        BSR.W   UPDATE_PADDLE
        BSR.W   UPDATE_STATE
        BSR.W   DRAW_BALL
        BSR.W   DRAW_PADDLE
        BSR.W   DRAW_COURT
        BSR.W   DRAW_HUD
        BRA.W   MAIN_LOOP

; Wait for one 100 Hz NDOS tick so movement remains bounded and smooth.
WAIT_TICK:
        MOVE.L  D1,-(A7)
.WAIT:
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  LAST_TICK_OFF(A5),D1
        CMP.L   D1,D0
        BEQ.S   .WAIT
        MOVE.L  D0,LAST_TICK_OFF(A5)
        MOVE.L  (A7)+,D1
        RTS

DO_EXIT:
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.EXIT_HANG:
        BRA.S   .EXIT_HANG

; Read held game-window controls first, then one-shot MAME or serial input.
; POLLCHAR is nonblocking, so gameplay never waits on input.
HANDLE_INPUT:
        CLR.B   PADDLE_INPUT_OFF(A5)
        MOVE.L  KBD_STAT,D5
        BTST    #2,D5
        BNE.W   DO_EXIT
        BTST    #31,D5
        BEQ.S   .CHECK_HELD_LEFT
        BTST    #0,D5
        BNE.S   .DISCARD_QUEUED
        BTST    #1,D5
        BEQ.S   .CHECK_HELD_LEFT
.DISCARD_QUEUED:
        MOVE.L  KBD_DATA,D0
.CHECK_HELD_LEFT:
        BTST    #0,D5
        BNE.S   .LEFT_HELD
        BTST    #1,D5
        BNE.S   .RIGHT_HELD
        BTST    #31,D5
        BNE.S   .MAME_QUEUE

.SERIAL:
        MOVEQ   #NDOS_SYS_POLLCHAR,D0
        TRAP    #0
        TST.L   D0
        BEQ.W   .DONE
        MOVE.B  D1,D0
        BRA.S   .PROCESS_KEY

.MAME_QUEUE:
        MOVE.L  KBD_DATA,D0
        SWAP    D0
        LSR.W   #8,D0

.PROCESS_KEY:
        CMPI.B  #'q',D0
        BEQ.W   DO_EXIT
        CMPI.B  #'Q',D0
        BEQ.W   DO_EXIT
        CMPI.B  #'a',D0
        BEQ.S   .LEFT
        CMPI.B  #'A',D0
        BEQ.S   .LEFT
        CMPI.B  #'d',D0
        BEQ.S   .RIGHT
        CMPI.B  #'D',D0
        BEQ.S   .RIGHT
        BRA.S   .DONE

.LEFT_HELD:
        MOVE.B  #1,PADDLE_INPUT_OFF(A5)
        MOVE.W  PADDLE_VX_OFF(A5),D0
        SUBI.W  #PADDLE_ACCEL,D0
        CMPI.W  #-PADDLE_MAX_SPEED,D0
        BGE.S   .SAVE_VELOCITY
        MOVE.W  #-PADDLE_MAX_SPEED,D0
        BRA.S   .SAVE_VELOCITY

.RIGHT_HELD:
        MOVE.B  #1,PADDLE_INPUT_OFF(A5)
        MOVE.W  PADDLE_VX_OFF(A5),D0
        ADDI.W  #PADDLE_ACCEL,D0
        CMPI.W  #PADDLE_MAX_SPEED,D0
        BLE.S   .SAVE_VELOCITY
        MOVE.W  #PADDLE_MAX_SPEED,D0
        BRA.S   .SAVE_VELOCITY

.LEFT:
        MOVE.B  #1,PADDLE_INPUT_OFF(A5)
        MOVE.W  PADDLE_VX_OFF(A5),D0
        SUBI.W  #PADDLE_TAP_IMPULSE,D0
        CMPI.W  #-PADDLE_MAX_SPEED,D0
        BGE.S   .SAVE_VELOCITY
        MOVE.W  #-PADDLE_MAX_SPEED,D0
        BRA.S   .SAVE_VELOCITY

.RIGHT:
        MOVE.B  #1,PADDLE_INPUT_OFF(A5)
        MOVE.W  PADDLE_VX_OFF(A5),D0
        ADDI.W  #PADDLE_TAP_IMPULSE,D0
        CMPI.W  #PADDLE_MAX_SPEED,D0
        BLE.S   .SAVE_VELOCITY
        MOVE.W  #PADDLE_MAX_SPEED,D0

.SAVE_VELOCITY:
        MOVE.W  D0,PADDLE_VX_OFF(A5)
.DONE:
        RTS

; Apply inertia, then friction. The paddle accelerates with a key held and
; coasts briefly when released. Reaching either wall clears horizontal speed.
UPDATE_PADDLE:
        TST.B   PADDLE_INPUT_OFF(A5)
        BNE.S   .MOVE_PADDLE
        MOVE.W  PADDLE_VX_OFF(A5),D0
        TST.W   D0
        BEQ.S   .MOVE_PADDLE
        BMI.S   .DRAG_LEFT
        SUBQ.W  #PADDLE_FRICTION,D0
        BPL.S   .SAVE_DRAG
        CLR.W   D0
        BRA.S   .SAVE_DRAG
.DRAG_LEFT:
        ADDQ.W  #PADDLE_FRICTION,D0
        BMI.S   .SAVE_DRAG
        CLR.W   D0
.SAVE_DRAG:
        MOVE.W  D0,PADDLE_VX_OFF(A5)
.MOVE_PADDLE:
        MOVE.W  PADDLE_X_OFF(A5),D0
        ADD.W   PADDLE_VX_OFF(A5),D0
        TST.W   D0
        BGT.S   .CHECK_RIGHT_WALL
        MOVEQ   #0,D0
        CLR.W   PADDLE_VX_OFF(A5)
        BRA.S   .SAVE_POSITION
.CHECK_RIGHT_WALL:
        CMPI.W  #(SCREEN_W-PADDLE_W),D0
        BLT.S   .SAVE_POSITION
        MOVE.W  #(SCREEN_W-PADDLE_W),D0
        CLR.W   PADDLE_VX_OFF(A5)
.SAVE_POSITION:
        MOVE.W  D0,PADDLE_X_OFF(A5)
        RTS

; Update ball motion, bounce off the court walls, and score paddle hits.
UPDATE_STATE:
        MOVE.W  BALL_X_OFF(A5),D0
        ADD.W   BALL_DX_OFF(A5),D0
        CMPI.W  #0,D0
        BGT.S   .CHECK_X_RIGHT
        MOVEQ   #0,D0
        NEG.W   BALL_DX_OFF(A5)
        BRA.S   .SAVE_X
.CHECK_X_RIGHT:
        CMPI.W  #(SCREEN_W-BALL_SIZE),D0
        BLT.S   .SAVE_X
        MOVE.W  #(SCREEN_W-BALL_SIZE),D0
        NEG.W   BALL_DX_OFF(A5)
.SAVE_X:
        MOVE.W  D0,BALL_X_OFF(A5)

        MOVE.W  BALL_Y_OFF(A5),D1
        ADD.W   BALL_DY_OFF(A5),D1
        CMPI.W  #(COURT_TOP+1),D1
        BGT.S   .CHECK_PADDLE
        MOVE.W  #(COURT_TOP+1),D1
        NEG.W   BALL_DY_OFF(A5)
        BRA.W   .SAVE_Y

.CHECK_PADDLE:
        ; Ball overlaps paddle vertically from y=186 through y=195.
        CMPI.W  #(PADDLE_Y-BALL_SIZE+1),D1
        BLT.W   .SAVE_Y
        CMPI.W  #(SCREEN_H-BALL_SIZE+1),D1
        BGE.S   .RESET_BALL

        ; Test horizontal overlap using both objects' edges.
        MOVE.W  BALL_X_OFF(A5),D2
        ADDI.W  #(BALL_SIZE-1),D2
        MOVE.W  PADDLE_X_OFF(A5),D3
        CMP.W   D3,D2
        BLT.W   .SAVE_Y
        ADDI.W  #(PADDLE_W-1),D3
        MOVE.W  BALL_X_OFF(A5),D2
        CMP.W   D3,D2
        BGT.W   .SAVE_Y

        ; Angle the return according to where the ball hits the paddle.
        MOVE.W  BALL_X_OFF(A5),D2
        ADDI.W  #(BALL_SIZE/2),D2
        MOVE.W  PADDLE_X_OFF(A5),D3
        ADDI.W  #(PADDLE_W/2),D3
        SUB.W   D3,D2
        EXT.L   D2
        DIVS.W  #8,D2
        TST.W   D2
        BNE.S   .SET_BOUNCE_X
        MOVE.W  BALL_DX_OFF(A5),D2
        TST.W   D2
        BNE.S   .SET_BOUNCE_X
        MOVEQ   #1,D2
.SET_BOUNCE_X:
        MOVE.W  D2,BALL_DX_OFF(A5)
        ADDQ.L  #1,SCORE_OFF(A5)
        CMPI.L  #1000,SCORE_OFF(A5)
        BLO.S   .SCORE_OK
        CLR.L   SCORE_OFF(A5)
.SCORE_OK:
        MOVE.W  #(PADDLE_Y-BALL_SIZE+1),D1
        NEG.W   BALL_DY_OFF(A5)
        BRA.S   .SAVE_Y

.RESET_BALL:
        ADDQ.L  #1,MISSES_OFF(A5)
        CMPI.L  #1000,MISSES_OFF(A5)
        BLO.S   .MISSES_OK
        CLR.L   MISSES_OFF(A5)
.MISSES_OK:
        MOVE.W  #160,BALL_X_OFF(A5)
        MOVE.W  #100,D1
        MOVE.W  #2,BALL_DY_OFF(A5)
        MOVE.W  MISSES_OFF(A5),D2
        BTST    #0,D2
        BEQ.S   .SERVE_RIGHT
        MOVE.W  #-2,BALL_DX_OFF(A5)
        BRA.S   .SAVE_Y
.SERVE_RIGHT:
        MOVE.W  #2,BALL_DX_OFF(A5)
.SAVE_Y:
        MOVE.W  D1,BALL_Y_OFF(A5)
        RTS

ERASE_BALL:
        MOVE.W  BALL_X_OFF(A5),D0
        MOVE.W  BALL_Y_OFF(A5),D1
        MOVEQ   #BALL_SIZE,D2
        MOVEQ   #BALL_SIZE,D3
        MOVEQ   #COLOR_BLACK,D4
        BRA.W   DRAW_RECT

ERASE_PADDLE:
        MOVE.W  PADDLE_X_OFF(A5),D0
        MOVE.W  #PADDLE_Y,D1
        MOVEQ   #PADDLE_W,D2
        MOVEQ   #PADDLE_H,D3
        MOVEQ   #COLOR_BLACK,D4
        BRA.W   DRAW_RECT

DRAW_BALL:
        MOVE.W  BALL_X_OFF(A5),D0
        MOVE.W  BALL_Y_OFF(A5),D1
        MOVEQ   #BALL_SIZE,D2
        MOVEQ   #BALL_SIZE,D3
        MOVEQ   #0,D4
        MOVE.B  #COLOR_YELLOW,D4
        BRA.W   DRAW_RECT

DRAW_PADDLE:
        MOVE.W  PADDLE_X_OFF(A5),D0
        MOVE.W  #PADDLE_Y,D1
        MOVEQ   #PADDLE_W,D2
        MOVEQ   #PADDLE_H,D3
        MOVEQ   #COLOR_GREEN,D4
        BRA.W   DRAW_RECT

; Yellow score and red miss counter, each displayed as three seven-segment digits.
DRAW_HUD:
        MOVEM.L D0-D4,-(A7)
        MOVE.L  SCORE_OFF(A5),D0
        MOVE.W  #112,D1
        MOVEQ   #5,D2
        MOVEQ   #0,D4
        MOVE.B  #COLOR_YELLOW,D4
        BSR.W   DRAW_NUMBER
        MOVE.L  MISSES_OFF(A5),D0
        MOVE.W  #192,D1
        MOVEQ   #5,D2
        MOVEQ   #0,D4
        MOVE.B  #COLOR_RED,D4
        BSR.W   DRAW_NUMBER
        MOVEM.L (A7)+,D0-D4
        RTS

; Draw a 000..999 value. Input: D0=value, D1=x, D2=y, D4=color.
DRAW_NUMBER:
        MOVEM.L D0-D7/A0-A3,-(A7)
        MOVE.W  D1,D6                  ; left digit x
        MOVE.W  D2,D7                  ; digit y
        MOVE.W  D4,D3                  ; color
        CMPI.L  #1000,D0
        BLO.S   .IN_RANGE
        CLR.L   D0
.IN_RANGE:
        DIVU.W  #100,D0                ; quotient=hundreds, remainder in high word
        MOVE.W  D0,-(A7)
        SWAP    D0
        ANDI.L  #$0000FFFF,D0
        DIVU.W  #10,D0                 ; quotient=tens, remainder=ones
        MOVE.W  D0,-(A7)
        SWAP    D0
        MOVE.W  D0,-(A7)

        MOVE.W  (A7)+,D0               ; ones at right
        MOVE.W  D6,D1
        ADDI.W  #26,D1
        MOVE.W  D7,D2
        MOVE.W  D3,D4
        BSR.W   DRAW_DIGIT
        MOVE.W  (A7)+,D0               ; tens
        MOVE.W  D6,D1
        ADDI.W  #13,D1
        MOVE.W  D7,D2
        MOVE.W  D3,D4
        BSR.W   DRAW_DIGIT
        MOVE.W  (A7)+,D0               ; hundreds
        MOVE.W  D6,D1
        MOVE.W  D7,D2
        MOVE.W  D3,D4
        BSR.W   DRAW_DIGIT
        MOVEM.L (A7)+,D0-D7/A0-A3
        RTS

; Draw one 10x14 digit. Input: D0=digit, D1=x, D2=y, D4=color.
DRAW_DIGIT:
        MOVEM.L D0-D7/A0-A3,-(A7)
        MOVEA.W D1,A2
        MOVEA.W D2,A3
        MOVE.W  D4,D7
        LEA     DIGIT_MASKS(PC),A0
        MOVEQ   #0,D1
        MOVE.B  (A0,D0.W),D1
        MOVE.W  D1,D5
        LEA     SEGMENT_TABLE(PC),A0
        MOVEQ   #0,D6
.SEGMENT_LOOP:
        BTST    D6,D5
        BEQ.S   .SKIP_SEGMENT
        MOVE.W  (A0),D0
        ADD.W   A2,D0
        MOVE.W  2(A0),D1
        ADD.W   A3,D1
        MOVE.W  4(A0),D2
        MOVE.W  6(A0),D3
        MOVE.W  D7,D4
        BSR.W   DRAW_RECT
.SKIP_SEGMENT:
        LEA     8(A0),A0
        ADDQ.W  #1,D6
        CMPI.W  #7,D6
        BNE.S   .SEGMENT_LOOP
        MOVEM.L (A7)+,D0-D7/A0-A3
        RTS

DRAW_COURT:
        MOVEM.L D0-D4,-(A7)
        MOVEQ   #0,D0
        MOVE.W  #COURT_TOP,D1
        MOVE.W  #SCREEN_W,D2
        MOVEQ   #1,D3
        MOVEQ   #COLOR_GREEN,D4
        BSR.W   DRAW_RECT
        MOVEQ   #0,D0
        MOVE.W  #(COURT_TOP+1),D1
        MOVEQ   #1,D2
        MOVE.W  #(SCREEN_H-COURT_TOP-1),D3
        MOVEQ   #COLOR_GREEN,D4
        BSR.W   DRAW_RECT
        MOVE.W  #(SCREEN_W-1),D0
        MOVE.W  #(COURT_TOP+1),D1
        MOVEQ   #1,D2
        MOVE.W  #(SCREEN_H-COURT_TOP-1),D3
        MOVEQ   #COLOR_GREEN,D4
        BSR.W   DRAW_RECT
        MOVEM.L (A7)+,D0-D4
        RTS

; Fill a clipped-by-design rectangle.
; Input: D0=x, D1=y, D2=width, D3=height, D4.B=color.
DRAW_RECT:
        MOVEM.L D0-D5/A0-A1,-(A7)
        LEA     VIRTUAL_VIDEO_BASE,A0
        MULU.W  #SCREEN_W,D1
        ADDA.L  D1,A0
        EXT.L   D0
        ADDA.L  D0,A0
        SUBQ.W  #1,D2
        SUBQ.W  #1,D3
.ROW:
        MOVEA.L A0,A1
        MOVE.W  D2,D5
.COLUMN:
        MOVE.B  D4,(A1)+
        DBF     D5,.COLUMN
        ADDA.L  #SCREEN_W,A0
        DBF     D3,.ROW
        MOVEM.L (A7)+,D0-D5/A0-A1
        RTS

CLEAR_SCREEN:
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.W  #15999,D0
        MOVEQ   #COLOR_BLACK,D1
.CLEAR:
        MOVE.L  D1,(A0)+
        DBF     D0,.CLEAR
        RTS

TITLE_TEXT:
        DC.B    13,10,'PONG: A/D OR ARROWS MOVE  Q QUIT',13,10
        DC.B    'HUD: YELLOW SCORE / RED MISSES',13,10,0
        EVEN

GAME_STATE:
        DC.W    160,100,2,2,140
        DC.L    0,0,0
PADDLE_VX_OFF  EQU     22
        DC.W    0
PADDLE_INPUT_OFF EQU   24
        DC.B    0,0

; Seven-segment bits: top, upper-right, lower-right, bottom,
; lower-left, upper-left, middle.
DIGIT_MASKS:
        DC.B    $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F
        EVEN
SEGMENT_TABLE:
        DC.W    1,0,8,2       ; top
        DC.W    9,2,2,5       ; upper-right
        DC.W    9,8,2,5       ; lower-right
        DC.W    1,12,8,2      ; bottom
        DC.W    0,8,2,5       ; lower-left
        DC.W    0,2,2,5       ; upper-left
        DC.W    1,6,8,2       ; middle

        END     START
