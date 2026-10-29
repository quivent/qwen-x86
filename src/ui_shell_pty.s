# User-invoked interactive shell: real Linux PTY, controlling terminal, no
# implementation helper runtime. Caller leaves UI before entering this backend.
.include "abi.inc"
.section .rodata
.Sp_ptmx: .asciz "/dev/ptmx"
.Sp_pts: .ascii "/dev/pts/"
.Sp_shell: .asciz "/bin/sh"
.Sp_dashc: .asciz "-c"
.Sp_ignore: .quad 1,0,0,0
.Sp_default: .quad 0,0,0,0
.section .bss
.balign 16
.Sp_master: .skip 8
.Sp_slave: .skip 8
.Sp_pid: .skip 8
.Sp_parent: .skip 8
.Sp_cwd: .skip 8
.Sp_env: .skip 8
.Sp_out: .skip 8
.Sp_cap: .skip 8
.Sp_len: .skip 8
.Sp_result: .skip 8
.Sp_exit: .skip 8
.Sp_cancel: .skip 8
.Sp_state: .skip 8
.Sp_reaped: .skip 8
.Sp_status: .skip 8
.Sp_number: .skip 8
.Sp_poll: .skip 16
.Sp_saved: .skip 40
.Sp_raw: .skip 40
.Sp_win: .skip 8
.Sp_oldint: .skip 32
.Sp_oldquit: .skip 32
.Sp_path: .skip 64
.Sp_digits: .skip 32
.Sp_argv: .skip 32
.Sp_command: .skip 65536
.Sp_buffer: .skip 8192
.section .text
.global ui_shell_execute_pty,ui_shell_pty_status,ui_shell_pty_cancelled
ui_shell_pty_status:
 mov rax,[rip+.Sp_exit]
 ret
ui_shell_pty_cancelled:
 mov rax,[rip+.Sp_cancel]
 ret
# cmd,len,cwdZ,envp,out,cap ->captured length or fatal error. Capture NUL-term.
ui_shell_execute_pty:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov qword ptr [rip+.Sp_master],-1
 mov qword ptr [rip+.Sp_slave],-1
 mov qword ptr [rip+.Sp_pid],-1
 mov qword ptr [rip+.Sp_state],0
 mov qword ptr [rip+.Sp_len],0
 mov qword ptr [rip+.Sp_cancel],0
 mov qword ptr [rip+.Sp_reaped],0
 mov qword ptr [rip+.Sp_exit],-1
 mov qword ptr [rip+.Sp_result],-22
 mov [rip+.Sp_cwd],rdx
 mov [rip+.Sp_env],rcx
 mov [rip+.Sp_out],r8
 mov [rip+.Sp_cap],r9
 test rdi,rdi
 jz .Sp_cleanup
 test rsi,rsi
 jz .Sp_cleanup
 cmp rsi,65535
 ja .Sp_cleanup
 test rdx,rdx
 jz .Sp_cleanup
 test rcx,rcx
 jz .Sp_cleanup
 test r8,r8
 jz .Sp_cleanup
 test r9,r9
 jz .Sp_cleanup
 mov rcx,rsi
 mov rsi,rdi
 lea rdi,[rip+.Sp_command]
 xor eax,eax
.Sp_copy_command:
 lodsb
 test al,al
 jz .Sp_cleanup
 stosb
 loop .Sp_copy_command
 mov byte ptr [rdi],0
 mov eax,16
 xor edi,edi
 mov esi,0x5401
 lea rdx,[rip+.Sp_saved]
 syscall
 test rax,rax
 js .Sp_error
 mov eax,16
 xor edi,edi
 mov esi,0x5413
 lea rdx,[rip+.Sp_win]
 syscall
 test rax,rax
 js .Sp_error
 mov eax,2
 lea rdi,[rip+.Sp_ptmx]
 mov esi,0x80902 # RDWR|NOCTTY|NONBLOCK|CLOEXEC
 xor edx,edx
 syscall
 test rax,rax
 js .Sp_error
 mov [rip+.Sp_master],rax
 mov qword ptr [rip+.Sp_number],0
 mov eax,16
 mov rdi,[rip+.Sp_master]
 mov esi,0x40045431 # TIOCSPTLCK unlock
 lea rdx,[rip+.Sp_number]
 syscall
 test rax,rax
 js .Sp_error
 mov eax,16
 mov rdi,[rip+.Sp_master]
 mov esi,0x80045430 # TIOCGPTN
 lea rdx,[rip+.Sp_number]
 syscall
 test rax,rax
 js .Sp_error
 lea rdi,[rip+.Sp_path]
 lea rsi,[rip+.Sp_pts]
 mov ecx,9
 rep movsb
 mov eax,[rip+.Sp_number]
 lea rsi,[rip+.Sp_digits+32]
 xor ecx,ecx
 mov r8d,10
