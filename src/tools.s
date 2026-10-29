.include "abi.inc"

.equ TOOL_CAP, 65536
.equ TOOL_PATH, 4096
.equ O_DIR_SAFE, 0xb0000
.equ O_FILE_SAFE, 0xa0800

.section .data
.align 8
t_workspace_fd: .quad -1
t_approval: .quad 0
t_allow_all: .quad 0
t_environment: .quad 0
t_cancel_callback: .quad 0
t_pidfd: .quad -1

.section .rodata
t_name_read: .asciz "read_file"
t_name_list: .asciz "list_directory"
t_name_write: .asciz "write_file"
t_name_edit: .asciz "edit_file"
t_name_shell: .asciz "run_shell"
t_names: .long t_name_read-t_names,t_name_list-t_names,t_name_write-t_names,t_name_edit-t_names,t_name_shell-t_names
t_routes: .long t_read-t_routes,t_list-t_routes,t_write-t_routes,t_edit-t_routes,t_shell-t_routes
k_path: .asciz "path"
k_content: .asciz "content"
k_old: .asciz "old_string"
k_new: .asciz "new_string"
k_command: .asciz "command"
k_timeout: .asciz "timeout_seconds"
t_dot: .asciz "."
t_sh: .asciz "/bin/sh"
t_dash_c: .asciz "-c"
t_temp_prefix: .ascii ".qwen-x86-tmp-"
.equ TEMP_PREFIX_LEN, .-t_temp_prefix
m_unknown: .asciz "Error: unknown tool."
m_arguments: .asciz "Error: invalid or missing tool arguments."
m_workspace: .asciz "Error: workspace is unavailable."
m_path: .asciz "Error: path must be relative, contain no '..' components, and traverse no symlinks."
m_open: .asciz "Error: cannot open the requested workspace path."
m_regular: .asciz "Error: only regular text files are supported."
m_large: .asciz "Error: file or content exceeds the 64 KiB tool limit."
m_read: .asciz "Error: could not read the file."
m_denied: .asciz "Error: user denied permission; no mutation or command was performed."
m_written: .asciz "File written successfully."
m_edited: .asciz "File edited successfully (one exact replacement)."
m_write: .asciz "Error: could not atomically write the file; original preserved."
m_empty: .asciz "[Empty directory]"
m_no_match: .asciz "Error: old_string was not found; nothing changed."
m_ambiguous: .asciz "Error: old_string has multiple matches; nothing changed."
m_shell: .asciz "Error: could not start or capture the shell command."
m_shell_exit: .asciz "\nError: shell command exited unsuccessfully."
m_timeout: .asciz "\nError: shell command timed out and its process group was terminated."
m_cancelled: .asciz "\nError: shell command cancelled; its process group was terminated."
m_truncated: .asciz "\n[Output truncated at 64 KiB]"
m_exec: .ascii "Error: execve /bin/sh failed.\n"
.equ M_EXEC_LEN, .-m_exec
p_write: .asciz "Allow this file write?\n"
p_edit: .asciz "Allow this exact file edit?\n"
p_shell: .asciz "Allow this unrestricted shell command as your user?\n"

.section .bss
.align 16
t_tokens: .skip 32768
t_args: .skip 8
t_args_len: .skip 8
t_out: .skip 8
t_out_cap: .skip 8
t_path: .skip TOOL_PATH
t_content: .skip TOOL_CAP+1
t_old: .skip TOOL_CAP+1
t_new: .skip TOOL_CAP+1
t_readbuf: .skip TOOL_CAP+1
t_result: .skip TOOL_CAP+1
t_old_len: .skip 8
t_new_len: .skip 8
t_content_len: .skip 8
t_read_len: .skip 8
t_match: .skip 8
t_parent_fd: .skip 8
t_file_mode: .skip 8
t_final_name: .skip 8
t_stat: .skip 160
t_temp: .skip 64
t_approval_text: .skip MAX_JSON+128
t_dirbuf: .skip 8192
t_pipe: .skip 8
t_poll: .skip 8
t_clock: .skip 16
t_started: .skip 8
t_started_nsec: .skip 8
t_pipe_closed: .skip 8
t_pause: .skip 16
t_timeout_sec: .skip 8
t_child: .skip 8
t_wait_status: .skip 8
t_shell_len: .skip 8
t_shell_truncated: .skip 8
t_shell_timed_out: .skip 8
t_shell_cancelled: .skip 8
t_argv: .skip 32

.section .text
.global tools_set_workspace,tools_set_approval,tools_set_environment,tools_set_cancel,tool_execute
.extern json_parse,json_find,json_decode

# Bind the workspace once before data arrives. Returns a directory FD error.
tools_set_workspace:
 push rbx
 mov eax,257
 mov rsi,rdi
 mov edi,-100
 mov edx,O_DIR_SAFE
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lworkspace_return
 mov rbx,rax
 mov rdi,QWORD PTR [rip+t_workspace_fd]
 cmp rdi,0
 jl .Lworkspace_store
 mov eax,3
 syscall
.Lworkspace_store:
 mov QWORD PTR [rip+t_workspace_fd],rbx
 xor eax,eax
.Lworkspace_return:
 pop rbx
 ret

