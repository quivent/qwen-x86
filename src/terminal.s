# Linux x86-64 terminal input and output.
# A byte selects a bound state-table row; acquisition, transition and output are
# separate chains. Unknown stream extent and syscall error routes remain checked.
.intel_syntax noprefix
.equ SYS_READ, 0
.equ SYS_WRITE, 1
.equ SYS_POLL, 7
.equ SYS_RT_SIGACTION, 13
.equ SYS_IOCTL, 16
.equ TCGETS, 0x5401
.equ TCSETS, 0x5402
.equ TERMIOS_BYTES, 36
.equ OUTPUT_BYTES, 4096

.section .bss
.balign 8
.Lterm_saved: .skip TERMIOS_BYTES
.Lterm_raw: .skip TERMIOS_BYTES
.Lterm_active: .skip 1
.Lterm_pipe_ignored: .skip 1
.Lterm_filter_state: .skip 1
.Lterm_utf8_state: .skip 1
.Lterm_skip_lf: .skip 1
.Lterm_output: .skip OUTPUT_BYTES+2

.section .rodata
.balign 8
.Lpipe_ignore: .quad 1, 0, 0, 0
.Lbanner_color: .ascii "\033[1;36mQWEN x86\033[0m  native x86-64 · Linux syscalls\n"
.set .Lbanner_color_len, .-.Lbanner_color
.Lbanner_plain: .ascii "QWEN x86  native x86-64 · Linux syscalls\n"
.set .Lbanner_plain_len, .-.Lbanner_plain
.Lmodel_label: .ascii "Model: "
.set .Lmodel_label_len, .-.Lmodel_label
.Lcwd_label: .ascii "  ·  Workspace: "
.set .Lcwd_label_len, .-.Lcwd_label
.Lnewline: .ascii "\n"
.Lcancel_echo: .ascii "^C\n"
.Lerase_one: .ascii "\b \b"
.Lstatus_prefix: .ascii "\n· "
.Lapproval_prompt: .ascii "Allow this action? [y/N] "
.set .Lapproval_prompt_len, .-.Lapproval_prompt

# Descriptor bits 0..2: next state; bit 7: emit this byte. The byte is
# speculatively stored to a mapped sink; only the descriptor advances output.
# States: text, ESC, CSI, OSC, OSC-ESC, DCS/SOS/PM/APC, string-ESC, ESC-intermediate.
.balign 16
.Lfilter_table:
.set state, 0
.rept 8
 .set byte_value, 0
 .rept 256
  .set descriptor, 0
  .if state == 0
   .if byte_value == 27
    .set descriptor, 1
   .elseif byte_value == 9 || byte_value == 10 || byte_value >= 32 && byte_value != 127
    .set descriptor, 128
   .endif
  .elseif state == 1
   .if byte_value == 91
    .set descriptor, 2
   .elseif byte_value == 93
    .set descriptor, 3
   .elseif byte_value == 80 || byte_value == 88 || byte_value == 94 || byte_value == 95
    .set descriptor, 5
   .elseif byte_value == 27
    .set descriptor, 1
   .elseif byte_value >= 32 && byte_value <= 47
    .set descriptor, 7
   .endif
  .elseif state == 2
   .set descriptor, 2
   .if byte_value >= 64 && byte_value <= 126
    .set descriptor, 0
   .elseif byte_value == 27
    .set descriptor, 1
   .endif
  .elseif state == 3
   .set descriptor, 3
   .if byte_value == 7
    .set descriptor, 0
   .elseif byte_value == 27
    .set descriptor, 4
   .endif
  .elseif state == 4
   .set descriptor, 3
   .if byte_value == 92
    .set descriptor, 0
   .elseif byte_value == 27
    .set descriptor, 4
   .endif
  .elseif state == 5
   .set descriptor, 5
   .if byte_value == 27
    .set descriptor, 6
   .endif
  .elseif state == 6
   .set descriptor, 5
   .if byte_value == 92
    .set descriptor, 0
   .elseif byte_value == 27
    .set descriptor, 6
   .endif
  .elseif state == 7
   .set descriptor, 7
   .if byte_value >= 48 && byte_value <= 126
    .set descriptor, 0
   .elseif byte_value == 27
    .set descriptor, 1
   .endif
  .endif
  .byte descriptor
  .set byte_value, byte_value+1
 .endr
 .set state, state+1
.endr

.section .text