.Sp_decimal:
 xor edx,edx
 div r8
 add dl,48
 dec rsi
 mov [rsi],dl
 inc ecx
 test rax,rax
 jnz .Sp_decimal
 rep movsb
 mov byte ptr [rdi],0
 mov eax,2
 lea rdi,[rip+.Sp_path]
 mov esi,0x80102 # RDWR|NOCTTY|CLOEXEC
 xor edx,edx
 syscall
 test rax,rax
 js .Sp_error
 mov [rip+.Sp_slave],rax
 mov rdi,rax
 mov eax,16
 mov esi,0x5402
 lea rdx,[rip+.Sp_saved]
 syscall
 test rax,rax
 js .Sp_error
 mov eax,16
 mov rdi,[rip+.Sp_slave]
 mov esi,0x5414
 lea rdx,[rip+.Sp_win]
 syscall
 test rax,rax
 js .Sp_error
 # Ignore parent signal dispositions only across this explicit interactive job.
 mov eax,13
 mov edi,2
 lea rsi,[rip+.Sp_ignore]
 lea rdx,[rip+.Sp_oldint]
 mov r10d,8
 syscall
 test rax,rax
 js .Sp_error
 mov qword ptr [rip+.Sp_state],1
 mov eax,13
 mov edi,3
 lea rsi,[rip+.Sp_ignore]
 lea rdx,[rip+.Sp_oldquit]
 mov r10d,8
 syscall
 test rax,rax
 js .Sp_error
 mov qword ptr [rip+.Sp_state],2
 mov eax,39
 syscall
 mov [rip+.Sp_parent],rax
 mov eax,57
 syscall
 test rax,rax
 js .Sp_error
 jz .Sp_child
 mov [rip+.Sp_pid],rax
 mov eax,3
 mov rdi,[rip+.Sp_slave]
 syscall
 mov qword ptr [rip+.Sp_slave],-1
 # Relay uses raw input; child has the caller's original cooked termios.
 lea rsi,[rip+.Sp_saved]
 lea rdi,[rip+.Sp_raw]
 mov ecx,36
 rep movsb
 and dword ptr [rip+.Sp_raw],-1516
 and dword ptr [rip+.Sp_raw+8],-305
 or dword ptr [rip+.Sp_raw+8],48
 and dword ptr [rip+.Sp_raw+12],-32844
 mov byte ptr [rip+.Sp_raw+22],0
 mov byte ptr [rip+.Sp_raw+23],1
 mov eax,16
 xor edi,edi
 mov esi,0x5402
 lea rdx,[rip+.Sp_raw]
 syscall
 test rax,rax
 js .Sp_error
 mov qword ptr [rip+.Sp_state],3
 mov eax,dword ptr [rip+.Sp_master]
 mov [rip+.Sp_poll],eax
 mov word ptr [rip+.Sp_poll+4],1
 mov dword ptr [rip+.Sp_poll+8],0
 mov word ptr [rip+.Sp_poll+12],1
.Sp_loop:
 call .Sp_wait
 cmp qword ptr [rip+.Sp_reaped],0
 jne .Sp_drain_final
 mov eax,7
 lea rdi,[rip+.Sp_poll]
 mov esi,2
 mov edx,100
 syscall
 cmp rax,-4
 je .Sp_loop
 test rax,rax
 js .Sp_error
 test word ptr [rip+.Sp_poll+6],0x19
 jnz .Sp_read_master
.Sp_input:
 test word ptr [rip+.Sp_poll+14],1
 jz .Sp_resize
 xor eax,eax
 xor edi,edi
 lea rsi,[rip+.Sp_buffer]
 mov edx,8192
 syscall
 cmp rax,-4
 je .Sp_loop
 test rax,rax
 jle .Sp_resize
 mov r12,rax
 xor ecx,ecx
 lea rsi,[rip+.Sp_buffer]
