BITS 16
ORG 0x7C00

jmp short start
nop

bpb_oem:                    db "PecDOS  "
bpb_bytes_per_sector:       dw 512
bpb_sectors_per_cluster:    db 1
bpb_reserved_sectors:       dw 32
bpb_fat_count:              db 2
bpb_root_entry_count:       dw 0
bpb_total_sectors:          dw 0
bpb_media_descriptor:       db 0xF8
bpb_sectors_per_fat:        dw 0
bpb_sectors_per_track:      dw 18
bpb_head_count:             dw 2
bpb_hidden_sectors:         dd 0
bpb_large_sector_count:     dd 0

ebpb_sectors_per_fat32:     dd 0x00000180
ebpb_flags:                 dw 0
ebpb_fat_version:           dw 0
ebpb_root_cluster:          dd 2
ebpb_fs_info_sector:        dw 1
ebpb_backup_boot_sector:    dw 6
ebpb_reserved:              times 12 db 0
ebpb_drive_number:          db 0x80
ebpb_nt_flags:              db 0
ebpb_signature:             db 0x29
ebpb_volume_id:             dd 0x12345678
ebpb_volume_label:          db "PEACEDOS   "
ebpb_system_id:             db "FAT32   "

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov ax, 0x0200 + 63
    mov cx, 0x0002
    mov dh, 0
    mov bx, 0x7E00
    int 0x13
    jc disk_error

    jmp 0x0000:0x7E00

disk_error:
    mov si, msg_disk_error
    call boot_print_string
    jmp $

boot_print_string:
    mov ah, 0x0E
.boot_print_loop:
    lodsb
    test al, al
    jz .boot_print_done
    int 0x10
    jmp .boot_print_loop
.boot_print_done:
    ret

boot_drive: db 0
msg_disk_error: db "Disk error! System halted.", 0

times 510-($-$$) db 0
dw 0xAA55

kernel_start:
    call clear_screen
    mov si, msg_welcome
    call print_string
    
main_loop:
    mov si, prompt
    call print_string
    
    mov di, command_buffer
    call read_command
    
    call process_command
    jmp main_loop

clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

print_string:
    mov ah, 0x0E
.print_loop:
    lodsb
    test al, al
    jz .print_done
    int 0x10
    jmp .print_loop
.print_done:
    ret

read_command:
    xor cx, cx
    mov byte [di], 0
    
.read_loop:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x0D
    je .done
    
    cmp al, 0x08
    je .backspace
    
    cmp al, 0
    je .read_loop
    
    cmp cx, 250
    jae .read_loop
    
    mov [di], al
    inc di
    inc cx
    
    mov ah, 0x0E
    int 0x10
    jmp .read_loop

.backspace:
    test cx, cx
    jz .read_loop
    dec di
    dec cx
    mov byte [di], 0
    
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop

.done:
    mov byte [di], 0
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

process_command:
    mov si, command_buffer
    
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .empty
    dec si
    
    call to_uppercase
    
    mov di, cmd_help
    call simple_strcmp
    jc execute_help
    
    mov di, cmd_ver
    call simple_strcmp
    jc execute_ver
    
    mov di, cmd_dir
    call simple_strcmp
    jc execute_dir
    
    mov di, cmd_cls
    call simple_strcmp
    jc execute_cls
    
    mov di, cmd_time
    call simple_strcmp
    jc execute_time
    
    mov di, cmd_date
    call simple_strcmp
    jc execute_date
    
    mov di, cmd_mem
    call simple_strcmp
    jc execute_mem
    
    mov di, cmd_vol
    call simple_strcmp
    jc execute_vol
    
    mov si, msg_unknown_cmd
    call print_string
    ret

.empty:
    ret

execute_help:
    mov si, msg_help
    call print_string
    ret

execute_ver:
    mov si, msg_version
    call print_string
    ret

execute_dir:
    mov si, msg_dir_header
    call print_string
    mov si, file_list
    call print_string
    ret

execute_cls:
    call clear_screen
    ret

execute_time:
    mov ah, 0x02
    int 0x1A
    jc .time_error
    
    mov si, msg_time
    call print_string
    
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char
    mov al, cl
    call print_bcd
    mov al, ':'
    call print_char
    mov al, dh
    call print_bcd
    call newline
    ret

.time_error:
    mov si, msg_time_error
    call print_string
    ret

execute_date:
    mov ah, 0x04
    int 0x1A
    jc .date_error
    
    mov si, msg_date
    call print_string
    
    mov al, dl
    call print_bcd
    mov al, '/'
    call print_char
    mov al, dh
    call print_bcd
    mov al, '/'
    call print_char
    mov ax, cx
    call print_hex_byte
    mov al, ah
    call print_hex_byte
    call newline
    ret

.date_error:
    mov si, msg_date_error
    call print_string
    ret

