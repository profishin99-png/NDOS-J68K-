        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'
        ORG     0

SCREEN_W        EQU     320
SCREEN_H        EQU     200

; ---------------------------------------------------------------------------
; Program entry.
;
; D7 is our frame counter.  It is deliberately kept in a register between
; frames so CUBE can use it as a small animation phase.  The video framebuffer
; and input registers are MAME-only virtual devices declared in build/map.inc;
; they are not yet a promise of real Rev A motherboard video hardware.
; ---------------------------------------------------------------------------
START:
        MOVEQ   #0,D7
FRAME:
        ; Paint the entire 320 x 200, one-byte-per-pixel framebuffer black.
        BSR.L   CLEAR

        ; Draw one complete wireframe cube into the cleared framebuffer.
        BSR.L   CUBE

        ; Keep the image visible long enough to see before the next frame.
        BSR.L   DELAY

        ; VIRTUAL_INPUT_BASE bit 31 is set when MAME has queued a key.
        ; Consume the character, then exit through the normal NDOS ABI.
        MOVE.L  VIRTUAL_INPUT_BASE,D0
        BPL.S   .NO_KEY
        MOVE.L  VIRTUAL_INPUT_BASE+4,D0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.NO_KEY: ADDQ.L #1,D7
        BRA.S   FRAME

; ---------------------------------------------------------------------------
; CLEAR
;
; Writes 64,000 zero bytes = 320 * 200 pixels.  A longword at a time makes
; the routine four times shorter than a byte-write loop.  15,999 DBF passes
; plus the first write gives exactly 16,000 longwords, or 64,000 bytes.
;
; Clobbers: A0, D0, D1
; ---------------------------------------------------------------------------
CLEAR:  LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.L  #15999,D0
        MOVEQ   #0,D1
.C:     MOVE.L  D1,(A0)+
        DBF     D0,.C
        RTS

; Two projected squares, connected at the corners. The phase moves the
; front square slightly to give a readable rotating-cube effect.
; ---------------------------------------------------------------------------
; CUBE
;
; Draws a deliberately simple perspective cube.  It is not matrix 3D yet:
; the "back" square is manually offset from the front square.  This keeps the
; demo useful as a framebuffer and line-rasterizer test while remaining easy
; to reverse engineer.
;
; EDGE input convention:
;   D0.W = x0       D1.W = y0
;   D2.W = x1       D3.W = y1
;   D4.B = RGB332 colour ($FF = bright white)
;
; D5/D6 hold the moving front-square origin.  Every EDGE call saves/restores
; all of its working registers, so the values remain valid after the call.
; ---------------------------------------------------------------------------
CUBE:   MOVEQ   #-1,D4

        ; Make a 0..31..0 triangular phase from the low six frame-counter
        ; bits.  The front face therefore slides left/right slowly.
        MOVE.W  D7,D6
        ANDI.W  #63,D6
        CMPI.W  #32,D6
        BLO.S   .PHASE
        MOVE.W  #64,D6
        SUB.W   D7,D6
        ANDI.W  #63,D6
.PHASE: MOVE.W  D6,D5
        ADDI.W  #105,D5           ; front-left x
        MOVE.W  #65,D6            ; front top y

        ; Front-face top edge: (x,y) -> (x+72,y).
        MOVE.W  D5,D0             ; x0
        MOVE.W  D6,D1             ; y0
        MOVE.W  D5,D2
        ADDI.W  #72,D2
        MOVE.W  D6,D3
        BSR.L   EDGE

        ; Front-face right edge: (x+72,y) -> (x+72,y+34).
        MOVE.W  D5,D0
        ADDI.W  #72,D0
        MOVE.W  D6,D1
        MOVE.W  D0,D2
        MOVE.W  D1,D3
        ADDI.W  #34,D3
        BSR.L   EDGE

        ; Front-face bottom edge: (x+72,y+34) -> (x,y+34).
        MOVE.W  D5,D0
        ADDI.W  #72,D0
        MOVE.W  D6,D1
        ADDI.W  #34,D1
        MOVE.W  D5,D2
        MOVE.W  D1,D3
        BSR.L   EDGE

        ; Front-face left edge: (x,y) -> (x,y+34).
        MOVE.W  D5,D0
        MOVE.W  D6,D1
        MOVE.W  D0,D2
        MOVE.W  D1,D3
        ADDI.W  #34,D3
        BSR.L   EDGE

        ; Back face is offset right and down from the front face to create
        ; the simple perspective effect.
        MOVE.W  D6,D1           ; back top y
        ADDI.W  #34,D1
        MOVE.W  D5,D0
        ADDI.W  #20,D0
        MOVE.W  D0,D2
        ADDI.W  #72,D2
        MOVE.W  D1,D3
        BSR.L   EDGE
        MOVE.W  D0,D2
        MOVE.W  D1,D3
        ADDI.W  #34,D3
        BSR.L   EDGE
        MOVE.W  D0,D2
        ADDI.W  #72,D2
        MOVE.W  D1,D3
        ADDI.W  #34,D3
        BSR.L   EDGE
        ; connectors
        MOVE.W  D5,D0
        MOVE.W  D6,D1
        MOVE.W  D5,D2
        ADDI.W  #20,D2
        MOVE.W  D1,D3
        ADDI.W  #34,D3
        BSR.L   EDGE
        MOVE.W  D5,D0
        ADDI.W  #72,D0
        MOVE.W  D6,D1
        MOVE.W  D0,D2
        ADDI.W  #20,D2
        MOVE.W  D1,D3
        ADDI.W  #34,D3
        BSR.L   EDGE
        MOVE.W  D5,D0
        MOVE.W  D6,D1
        ADDI.W  #34,D1
        MOVE.W  D0,D2
        ADDI.W  #20,D2
        MOVE.W  D1,D3
        BSR.L   EDGE
        RTS

