;-----------------------------------------------------------
* Title      : NDOS Pre-Alpha
* Written by : James
* Description: per alpha Ndos
*-----------------------------------------------------------
        INCLUDE 'build/c-map.inc'
        INCLUDE 'kernel/pcb.inc'

        ORG     $000000

        DC.L    $00008000          ; Initial supervisor stack pointer
        DC.L    START              ; Reset vector


*-----------------------------------------------------------
* CPU exception vectors
*-----------------------------------------------------------
     ORG     $000008
        DC.L    EXC_BUS_ERROR

        ORG     $00000C
        DC.L    EXC_ADDRESS_ERROR

        ORG     $000010
        DC.L    EXC_ILLEGAL

        ORG     $000014
        DC.L    EXC_DIVIDE_ZERO

        ORG     $000018
        DC.L    EXC_CHK

        ORG     $00001C
        DC.L    EXC_TRAPV

        ORG     $000020
        DC.L    EXC_PRIVILEGE
*-----------------------------------------------------------
* MC68681 channel-A receive interrupt (programmed IVR $1A)
*-----------------------------------------------------------

        ORG     $000068
        DC.L    DUART_IRQ


*-----------------------------------------------------------
* Reserved CPLD1 timer IRQ
* The active MAME development tick arrives through DUART_IRQ/vector $1A.
*-----------------------------------------------------------

        ORG     $000070
        DC.L    timer_irq
        

*-----------------------------------------------------------
* TRAP #0 syscall vector
*-----------------------------------------------------------

        ORG     $000080
        DC.L    SYSCALL
        
        
;-----------------------------------------------------------
; TRAP #1 - scheduler / yield
;-----------------------------------------------------------
        ORG     $000084
        DC.L    SCHEDULER
;-----------------------------------------------------------
; NDOS storge block
;-----------------------------------------------------------
SECTOR_SIZE  EQU 512
RAMDISK_SECTORS EQU 1024

RAMDISK_BASE EQU $00100000
PHYSICAL_SRAM_SIZE   EQU $00200000
STATIC_RESERVED_SIZE EQU $000B0200
UNRESERVED_RAM_SIZE  EQU $0014FE00
RAMDISKSIZE  EQU $00080000
SECTOR_BUFFER EQU $00180000



  

;-----------------------------------------------------------
; NDOS memory map
;-----------------------------------------------------------

PROGRAM_BASE        EQU     $00010000
PROGRAM_LIMIT       EQU     $0001FFFF
; MAME-only experimental large-program area. Normal NEX apps remain below it.
LARGE_PROGRAM_BASE  EQU     $00030000
LARGE_PROGRAM_LIMIT EQU     $000FFFFF
PROGRAM_REGION_SIZE EQU     $00010000

; Scheduler Rev. 1 second physical NEX slot.  This is a proposed software
; allocation inside the existing 2 MiB SRAM; the original Slot A ABI remains.
PROGRAM_B_BASE        EQU     $00020000
PROGRAM_B_LIMIT       EQU     $0002FFFF
PROGRAM_B_REGION_SIZE EQU     $00010000

; J68K/MAME MC68681 virtual console (channel A, stride 4)
DUART_BASE          EQU     $00F00000
DUART_MR1A          EQU     DUART_BASE+0
DUART_SRA           EQU     DUART_BASE+4
DUART_CRA           EQU     DUART_BASE+8
DUART_TBA           EQU     DUART_BASE+12
DUART_RBA           EQU     DUART_BASE+12
DUART_ISR           EQU     DUART_BASE+20
DUART_IMR           EQU     DUART_BASE+20
DUART_ACR           EQU     DUART_BASE+16
DUART_CTUR          EQU     DUART_BASE+24
DUART_CTLR          EQU     DUART_BASE+28
DUART_IVR           EQU     DUART_BASE+48
DUART_START_TIMER   EQU     DUART_BASE+56
DUART_STOP_TIMER    EQU     DUART_BASE+60
; The MC68681 multiplexes these write-only output-port controls with the
; read-only counter/timer start and stop commands above.
DUART_SET_OPR        EQU     DUART_BASE+56
DUART_RESET_OPR      EQU     DUART_BASE+60
DUART_RTS_A_MASK     EQU     $01
DUART_RX_VECTOR     EQU     $1A
DUART_RX_IRQ_MASK   EQU     $02
DUART_TIMER_IRQ_MASK EQU    $08
DUART_INTERRUPT_MASK EQU     DUART_RX_IRQ_MASK+DUART_TIMER_IRQ_MASK
DUART_CTRL_C        EQU     $03
USER_ABORT_EXIT_CODE EQU    3
DUART_TIMER_ACR     EQU     $70
DUART_TIMER_PRELOAD EQU     $0480
; Byte indexes deliberately wrap at 256.  This doubles the old 128-byte
; interrupt-fed queue without changing the established queue ABI.
RX_BUFFER_SIZE      EQU     256
RX_BUFFER_MASK      EQU     RX_BUFFER_SIZE-1
; RTS is asserted while the queue is below PAUSE, then reasserted after the
; consumer has drained it to RESUME.  A physical terminal that honors RTS
; therefore has room for characters already in flight.
RX_RTS_PAUSE_THRESHOLD  EQU 224
RX_RTS_RESUME_THRESHOLD EQU 128
*-----------------------------------------------------------
* Kernel code
*-----------------------------------------------------------

        ORG     $000100

START:
        ; The ROM loader can transfer control while the final status character
        ; is still leaving the DUART.  Drain it, then reinitialize the channel
        ; before NDOS enables its own IRQs or attempts console output.
        MOVE.W  #$FFFF,D7
.DUART_HANDOFF_WAIT:
        BTST    #3,DUART_SRA       ; TxEMT: holding register and shift register empty
        BNE.S   .DUART_HANDOFF_READY
        DBRA    D7,.DUART_HANDOFF_WAIT
.DUART_HANDOFF_READY:
        MOVEA.L $FFF00050,A0       ; BIOS service table: BIOS_DUART_INIT
        JSR     (A0)

        EnableCache:
    MOVE.L  #$00000009,D0       ; %1001: Bit 3 (Clear) + Bit 0 (Enable)
    MOVEC   D0,CACR
    NOP
     MOVEQ.L #0,D0  ;CLEAR D0
        lea   CURRENT_PROCESS,A0
        move.l   a0,SCHED_CURRENT_PCB
        bsr     INIT_TASK_B_CONTEXT
        MOVEQ.L #0,D0  ;CLEAR D0
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        CLR.B   PROMPT_SKIP

        CLR.L   PROC_PID
        MOVE.L  #PROC_UNUSED,PROC_STATE
        CLR.L   PROC_EXIT_CODE

        CLR.B   RX_READ_INDEX
        CLR.B   RX_WRITE_INDEX
        CLR.W   RX_COUNT
        CLR.L   RX_OVERFLOW
        CLR.L   RX_RECEIVED
        CLR.L   tick_counter
        CLR.B   DUART_TIMER_PENDING

        ; Channel A output-port bit 0 is active-low RTS.  Assert it while
        ; NDOS can accept input.  MR2A enables CTS-gated transmit in boot.s.
        MOVE.B  #DUART_RTS_A_MASK,DUART_SET_OPR

        ; The boot loader configured channel A with interrupts masked.
        ; Install the DUART vector, enable RX-ready, then accept IRQs.
        MOVE.B  #DUART_RX_VECTOR,DUART_IVR

        ; MAME development tick: MC68681 timer at 100 Hz.
        ; X1/16 = 230400 Hz; 2*1152 clocks = 10 ms.
        ; The final CPLD1 timer ABI remains separate and unresolved.
        MOVE.B  #DUART_TIMER_ACR,DUART_ACR
        MOVE.B  #$04,DUART_CTUR
        MOVE.B  #$80,DUART_CTLR
        MOVE.B  DUART_START_TIMER,D0
        MOVE.B  #DUART_INTERRUPT_MASK,DUART_IMR
        MOVE.W  #$2000,SR
            MOVEQ.L #0,D0  ;CLEAR D0
 
  ; J68K console has no emulator keyboard-echo control call.
 
  move.w #1,d3
  
*print sys call        
             LEA     msg,A1

print:

        MOVEQ   #7,D0           ; NDOS puts    ;NDOS STARTUP MSG
        TRAP    #0
                                              ;ILLEGAL (DIGNOSTIC)  
      BRA  COMMAND_LOOP 
*-----------------------------------------------------------
* Command parser
*-----------------------------------------------------------

COMMAND_PARSER:
        LEA     CHAR_BUFFER,A0

        ; Empty command?
        TST.B   (A0)
        BEQ     COMMAND_SKIPPED
          

           ; Check HELP
        LEA     CHAR_BUFFER,A0
        LEA     CMD_HELP,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_HELP

        ; Check C toolchain/runtime bridge
        LEA     CHAR_BUFFER,A0
        LEA     CMD_CTEST,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_CTEST

        ;Check MAP
        LEA     CHAR_BUFFER,A0
        LEA     CMD_MAP,A1
        BSR     STRCMP
        TST.L   D0
        BEQ     COMMAND_MEMORYMAP

        LEA     CHAR_BUFFER,A0
        LEA     CMD_TM,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_TASK_MANAGER
        ; Check VERSION
        LEA     CHAR_BUFFER,A0
        LEA     CMD_VERSION,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_VERSION

        ; Check CLEAR
        LEA     CHAR_BUFFER,A0
        LEA     CMD_CLEAR,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_CLEAR

        ; Check KDR (safe WozMon-style RAM monitor)
        LEA     CHAR_BUFFER,A0
        LEA     CMD_KDR,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_KDR
        
          ; RUN requires a FAT12 filename after one space.
        LEA     CHAR_BUFFER,A0
        LEA     CMD_RUN2_PREFIX,A1
        BSR     STRPREFIX
        TST.L   D0
        BNE.W   .CHECK_RUN
        MOVE.B  #1,NEX_RUN2_MODE
        LEA     CHAR_BUFFER+5,A0
        MOVE.L  A0,NEX_NAME_PTR
        BRA.W   COMMAND_RUN
.CHECK_RUN:
        MOVE.B  #0,NEX_RUN2_MODE
        LEA     CHAR_BUFFER+4,A0
        MOVE.L  A0,NEX_NAME_PTR
        LEA     CHAR_BUFFER,A0
        LEA     CMD_RUN,A1
        BSR     STRCMP

        TST.L   D0
        BEQ.W   COMMAND_RUN_USAGE

        LEA     CHAR_BUFFER,A0
        LEA     CMD_RUN_PREFIX,A1
        BSR     STRPREFIX
        TST.L   D0
        BEQ.W   COMMAND_RUN

        ; Destructive write/read verification of all 128 RAM-disk sectors
        LEA     CHAR_BUFFER,A0
        LEA     CMD_DISKTEST,A1
        BSR     STRCMP

        TST.L   D0
        BEQ.W   COMMAND_DISKTEST
      
        ; FORMAT enters its own guarded confirmation prompt.  "FORMAT YES"
        ; is deliberately not a shell command, so a pasted command cannot
        ; bypass the confirmation step.
        ; FORMAT SD is explicit and formats only the mounted SD image.
        LEA     CHAR_BUFFER,A0
        LEA     CMD_FORMAT_SD,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_FORMAT_SD

        ; FORMAT alone retains its RAM-disk-only behavior.
        LEA     CHAR_BUFFER,A0
        LEA     CMD_FORMAT,A1
        BSR     STRCMP

        TST.L   D0
        BEQ.W   COMMAND_FORMAT

        ; Check mounted FAT12 volume information
        LEA     CHAR_BUFFER,A0
        LEA     CMD_FATINFO,A1
        BSR     STRCMP

        TST.L   D0
        BEQ.W   COMMAND_FATINFO

        ; Validate and report the active FAT12 volume (SD first, RAM fallback).
        LEA     CHAR_BUFFER,A0
        LEA     CMD_MOUNT,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_MOUNT

        ; Report static SRAM accounting and live FAT12 free space.
        LEA     CHAR_BUFFER,A0
        LEA     CMD_FREE,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_FREE

        ; List visible FAT12 root-directory entries
        LEA     CHAR_BUFFER,A0
        LEA     CMD_DIR,A1
        BSR     STRCMP

        TST.L   D0
        BEQ.W   COMMAND_DIR

        ; Diagnostic for FAT12 lookup and non-contiguous cluster reads
        LEA     CHAR_BUFFER,A0
        LEA     CMD_FTEST,A1
        BSR     STRCMP

        TST.L   D0
        BEQ.W   COMMAND_FTEST

        LEA     CHAR_BUFFER,A0
        LEA     CMD_WTEST,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_WTEST

        ; TYPE requires a filename argument after one space.
        LEA     CHAR_BUFFER,A0
        LEA     CMD_TYPE,A1
        BSR     STRCMP
        TST.L   D0
        BEQ.W   COMMAND_TYPE_USAGE

        LEA     CHAR_BUFFER,A0
        LEA     CMD_TYPE_PREFIX,A1
        BSR     STRPREFIX
        TST.L   D0
        BEQ.W   COMMAND_TYPE

        ; Nothing matched
        BRA     COMMAND_UNKNOWN


COMMAND_HELP:
        LEA     HELP_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE

COMMAND_FORMAT:
        CLR.B   FORMAT_TARGET
        BRA.W   FORMAT_CONFIRM_START

COMMAND_FORMAT_SD:
        MOVE.B  #1,FORMAT_TARGET

FORMAT_CONFIRM_START:
        ; Formatting is destructive. Ask for a separate input line, rather
        ; than accepting "FORMAT YES" as a command argument.
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        TST.B   FORMAT_TARGET
        BNE.S   FORMAT_WARN_SD
        LEA     FORMAT_WARNING_TEXT,A1
        BRA.S   FORMAT_SHOW_WARNING