.Sp_input_cancel_scan:
 cmp rcx,r12
 jae .Sp_relay_input
 cmp byte ptr [rsi+rcx],3
 je .Sp_cancel_job
 inc rcx
 jmp .Sp_input_cancel_scan
.Sp_relay_input:
 mov rdi,[rip+.Sp_master]
 mov rdx,r12
 call .Sp_write_all
 test rax,rax
 js .Sp_error
.Sp_resize:
 mov eax,16
 xor edi,edi
 mov esi,0x5413
 lea rdx,[rip+.Sp_win]
 syscall
 mov eax,16
 mov rdi,[rip+.Sp_master]
 mov esi,0x5414
 lea rdx,[rip+.Sp_win]
 syscall
 jmp .Sp_loop
.Sp_read_master:
 call .Sp_read_output
 cmp rax,-11
 je .Sp_input
 cmp rax,-5
 je .Sp_output_eof
 test rax,rax
 js .Sp_error
 jz .Sp_output_eof
 jmp .Sp_input
.Sp_output_eof:
 call .Sp_wait
 cmp qword ptr [rip+.Sp_reaped],0
 je .Sp_loop
 jmp .Sp_done
.Sp_drain_final:
 call .Sp_read_output
 test rax,rax
 jg .Sp_drain_final
 jmp .Sp_done
.Sp_cancel_job:
 mov qword ptr [rip+.Sp_cancel],1
 call .Sp_kill
 jmp .Sp_done
.Sp_done:
 mov rax,[rip+.Sp_len]
 mov [rip+.Sp_result],rax
 jmp .Sp_cleanup
.Sp_error:
 mov [rip+.Sp_result],rax
.Sp_cleanup:
 cmp qword ptr [rip+.Sp_pid],0
 jl .Sp_restore
 call .Sp_kill
.Sp_restore:
 cmp qword ptr [rip+.Sp_state],3
 jne .Sp_restore_signals
 mov eax,16
 xor edi,edi
 mov esi,0x5402
 lea rdx,[rip+.Sp_saved]
 syscall
.Sp_restore_signals:
 cmp qword ptr [rip+.Sp_state],2
 jb .Sp_restore_int
 mov eax,13
 mov edi,3
 lea rsi,[rip+.Sp_oldquit]
 xor edx,edx
 mov r10d,8
 syscall
.Sp_restore_int:
 cmp qword ptr [rip+.Sp_state],1
 jb .Sp_close
 mov eax,13
 mov edi,2
 lea rsi,[rip+.Sp_oldint]
 xor edx,edx
 mov r10d,8
 syscall
.Sp_close:
 mov rdi,[rip+.Sp_slave]
 cmp rdi,0
 jl .Sp_close_master
 mov eax,3
 syscall
.Sp_close_master:
 mov rdi,[rip+.Sp_master]
 cmp rdi,0
 jl .Sp_return
 mov eax,3
 syscall
.Sp_return:
 mov rax,[rip+.Sp_result]
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.Sp_read_output:
 sub rsp,8
 xor eax,eax
 mov rdi,[rip+.Sp_master]
 lea rsi,[rip+.Sp_buffer]
 mov edx,8192
 syscall
 test rax,rax
 jle .Sp_ro_return
 mov r12,rax
 # Capture bounded bytes; still drain all output and forward it to the user.
 mov rcx,[rip+.Sp_cap]
 dec rcx
 sub rcx,[rip+.Sp_len]
 cmp rcx,r12
 jbe .Sp_ro_cap
 mov rcx,r12
.Sp_ro_cap:
 mov rdi,[rip+.Sp_out]
 add rdi,[rip+.Sp_len]
 lea rsi,[rip+.Sp_buffer]
 add [rip+.Sp_len],rcx
 rep movsb
 mov byte ptr [rdi],0
 mov edi,1
 lea rsi,[rip+.Sp_buffer]
 mov rdx,r12
 call .Sp_write_all
 test rax,rax
 js .Sp_ro_return
 mov rax,r12
.Sp_ro_return:
 add rsp,8
 ret
.Sp_write_all:
 push rbx
 push r13
 push r14
 mov rbx,rdi
 mov r13,rsi
 mov r14,rdx