tools_set_approval:
 mov QWORD PTR [rip+t_approval],rdi
 mov QWORD PTR [rip+t_allow_all],rsi
 xor eax,eax
 ret

tools_set_environment:
 mov QWORD PTR [rip+t_environment],rdi
 ret

# Optional process-local cancellation membrane: callback()->0 or-125.
# It is bound once; shell code itself has no network/terminal dependency.
tools_set_cancel:
 mov QWORD PTR [rip+t_cancel_callback],rdi
 xor eax,eax
 ret

# Dispatch immutable tool names to their bound native handler routes.
tool_execute:
 push rbp
 mov rbp,rsp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 test r12,r12
 jz .Lexecute_internal
 mov QWORD PTR [rip+t_args],rsi
 mov QWORD PTR [rip+t_args_len],rdx
 mov QWORD PTR [rip+t_out],rcx
 mov QWORD PTR [rip+t_out_cap],r8
 test rcx,rcx
 jz .Lexecute_internal
 cmp r8,2
 jb .Lexecute_internal
 cmp rdx,MAX_JSON
 ja .Lexecute_arguments
 cmp QWORD PTR [rip+t_workspace_fd],0
 jl .Lexecute_workspace
 mov rdi,rsi
 mov rsi,rdx
 lea rdx,[rip+t_tokens]
 mov ecx,1024
 call json_parse@PLT
 test rax,rax
 js .Lexecute_arguments
 cmp QWORD PTR [rip+t_tokens+T_TYPE],JT_OBJECT
 jne .Lexecute_arguments
 xor r13d,r13d
.Lexecute_select:
 lea rax,[rip+t_names]
 movsxd rdi,DWORD PTR [rax+r13*4]
 add rdi,rax
 mov rsi,r12
 call t_equal
 test eax,eax
 jnz .Lexecute_selected
 inc r13
 cmp r13,5
 jb .Lexecute_select
 lea rdi,[rip+m_unknown]
 jmp .Lexecute_message
.Lexecute_selected:
 lea rax,[rip+t_routes]
 movsxd rdx,DWORD PTR [rax+r13*4]
 add rax,rdx
 call rax
 jmp .Lexecute_done
.Lexecute_arguments:
 lea rdi,[rip+m_arguments]
 jmp .Lexecute_message
.Lexecute_workspace:
 lea rdi,[rip+m_workspace]
.Lexecute_message:
 call t_message
 jmp .Lexecute_done
.Lexecute_internal:
 mov rax,-1
.Lexecute_done:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# Immutable NUL strings: equality and length.
t_equal:
 xor eax,eax
.Leq_loop:
 mov dl,BYTE PTR [rdi+rax]
 cmp dl,BYTE PTR [rsi+rax]
 jne .Leq_no
 test dl,dl
 jz .Leq_yes
 inc rax
 jmp .Leq_loop
.Leq_yes:
 mov eax,1
 ret
.Leq_no:
 xor eax,eax
 ret

t_strlen:
 xor eax,eax
.Lstrlen_loop:
 cmp BYTE PTR [rdi+rax],0
 je .Lstrlen_done
 inc rax
 jmp .Lstrlen_loop
.Lstrlen_done:
 ret

# Copy raw output into the bound caller buffer; always leave a trailing NUL.
t_return:
 mov rcx,QWORD PTR [rip+t_out_cap]
 dec rcx
 cmp rsi,rcx
 cmova rsi,rcx
 mov rax,rsi
 mov rdx,rdi
 mov rdi,QWORD PTR [rip+t_out]
 mov rcx,rsi
 mov rsi,rdx
 rep movsb
 mov BYTE PTR [rdi],0
 ret

t_message:
 push rdi
 call t_strlen
 pop rdi
 mov rsi,rax
 jmp t_return

# Find/decode one required string into dst. Embedded NULs are rejected.
# rdi keyz, rsi destination, rdx capacity; rax decoded length or negative.
t_string:
 push rbp
 mov rbp,rsp
 push rbx
 push r12
 push r13
 sub rsp,8
 mov rbx,rsi
 mov r12,rdx
 mov rcx,rdi
 mov rdi,QWORD PTR [rip+t_args]
 lea rsi,[rip+t_tokens]
 xor edx,edx
 call json_find@PLT
 test rax,rax
 js .Lstring_error
 shl rax,5
 lea rdx,[rip+t_tokens]
 add rdx,rax
 cmp QWORD PTR [rdx+T_TYPE],JT_STRING
 jne .Lstring_error
 mov rsi,QWORD PTR [rdx+T_START]
 add rsi,QWORD PTR [rip+t_args]
 mov rdx,QWORD PTR [rdx+T_LEN]
 mov rdi,rbx
 lea rcx,[r12-1]
 call json_decode@PLT
 test rax,rax
 js .Lstring_error
 mov r13,rax
 xor ecx,ecx
.Lstring_nul:
 cmp rcx,r13
 jae .Lstring_good
 cmp BYTE PTR [rbx+rcx],0
 je .Lstring_error
 inc rcx
 jmp .Lstring_nul
.Lstring_good:
 mov BYTE PTR [rbx+r13],0
 mov rax,r13
 jmp .Lstring_done
