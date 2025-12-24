SO_REUSEADDR equ 1
SOL_SOCKET equ 2

section .data
    msg: db \
        "HTTP/1.0 200 OK", 13, 10, 13, 10, \
        "ok, Iscra-chan?"
        msg_len equ $ - msg
    optval: dd 1
    sockaddr:
        dw 2              ; AF_INET (IPV4)
        dw 0x901F         ; port 8080 (0x1F90), but in network byte order (big-endian)
        dd 0              ; Address 0.0.0.0 => Listening on all interfaces
        times 8 db 0      ; Padding (required in sockaddr_in structure)
    read_buf: times 1024 db 0
    file_path: times 256 db 0


section .text
global _start
_start:
    mov rdi, 2       ; AF_INET
    mov rsi, 1       ; SOCK_STREAM
    xor rdx, rdx     ; rdx = protocol = 0 = (TCP)
    mov rax, 41      ; syscall: socket
    syscall
    mov r12, rax     ; Save the server socket fd

    mov rax, 54         ; sys_setsockopt
    mov rdi, r12        ; дескриптор сокета (из r12)
    mov rsi, SOL_SOCKET
    mov rdx, SO_REUSEADDR
    mov r10, optval     ; адрес переменной со значением 1
    mov r8, 4           ; размер optval (4 байта для dd)
    syscall

    ; bind
    mov rdi, r12
    mov rsi, sockaddr ; pointer to address structure
    mov rdx, 16             ;frame size
    mov rax, 49             ; syscall: bind
    syscall

    ; listen
    mov rdi, r12
    xor rsi, rsi                 ; backlog = 0
    mov rax, 50                  ; syscall: listen
    syscall

    main_loop:
        ; accept
        mov rdi, r12
        xor rsi, rsi
        xor rdx, rdx
        mov rax, 43       ; syscall: accept
        syscall
        mov r13, rax      ; client fd (e.g., 4)

        ; fork
        mov rax, 57       ; syscall: fork
        syscall
        test rax, rax
        jz child_handler  ; child process (rax == 0)

        ; parent process
        ; close client socket (fd 4)
        mov rdi, r13
        mov rax, 3        ; syscall: close
        syscall
    jmp main_loop     ; back to accept

    child_handler:
        ; child closes listening socket (fd 3)
        mov rdi, r12
        mov rax, 3        ; syscall: close
        syscall

        ; read(client_fd, read_buf, 1024)
        mov rdi, r13
        mov rsi, read_buf
        mov rdx, 1024
        mov rax, 0        ; syscall: read
        syscall
        mov r14, rax      ; bytes read

        ; parse HTTP GET path
        lea rsi, [read_buf]
        lea rdi, [file_path]
        add rsi, 4        ; skip "GET "
        parse_loop:
            cmp byte [rsi], ' '
            je end_parse
            mov al, [rsi]
            mov [rdi], al
            inc rsi
            inc rdi
            jmp parse_loop
        end_parse:
        mov byte [rdi], 0

        mov rax, 1
        mov rdi, 1
        mov rsi, file_path
        mov rdx, 1024
        syscall

        ; open(file_path, O_RDONLY)
        lea rdi, [file_path]
        xor rsi, rsi      ; O_RDONLY = 0
        mov rax, 2        ; syscall: open
        syscall
        mov r15, rax      ; file fd (e.g., 3)

        ; read(file_fd, read_buf, 1024)
        mov rdi, r15
        lea rsi, [read_buf]
        mov rdx, 1024
        mov rax, 0        ; syscall: read
        syscall
        mov r14, rax

        ; close(file fd)
        mov rdi, r15
        mov rax, 3        ; syscall: close
        syscall

        ; write(client_fd, msg, msg_len)
        mov rdi, r13
        lea rsi, [msg]
        mov rdx, msg_len
        mov rax, 1        ; syscall: write
        syscall

        ; write(client_fd, read_buf, r14)
        mov rdi, r13
        lea rsi, [read_buf]
        mov rdx, r14
        mov rax, 1
        syscall

        ; close(client socket)
        mov rdi, r13
        mov rax, 3
        syscall

        ; exit(0)
        xor rdi, rdi
        mov rax, 60
        syscall