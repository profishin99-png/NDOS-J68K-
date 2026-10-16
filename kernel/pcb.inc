; -----------------------------------------------------------
; NDOS Process Control Block layout — Scheduler Rev. 1
;
; Offsets are byte offsets from a PCB base.  The first nine
; longwords preserve the pre-scheduler single-process record.
; The remaining fields reserve scheduler/region state only.
; -----------------------------------------------------------

PCB_PID                 EQU     0
PCB_STATE               EQU     4
PCB_BASE                EQU     8
PCB_SIZE                EQU     12
PCB_ENTRY               EQU     16
PCB_STACK_TOP           EQU     20
PCB_STACK_SIZE          EQU     24
PCB_KERNEL_SSP          EQU     28
PCB_EXIT_CODE           EQU     32

PCB_SIGNALS             EQU     36
PCB_WAIT_MASK           EQU     40
PCB_WAKE_TICK           EQU     44
PCB_QUANTUM_LEFT        EQU     48
PCB_REGION_ID           EQU     52
PCB_PHYSICAL_SLOT_BASE  EQU     56
PCB_SAVED_SSP         EQU     60
PCB_SAVED_USP         EQU     64

; Per-process MC68881 save area.  FSAVE's internal frame is variable length,
; so reserve for the MC68881 BUSY frame.  The visible FP data registers and
; control registers are saved separately with FMOVEM.
PCB_FPU_FLAGS           EQU     68
PCB_FPU_FRAME           EQU     72
PCB_FPU_FRAME_BYTES     EQU     $00B8   ; 184 bytes: maximum MC68881 frame
PCB_FPU_REGS            EQU     256     ; 72 + 184
PCB_FPU_REGS_BYTES      EQU     96      ; FP0-FP7, 8 extended values * 12
PCB_FPU_CONTROL         EQU     352     ; FPCR, FPSR, FPIAR
PCB_FPU_CONTROL_BYTES   EQU     12
PCB_SIZEOF              EQU     364     ; 68-byte CPU PCB + 296-byte FPU area

; FPU flags are a reservation for the upcoming save/restore implementation.
PCB_FPU_FLAG_VALID      EQU     1       ; saved state is initialized/usable
PCB_FPU_FLAG_USED       EQU     2       ; process has executed FPU instructions

; PCB capacity for the planned Task Manager / process table.
; Reserving records does not yet make all slots runnable.
MAX_PROCS               EQU     16
PCB_MAX_TASKS           EQU     MAX_PROCS
PCB_TABLE_BYTES         EQU     PCB_SIZEOF*MAX_PROCS

; Internal NDOS process states.  They are not yet a public ABI.
PROC_UNUSED             EQU     0
PROC_READY              EQU     1
PROC_RUNNING            EQU     2
PROC_WAITING            EQU     3
PROC_EXITED             EQU     4
