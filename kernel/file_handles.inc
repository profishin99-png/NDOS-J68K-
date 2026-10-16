; -----------------------------------------------------------
; NDOS file-handle ABI — first design pass
; -----------------------------------------------------------

MAX_OPEN_HANDLES        EQU     4

; Handle states
HANDLE_UNUSED           EQU     0
HANDLE_OPEN              EQU     1

; Open-mode bits
OPEN_READ                EQU     1
OPEN_WRITE               EQU     2
OPEN_CREATE              EQU     4
OPEN_TRUNCATE            EQU     8
OPEN_APPEND              EQU     16

; -----------------------------------------------------------
; Open-file record layout
;
; A0 = address of one file-handle record
; -----------------------------------------------------------

FH_STATE                 EQU     0
FH_MODE                  EQU     4
FH_FIRST_CLUSTER         EQU     8
FH_CURRENT_CLUSTER       EQU     12
FH_POSITION              EQU     16
FH_SIZE                  EQU     20
FH_DIRECTORY_ENTRY       EQU     24

FH_SIZEOF                EQU     28