        ORG     $00000000

        DC.L    $4E444F53              ; "NDOS"
        DC.L    IMAGE_END-IMAGE_START  ; payload size
        DC.L    NEX_ENTRY-IMAGE_START  ; entry offset
        DC.L    1024                   ; requested user stack

IMAGE_START:
NEX_ENTRY:
        LEA     HELLO_TEXT(PC),A1
        MOVEQ   #7,D0                  ; SYS_PUTS
        TRAP    #0

        MOVEQ   #4,D0                  ; SYS_EXIT
        MOVEQ   #0,D1
        TRAP    #0

.HANG:
        BRA     .HANG

HELLO_TEXT:
        DC.B    13,10
        DC.B    'HELLO.NEX LOADED FROM FAT12 DISK',13,10
        DC.B    'FILESYSTEM PROGRAM LAUNCH PASSED',13,10,0
        EVEN
IMAGE_END:
        END     NEX_ENTRY