# stdout writer; rdi bytes, rsi length. All short writes and EINTR are drained.
# Caller-saved registers only. A zero-progress write is an I/O error.
.Lraw_write:
 mov r8, rdi
 mov r9, rsi
 xor r10d, r10d
.Lraw_write_next:
 test r9, r9
 jz .Lraw_write_done
 mov eax, SYS_WRITE
 mov edi, 1
 mov rsi, r8
 mov rdx, r9
 syscall
 cmp rax, -4
 je .Lraw_write_next
 test rax, rax
 js .Lraw_write_return
 jz .Lraw_write_zero
 add r8, rax
 sub r9, rax
 add r10, rax
 jmp .Lraw_write_next
.Lraw_write_zero:
 mov rax, -5
 ret
.Lraw_write_done:
 mov rax, r10
.Lraw_write_return:
 ret

# SIGPIPE must not terminate the process before write can return -EPIPE.
.Lignore_pipe:
 cmp byte ptr [rip+.Lterm_pipe_ignored], 0
 jne .Lignore_pipe_done
 mov eax, SYS_RT_SIGACTION
 mov edi, 13
 lea rsi, [rip+.Lpipe_ignore]
 xor edx, edx
 mov r10d, 8
 syscall
 test rax, rax
 jne .Lignore_pipe_done
 mov byte ptr [rip+.Lterm_pipe_ignored], 1
.Lignore_pipe_done:
 ret

.globl term_init
.type term_init,@function
term_init:
 push rbx
 call .Lignore_pipe
 cmp byte ptr [rip+.Lterm_active], 0
 jne .Lterm_init_ok
.Lterm_get:
 mov eax, SYS_IOCTL
 xor edi, edi
 mov esi, TCGETS
 lea rdx, [rip+.Lterm_saved]
 syscall
 cmp rax, -4
 je .Lterm_get
 test rax, rax
 js .Lterm_init_return
 # Fixed-size termios cartography is copied without data-dependent routing.
 mov rax, qword ptr [rip+.Lterm_saved]
 mov qword ptr [rip+.Lterm_raw], rax
 mov rax, qword ptr [rip+.Lterm_saved+8]
 mov qword ptr [rip+.Lterm_raw+8], rax
 mov rax, qword ptr [rip+.Lterm_saved+16]
 mov qword ptr [rip+.Lterm_raw+16], rax
 mov rax, qword ptr [rip+.Lterm_saved+24]
 mov qword ptr [rip+.Lterm_raw+24], rax
 mov eax, dword ptr [rip+.Lterm_saved+32]
 mov dword ptr [rip+.Lterm_raw+32], eax
 and dword ptr [rip+.Lterm_raw], -1516    # input: no CR translation, flow control, stripping
 # Keep output postprocessing, so kernel ONLCR preserves ordinary LF rendering.
 and dword ptr [rip+.Lterm_raw+8], -305
 or dword ptr [rip+.Lterm_raw+8], 48     # CS8, no parity
 and dword ptr [rip+.Lterm_raw+12], -32844 # ECHO/ECHONL/ICANON/ISIG/IEXTEN off
 mov byte ptr [rip+.Lterm_raw+22], 0    # VTIME
 mov byte ptr [rip+.Lterm_raw+23], 1    # VMIN
.Lterm_set:
 mov eax, SYS_IOCTL
 xor edi, edi
 mov esi, TCSETS
 lea rdx, [rip+.Lterm_raw]
 syscall
 cmp rax, -4
 je .Lterm_set
 test rax, rax
 js .Lterm_init_return
 mov byte ptr [rip+.Lterm_active], 1
.Lterm_init_ok:
 xor eax, eax
.Lterm_init_return:
 pop rbx
 ret
.size term_init,.-term_init

.globl term_restore
.type term_restore,@function
term_restore:
 cmp byte ptr [rip+.Lterm_active], 0
 je .Lrestore_done
.Lrestore_retry:
 mov eax, SYS_IOCTL
 xor edi, edi
 mov esi, TCSETS
 lea rdx, [rip+.Lterm_saved]
 syscall
 cmp rax, -4
 je .Lrestore_retry
 test rax, rax
 js .Lrestore_done
 mov byte ptr [rip+.Lterm_active], 0
.Lrestore_done:
 ret
.size term_restore,.-term_restore

.globl term_write
.type term_write,@function
term_write:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 xor r15d,r15d
 movzx ebx,byte ptr [rip+.Lterm_filter_state]
 movzx ebp,byte ptr [rip+.Lterm_utf8_state]
 call .Lignore_pipe
