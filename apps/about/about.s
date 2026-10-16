        ORG     0
START:
        LEA     ABOUT_TEXT(PC),A1
        MOVEQ   #7,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #4,D0
        TRAP    #0
.HANG:  BRA     .HANG
ABOUT_TEXT:
        DC.B    13,10,'NDOS PRE-ALPHA 1.01',13,10
        DC.B    'J68K REV-A MC68020 SYSTEM',13,10
        DC.B    'FAT12 APPLICATION SDK ACTIVE',13,10,0
        EVEN
        END     START