.Sp_wa_loop:
 mov eax,1
 mov rdi,rbx
 mov rsi,r13
 mov rdx,r14
 syscall
 cmp rax,-4
 je .Sp_wa_loop
 cmp rax,-11
 jne .Sp_wa_progress
 # PTY input backpressure: yield briefly then retry, never drop keystrokes.
 mov eax,7
 xor edi,edi
 xor esi,esi
 mov edx,10
 syscall
 jmp .Sp_wa_loop
.Sp_wa_progress:
 test rax,rax
 jle .Sp_wa_done
 add r13,rax
 sub r14,rax
 jnz .Sp_wa_loop
 xor eax,eax
.Sp_wa_done:
 pop r14
 pop r13
 pop rbx
 ret
.Sp_wait:
 cmp qword ptr [rip+.Sp_reaped],0
 jne .Sp_wait_done
 mov eax,61
 mov rdi,[rip+.Sp_pid]
 lea rsi,[rip+.Sp_status]
 mov edx,1
 xor r10d,r10d
 syscall
 test rax,rax
 jle .Sp_wait_done
 mov qword ptr [rip+.Sp_reaped],1
 mov eax,[rip+.Sp_status]
 mov edx,eax
 and edx,127
 test edx,edx
 jnz .Sp_wait_signal
 shr eax,8
 and eax,255
 mov [rip+.Sp_exit],rax
 ret
.Sp_wait_signal:
 neg rdx
 mov [rip+.Sp_exit],rdx
.Sp_wait_done:
 ret
.Sp_kill:
 mov rdi,[rip+.Sp_pid]
 test rdi,rdi
 jle .Sp_kill_done
 neg rdi
 mov eax,62
 mov esi,9
 syscall
 cmp qword ptr [rip+.Sp_reaped],0
 jne .Sp_kill_done
 mov eax,62
 mov rdi,[rip+.Sp_pid]
 mov esi,9
 syscall
.Sp_reap:
 mov eax,61
 mov rdi,[rip+.Sp_pid]
 lea rsi,[rip+.Sp_status]
 xor edx,edx
 xor r10d,r10d
 syscall
 cmp rax,-4
 je .Sp_reap
 mov qword ptr [rip+.Sp_reaped],1
 mov qword ptr [rip+.Sp_exit],-9
.Sp_kill_done:
 ret
.Sp_child:
 # Parent-death signal with race check, no orphan interactive child.
 mov eax,157
 mov edi,1
 mov esi,9
 xor edx,edx
 xor r10d,r10d
 xor r8d,r8d
 syscall
 mov eax,110
 syscall
 cmp rax,[rip+.Sp_parent]
 jne .Sp_child_fail
 mov eax,112
 syscall
 test rax,rax
 js .Sp_child_fail
 mov eax,16
 mov rdi,[rip+.Sp_slave]
 mov esi,0x540e
 xor edx,edx
 syscall
 test rax,rax
 js .Sp_child_fail
 xor ebx,ebx
.Sp_dup:
 mov eax,33
 mov rdi,[rip+.Sp_slave]
 mov rsi,rbx
 syscall
 test rax,rax
 js .Sp_child_fail
 inc ebx
 cmp ebx,3
 jb .Sp_dup
 mov eax,3
 mov rdi,[rip+.Sp_master]
 syscall
 mov eax,3
 mov rdi,[rip+.Sp_slave]
 syscall
 mov eax,13
 mov edi,2
 lea rsi,[rip+.Sp_default]
 xor edx,edx
 mov r10d,8
 syscall
 mov eax,13
 mov edi,3
 lea rsi,[rip+.Sp_default]
 xor edx,edx
 mov r10d,8
 syscall
 mov eax,80
 mov rdi,[rip+.Sp_cwd]
 syscall
 test rax,rax
 js .Sp_child_fail
 lea rdi,[rip+.Sp_argv]
 lea rax,[rip+.Sp_shell]
 mov [rdi],rax
 lea rax,[rip+.Sp_dashc]
 mov [rdi+8],rax
 lea rax,[rip+.Sp_command]
 mov [rdi+16],rax
 mov qword ptr [rdi+24],0
 mov eax,59
 lea rdi,[rip+.Sp_shell]
 lea rsi,[rip+.Sp_argv]
 mov rdx,[rip+.Sp_env]
 syscall
.Sp_child_fail:
 mov eax,60
 mov edi,127
 syscall
 ud2
.section .note.GNU-stack,"",@progbits
