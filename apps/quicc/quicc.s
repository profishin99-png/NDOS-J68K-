; -----------------------------------------------------------
; QUICC.NEX -- MAME-only dual-M68000 graphics playground demo
;
; This is deliberately not a real MC68360 QUICC driver and not
; Rev-A hardware.  It talks to the temporary $00E20000 mailbox
; implemented only by the reduced J68K MAME target.
; -----------------------------------------------------------
        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'

QP_COMMAND      EQU     0
QP_STATUS       EQU     4
QP_COLOUR       EQU     8
QP_X0           EQU     12
QP_Y0           EQU     16
QP_X1           EQU     20
QP_Y1           EQU     24
QP_WORKERS      EQU     28
QP_HEART_A      EQU     36
QP_HEART_B      EQU     40

QP_CLEAR        EQU     1
QP_FILL_RECT    EQU     2
QP_LINE         EQU     3

WORKER_LEFT     EQU     1
WORKER_RIGHT    EQU     2
WORKER_BOTH     EQU     3

COLOUR_BLACK    EQU     $00
COLOUR_RED      EQU     $E0
COLOUR_GREEN    EQU     $1C
COLOUR_YELLOW   EQU     $FC
COLOUR_WHITE    EQU     $FF

        ORG     0

START:
        LEA     QUICC_PLAY_BASE,A0

        ; Clear the full temporary 320x200 MAME framebuffer.
        MOVE.L  #COLOUR_BLACK,QP_COLOUR(A0)
        MOVE.L  #WORKER_BOTH,QP_WORKERS(A0)
        MOVE.L  #QP_CLEAR,QP_COMMAND(A0)

        ; Worker A owns and fills the left half in red.
        MOVE.L  #COLOUR_RED,QP_COLOUR(A0)
        MOVE.L  #0,QP_X0(A0)
        MOVE.L  #0,QP_Y0(A0)
        MOVE.L  #159,QP_X1(A0)
        MOVE.L  #199,QP_Y1(A0)
        MOVE.L  #WORKER_LEFT,QP_WORKERS(A0)
        MOVE.L  #QP_FILL_RECT,QP_COMMAND(A0)

        ; Worker B owns and fills the right half in green.
        MOVE.L  #COLOUR_GREEN,QP_COLOUR(A0)
        MOVE.L  #160,QP_X0(A0)
        MOVE.L  #0,QP_Y0(A0)
        MOVE.L  #319,QP_X1(A0)
        MOVE.L  #199,QP_Y1(A0)
        MOVE.L  #WORKER_RIGHT,QP_WORKERS(A0)
        MOVE.L  #QP_FILL_RECT,QP_COMMAND(A0)

        ; Both workers draw two white diagonal lines.
        MOVE.L  #COLOUR_WHITE,QP_COLOUR(A0)
        MOVE.L  #0,QP_X0(A0)
        MOVE.L  #0,QP_Y0(A0)
        MOVE.L  #319,QP_X1(A0)
        MOVE.L  #199,QP_Y1(A0)
        MOVE.L  #WORKER_BOTH,QP_WORKERS(A0)
        MOVE.L  #QP_LINE,QP_COMMAND(A0)

        MOVE.L  #0,QP_X0(A0)
        MOVE.L  #199,QP_Y0(A0)
        MOVE.L  #319,QP_X1(A0)
        MOVE.L  #0,QP_Y1(A0)
        MOVE.L  #QP_LINE,QP_COMMAND(A0)

        ; A yellow centre box crosses the worker boundary.
        MOVE.L  #COLOUR_YELLOW,QP_COLOUR(A0)
        MOVE.L  #120,QP_X0(A0)
        MOVE.L  #80,QP_Y0(A0)
        MOVE.L  #199,QP_X1(A0)
        MOVE.L  #119,QP_Y1(A0)
        MOVE.L  #QP_FILL_RECT,QP_COMMAND(A0)

        LEA     MESSAGE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Getchar blocks until a terminal key arrives, then NDOS returns us
        ; cleanly to the shell.  The temporary MAME framebuffer stays visible
        ; until the next graphics program redraws it.
        MOVEQ   #NDOS_SYS_GETCHAR,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0

MESSAGE:
        DC.B    13,10,'DUAL M68000 PLAYGROUND RENDERED.',13,10
        DC.B    'RED = LEFT WORKER, GREEN = RIGHT WORKER.',13,10
        DC.B    'PRESS A KEY TO RETURN.',13,10,0
        EVEN

        END     START