FORMAT_WARN_SD:
        LEA     FORMAT_SD_WARNING_TEXT,A1
FORMAT_SHOW_WARNING:
        BSR     DUART_PUTS

FORMAT_CONFIRM_WAIT:
        MOVEQ   #6,D0
        TRAP    #0
        CMPI.L  #NDOS_BUFFER_FULL,D0
        BEQ     FORMAT_CANCELLED_HANDLER
        CMPI.L  #NDOS_LINE_READY,D0
        BNE     FORMAT_CONFIRM_WAIT

        LEA     CHAR_BUFFER,A0
        LEA     CMD_YES,A1
        BSR     STRCMP
        TST.L   D0
        BNE     FORMAT_CANCELLED_HANDLER

        LEA     FORMAT_START_TEXT,A1
        BSR     DUART_PUTS

        TST.B   FORMAT_TARGET
        BNE.S   FORMAT_CALL_SD
        JSR     NDOS_FORMAT_RAMDISK
        BRA.S   FORMAT_CHECK_RESULT
FORMAT_CALL_SD:
        JSR     NDOS_FORMAT_SDCARD
FORMAT_CHECK_RESULT:
        TST.L   D0
        BNE     FORMAT_FAILED

        TST.B   FORMAT_TARGET
        BNE.S   FORMAT_SD_COMPLETE
        LEA     FORMAT_COMPLETE_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE
FORMAT_SD_COMPLETE:
        LEA     FORMAT_SD_COMPLETE_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

FORMAT_CANCELLED_HANDLER:
        LEA     FORMAT_CANCELLED_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

FORMAT_FAILED:
        LEA     FORMAT_FAILED_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_MOUNT:
        JSR     NDOS_MOUNT_CURRENT_VOLUME
        TST.L   D0
        BMI     MOUNT_FAILED
        TST.L   D0
        BNE.S   MOUNT_SD_READY
        LEA     MOUNT_RAM_READY_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE
MOUNT_SD_READY:
        LEA     MOUNT_SD_READY_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE
MOUNT_FAILED:
        LEA     MOUNT_FAILED_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_FATINFO:
        JSR     NDOS_MOUNT_RAMDISK
        TST.L   D0
        BNE     FATINFO_FAILED

        LEA     FATINFO_OK_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

FATINFO_FAILED:
        LEA     FATINFO_FAILED_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_FREE:
        PEA     FREE_DISK_BYTES
        PEA     FREE_DISK_CLUSTERS
        JSR     NDOS_GET_DISK_FREE
        ADDQ.L  #8,A7
        TST.L   D0
        BNE     FREE_FAILED

        LEA     FREE_HEADER_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  #PHYSICAL_SRAM_SIZE,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     FREE_RESERVED_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  #STATIC_RESERVED_SIZE,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     FREE_RAM_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  #UNRESERVED_RAM_SIZE,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     FREE_DISK_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  FREE_DISK_BYTES,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     FREE_CLUSTERS_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  FREE_DISK_CLUSTERS,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     FREE_NOTE_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

FREE_FAILED:
        MOVE.L  D0,D2
        LEA     FREE_FAILED_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  D2,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_DIR:
        LEA     DIR_HEADER_TEXT,A1
        BSR     DUART_PUTS

        MOVEQ   #0,D4           ; visible root-entry index
        MOVEQ   #0,D5           ; number of entries printed

DIR_NEXT_ENTRY:
        MOVE.L  D4,-(A7)
        JSR     NDOS_DIR_GET
        ADDQ.L  #4,A7

        TST.L   D0
        BMI     DIR_FAILED
        BEQ     DIR_FINISHED

        LEA     SECTOR_BUFFER,A1
        BSR     DUART_PUTS
        LEA     DIR_SIZE_SEPARATOR,A1
        BSR     DUART_PUTS
        MOVE.L  SECTOR_BUFFER+16,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS

        ADDQ.L  #1,D4
        ADDQ.L  #1,D5
        BRA     DIR_NEXT_ENTRY

DIR_FINISHED:
        TST.L   D5
        BNE     COMMAND_DONE
        LEA     DIR_EMPTY_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

DIR_FAILED:
        LEA     DIR_FAILED_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_FTEST:
        JSR     NDOS_TEST_FILE_READ
        TST.L   D0
        BNE     FTEST_FAILED
        LEA     FTEST_OK_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

FTEST_FAILED:
        MOVE.L  D0,D6
        LEA     FTEST_FAILED_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  D6,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_WTEST:
        JSR     NDOS_TEST_FILE_CREATE
        TST.L   D0
        BNE     WTEST_FAILED
        LEA     WTEST_OK_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

WTEST_FAILED:
        MOVE.L  D0,D6
        LEA     WTEST_FAILED_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  D6,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_TYPE:
              LEA     CHAR_BUFFER+5,A0

        BSR     IS_TXT_FILENAME
        TST.L   D0
        BNE     COMMAND_TYPE_NOT_TEXT

        CLR.L   TYPE_BYTES_READ
        PEA     TYPE_BYTES_READ
        MOVE.L  #TYPE_BUFFER_SIZE,-(A7)
        PEA     TYPE_BUFFER
        PEA     CHAR_BUFFER+5
        JSR     NDOS_READ_FILE
        LEA     16(A7),A7

        TST.L   D0
        BNE     TYPE_FAILED
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        LEA     TYPE_BUFFER,A0
        MOVE.L  TYPE_BYTES_READ,D7
TYPE_PRINT_LOOP:
        TST.L   D7
        BEQ     TYPE_PRINT_DONE
        MOVE.B  (A0)+,D1
        BSR     DUART_PUTCHAR
        SUBQ.L  #1,D7
        BRA     TYPE_PRINT_LOOP
TYPE_PRINT_DONE:
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

TYPE_FAILED:
        CMPI.L  #-5,D0          ; FAT12_ERR_NOT_FOUND
        BEQ     TYPE_NOT_FOUND
        CMPI.L  #-9,D0          ; FAT12_ERR_INVALID_NAME
        BEQ     COMMAND_TYPE_USAGE
        MOVE.L  D0,D6
        LEA     TYPE_FAILED_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  D6,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE


  COMMAND_TYPE_NOT_TEXT:
        LEA     TYPE_TEXT_ONLY_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE      
TYPE_NOT_FOUND:
        LEA     TYPE_NOT_FOUND_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_TYPE_USAGE:
        LEA     TYPE_USAGE_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_VERSION:
        LEA     VERSION_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE

COMMAND_CTEST:
        LEA     CTEST_START_TEXT,A1
        BSR     DUART_PUTS

        JSR     NDOS_C_SELFTEST
        TST.L   D0
        BNE     COMMAND_CTEST_FAILED

        LEA     CTEST_PASS_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_CTEST_FAILED:
        MOVE.L  D0,D4
        LEA     CTEST_FAIL_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  D4,D0
        NEG.L   D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     CTEST_FAIL_HELP_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE


COMMAND_MEMORYMAP:
        LEA     MAP_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE

; Show development timer, scheduler counters, and active PCB records.
COMMAND_TASK_MANAGER:
        ADDQ.L  #1,TM_COMMAND_COUNT
        LEA     TM_HEADER_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  tick_counter,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     TM_YIELD_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  YIELD_COUNT,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     TM_SWITCH_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  SCHED_SWITCH_COUNT,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     TM_TABLE_HEADER,A1
        BSR     DUART_PUTS

        LEA     PCB_TABLE,A2
.TM_SCAN:
        CMPA.L  #PCB_TABLE_END,A2
        BEQ.W   .TM_DONE
        MOVE.L  PCB_STATE(A2),D3
        CMPI.L  #PROC_UNUSED,D3
        BEQ.W   .TM_NEXT

        MOVE.L  PCB_PID(A2),D0
        BSR     KDR_PRINT_HEX_LONG
        MOVE.B  #' ',D1
        BSR     DUART_PUTCHAR
        CMPI.L  #PROC_RUNNING,D3
        BEQ.S   .TM_RUNNING
        CMPI.L  #PROC_READY,D3
        BEQ.S   .TM_READY
        CMPI.L  #PROC_WAITING,D3
        BEQ.S   .TM_WAITING
        CMPI.L  #PROC_EXITED,D3
        BEQ.S   .TM_EXITED
        LEA     TM_OTHER_TEXT,A1
        BRA.S   .TM_PRINT_STATE
.TM_RUNNING:
        LEA     TM_RUNNING_TEXT,A1
        BRA.S   .TM_PRINT_STATE
.TM_READY:
        LEA     TM_READY_TEXT,A1
        BRA.S   .TM_PRINT_STATE
.TM_WAITING:
        LEA     TM_WAITING_TEXT,A1
        BRA.S   .TM_PRINT_STATE
.TM_EXITED:
        LEA     TM_EXITED_TEXT,A1
.TM_PRINT_STATE:
        BSR     DUART_PUTS
        MOVE.B  #' ',D1
        BSR     DUART_PUTCHAR
        MOVE.L  PCB_BASE(A2),D0
        BSR     KDR_PRINT_HEX_LONG
        MOVE.B  #' ',D1
        BSR     DUART_PUTCHAR
        MOVE.L  PCB_ENTRY(A2),D0
        BSR     KDR_PRINT_HEX_LONG
        MOVE.B  #' ',D1
        BSR     DUART_PUTCHAR
        CMPA.L  SCHED_CURRENT_PCB,A2
        BNE.S   .TM_NOT_CURRENT
        MOVE.B  #'*',D1
        BRA.S   .TM_MARKER
.TM_NOT_CURRENT:
        MOVE.B  #' ',D1
.TM_MARKER:
        BSR     DUART_PUTCHAR
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
.TM_NEXT:
        ADDA.L  #PCB_SIZEOF,A2
        BRA     .TM_SCAN
.TM_DONE:
        BRA     COMMAND_DONE

COMMAND_RUN:
        ; Split "RUN FILE.NEX [ARG]" in place.  The executable name remains
        ; at CHAR_BUFFER+4 and NEX_ARG_SOURCE points at the optional argument.
        CLR.L   NEX_ARG_SOURCE
        MOVEA.L NEX_NAME_PTR,A0
.FIND_NAME_END:
        MOVE.B  (A0),D0
        BEQ     .NAME_READY
        CMPI.B  #' ',D0
        BEQ     .FOUND_SEPARATOR
        ADDQ.L  #1,A0
        BRA     .FIND_NAME_END
.FOUND_SEPARATOR:
        CLR.B   (A0)+
.SKIP_SPACES:
        CMPI.B  #' ',(A0)
        BNE     .CHECK_ARGUMENT
        ADDQ.L  #1,A0
        BRA     .SKIP_SPACES
.CHECK_ARGUMENT:
        TST.B   (A0)
        BEQ     .NAME_READY
        MOVE.L  A0,NEX_ARG_SOURCE
.NAME_READY:
        CLR.L   NEX_FILE_BYTES
        PEA     NEX_FILE_BYTES
        MOVE.L  #NEX_FILE_BUFFER_SIZE,-(A7)
        PEA     NEX_FILE_BUFFER
        MOVE.L  NEX_NAME_PTR,-(A7)
        JSR     NDOS_READ_FILE
        LEA     16(A7),A7
        TST.L   D0
        BNE.W   NEX_FILE_ERROR

        ; Validate the disk file and copy its payload into Slot A.
        LEA     NEX_FILE_BUFFER,A0
        MOVE.L  NEX_FILE_BYTES,D6
        MOVEA.L #PROGRAM_BASE,A2
        BSR     LOAD_NEX

        TST.L   D0
        BNE     NEX_ERROR

        ; D1 = FS
        ; D2 = EP
        ; D3 = SS

        ; Entry address = PROGRAM_BASE + EP
        MOVEA.L #PROGRAM_BASE,A0
        ADDA.L  D2,A0

        ; User stack top.  If present, copy the single argument to the top of
        ; the process region and place USP immediately below it.  The NEX
        ; stack reservation must be large enough to contain this startup data.
        MOVEA.L #PROGRAM_LIMIT+1,A1

        CLR.L   NEX_START_ARGC
        CLR.L   NEX_START_ARG_PTR
        MOVEA.L NEX_ARG_SOURCE,A2
        MOVE.L  A2,D4
        BEQ     .ARGUMENT_READY

        MOVEA.L A2,A3
        MOVEQ   #1,D4                   ; include the terminating zero
.COUNT_ARGUMENT:
        TST.B   (A3)+
        BEQ     .ARGUMENT_SIZE_READY
        ADDQ.L  #1,D4
        BRA     .COUNT_ARGUMENT
.ARGUMENT_SIZE_READY:
        CMP.L   D3,D4
        BHS.W   NEX_ARGUMENT_TOO_LONG
        SUBA.L  D4,A1
        MOVE.L  A1,D5
        ANDI.L  #$FFFFFFFE,D5
        MOVEA.L D5,A1
        MOVE.L  A1,NEX_START_ARG_PTR
        MOVE.L  #1,NEX_START_ARGC
        MOVEA.L A1,A3
.COPY_ARGUMENT:
        MOVE.B  (A2)+,(A3)+
        BNE     .COPY_ARGUMENT
