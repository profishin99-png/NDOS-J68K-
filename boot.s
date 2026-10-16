; J68K Rev-A ROM BIOS and NDOS boot loader.
        include 'build/map.inc'

DUART_MR1A equ DUART_BASE+0*DUART_REG_STRIDE
DUART_SRA  equ DUART_BASE+1*DUART_REG_STRIDE
DUART_CRA  equ DUART_BASE+2*DUART_REG_STRIDE
DUART_TBA  equ DUART_BASE+3*DUART_REG_STRIDE
DUART_ACR  equ DUART_BASE+4*DUART_REG_STRIDE
DUART_IMR  equ DUART_BASE+5*DUART_REG_STRIDE
BIOS_VERSION equ $0100
BEL equ 7
FF  equ 12

; MAME-only virtual SD controller.  The final CPLD2/SPI ABI remains undefined.
SD_STATUS equ VIRTUAL_SD_BASE+$00
SD_COMMAND equ VIRTUAL_SD_BASE+$04
SD_LBA equ VIRTUAL_SD_BASE+$08
SD_SECTOR_COUNT equ VIRTUAL_SD_BASE+$0c
SD_BUFFER equ VIRTUAL_SD_BUFFER_BASE
SD_WORK equ $00180200
SD_W_FAT_START equ SD_WORK+$00
SD_W_ROOT_START equ SD_WORK+$04
SD_W_ROOT_SECTORS equ SD_WORK+$08
SD_W_DATA_START equ SD_WORK+$0c
SD_W_SECTORS_PER_CLUSTER equ SD_WORK+$10
SD_W_ROOT_ENTRIES equ SD_WORK+$14
SD_W_CLUSTER_COUNT equ SD_WORK+$18
SD_W_CLUSTER equ SD_WORK+$1c
SD_W_REMAINING equ SD_WORK+$20
SD_W_FILE_SIZE equ SD_WORK+$24
SD_W_DEST equ SD_WORK+$28
SD_W_FAT_OFFSET equ SD_WORK+$2c
SD_W_FAT_POSITION equ SD_WORK+$30
SD_W_TEMP equ SD_WORK+$34

        org ROM_BASE
        dc.l $001ff000,$00000100

        ; Identification block at permanent ROM address $FFF00020.
        dcb.b $20-(*-ROM_BASE),$ff
        dc.b 'J68KBIOS',0
        even
        dc.w BIOS_VERSION

        ; Fixed BIOS service-pointer table at $FFF00040.
        dcb.b $40-(*-ROM_BASE),$ff
        dc.l BIOS_PUTCHAR
        dc.l BIOS_PUTS
        dc.l BIOS_BEEP_CODE
        dc.l BIOS_POST
        dc.l BIOS_DUART_INIT
        dc.l 0

        dcb.b $100-(*-ROM_BASE),$ff
        ; Reset executes this at low alias $00000100.  Move instruction
        ; fetch high before the POST clears the overlay.
        dc.w $4ef9
        dc.l HIGH_ENTRY

HIGH_ENTRY:
        move.w  #$2700,sr
        bsr.w   BIOS_DUART_INIT
        lea     BIOS_BANNER,a1
        bsr.w   BIOS_PUTS
        bsr.w   BIOS_POST
        tst.l   d0
        bne.w   BIOS_POST_FATAL

        lea     BIOS_PASS_TEXT,a1
        bsr.w   BIOS_PUTS
        moveq   #1,d0
        bsr.w   BIOS_BEEP_CODE
        bsr.w   BIOS_RESULT_DELAY
        moveq   #FF,d1
        bsr.w   BIOS_PUTCHAR

        ; Prefer NDOS.SYS from the mounted MAME SD image.  Any missing,
        ; unsupported or damaged card falls back to the ROM-resident copy.
        lea     BIOS_SD_CHECK_TEXT,a1
        bsr.w   BIOS_PUTS
        bsr.w   BIOS_TRY_SD_BOOT
        lea     BIOS_SD_FALLBACK_TEXT,a1
        bsr.w   BIOS_PUTS

        ; Overlay is now clear. Install NDOS, including vectors, at zero.
        lea     PAYLOAD,a0
        suba.l  a1,a1
        move.l  #PAYLOAD_END-PAYLOAD,d0
