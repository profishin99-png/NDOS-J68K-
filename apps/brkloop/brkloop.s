        INCLUDE 'sdk/asm/ndos_syscall.inc'
        ORG     0

START:
        LEA     TITLE(PC),A1
        MOVEQ   #NDOS_SYS_PUTS,D0
        TRAP    #0

.PRINT_FOREVER:
        MOVEQ   #'.',D1
        MOVEQ   #NDOS_SYS_PUTCHAR,D0
        TRAP    #0
        BRA.S   .PRINT_FOREVER

TITLE:
        DC.B    13,10,'BRKLOOP: PRESS CTRL-C TO RETURN TO NDOS',13,10,0
        EVEN
        END     START
