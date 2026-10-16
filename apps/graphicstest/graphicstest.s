        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'

 ORG     0

SCREEN_W        EQU     320
SCREEN_H        EQU     200

BLACK           EQU     $00
BLUE            EQU     $03
GREEN           EQU     $1C
RED             EQU     $E0
YELLOW          EQU     $FC
WHITE           EQU     $FF


    START:
        MOVEQ     #1,D5                   ; MOVEQ always writes a longword.
    ;plot a single pixel at 160,100
    bsr.l CLEAR_SCREEN
    move.w #159,d0
    move.w #99,d1
    moveq.l  #12,D4
    bsr.l  PLOT_PIXEL
    
       ; horizontal red line.
        MOVE.W  #160,D0
        MOVE.W  #100,D1
        MOVE.W  #170,D2
        MOVE.B  #RED,D4
      
        BSR.L   HLINE
      
         MOVE.W  #160,D0
        MOVE.W  #100,D1
        MOVE.W  #170,D2
        MOVE.B  #RED,D4
        ADDI.W   #50,D1
        BSR.L   HLINE
        

        MOVE.W  #100,D0
        MOVE.W  #160,D1
        MOVE.W  #70,D2
        MOVE.B  #BLUE,D4
        BSR.L   VLINE
        BRA.S   EXIT

      EXIT: 

        ; Return normally to NDOS.
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0


; -----------------------------------------------------------
; PLOT_PIXEL
;
; Input:
;   D0.W = X coordinate: 0..319
;   D1.W = Y coordinate: 0..199
;   D4.B = RGB332 colour
;
; Clobbers:
;   D2, D3, A0
; -----------------------------------------------------------
PLOT_PIXEL:
        ; Reject X outside 0..319.
        TST.W   D0
        BMI.S   .DONE
        CMPI.W  #SCREEN_W,D0
        BHS.S   .DONE

        ; Reject Y outside 0..199.
        TST.W   D1
        BMI.S   .DONE
        CMPI.W  #SCREEN_H,D1
        BHS.S   .DONE

        ; D2 = X.
        MOVEQ   #0,D2
        MOVE.W  D0,D2

        ; D3 = Y * 320.
        MOVEQ   #0,D3
        MOVE.W  D1,D3
        MULU    #SCREEN_W,D3

        ; D2 = X + (Y * 320).
        ADD.L   D3,D2

        ; framebuffer[X + Y*320] = colour.
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.B  D4,0(A0,D2.L)

.DONE:
        RTS




; -----------------------------------------------------------
; VLINE
;
; Input:
;   D0.W = first Y
;   D1.W = X
;   D2.W = final Y, inclusive
;   D4.B = colour
; -----------------------------------------------------------
VLINE:
        CMP.W   D0,D2
        BLO.S   .DONE
        EXG     D0,D1
.LOOP:
        BSR.L   PLOT_PIXEL
        ADDQ.W  #1,D1
        CMP.W   D1,D2
        BHS.S   .LOOP

.DONE:
        RTS

        
; -----------------------------------------------------------
; HLINE
;
; Input:
;   D0.W = first X
;   D1.W = Y
;   D2.W = final X, inclusive
;   D4.B = colour
; -----------------------------------------------------------
HLINE:
        CMP.W   D0,D2
        BLO.S   .DONE
        
.LOOP:
        BSR.L   PLOT_PIXEL
        ADDQ.W  #1,D0
        CMP.W   D0,D2
        BHS.S   .LOOP

.DONE:
        RTS

 CLEAR_SCREEN:
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVE.L  #15999,D0
        MOVEQ   #0,D1

.CLEAR_LOOP:
        MOVE.L  D1,(A0)+
        DBF     D0,.CLEAR_LOOP
        RTS




 END  START