BIOS_COPY_NDOS:
        move.b  (a0)+,(a1)+
        subq.l  #1,d0
        bne     BIOS_COPY_NDOS

        moveq   #0,d0
        movec   d0,vbr
        movea.l $0.l,sp
        movea.l $4.l,a0
        jmp     (a0)

; POST result D0: 0 pass, 1 ROM alias, 2 SRAM, 3 overlay/low SRAM.
BIOS_POST:
        lea     BIOS_ROM_TEXT,a1
        bsr.w   BIOS_PUTS
        suba.l  a0,a0
        movea.l #ROM_BASE,a1
        moveq   #15,d2
BIOS_ROM_COMPARE:
        move.l  (a0)+,d1
        cmp.l   (a1)+,d1
        bne.w   BIOS_ROM_FAILED
        dbra    d2,BIOS_ROM_COMPARE
        lea     BIOS_OK_TEXT,a1
        bsr.w   BIOS_PUTS

        lea     BIOS_SRAM_TEXT,a1
        bsr.w   BIOS_PUTS
        lea     BIOS_SRAM_TEST_ADDRESSES,a2
BIOS_SRAM_NEXT:
        move.l  (a2)+,d0
        beq     BIOS_SRAM_PASSED
        movea.l d0,a0
        bsr.w   BIOS_TEST_SRAM_ADDRESS
        tst.l   d0
        bne.w   BIOS_SRAM_FAILED
        bra     BIOS_SRAM_NEXT
BIOS_SRAM_PASSED:
        lea     BIOS_OK_TEXT,a1
        bsr.w   BIOS_PUTS

        lea     BIOS_OVERLAY_TEXT,a1
        bsr.w   BIOS_PUTS
        move.l  #1,CORE_BASE+OVERLAY_CLEAR_OFFSET
        suba.l  a0,a0
        move.l  #$55aa33cc,(a0)
        cmpi.l  #$55aa33cc,(a0)
        bne.w   BIOS_OVERLAY_FAILED
        lea     BIOS_OK_TEXT,a1
        bsr.w   BIOS_PUTS
        moveq   #0,d0
        rts

BIOS_ROM_FAILED:
        moveq   #1,d0
        rts
BIOS_SRAM_FAILED:
        moveq   #2,d0
        rts
BIOS_OVERLAY_FAILED:
        moveq   #3,d0
        rts

; Test one aligned longword and all four byte lanes; restore original data.
BIOS_TEST_SRAM_ADDRESS:
        move.l  (a0),d4
        move.l  #$55aa33cc,(a0)
        cmpi.l  #$55aa33cc,(a0)
        bne     BIOS_TEST_SRAM_BAD
        move.l  #$aa55cc33,(a0)
        cmpi.l  #$aa55cc33,(a0)
        bne     BIOS_TEST_SRAM_BAD
        clr.l   (a0)
        move.b  #$12,0(a0)
        move.b  #$34,1(a0)
        move.b  #$56,2(a0)
        move.b  #$78,3(a0)
        cmpi.l  #$12345678,(a0)
        bne     BIOS_TEST_SRAM_BAD
        move.l  d4,(a0)
        moveq   #0,d0
        rts
BIOS_TEST_SRAM_BAD:
        move.l  d4,(a0)
        moveq   #-1,d0
        rts

BIOS_DUART_INIT:
        move.b  #$10,DUART_CRA
        move.b  #$20,DUART_CRA
        move.b  #$30,DUART_CRA
        move.b  #$13,DUART_MR1A
        ; MR2A: normal mode, CTS gates transmitter, 1 stop bit.
        ; RTS itself is controlled by the NDOS receive-queue watermarks.
        move.b  #$17,DUART_MR1A
        move.b  #0,DUART_ACR
        move.b  #$cc,DUART_SRA ; RX/TX selector C = 38400 baud; matches the installed MAME terminal default
        move.b  #0,DUART_IMR
        move.b  #$05,DUART_CRA
        rts

; D1.B = character
BIOS_PUTCHAR:
BIOS_TX_WAIT:
        btst    #2,DUART_SRA
        beq     BIOS_TX_WAIT
        move.b  d1,DUART_TBA
        rts

