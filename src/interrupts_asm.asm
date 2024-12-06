[BITS 32]

global isr_keyboard
global isr_default

extern keyboardHandler
extern defaultHandler

section .text

; Macro for saving registers
%macro SAVE_REGISTERS 0
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    push ds
    push es
    push fs
    push gs
%endmacro

; Macro for restoring registers
%macro RESTORE_REGISTERS 0
    pop gs
    pop fs
    pop es
    pop ds
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro

isr_keyboard:
    SAVE_REGISTERS
    cld                    ; Clear direction flag
    call keyboardHandler
    RESTORE_REGISTERS
    iret

isr_default:
    SAVE_REGISTERS
    cld                    ; Clear direction flag
    call defaultHandler
    RESTORE_REGISTERS
    iret