; D0=x0 D1=y0 D2=x1 D3=y1 D4=color. Fixed-point DDA, 81 samples.
; DIVS leaves the remainder in the upper word.  Every word coordinate and
; quotient must therefore be sign-extended before it is used as a longword.
; ---------------------------------------------------------------------------
; EDGE
;
; The public inputs are integer pixels.  Internally, D5 and D6 become 24.8
; fixed-point current X/Y positions.  D2/D3 become fixed-point increments:
;
;     dx_step = ((x1 - x0) << 8) / 80
;     dy_step = ((y1 - y0) << 8) / 80
;
; The loop runs 81 times, plotting both endpoints and every intermediate
; position.  Eight fractional bits prevent shallow diagonals from collapsing
; into horizontal or vertical bars.
;
; Important 68020 detail: word-sized MOVEs and SUBs do not clean the upper
; half of a data register.  DIVS.W stores remainder:quotient in one longword.
; The EXT.L instructions are required before values are used as longwords.
;
; Preserves all caller-visible registers by saving D0-D7/A0.
; ---------------------------------------------------------------------------
EDGE:   MOVEM.L D0-D7/A0,-(A7)

        ; D5 = x0 << 8.  Clear before MOVE.W to avoid stale high bits.
        MOVEQ   #0,D5
        MOVE.W  D0,D5
        LSL.L   #8,D5
        MOVEQ   #0,D6
        MOVE.W  D1,D6
        LSL.L   #8,D6

        ; D2 = signed 24.8 dx per plotted point.
        SUB.W   D0,D2
        EXT.L   D2
        LSL.L   #8,D2
        DIVS    #80,D2
        EXT.L   D2

        ; D3 = signed 24.8 dy per plotted point.
        SUB.W   D1,D3
        EXT.L   D3
        LSL.L   #8,D3
        DIVS    #80,D3
        EXT.L   D3
        MOVEQ   #80,D7
.E:     ; Convert current 24.8 coordinates back to integer pixels.
        MOVE.L  D6,D1
        ASR.L   #8,D1
        MOVE.L  D5,D0
        ASR.L   #8,D0
        BSR.L   PIXEL
        ADD.L   D2,D5
        ADD.L   D3,D6
        DBF     D7,.E
        MOVEM.L (A7)+,D0-D7/A0
        RTS

; ---------------------------------------------------------------------------
; PIXEL
;
; Input:
;   D0.W = X pixel, 0..319
;   D1.W = Y pixel, 0..199
;   D4.B = RGB332 colour
;
; Framebuffer layout is linear row-major memory:
;
;   byte address = VIRTUAL_VIDEO_BASE + X + (Y * 320)
;
; The bounds guards are intentional.  They keep a malformed future line or
; 3D projection from writing outside the MAME virtual-video window and causing
; an MC68020 bus error.  D2/D3/A0 are saved because EDGE needs D2/D3 to retain
; its fixed-point slopes across every pixel call.
; ---------------------------------------------------------------------------
PIXEL:  TST.W   D0
        BMI.S   .OUT
        CMPI.W  #SCREEN_H,D0
        BHS.S   .OUT
        TST.W   D1
        BMI.S   .OUT
        CMPI.W  #SCREEN_W,D1
        BHS.S   .OUT
        MOVEM.L D2-D3/A0,-(A7)
        MOVEQ   #0,D2
        MOVE.W  D1,D2
        MOVEQ   #0,D3
        MOVE.W  D0,D3
        MULU    #SCREEN_W,D3
        ADD.L   D3,D2
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.B  D4,0(A0,D2.L)
        MOVEM.L (A7)+,D2-D3/A0
.OUT:   RTS

; ---------------------------------------------------------------------------
; DELAY
;
; Simple busy wait used only by this visual demo.  It is not a real timebase;
; future NDOS timer interrupts should replace this style of delay in programs
; that need stable timing or multitasking.
;
; Clobbers: D0
; ---------------------------------------------------------------------------
DELAY:  MOVE.L  #12000,D0
.D:     SUBQ.L  #1,D0
        BNE.S   .D
        RTS
        END     START