; A1 = zero-terminated string
BIOS_PUTS:
        move.b  (a1)+,d1
        beq     BIOS_PUTS_DONE
        bsr     BIOS_PUTCHAR
        bra     BIOS_PUTS
BIOS_PUTS_DONE:
        rts

; D0 = count. BEL targets the RS-232 terminal; no board speaker is defined.
BIOS_BEEP_CODE:
        movem.l d1-d3,-(sp)
        move.l  d0,d2
BIOS_BEEP_NEXT:
        tst.l   d2
        beq     BIOS_BEEP_DONE
        moveq   #BEL,d1
        bsr     BIOS_PUTCHAR
        move.l  #50000,d3
BIOS_BEEP_GAP:
        subq.l  #1,d3
        bne     BIOS_BEEP_GAP
        subq.l  #1,d2
        bra     BIOS_BEEP_NEXT
BIOS_BEEP_DONE:
        movem.l (sp)+,d1-d3
        rts

BIOS_RESULT_DELAY:
        movem.l d2-d3,-(sp)
        moveq   #20,d2
BIOS_DELAY_OUTER:
        move.w  #$ffff,d3
BIOS_DELAY_INNER:
        dbra    d3,BIOS_DELAY_INNER
        dbra    d2,BIOS_DELAY_OUTER
        movem.l (sp)+,d2-d3
        rts

BIOS_POST_FATAL:
        move.l  d0,d4
        lea     BIOS_FAIL_TEXT,a1
        bsr.w   BIOS_PUTS
BIOS_FATAL_REPEAT:
        move.l  d4,d0
        bsr.w   BIOS_BEEP_CODE
        bsr.w   BIOS_RESULT_DELAY
        bra     BIOS_FATAL_REPEAT

; Mount-time image protocol for the MAME-only sector device:
;   D0 = LBA, command 1 reads one 512-byte sector into SD_BUFFER.
; Returns D0=0 on success.  A card image is a raw FAT12 floppy image.
BIOS_SD_READ_SECTOR:
        move.l  d0,SD_LBA
        move.l  #1,SD_COMMAND
        move.l  SD_STATUS,d1
        btst    #30,d1
        beq.s   BIOS_SD_READ_FAILED
        andi.l  #$000000ff,d1
        bne.s   BIOS_SD_READ_FAILED
        moveq   #0,d0
        rts
BIOS_SD_READ_FAILED:
        moveq   #-1,d0
        rts

; A0 points at little-endian metadata.  Helpers advance A0 and return D0.
BIOS_SD_READ_LE16:
        moveq   #0,d0
        move.b  (a0)+,d0
        moveq   #0,d1
        move.b  (a0)+,d1
        lsl.w   #8,d1
        or.w    d1,d0
        rts

BIOS_SD_READ_LE32:
        moveq   #0,d0
        move.b  (a0)+,d0
        moveq   #0,d1
        move.b  (a0)+,d1
        lsl.l   #8,d1
        or.l    d1,d0
        moveq   #0,d1
        move.b  (a0)+,d1
        swap    d1
        or.l    d1,d0
        moveq   #0,d1
        move.b  (a0)+,d1
        lsl.w   #8,d1
        swap    d1
        or.l    d1,d0
        rts