.Lfilter_next:
 test r13,r13
 jz .Lfilter_finish
 movzx r9d,byte ptr [r12]
 test ebx,ebx
 jnz .Lfilter_ansi_byte
 mov ecx,ebp
 shl ecx,8
 add ecx,r9d
 lea rdx,[rip+.Lterm_utf8_table]
 movzx edx,byte ptr [rdx+rcx]
 mov ebp,edx
 and ebp,7
 test edx,128
 jnz .Lfilter_utf8_pair
 test edx,64
 jz .Lfilter_advance
.Lfilter_ansi_byte:
 mov eax,r9d
 shl ebx,8
 add ebx,eax
 lea rdx,[rip+.Lfilter_table]
 movzx ebx,byte ptr [rdx+rbx]
 lea rdx,[rip+.Lterm_output]
 mov byte ptr [rdx+r14],al
 mov eax,ebx
 shr eax,7
 add r14,rax
 and ebx,7
 jmp .Lfilter_advance
.Lfilter_utf8_pair:
 lea rdx,[rip+.Lterm_output]
 mov eax,r9d
 shl eax,8
 or eax,194
 mov word ptr [rdx+r14],ax
 add r14,2
.Lfilter_advance:
 inc r12
 dec r13
 cmp r14,OUTPUT_BYTES
 jb .Lfilter_next
 lea rdi,[rip+.Lterm_output]
 mov rsi,r14
 call .Lraw_write
 test rax,rax
 js .Lfilter_return
 add r15,rax
 xor r14d,r14d
 jmp .Lfilter_next
.Lfilter_finish:
 lea rdi,[rip+.Lterm_output]
 mov rsi,r14
 call .Lraw_write
 test rax,rax
 js .Lfilter_return
 add rax,r15
.Lfilter_return:
 mov byte ptr [rip+.Lterm_filter_state],bl
 mov byte ptr [rip+.Lterm_utf8_state],bpl
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.size term_write,.-term_write

# rdi zero-terminated string -> rax count (private, does not consume the pointer).
.Lzlen:
 xor eax, eax
.Lzlen_next:
 cmp byte ptr [rdi+rax], 0
 je .Lzlen_done
 inc rax
 cmp rax,65536
 jb .Lzlen_next
.Lzlen_done:
 ret

.globl term_banner
.type term_banner,@function
term_banner:
 push rbx
 push r12
 push r13
 mov r12, rdi
 mov r13, rsi
 call term_reset_filter
 lea rdi, [rip+.Lbanner_plain]
 mov esi, .Lbanner_plain_len
 cmp byte ptr [rip+.Lterm_active], 0
 je .Lbanner_selected
 lea rdi, [rip+.Lbanner_color]
 mov esi, .Lbanner_color_len
.Lbanner_selected:
 call .Lraw_write
 lea rdi, [rip+.Lmodel_label]
 mov esi, .Lmodel_label_len
 call .Lraw_write
 mov rdi, r12
 call .Lzlen
 mov rsi, rax
 call term_write
 call term_reset_filter
 lea rdi, [rip+.Lcwd_label]
 mov esi, .Lcwd_label_len
 call .Lraw_write
 mov rdi, r13
 call .Lzlen
 mov rsi, rax
 call term_write
 call term_reset_filter
 lea rdi, [rip+.Lnewline]
 mov esi, 1
 call .Lraw_write
 pop r13
 pop r12
 pop rbx
 ret
.size term_banner,.-term_banner

.globl term_status
.type term_status,@function
term_status:
 push rbx
 mov rbx, rdi
 call term_reset_filter
 lea rdi, [rip+.Lstatus_prefix]
 mov esi, 4
 call .Lraw_write
 mov rdi, rbx
 call .Lzlen
 mov rsi, rax
 call term_write
 call term_reset_filter
 lea rdi, [rip+.Lnewline]
 mov esi, 1
 call .Lraw_write
 pop rbx
 ret
.size term_status,.-term_status

.globl term_readline
.type term_readline,@function
term_readline:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp, 24
 mov r12, rdi
 mov r13, rsi
 xor r14d, r14d
 mov qword ptr [rsp+16], 0
 movzx r15d, byte ptr [rip+.Lterm_active]
 test r13, r13
 jz .Lread_invalid
 mov byte ptr [r12], 0
 dec r13