.Lstring_error:
 mov rax,-1
.Lstring_done:
 add rsp,8
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

t_get_path:
 lea rdi,[rip+k_path]
 lea rsi,[rip+t_path]
 mov edx,TOOL_PATH
 jmp t_string

# Open a path's parent by walking O_DIRECTORY|O_NOFOLLOW components.
# Leaves fd and basename in BSS; caller closes fd. Reject all absolute/.. paths.
t_parent:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 lea r13,[rip+t_path]
 cmp BYTE PTR [r13],0
 je .Lparent_bad
 cmp BYTE PTR [r13],47
 je .Lparent_bad
 mov rdi,QWORD PTR [rip+t_workspace_fd]
 mov eax,32
 syscall
 test rax,rax
 js .Lparent_bad
 mov r12,rax
 mov r14,r13
.Lparent_scan:
 mov al,BYTE PTR [r14]
 test al,al
 jz .Lparent_final
 cmp al,47
 je .Lparent_component
 inc r14
 jmp .Lparent_scan
.Lparent_component:
 cmp r14,r13
 je .Lparent_close_bad
 mov BYTE PTR [r14],0
 mov rdi,r13
 call t_safe_component
 test eax,eax
 jz .Lparent_restore_bad
 mov rdi,r12
 mov rsi,r13
 mov edx,O_DIR_SAFE
 xor r10d,r10d
 mov eax,257
 syscall
 mov BYTE PTR [r14],47
 test rax,rax
 js .Lparent_close_bad
 mov rbx,rax
 mov rdi,r12
 mov eax,3
 syscall
 mov r12,rbx
 lea r13,[r14+1]
 mov r14,r13
 jmp .Lparent_scan
.Lparent_final:
 mov rdi,r13
 call t_safe_component
 test eax,eax
 jz .Lparent_close_bad
 mov QWORD PTR [rip+t_parent_fd],r12
 mov QWORD PTR [rip+t_final_name],r13
 xor eax,eax
 jmp .Lparent_done
.Lparent_restore_bad:
 mov BYTE PTR [r14],47
.Lparent_close_bad:
 mov rdi,r12
 mov eax,3
 syscall
.Lparent_bad:
 mov rax,-1
.Lparent_done:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

t_safe_component:
 xor eax,eax
 cmp BYTE PTR [rdi],0
 je .Lcomponent_done
 cmp BYTE PTR [rdi],46
 jne .Lcomponent_yes
 cmp BYTE PTR [rdi+1],46
 jne .Lcomponent_yes
 cmp BYTE PTR [rdi+2],0
 je .Lcomponent_done
.Lcomponent_yes:
 mov eax,1
.Lcomponent_done:
 ret

t_close_parent:
 mov rdi,QWORD PTR [rip+t_parent_fd]
 mov eax,3
 syscall
 ret