; Return to ROM boot if the card is absent or NDOS.SYS cannot be loaded.
; On success, the file is placed at address zero and execution enters its vector.
BIOS_TRY_SD_BOOT:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #0,d0
        bsr.w   BIOS_SD_READ_SECTOR
        tst.l   d0
        bne.w   BIOS_SD_BOOT_FAILED

        lea     SD_BUFFER,a0
        cmpi.b  #$55,510(a0)
        bne.w   BIOS_SD_BOOT_FAILED
        cmpi.b  #$aa,511(a0)
        bne.w   BIOS_SD_BOOT_FAILED
        lea     11(a0),a0
        bsr.w   BIOS_SD_READ_LE16
        cmpi.w  #512,d0
        bne.w   BIOS_SD_BOOT_FAILED

        lea     SD_BUFFER+13,a0
        moveq   #0,d0
        move.b  (a0),d0
        beq.w   BIOS_SD_BOOT_FAILED
        cmpi.w  #64,d0
        bhi.w   BIOS_SD_BOOT_FAILED
        move.l  d0,SD_W_SECTORS_PER_CLUSTER

        lea     SD_BUFFER+14,a0
        bsr.w   BIOS_SD_READ_LE16
        tst.w   d0
        beq.w   BIOS_SD_BOOT_FAILED
        move.l  d0,SD_W_FAT_START
        move.l  d0,SD_W_ROOT_START

        lea     SD_BUFFER+16,a0
        moveq   #0,d1
        move.b  (a0),d1
        beq.w   BIOS_SD_BOOT_FAILED
        move.l  d1,d4

        lea     SD_BUFFER+17,a0
        bsr.w   BIOS_SD_READ_LE16
        tst.w   d0
        beq.w   BIOS_SD_BOOT_FAILED
        move.l  d0,SD_W_ROOT_ENTRIES
        lsl.l   #5,d0
        addi.l  #511,d0
        lsr.l   #8,d0
        lsr.l   #1,d0
        move.l  d0,SD_W_ROOT_SECTORS

        lea     SD_BUFFER+22,a0
        bsr.w   BIOS_SD_READ_LE16
        tst.w   d0
        beq.w   BIOS_SD_BOOT_FAILED
        move.l  d0,d5
        move.l  SD_W_FAT_START,d0
        move.l  d4,d1
        mulu.w  d5,d1
        add.l   d1,d0
        move.l  d0,SD_W_ROOT_START
        add.l   SD_W_ROOT_SECTORS,d0
        move.l  d0,SD_W_DATA_START

        ; The BIOS loader intentionally supports FAT12 only (cluster count < 4085).
        lea     SD_BUFFER+19,a0
        bsr.w   BIOS_SD_READ_LE16
        andi.l  #$0000ffff,d0
        bne.s   BIOS_SD_TOTAL_READY
        lea     SD_BUFFER+32,a0
        bsr.w   BIOS_SD_READ_LE32
BIOS_SD_TOTAL_READY:
        move.l  SD_SECTOR_COUNT,d1
        cmp.l   d1,d0
        bhi.w   BIOS_SD_BOOT_FAILED
        sub.l   SD_W_DATA_START,d0
        bmi.w   BIOS_SD_BOOT_FAILED
        move.l  SD_W_SECTORS_PER_CLUSTER,d1
        divu.w  d1,d0
        andi.l  #$0000ffff,d0
        cmpi.l  #4085,d0
        bhs.w   BIOS_SD_BOOT_FAILED
        move.l  d0,SD_W_CLUSTER_COUNT

        ; Locate the exact 8.3 root entry NDOS    SYS.
        move.l  SD_W_ROOT_START,d5
        move.l  SD_W_ROOT_SECTORS,d6
        move.l  SD_W_ROOT_ENTRIES,d7
BIOS_SD_ROOT_SECTOR:
        move.l  d5,d0
        bsr.w   BIOS_SD_READ_SECTOR
        tst.l   d0
        bne.w   BIOS_SD_BOOT_FAILED
        lea     SD_BUFFER,a0
        moveq   #16,d4
BIOS_SD_ROOT_ENTRY:
        tst.l   d7
        beq.w   BIOS_SD_BOOT_FAILED
        movea.l a0,a4
        tst.b   (a0)
        beq.w   BIOS_SD_BOOT_FAILED
        cmpi.b  #$e5,(a0)
        beq.s   BIOS_SD_ROOT_NEXT
        cmpi.b  #$0f,11(a0)
        beq.s   BIOS_SD_ROOT_NEXT
        lea     BIOS_SD_NDOS_NAME,a1
        moveq   #10,d3