.Lread_next:
 mov eax, SYS_READ
 xor edi, edi
 mov rsi, rsp
 mov edx, 1
 syscall
 cmp rax, -4
 je .Lread_next
 test rax, rax
 js .Lread_finish
 jz .Lread_eof
 movzx ebx, byte ptr [rsp]
 cmp byte ptr [rip+.Lterm_skip_lf], 0
 je .Lread_route
 mov byte ptr [rip+.Lterm_skip_lf], 0
 cmp bl, 10
 je .Lread_next
.Lread_route:
 cmp qword ptr [rsp+16],0
 je .Lread_dispatch
 mov eax,ebx
 and eax,192
 cmp eax,128
 jne .Lread_drop_skip
 dec qword ptr [rsp+16]
 jmp .Lread_next
.Lread_drop_skip:
 mov qword ptr [rsp+16],0
.Lread_dispatch:
 lea rax, [rip+.Linput_routes]
 jmp qword ptr [rax+rbx*8]
.Lread_normal:
 cmp r14, r13
 jae .Lread_next
 lea rax,[rip+.Lutf8_lengths]
 movzx edx,byte ptr [rax+rbx]
 mov rax,r13
 sub rax,r14
 cmp rax,rdx
 jb .Lread_utf8_no_room
 mov byte ptr [r12+r14], bl
 inc r14
 test r15, r15
 jz .Lread_next
 mov byte ptr [rsp], bl
 lea rdi, [rsp]
 mov esi, 1
 call .Lraw_write
 test rax, rax
 js .Lread_finish
 jmp .Lread_next
.Lread_utf8_no_room:
 dec rdx
 mov qword ptr [rsp+16],rdx
 jmp .Lread_next
.Lread_backspace:
 test r14, r14
 jz .Lread_next
 dec r14
.Lread_back_continuation:
 test r14, r14
 jz .Lread_back_echo
 movzx eax, byte ptr [r12+r14]
 and eax, 192
 cmp eax, 128
 jne .Lread_back_echo
 dec r14
 jmp .Lread_back_continuation
.Lread_back_echo:
 test r15, r15
 jz .Lread_next
 lea rdi, [rip+.Lerase_one]
 mov esi, 3
 call .Lraw_write
 test rax, rax
 js .Lread_finish
 jmp .Lread_next
.Lread_enter:
 cmp bl, 13
 sete byte ptr [rip+.Lterm_skip_lf]
 test r15, r15
 jz .Lread_success
 lea rdi, [rip+.Lnewline]
 mov esi, 1
 call .Lraw_write
 test rax, rax
 js .Lread_finish
.Lread_success:
 mov rax, r14
 jmp .Lread_finish
.Lread_cancel:
 xor r14d, r14d
 test r15, r15
 jz .Lread_cancel_code
 lea rdi, [rip+.Lcancel_echo]
 mov esi, 3
 call .Lraw_write
.Lread_cancel_code:
 mov rax, -2
 jmp .Lread_finish
.Lread_eof:
 mov rax, r14
 test r14, r14
 jnz .Lread_finish
 mov rax, -1
 jmp .Lread_finish
.Lread_escape:
 # ESC alone is discarded after a short bounded wait. Known CSI/SS3 key
 # sequences are consumed, not inserted as text. Alt+Enter adds a newline.
 mov rax, 0x0000000100000000
 mov qword ptr [rsp+8], rax
 mov eax, SYS_POLL
 lea rdi, [rsp+8]
 mov esi, 1
 mov edx, 30
 syscall
 test rax, rax
 jle .Lread_next
.Lread_escape_byte:
 mov eax, SYS_READ
 xor edi, edi
 mov rsi, rsp
 mov edx, 1
 syscall
 cmp rax, -4
 je .Lread_escape_byte
 test rax, rax
 js .Lread_finish
 jz .Lread_eof
 movzx ebx, byte ptr [rsp]
 cmp bl, 13
 je .Lread_alt_enter
 cmp bl, 10
 je .Lread_alt_enter
 cmp bl, 91
 je .Lread_escape_sequence
 cmp bl, 79
 jne .Lread_next
.Lread_escape_sequence:
 mov ebp, 64
.Lread_sequence_next:
 mov rax, 0x0000000100000000
 mov qword ptr [rsp+8], rax
 mov eax, SYS_POLL
 lea rdi, [rsp+8]
 mov esi, 1
 mov edx, 30
 syscall
 test rax, rax
 jle .Lread_next