# Read a regular file into the private read buffer. Path must be decoded.
t_load:
 push rbx
 push r12
 push r13
 sub rsp,0
 call t_parent
 test rax,rax
 js .Lload_path
 mov rdi,QWORD PTR [rip+t_parent_fd]
 mov rsi,QWORD PTR [rip+t_final_name]
 mov edx,O_FILE_SAFE
 xor r10d,r10d
 mov eax,257
 syscall
 mov r12,rax
 call t_close_parent
 test r12,r12
 js .Lload_open
 mov eax,5
 mov rdi,r12
 lea rsi,[rip+t_stat]
 syscall
 test rax,rax
 js .Lload_error
 mov eax,DWORD PTR [rip+t_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lload_regular
 xor r13d,r13d
.Lload_loop:
 mov rdi,r12
 lea rsi,[rip+t_readbuf]
 add rsi,r13
 mov edx,TOOL_CAP+1
 sub rdx,r13
 xor eax,eax
 syscall
 cmp rax,-4
 je .Lload_loop
 test rax,rax
 js .Lload_error
 jz .Lload_complete
 add r13,rax
 cmp r13,TOOL_CAP
 ja .Lload_large
 jmp .Lload_loop
.Lload_complete:
 mov rdi,r12
 mov eax,3
 syscall
 mov QWORD PTR [rip+t_read_len],r13
 mov rax,r13
 jmp .Lload_done
.Lload_regular:
 mov ebx,3
 jmp .Lload_close_error
.Lload_large:
 mov ebx,4
 jmp .Lload_close_error
.Lload_error:
 mov ebx,5
.Lload_close_error:
 mov rdi,r12
 mov eax,3
 syscall
 mov rax,rbx
 neg rax
 jmp .Lload_done
.Lload_path:
 mov rax,-1
 jmp .Lload_done
.Lload_open:
 mov rax,-2
.Lload_done:
 pop r13
 pop r12
 pop rbx
 ret

t_read:
 sub rsp,8
 call t_get_path
 test rax,rax
 js .Lread_args
 call t_load
 test rax,rax
 js .Lread_failed
 mov rsi,rax
 lea rdi,[rip+t_readbuf]
 call t_return
 add rsp,8
 ret
.Lread_failed:
 cmp rax,-1
 je .Lread_path
 cmp rax,-2
 je .Lread_open
 cmp rax,-3
 je .Lread_regular
 cmp rax,-4
 je .Lread_large
 lea rdi,[rip+m_read]
 jmp .Lread_message
.Lread_args:
 lea rdi,[rip+m_arguments]
 jmp .Lread_message
.Lread_path:
 lea rdi,[rip+m_path]
 jmp .Lread_message
.Lread_open:
 lea rdi,[rip+m_open]
 jmp .Lread_message
.Lread_regular:
 lea rdi,[rip+m_regular]
 jmp .Lread_message
.Lread_large:
 lea rdi,[rip+m_large]
.Lread_message:
 call t_message
 add rsp,8
 ret

# A single writer owns the permission callback and complete JSON preview.
t_approve:
 push rbx
 push r12
 sub rsp,8
 cmp QWORD PTR [rip+t_allow_all],0
 jne .Lapprove_yes
 mov r12,QWORD PTR [rip+t_approval]
 test r12,r12
 jz .Lapprove_no
 mov rbx,rdi
 call t_strlen
 lea rdi,[rip+t_approval_text]
 mov rsi,rbx
 mov rcx,rax
 rep movsb
 mov rsi,QWORD PTR [rip+t_args]
 mov rcx,QWORD PTR [rip+t_args_len]
 rep movsb
 mov BYTE PTR [rdi],0
 lea rdi,[rip+t_approval_text]
 call r12
 test rax,rax
 setne al
 movzx eax,al
 jmp .Lapprove_done
.Lapprove_yes:
 mov eax,1
 jmp .Lapprove_done
.Lapprove_no:
 xor eax,eax
.Lapprove_done:
 add rsp,8
 pop r12
 pop rbx
 ret

# Atomic same-directory replacement, preserving existing regular-file mode.
# rdi data, rsi length. Decoded path remains in t_path.
t_atomic:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 call t_parent
 test rax,rax
 js .Latomic_fail
 mov r14,QWORD PTR [rip+t_parent_fd]
 mov r15,QWORD PTR [rip+t_final_name]
 mov rdi,r14
 mov rsi,r15
 lea rdx,[rip+t_stat]
 mov r10d,256
 mov eax,262
 syscall
 mov ebx,0644
 cmp rax,-2
 je .Latomic_temp
 test rax,rax
 js .Latomic_close_fail
 mov eax,DWORD PTR [rip+t_stat+24]
 mov ebx,eax
 and eax,0xf000
 cmp eax,0x8000
 jne .Latomic_close_fail
 and ebx,0777
.Latomic_temp:
 mov QWORD PTR [rip+t_file_mode],rbx
 lea rdi,[rip+t_temp]
 lea rsi,[rip+t_temp_prefix]
 mov ecx,TEMP_PREFIX_LEN
 rep movsb
 mov eax,39
 syscall
 mov rsi,rdi
 mov rdi,rax
 call t_decimal
 # t_decimal appends the PID and trailing NUL at the supplied destination.
 mov rdi,r14
 lea rsi,[rip+t_temp]
 mov edx,0xa00c1
 mov r10d,ebx
 mov eax,257
 syscall
 test rax,rax
 js .Latomic_close_fail
 mov rbx,rax
 mov rdi,rbx
 mov rsi,QWORD PTR [rip+t_file_mode]
 mov eax,91
 syscall
 test rax,rax
 js .Latomic_temp_fail
 xor r15d,r15d
.Latomic_write:
 cmp r15,r13
 jae .Latomic_sync
 mov rdi,rbx
 lea rsi,[r12+r15]
 mov rdx,r13
 sub rdx,r15
 mov eax,1
 syscall
 cmp rax,-4
 je .Latomic_write
 test rax,rax
 jle .Latomic_temp_fail
 add r15,rax
 jmp .Latomic_write
.Latomic_sync:
 mov rdi,rbx
 mov eax,74
 syscall
 test rax,rax
 js .Latomic_temp_fail
 mov rdi,rbx
 mov eax,3
 syscall
 mov rdi,r14
 lea rsi,[rip+t_temp]
 mov rdx,r14
 mov r10,QWORD PTR [rip+t_final_name]
 mov eax,264
 syscall
 test rax,rax
 js .Latomic_unlink_fail
 mov rdi,r14
 mov eax,3
 syscall
 xor eax,eax
 jmp .Latomic_done
.Latomic_temp_fail:
 mov rdi,rbx
 mov eax,3
 syscall
.Latomic_unlink_fail:
 mov rdi,r14
 lea rsi,[rip+t_temp]
 xor edx,edx
 mov eax,263
 syscall
.Latomic_close_fail:
 mov rdi,r14
 mov eax,3
 syscall
.Latomic_fail:
 mov rax,-1
.Latomic_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# rdi unsigned value, rsi destination; returns count, appends NUL.
t_decimal:
 sub rsp,32
 mov rax,rdi
 lea r8,[rsp+31]
 mov BYTE PTR [r8],0
 mov r9,r8
 mov r10d,10
.Ldecimal_digit:
 xor edx,edx
 div r10
 add dl,48
 dec r8
 mov BYTE PTR [r8],dl
 test rax,rax
 jnz .Ldecimal_digit
 mov rcx,r9
 sub rcx,r8
 mov rax,rcx
 mov rdi,rsi
 mov rsi,r8
 rep movsb
 mov BYTE PTR [rdi],0
 add rsp,32
 ret

t_write:
 push rbx
 call t_get_path
 test rax,rax
 js .Lwrite_args
 lea rdi,[rip+k_content]
 lea rsi,[rip+t_content]
 mov edx,TOOL_CAP+1
 call t_string
 test rax,rax
 js .Lwrite_args
 mov rbx,rax
 lea rdi,[rip+p_write]
 call t_approve
 test eax,eax
 jz .Lwrite_denied
 lea rdi,[rip+t_content]
 mov rsi,rbx
 call t_atomic
 test rax,rax
 js .Lwrite_error
 lea rdi,[rip+m_written]
 jmp .Lwrite_message
.Lwrite_args:
 lea rdi,[rip+m_arguments]
 jmp .Lwrite_message
.Lwrite_denied:
 lea rdi,[rip+m_denied]
 jmp .Lwrite_message
.Lwrite_error:
 lea rdi,[rip+m_write]
.Lwrite_message:
 call t_message
 pop rbx
 ret

t_edit:
 push rbx
 push r12
 sub rsp,8
 call t_get_path
 test rax,rax
 js .Ledit_args
 lea rdi,[rip+k_old]
 lea rsi,[rip+t_old]
 mov edx,TOOL_CAP+1
 call t_string
 test rax,rax
 jle .Ledit_args
 mov QWORD PTR [rip+t_old_len],rax
 lea rdi,[rip+k_new]
 lea rsi,[rip+t_new]
 mov edx,TOOL_CAP+1
 call t_string
 test rax,rax
 js .Ledit_args
 mov QWORD PTR [rip+t_new_len],rax
 call t_load
 test rax,rax
 js .Ledit_open
 mov r12,rax
 lea rdi,[rip+t_content]
 lea rsi,[rip+t_readbuf]
 mov rcx,r12
 rep movsb
 mov rax,QWORD PTR [rip+t_old_len]
 cmp rax,r12
 ja .Ledit_missing
 mov rbx,-1
 xor r8d,r8d
 mov r9,r12
 sub r9,rax
.Ledit_scan:
 cmp r8,r9
 ja .Ledit_scanned
 lea rdi,[rip+t_readbuf]
 add rdi,r8
 lea rsi,[rip+t_old]
 mov rcx,QWORD PTR [rip+t_old_len]
 repe cmpsb
 jne .Ledit_next
 cmp rbx,-1
 jne .Ledit_ambiguous
 mov rbx,r8
.Ledit_next:
 inc r8
 jmp .Ledit_scan
.Ledit_scanned:
 cmp rbx,-1
 je .Ledit_missing
 mov QWORD PTR [rip+t_match],rbx
 mov rax,r12
 sub rax,QWORD PTR [rip+t_old_len]
 add rax,QWORD PTR [rip+t_new_len]
 cmp rax,TOOL_CAP
 ja .Ledit_large
 mov QWORD PTR [rip+t_content_len],rax
 lea rdi,[rip+t_result]
 lea rsi,[rip+t_readbuf]
 mov rcx,rbx
 rep movsb
 lea rsi,[rip+t_new]
 mov rcx,QWORD PTR [rip+t_new_len]
 rep movsb
 lea rsi,[rip+t_readbuf]
 add rsi,rbx
 add rsi,QWORD PTR [rip+t_old_len]
 mov rcx,r12
 sub rcx,rbx
 sub rcx,QWORD PTR [rip+t_old_len]
 rep movsb
 lea rdi,[rip+p_edit]
 call t_approve
 test eax,eax
 jz .Ledit_denied
 # Re-read after approval so a concurrent edit is never silently overwritten.
 call t_load
 cmp rax,r12
 jne .Ledit_concurrent
 lea rsi,[rip+t_readbuf]
 # Original snapshot lives in content buffer before approval (see below).
 # Verify entire original by reconstructing comparison against saved snapshot.
 lea rdi,[rip+t_content]
 mov rcx,r12
 repe cmpsb
 jne .Ledit_concurrent
 lea rdi,[rip+t_result]
 mov rsi,QWORD PTR [rip+t_content_len]
 call t_atomic
 test rax,rax
 js .Ledit_write_error
 lea rdi,[rip+m_edited]
 jmp .Ledit_message
.Ledit_args:
 lea rdi,[rip+m_arguments]
 jmp .Ledit_message
.Ledit_open:
 lea rdi,[rip+m_open]
 jmp .Ledit_message
.Ledit_missing:
 lea rdi,[rip+m_no_match]
 jmp .Ledit_message
.Ledit_ambiguous:
 lea rdi,[rip+m_ambiguous]
 jmp .Ledit_message
.Ledit_large:
 lea rdi,[rip+m_large]
 jmp .Ledit_message
.Ledit_denied:
 lea rdi,[rip+m_denied]
 jmp .Ledit_message
.Ledit_concurrent:
 lea rdi,[rip+m_write]
 jmp .Ledit_message
.Ledit_write_error:
 lea rdi,[rip+m_write]
.Ledit_message:
 call t_message
 add rsp,8
 pop r12
 pop rbx
 ret

# Directory records use Linux getdents64's owning schema, never an opcode font.
t_list:
 push rbx
 push r12
 push r13
 push r14
 push r15
 call t_get_path
 test rax,rax
 jns .Llist_have_path
 mov rdi,QWORD PTR [rip+t_args]
 lea rsi,[rip+t_tokens]
 xor edx,edx
 lea rcx,[rip+k_path]
 call json_find@PLT
 test rax,rax
 jns .Llist_args
 lea rdi,[rip+t_path]
 mov WORD PTR [rdi],46
.Llist_have_path:
 call t_parent
 test rax,rax
 js .Llist_path
 mov rdi,QWORD PTR [rip+t_parent_fd]
 mov rsi,QWORD PTR [rip+t_final_name]
 mov edx,O_DIR_SAFE
 xor r10d,r10d
 mov eax,257
 syscall
 mov r12,rax
 call t_close_parent
 test r12,r12
 js .Llist_open
 xor ebx,ebx
.Llist_read:
 mov rdi,r12
 lea rsi,[rip+t_dirbuf]
 mov edx,8192
 mov eax,217
 syscall
 cmp rax,-4
 je .Llist_read
 test rax,rax
 js .Llist_bad_fd
 jz .Llist_finish
 lea r13,[rip+t_dirbuf]
 lea r14,[r13+rax]
.Llist_record:
 cmp r13,r14
 jae .Llist_read
 movzx r15d,WORD PTR [r13+16]
 cmp r15d,20
 jb .Llist_bad_fd
 lea rax,[r13+r15]
 cmp rax,r14
 ja .Llist_bad_fd
 lea rsi,[r13+19]
 cmp BYTE PTR [rsi],46
 jne .Llist_name
 cmp BYTE PTR [rsi+1],0
 je .Llist_next
 cmp BYTE PTR [rsi+1],46
 jne .Llist_name
 cmp BYTE PTR [rsi+2],0
 je .Llist_next
.Llist_name:
 lea rdi,[rip+t_result]
 add rdi,rbx
 xor ecx,ecx
.Llist_copy:
 lea rax,[rsi+rcx]
 lea rdx,[r13+r15]
 cmp rax,rdx
 jae .Llist_bad_fd
 mov al,BYTE PTR [rsi+rcx]
 test al,al
 jz .Llist_suffix
 cmp rbx,TOOL_CAP-3
 jae .Llist_finish
 mov BYTE PTR [rdi],al
 inc rdi
 inc rcx
 inc rbx
 jmp .Llist_copy
.Llist_suffix:
 cmp BYTE PTR [r13+18],4
 jne .Llist_newline
 mov BYTE PTR [rdi],47
 inc rdi
 inc rbx
.Llist_newline:
 mov BYTE PTR [rdi],10
 inc rbx
.Llist_next:
 add r13,r15
 jmp .Llist_record
.Llist_finish:
 mov rdi,r12
 mov eax,3
 syscall
 test rbx,rbx
 jz .Llist_empty
 lea rdi,[rip+t_result]
 mov rsi,rbx
 call t_return
 jmp .Llist_done
.Llist_bad_fd:
 mov rdi,r12
 mov eax,3
 syscall
.Llist_open:
 lea rdi,[rip+m_open]
 jmp .Llist_message
.Llist_path:
 lea rdi,[rip+m_path]
 jmp .Llist_message
.Llist_args:
 lea rdi,[rip+m_arguments]
 jmp .Llist_message
.Llist_empty:
 lea rdi,[rip+m_empty]
.Llist_message:
 call t_message
.Llist_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Native process group with poll/monotonic timeout; captured output is drained.
t_shell:
 push rbx
 push r12
 push r13
 mov QWORD PTR [rip+t_pidfd],-1
 lea rdi,[rip+k_command]
 lea rsi,[rip+t_content]
 mov edx,TOOL_CAP+1
 call t_string
 test rax,rax
 jle .Lshell_args
 lea rdi,[rip+p_shell]
 call t_approve
 test eax,eax
 jz .Lshell_denied
 call t_shell_timeout
 lea rdi,[rip+t_pipe]
 mov esi,0x80000
 mov eax,293
 syscall
 test rax,rax
 js .Lshell_error
 mov eax,57
 syscall
 test rax,rax
 jz .Lshell_child
 js .Lshell_fork_error
 mov r12,rax
 mov QWORD PTR [rip+t_child],rax
 mov rdi,rax
 mov rsi,rax
 mov eax,109
 syscall
 mov edi,DWORD PTR [rip+t_pipe+4]
 mov eax,3
 syscall
 mov eax,DWORD PTR [rip+t_pipe]
 mov DWORD PTR [rip+t_poll],eax
 mov WORD PTR [rip+t_poll+4],1
 # pidfd readiness wakes exactly when the direct child exits, including when
 # stdout closes first. Old kernels retain the bounded legacy polling fallback.
 mov eax,434
 mov rdi,r12
 xor esi,esi
 syscall
 mov QWORD PTR [rip+t_pidfd],rax
 mov QWORD PTR [rip+t_shell_len],0
 mov QWORD PTR [rip+t_shell_truncated],0
 mov QWORD PTR [rip+t_shell_timed_out],0
 mov QWORD PTR [rip+t_shell_cancelled],0
 mov QWORD PTR [rip+t_pipe_closed],0
 mov QWORD PTR [rip+t_pause],0
 mov QWORD PTR [rip+t_pause+8],100000000
 mov edi,1
 lea rsi,[rip+t_clock]
 mov eax,228
 syscall
 mov rax,QWORD PTR [rip+t_clock]
 mov QWORD PTR [rip+t_started],rax
 mov rax,QWORD PTR [rip+t_clock+8]
 mov QWORD PTR [rip+t_started_nsec],rax
.Lshell_poll:
 mov rax,QWORD PTR [rip+t_cancel_callback]
 test rax,rax
 jz .Lshell_check_clock
 call rax
 cmp rax,-125
 je .Lshell_cancel_kill
.Lshell_check_clock:
 mov edi,1
 lea rsi,[rip+t_clock]
 mov eax,228
 syscall
 mov rax,QWORD PTR [rip+t_clock]
 sub rax,QWORD PTR [rip+t_started]
 cmp rax,QWORD PTR [rip+t_timeout_sec]
 ja .Lshell_timeout_kill
 jb .Lshell_time_ok
 mov rax,QWORD PTR [rip+t_clock+8]
 cmp rax,QWORD PTR [rip+t_started_nsec]
 jae .Lshell_timeout_kill
.Lshell_time_ok:
 cmp QWORD PTR [rip+t_pipe_closed],0
 jne .Lshell_reap_poll
 lea rdi,[rip+t_poll]
 mov esi,1
 mov edx,100
 mov eax,7
 syscall
 cmp rax,-4
 je .Lshell_poll
 test rax,rax
 js .Lshell_timeout_kill
 jz .Lshell_poll
 mov edi,DWORD PTR [rip+t_pipe]
 lea rsi,[rip+t_dirbuf]
 mov edx,8192
 xor eax,eax
 syscall
 cmp rax,-4
 je .Lshell_poll
 test rax,rax
 js .Lshell_timeout_kill
 jz .Lshell_eof
 mov rcx,rax
 mov rbx,QWORD PTR [rip+t_shell_len]
 mov rdx,TOOL_CAP-256
 sub rdx,rbx
 cmp rcx,rdx
 jbe .Lshell_capture
 mov QWORD PTR [rip+t_shell_truncated],1
 mov rcx,rdx
.Lshell_capture:
 lea rdi,[rip+t_result]
 add rdi,rbx
 lea rsi,[rip+t_dirbuf]
 add rbx,rcx
 rep movsb
 mov QWORD PTR [rip+t_shell_len],rbx
 jmp .Lshell_poll
.Lshell_cancel_kill:
 mov QWORD PTR [rip+t_shell_cancelled],1
 jmp .Lshell_kill_group
.Lshell_timeout_kill:
 mov QWORD PTR [rip+t_shell_timed_out],1
.Lshell_kill_group:
 mov rdi,r12
 neg rdi
 mov esi,9
 mov eax,62
 syscall
.Lshell_wait:
 cmp QWORD PTR [rip+t_pipe_closed],0
 jne .Lshell_wait_reap
 mov edi,DWORD PTR [rip+t_pipe]
 mov eax,3
 syscall
.Lshell_wait_reap:
 mov rdi,r12
 lea rsi,[rip+t_wait_status]
 xor edx,edx
 xor r10d,r10d
 mov eax,61
 syscall
 cmp rax,-4
 je .Lshell_wait_reap
 jmp .Lshell_status
.Lshell_eof:
 mov edi,DWORD PTR [rip+t_pipe]
 mov eax,3
 syscall
 mov QWORD PTR [rip+t_pipe_closed],1
.Lshell_reap_poll:
 mov rdi,r12
 lea rsi,[rip+t_wait_status]
 mov edx,1
 xor r10d,r10d
 mov eax,61
 syscall
 cmp rax,r12
 je .Lshell_status
 cmp rax,-4
 je .Lshell_poll
 test rax,rax
 js .Lshell_timeout_kill
 mov rax,QWORD PTR [rip+t_pidfd]
 test rax,rax
 js .Lshell_reap_fallback
 mov DWORD PTR [rip+t_poll],eax
 mov WORD PTR [rip+t_poll+4],1
 mov WORD PTR [rip+t_poll+6],0
 lea rdi,[rip+t_poll]
 mov esi,1
 mov edx,100
 mov eax,7
 syscall
 cmp rax,-4
 je .Lshell_poll
 test rax,rax
 js .Lshell_timeout_kill
 jmp .Lshell_poll
.Lshell_reap_fallback:
 lea rdi,[rip+t_pause]
 xor esi,esi
 mov eax,35
 syscall
 jmp .Lshell_poll
.Lshell_status:
 mov rbx,QWORD PTR [rip+t_shell_len]
 cmp QWORD PTR [rip+t_shell_cancelled],0
 jne .Lshell_cancel_suffix
 cmp QWORD PTR [rip+t_shell_timed_out],0
 jne .Lshell_timeout_suffix
 cmp DWORD PTR [rip+t_wait_status],0
 jne .Lshell_exit_suffix
 jmp .Lshell_truncation
.Lshell_cancel_suffix:
 lea rsi,[rip+m_cancelled]
 call t_shell_suffix
 jmp .Lshell_truncation
.Lshell_timeout_suffix:
 lea rsi,[rip+m_timeout]
 call t_shell_suffix
 jmp .Lshell_truncation
.Lshell_exit_suffix:
 lea rsi,[rip+m_shell_exit]
 call t_shell_suffix
.Lshell_truncation:
 cmp QWORD PTR [rip+t_shell_truncated],0
 je .Lshell_output
 lea rsi,[rip+m_truncated]
 call t_shell_suffix
.Lshell_output:
 lea rdi,[rip+t_result]
 mov rsi,rbx
 call t_return
 jmp .Lshell_done
.Lshell_child:
 xor edi,edi
 xor esi,esi
 mov eax,109
 syscall
 mov edi,DWORD PTR [rip+t_pipe+4]
 mov esi,1
 mov eax,33
 syscall
 mov edi,DWORD PTR [rip+t_pipe+4]
 mov esi,2
 mov eax,33
 syscall
 mov edi,DWORD PTR [rip+t_pipe]
 mov eax,3
 syscall
 mov edi,DWORD PTR [rip+t_pipe+4]
 mov eax,3
 syscall
 mov rdi,QWORD PTR [rip+t_workspace_fd]
 mov eax,81
 syscall
 test rax,rax
 js .Lshell_child_failed
 lea rax,[rip+t_sh]
 mov QWORD PTR [rip+t_argv],rax
 lea rax,[rip+t_dash_c]
 mov QWORD PTR [rip+t_argv+8],rax
 lea rax,[rip+t_content]
 mov QWORD PTR [rip+t_argv+16],rax
 mov QWORD PTR [rip+t_argv+24],0
 lea rdi,[rip+t_sh]
 lea rsi,[rip+t_argv]
 mov rdx,QWORD PTR [rip+t_environment]
 mov eax,59
 syscall
.Lshell_child_failed:
 mov edi,2
 lea rsi,[rip+m_exec]
 mov edx,M_EXEC_LEN
 mov eax,1
 syscall
 mov edi,127
 mov eax,60
 syscall
.Lshell_fork_error:
 mov edi,DWORD PTR [rip+t_pipe]
 mov eax,3
 syscall
 mov edi,DWORD PTR [rip+t_pipe+4]
 mov eax,3
 syscall
.Lshell_error:
 lea rdi,[rip+m_shell]
 jmp .Lshell_message
.Lshell_args:
 lea rdi,[rip+m_arguments]
 jmp .Lshell_message
.Lshell_denied:
 lea rdi,[rip+m_denied]
.Lshell_message:
 call t_message
 .Lshell_done:
 mov r13,rax
 mov rdi,QWORD PTR [rip+t_pidfd]
 test rdi,rdi
 js .Lshell_done_return
 mov eax,3
 syscall
 mov QWORD PTR [rip+t_pidfd],-1
.Lshell_done_return:
 mov rax,r13
 pop r13
 pop r12
 pop rbx
 ret

# Append a small immutable status suffix. rbx is the bound result length.
t_shell_suffix:
 lea rdi,[rip+t_result]
 add rdi,rbx
.Lsuffix_loop:
 mov al,BYTE PTR [rsi]
 test al,al
 jz .Lsuffix_done
 mov BYTE PTR [rdi],al
 inc rsi
 inc rdi
 inc rbx
 jmp .Lsuffix_loop
.Lsuffix_done:
 ret

# Decode a bounded optional timeout from the token's decimal bytes.
t_shell_timeout:
 push rbx
 mov QWORD PTR [rip+t_timeout_sec],120
 mov rdi,QWORD PTR [rip+t_args]
 lea rsi,[rip+t_tokens]
 xor edx,edx
 lea rcx,[rip+k_timeout]
 call json_find@PLT
 test rax,rax
 js .Ltimeout_done
 shl rax,5
 lea rbx,[rip+t_tokens]
 add rbx,rax
 cmp QWORD PTR [rbx+T_TYPE],JT_NUMBER
 jne .Ltimeout_done
 mov rcx,QWORD PTR [rbx+T_LEN]
 cmp rcx,3
 ja .Ltimeout_done
 mov rsi,QWORD PTR [rbx+T_START]
 add rsi,QWORD PTR [rip+t_args]
 xor eax,eax
.Ltimeout_digits:
 test rcx,rcx
 jz .Ltimeout_value
 movzx edx,BYTE PTR [rsi]
 sub edx,48
 cmp edx,9
 ja .Ltimeout_done
 imul eax,eax,10
 add eax,edx
 inc rsi
 dec rcx
 jmp .Ltimeout_digits
.Ltimeout_value:
 test eax,eax
 jz .Ltimeout_done
 mov edx,120
 cmp eax,120
 cmova eax,edx
 mov QWORD PTR [rip+t_timeout_sec],rax
.Ltimeout_done:
 pop rbx
 ret

.section .note.GNU-stack,"",@progbits
