;-----------------------------------------------------------------------------
; wordcount64.asm - count number of words, lines, and characters
;-----------------------------------------------------------------------------
;
; DHBW Ravensburg - Campus Friedrichshafen
;
; Vorlesung Systemnahe Programmierung (SNP)
;
; TESTAT TI20
;
;----------------------------------------------------------------------------
;
; Architecture:  x86-64
; Language:      NASM Assembly Language
;
; Course:    (X) TIT20    ( ) TIM20    ( ) TIS20
; Author 1: Florian Glaser
; Author 2: Florian Herkommer
; Author 3: David Felder
;
;----------------------------------------------------------------------------

%include "syscall.inc"  ; OS-specific system call macros

; import for output
extern  uint_to_ascii

;-----------------------------------------------------------------------------
; CONSTANTS
;-----------------------------------------------------------------------------
%define BUFFER_SIZE          512 ; max buffer size
%define CHR_LF               10  ; line feed (LF) character
%define SPACE                32  ; Highest not printable character

;-----------------------------------------------------------------------------
; Section DATA
;-----------------------------------------------------------------------------
SECTION .data

true:       db 0x01
false:      db 0x00

chars:      times 7 dq 0
lines:      times 7 dq 0
words:      times 7 dq 0

outstr:
            db "lines:   "
.lines        db "             ", CHR_LF
            db "words:   "
.words        db "             ", CHR_LF
            db "chars:   "
.chars        db "             ", CHR_LF

outstr_len  equ $-outstr
            db 0

;-----------------------------------------------------------------------------
; Section BSS
;-----------------------------------------------------------------------------
SECTION .bss

buffer          resb BUFFER_SIZE


;-----------------------------------------------------------------------------
; SECTION TEXT
;-----------------------------------------------------------------------------
SECTION .text

        ;-----------------------------------------------------------
        ; PROGRAM'S START ENTRY
        ;-----------------------------------------------------------
%ifidn __OUTPUT_FORMAT__, macho64
        DEFAULT REL
        global start            ; make label available to linker
start:                         ; standard entry point for ld
%else
        DEFAULT ABS
        global _start:function  ; make label available to linker
_start:
%endif
        nop

next_string:
        ;-----------------------------------------------------------
        ; read string from standard input (usually keyboard)
        ;-----------------------------------------------------------
        SYSCALL_4 SYS_READ, FD_STDIN, buffer, BUFFER_SIZE
        test    rax,rax         ; check system call return value
        jz      finished        ; jump to loop exit if end of input is
                                ; reached, i.e. no characters have been
                                ; read (rax == 0)

        ; rsi: pointer to current character in buffer
        lea     rsi,[buffer]
        mov     ecx,128
        xor     r8w,r8w                 ; "bool" to safe if last char was printable
next_char:
        movsx   edx,byte [rsi+rax-1]    ; ptr_current_char + ptr_line-1
        test    edx,edx                 ; test if edx < 128 -> ASCII Char
        cmovs   edx,ecx                 ; if edx >= 128 -> set edx 1000 0000b

        ; increment chars for each char
        inc     qword [chars]

        ; increment lines if current char equals LF
        cmp     edx,CHR_LF
        je      increment_lines

back_lines:
        ; increment words if unprintable char follows printable char
        cmp     r8w,[true]              ; check if last char was not printable
        jne     r8w_is_not_set

        cmp     edx,SPACE               ; check if current char is printable
        jg      increment_words         ; if greater than last not printable char increment word-counter
        jmp     back_words

r8w_is_not_set:
        cmp     edx,SPACE               ; check if current char is printable
        cmovle  r8w,[true]              ; if less equal than last not printable char set r8w = 1

back_words:
        dec     rax
        jnz     next_char
        jmp     next_string             ; jump back to read next input line

        ;-----------------------------------------------------------
        ; increment lines
        ;-----------------------------------------------------------
increment_lines:
        inc     qword [lines]
        jmp     back_lines

        ;-----------------------------------------------------------
        ; increment words
        ;-----------------------------------------------------------
increment_words:
        mov     r8w,[false]
        inc     qword [words]
        jmp     back_words

        ;-----------------------------------------------------------
        ; finish input loop
        ;-----------------------------------------------------------
finished:

        mov     rdi,outstr.lines
        mov     rsi,[lines]
        call    uint_to_ascii

        mov     rdi,outstr.words
        mov     rsi,[words]
        call    uint_to_ascii

        mov     rdi,outstr.chars
        mov     rsi,[chars]
        call    uint_to_ascii

        ;-----------------------------------------------------------
        ; print output string
        ;-----------------------------------------------------------
        SYSCALL_4 SYS_WRITE, FD_STDOUT, outstr, outstr_len

        ;-----------------------------------------------------------
        ; call system exit and return to operating system / shell
        ;-----------------------------------------------------------
_exit:  SYSCALL_2 SYS_EXIT, 0
        ;-----------------------------------------------------------
        ; END OF PROGRAM
        ;-----------------------------------------------------------
