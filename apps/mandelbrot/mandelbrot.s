        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'
        ORG     0

; 320x200 RGB332 output, rendered at 160x100 and doubled to reduce CPU work.
; FP0=x, FP1=y, FP2=c real, FP3=c imaginary,
; FP4=x*x, FP5=y*y, FP6=temporary/new y, FP7=x*x+y*y.
SCREEN_W        EQU     160
SCREEN_H        EQU     100
OUTPUT_ROW_BYTES EQU    320
MAX_ITER        EQU     1000

START:
        LEA     START_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Clear the indexed framebuffer once, then draw 2x2 pixel blocks.
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.W  #(OUTPUT_ROW_BYTES*SCREEN_H*2)-1,D0
        MOVEQ   #0,D1
.CLEAR:
        MOVE.B  D1,(A0)+
        DBF     D0,.CLEAR

        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVEQ   #0,D5                 ; pixel row
        FMOVE.S IMAG_MIN(PC),FP3      ; c imaginary coordinate for first row
        MOVE.L  A0,-(A7)              ; GET_TICKS dispatch uses A0 internally
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D3                 ; start tick; syscall 14 is nominally 100 Hz
        MOVEA.L (A7)+,A0              ; restore framebuffer pointer

.ROW:
        CMPI.W  #SCREEN_H,D5
        BHS.W   .DONE_DRAWING
        MOVEQ   #0,D4                 ; pixel column
        FMOVE.S REAL_MIN(PC),FP2      ; c real coordinate for first column

.COLUMN:
        CMPI.W  #SCREEN_W,D4
        BHS.W   .NEXT_ROW

        ; Start the orbit at z=0 for this pixel's complex coordinate c.
        FMOVE.S ZERO(PC),FP0
        FMOVE.S ZERO(PC),FP1
        MOVEQ   #0,D6                 ; iteration count

.ITERATE:
        ; Compute x*x + y*y and escape when the radius exceeds 2.
        FMOVE   FP0,FP4
        FMUL    FP0,FP4
        FMOVE   FP1,FP5
        FMUL    FP1,FP5
        FMOVE   FP4,FP7
        FADD    FP5,FP7
        ; Compare in the FPU directly. This avoids writing the radius to a
        ; scratch location and reading it back on every iteration.
        FCMP.S  #4.0,FP7
        FBGT.W  .ESCAPED

        ; y' = 2*x*y + c_imag, using the old x and y.
        FMOVE   FP0,FP6
        FMUL    FP1,FP6
        FADD    FP6,FP6
        FADD    FP3,FP6

        ; x' = x*x - y*y + c_real.
        FSUB    FP5,FP4
        FADD    FP2,FP4
        FMOVE   FP6,FP1
        FMOVE   FP4,FP0

        ADDQ.W  #1,D6
        CMPI.W  #MAX_ITER,D6
        BLO.S   .ITERATE

        ; Points that did not escape are black.
        MOVEQ   #0,D7
        BRA.S   .PLOT

.ESCAPED:
        ; Cycle escaped pixels through red, blue, and yellow by iteration.
        MOVEQ   #0,D7
        MOVE.B  D6,D7
        DIVU    #3,D7                 ; remainder in high word, quotient in low
        SWAP    D7
        ANDI.W  #3,D7
        CMPI.W  #0,D7
        BEQ.S   .RED
        CMPI.W  #1,D7
        BEQ.S   .BLUE
        BRA.S   .YELLOW

.YELLOW:
        MOVEQ   #0,D7
        MOVE.B  D6,D7
        LSR.B   #2,D7
        MOVE.B  D7,D1
        ANDI.B  #$07,D7
        LSL.B   #5,D7                 ; scale count into RGB332 red field
        ANDI.B  #$07,D1
        LSL.B   #2,D1                 ; scale count into RGB332 green field
        OR.B    D1,D7
        BRA.S   .COLOR_DONE

.RED:
        MOVEQ   #0,D7
        MOVE.B  D6,D7
        LSR.B   #2,D7
        ANDI.B  #$07,D7
        LSL.B   #5,D7                 ; scale count into RGB332 red field
        BRA.S   .COLOR_DONE

.BLUE:
        MOVEQ   #0,D7
        MOVE.B  D6,D7
        LSR.B   #2,D7
        ANDI.B  #$03,D7               ; RGB332 blue field has two bits

.COLOR_DONE:

.PLOT:
        ; The logical pixel is doubled horizontally. Replicate its color in
        ; one aligned word store instead of two byte stores.
        MOVEQ   #0,D1
        MOVE.B  D7,D1
        LSL.W   #8,D1
        MOVE.B  D7,D1
        MOVE.W  D1,(A0)+
        ADDQ.W  #1,D4
        FMOVE.S REAL_STEP(PC),FP6
        FADD    FP6,FP2
        BRA.W   .COLUMN

.NEXT_ROW:
        ; Copy the completed 320-byte scanline to the following output row.
        MOVEA.L A0,A1
        SUBA.L  #OUTPUT_ROW_BYTES,A1
        MOVE.W  #(OUTPUT_ROW_BYTES/2)-1,D0
.DUPLICATE_ROW:
        MOVE.W  (A1)+,(A0)+
        DBF     D0,.DUPLICATE_ROW
        ADDQ.W  #1,D5
        FMOVE.S IMAG_STEP(PC),FP6
        FADD    FP6,FP3
        BRA.W   .ROW

.DONE_DRAWING:
        ; Report wall-clock rendering time from the NDOS 100 Hz tick source.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        SUB.L   D3,D0                 ; unsigned elapsed ticks (wrap-safe here)
        MOVE.L  D0,D4                 ; retain total ticks for both displays

        LEA     RENDER_TIME_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Convert 100 Hz ticks to seconds and hundredths for display.
        MOVE.L  D4,D1
        DIVU    #100,D1               ; quotient=seconds, remainder=hundredths
        MOVEQ   #0,D2
        MOVE.W  D1,D2
        SWAP    D1
        MOVEQ   #0,D5
        MOVE.W  D1,D5

        MOVE.L  D2,D1
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #'.',D1
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0
        CMPI.L  #10,D5
        BHS.S   .PRINT_HUNDREDTHS
        MOVEQ   #'0',D1
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0
.PRINT_HUNDREDTHS:
        MOVE.L  D5,D1
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     SECONDS_TICKS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVE.L  D4,D1
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
        LEA     NUMBER_BUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     TICKS_SUFFIX(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        LEA     DONE_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:
        BRA.S   .HANG

START_TEXT:
        DC.B    13,10,'MANDELBROT: RENDERING 320 X 200...',13,10,0
RENDER_TIME_TEXT:
        DC.B    'RENDER TIME: ',0
SECONDS_TICKS_TEXT:
        DC.B    ' SEC (',0
TICKS_SUFFIX:
        DC.B    ' TICKS AT 100 HZ)',13,10,0
DONE_TEXT:
        DC.B    13,10,'MANDELBROT: DONE',13,10,0
NUMBER_BUFFER:
        DS.B    11
        EVEN

ZERO:
        DC.S    0.0
REAL_MIN:
        DC.S    -2.0
IMAG_MIN:
        DC.S    -1.0
REAL_STEP:
        DC.S    0.01875              ; 3.0 / 160 logical pixels
IMAG_STEP:
        DC.S    0.02                 ; 2.0 / 100 logical pixels
RADIUS_REAL:
        DC.S    0.0

        END     START