.ARGUMENT_READY:


        ; --------------------------------------------
        ; Initialize process control block
        ; --------------------------------------------

        MOVE.L  #1,PROC_PID
        MOVE.L  #PROC_RUNNING,PROC_STATE

        MOVE.L  #PROGRAM_BASE,PROC_BASE
        MOVE.L  D1,PROC_SIZE

        MOVE.L  A0,PROC_ENTRY
        MOVE.L  A1,PROC_STACK_TOP
        MOVE.L  D3,PROC_STACK_SIZE

        MOVE.L  A7,PROC_KERNEL_SSP
        CLR.L   PROC_EXIT_CODE


        ; Keep this for the moment because SYS_EXIT
        ; still uses the old KERNEL_SSP variable.
        MOVE.L  A7,KERNEL_SSP

        TST.B   NEX_RUN2_MODE
        BNE.W   .PREPARE_SECOND_NEX
        BRA     LAUNCH_PROGRAM

.PREPARE_SECOND_NEX:
        MOVE.L  A0,-(A7)
        MOVE.L  A1,-(A7)
        BSR.W   PREPARE_SECOND_NEX
        MOVEA.L (A7)+,A1
        MOVEA.L (A7)+,A0
        BRA     LAUNCH_PROGRAM

PREPARE_SECOND_NEX:
        LEA     PROGRAM_BASE,A0
        LEA     PROGRAM_B_BASE,A1
        MOVE.L  PROC_SIZE,D6
.COPY_SECOND_NEX:
        MOVE.B  (A0)+,(A1)+
        SUBQ.L  #1,D6
        BNE.S   .COPY_SECOND_NEX

        MOVE.L  #PROGRAM_B_BASE,TASK_B_INIT_BASE
        MOVE.L  PROC_SIZE,TASK_B_INIT_SIZE
        MOVE.L  PROC_ENTRY,D0
        ADDI.L  #(PROGRAM_B_BASE-PROGRAM_BASE),D0
        MOVE.L  D0,TASK_B_INIT_ENTRY
        MOVE.L  #PROGRAM_B_LIMIT+1,TASK_B_INIT_STACK_TOP
        MOVE.L  #PROGRAM_B_LIMIT+1,TASK_B_INIT_USER_STACK
        BSR.W   INIT_TASK_B_CONTEXT
        RTS

COMMAND_RUN_USAGE:
        LEA     RUN_USAGE_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

NEX_FILE_ERROR:
        CMPI.L  #-5,D0
        BEQ     NEX_FILE_NOT_FOUND
        CMPI.L  #-9,D0
        BEQ     COMMAND_RUN_USAGE
        MOVE.L  D0,D6
        LEA     NEX_READ_ERROR_TEXT,A1
        BSR     DUART_PUTS
        MOVE.L  D6,D0
        BSR     KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

NEX_FILE_NOT_FOUND:
        LEA     NEX_NOT_FOUND_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

NEX_ARGUMENT_TOO_LONG:
        LEA     NEX_ARGUMENT_ERROR_TEXT,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

COMMAND_CLEAR:
        LEA     DUART_CLEAR_SEQ,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

;-----------------------------------------------------------
; DISKTEST - destructive verification of the complete RAM disk
;
; Writes sector N with 512 copies of byte N, then reads every sector
; through BLOCK_READ and checks all 512 bytes.  D4 holds the sector.
;-----------------------------------------------------------
COMMAND_DISKTEST:
        LEA     DISKTEST_START_TEXT,A1
        BSR.W   DUART_PUTS

        MOVEQ   #0,D4
DISKTEST_WRITE_SECTOR:
        LEA     SECTOR_BUFFER,A0
        MOVE.W  #SECTOR_SIZE-1,D5
        MOVE.B  D4,D6
DISKTEST_FILL_BYTE:
        MOVE.B  D6,(A0)+
        DBRA    D5,DISKTEST_FILL_BYTE

        LEA     SECTOR_BUFFER,A0
        MOVE.L  D4,D0
        BSR.W   BLOCK_WRITE
        TST.L   D0
        BNE.W   DISKTEST_FAILED

        ADDQ.L  #1,D4
        CMPI.L  #RAMDISK_SECTORS,D4
        BLO     DISKTEST_WRITE_SECTOR

        MOVEQ   #0,D4
DISKTEST_READ_SECTOR:
        ; Poison the buffer so a short or missing read cannot compare equal.
        LEA     SECTOR_BUFFER,A0
        MOVE.W  #SECTOR_SIZE-1,D5
DISKTEST_POISON_BYTE:
        MOVE.B  #$A5,(A0)+
        DBRA    D5,DISKTEST_POISON_BYTE

        LEA     SECTOR_BUFFER,A0
        MOVE.L  D4,D0
        BSR.W   BLOCK_READ
        TST.L   D0
        BNE.W   DISKTEST_FAILED

        LEA     SECTOR_BUFFER,A0
        MOVE.W  #SECTOR_SIZE-1,D5
        MOVE.B  D4,D7
DISKTEST_VERIFY_BYTE:
        CMP.B   (A0)+,D7
        BNE.W   DISKTEST_FAILED
        DBRA    D5,DISKTEST_VERIFY_BYTE

        ADDQ.L  #1,D4
        CMPI.L  #RAMDISK_SECTORS,D4
        BLO     DISKTEST_READ_SECTOR

        LEA     DISKTEST_PASS_TEXT,A1
        BSR.W   DUART_PUTS
        BRA.W   COMMAND_DONE

DISKTEST_FAILED:
        LEA     DISKTEST_FAIL_TEXT,A1
        BSR.W   DUART_PUTS
        MOVE.L  D4,D0
        BSR.W   KDR_PRINT_HEX_LONG
        LEA     KDR_NEWLINE,A1
        BSR.W   DUART_PUTS
        BRA.W   COMMAND_DONE
;--------------------------------------------------
 ; comma
;-----------------------------------------------------------
; KDR RAM monitor
;
;   address             examine 16 bytes
;   address.end         examine inclusive range
;   address: byte ...   deposit bytes in RAM-disk window
;   Q                   return to NDOS
;
; There is deliberately no R/run command.  Reads are limited to the 2 MiB
; SRAM range.  Writes are further restricted to the 64 KiB RAM disk so a
; typo cannot overwrite the resident kernel, vectors, stack or NEX program.
;-----------------------------------------------------------
COMMAND_KDR:
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        LEA     KDR_BANNER,A1
        BSR     DUART_PUTS

KDR_LOOP:
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        LEA     KDR_PROMPT,A1
        BSR     DUART_PUTS

KDR_WAIT_INPUT:
        MOVEQ   #6,D0
        TRAP    #0
        CMPI.L  #NDOS_BUFFER_FULL,D0
        BEQ     KDR_INPUT_ERROR
        CMPI.L  #NDOS_LINE_READY,D0
        BNE     KDR_WAIT_INPUT

        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        LEA     CHAR_BUFFER,A0
        CMPI.B  #'Q',(A0)
        BNE     KDR_EXEC_LINE
        TST.B   1(A0)
        BEQ     KDR_EXIT

KDR_EXEC_LINE:
        BSR     KDR_SKIP_SPACES
        CMPI.B  #'$',(A0)
        BNE     KDR_PARSE_START
        ADDQ.L  #1,A0
KDR_PARSE_START:
        BSR     KDR_PARSE_HEX
        TST.W   D2
        BEQ     KDR_SYNTAX_ERROR
        MOVE.L  D0,D4
        CMPI.L  #$001FFFFF,D4
        BHI     KDR_RANGE_ERROR
        BSR     KDR_SKIP_SPACES

        TST.B   (A0)
        BEQ     KDR_EXAMINE_LINE
        CMPI.B  #'.',(A0)
        BEQ     KDR_EXAMINE_RANGE
        CMPI.B  #':',(A0)
        BEQ.W   KDR_DEPOSIT
        BRA     KDR_SYNTAX_ERROR

KDR_EXAMINE_LINE:
        MOVE.L  D4,D6
        ADDI.L  #15,D6
        CMPI.L  #$001FFFFF,D6
        BLS     KDR_DUMP_RANGE
        MOVE.L  #$001FFFFF,D6
        BRA     KDR_DUMP_RANGE

KDR_EXAMINE_RANGE:
        ADDQ.L  #1,A0
        BSR     KDR_SKIP_SPACES
        CMPI.B  #'$',(A0)
        BNE     KDR_PARSE_END
        ADDQ.L  #1,A0
KDR_PARSE_END:
        BSR     KDR_PARSE_HEX
        TST.W   D2
        BEQ     KDR_SYNTAX_ERROR
        MOVE.L  D0,D6
        BSR     KDR_SKIP_SPACES
        TST.B   (A0)
        BNE     KDR_SYNTAX_ERROR
        CMP.L   D4,D6
        BLO     KDR_RANGE_ERROR
        CMPI.L  #$001FFFFF,D6
        BHI     KDR_RANGE_ERROR
        BRA     KDR_DUMP_RANGE

KDR_DEPOSIT:
        CMPI.L  #RAMDISK_BASE,D4
        BLO     KDR_WRITE_PROTECT
        CMPI.L  #RAMDISK_BASE+RAMDISKSIZE-1,D4
        BHI.W   KDR_WRITE_PROTECT
        MOVE.L  D4,D7
        ADDQ.L  #1,A0
        MOVEQ   #0,D6

KDR_DEPOSIT_NEXT:
        BSR     KDR_SKIP_SPACES
        TST.B   (A0)
        BEQ     KDR_DEPOSIT_DONE
        CMPI.B  #'$',(A0)
        BNE     KDR_PARSE_BYTE
        ADDQ.L  #1,A0
KDR_PARSE_BYTE:
        BSR     KDR_PARSE_HEX
        TST.W   D2
        BEQ     KDR_SYNTAX_ERROR
        CMPI.W  #2,D2
        BHI     KDR_SYNTAX_ERROR
        CMPI.L  #$FF,D0
        BHI     KDR_SYNTAX_ERROR
        CMPI.L  #RAMDISK_BASE+RAMDISKSIZE-1,D4
        BHI     KDR_WRITE_PROTECT
        MOVEA.L D4,A2
        MOVE.B  D0,(A2)
        ADDQ.L  #1,D4
        ADDQ.L  #1,D6
        BRA     KDR_DEPOSIT_NEXT

KDR_DEPOSIT_DONE:
        TST.L   D6
        BEQ     KDR_SYNTAX_ERROR
        MOVE.L  D4,D6
        SUBQ.L  #1,D6
        MOVE.L  D7,D4
        BRA     KDR_DUMP_RANGE

KDR_DUMP_RANGE:
KDR_DUMP_LINE:
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        MOVE.L  D4,D0
        BSR     KDR_PRINT_HEX_LONG
        MOVE.B  #':',D1
        BSR.W   DUART_PUTCHAR
        MOVEQ   #15,D7

KDR_DUMP_BYTE:
        MOVE.B  #' ',D1
        BSR     DUART_PUTCHAR
        MOVEQ   #0,D0
        MOVEA.L D4,A2
        MOVE.B  (A2),D0
        BSR     KDR_PRINT_HEX_BYTE
        CMP.L   D6,D4
        BEQ     KDR_DUMP_DONE
        ADDQ.L  #1,D4
        DBRA    D7,KDR_DUMP_BYTE
        BRA     KDR_DUMP_LINE

KDR_DUMP_DONE:
        LEA     KDR_NEWLINE,A1
        BSR     DUART_PUTS
        BRA     KDR_LOOP

KDR_INPUT_ERROR:
        LEA     KDR_BUFFER_ERROR_TEXT,A1
        BRA     KDR_SHOW_ERROR
KDR_SYNTAX_ERROR:
        LEA     KDR_SYNTAX_ERROR_TEXT,A1
        BRA     KDR_SHOW_ERROR
KDR_RANGE_ERROR:
        LEA     KDR_RANGE_ERROR_TEXT,A1
        BRA     KDR_SHOW_ERROR
KDR_WRITE_PROTECT:
        LEA     KDR_WRITE_ERROR_TEXT,A1
KDR_SHOW_ERROR:
        BSR     DUART_PUTS
        BRA     KDR_LOOP

KDR_EXIT:
        BRA     COMMAND_DONE

; Parse up to eight hexadecimal digits at A0.
; Returns D0=value, D2=digit count and A0 at the first non-hex byte.
KDR_PARSE_HEX:
        MOVEQ   #0,D0
        MOVEQ   #0,D2
KDR_HEX_LOOP:
        CMPI.W  #8,D2
        BHS     KDR_HEX_DONE
        MOVEQ   #-1,D3
        MOVE.B  (A0),D1
        CMPI.B  #'0',D1
        BLO     KDR_HEX_UPPER
        CMPI.B  #'9',D1
        BHI     KDR_HEX_UPPER
        MOVEQ   #0,D3
        MOVE.B  D1,D3
        SUBI.B  #'0',D3
        BRA     KDR_HAVE_NIBBLE
KDR_HEX_UPPER:
        CMPI.B  #'A',D1
        BLO     KDR_HEX_LOWER
        CMPI.B  #'F',D1
        BHI     KDR_HEX_LOWER
        MOVEQ   #0,D3
        MOVE.B  D1,D3
        SUBI.B  #'A'-10,D3
        BRA     KDR_HAVE_NIBBLE
KDR_HEX_LOWER:
        CMPI.B  #'a',D1
        BLO     KDR_HEX_DONE
        CMPI.B  #'f',D1
        BHI     KDR_HEX_DONE
        MOVEQ   #0,D3
        MOVE.B  D1,D3
        SUBI.B  #'a'-10,D3
KDR_HAVE_NIBBLE:
        LSL.L   #4,D0
        OR.B    D3,D0
        ADDQ.W  #1,D2
        ADDQ.L  #1,A0
        BRA     KDR_HEX_LOOP
KDR_HEX_DONE:
        RTS

KDR_SKIP_SPACES:
        CMPI.B  #' ',(A0)
        BNE     KDR_SPACES_DONE
        ADDQ.L  #1,A0
        BRA     KDR_SKIP_SPACES
KDR_SPACES_DONE:
        RTS

KDR_PRINT_HEX_LONG:
        MOVEM.L D0-D3,-(A7)
        MOVE.L  D0,D3
        MOVEQ   #7,D2
KDR_LONG_LOOP:
        ROL.L   #4,D3
        MOVE.L  D3,D0
        ANDI.L  #$0F,D0
        BSR     KDR_PRINT_NIBBLE
        DBRA    D2,KDR_LONG_LOOP
        MOVEM.L (A7)+,D0-D3
        RTS

KDR_PRINT_HEX_BYTE:
        MOVEM.L D0-D2,-(A7)
        MOVE.L  D0,D2
        LSR.B   #4,D0
        ANDI.L  #$0F,D0
        BSR     KDR_PRINT_NIBBLE
        MOVE.L  D2,D0
        ANDI.L  #$0F,D0
        BSR     KDR_PRINT_NIBBLE
        MOVEM.L (A7)+,D0-D2
        RTS

KDR_PRINT_NIBBLE:
        ADDI.B  #'0',D0
        CMPI.B  #'9',D0
        BLS     KDR_PRINT_DIGIT
        ADDI.B  #'A'-'9'-1,D0
KDR_PRINT_DIGIT:
        MOVE.B  D0,D1
        BSR     DUART_PUTCHAR
        RTS

COMMAND_SKIPPED:
        MOVE.B  #1,PROMPT_SKIP
        BRA  COMMAND_LOOP

COMMAND_UNKNOWN:
        LEA     UNKNOWN_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE


COMMAND_DONE:
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        BRA     COMMAND_LOOP    
        
        
       
  ;get input

 COMMAND_LOOP:
        TST.B   PROMPT_SKIP
        BNE     .skip_prompt

        BSR     PRINT_PROMPT
  .skip_prompt:
        CLR.B   PROMPT_SKIP
        BRA     input

 input:
        MOVEQ   #6,D0
        TRAP    #0

        CMPI.L  #NDOS_BUFFER_FULL,D0
        BEQ     error

        CMPI.L  #NDOS_LINE_READY,D0
        BEQ     COMMAND_PARSER

        BRA     input

 
  
  
error: 
            LEA     err,A1
        MOVEQ   #7,D0
        TRAP    #0

        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        BRA     input

*-----------------------------------------------------------
* Kernel utility routines
*-----------------------------------------------------------

STRCMP:
.loop:
        MOVE.B  (A0)+,D1
        MOVE.B  (A1)+,D2

        ; Fold ASCII a-z to A-Z without modifying either source string.
        CMPI.B  #'a',D1
        BLO.W   .d1_folded
        CMPI.B  #'z',D1
        BHI     .d1_folded
        SUBI.B  #'a'-'A',D1
.d1_folded:
        CMPI.B  #'a',D2
        BLO     .d2_folded
        CMPI.B  #'z',D2
        BHI     .d2_folded
        SUBI.B  #'a'-'A',D2
.d2_folded:

        CMP.B   D2,D1
        BNE     .not_equal

        TST.B   D1
        BEQ     .equal

        BRA     .loop

.equal:
        MOVEQ   #0,D0
        RTS

.not_equal:
        MOVEQ   #1,D0
        RTS

; Compare a zero-terminated command prefix. A0 may contain trailing text.
STRPREFIX:
.loop:
        MOVE.B  (A1)+,D2
        BEQ     .equal
        MOVE.B  (A0)+,D1
        CMPI.B  #'a',D1
        BLO     .d1_folded
        CMPI.B  #'z',D1
        BHI     .d1_folded
        SUBI.B  #'a'-'A',D1
.d1_folded:
        CMPI.B  #'a',D2
        BLO     .d2_folded
        CMPI.B  #'z',D2
        BHI     .d2_folded
        SUBI.B  #'a'-'A',D2
.d2_folded:
        CMP.B   D2,D1
        BEQ     .loop
        MOVEQ   #1,D0
        RTS
.equal:
        MOVEQ   #0,D0
        RTS


PRINT_PROMPT:
        LEA     PROMPT_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        RTS
 ;-----------------------------------------------------------
; IS_TXT_FILENAME
;
; Input:
;   A0 = zero-terminated filename
;
; Output:
;   D0 = 0  filename ends in .TXT and has a nonempty base
;   D0 = -1 missing, unterminated, or different extension
;
; Preserves:
;   A0
;
; Clobbers:
;   A1, D1
;-----------------------------------------------------------

IS_TXT_FILENAME:
        MOVE.L  A0,-(A7)
        MOVEA.L A0,A1
        MOVEQ   #127,D1

.FIND_END:
        TST.B   (A1)
        BEQ     .AT_END
        ADDQ.L  #1,A1
        DBRA    D1,.FIND_END

        ; No zero terminator in the permitted input range.
        BRA     .NOT_TXT

.AT_END:
        ; Require at least "A.TXT".
        MOVE.L  A1,D1
        SUB.L   A0,D1
        CMPI.L  #5,D1
        BLO     .NOT_TXT

        CMPI.B  #'.',-4(A1)
        BNE.W   .NOT_TXT

        MOVE.B  -3(A1),D1
        ANDI.B  #$DF,D1
        CMPI.B  #'T',D1
        BNE     .NOT_TXT

        MOVE.B  -2(A1),D1
        ANDI.B  #$DF,D1
        CMPI.B  #'X',D1
        BNE     .NOT_TXT

        MOVE.B  -1(A1),D1
        ANDI.B  #$DF,D1
        CMPI.B  #'T',D1
        BNE     .NOT_TXT

        MOVEQ   #0,D0
        BRA     .DONE

.NOT_TXT:
        MOVEQ   #-1,D0

.DONE:
        MOVEA.L (A7)+,A0
        RTS
; Input:
;   A1 = filename
;
; Return:
;   D0 = 0 valid bounded string
;   D0 = -2 invalid pointer or unterminated string
;
; Clobbers:
;   D1, A0

VALIDATE_USER_FILENAME:
        MOVE.L  A1,D1
        CMPI.L  #PROGRAM_BASE,D1
        BLO     .BAD

        CMPI.L  #PROGRAM_LIMIT,D1
        BHI     .BAD

        MOVEA.L A1,A0
        MOVEQ   #12,D1

        ; Reject an empty filename.
        TST.B   (A0)
        BEQ     .BAD

.SCAN:
        TST.B   (A0)+
        BEQ     .GOOD

        ; Reject before reading beyond user memory.
        CMPA.L  #PROGRAM_LIMIT+1,A0
        BHS.W   .BAD

        DBRA    D1,.SCAN

.BAD:
        MOVEQ   #-2,D0 ;BAD FILE 
        RTS

.GOOD:
        MOVEQ   #0,D0 ;VALID  FILE
        RTS
*-----------------------------------------------------------
; BLOCK_WRITE
; D0 = sector number, 0-127
; A0 = source buffer, 512 bytes
; Returns D0 = 0 or -1
; Preserves A0
; Clobbers A1, D2, D3

; BLOCK_READ
; D0 = sector number, 0-127
; A0 = destination buffer, 512 bytes
; Returns D0 = 0 or -1
; Preserves A0
; Clobbers A1, D2, D3


;D0 = sector number
;A0 = source buffer
;D3 = BYTE COUNTER
;D2 =  D0 original vaulue
;if D0 >= RAMDISK_SECTORS:
    ;D0 = -1
    ;return

;A1 = RAMDISK_BASE + (D0 << 9)

;copy 512 bytes:
    ;(A0)+ ? (A1)+

;D0 = 0
;return

BLOCK_WRITE:
     
          ;range check   
         
         MOVE.l  a0,d2  ;save callers a0
           TST.L   D0
         BMI    MEM_error        ; D0 < 0
          
        CMP.L   #RAMDISK_SECTORS,D0
        BGE   MEM_error

      
         
          lsl #8,d0 ;calculate off set
          lsl #1,d0
         
           move.l  #RAMDISK_BASE,a1  
           add.l d0,a1 ;add base
            
             MOVE.l  #127,D3
.copy:
                MOVE.L  (A0)+,(A1)+
                DBRA    D3,.copy
                     
   
          bra .done


.done:      
       move.l #0,d0 
       move.l d2,a0 ;restore called a0
       rts  
  
            



     BLOCK_READ:
        MOVE.L  A0,D2

        TST.L   D0
        BMI     MEM_error

        CMP.L   #RAMDISK_SECTORS,D0
        BGE     MEM_error

        LSL.L   #8,D0
        LSL.L   #1,D0

        MOVEA.L #RAMDISK_BASE,A1
        ADDA.L  D0,A1

        MOVEQ   #127,D3

.copy:
        MOVE.L  (A1)+,(A0)+
        DBRA    D3,.copy

        MOVEQ   #0,D0
        MOVE.L  D2,A0
        RTS

MEM_error:
        MOVE.L  D2,A0
        MOVEQ   #-1,D0
        RTS
  
;-----------------------------------------------------------
; NEX loader
; A0 = NEX header address
; A2 = destination program-slot base
; D6 = number of bytes available at A0
; D0 = 0 on success, -1 on failure
; On success: D1 = FS, D2 = EP, D3 = SS
; Clobbers A1, A2, D4, D5, D6

;-----------------------------------------------------------


LOAD_NEX:
        ; Need the entire 16-byte header before reading its fields.
        CMPI.L  #16,D6
        BLO     .BAD_HEADER

        CMPI.L  #$4E444F53,(A0)    ; "NDOS"
        BNE     .BAD_HEADER

        MOVE.L  4(A0),D1           ; FS: image size
        TST.L   D1
        BEQ     .BAD_HEADER
        CMPI.L  #PROGRAM_REGION_SIZE,D1
        BHI     .BAD_HEADER

        ; Confirm the supplied source includes all image bytes.
        SUBI.L  #16,D6             ; Bytes available after header
        CMP.L   D6,D1
        BHI     .BAD_HEADER

        MOVE.L  8(A0),D2           ; EP: entry offset
        CMP.L   D1,D2
        BHS     .BAD_HEADER        ; EP must be inside image
        BTST    #0,D2
        BNE     .BAD_HEADER        ; Instruction address must be even

        MOVE.L  12(A0),D3          ; SS: reserved stack size
        TST.L   D3
        BEQ     .BAD_HEADER

        MOVE.L  D1,D4
        ADD.L   D3,D4
        BCS     .BAD_HEADER        ; Reject 32-bit overflow
        CMPI.L  #PROGRAM_REGION_SIZE,D4
        BHI     .BAD_HEADER        ; Image + stack must fit

        LEA     16(A0),A1
        MOVE.L  D1,D5

.COPY:
        MOVE.B  (A1)+,(A2)+
        SUBQ.L  #1,D5
        BNE     .COPY

        MOVEQ   #0,D0
        RTS

.BAD_HEADER:
        MOVEQ   #-1,D0
        RTS
NEX_ERROR:
        LEA     NEX_ERROR_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE
*-----------------------------------------------------------
* Enter user mode
*-----------------------------------------------------------

*-----------------------------------------------------------
* Launch user program
*
* A0 = program entry address
* A1 = user stack top
*-----------------------------------------------------------

LAUNCH_PROGRAM:
        clr.w BUF_INDEX

      MOVE.L  #$00000009,D0
        MOVEC   D0,CACR
        NOP

        MOVE.L  A1,USP

        ; Build initial MC68020 format-0 frame
       
        CLR.W   -(A7)   ; format/vector word
        MOVE.L  A0,-(A7)   ; user entry PC
        MOVE.W  #$0000,-(A7)  ; user mode, interrupts 

        ; NEX startup ABI: D0 is argc (zero or one), and A0 points to the
        ; zero-terminated argument when argc is one.
        MOVE.L  NEX_START_ARGC,D0
        MOVEA.L NEX_START_ARG_PTR,A0

        RTE
        
 ;-----------------------------------------------------------
;            scheduler
;-----------------------------------------------------------
         INCLUDE 'kernel/scheduler.s'



*-----------------------------------------------------------
* NDOS syscall dispatcher/KERNAL PANIC/IRQ
*
* D0 = syscall number
* D1 = argument 1
* D2 = argument 2
*
* D3 / A0 = kernel scratch
* D0 = return value
* A1 = STRING ADRESS
*-----------------------------------------------------------
KERNAL_PANIC:
        MOVE.L  D0,PANIC_VECTOR
        MOVE.W  (A7),PANIC_SR
        MOVE.L  2(A7),PANIC_PC
        MOVE.W  6(A7),PANIC_FRAME_WORD
        MOVE.L #$DEADBEEF,D7 ;panic marker
             ; Was a user process running?
        CMPI.L  #PROC_RUNNING,PROC_STATE
        BNE     .KERNEL_FATAL

        ; User program caused the exception.
        MOVE.L  #PROC_EXITED,PROC_STATE
        MOVE.L  #-1,PROC_EXIT_CODE

        ; Throw away the exception's supervisor stack
        ; and recover the kernel stack from before launch.
        MOVE.L  PROC_KERNEL_SSP,A7

        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER

        LEA     USER_EXCEPTION_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
      
       MOVE.L PANIC_VECTOR,D0
       BSR     KDR_PRINT_HEX_LONG
       LEA     KDR_NEWLINE,A1
       BSR    DUART_PUTS

        BRA     COMMAND_LOOP
.KERNEL_FATAL:
        STOP    #$2700

timer_irq:    
       addq.l #1,tick_counter
       rte



