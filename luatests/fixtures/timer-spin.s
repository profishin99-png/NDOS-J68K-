        ORG     0

; Minimal CPU-bound test payload. No syscalls or TRAP #1: the timer IRQ must
; save and switch the interrupted user context itself.
START:
        BRA.S   START
        END     START