BIOS_SD_NAME_COMPARE:
        cmpm.b  (a1)+,(a0)+
        bne.s   BIOS_SD_NAME_NO_MATCH
        dbra    d3,BIOS_SD_NAME_COMPARE
        movea.l a4,a0
        lea     26(a0),a0
        bsr.w   BIOS_SD_READ_LE16
        move.l  d0,SD_W_CLUSTER
        lea     28(a4),a0
        bsr.w   BIOS_SD_READ_LE32
        tst.l   d0
        beq.w   BIOS_SD_BOOT_FAILED
        cmpi.l  #$00010000,d0
        bhi.w   BIOS_SD_BOOT_FAILED
        move.l  d0,SD_W_FILE_SIZE
        move.l  d0,SD_W_REMAINING
        move.l  #0,SD_W_DEST
        bra.w   BIOS_SD_LOAD_FILE
BIOS_SD_NAME_NO_MATCH:
        movea.l a4,a0
BIOS_SD_ROOT_NEXT:
        adda.w  #32,a0
        subq.l  #1,d7
        subq.w  #1,d4
        bne.s   BIOS_SD_ROOT_ENTRY
        addq.l  #1,d5
        subq.l  #1,d6
        bne.w   BIOS_SD_ROOT_SECTOR
        bra.w   BIOS_SD_BOOT_FAILED

BIOS_SD_LOAD_FILE:
        move.l  #128,d6             ; hard bound prevents corrupt FAT loops
BIOS_SD_LOAD_CLUSTER:
        tst.l   d6
        beq.w   BIOS_SD_BOOT_FAILED
        subq.l  #1,d6
        move.l  SD_W_CLUSTER,d7
        cmpi.l  #2,d7
        blo.w   BIOS_SD_BOOT_FAILED
        move.l  SD_W_CLUSTER_COUNT,d0
        addq.l  #2,d0
        cmp.l   d0,d7
        bhs.w   BIOS_SD_BOOT_FAILED
        moveq   #0,d5
BIOS_SD_LOAD_CLUSTER_SECTOR:
        move.l  SD_W_REMAINING,d0
        beq.w   BIOS_SD_VALIDATE_LOADED
        move.l  d7,d0
        subq.l  #2,d0
        move.l  SD_W_SECTORS_PER_CLUSTER,d1
        mulu.w  d1,d0
        add.l   d5,d0
        add.l   SD_W_DATA_START,d0
        bsr.w   BIOS_SD_READ_SECTOR
        tst.l   d0
        bne.w   BIOS_SD_BOOT_FAILED

        move.l  SD_W_REMAINING,d4
        cmpi.l  #512,d4
        bls.s   BIOS_SD_COPY_COUNT_READY
        move.l  #512,d4
BIOS_SD_COPY_COUNT_READY:
        move.l  d4,SD_W_TEMP
        lea     SD_BUFFER,a0
        movea.l SD_W_DEST,a1
BIOS_SD_COPY_BYTE:
        move.b  (a0)+,(a1)+
        subq.l  #1,d4
        bne.s   BIOS_SD_COPY_BYTE
        move.l  a1,SD_W_DEST
        move.l  SD_W_REMAINING,d0
        sub.l   SD_W_TEMP,d0
        move.l  d0,SD_W_REMAINING
        tst.l   SD_W_REMAINING
        beq.w   BIOS_SD_VALIDATE_LOADED
        addq.l  #1,d5
        cmp.l   SD_W_SECTORS_PER_CLUSTER,d5
        blo.w   BIOS_SD_LOAD_CLUSTER_SECTOR

        ; Read the next packed 12-bit FAT entry, including sector-boundary case.
        move.l  SD_W_CLUSTER,d0
        move.l  d0,d1
        lsr.l   #1,d1
        add.l   d1,d0
        move.l  d0,SD_W_FAT_OFFSET
        move.l  d0,d1
        lsr.l   #8,d1
        lsr.l   #1,d1
        andi.l  #$000001ff,d0
        move.l  d0,SD_W_FAT_POSITION
        move.l  SD_W_FAT_START,d0
        add.l   d1,d0
        bsr.w   BIOS_SD_READ_SECTOR
        tst.l   d0
        bne.w   BIOS_SD_BOOT_FAILED
        movea.l #SD_BUFFER,a0
        adda.l  SD_W_FAT_POSITION,a0
        moveq   #0,d0
        move.b  (a0),d0
        move.l  d0,SD_W_TEMP
        cmpi.l  #511,SD_W_FAT_POSITION
        bne.s   BIOS_SD_FAT_SECOND_BYTE
        move.l  SD_W_FAT_START,d0
        move.l  SD_W_FAT_OFFSET,d1
        lsr.l   #8,d1
        lsr.l   #1,d1
        addq.l  #1,d1
        add.l   d1,d0
        bsr.w   BIOS_SD_READ_SECTOR
        tst.l   d0
        bne.w   BIOS_SD_BOOT_FAILED
        movea.l #SD_BUFFER,a0
        moveq   #0,d1
        move.b  (a0),d1
        bra.s   BIOS_SD_FAT_WORD_READY
