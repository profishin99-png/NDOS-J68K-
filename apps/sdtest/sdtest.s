        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'

        ORG     0

SD_STATUS       EQU     VIRTUAL_SD_BASE+$00
SD_COMMAND      EQU     VIRTUAL_SD_BASE+$04
SD_LBA          EQU     VIRTUAL_SD_BASE+$08
SD_SECTORS      EQU     VIRTUAL_SD_BASE+$0C

SD_READ          EQU     1               ; card sector -> staging buffer
SD_WRITE         EQU     2               ; staging buffer -> card sector
TEST_LBA         EQU     16              ; MAME-only test sector
TEST_PATTERN     EQU     $A5A5A5A5

START:
        ; Fill all 512 bytes of the staging buffer with a known pattern.
        LEA     VIRTUAL_SD_BUFFER_BASE,A0
        MOVE.L  #TEST_PATTERN,D1
        MOVE.W  #127,D0
.FILL:
        MOVE.L  D1,(A0)+
        DBF     D0,.FILL

        ; Write it to a safe test sector on the virtual SD card.
        MOVE.L  #TEST_LBA,SD_LBA
        MOVE.L  #SD_WRITE,SD_COMMAND

        ; Clear the staging buffer so the following read proves it worked.
        LEA     VIRTUAL_SD_BUFFER_BASE,A0
        MOVEQ   #0,D1
        MOVE.W  #127,D0
.CLEAR:
        MOVE.L  D1,(A0)+
        DBF     D0,.CLEAR

        ; Read the same sector back into the staging buffer.
        MOVE.L  #TEST_LBA,SD_LBA
        MOVE.L  #SD_READ,SD_COMMAND

        ; Verify all 128 longwords.
        LEA     VIRTUAL_SD_BUFFER_BASE,A0
        MOVE.L  #TEST_PATTERN,D1
        MOVE.W  #127,D0
.VERIFY:
        CMP.L   (A0)+,D1
        BNE.S   .FAIL
        DBF     D0,.VERIFY

        LEA     PASS_TEXT(PC),A1
        BRA.S   .PRINT
.FAIL:
        LEA     FAIL_TEXT(PC),A1
.PRINT:
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0
        MOVEQ   #NDOS_SYS_GETCHAR,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0

PASS_TEXT:
        DC.B    13,10,'MAME VIRTUAL SD TEST PASS',13,10,0
FAIL_TEXT:
        DC.B    13,10,'MAME VIRTUAL SD TEST FAIL',13,10,0

        END     START
