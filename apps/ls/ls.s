   INCLUDE 'sdk/asm/ndos_syscall.inc'

   ORG 0
   
START:
        LEA     NEWLINE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D2
       
   .NEXT_ENTRY:
        MOVE.L  D2,D1
        LEA   DIRECTORY_ENTRY(PC),A1
        MOVEQ  #NDOS_SYS_READ_DIR,D0
        TRAP    #0

        TST.L  D0
        BMI   LS_ERROR

        CMPI.L #1,D0  ;END OF DIRECTORY?
        BEQ    .DONE

    ;d1 contains the ithe next idex visable 
    move.l d1,d2
    

      LEA DIRECTORY_ENTRY(PC),A1
      MOVEQ #NDOS_SYS_PUTS,D0
      TRAP #0

      LEA SIZE_SEPARATOR(PC),A1
      MOVEQ #NDOS_SYS_PUTS,D0
      TRAP #0

      LEA     DIRECTORY_ENTRY(PC),A2
      MOVE.L  NDOS_DIR_SIZE(A2),D0
      BSR     PRINT_HEX32

       LEA     NEWLINE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        
      BRA     .NEXT_ENTRY
      ;NEXT_ENTRY:

      .DONE:
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
    
      
;-----------------------------------------------------------
; PRINT_HEX32
;
; Input:
;   D0.L = value
;
; Preserves:
;   D2, D5-D7, A2-A6
;
; Clobbers:
;   D0, D1, D3, D4
;-----------------------------------------------------------

PRINT_HEX32:
        MOVE.L  D0,D3
        MOVEQ   #7,D4

.NEXT_DIGIT:
        ROL.L   #4,D3
        MOVE.L  D3,D1
        ANDI.L  #$0000000F,D1

        CMPI.B  #9,D1
        BLS     .NUMBER

        ADDI.B  #'A'-10,D1
        BRA     .PRINT

.NUMBER:
        ADDI.B  #'0',D1

.PRINT:
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0

        DBRA    D4,.NEXT_DIGIT
        RTS

LS_ERROR:

        LEA     ERROR_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        MOVEQ   #1,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0

   NEWLINE:
        DC.B    13,10,0



SIZE_SEPARATOR:
        DC.B    '  $',0


        ERROR_TEXT:
        DC.B    13,10,'LS: DIRECTORY READ FAILED',13,10,0
        EVEN

        DIRECTORY_ENTRY:
        DS.B    NDOS_DIR_ENTRY_SIZE

        END     START
