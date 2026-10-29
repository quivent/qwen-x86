# Native user-initiated external editor. No helper runtime or implementation
# subprocess: /bin/sh interprets only the user's VISUAL/EDITOR command.
# Original useTextBuffer keeps trailing newlines and normalizes CRLF/CR to LF.
.include "abi.inc"
.section .rodata
.Le_visual: .asciz "VISUAL="
.Le_editor: .asciz "EDITOR="
.Le_vi: .asciz "vi"
.Le_shell: .asciz "/bin/sh"
.Le_dashc: .asciz "-c"
.Le_name: .asciz "qwen-editor"
.Le_tail: .asciz " \"$1\""
.Le_hex: .ascii "0123456789abcdef"
.Le_prefix: .ascii "/tmp/qwen-edit-"
.equ E_PREFIX,15
.Le_extension: .asciz ".txt"
.Le_ignore: .quad 1,0,0,0
.Le_default: .quad 0,0,0,0
.section .bss
.balign 16
.Le_raw: .skip 8
.Le_len: .skip 8
.Le_out: .skip 8
.Le_cap: .skip 8
.Le_env: .skip 8
.Le_fd: .skip 8
.Le_pid: .skip 8
.Le_created: .skip 8
.Le_sigstate: .skip 8
.Le_status: .skip 8
.Le_result: .skip 8
.Le_readlen: .skip 8
.Le_oldint: .skip 32
.Le_oldquit: .skip 32
.Le_stat: .skip 144
.Le_random: .skip 16
.Le_path: .skip 80
.Le_command: .skip 8208
.Le_argv: .skip 48
.Le_bytes: .skip 65536
.Le_normalized: .skip 65536
.Le_quote: .skip 393218
.text
.global ui_external_edit
.type ui_external_edit,@function
ui_external_edit:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov [rip+.Le_raw],rdi
 mov [rip+.Le_len],rsi
 mov [rip+.Le_out],rdx
 mov [rip+.Le_cap],rcx
 mov [rip+.Le_env],r8
 mov qword ptr [rip+.Le_fd],-1
 mov qword ptr [rip+.Le_created],0
 mov qword ptr [rip+.Le_sigstate],0
 mov qword ptr [rip+.Le_result],-22
 test rdi,rdi
 jz .Le_finish
 test rdx,rdx
 jz .Le_finish
 test rcx,rcx
 jz .Le_finish
 test r8,r8
 jz .Le_finish
 cmp rsi,65535
 ja .Le_finish
 # Validate initial UTF-8 before creating anything. NUL is not valid UI input.
 mov rcx,rsi
 mov rsi,rdi
 call .Le_check_nul
 test eax,eax
 jnz .Le_finish
 lea rdi,[rip+.Le_quote]
 mov rsi,[rip+.Le_raw]
 mov rdx,[rip+.Le_len]
 mov ecx,393218
 call json_quote
 test rax,rax
 js .Le_finish
 # Prefer the first nonempty configured editor; inherit the exact environment.
 lea rsi,[rip+.Le_visual]
 call .Le_getenv
 test rax,rax
 jz .Le_try_editor
 cmp byte ptr [rax],0
 jne .Le_command_found
.Le_try_editor:
 lea rsi,[rip+.Le_editor]
 call .Le_getenv
 test rax,rax
 jz .Le_default_editor
 cmp byte ptr [rax],0
 jne .Le_command_found
.Le_default_editor:
 lea rax,[rip+.Le_vi]
.Le_command_found:
 mov rsi,rax
 lea rdi,[rip+.Le_command]
 xor ecx,ecx
.Le_command_copy:
 cmp ecx,8192
 jae .Le_finish
 lodsb
 test al,al
 jz .Le_command_tail
 stosb
 inc ecx
 jmp .Le_command_copy
.Le_command_tail:
 lea rsi,[rip+.Le_tail]
.Le_tail_copy:
 lodsb
 stosb
 test al,al
 jnz .Le_tail_copy
 mov ebp,16
.Le_random_path:
 xor ebx,ebx
.Le_random_more:
 mov eax,318
 lea rdi,[rip+.Le_random]
 add rdi,rbx
 mov esi,16
 sub rsi,rbx
 xor edx,edx
 syscall
 cmp rax,-4
 je .Le_random_more
 test rax,rax
 jle .Le_record_failure
 add rbx,rax
 cmp ebx,16
 jb .Le_random_more
 lea rdi,[rip+.Le_path]
 lea rsi,[rip+.Le_prefix]
 mov ecx,E_PREFIX
 rep movsb
 lea rsi,[rip+.Le_random]
 lea rdx,[rip+.Le_hex]
 mov ecx,16
.Le_hex_loop:
 movzx eax,byte ptr [rsi]
 inc rsi
 mov ebx,eax
 shr eax,4
 and ebx,15
 mov al,[rdx+rax]
 stosb
 mov al,[rdx+rbx]
 stosb
 loop .Le_hex_loop
 lea rsi,[rip+.Le_extension]
 mov ecx,5
 rep movsb
 mov eax,2
 lea rdi,[rip+.Le_path]
 mov esi,0xa00c2
 mov edx,0600
 syscall
 cmp rax,-17
 jne .Le_created_check
 dec ebp
 jnz .Le_random_path
.Le_created_check:
 test rax,rax
 js .Le_record_failure
 mov [rip+.Le_fd],rax
 mov qword ptr [rip+.Le_created],1
 mov rdi,rax
 mov eax,91
 mov esi,0600
 syscall
 test rax,rax
 js .Le_record_failure
 mov r12,[rip+.Le_raw]
 mov r13,[rip+.Le_len]
.Le_write:
 test r13,r13
 jz .Le_fsync
 mov eax,1
 mov rdi,[rip+.Le_fd]
 mov rsi,r12
 mov rdx,r13
 syscall
 cmp rax,-4
 je .Le_write
 test rax,rax
 jle .Le_record_failure
 add r12,rax
 sub r13,rax
 jmp .Le_write
.Le_fsync:
 mov eax,74
 mov rdi,[rip+.Le_fd]
 syscall
 cmp rax,-4
 je .Le_fsync
 test rax,rax
 js .Le_record_failure
 call .Le_close_fd
 # Parent ignores interactive editor signals only while its child owns the tty.
 mov eax,13
 mov edi,2
 lea rsi,[rip+.Le_ignore]
 lea rdx,[rip+.Le_oldint]
 mov r10d,8
 syscall
 test rax,rax
 js .Le_record_failure
 mov qword ptr [rip+.Le_sigstate],1
 mov eax,13
 mov edi,3
 lea rsi,[rip+.Le_ignore]
 lea rdx,[rip+.Le_oldquit]
 mov r10d,8
 syscall
 test rax,rax
 js .Le_record_failure
 mov qword ptr [rip+.Le_sigstate],2
 mov eax,57
 syscall
 test rax,rax
 js .Le_record_failure
 jz .Le_child
 mov [rip+.Le_pid],rax
.Le_wait:
 mov eax,61
 mov rdi,[rip+.Le_pid]
 lea rsi,[rip+.Le_status]
 xor edx,edx
 xor r10d,r10d
 syscall
 cmp rax,-4
 je .Le_wait
 test rax,rax
 js .Le_record_failure
 call .Le_restore_signals
 cmp dword ptr [rip+.Le_status],0
 jne .Le_child_failed
 # Reopen the editor's resulting file. Atomic editor replacement is supported.
 mov eax,2
 lea rdi,[rip+.Le_path]
 mov esi,0xa0800
 xor edx,edx
 syscall
 test rax,rax
 js .Le_record_failure
 mov [rip+.Le_fd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Le_stat]
 syscall
 test rax,rax
 js .Le_record_failure
 mov eax,[rip+.Le_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Le_finish
 mov eax,107
 syscall
 cmp eax,[rip+.Le_stat+28]
 jne .Le_finish
 cmp qword ptr [rip+.Le_stat+48],65535
 ja .Le_too_large
 mov qword ptr [rip+.Le_readlen],0
.Le_read:
 mov eax,0
 mov rdi,[rip+.Le_fd]
 lea rsi,[rip+.Le_bytes]
 add rsi,[rip+.Le_readlen]
 mov edx,65536
 sub rdx,[rip+.Le_readlen]
 jz .Le_too_large
 syscall
 cmp rax,-4
 je .Le_read
 test rax,rax
 js .Le_record_failure
 jz .Le_validate
 add [rip+.Le_readlen],rax
 jmp .Le_read
.Le_validate:
 cmp qword ptr [rip+.Le_readlen],65535
 ja .Le_too_large
 lea rsi,[rip+.Le_bytes]
 mov rcx,[rip+.Le_readlen]
 call .Le_check_nul
 test eax,eax
 jnz .Le_finish
 lea rdi,[rip+.Le_quote]
 lea rsi,[rip+.Le_bytes]
 mov rdx,[rip+.Le_readlen]
 mov ecx,393218
 call json_quote
 test rax,rax
 js .Le_finish
 # Normalize CRLF and bare CR only. Preserve all trailing LF characters.
 lea rsi,[rip+.Le_bytes]
 lea rdi,[rip+.Le_normalized]
 mov rcx,[rip+.Le_readlen]
 xor ebx,ebx
.Le_normalize:
 test rcx,rcx
 jz .Le_normalize_done
 lodsb
 dec rcx
 cmp al,13
 jne .Le_store
 mov al,10
 test rcx,rcx
 jz .Le_store
 cmp byte ptr [rsi],10
 jne .Le_store
 inc rsi
 dec rcx
.Le_store:
 stosb
 inc rbx
 jmp .Le_normalize
.Le_normalize_done:
 cmp rbx,[rip+.Le_cap]
 jae .Le_too_large
 mov rdi,[rip+.Le_out]
 lea rsi,[rip+.Le_normalized]
 mov rcx,rbx
 rep movsb
 mov byte ptr [rdi],0
 mov [rip+.Le_result],rbx
 jmp .Le_finish
.Le_child_failed:
 mov qword ptr [rip+.Le_result],-125
 jmp .Le_finish
.Le_too_large:
 mov qword ptr [rip+.Le_result],-28
 jmp .Le_finish
.Le_record_failure:
 test rax,rax
 js .Le_store_failure
 mov rax,-5
.Le_store_failure:
 mov [rip+.Le_result],rax
.Le_finish:
 call .Le_close_fd
 call .Le_restore_signals
 cmp qword ptr [rip+.Le_created],0
 je .Le_return
.Le_unlink_retry:
 mov eax,87
 lea rdi,[rip+.Le_path]
 syscall
 cmp rax,-4
 je .Le_unlink_retry
.Le_return:
 mov rax,[rip+.Le_result]
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.Le_child:
 mov eax,13
 mov edi,2
 lea rsi,[rip+.Le_default]
 xor edx,edx
 mov r10d,8
 syscall
 mov eax,13
 mov edi,3
 lea rsi,[rip+.Le_default]
 xor edx,edx
 mov r10d,8
 syscall
 lea rdi,[rip+.Le_argv]
 lea rax,[rip+.Le_shell]
 mov [rdi],rax
 lea rax,[rip+.Le_dashc]
 mov [rdi+8],rax
 lea rax,[rip+.Le_command]
 mov [rdi+16],rax
 lea rax,[rip+.Le_name]
 mov [rdi+24],rax
 lea rax,[rip+.Le_path]
 mov [rdi+32],rax
 mov qword ptr [rdi+40],0
 mov eax,59
 lea rdi,[rip+.Le_shell]
 lea rsi,[rip+.Le_argv]
 mov rdx,[rip+.Le_env]
 syscall
 mov eax,60
 mov edi,127
 syscall
 ud2
.Le_close_fd:
 mov rdi,[rip+.Le_fd]
 test rdi,rdi
 js .Le_close_done
 mov eax,3
 syscall
 mov qword ptr [rip+.Le_fd],-1
.Le_close_done:
 ret
.Le_restore_signals:
 cmp qword ptr [rip+.Le_sigstate],2
 jb .Le_restore_int
 mov eax,13
 mov edi,3
 lea rsi,[rip+.Le_oldquit]
 xor edx,edx
 mov r10d,8
 syscall
.Le_restore_int:
 cmp qword ptr [rip+.Le_sigstate],1
 jb .Le_restored
 mov eax,13
 mov edi,2
 lea rsi,[rip+.Le_oldint]
 xor edx,edx
 mov r10d,8
 syscall
 mov qword ptr [rip+.Le_sigstate],0
.Le_restored:
 ret
# Find exact KEY= prefix in the supplied unchanged environment.
.Le_getenv:
 mov r8,[rip+.Le_env]
.Le_env_loop:
 mov rdi,[r8]
 test rdi,rdi
 jz .Le_env_missing
 mov r9,rsi
.Le_env_compare:
 mov al,[r9]
 test al,al
 jz .Le_env_found
 cmp al,[rdi]
 jne .Le_env_next
 inc r9
 inc rdi
 jmp .Le_env_compare
.Le_env_next:
 add r8,8
 jmp .Le_env_loop
.Le_env_found:
 mov rax,rdi
 ret
.Le_env_missing:
 xor eax,eax
 ret
.Le_check_nul:
 xor eax,eax
 test rcx,rcx
 jz .Le_nul_done
.Le_nul_loop:
 cmp byte ptr [rsi],0
 je .Le_nul_bad
 inc rsi
 dec rcx
 jnz .Le_nul_loop
.Le_nul_done:
 ret
.Le_nul_bad:
 mov eax,1
 ret
.section .note.GNU-stack,"",@progbits