execute_mem:
    mov si, msg_mem
    call print_string
    
    mov ah, 0x88
    int 0x15
    mov si, msg_mem_base
    call print_string
    call print_decimal
    mov si, msg_kb
    call print_string
    
    mov ax, 0xE801
    int 0x15
    jc .no_extended
    
    mov si, msg_mem_ext
    call print_string
    mov ax, bx
    call print_decimal
    mov si, msg_kb
    call print_string
    
.no_extended:
    ret

execute_vol:
    mov si, msg_vol
    call print_string
    ret

simple_strcmp:
    push si
    push di
    push ax
    push bx
    
.strcmp_loop:
    mov al, [si]
    mov bl, [di]
    
    cmp al, bl
    jne .not_equal
    
    test al, al
    jz .equal
    
    inc si
    inc di
    jmp .strcmp_loop

.equal:
    pop bx
    pop ax
    pop di
    pop si
    stc
    ret

.not_equal:
    pop bx
    pop ax
    pop di
    pop si
    clc
    ret

to_uppercase:
    mov si, command_buffer
.upper_loop:
    mov al, [si]
    test al, al
    jz .upper_done
    cmp al, 'a'
    jb .upper_next
    cmp al, 'z'
    ja .upper_next
    sub al, 0x20
    mov [si], al
.upper_next:
    inc si
    jmp .upper_loop
.upper_done:
    ret

print_char:
    mov ah, 0x0E
    int 0x10
    ret

newline:
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    ret

print_bcd:
    push ax
    shr al, 4
    add al, '0'
    call print_char
    pop ax
    and al, 0x0F
    add al, '0'
    call print_char
    ret

print_hex_byte:
    push ax
    shr al, 4
    call nibble_to_hex
    call print_char
    pop ax
    and al, 0x0F
    call nibble_to_hex
    call print_char
    ret

nibble_to_hex:
    cmp al, 10
    jb .nibble_digit
    add al, 'A' - 10
    ret
.nibble_digit:
    add al, '0'
    ret

print_decimal:
    pusha
    mov bx, 10
    xor cx, cx
    mov [.temp], ax
    
    mov ax, [.temp]
.decimal_divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .decimal_divide
    
.decimal_print:
    pop ax
    add al, '0'
    call print_char
    loop .decimal_print
    popa
    ret
.temp: dw 0

msg_welcome:
    db "PeaceDOS!!!!!!", 0x0D, 0x0A
    db "Chornoy pelenoy ikran zapolnil PeaceDOS!", 0x0D, 0x0A
    db "Copyright (C) ACYC", 0x0D, 0x0A
    db "Type HELP for command list", 0x0D, 0x0A, 0

prompt: db "Z:\>", 0

cmd_help: db "HELP", 0
cmd_ver: db "VER", 0
cmd_dir: db "DIR", 0
cmd_cls: db "CLS", 0
cmd_time: db "TIME", 0
cmd_date: db "DATE", 0
cmd_mem: db "MEM", 0
cmd_vol: db "VOL", 0

msg_unknown_cmd: db "Bad command or file name", 0x0D, 0x0A, 0
msg_help:
    db "Available commands:", 0x0D, 0x0A
    db "HELP    - This help message", 0x0D, 0x0A
    db "VER     - Show version", 0x0D, 0x0A
    db "DIR     - List files", 0x0D, 0x0A
    db "CLS     - Clear screen", 0x0D, 0x0A
    db "TIME    - Show time", 0x0D, 0x0A
    db "DATE    - Show date", 0x0D, 0x0A
    db "MEM     - Memory info", 0x0D, 0x0A
    db "VOL     - Volume info", 0x0D, 0x0A, 0
msg_version: 
    db "PeaceDOS", 0x0D, 0x0A
    db "REALLY Full DOS-compatible Operating System", 0x0D, 0x0A, 0
msg_dir_header: 
    db " Volume in drive Z is PEACEDOS", 0x0D, 0x0A
    db " Directory of Z:\", 0x0D, 0x0A, 0
msg_time: db "Current time: ", 0
msg_date: db "Current date: ", 0
msg_time_error: db "Time not available", 0x0D, 0x0A, 0
msg_date_error: db "Date not available", 0x0D, 0x0A, 0
msg_mem: db "Memory Information:", 0x0D, 0x0A, 0
msg_mem_base: db "Conventional memory: ", 0
msg_mem_ext: db "Extended memory: ", 0
msg_kb: db " KB", 0x0D, 0x0A, 0
msg_vol: db " Volume in drive A is PEACEDOS", 0x0D, 0x0A, 0

file_list:
    db "AUTOEXEC BAT      256 2000-01-01", 0x0D, 0x0A
    db "CONFIG   SYS      128 2000-01-01", 0x0D, 0x0A
    db "COMMAND  COM     1024 2000-01-01", 0x0D, 0x0A
    db "TEST     EXE      512 2000-01-01", 0x0D, 0x0A
    db "        4 file(s)     1920 bytes", 0x0D, 0x0A
    db "              1,457,664 bytes free", 0x0D, 0x0A, 0

command_buffer: times 256 db 0

times 1474560 - ($-$$) db 0