;---------------------------------------------------------
; kernal working  error handler
; Ctrl+C recovery path. DUART_IRQ redirects the user format-0 frame here.
; Foreground NEX processes return to the shell; Task B returns to saved Task A.
USER_ABORT_TRAMPOLINE:
        MOVEA.L SCHED_CURRENT_PCB,A0
        CMPA.L  #SECOND_PROCESS,A0
        BEQ.W   USER_ABORT_BACKGROUND

        MOVE.L  #PROC_EXITED,PROC_STATE
        MOVE.L  #USER_ABORT_EXIT_CODE,PROC_EXIT_CODE
        MOVEA.L PROC_KERNEL_SSP,A7
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        MOVE.W  #$2000,SR
        BRA.W   COMMAND_LOOP

USER_ABORT_BACKGROUND:
        MOVE.L  #PROC_EXITED,PCB_STATE(A0)
        MOVE.L  #USER_ABORT_EXIT_CODE,PCB_EXIT_CODE(A0)
        LEA     CURRENT_PROCESS,A0
        MOVE.L  A0,SCHED_CURRENT_PCB
        MOVE.L  #PROC_RUNNING,PCB_STATE(A0)
        MOVE.L  PCB_SAVED_USP(A0),A1
        MOVE.L  A1,USP
        MOVE.L  PCB_SAVED_SSP(A0),A7
        MOVEM.L (A7)+,D0-D7/A0-A6
        RTE

EXC_BUS_ERROR:
        MOVEQ   #2,D0
        BRA     KERNAL_PANIC

EXC_ADDRESS_ERROR:
        MOVEQ   #3,D0
        BRA     KERNAL_PANIC

EXC_ILLEGAL:
        MOVEQ   #4,D0
        BRA     KERNAL_PANIC

EXC_DIVIDE_ZERO:
        MOVEQ   #5,D0
        BRA     KERNAL_PANIC

EXC_CHK:
        MOVEQ   #6,D0
        BRA     KERNAL_PANIC

EXC_TRAPV:
        MOVEQ   #7,D0
        BRA     KERNAL_PANIC

EXC_PRIVILEGE:
        MOVEQ   #8,D0
        BRA     KERNAL_PANIC       
;-----------------------------------------------------------
; MC68681 channel-A receive interrupt
;
; Drain all available bytes into the 256-byte software queue.  RTS asks a
; physical peer to pause at the high-water mark.  If that peer ignores RTS,
; a full queue still discards bytes and RX_OVERFLOW records the loss.
;-----------------------------------------------------------
DUART_IRQ:
        MOVEM.L D0-D2/A0,-(A7)

        ; RX and C/T share the MC68681 IRQ output and IVR. A timer-mode
        ; stop command acknowledges ISR[3] but leaves the timer running.
        MOVE.B  DUART_ISR,D0
        BTST    #3,D0
        BEQ.W   DUART_IRQ_DRAIN
        ADDQ.L  #1,tick_counter
        MOVE.B  #1,DUART_TIMER_PENDING
        MOVE.B  DUART_STOP_TIMER,D0

DUART_IRQ_DRAIN:
        BTST    #0,DUART_SRA
        BEQ     DUART_IRQ_DONE

        MOVEQ   #0,D0
        MOVE.B  DUART_RBA,D0
        ADDQ.L  #1,RX_RECEIVED

        ; Ctrl+C is a kernel break request while a NEX task is running. Redirect
        ; the user exception frame to a supervisor trampoline so a tight loop
        ; or a blocking console writer can be stopped without app cooperation.
        CMPI.B  #DUART_CTRL_C,D0
        BNE.S   DUART_IRQ_QUEUE_BYTE
        MOVEA.L SCHED_CURRENT_PCB,A0
        CMPA.L  #CURRENT_PROCESS,A0
        BEQ.S   DUART_IRQ_BREAK_FOREGROUND
        CMPA.L  #SECOND_PROCESS,A0
        BNE.S   DUART_IRQ_QUEUE_BYTE
        CMPI.L  #PROC_RUNNING,PCB_STATE(A0)
        BNE.S   DUART_IRQ_QUEUE_BYTE
        BRA.S   DUART_IRQ_REDIRECT_BREAK

DUART_IRQ_BREAK_FOREGROUND:
        CMPI.L  #PROC_RUNNING,PROC_STATE
        BNE.S   DUART_IRQ_QUEUE_BYTE

DUART_IRQ_REDIRECT_BREAK:
        ; The ISR saved D0-D2/A0 (16 bytes), so the format-0 user frame begins
        ; at 16(A7): SR, PC, then format/vector. RTE enters the kernel trampoline.
        MOVE.W  #$2200,16(A7)       ; supervisor mode, mask level-2 IRQs briefly
        MOVE.L  #USER_ABORT_TRAMPOLINE,18(A7)
        BRA.W   DUART_IRQ_DONE

DUART_IRQ_QUEUE_BYTE:

        MOVE.W  RX_COUNT,D1
        CMPI.W  #RX_BUFFER_SIZE,D1
        BHS     DUART_IRQ_OVERFLOW

        MOVEQ   #0,D2
        MOVE.B  RX_WRITE_INDEX,D2
        LEA     RX_BUFFER,A0
        MOVE.B  D0,0(A0,D2.W)
        ADDQ.B  #1,D2
        ANDI.B  #RX_BUFFER_MASK,D2
        MOVE.B  D2,RX_WRITE_INDEX
        ADDQ.W  #1,RX_COUNT
        CMPI.W  #RX_RTS_PAUSE_THRESHOLD,RX_COUNT
        BNE.W   DUART_IRQ_DRAIN
        ; Deassert active-low RTS: software queue is nearly full.
        MOVE.B  #DUART_RTS_A_MASK,DUART_RESET_OPR
        BRA     DUART_IRQ_DRAIN

DUART_IRQ_OVERFLOW:
        ADDQ.L  #1,RX_OVERFLOW
        BRA     DUART_IRQ_DRAIN

DUART_IRQ_DONE:
        ; Timer preemption is safe only when the interrupted frame returns to
        ; user mode and a task PCB is currently RUNNING.  RX handling above
        ; completes first, including Ctrl+C's supervisor trampoline redirect.
        MOVE.W  16(A7),D0             ; saved SR below our four saved registers
        BTST    #13,D0                ; S=1 means we interrupted kernel code
        BNE.S   .DUART_IRQ_RETURN
        TST.B   DUART_TIMER_PENDING
        BEQ.S   .DUART_IRQ_RETURN
        MOVEA.L SCHED_CURRENT_PCB,A0
        CMPI.L  #PROC_RUNNING,PCB_STATE(A0)
        BNE.S   .DUART_IRQ_RETURN

        ; Put the original task registers above the hardware IRQ frame, save
        ; that full context in its PCB, then share the round-robin selector.
        MOVEM.L (A7)+,D0-D2/A0
        MOVEM.L D0-D7/A0-A6,-(A7)
        MOVEA.L SCHED_CURRENT_PCB,A0
        MOVE.L  A7,PCB_SAVED_SSP(A0)
        MOVE.L  USP,A1
        MOVE.L  A1,PCB_SAVED_USP(A0)
        ; Timer preemption bypasses SCHEDULER_ENTRY, so save the outgoing
        ; MC68881 state here before the common round-robin selector runs.
        FSAVE   PCB_FPU_FRAME(A0)
        FMOVEM.X FP0-FP7,PCB_FPU_REGS(A0)
        FMOVEM.L FPCR/FPSR/FPIAR,PCB_FPU_CONTROL(A0)
        MOVE.L  #PROC_READY,PCB_STATE(A0)
        CLR.B   DUART_TIMER_PENDING
        BRA.W   SCHEDULER_SELECT_NEXT

.DUART_IRQ_RETURN:
        CLR.B   DUART_TIMER_PENDING
        MOVEM.L (A7)+,D0-D2/A0
        RTE

SYSCALL:
        CMPI.L  #20,D0
        BHI     SYS_INVALID

        LSL.L   #2,D0

        LEA     SYSCALL_TABLE,A0
        MOVEA.L 0(A0,D0.L),A0
        JMP     (A0)        


*-----------------------------------------------------------
* Syscall table
*-----------------------------------------------------------

SYSCALL_TABLE:
        DC.L    SYS_INVALID     ; 0
        DC.L    SYS_ADD         ; 1
        DC.L    SYS_SUB         ; 2
        DC.L    SYS_VERSION     ; 3
        DC.L    SYS_EXIT        ; 4
        DC.L    SYS_PUTCHAR     ; 5
        DC.L    SYS_GETCHAR     ; 6
        DC.L    SYS_PUTS        ; 7
        DC.L    SYS_DISK_INFO   ; 8
        DC.L    SYS_READ_FILE   ; 9
        DC.L    SYS_READ_DIR    ; 10
        DC.L    SYS_CREATE_FILE ; 11
        DC.L    SYS_READ_LINE   ; 12
        DC.L    SYS_DELETE_FILE ; 13
        DC.L    SYS_GET_TICKS   ; 14
        DC.L    SYS_FORMAT_U32  ; 15
        DC.L    SYS_FADD_S      ; 16
        DC.L    SYS_FSUB_S      ; 17
        DC.L    SYS_SET_ATTRIBUTES ; 18
        DC.L    SYS_READ_LARGE  ; 19, experimental DOOMLOAD-only service
        DC.L    SYS_POLLCHAR    ; 20, nonblocking console receive
*-----------------------------------------------------------
* Syscall handlers
*-----------------------------------------------------------

SYS_ADD:
        MOVE.L  D1,D0
        ADD.L   D2,D0
        RTE


SYS_SUB:
        MOVE.L  D1,D0
        SUB.L   D2,D0
        RTE


SYS_VERSION:
        MOVE.L  #$312E3031,D0     ; ASCII "1.01"
        MOVE.L  D0,VERSION_BUFFER
        RTE


SYS_INVALID:
        MOVEQ   #-1,D0
        RTE


SYS_EXIT:
        MOVEA.L SCHED_CURRENT_PCB,A0
        CMPA.L  #SECOND_PROCESS,A0
        BEQ.W   SYS_EXIT_BACKGROUND
        MOVE.L  #PROC_EXITED,PROC_STATE
        MOVE.L  D1,PROC_EXIT_CODE
        LEA     SECOND_PROCESS,A0
        CMPI.L  #PROC_READY,PCB_STATE(A0)
        BEQ.W   SYS_EXIT_RESUME_BACKGROUND
SYS_EXIT_TO_SHELL:     
        ; Task B may have been the last user task to exit.  Re-anchor the
        ; process pointer to the foreground PCB before returning to the shell.
        LEA     CURRENT_PROCESS,A0
        MOVE.L  A0,SCHED_CURRENT_PCB
        MOVE.L  PROC_KERNEL_SSP,A7

        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER

        BRA     COMMAND_LOOP

SYS_EXIT_BACKGROUND:
        MOVE.L  #PROC_EXITED,PCB_STATE(A0)
        MOVE.L  D1,PCB_EXIT_CODE(A0)
        LEA     CURRENT_PROCESS,A0   
        CMPI.L  #PROC_EXITED,PCB_STATE(A0)
        BEQ.W   SYS_EXIT_TO_SHELL

        MOVE.L  A0,SCHED_CURRENT_PCB
        MOVE.L  #PROC_RUNNING,PCB_STATE(A0)
        MOVE.L  PCB_SAVED_USP(A0),A1
        MOVE.L  A1,USP


        MOVE.L  PCB_SAVED_SSP(A0),A7
        MOVEM.L (A7)+,D0-D7/A0-A6
        RTE
SYS_EXIT_RESUME_BACKGROUND:
         MOVE.L  A0,SCHED_CURRENT_PCB
         MOVE.L #PROC_RUNNING,PCB_STATE(A0)
         MOVE.L  PCB_SAVED_USP(A0),A1
         MOVE.L  A1,USP
         MOVE.L  PCB_SAVED_SSP(A0),A7
         MOVEM.L (A7)+,D0-D7/A0-A6
         RTE     
SYS_PUTCHAR:
        CMPI.L  #SECOND_PROCESS,SCHED_CURRENT_PCB
        BEQ.S   .BACKGROUND_OUTPUT
        ADDQ.L  #1,CONSOLE_FG_WRITE_COUNT
        BSR     DUART_PUTCHAR
        MOVEQ   #0,D0      ; NDOS return value: success
        MOVE.B  D1,LASTCHAR   
        RTE
.BACKGROUND_OUTPUT:
        ADDQ.L  #1,CONSOLE_BG_SUPPRESSED_COUNT
        MOVEQ   #0,D0      ; suppressed console output is still a successful call
        RTE

; Nonblocking console receive.  This deliberately bypasses the legacy line
; buffer used by SYS_GETCHAR so event-driven applications can poll safely.
; D0.L = 1 and D1.B = byte when a byte was available; D0.L = 0 otherwise.
SYS_POLLCHAR:
        BSR     DUART_GETCHAR
        RTE

SYS_GETCHAR:
.WAIT:
        BSR     DUART_GETCHAR    ; D1.B = character, Z if no data
        BEQ     .WAIT
      
        

        ; Enter finishes the current line
        CMPI.B  #CR,D1
        BEQ     .LINE_READY
        
       ; Backspace removes previous character
      CMPI.B  #DEL,D1
        BEQ     .BACKSPACE
        CMPI.B  #BS,D1
        BEQ     .BACKSPACE

        ; Save received character
        MOVE.W  D1,-(A7)

        LEA     CHAR_BUFFER,A0
        MOVE.W  BUF_INDEX,D1

        ; Leave one byte available for null terminator
        CMPI.W  #127,D1
        BHS     .BUFFER_FULL

        ; Recover character
        MOVE.W  (A7)+,D2
        MOVE.B  D2,0(A0,D1.W)

        ; Advance buffer index
        ADDQ.W  #1,D1
        MOVE.W  D1,BUF_INDEX

        ; Keep buffer null terminated
        CLR.B   0(A0,D1.W)
             ; NDOS-controlled echo
        MOVE.B  D2,D1
        BSR     DUART_PUTCHAR


        MOVEQ   #NDOS_OK,D0
        RTE