BIOS_SD_FAT_SECOND_BYTE:
        moveq   #0,d1
        move.b  1(a0),d1
BIOS_SD_FAT_WORD_READY:
        lsl.w   #8,d1
        move.l  SD_W_TEMP,d0
        or.w    d1,d0
        btst    #0,SD_W_CLUSTER+3
        beq.s   BIOS_SD_FAT_EVEN
        lsr.w   #4,d0
        bra.s   BIOS_SD_FAT_VALUE_READY
BIOS_SD_FAT_EVEN:
        andi.w  #$0fff,d0
BIOS_SD_FAT_VALUE_READY:
        andi.l  #$0000ffff,d0
        cmpi.l  #$00000ff8,d0
        bhs.w   BIOS_SD_BOOT_FAILED
        move.l  d0,SD_W_CLUSTER
        bra.w   BIOS_SD_LOAD_CLUSTER

BIOS_SD_VALIDATE_LOADED:
        ; Validate the NDOS reset vectors before transferring control.
        move.l  0.l,d0
        cmpi.l  #$00001000,d0
        blo.w   BIOS_SD_BOOT_FAILED
        cmpi.l  #$00200000,d0
        bhi.w   BIOS_SD_BOOT_FAILED
        move.l  4.l,d1
        cmpi.l  #$00000100,d1
        blo.w   BIOS_SD_BOOT_FAILED
        cmp.l   SD_W_FILE_SIZE,d1
        bhs.w   BIOS_SD_BOOT_FAILED
        lea     BIOS_SD_BOOT_TEXT,a1
        bsr.w   BIOS_PUTS
        moveq   #0,d0
        movec   d0,vbr
        movea.l 0.l,sp
        movea.l 4.l,a0
        jmp     (a0)

BIOS_SD_BOOT_FAILED:
        movem.l (sp)+,d1-d7/a0-a6
        moveq   #-1,d0
        rts

        even
BIOS_SRAM_TEST_ADDRESSES:
        dc.l $00020000,$00040000,$00080000,$00100000
        dc.l $00180000,$001ffffc,0

BIOS_BANNER:
        dc.b 13,10,'J68K REV-A BIOS 1.0',13,10
        dc.b 'MC68020 16 MHZ POWER-ON SELF TEST',13,10,0
BIOS_ROM_TEXT:
        dc.b 'ROM ALIAS ........ ',0
BIOS_SRAM_TEXT:
        dc.b 'SRAM/LANES ....... ',0
BIOS_OVERLAY_TEXT:
        dc.b 'RESET OVERLAY .... ',0
BIOS_OK_TEXT:
        dc.b 'OK',13,10,0
BIOS_PASS_TEXT:
        dc.b 'POST PASS - BOOTING NDOS',13,10,0
BIOS_FAIL_TEXT:
        dc.b 'FAILED - HALTED; BEEP CODE REPEATS',13,10,0
BIOS_SD_NDOS_NAME:
        dc.b 'NDOS    SYS'
BIOS_SD_CHECK_TEXT:
        dc.b 'SD BOOT: LOOKING FOR NDOS.SYS...',13,10,0
BIOS_SD_FALLBACK_TEXT:
        dc.b 'SD BOOT NOT AVAILABLE - USING ROM NDOS',13,10,0
BIOS_SD_BOOT_TEXT:
        dc.b 'SD BOOT: NDOS.SYS LOADED',13,10,0

        even
PAYLOAD:
        incbin 'build/ndos.bin'
PAYLOAD_END:
        dcb.b ROM_SIZE-(*-ROM_BASE),$ff
