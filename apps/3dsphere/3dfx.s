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

 ; Both workers draw two white diagonal lines.
        MOVE.L  #COLOUR_WHITE,QP_COLOUR(A0)
        MOVE.L  #0,QP_X0(A0)
        MOVE.L  #0,QP_Y0(A0)
        MOVE.L  #319,QP_X1(A0)
        MOVE.L  #199,QP_Y1(A0)
        MOVE.L  #WORKER_BOTH,QP_WORKERS(A0)
        MOVE.L  #QP_LINE,QP_COMMAND(A0)
    
       
        MOVE.L #$00000003,QP_WORKERS ; both workers
        MOVE.L  #COLOUR_YELLOW,QP_COLOUR(A0)
        MOVE.L #8,QP_X0(A0)
        MOVE.L #8,QP_Y0(A0)
        MOVE.L #145,QP_X1(A0)
        MOVE.L #180,QP_Y1(A0)
        MOVE.L  #2,QP_COMMAND(A0)
       
    MOVE.L    NDOS_SYS_EXIT,D0
       TRAP    #0
     
       END  START