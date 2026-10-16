
; Static task identities for Scheduler Rev. 1.
TASK_A_PID      EQU     1
TASK_B_PID      EQU     2

 ;Initial MC68020 user-task exception-frame values.
TASK_INITIAL_SR             EQU     $0000   ;Task B stack top addresses.
MC68020_FORMAT0_FRAME       EQU     $0000
MC68020_SAVED_REG_BYTES     EQU     60 ; bytes for saved registers
MC68020_SAVED_REG_COUNT     EQU     15 ; number of saved registers
 
INITIAL_TASKB_VALUE         EQU     0   ;initial value for all registers in task B's context

; Find the first free record in the kernel-owned fixed PCB table.
; Output: D0 = 0 and A0 = free PCB; D0 = -1 and A0 = 0 if full.
; Clobbers: D0, D1, A0
;
; The NEX loader can use this before initializing a new process.  It must
; initialize the record before any later allocation attempt; current process
; memory placement remains limited to the existing Slot A / Slot B regions.
FIND_UNUSED_PCB:
        LEA     PCB_TABLE,A0
        MOVEQ   #MAX_PROCS,D1
.SCAN:
        CMPI.L  #PROC_UNUSED,PCB_STATE(A0)
        BEQ.S   .FOUND
        ADDA.L  #PCB_SIZEOF,A0
        SUBQ.L  #1,D1
        BNE.S   .SCAN

        MOVEQ   #-1,D0
        MOVEA.L #0,A0
        RTS

.FOUND:
        MOVEQ   #0,D0
        RTS


SCHEDULER:


.SCHEDULER_ENTRY:
    ADDQ.L  #1,YIELD_COUNT


.save_current:
  MOVEM.L D0-D7/A0-A6,-(A7) ;save current context
  MOVEA.L SCHED_CURRENT_PCB,A0     
  MOVE.L A7,PCB_SAVED_SSP(A0)
  MOVE.L USP,A1
  MOVE.L A1,PCB_SAVED_USP(A0)

   FSAVE PCB_FPU_FRAME(A0)
   FMOVEM.X FP0-FP7,PCB_FPU_REGS(A0)
   FMOVEM.L FPCR/FPSR/FPIAR,PCB_FPU_CONTROL(A0)
               
  MOVE.L  #PROC_READY,PCB_STATE(A0)  ;set current process to ready state

        BRA.W   SCHEDULER_SELECT_NEXT

; Shared by cooperative TRAP #1 and the DUART timer preemption path.  Entry
; expects the outgoing PCB already saved and marked READY.
SCHEDULER_SELECT_NEXT:
        MOVEA.L SCHED_CURRENT_PCB,A0 ; PCB that just yielded
        MOVEA.L A0,A1                ; scan candidate
        ADDA.L  #PCB_SIZEOF,A1       ; begin after current PCB
        MOVEQ   #MAX_PROCS,D1        ; inspect at most one full table

SCHEDULER_SCAN_CANDIDATE:
        CMPA.L  #PCB_TABLE_END,A1
        BNE.S   SCHEDULER_CHECK_CANDIDATE
        LEA     PCB_TABLE,A1         ; wrap to first PCB

SCHEDULER_CHECK_CANDIDATE:
        CMPI.L  #PROC_READY,PCB_STATE(A1)
        BEQ.S   SCHEDULER_SELECT_CANDIDATE

        ADDA.L  #PCB_SIZEOF,A1
        SUBQ.L  #1,D1
        BNE.S   SCHEDULER_SCAN_CANDIDATE

        ; The outgoing task was marked READY above, so it should be found.
        ; If the table is inconsistent, resume that saved task safely.
        BRA.S   SCHEDULER_RESTORE_AND_RETURN

SCHEDULER_SELECT_CANDIDATE:
        ; Count only a real process change, not a one-task resume.
        CMPA.L  SCHED_CURRENT_PCB,A1
        BEQ.S   SCHEDULER_SAME_CANDIDATE
        ADDQ.L  #1,SCHED_SWITCH_COUNT
SCHEDULER_SAME_CANDIDATE:
        MOVEA.L A1,A0
        MOVE.L  A0,SCHED_CURRENT_PCB

SCHEDULER_RESTORE_AND_RETURN:
        FMOVEM.X PCB_FPU_REGS(A0),FP0-FP7      ;restore fpu state
        FMOVEM.L PCB_FPU_CONTROL(A0),FPCR/FPSR/FPIAR
        FRESTORE PCB_FPU_FRAME(A0)

        MOVE.L  #PROC_RUNNING,PCB_STATE(A0)  ;restore cpu state 
        MOVE.L PCB_SAVED_USP(A0),A1
        MOVE.L A1,USP

        MOVE.L PCB_SAVED_SSP(A0),A7
        
        MOVEM.L (A7)+,D0-D7/A0-A6
        RTE  

  
INIT_TASK_B_CONTEXT:
      LEA     SECOND_PROCESS,A0
      MOVE.L  #TASK_B_PID,PCB_PID(A0)
      MOVE.L  TASK_B_INIT_BASE,PCB_BASE(A0)
      MOVE.L  TASK_B_INIT_SIZE,PCB_SIZE(A0)
      MOVE.L  TASK_B_INIT_ENTRY,PCB_ENTRY(A0)
      MOVE.L  TASK_B_INIT_STACK_TOP,PCB_STACK_TOP(A0)
      MOVE.L  TASK_B_INIT_USER_STACK,PCB_SAVED_USP(A0)

      MOVEA.L TASK_B_INIT_SUPERVISOR_TOP,A1

      MOVE.W  #MC68020_FORMAT0_FRAME,-(A1)
      MOVE.L  TASK_B_INIT_ENTRY,-(A1)
      MOVE.W  #TASK_INITIAL_SR,-(A1)

      suba.l   #MC68020_SAVED_REG_BYTES,A1
      move.l   A1,A2
      MOVE.L   #INITIAL_TASKB_VALUE,D1 ;value to initialize registers with
      MOVE.L   #MC68020_SAVED_REG_COUNT,D2 ;Put the value of MC68020_SAVED_REG_COUNT into D2.
   
      .REGISTER_INIT_LOOP: ;move the value in D1 into the registers saved on the stack 
      MOVE.L   D1,(A2)
      ADDQ.L #4,A2
      SUBQ.L #1,D2
      TST.L   D2
      BNE.S   .REGISTER_INIT_LOOP
 
      ; Task B's initial D7 selects the right display region in BRAIN.NEX.
      MOVEQ   #1,D0
      MOVE.L  D0,28(A1)

      
      move.l   A1,PCB_SAVED_SSP(A0)
      MOVE.L  #PROC_READY,PCB_STATE(A0)
      RTS
TASK_B_ENTRY:
.loop:
       
        ADDQ.L  #1,TASK_B_COUNTER
        TRAP    #1
        BRA     .loop
