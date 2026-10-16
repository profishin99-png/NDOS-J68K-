        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0
START:
        LEA START_TEXT(PC),A1  ;PRINT START TEXT
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP #0

        MOVE.L #1200000,d1
        ; Syscall number is an immediate value; TRAP #0 returns ticks in D0.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D3                 ; save start ticks
        FMOVE.S NUM1,FP0
        FMOVE.S NUM2,FP1
        ; Register-to-register FPU arithmetic has no source-format suffix.
        ; The FP registers already contain the values loaded as singles.
        FADD    FP1,FP0
        FMOVE.S FP0,FLOAT_STORE
         FMOVE.S NUM3,FP2
floatloop:
        SUBQ.L  #1,D1
         FMOVE.S FLOAT_STORE,FP2
         FMUL    FP2,FP0
         FADD    FP1,FP0
         FADD    FP2,FP0
        FMOVE.S FP0,FLOAT_STORE
        TST.L   D1
        BNE.S   floatloop
        ; End ticks minus start ticks = elapsed 100 Hz timer ticks.
        MOVEQ   #NDOS_SYS_GET_TICKS,D0
        TRAP    #0
        MOVE.L  D0,D4
        SUB.L   D3,D4
        MOVE.L  D4,TICKS_STORE
        
     
        MOVE.L  TICKS_STORE,D2
        DIVU.L  #100,D2
        MOVE.L  D2,SECONDS_STORE


        LEA     TICKS_TEXT(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

        ; Convert SECONDS_STORE to a NUL-terminated decimal string in DECIMAL_BUFFER.
        MOVE.L  SECONDS_STORE,D1
        LEA     decimalBUFFER(PC),A1
        MOVEQ   #NDOS_SYS_FORMAT_U32,D0
        TRAP    #0
       
        LEA     decimalBUFFER(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        LEA     PASS_TEXT(PC),A1
        BRA.S   PRINT_AND_EXIT


PRINT_AND_EXIT:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.HANG:  BRA.S   .HANG
PASS_TEXT: DC.B 13,10,'FLOPS PASSED',13,10,0
TICKS_TEXT: DC.B 13,10,'ELAPSED SECONDS: ',0
START_TEXT: DC.B 13,10,'FPU TEST START' ,0
NUM1: DC.S 1.5,0
NUM2: DC.S 2.25,0
NUM3: DC.S 3.75,0

decimalBUFFER: DS.B 11            ; ten digits plus NUL, written by syscall 15
FLOAT_STORE: DC.S  0
TICKS_STORE: DC.L 0
SECONDS_STORE: DC.L 0
        END START
       
