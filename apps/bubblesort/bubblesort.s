    INCLUDE "SDK/asm/ndos_syscall.inc"   
    
    
    ORG 0 
    
    
START:       
       
       LEA     ARRAY(PC),A1
        MOVEQ   #4,D4
        MOVEQ   #4,D5
        MOVEQ   #0,D7

OUTER:
        LEA     ARRAY(PC),A1
        MOVEQ   #0,D6

INNER:
        MOVE.l  (A1),D0
        MOVE.L  4(A1),D1
        CMP.L   D1,D0
        BLS     SKIP
        MOVE.L  D1,(A1)
        MOVE.L  D0,4(A1)
SKIP:
        ADDQ.L  #4,A1
        ADDQ.L  #1,D6
        CMP.L   D5,D6
        BNE     INNER
        ADDQ.l  #1,D7

        CMP.L   D4,D7
        BNE     OUTER
       
        LEA     DONETXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP #0

EXIT:
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP #0
    
DONETXT:
        DC.B    'SORT DONE',13,10,0

    ARRAY:  DC.L   72,13,125,19,22
  
    END START
