        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'

; ---------------------------------------------------------------------------
; JUGGLER.NEX -- original Amiga-inspired framebuffer demonstration.
; MAME-only temporary video target: 320x200 RGB332 at VIRTUAL_VIDEO_BASE.
; Press any key in the MAME window to return to NDOS.
; ---------------------------------------------------------------------------
        ORG     0

SCREEN_W        EQU     320
SCREEN_H        EQU     200
GROUND_Y        EQU     170

START:
        BSR     CLEAR_SCREEN
        MOVEQ   #0,D7                   ; animation phase: 0..119

FRAME:
        BSR     CLEAR_SCREEN
        BSR     DRAW_GROUND
        BSR     DRAW_JUGGLER
        BSR     DRAW_BALLS
        BSR     DELAY

        ; Temporary MAME input queue: status bit 31 says a byte is ready.
        MOVE.L  VIRTUAL_INPUT_BASE,D0
        BPL.S   .NO_KEY
        MOVE.L  VIRTUAL_INPUT_BASE+4,D0 ; pop one key
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.NO_KEY:
        ADDQ.L  #1,D7
        CMPI.L  #120,D7
        BLO.S   FRAME
        MOVEQ   #0,D7
        BRA.S   FRAME

; A0 = framebuffer base, one byte per pixel.
CLEAR_SCREEN:
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.L  #((SCREEN_W*SCREEN_H)/4)-1,D0
        MOVE.L  #$00000000,D1
.CLEAR: MOVE.L  D1,(A0)+
        DBF     D0,.CLEAR
        RTS

DRAW_GROUND:
        MOVE.W  #GROUND_Y,D0
 .ROW:  MOVEQ   #0,D1
 .COL:  MOVE.W  D1,D2
        LSR.W   #3,D2
        EOR.W   D0,D2
        ANDI.W  #1,D2
        BNE.S   .DARK
        MOVEQ   #$49,D2
        BRA.S   .PUT
 .DARK: MOVEQ   #$24,D2
 .PUT:  BSR.L   PLOT
        ADDQ.W  #1,D1
        CMPI.W  #SCREEN_W,D1
        BLO.S   .COL
        ADDQ.W  #1,D0
        CMPI.W  #SCREEN_H,D0
        BLO.S   .ROW
        RTS

; Fixed figure: head, torso, arms, and legs.  This is deliberately simple
; so the moving balls are easy to inspect in the MAME debugger.
DRAW_JUGGLER:
        ; head: 9x9 yellow block around (160,72)
        MOVEQ   #68,D0
.HROW:  MOVE.W  #156,D1
.HCOL:  MOVE.B  #$fc,D2
        BSR.L   PLOT
        ADDQ.W  #1,D1
        CMPI.W  #165,D1
        BLO.S   .HCOL
        ADDQ.W  #1,D0
        CMPI.W  #77,D0
        BLO.S   .HROW
        ; torso
        MOVEQ   #77,D0
.TROW:  MOVE.W  #158,D1
.TCOL:  MOVEQ   #$1c,D2
        BSR.L   PLOT
        ADDQ.W  #1,D1
        CMPI.W  #163,D1
        BLO.S   .TCOL
        ADDQ.W  #1,D0
        CMPI.W  #130,D0
        BLO.S   .TROW
        ; arms at y=96: left x=132..158, right x=163..190
        MOVEQ   #96,D0
        MOVE.W  #132,D1
.AL:    MOVE.B  #$e0,D2
        BSR.L   PLOT
        ADDQ.W  #1,D1
        CMPI.W  #159,D1
        BLO.S   .AL
        MOVE.W  #163,D1
.AR:    MOVE.B  #$e0,D2
        BSR.L   PLOT
        ADDQ.W  #1,D1
        CMPI.W  #191,D1
        BLO.S   .AR
        ; legs
        MOVE.W  #130,D0
.LROW:  MOVE.W   D0,D1
        SUBI.W  #130,D1
        ADDI.W  #145,D1
        MOVEQ   #$1c,D2
        BSR.L   PLOT
        MOVE.W  #175,D1
        SUB.W   D0,D1
        ADDI.W  #130,D1
        BSR.L   PLOT
        ADDQ.W  #1,D0
        CMPI.W  #166,D0
        BLO.S   .LROW
        RTS

; Three balls follow a repeating 120-frame triangular path.  This avoids a
; sine table and gives us an easy, deterministic first graphics regression.
DRAW_BALLS:
        MOVE.L  D7,D3
        BSR     BALL_A
        MOVE.L  D7,D3
        ADDI.L  #40,D3
        CMPI.L  #120,D3
        BLO.S   .B
        SUBI.L  #120,D3
.B:     BSR     BALL_B
        MOVE.L  D7,D3
        ADDI.L  #80,D3
        CMPI.L  #120,D3
        BLO.S   .C
        SUBI.L  #120,D3
.C:     BSR     BALL_C
        RTS

; D3 phase in 0..119. D2 colour. Ball trajectory uses x 112..207 and a
; folded height; three separate colors make frame ordering visible.
BALL_A: MOVE.B  #$e0,D2
        BRA.S   BALL_COMMON
BALL_B: MOVEQ   #$1c,D2
        BRA.S   BALL_COMMON
BALL_C: MOVEQ   #$03,D2
BALL_COMMON:
        MOVE.W  D3,D1
        ADDI.W  #112,D1                ; horizontal travel
        MOVE.W  D3,D0
        CMPI.W  #60,D0
        BLO.S   .UP
        MOVE.W  #120,D4
        SUB.W   D0,D4
        MOVE.W  D4,D0
.UP:    ; y = 145 - phase folded, so top is y=85
        MOVE.W  #145,D4
        SUB.W   D0,D4
        MOVE.W  D4,D0
        BSR     BALL_DOT
        RTS

; D0=y, D1=x, D2=colour. Draw a 5x5 square.
BALL_DOT:
        SUBQ.W  #2,D0
        SUBQ.W  #2,D1
        MOVEQ   #5-1,D5
.ROW:   MOVEQ   #5-1,D6
.COL:   BSR.L   PLOT
        ADDQ.W  #1,D1
        DBF     D6,.COL
        SUBI.W  #5,D1
        ADDQ.W  #1,D0
        DBF     D5,.ROW
        RTS

; D0.W=y, D1.W=x, D2.B=colour.  Inputs are in range in this demonstration.
PLOT:   MOVEM.L D3-D4/A0,-(A7)
        MOVEQ   #0,D3
        MOVE.W  D0,D3
        MULU    #SCREEN_W,D3
        MOVEQ   #0,D4
        MOVE.W  D1,D4
        ADD.L   D4,D3
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.B  D2,0(A0,D3.L)
        MOVEM.L (A7)+,D3-D4/A0
        RTS

DELAY:  MOVE.L  #18000,D0
.LOOP:  SUBQ.L  #1,D0
        BNE.S   .LOOP
        RTS

        END     START
