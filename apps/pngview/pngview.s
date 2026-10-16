        INCLUDE 'sdk/asm/ndos_syscall.inc'
        INCLUDE 'build/map.inc'

        ORG     0

START:
        ; Copy the generated 320x200 RGB332 image to the MAME framebuffer.
        LEA     IMAGE_DATA(PC),A1
        LEA     VIRTUAL_VIDEO_BASE,A0
        MOVEQ   #0,D0
        MOVE.W  #15999,D0             ; 16000 longwords = 64000 pixels
.COPY:
        MOVE.L  (A1)+,(A0)+
        DBF     D0,.COPY

        ; Keep the image visible until the user presses a key.
        MOVEQ   #NDOS_SYS_GETCHAR,D0
        TRAP    #0
        MOVEQ   #0,D1
        MOVEQ   #NDOS_SYS_EXIT,D0
        TRAP    #0

IMAGE_DATA:
        INCBIN  'build/assets/pngview.rgb332'

        END     START
