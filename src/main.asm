section .bss
    numbers resq 1000           ; keep it simple, reserve space for 1000 numbers
    count resq 1                ; how many numbers i've read
    buffer resb 32              ; buffer to read a 64 bit number

section .data
    ;
    ; system constants
    ;
    stdin equ 0
    stdout equ 1
    stderr equ 2
    sys_read equ 0              ; rdi (fd), rsi (buf), rdx (count)
    sys_write equ 1             ; rdi (fd), rsi (buf), rdx (count)
    sys_open equ 2              ; rdi (filename), rsi (flags), rdx (mode)
    sys_exit equ 60             ; rdi (code)
    EXIT_SUCCESS equ 0
    EXIT_FAILURE equ 1
    O_RDONLY equ 0
    ;
    ; related to the program and not to the system
    ;
    buffer_size equ 32          ; used with buffer to call sys_write
    ;
    ; error/info messages
    ;
    msg_err_usage db "usage: ./main [input_set] [number]", 0xA
    msg_err_usage_len equ $-msg_err_usage
    msg_err_opening_file db "error: couldn't open file", 0xA
    msg_err_opening_file_len equ $-msg_err_opening_file
    msg_prompt db "enter a number: ", 0
    msg_prompt equ $-msg_prompt

section .text
    global _start

atoi:
    ; --------------------------------------
    ; args: rdi (pointer to the first byte)
    ;
    ;
    push rbp
    mov rbp, rsp
    xor rax, rax                ; initalise result to 0
    xor rcx, rcx                ; clear contents of rcx, store the current digit here

_next_digit:
    movzx rcx, byte [rdi]       ; move the contents of rdi (ptr to the string) to rcx
    test cl, cl                 ; null terminator check
    jz _done                    ; jump if zero bc it's null, so end
    cmp cl, '0'                 ; the cl register contains the lower 8 bits of rcx
    jl _error                   ; these two checks are to see if the character is a digit
    cmp cl, '9'
    jg _error
    sub cl, '0'                 ; convert ASCII to digit
    mov rdx, 10
    mul rdx                     ; rax *= 10
    test rdx, rdx               ; check for possible overflow
    jnz _error
    add rax, rcx                ; add this new digit
    jc _error                   ; another check for possible overflow, jc (check for zero in the cx register)
    inc rdi                     ; move to the next byte
    jmp _next_digit

_error:
    mov rax, err_code
    jmp _exit_atoi

_done:
                                ; nothing to do here, result is already in rax
_exit_atoi:
    pop rbp
    ret

_start:
    ;
    ; usage: ./main [sorted_data_set]
    ;
    ; e.g: ./main sorted_data_set.txt
    ;
    ; basic program that reads a data set file identified in argv[1] and prompts u to type a number,
    ; then it will show u a message telling you whether the computer did find the number in the set
    ; or not
    ;
    ; NOTE: it assumes ur input is already sorted bc i don't know how to do quicksort in asm yet
    ;
    pop rax                     ; get argc
    cmp rax, 2
    jne _wrong_num_args
    mov rax, sys_open
    mov rdi, [rsp + 8]          ; get filename (argv[1])
    mov rsi, O_RDONLY
    mov rdx, O_RDONLY
    syscall
    cmp rax, -1                 ; open returns -1 on error, otherwise the fd
    je _error_opening_file
    ; TODO: read file and store numbers in memory

    ; prompt the user
    mov rax, sys_write
    mov rdi, stdout
    mov rsi, msg_prompt
    mov rdx, msg_prompt_len
    syscall
    ; TODO: check for errors

    ; b4 reading, need to clear `buffer` of possible crap
    mov rdi, buffer             ; destination
    mov rcx, buffer_size        ; count
    xor al, al                  ; what am i filling with zeroes
    rep stosb                   ; repeat store byte
    ; read input from user
    mov rax, sys_read
    mov rdi, stdin
    mov rsi, buffer
    mov rdx, buffer_size
    ; TODO: check for errors

    mov rax, sys_exit
    mov rdi, EXIT_SUCCESS
    syscall

_wrong_num_args:
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_err_usage
    mov rdx, msg_err_usage_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall

_error_opening_file:
    mov rax, sys_write
    mov rdi, sterr
    mov rsi, msg_err_opening_file
    mov rdx, msg_err_opening_file_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall
