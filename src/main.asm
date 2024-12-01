section .bss
    numbers resq 1000           ; keep it simple, reserve space for 1000 numbers
    count resq 1                ; how many numbers i've read
    buffer resb 1000            ; buffer to read FIXME: half assed
    input_file_fd resq 1
    flush_buffer resb 1         ; temp buffer for flushing stdin

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
    buffer_size equ 1000        ; used with buffer to call sys_write FIXME: half assed
    max_digits equ 20           ; max digits for a 64 bit number
    ;
    ; error/info messages
    ;
    msg_err_usage db "usage: ./main [input_set]", 0xA
    msg_err_usage_len equ $-msg_err_usage
    msg_err_opening_file db "error: couldn't open file", 0xA
    msg_err_opening_file_len equ $-msg_err_opening_file
    msg_prompt db "enter a number: ", 0
    msg_prompt_len equ $-msg_prompt
    msg_err_write db "error: couldn't write to stdout", 0xA
    msg_err_write_len equ $-msg_err_write
    msg_err_read db "error: couldn't read from stdin", 0xA
    msg_err_read_len equ $-msg_err_read
    msg_found_num db "success! found the number in the array!", 0xA
    msg_found_num_len equ $-msg_found_num
    msg_not_found_num db "boooo! didn't find the number in the array", 0xA
    msg_not_found_num_len equ $-msg_not_found_num
    msg_err_atoi db "error parsing number in atoi", 0xA
    msg_err_atoi_len equ $-msg_err_atoi
    msg_err_reading_file db "error: couldn't read file", 0xA
    msg_err_reading_file_len equ $-msg_err_reading_file
    msg_piece_of_shit db "you suck so hard", 0xA
    msg_piece_of_shit_len equ $-msg_piece_of_shit
    msg_err_you_fucker db "error: input too long u fucker, max is 20 digits", 0xA
    msg_err_you_fucker_len equ $-msg_err_you_fucker

section .text
    global _start

flush_stdin:
    push rax
    push rdi
    push rsi
    push rdx

_flush_loop:
    mov rax, sys_read
    mov rdi, stdin
    mov rsi, flush_buffer
    mov rdx, 1
    syscall
    cmp rax, 1                  ; read 1 byte?
    jne _done_flush
    mov al, [flush_buffer]
    cmp al, 0xA                 ; newline found?
    jne _flush_loop             ; if not, keep reading

_done_flush:
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

read_file:
    ; --------------------------------------
    ; args: rdi (fd of the opened file)
    ;
    mov [input_file_fd], rdi    ; store fd in memory
    mov rbx, rdi                ; save the fd in rbx
    mov rsi, buffer             ; sys_read into this buffer
    mov rdx, buffer_size        ; num of bytes to read

_read_loop:
    mov rax, sys_read
    mov rdi, [input_file_fd]
    syscall
    cmp rax, 0                  ; did i reach the end?
    jl _error_reading_file
    je _done_read_file
    ; rax contains the num of bytes read, now prepare to call parse_numbers
    mov rcx, rax                ; set up counter for parsing
    mov rdi, buffer             ; set up buffer for parsing
    call parse_numbers
    cmp rax, -69
    je _error_reading_file_parsing
    mov rsi, count              ; get pointer to the count
    mov rdx, [rsi]              ; store in rdx
    cmp rdx, 1000               ; did i reach the limit
    je _done_read_file          ; yes, stop
    jmp _read_loop

_done_read_file:
    xor rax, rax
    ret

_error_reading_file_parsing:
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_piece_of_shit
    mov rdx, msg_piece_of_shit_len
    syscall
    mov rax, -69
    ret

_error_reading_file:
    mov rax, -69
    ret

parse_numbers:
    ; --------------------------------------
    ; args: rdi (pointer to the buffer)
    ;       rcx (number of bytes to parse)
    ;
    mov rbx, numbers            ; base addr of numbers array
    mov rsi, count              ; address of count
    mov rdx, [rsi]              ; current count of numbers

_parse_loop:
    cmp rcx, 0                  ; 0 bytes to read?
    jle _done_parse
    ; check current character
    movzx rax, byte [rdi]
    cmp al, 0x20                ; whitespace?
    je _skip_space               ; skip that fucker
    cmp al, 0xA                 ; newline?
    je _skip_space               ; skip that fucker
    test al, al                 ; YOOOO null terminator???
    jz _done_parse              ; i'm fucking done
    push rdx                    ; preserve my counter bitch
    call atoi                   ; convert ASCII letter to integer, res in rax
    pop rdx                     ; get my counter back
    cmp rax, -69                ; check for error
    je _error_parsing
    mov [rbx + rdx * 8], rax    ; store the integer into the array, rbx (base address of the array + current byte in that array + 8 bytes (64 bit int))
    inc rdx                     ; increment the counter
    jmp _parse_loop

_skip_space:
    inc rdi                     ; go to next character
    dec rcx                     ; decrease the count
    jmp _parse_loop             ; keep looping

_error_parsing:
    ret                         ; returns -69

_done_parse:
    mov [rsi], rdx              ; update count
    ret

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
    cmp cl, 0x20                ; whitespace
    je _done
    cmp cl, 0xA                 ; newline
    je _done
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
    mov rax, -69
    jmp _exit_atoi

_done:
                                ; nothing to do here, result is already in rax
_exit_atoi:
    pop rbp
    ret

binary_search:
    ;
    ; args: rdi (number to search)
    ;
    ; returns: 1 found
    ;          0 not found
    ;
    ;
    mov rax, rdi                ; rax = number to find
    mov rdi, numbers            ; rdi points to the base of the array of numbers
    xor rsi, rsi                ; left = 0
    mov rdx, [count]            ; right = count
    dec rdx                     ; right = count - 1

_bs_loop:
    cmp rsi, rdx
    jg _bs_not_found            ; left > right means not found
    mov rcx, rdx                ; rcx (mid) = right - left
    sub rcx, rsi                ; right - left
    shr rcx, 1                  ; right - left / 2
    add rcx, rsi                ; left + ((right - left) / 2)
    mov r8, [rdi + rcx * 8]     ; get the mid element
    cmp rax, r8
    je _bs_found
    jl _bs_go_left
    ; go right otherwise
    lea rsi, [rcx + 1]          ; left = mid + 1
    jmp _bs_loop

_bs_go_left:
    lea rdx, [rcx - 1]          ; right = mid - 1
    jmp _bs_loop

_bs_not_found:
    xor rax, rax
    ret

_bs_found:
    mov rax, 1
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
    syscall
    cmp rax, -1                 ; open returns -1 on error, otherwise the fd
    je _error_opening_file
    mov rdi, rax                ; pass fd i just obtained to read_file
    call read_file
    cmp rax, -69
    je _error_reading
    ; prompt the user
    mov rax, sys_write
    mov rdi, stdout
    mov rsi, msg_prompt
    mov rdx, msg_prompt_len
    syscall
    cmp rax, -1
    je _error_prompt_user
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
    syscall
    cmp rax, -1
    je _error_read_user
    cmp rax, max_digits
    jg _error_input_too_long
    mov rdi, buffer             ; pass what i've read from the user to atoi
    call atoi                   ; parse it and get the number in rax
    cmp rax, -69                ; check error
    je _error_atoi
    mov rdi, rax                ; prepare to call binary_search
    call binary_search          ; now call binary_search
    cmp rax, 1
    je _found_message
    jne _not_found_message

_found_message:
    mov rax, sys_write
    mov rdi, stdout
    mov rsi, msg_found_num
    mov rdx, msg_found_num_len
    syscall
    jmp _done_program

_not_found_message:
    mov rax, sys_write
    mov rdi, stdout
    mov rsi, msg_not_found_num
    mov rdx, msg_not_found_num_len
    syscall
    jmp _done_program

_done_program:
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
    mov rdi, stderr
    mov rsi, msg_err_opening_file
    mov rdx, msg_err_opening_file_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall

_error_prompt_user:
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_err_write
    mov rdx, msg_err_write_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall

_error_read_user:
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_err_read
    mov rdx, msg_err_read_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall

_error_atoi:
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_err_atoi
    mov rdx, msg_err_atoi_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall

_error_reading:
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_err_reading_file
    mov rdx, msg_err_reading_file_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall

_error_input_too_long:
    call flush_stdin            ; needed for long inputs (error)
    mov rax, sys_write
    mov rdi, stderr
    mov rsi, msg_err_you_fucker
    mov rdx, msg_err_you_fucker_len
    syscall
    mov rax, sys_exit
    mov rdi, EXIT_FAILURE
    syscall
