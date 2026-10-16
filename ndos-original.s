
;-----------------------------------------------------------
; Title      : NDOS Pre-Alpha
; Written by : James
; Description: per alpha Ndos
;-----------------------------------------------------------
        ORG     $000000

        DC.L    $00008000          ; Initial supervisor stack pointer
        DC.L    START              ; Reset vector


*-----------------------------------------------------------
* CPU exception vectors
*-----------------------------------------------------------

        ORG     $000008
        DC.L    KERNAL_PANIC       ; Bus error

        ORG     $00000C
        DC.L    KERNAL_PANIC       ; Address error

        ORG     $000010
        DC.L    KERNAL_PANIC       ; Illegal instruction

        ORG     $000014
        DC.L    KERNAL_PANIC       ; Divide by zero

        ORG     $000018
        DC.L    KERNAL_PANIC       ; CHK

        ORG     $00001C
        DC.L    KERNAL_PANIC       ; TRAPV

        ORG     $000020
        DC.L    KERNAL_PANIC       ; Privilege violation


*-----------------------------------------------------------
* Timer IRQ
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
RAMDISK_SECTORS EQU 128

RAMDISK_BASE EQU $00100000
RAMDISKSIZE  EQU $00010000
SECTOR_BUFFER EQU $00110000



  

;-----------------------------------------------------------
; NDOS memory map
;-----------------------------------------------------------

PROGRAM_BASE        EQU     $00010000
PROGRAM_LIMIT       EQU     $0001FFFF
PROGRAM_REGION_SIZE EQU     $00010000

; J68K/MAME MC68681 virtual console (channel A, stride 4)
DUART_BASE          EQU     $00F00000
DUART_MR1A          EQU     DUART_BASE+0
DUART_SRA           EQU     DUART_BASE+4
DUART_CRA           EQU     DUART_BASE+8
DUART_TBA           EQU     DUART_BASE+12
DUART_RBA           EQU     DUART_BASE+12
*-----------------------------------------------------------
* Kernel code
*-----------------------------------------------------------

        ORG     $000100

START:
  CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER
        CLR.B   PROMPT_SKIP

        CLR.L   PROC_PID
        MOVE.L  #PROC_UNUSED,PROC_STATE
        CLR.L   PROC_EXIT_CODE

 
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
                ; Check CRASH
        LEA     CHAR_BUFFER,A0
        LEA     CMD_CRASH,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_CRASH

           ; Check HELP
        LEA     CHAR_BUFFER,A0
        LEA     CMD_HELP,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_HELP
        
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
        
          ; Check RUN
        LEA     CHAR_BUFFER,A0
        LEA     CMD_RUN,A1
        BSR     STRCMP

        TST.L   D0
        BEQ     COMMAND_RUN
        

        ; Nothing matched
        BRA     COMMAND_UNKNOWN


COMMAND_HELP:
        LEA     HELP_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE


COMMAND_VERSION:
        LEA     VERSION_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        BRA     COMMAND_DONE
COMMAND_RUN:
        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER

        ; Validate and copy NEX image
       LEA     NEX_HEADER,A0
        MOVE.L  #NEX_END-NEX_HEADER,D6
        BSR     LOAD_NEX

        TST.L   D0
        BNE     NEX_ERROR

        ; D1 = FS
        ; D2 = EP
        ; D3 = SS

        ; Entry address = PROGRAM_BASE + EP
        MOVEA.L #PROGRAM_BASE,A0
        ADDA.L  D2,A0

        ; User stack top
        MOVEA.L #PROGRAM_LIMIT+1,A1


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

        BRA     LAUNCH_PROGRAM

COMMAND_CLEAR:
        LEA     DUART_CLEAR_SEQ,A1
        BSR     DUART_PUTS
        BRA     COMMAND_DONE

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

 COMMAND_CRASH:
        ILLEGAL
  
  
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


PRINT_PROMPT:
        LEA     PROMPT_TEXT,A1
        MOVEQ   #7,D0
        TRAP    #0
        RTS
 

*-----------------------------------------------------------
*    STRORAGE code ram disk/ssd
;D0 = sector number
;A0 = source buffer
;A1 = RAMDISK_BASE + (D0 << 9)
;A0 preserved
;D0 = status
;A1 clobbered
;D2 scratch
;D3 scratch
*-----------------------------------------------------------
;D0 = sector number
;A0 = source buffer
;D3 = BYTE COUNTER
;D2 =  D0 original vaulue
;if D0 >= 128:
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
  
         cmp.l #128,d0 
         Bcc  .error
         
         
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
  
            

.error:
     move.l d2,a0
     moveq #-1,d0
     rts
  
;-----------------------------------------------------------
; NEX loader
; A0 = NEX header address
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
        MOVEA.L #PROGRAM_BASE,A2
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
        MOVE.L  A1,USP

        ; Build initial MC68020 format-0 frame
        CLR.W   -(A7)
        MOVE.L  A0,-(A7)
        MOVE.W  #$0000,-(A7)

        RTE
        
 ;-----------------------------------------------------------
;            scheduler
;-----------------------------------------------------------
 SCHEDULER:
        ADDQ.L  #1,YIELD_COUNT
        RTE       
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

        BRA     COMMAND_LOOP
.KERNEL_FATAL:
        STOP    #$2700

timer_irq:    
       addq.l #1,tick_counter
       rte
SYSCALL:
        CMPI.L  #7,D0
        BHI     SYS_INVALID

        MOVE.L  D0,D3
        LSL.L   #2,D3

        LEA     SYSCALL_TABLE,A0
        MOVEA.L 0(A0,D3.L),A0
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
        MOVE.L  #PROC_EXITED,PROC_STATE
        MOVE.L  D1,PROC_EXIT_CODE

        MOVE.L  PROC_KERNEL_SSP,A7

        CLR.W   BUF_INDEX
        CLR.B   CHAR_BUFFER

        BRA     COMMAND_LOOP
        
SYS_PUTCHAR:
        BSR     DUART_PUTCHAR
        MOVEQ   #0,D0      ; NDOS return value: success
        MOVE.B  D1,LASTCHAR   
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
       move.b #bs,d1
        BSR     DUART_PUTCHAR
    
        move.b #32,d1
        BSR     DUART_PUTCHAR
        move.b #bs,d1
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
.loop:
        MOVE.B  (A1)+,D1
        TST.B   D1
        BEQ     .done

        BSR     DUART_PUTCHAR
        BRA     .loop

.done:
        MOVEQ   #0,D0
        RTE



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
        MOVEQ   #0,D0
        BTST    #0,DUART_SRA
        BEQ     .none
        MOVE.B  DUART_RBA,D1
        MOVEQ   #1,D0
.none:
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
         
BUF_INDEX:
      DC.W 0
 
KERNEL_SSP:
        DC.L    0
        
LASTCHAR:
       DC.B 0
       
VERSION_BUFFER:
        DC.L    0
        DC.B    0

tick_counter:
       DC.L 0
NEX_ERROR_TEXT:
        DC.B    CR,LF
        DC.B    'INVALID NEX EXECUTABLE',CR,LF,0
     

msg:
        ; Minimal boot banner.  Keep this as ordinary console text so the
        ; existing TRAP #0 puts path and RAM-disk layout remain unchanged.
        DC.B    CR,LF
        DC.B    '================================',CR,LF
        DC.B    '              NDOS',CR,LF
        DC.B    '        PRE-ALPHA 0.01',CR,LF
        DC.B    '        J68K REV-A SYSTEM',CR,LF
        DC.B    '================================',CR,LF
        DC.B    'Memory: 2 MiB SRAM',CR,LF
        DC.B    'Console: MC68681 DUART',CR,LF
        DC.B    'Booting command shell...',CR,LF,CR,LF,0

DUART_CLEAR_SEQ:
        DC.B    27,'[2J',27,'[H',0
    
    
CMD_RUN:
        DC.B    'RUN',0
PROMPT_SKIP:
        DC.B    0
    
    
err:
     DC.B    'error code',0
      

CMD_HELP:
        DC.B    'HELP',0


UNKNOWN_TEXT:
        DC.B    CR,LF
        DC.B    'UNKNOWN COMMAND',CR,LF
        DC.B    0
        

CMD_VERSION:
        DC.B    'VERSION',0

CMD_CLEAR:
        DC.B    'CLEAR',0
CMD_CRASH:
        DC.B    'CRASH',0       
 

VERSION_TEXT:
        DC.B    CR,LF
        DC.B    'NDOS PRE-ALPHA VERSION 1.01',CR,LF
        DC.B    0       DC.B    'CLEAR',0
TEXT_BS:
     DC.B BS, 0
     
 PROMPT_TEXT:
        DC.B    'NDOS> ',0 
  

HELP_TEXT:
        DC.B    CR,LF
        DC.B    'NDOS COMMANDS:',CR,LF
        DC.B    'HELP    - SHOW COMMANDS',CR,LF
        DC.B    'VERSION - SHOW NDOS VERSION',CR,LF
        DC.B    'CLEAR   - CLEAR SCREEN',CR,LF
        DC.B    'RUN     - RUN PROGRAM',CR,LF
        DC.B    'CRASH    - RUN crash test',CR,LF
        DC.B    0
        
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
        
USER_EXCEPTION_TEXT:
        DC.B    CR,LF
        DC.B    'PROGRAM TERMINATED: CPU EXCEPTION VIOLATION',CR,LF
        DC.B    0
        
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
; NDOS PROCESS CONTROL BLOCK - REV 0
; ============================================

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
        
PROC_UNUSED     EQU     0
PROC_READY      EQU     1
PROC_RUNNING    EQU     2
PROC_EXITED     EQU     3

*===========================================================
* Embedded NEX test executable
*===========================================================
;
; OFFSET   SIZE    FIELD
; $00      4       SOH   "NDOS"
; $04      4       FS    Program size
; $08      4       EP    Entry-point offset
; $0C      4       SS    Stack size
; $10      ...     Program image
;

NEX_HEADER:
        DC.L    $4E444F53
        DC.L    PROGRAM_END-PROGRAM_START
        DC.L    PROGRAM_ENTRY-PROGRAM_START
        DC.L    1028

PROGRAM_START:

PROGRAM_ENTRY:
        LEA     START_TEXT(PC),A1
        MOVEQ   #7,D0              ; NDOS puts
        TRAP    #0

        MOVEQ   #20,D1
        MOVEQ   #22,D2
        MOVEQ   #1,D0              ; NDOS add
        TRAP    #0

        CMPI.L  #42,D0
        BNE     .FAIL

        LEA     PASS_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0

        MOVEQ   #0,D1              ; Successful exit code
        BRA     .EXIT

.FAIL:
        LEA     FAIL_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #1,D1              ; Failed exit code

.EXIT:
        MOVEQ   #4,D0              ; NDOS exit
        TRAP    #0

.HANG:
        BRA     .HANG              ; Should never be reached

START_TEXT:
        DC.B    CR,LF,'NEX PROGRAM STARTED',CR,LF,0
PASS_TEXT:
        DC.B    'ADD TEST PASSED',CR,LF,0
FAIL_TEXT:
        DC.B    'ADD TEST FAILED',CR,LF,0

PROGRAM_END:
NEX_END:

NEX_END:
        END     START
      