.LINE_READY:
        LEA     CHAR_BUFFER,A0
        MOVE.W  BUF_INDEX,D1
        CLR.B   0(A0,D1.W)

        MOVEQ   #NDOS_LINE_READY,D0
        RTE
.BACKSPACE:
        LEA     CHAR_BUFFER,A0
        MOVE.W  BUF_INDEX,D1

        ; Nothing to erase if buffer is empty
        TST.W   D1
        BEQ     .BACKSPACE_DONE

        ; Move index back one character
        SUBQ.W  #1,D1
        MOVE.W  D1,BUF_INDEX
        MOVE.W  d0,-(A7)
        MOVE.W  D1,-(A7)
       move.b #BS,d1
        BSR     DUART_PUTCHAR
    
        move.b #32,d1
        BSR     DUART_PUTCHAR
        move.b #BS,d1
        BSR     DUART_PUTCHAR
       
       
       
      
         MOVE.W  (A7)+,D1
         MOVE.W  (A7)+,d0

        ; New end of string
        CLR.B   0(A0,D1.W)

.BACKSPACE_DONE:
        MOVEQ   #NDOS_OK,D0
        RTE


.BUFFER_FULL:
        ADDQ.L  #2,A7           ; discard saved character
        MOVEQ   #NDOS_BUFFER_FULL,D0
        RTE
SYS_PUTS:
        CMPI.L  #SECOND_PROCESS,SCHED_CURRENT_PCB
        BEQ.S   .BACKGROUND_OUTPUT
        ADDQ.L  #1,CONSOLE_FG_WRITE_COUNT
.loop:
        MOVE.B  (A1)+,D1
        TST.B   D1
        BEQ     .done

        BSR     DUART_PUTCHAR
        BRA     .loop

.done:
        MOVEQ   #0,D0
        RTE
.BACKGROUND_OUTPUT:
        ADDQ.L  #1,CONSOLE_BG_SUPPRESSED_COUNT
        MOVEQ   #0,D0      ; discard background text rather than mix consoles
        RTE

SYS_DISK_INFO:
        MOVEM.L D1-D7/A0-A6,-(A7)

        ; A1 must point to a complete writable 20-byte user structure.
        MOVE.L  A1,D1
        CMPI.L  #PROGRAM_BASE,D1
        BLO     .BAD_POINTER

        ADDI.L  #20,D1
        BCS     .BAD_POINTER

        CMPI.L  #PROGRAM_LIMIT+1,D1
        BHI     .BAD_POINTER

        ; Preserve the user destination while GCC uses volatile registers.
        MOVE.L  A1,-(A7)

        PEA     KERNEL_FREE_BYTES
        PEA     KERNEL_FREE_CLUSTERS
        JSR     NDOS_GET_DISK_FREE
        ADDQ.L  #8,A7

        MOVEA.L (A7)+,A1

        TST.L   D0
        BNE     .DONE

        MOVE.L  #$0007E200,0(A1)
        MOVE.L  KERNEL_FREE_BYTES,4(A1)
        MOVE.L  #$000003F1,8(A1)
        MOVE.L  KERNEL_FREE_CLUSTERS,12(A1)
        MOVE.L  #$00000200,16(A1)

        MOVEQ   #0,D0
        BRA     .DONE

.BAD_POINTER:
        MOVEQ   #-2,D0

.DONE:
        MOVEM.L (A7)+,D1-D7/A0-A6
        RTE
SYS_READ_FILE:
        MOVEM.L D1-D7/A0-A6,-(A7)

        ; Preserve original syscall arguments in saved kernel scratch values.
        MOVE.L  A1,READ_NAME
        MOVE.L  A2,READ_DESTINATION
        MOVE.L  D1,READ_CAPACITY
        MOVE.L  A3,READ_COUNT_POINTER

        ; Validate filename.
        BSR     VALIDATE_USER_FILENAME
        TST.L   D0
        BNE     .DONE

        ; Reject zero or negative-as-unsigned capacities.
        MOVE.L  READ_CAPACITY,D1
        TST.L   D1
        BEQ     .BAD_ARGUMENT

        ; Validate [destination, destination+capacity).
        MOVE.L  READ_DESTINATION,D0
        CMPI.L  #PROGRAM_BASE,D0
        BLO     .BAD_POINTER
        ADD.L   D1,D0
        BCS     .BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI     .BAD_POINTER

        ; Validate the four-byte bytes-read destination.
        MOVE.L  READ_COUNT_POINTER,D0
        CMPI.L  #PROGRAM_BASE,D0
        BLO     .BAD_POINTER
        ADDQ.L  #4,D0
        BCS     .BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI     .BAD_POINTER

        ; C arguments are pushed right-to-left.
        MOVE.L  READ_COUNT_POINTER,-(A7)
        MOVE.L  READ_CAPACITY,-(A7)
        MOVE.L  READ_DESTINATION,-(A7)
        MOVE.L  READ_NAME,-(A7)
        JSR     NDOS_READ_FILE
        LEA     16(A7),A7
        BRA     .DONE

.BAD_ARGUMENT:
        MOVEQ   #-1,D0
        BRA     .DONE

.BAD_POINTER:
        MOVEQ   #-2,D0

.DONE:
        MOVEM.L (A7)+,D1-D7/A0-A6
        RTE

;-----------------------------------------------------------
; SYS_READ_LARGE -- experimental MAME-only large-loader service
;
; A1 = zero-terminated 8.3 filename in normal NEX RAM
; A2 = destination in LARGE_PROGRAM_BASE..LARGE_PROGRAM_LIMIT
; D1 = destination capacity, 1..65536
; A3 = writable longword byte-count result in normal NEX RAM
;
; Kept separate from syscall 9 so normal applications remain confined to
; their 64 KiB NEX region.  DOOMLOAD will call this once per disk chunk.
;-----------------------------------------------------------
SYS_READ_LARGE:
        MOVEM.L D1-D7/A0-A6,-(A7)
        MOVE.L  A1,READ_NAME
        MOVE.L  A2,READ_DESTINATION
        MOVE.L  D1,READ_CAPACITY
        MOVE.L  A3,READ_COUNT_POINTER

        BSR     VALIDATE_USER_FILENAME
        TST.L   D0
        BNE.S   .DONE
        MOVE.L  READ_CAPACITY,D1
        BEQ.S   .BAD_ARGUMENT
        CMPI.L  #$00010000,D1
        BHI.S   .BAD_ARGUMENT

        MOVE.L  READ_DESTINATION,D0
        CMPI.L  #LARGE_PROGRAM_BASE,D0
        BLO.S   .BAD_POINTER
        ADD.L   D1,D0
        BCS.S   .BAD_POINTER
        CMPI.L  #LARGE_PROGRAM_LIMIT+1,D0
        BHI.S   .BAD_POINTER

        MOVE.L  READ_COUNT_POINTER,D0
        CMPI.L  #PROGRAM_BASE,D0
        BLO.S   .BAD_POINTER
        ADDQ.L  #4,D0
        BCS.S   .BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI.S   .BAD_POINTER

        MOVE.L  READ_COUNT_POINTER,-(A7)
        MOVE.L  READ_CAPACITY,-(A7)
        MOVE.L  READ_DESTINATION,-(A7)
        MOVE.L  READ_NAME,-(A7)
        JSR     NDOS_READ_FILE
        LEA     16(A7),A7
        BRA.S   .DONE
.BAD_ARGUMENT:
        MOVEQ   #-1,D0
        BRA.S   .DONE
.BAD_POINTER:
        MOVEQ   #-2,D0
.DONE:
        MOVEM.L (A7)+,D1-D7/A0-A6
        RTE

;-----------------------------------------------------------
; SYS_READ_DIR
;
; Entry:
;   D1.L = visible root-directory index
;   A1   = writable 24-byte ndos_directory_entry
; Return:
;   D0.L = 0 entry returned, 1 end of directory, negative error
;   D1.L = next visible index after a returned entry
;-----------------------------------------------------------
SYS_READ_DIR:
        MOVEM.L D2-D7/A0-A6,-(A7)

        MOVE.L  D1,DIR_VISIBLE_INDEX
        MOVE.L  A1,DIR_DESTINATION

        ; Validate the complete writable destination structure.
        MOVE.L  A1,D0
        CMPI.L  #PROGRAM_BASE,D0
        BLO     .BAD_POINTER
        ADDI.L  #24,D0
        BCS     .BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI     .BAD_POINTER

        ; C arguments are pushed right-to-left.
        MOVE.L  DIR_DESTINATION,-(A7)
        MOVE.L  DIR_VISIBLE_INDEX,-(A7)
        JSR     NDOS_GET_DIRECTORY_ENTRY
        ADDQ.L  #8,A7

        TST.L   D0
        BNE     .DONE
        MOVE.L  DIR_VISIBLE_INDEX,D1
        ADDQ.L  #1,D1
        BRA     .DONE

.BAD_POINTER:
        MOVEQ   #-2,D0
.DONE:
        MOVEM.L (A7)+,D2-D7/A0-A6
        RTE

; A1=name, A2=source, D1.L=size. Existing names are rejected.
SYS_CREATE_FILE:
        MOVEM.L D1-D7/A0-A6,-(A7)
        MOVE.L  A1,CREATE_NAME
        MOVE.L  A2,CREATE_SOURCE
        MOVE.L  D1,CREATE_SIZE
        BSR     VALIDATE_USER_FILENAME
        TST.L   D0
        BNE     .DONE
        MOVE.L  CREATE_SIZE,D1
        BEQ     .CALL_C
        MOVE.L  CREATE_SOURCE,D0
        CMPI.L  #PROGRAM_BASE,D0
        BLO     .BAD_POINTER
        ADD.L   D1,D0
        BCS     .BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI     .BAD_POINTER
.CALL_C:
        MOVE.L  CREATE_SIZE,-(A7)
        MOVE.L  CREATE_SOURCE,-(A7)
        MOVE.L  CREATE_NAME,-(A7)
        JSR     NDOS_CREATE_FILE
        LEA     12(A7),A7
        BRA     .DONE
.BAD_POINTER:
        MOVEQ   #-2,D0
.DONE:
        MOVEM.L (A7)+,D1-D7/A0-A6
        RTE

; A1 -> word capacity, word length, data[capacity+1].
SYS_READ_LINE:
        MOVEM.L D2-D7/A0-A6,-(A7)
        MOVEA.L A1,A2
        MOVE.L  A2,D0
        CMPI.L  #PROGRAM_BASE,D0
        BLO     .LINE_BAD_POINTER
        ADDQ.L  #4,D0
        BCS     .LINE_BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI     .LINE_BAD_POINTER
        MOVEQ   #0,D2
        MOVE.W  (A2),D2
        BEQ     .LINE_BAD_ARGUMENT
        MOVE.L  A2,D0
        ADDQ.L  #5,D0
        ADD.L   D2,D0
        BCS     .LINE_BAD_POINTER
        CMPI.L  #PROGRAM_LIMIT+1,D0
        BHI     .LINE_BAD_POINTER
        MOVEQ   #0,D3
        CLR.W   2(A2)
        CLR.B   4(A2)
.LINE_WAIT:
        BSR     DUART_GETCHAR
        BEQ     .LINE_WAIT
        CMPI.B  #CR,D1
        BEQ     .LINE_COMPLETE
        CMPI.B  #BS,D1
        BEQ     .LINE_BACKSPACE
        CMPI.B  #DEL,D1
        BEQ     .LINE_BACKSPACE
        CMPI.B  #$20,D1
        BLO     .LINE_WAIT
        CMPI.B  #$7E,D1
        BHI     .LINE_WAIT
        CMP.L   D2,D3
        BHS     .LINE_FULL
        MOVE.B  D1,4(A2,D3.L)
        ADDQ.L  #1,D3
        CLR.B   4(A2,D3.L)
        BSR     DUART_PUTCHAR
        BRA     .LINE_WAIT
.LINE_FULL:
        MOVEQ   #7,D1
        BSR     DUART_PUTCHAR
        BRA     .LINE_WAIT
.LINE_BACKSPACE:
        TST.L   D3
        BEQ     .LINE_WAIT
        SUBQ.L  #1,D3
        CLR.B   4(A2,D3.L)
        MOVEQ   #BS,D1
        BSR     DUART_PUTCHAR
        MOVEQ   #' ',D1
        BSR     DUART_PUTCHAR
        MOVEQ   #BS,D1
        BSR     DUART_PUTCHAR
        BRA     .LINE_WAIT
.LINE_COMPLETE:
        MOVE.W  D3,2(A2)
        CLR.B   4(A2,D3.L)
        MOVEQ   #CR,D1
        BSR     DUART_PUTCHAR
        MOVEQ   #LF,D1
        BSR     DUART_PUTCHAR
        MOVE.L  D3,D1
        MOVEQ   #0,D0
        BRA     .LINE_DONE
.LINE_BAD_ARGUMENT:
        MOVEQ   #-1,D0
        BRA     .LINE_DONE
.LINE_BAD_POINTER:
        MOVEQ   #-2,D0
.LINE_DONE:
        MOVEM.L (A7)+,D2-D7/A0-A6
        RTE

