        ORG     0

APP_ENTRY:
        LEA     MESSAGE(PC),A1
        MOVEQ   #7,D0
        TRAP    #0

        MOVEQ   #0,D1
        MOVEQ   #4,D0
        TRAP    #0

.HANG:
        BRA     .HANG

MESSAGE:
        DC.B    13,10,'HELLO FROM AN NDOS APPLICATION',13,10,0
        EVEN
        END     APP_ENTRY
