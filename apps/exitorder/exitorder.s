        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

; RUN2 places the second copy at $00020000.  Task A yields first; Task B
; exits immediately.  A successful test must resume A after B exits.
START:
        LEA     START(PC),A0
        CMPA.L  #$00020000,A0
        BCC.S   .TASK_B

.TASK_A:
        TRAP    #1
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.TASK_A_HANG:
        BRA.S   .TASK_A_HANG

.TASK_B:
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0
.TASK_B_HANG:
        BRA.S   .TASK_B_HANG

        END     START