; A1=name. Deletes the file and releases its FAT12 cluster chain.
SYS_DELETE_FILE:
        MOVEM.L D1-D7/A0-A6,-(A7)
        MOVE.L  A1,DELETE_NAME
        BSR     VALIDATE_USER_FILENAME
        TST.L   D0
        BNE     .DELETE_DONE
        MOVE.L  DELETE_NAME,-(A7)
        JSR     NDOS_DELETE_FILE
        ADDQ.L  #4,A7
        BRA     .DELETE_DONE
.DELETE_BAD_POINTER:
        MOVEQ   #-2,D0
.DELETE_DONE:
        MOVEM.L (A7)+,D1-D7/A0-A6
        RTE

; D0 = monotonic 100 Hz development tick count from the MC68681 timer.
; This is intentionally separate from the future CPLD1 timer ABI.
SYS_GET_TICKS:
        MOVE.L  tick_counter,D0
        RTE

; D1.L = unsigned value; A1 = writable output buffer of at least 11 bytes.
; D0.L returns decimal character count.  The output is NUL terminated.
SYS_FORMAT_U32:
        MOVEM.L D2-D7/A2-A6,-(A7)
        MOVEA.L A1,A2
        ; Reserve the BCD scratch area before calling helpers.  Using LEA
        ; below A7 without moving A7 let BSR overwrite the temporary buffer
        ; with its return address, corrupting the RTE path.
        SUBA.L  #8,A7
        MOVEA.L A7,A0                   ; five BCD bytes plus alignment slack
        MOVE.L  D1,D0
        BSR     U32_TO_PACKED_BCD
        BSR     PACKED_BCD_TO_ASCII
        ADDA.L  #8,A7
        MOVEM.L (A7)+,D2-D7/A2-A6
        RTE


; MAME-development IEEE-754 binary32 operations.
; D1.L and D2.L are raw binary32 bit patterns; D0.L returns one.
SYS_FADD_S:
        FMOVE.S D1,FP0
        FADD.S  D2,FP0
        FMOVE.S FP0,D0
        RTE

SYS_FSUB_S:
        FMOVE.S D1,FP0
        FSUB.S  D2,FP0
        FMOVE.S FP0,D0
        RTE

SYS_SET_ATTRIBUTES:
  
  MOVEM.L D2-D7/A2-A6,-(A7)

   MOVE.L  A1,ATTRIB_NAME
    MOVE.L  D1,ATTRIB_VALUE

   BSR     VALIDATE_USER_FILENAME
   TST.L   D0
   BNE.S   .DONE

    MOVE.L  ATTRIB_VALUE,D2
   ANDI.L  #$FFFFFFD8,D2
   BNE.S   .BAD_ARGUMENT

    MOVE.L  ATTRIB_VALUE,-(A7)
     MOVE.L  ATTRIB_NAME,-(A7)

     JSR     NDOS_SET_FILE_ATTRIBUTES ;MAKES THE C CALL
     ADDQ.L  #8,A7
     BRA .DONE

 .BAD_ARGUMENT:
    MOVEQ   #-1,D0
    
.DONE:
       
      MOVEM.L (A7)+,D2-D7/A2-A6
      RTE


        

       INCLUDE 'kernel/decimal.inc'

;-----------------------------------------------------------
; J68K virtual MC68681 console helpers
;-----------------------------------------------------------
DUART_PUTCHAR:
.txwait:
        BTST    #2,DUART_SRA
        BEQ     .txwait
        MOVE.B  D1,DUART_TBA
        RTS

DUART_GETCHAR:
        ; Protect the consumer indexes from the level-2 producer ISR.
        MOVE.W  SR,-(A7)
        ORI.W   #$0700,SR

        TST.W   RX_COUNT
        BEQ     .queue_empty

        MOVEQ   #0,D0
        MOVE.B  RX_READ_INDEX,D0
        LEA     RX_BUFFER,A0
        MOVE.B  0(A0,D0.W),D1
        ADDQ.B  #1,D0
        ANDI.B  #RX_BUFFER_MASK,D0
        MOVE.B  D0,RX_READ_INDEX
        SUBQ.W  #1,RX_COUNT

        CMPI.W  #RX_RTS_RESUME_THRESHOLD,RX_COUNT
        BNE.S   .rts_state_done
        ; Assert active-low RTS again after draining enough headroom.
        MOVE.B  #DUART_RTS_A_MASK,DUART_SET_OPR
.rts_state_done:

        MOVE.W  (A7)+,SR
        MOVEQ   #1,D0
        RTS

.queue_empty:
        MOVE.W  (A7)+,SR
        MOVEQ   #0,D0
        RTS

DUART_PUTS:
.duart_loop:
        MOVE.B  (A1)+,D1
        BEQ     .duart_done
        BSR     DUART_PUTCHAR
        BRA     .duart_loop
.duart_done:
        RTS

*-----------------------------------------------------------
* Kernel/test data
*-----------------------------------------------------------
CHAR_BUFFER:
       DS.B 128

        EVEN
RX_BUFFER:
       DS.B RX_BUFFER_SIZE
RX_READ_INDEX:
       DC.B 0
RX_WRITE_INDEX:
       DC.B 0
RX_COUNT:
       DC.W 0
RX_OVERFLOW:
       DC.L 0
RX_RECEIVED:
       DC.L 0
         
BUF_INDEX:
      DC.W 0
 
KERNEL_SSP:
        DC.L    0
        
LASTCHAR:
       DC.B 0
       
VERSION_BUFFER:
        DC.L    0
        DC.B    0

PANIC_VECTOR:
        DC.L    0

PANIC_PC:
        DC.L    0

PANIC_SR:
        DC.W    0

PANIC_FRAME_WORD:
        DC.W    0

tick_counter:
       DC.L 0

DUART_TIMER_PENDING:
       DC.B 0
       EVEN

TASK_B_COUNTER:
         DC.L    0
; Internal console-policy counters used by the RUN2 regression.
CONSOLE_FG_WRITE_COUNT:
         DC.L    0
CONSOLE_BG_SUPPRESSED_COUNT:
         DC.L    0
; Task B context-builder inputs.  Defaults preserve the current kernel task;
; RUN2 will replace these values before initializing a second NEX instance.
TASK_B_INIT_BASE:
         DC.L    0
TASK_B_INIT_SIZE:
         DC.L    0
TASK_B_INIT_ENTRY:
         DC.L    TASK_B_ENTRY
TASK_B_INIT_STACK_TOP:
         DC.L    TASK_B_USER_STACK_TOP
TASK_B_INIT_USER_STACK:
         DC.L    TASK_B_USER_STACK_TOP
TASK_B_INIT_SUPERVISOR_TOP:
         DC.L    TASK_B_SUPERVISOR_STACK_TOP
NEX_ERROR_TEXT:
        DC.B    CR,LF
        DC.B    'INVALID NEX EXECUTABLE',CR,LF,0
RUN_USAGE_TEXT:
        DC.B    CR,LF,'USAGE: RUN FILE.NEX [ARG]',CR,LF,0
NEX_NOT_FOUND_TEXT:
        DC.B    CR,LF,'RUN: FILE NOT FOUND',CR,LF,0
NEX_READ_ERROR_TEXT:
        DC.B    CR,LF,'RUN: FILE READ FAILED: $',0
NEX_ARGUMENT_ERROR_TEXT:
        DC.B    CR,LF,'RUN: ARGUMENT EXCEEDS PROGRAM STACK',CR,LF,0

        EVEN
NEX_FILE_BYTES:
        DC.L    0
NEX_ARG_SOURCE:
        DC.L    0
NEX_NAME_PTR:
        DC.L    0
NEX_RUN2_MODE:
        DC.B    0
        EVEN
NEX_START_ARGC:
        DC.L    0
NEX_START_ARG_PTR:
        DC.L    0
NEX_FILE_BUFFER      EQU     $00180200
NEX_FILE_BUFFER_SIZE EQU     $00010000
     

msg:
        ; Minimal boot banner.  Keep this as ordinary console text so the
        ; existing TRAP #0 puts path and RAM-disk layout remain unchanged.
        DC.B    CR,LF
        DC.B    '================================',CR,LF
        DC.B    '              NDOS',CR,LF
        DC.B    '          ALPHA 0.01',CR,LF
        DC.B    '        J68K REV-A SYSTEM',CR,LF
        DC.B    '================================',CR,LF
        DC.B    'Memory: 2 MiB SRAM',CR,LF
        DC.B    'Console: MC68681 DUART',CR,LF
        DC.B    'Booting command shell...',CR,LF,CR,LF,0

DUART_CLEAR_SEQ:
        DC.B    FF,0             ; MAME generic terminal: clear screen and home
    
    
CMD_RUN:
        DC.B    'RUN',0
CMD_RUN_PREFIX:
        DC.B    'RUN ',0
CMD_RUN2_PREFIX:
        DC.B    'RUN2 ',0
CMD_KDR:
        DC.B    'KDR',0
CMD_DISKTEST:
        DC.B    'DISKTEST',0
PROMPT_SKIP:
        DC.B    0
    
    
err:
     DC.B    'error code',0
      

CMD_HELP:
        DC.B    'HELP',0
CMD_CTEST:
        DC.B    'CTEST',0


UNKNOWN_TEXT:
        DC.B    CR,LF
        DC.B    'UNKNOWN COMMAND',CR,LF
        DC.B    0
        
CMD_FORMAT:
        DC.B    'FORMAT',0
CMD_FORMAT_SD:
        DC.B    'FORMAT SD',0
CMD_MOUNT:
        DC.B    'MOUNT',0

CMD_YES:
        DC.B    'YES',0

CMD_FATINFO:
        DC.B    'FATINFO',0

CMD_FREE:
        DC.B    'FREE',0

CMD_DIR:
        DC.B    'DIR',0

CMD_FTEST:
        DC.B    'FTEST',0

CMD_WTEST:
        DC.B    'WTEST',0

CMD_TYPE:
        DC.B    'TYPE',0
CMD_TYPE_PREFIX:
        DC.B    'TYPE ',0

CMD_VERSION:
        DC.B    'VERSION',0

CMD_CLEAR:
        DC.B    'CLR',0
       
CMD_MAP:
        DC.B    'MEM MAP',0
CMD_TM:
        DC.B    'TM',0



PANIC_CODE_ARGUMENT: 
        DC.B    CR,LF
        DC.B    'NDOS KERNAL PANIC',CR,LF
        DC.B    'VECTOR: $',0


;| Error code | Vector  Meaning 
;|---|---:|---|
;| `E102` | 2 | Bus error 
;| `E103` | 3 | Address error 
;| `E104` | 4 | Illegal instruction 
;| `E105` | 5 | Divide by zero 
;| `E106` | 6 | CHK / CHK2 trap 
;| `E107` | 7 | TRAPV 
;| `E108` | 8 | Privilege violation 

VERSION_TEXT:
        DC.B    CR,LF
        DC.B    'NDOS PRE-ALPHA VERSION 1.01',CR,LF
        DC.B    0
TEXT_BS:
     DC.B BS, 0
 
MAP_TEXT:
        DC.B    CR,LF
        DC.B    'NDOS MEMORY MAP:',CR,LF
        DC.B    'SRAM:       0x00000000-0x001FFFFF',CR,LF
        DC.B    'NEX REGION: 0x00010000-0x0001FFFF',CR,LF
        DC.B    'USER SP:    0x00020000 (GROWS DOWN)',CR,LF
        DC.B    'RAM DISK:   0x00100000-0x0017FFFF',CR,LF
        DC.B    'SECTOR BUF: 0x00180000-0x001801FF',CR,LF
        DC.B    'DUART:      0x00F00000-0x00F000FF',CR,LF
        DC.B    'CORE CTRL:  0xF0000000-0xF0000FFF',CR,LF
        DC.B    'BOOT ROM:   0xFFF00000-0xFFFFFFFF',CR,LF
        DC.B    0
 PROMPT_TEXT:
        DC.B    'NDOS> ',0 
  

HELP_TEXT:
        DC.B    CR,LF
        DC.B    'NDOS COMMANDS:',CR,LF
        DC.B    'HELP    - SHOW COMMANDS',CR,LF
        DC.B    'VERSION - SHOW NDOS VERSION',CR,LF
        DC.B    'CLR   - CLEAR SCREEN',CR,LF
        DC.B    'CTEST   - SHOW C/FAT12 TEST REPORT',CR,LF
        DC.B    'MEM MAP - SHOW MEMORY MAP',CR,LF
        DC.B    'TM      - TASK / TIMER / SWITCH STATUS',CR,LF
        DC.B    'KDR     - RAM MONITOR (NO RUN)',CR,LF
        DC.B    'DISKTEST- TEST ALL RAM-DISK SECTORS',CR,LF
        DC.B    'RUN FILE.NEX - LOAD AND RUN FAT12 PROGRAM',CR,LF
        DC.B    'RUN2 FILE.NEX - RUN TWO COPIES COOPERATIVELY',CR,LF
        DC.B    'FORMAT  - CONFIRM, THEN ERASE AND FORMAT RAM DISK',CR,LF
        DC.B    'FORMAT SD - CONFIRM, THEN FORMAT SD CARD',CR,LF
        DC.B    'MOUNT   - CHECK ACTIVE SD OR RAM VOLUME',CR,LF
        DC.B    'FATINFO - VERIFY FAT12 VOLUME',CR,LF
        DC.B    'FREE    - SHOW EXACT RAM AND DISK SPACE',CR,LF
        DC.B    'DIR     - LIST FAT12 ROOT DIRECTORY',CR,LF
        DC.B    'FTEST   - TEST FAT12 FILE/CLUSTER READER',CR,LF
        DC.B    'WTEST   - TEST FAT12 FILE CREATION',CR,LF
        DC.B    'TYPE FILE.EXT - DISPLAY A FAT12 TEXT FILE',CR,LF
        DC.B    0