.Lread_sequence_byte:
 mov eax, SYS_READ
 xor edi, edi
 mov rsi, rsp
 mov edx, 1
 syscall
 cmp rax, -4
 je .Lread_sequence_byte
 test rax, rax
 js .Lread_finish
 jz .Lread_eof
 movzx ebx, byte ptr [rsp]
 cmp bl, 64
 jb .Lread_sequence_count
 cmp bl, 126
 jbe .Lread_next
.Lread_sequence_count:
 dec ebp
 jnz .Lread_sequence_next
 jmp .Lread_next
.Lread_alt_enter:
 mov ebx, 10
 jmp .Lread_normal
.Lread_invalid:
 mov rax, -22
 jmp .Lread_return
.Lread_finish:
 mov byte ptr [r12+r14], 0
.Lread_return:
 add rsp, 24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.size term_readline,.-term_readline

.globl term_approve
.type term_approve,@function
term_approve:
 push rbp
 mov rbp, rsp
 sub rsp, 16
 call term_status
 lea rdi, [rip+.Lapproval_prompt]
 mov esi, .Lapproval_prompt_len
 call .Lraw_write
 lea rdi, [rsp]
 mov esi, 16
 call term_readline
 cmp rax, 1
 sete dl
 movzx eax, byte ptr [rsp]
 and eax, 223
 cmp eax, 89
 sete al
 and al, dl
 movzx eax, al
 leave
 ret
.size term_approve,.-term_approve

.section .rodata
.balign 8
.Linput_routes:
.set input_byte, 0
.rept 256
 .if input_byte == 3
  .quad .Lread_cancel
 .elseif input_byte == 4
  .quad .Lread_eof
 .elseif input_byte == 8 || input_byte == 127
  .quad .Lread_backspace
 .elseif input_byte == 10 || input_byte == 13
  .quad .Lread_enter
 .elseif input_byte == 27
  .quad .Lread_escape
 .elseif input_byte == 9 || input_byte >= 32 && input_byte != 127
  .quad .Lread_normal
 .else
  .quad .Lread_next
 .endif
 .set input_byte, input_byte+1
.endr
.Lutf8_lengths:
.set utf8_byte,0
.rept 256
 .if utf8_byte >=194 && utf8_byte <=223
  .byte 2
 .elseif utf8_byte >=224 && utf8_byte <=239
  .byte 3
 .elseif utf8_byte >=240 && utf8_byte <=244
  .byte 4
 .else
  .byte 1
 .endif
 .set utf8_byte,utf8_byte+1
.endr

# Explicit message/trusted-prompt boundary. Never reset between model chunks.
.section .text
.globl term_reset_filter
.type term_reset_filter,@function
term_reset_filter:
 mov byte ptr [rip+.Lterm_filter_state],0
 mov byte ptr [rip+.Lterm_utf8_state],0
 xor eax,eax
 ret
.size term_reset_filter,.-term_reset_filter

.section .rodata
# UTF8state0ground,1..3continuations,4delayedC2. Actions64emitcurrentbyte,
#128emitdelayedC2+currentbyte;0omit. StripC280..9FwithoutmanglingvalidUTF8.
.Lterm_utf8_table:
.set utfstate,0
.rept 5
 .set utfbyte,0
 .rept 256
  .set utfdesc,0
  .if utfstate==4 && utfbyte>=128 && utfbyte<=159
   .set utfdesc,0
  .elseif utfstate==4 && utfbyte>=160 && utfbyte<=191
   .set utfdesc,128
  .elseif utfstate>=1 && utfstate<=3 && utfbyte>=128 && utfbyte<=191
   .set utfdesc,64+utfstate-1
  .elseif utfbyte<=127
   .set utfdesc,64
  .elseif utfbyte==194
   .set utfdesc,4
  .elseif utfbyte>=195 && utfbyte<=223
   .set utfdesc,65
  .elseif utfbyte>=224 && utfbyte<=239
   .set utfdesc,66
  .elseif utfbyte>=240 && utfbyte<=244
   .set utfdesc,67
  .endif
  .byte utfdesc
  .set utfbyte,utfbyte+1
 .endr
 .set utfstate,utfstate+1
.endr

.section .note.GNU-stack,"",@progbits

.text
.global term_ignore_pipe
term_ignore_pipe:
 jmp .Lignore_pipe