TM_HEADER_TEXT:
        DC.B    CR,LF,'NDOS TASK MANAGER (COOPERATIVE)',CR,LF
        DC.B    '100HZ TICKS: $',0
TM_YIELD_TEXT:
        DC.B    CR,LF,'TRAP1 YIELDS: $',0
TM_SWITCH_TEXT:
        DC.B    CR,LF,'PROCESS SWITCHES: $',0
TM_TABLE_HEADER:
        DC.B    CR,LF,'PID      STATE    BASE     ENTRY    * = CURRENT',CR,LF,0
TM_RUNNING_TEXT:
        DC.B    'RUNNING',0
TM_READY_TEXT:
        DC.B    'READY',0
TM_WAITING_TEXT:
        DC.B    'WAITING',0
TM_EXITED_TEXT:
        DC.B    'EXITED',0
TM_OTHER_TEXT:
        DC.B    'UNKNOWN',0

FREE_HEADER_TEXT:
        DC.B    CR,LF,'J68K MEMORY / DISK SPACE',CR,LF
        DC.B    'PHYSICAL SRAM:   $',0
FREE_RESERVED_TEXT:
        DC.B    ' BYTES',CR,LF,'STATIC RESERVED: $',0
FREE_RAM_TEXT:
        DC.B    ' BYTES',CR,LF,'UNRESERVED RAM:  $',0
FREE_DISK_TEXT:
        DC.B    ' BYTES',CR,LF,'FAT12 FREE:      $',0
FREE_CLUSTERS_TEXT:
        DC.B    ' BYTES',CR,LF,'FREE CLUSTERS:   $',0
FREE_NOTE_TEXT:
        DC.B    CR,LF,'RAM NOTE: NO HEAP/PAGE ALLOCATOR YET',CR,LF,0
FREE_FAILED_TEXT:
        DC.B    CR,LF,'FREE SPACE QUERY FAILED: $',0

        EVEN
FREE_DISK_CLUSTERS:
        DC.L    0
FREE_DISK_BYTES:
        DC.L    0

CTEST_START_TEXT:
        DC.B    CR,LF,'J68K C/FAT12 SELF-TEST',CR,LF,0

CTEST_PASS_TEXT:
        DC.B    'C ABI BRIDGE:         PASS',CR,LF
        DC.B    'LITTLE-ENDIAN I/O:    PASS',CR,LF
        DC.B    'FAT12 PACKED ENTRIES: PASS',CR,LF
        DC.B    'RAM-DISK CALLBACKS:   PASS',CR,LF
        DC.B    'FAT12 BPB MOUNT:      PASS',CR,LF
        DC.B    'ALL C TESTS PASSED',CR,LF,0

CTEST_FAIL_TEXT:
        DC.B    'C/FAT12 TEST FAILED: $',0

CTEST_FAIL_HELP_TEXT:
        DC.B    CR,LF
        DC.B    '01-0A ENDIAN; 0B-10 PACKED FAT',CR,LF
        DC.B    '14-19 RAM DISK; 1A-1E FAT MOUNT',CR,LF,0

DISKTEST_START_TEXT:
        DC.B    CR,LF,'RAM DISK TEST (DESTROYS CONTENTS)...',CR,LF,0
DISKTEST_PASS_TEXT:
        DC.B    'RAM DISK: 1024/1024 SECTORS PASSED',CR,LF,0
DISKTEST_FAIL_TEXT:
        DC.B    'RAM DISK FAILED AT SECTOR $',0

         EVEN

KERNEL_FREE_CLUSTERS:
        DC.L    0

KERNEL_FREE_BYTES:
        DC.L    0

READ_NAME:
        DC.L    0
READ_DESTINATION:
        DC.L    0
READ_CAPACITY:
        DC.L    0
READ_COUNT_POINTER:
        DC.L    0
DIR_VISIBLE_INDEX:
        DC.L    0
DIR_DESTINATION:
        DC.L    0
CREATE_NAME:
        DC.L    0
CREATE_SOURCE:
        DC.L    0
CREATE_SIZE:
        DC.L    0
DELETE_NAME:
        DC.L    0
ATTRIB_NAME:
        DC.L    0

ATTRIB_VALUE:
        DC.L    0

KDR_BANNER:
        DC.B    CR,LF,'KDR RAM MONITOR',CR,LF
        DC.B    'READ:  ADDRESS  OR  ADDRESS.END',CR,LF
        DC.B    'WRITE: ADDRESS: BYTE BYTE ...',CR,LF
        DC.B    'WRITES: 00100000-0010FFFF ONLY',CR,LF
        DC.B    'Q=QUIT  (NO R COMMAND)',CR,LF,0
KDR_PROMPT:
        DC.B    'KDR> ',0
KDR_NEWLINE:
        DC.B    CR,LF,0
KDR_SYNTAX_ERROR_TEXT:
        DC.B    'KDR SYNTAX ERROR',CR,LF,0
KDR_RANGE_ERROR_TEXT:
        DC.B    'KDR ADDRESS OUT OF SRAM RANGE',CR,LF,0
KDR_WRITE_ERROR_TEXT:
        DC.B    'KDR WRITE LIMITED TO 00100000-0010FFFF',CR,LF,0
KDR_BUFFER_ERROR_TEXT:
        DC.B    'KDR INPUT BUFFER FULL',CR,LF,0
        
RESULT1:
        DC.L    0

RESULT2:
        DC.L    0

RESULT3:
        DC.L    0

RESULT4:
        DC.L    0
        
        
YIELD_COUNT:
        DC.L    0
SCHED_SWITCH_COUNT:
        DC.L    0
TM_COMMAND_COUNT:
        DC.L    0
        
USER_EXCEPTION_TEXT:
        DC.B    CR,LF
        DC.B    'PROGRAM TERMINATED: ERROR VECTOR $' ,0
      
        
*RETURN_CODES

NDOS_OK             EQU     0
NDOS_BUFFER_FULL    EQU     1
NDOS_LINE_READY     EQU     2
       
*-----------------------------------------------------------
* ASCII control characters
*-----------------------------------------------------------

BEL     EQU     $07     ; Bell
BS      EQU     $08     ; Backspace
HT      EQU     $09     ; Horizontal tab
LF      EQU     $0A     ; Line feed
VT      EQU     $0B     ; Vertical tab
FF      EQU     $0C     ; Form feed
CR      EQU     $0D     ; Carriage return
ESC     EQU     $1B     ; Escape
DEL     EQU     $7F     ; Delete

; ============================================
; NDOS disk
; ============================================
FORMAT_WARNING_TEXT:
        DC.B    CR,LF
        DC.B    'FORMAT DESTROYS ALL RAM-DISK FILES.',CR,LF
        DC.B    'TYPE YES AND PRESS ENTER TO CONTINUE.',CR,LF
        DC.B    'ANY OTHER INPUT CANCELS.',CR,LF
        DC.B    'FORMAT> ',0

FORMAT_SD_WARNING_TEXT:
        DC.B    CR,LF
        DC.B    'FORMAT SD ERASES ALL FILES ON THE SD CARD.',CR,LF
        DC.B    'TYPE YES AND PRESS ENTER TO CONTINUE.',CR,LF
        DC.B    'ANY OTHER INPUT CANCELS.',CR,LF
        DC.B    'FORMAT SD> ',0

FORMAT_START_TEXT:
        DC.B    CR,LF,'FORMATTING VOLUME...',CR,LF,0

FORMAT_COMPLETE_TEXT:
        DC.B    'FORMAT COMPLETE',CR,LF
        DC.B    'VOLUME: J68KRAMDISK',CR,LF
        DC.B    'FAT12: 121 DATA CLUSTERS',CR,LF,0

FORMAT_SD_COMPLETE_TEXT:
        DC.B    'FORMAT COMPLETE',CR,LF
        DC.B    'VOLUME: J68KSDCARD',CR,LF
        DC.B    'FAT12 READY',CR,LF,0

FORMAT_FAILED_TEXT:
        DC.B    'FORMAT FAILED',CR,LF,0

FORMAT_CANCELLED_TEXT:
        DC.B    CR,LF,'FORMAT CANCELLED',CR,LF,0

FORMAT_TARGET:
        DC.B    0
        EVEN

MOUNT_RAM_READY_TEXT:
        DC.B    CR,LF,'MOUNT OK: RAM-DISK FAT12 READY',CR,LF,0

MOUNT_SD_READY_TEXT:
        DC.B    CR,LF,'MOUNT OK: SD CARD FAT12 READY',CR,LF,0

MOUNT_FAILED_TEXT:
        DC.B    CR,LF,'MOUNT FAILED: NO VALID FAT12 VOLUME',CR,LF,0

FATINFO_OK_TEXT:
        DC.B    CR,LF,'ACTIVE FAT12 VOLUME VALID',CR,LF
        DC.B    'USES SD CARD WHEN PRESENT.',CR,LF
        DC.B    'OTHERWISE USES RAM DISK.',CR,LF,0

FATINFO_FAILED_TEXT:
        DC.B    CR,LF,'NO VALID FAT12 FILESYSTEM',CR,LF,0

DIR_HEADER_TEXT:
        DC.B    CR,LF,'NAME          SIZE (HEX)',CR,LF,0

DIR_SIZE_SEPARATOR:
        DC.B    '    $',0

DIR_EMPTY_TEXT:
        DC.B    '(EMPTY)',CR,LF,0

DIR_FAILED_TEXT:
        DC.B    'DIR: NO VALID FAT12 VOLUME',CR,LF,0

FTEST_OK_TEXT:
        DC.B    CR,LF,'FAT12 FILE LOOKUP: PASS',CR,LF
        DC.B    'CLUSTER CHAIN 2 -> 5: PASS',CR,LF
        DC.B    '700 FILE BYTES VERIFIED',CR,LF,0

FTEST_FAILED_TEXT:
        DC.B    CR,LF,'FAT12 FILE TEST FAILED: $',0

WTEST_OK_TEXT:
        DC.B    CR,LF,'FAT12 FILE CREATE: PASS',CR,LF
        DC.B    'CREATE.BIN: 700 BYTES VERIFIED',CR,LF,0
WTEST_FAILED_TEXT:
        DC.B    CR,LF,'FAT12 FILE CREATE FAILED: $',0

TYPE_USAGE_TEXT:
        DC.B    CR,LF,'USAGE: TYPE FILE.TXT',CR,LF,0
TYPE_TEXT_ONLY_TEXT:
        DC.B    CR,LF,'TYPE SUPPORTS .TXT FILES ONLY',CR,LF,0
TYPE_NOT_FOUND_TEXT:
        DC.B    CR,LF,'TYPE: FILE NOT FOUND',CR,LF,0
TYPE_FAILED_TEXT:
        DC.B    CR,LF,'TYPE: FILE READ FAILED: $',0

        EVEN
TYPE_BYTES_READ:
        DC.L    0


TYPE_BUFFER      EQU     $00180200
TYPE_BUFFER_SIZE EQU     $00010000

; ============================================
; NDOS PROCESS CONTROL BLOCK TABLE
; ============================================


PCB_TABLE:
CURRENT_PROCESS:

PROC_PID:
        DC.L    0

PROC_STATE:
        DC.L    0

PROC_BASE:
        DC.L    0

PROC_SIZE:
        DC.L    0

PROC_ENTRY:
        DC.L    0

PROC_STACK_TOP:
        DC.L    0

PROC_STACK_SIZE:
        DC.L    0

PROC_KERNEL_SSP:
        DC.L    0

PROC_EXIT_CODE:
        DC.L    0

PROC_SIGNALS:
        DC.L    0
PROC_WAIT_MASK:
        DC.L    0
PROC_WAKE_TICK:
        DC.L    0
PROC_QUANTUM_LEFT:
        DC.L    0
PROC_REGION_ID:
        DC.L    0
PROC_PHYSICAL_SLOT_BASE:
        DC.L    0

PROC_SAVED_SSP:
        DC.L    0
PROC_SAVED_USP:
        DC.L    0
PROC_FPU_FLAGS:
        DC.L    0
PROC_FPU_FRAME:
        DS.B    PCB_FPU_FRAME_BYTES
PROC_FPU_REGS:
        DS.B    PCB_FPU_REGS_BYTES
PROC_FPU_CONTROL:
        DS.B    PCB_FPU_CONTROL_BYTES
stacksize:
        
TASK_SUPERVISOR_STACK_SIZE  EQU     256
TASK_USER_STACK_SIZE        EQU     1024

SECOND_PROCESS:
        DS.B    PCB_TABLE_BYTES-PCB_SIZEOF
PCB_TABLE_END:
        EVEN


SCHED_CURRENT_PCB:
        DC.L    CURRENT_PROCESS
TASK_A_SUPERVISOR_STACK:
        Ds.B    TASK_SUPERVISOR_STACK_SIZE

TASK_A_SUPERVISOR_STACK_TOP:
      EVEN
TASK_B_SUPERVISOR_STACK:
      Ds.B    TASK_SUPERVISOR_STACK_SIZE
TASK_B_SUPERVISOR_STACK_TOP:
    EVEN

TASK_A_USER_STACK:
        Ds.B    TASK_USER_STACK_SIZE
TASK_A_USER_STACK_TOP:
 EVEN
TASK_B_USER_STACK:
        Ds.B    TASK_USER_STACK_SIZE
TASK_B_USER_STACK_TOP:
        EVEN
        
        ; Freestanding GCC image.  The linker fixes it below the NEX region;
        ; build/c-map.inc exports its callable entry points to this source.
        ORG     $0000C000
NDOS_C_IMAGE:
        INCBIN  'build/ndos_c.bin'
NDOS_C_IMAGE_END:

        END     START
      










