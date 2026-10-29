# Native forked subagents: each worker owns its writable pages and conversation.
# Fixed descriptor rows describe worker state.
.include "abi.inc"
.equ A_SLOTS,8
.equ A_SIZE,70000
.equ A_TYPE,69864
.equ A_APPROVAL,69848
.equ A_POLICY,69856
.equ A_ID,0
.equ A_PID,8
.equ A_FD,16
.equ A_STATUS,24
.equ A_EXIT,32
.equ A_RLEN,40
.equ A_MLEN,48
.equ A_META,56
.equ A_REAPED,64
.equ A_NAME,72
.equ A_SESSION,200
.equ A_REPORT,4296
.equ A_TRUNC,69840
.equ A_RUNNING,1
.equ A_DONE,2
.equ A_CANCELLED,3
.equ A_FAILED,4

.section .rodata
a_n_spawn: .asciz "spawn_agent"
a_n_wait: .asciz "wait_agent"
a_n_list: .asciz "list_agents"
a_n_cancel: .asciz "cancel_agent"
a_n_message: .asciz "send_agent_message"
a_names: .long a_n_spawn-a_names,a_n_wait-a_names,a_n_list-a_names,a_n_cancel-a_names,a_n_message-a_names
a_routes: .long a_spawn-a_routes,a_wait-a_routes,a_list-a_routes,a_cancel-a_routes,a_message-a_routes
a_k_name: .asciz "name"
a_k_prompt: .asciz "prompt"
a_k_id: .asciz "id"
a_k_timeout: .asciz "timeout_seconds"
a_k_mode: .asciz "mode"
a_k_type: .asciz "agent_type"
a_k_subtype: .asciz "subagent_type"
a_general_type: .asciz "general-purpose"
a_statusline_type: .asciz "statusline-setup"
a_explore_type: .asciz "Explore"
a_review_type: .asciz "review-agent"
a_codex_type: .asciz "codex"
a_e_oneshot: .asciz "Error: Codex agents are one-shot; start a new agent instead of sending messages or resuming."
a_k_message: .asciz "message"
a_readonly: .asciz "read-only"
a_inherit: .asciz "inherit"
a_write: .asciz "write"
a_disabled: .asciz "disabled"
a_devnull: .asciz "/dev/null"
a_metadata_prefix: .ascii "@session:"
a_st_running: .asciz "running"
a_st_done: .asciz "completed"
a_st_cancelled: .asciz "cancelled"
a_st_failed: .asciz "failed"
a_statuses: .long a_st_running-a_statuses,a_st_done-a_statuses,a_st_cancelled-a_statuses,a_st_failed-a_statuses
a_e_args: .asciz "Error: invalid subagent arguments."
a_e_mode: .asciz "Error: mode must be read-only, inherit, or write."
a_e_limit: .asciz "Error: concurrent subagent limit reached; wait for an agent before spawning more."
a_e_closed: .asciz "Error: subagent manager is unavailable or closed (recursive delegation is disabled)."
a_e_unknown: .asciz "Error: unknown subagent ID or tool name."
a_e_running: .asciz "Error: agent is still running; wait before sending a followup."
a_e_session: .asciz "Error: no saved session; start a new agent."
a_e_fork: .asciz "Error: native subagent could not be forked."
a_e_capacity: .asciz "Error: subagent output exceeds the caller's buffer."
a_json_id: .ascii "{\"id\":"
.equ a_json_id_len,.-a_json_id
a_json_pid: .ascii ",\"pid\":"
.equ a_json_pid_len,.-a_json_pid
a_json_status: .ascii ",\"status\":"
.equ a_json_status_len,.-a_json_status
a_json_name: .ascii ",\"name\":"
.equ a_json_name_len,.-a_json_name
a_json_session: .ascii ",\"session\":"
.equ a_json_session_len,.-a_json_session
a_json_report: .ascii ",\"report\":"
.equ a_json_report_len,.-a_json_report
a_json_true: .ascii ",\"report_truncated\":true}"
.equ a_json_true_len,.-a_json_true
a_json_false: .ascii ",\"report_truncated\":false}"
.equ a_json_false_len,.-a_json_false
a_open: .ascii "["
.equ a_open_len,.-a_open
a_close: .ascii "]"
.equ a_close_len,.-a_close
a_comma: .ascii ","
.equ a_comma_len,.-a_comma
a_brace: .ascii "}"
.equ a_brace_len,.-a_brace

.section .bss
.align 16
a_entry: .skip 8
a_initialized: .skip 8
a_max: .skip 8
a_next_id: .skip 8
a_jobs: .skip A_SLOTS*A_SIZE
a_args: .skip 8
a_arglen: .skip 8
a_out: .skip 8
a_cap: .skip 8
a_tokens: .skip 32768
a_prompt: .skip 65537
a_child_name: .skip 128
a_child_resume: .skip 4096
a_mode: .skip 32
a_child_policy: .skip 8
a_child_type: .skip 128
a_approval_callback: .skip 8
a_approval_busy: .skip 8
a_approval_pair: .skip 8
a_child_approval_fd: .skip 8
a_approval_packet: .skip 131232
a_approval_reply: .skip 8
a_pipe: .skip 8
a_parent_pid: .skip 8
a_readbuf: .skip 8192
a_pollfds: .skip A_SLOTS*8
a_clock: .skip 16
a_start_sec: .skip 8
a_start_nsec: .skip 8
a_timeout: .skip 8
a_builder: .skip 24
a_number: .skip 32

.section .text
.global agents_init,agents_handles,agents_execute,agents_close
.extern json_parse,json_find,json_decode,qx_strlen,qx_uint,qx_cat,qx_quote_cat

.macro ACAT label
 lea rdi,[rip+a_builder]
 lea rsi,[rip+\label]
 mov edx,OFFSET FLAT:\label\()_len
 call qx_cat@PLT
 test rax,rax
 js .Lsnapshot_bad
.endm

agents_init:
 push rbx
 push r12
 sub rsp,8
 mov rbx,rdi
 mov r12,rsi
 cmp QWORD PTR [rip+a_initialized],0
 je .Linit_bind
 call agents_close
 call a_reset_rows
.Linit_bind:
 call a_reset_rows
 mov QWORD PTR [rip+a_child_approval_fd],-1
 mov QWORD PTR [rip+a_initialized],1
 mov rsi,r12
 mov QWORD PTR [rip+a_entry],rbx
 mov eax,1
 cmp rsi,1
 cmovb rsi,rax
 mov eax,3
 cmp rsi,3
 cmova rsi,rax
 mov QWORD PTR [rip+a_max],rsi
 mov QWORD PTR [rip+a_next_id],1
 xor eax,eax
 add rsp,8
 pop r12
 pop rbx
 ret

# Reset descriptors only: do not touch unrelated private report pages after fork.
a_reset_rows:
 lea rdi,[rip+a_jobs]
 mov ecx,A_SLOTS
.Lreset_row:
 mov QWORD PTR [rdi+A_ID],0
 mov QWORD PTR [rdi+A_PID],0
 mov QWORD PTR [rdi+A_FD],-1
 mov QWORD PTR [rdi+A_APPROVAL],-1
 mov QWORD PTR [rdi+A_POLICY],0
 mov QWORD PTR [rdi+A_STATUS],0
 mov QWORD PTR [rdi+A_REAPED],1
 add rdi,A_SIZE
 dec ecx
 jnz .Lreset_row
 ret

agents_handles:
 test rdi,rdi
 jz .Lhandles_no
 sub rsp,8
 call a_route
 test eax,eax
 setne al
 movzx eax,al
 add rsp,8
 ret
.Lhandles_no:
 xor eax,eax
 ret

a_route:
 push rbx
 push r12
 sub rsp,8
 mov r12,rdi
 xor ebx,ebx
.Lroute_name:
 lea rax,[rip+a_names]
 movsxd rdi,DWORD PTR [rax+rbx*4]
 add rdi,rax
 mov rsi,r12
 call a_equal
 test eax,eax
 jnz .Lroute_found
 inc ebx
 cmp ebx,5
 jb .Lroute_name
 xor eax,eax
 jmp .Lroute_done
.Lroute_found:
 lea eax,[rbx+1]
.Lroute_done:
 add rsp,8
 pop r12
 pop rbx
 ret

a_equal:
 xor eax,eax
.Lequal_byte:
 mov dl,BYTE PTR [rdi+rax]
 cmp dl,BYTE PTR [rsi+rax]
 jne .Lequal_no
 test dl,dl
 jz .Lequal_yes
 inc rax
 jmp .Lequal_byte
.Lequal_yes:
 mov eax,1
 ret
.Lequal_no:
 xor eax,eax
 ret

agents_execute:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 mov QWORD PTR [rip+a_args],rsi
 mov QWORD PTR [rip+a_arglen],rdx
 mov QWORD PTR [rip+a_out],rcx
 mov QWORD PTR [rip+a_cap],r8
 test r12,r12
 jz .Lexecute_internal
 test rcx,rcx
 jz .Lexecute_internal
 cmp r8,2
 jb .Lexecute_internal
 cmp QWORD PTR [rip+a_entry],0
 je .Lexecute_closed
 mov rdi,rsi
 mov rsi,rdx
 lea rdx,[rip+a_tokens]
 mov ecx,1024
 call json_parse@PLT
 test rax,rax
 js .Lexecute_args
 cmp QWORD PTR [rip+a_tokens],JT_OBJECT
 jne .Lexecute_args
 call a_pump_all
 mov rdi,r12
 call a_route
 test eax,eax
 jz .Lexecute_unknown
 dec eax
 lea rdx,[rip+a_routes]
 movsxd rax,DWORD PTR [rdx+rax*4]
 add rax,rdx
 call rax
 jmp .Lexecute_done
.Lexecute_closed:
 lea rdi,[rip+a_e_closed]
 jmp .Lexecute_text
.Lexecute_args:
 lea rdi,[rip+a_e_args]
 jmp .Lexecute_text
.Lexecute_unknown:
 lea rdi,[rip+a_e_unknown]
.Lexecute_text:
 call a_error
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

# Parameter string: keyz,destination,capacity ->len or negative.
a_string:
 push rbx
 push r12
 push r13
 mov rbx,rsi
 mov r12,rdx
 mov rcx,rdi
 mov rdi,QWORD PTR [rip+a_args]
 lea rsi,[rip+a_tokens]
 xor edx,edx
 call json_find@PLT
 test rax,rax
 js .Lstring_bad
 shl rax,5
 lea rdx,[rip+a_tokens]
 add rdx,rax
 cmp QWORD PTR [rdx+T_TYPE],JT_STRING
 jne .Lstring_bad
 mov rsi,QWORD PTR [rdx+T_START]
 add rsi,QWORD PTR [rip+a_args]
 mov rdx,QWORD PTR [rdx+T_LEN]
 mov rdi,rbx
 lea rcx,[r12-1]
 call json_decode@PLT
 test rax,rax
 js .Lstring_bad
 mov r13,rax
 xor ecx,ecx
.Lstring_check:
 cmp rcx,r13
 jae .Lstring_good
 cmp BYTE PTR [rbx+rcx],0
 je .Lstring_bad
 inc rcx
 jmp .Lstring_check
.Lstring_good:
 mov BYTE PTR [rbx+r13],0
 mov rax,r13
 jmp .Lstring_done
.Lstring_bad:
 mov rax,-1
.Lstring_done:
 pop r13
 pop r12
 pop rbx
 ret

# Positive integer parameter; absent/malformed returns-1.
a_integer:
 push rbx
 mov rcx,rdi
 mov rdi,QWORD PTR [rip+a_args]
 lea rsi,[rip+a_tokens]
 xor edx,edx
 call json_find@PLT
 test rax,rax
 js .Linteger_bad
 shl rax,5
 lea rbx,[rip+a_tokens]
 add rbx,rax
 cmp QWORD PTR [rbx+T_TYPE],JT_NUMBER
 jne .Linteger_bad
 mov rcx,QWORD PTR [rbx+T_LEN]
 cmp rcx,18
 ja .Linteger_bad
 mov rsi,QWORD PTR [rbx+T_START]
 add rsi,QWORD PTR [rip+a_args]
 xor eax,eax
.Linteger_digit:
 test rcx,rcx
 jz .Linteger_value
 movzx edx,BYTE PTR [rsi]
 sub edx,48
 cmp edx,9
 ja .Linteger_bad
 imul rax,rax,10
 add rax,rdx
 inc rsi
 dec rcx
 jmp .Linteger_digit
.Linteger_value:
 test rax,rax
 jz .Linteger_bad
 jmp .Linteger_done
.Linteger_bad:
 mov rax,-1
.Linteger_done:
 pop rbx
 ret

a_find_job:
 push rbx
 lea rdi,[rip+a_k_id]
 call a_integer
 test rax,rax
 js .Lfind_bad
 lea rbx,[rip+a_jobs]
 mov ecx,A_SLOTS
.Lfind_row:
 cmp QWORD PTR [rbx+A_ID],rax
 je .Lfind_good
 add rbx,A_SIZE
 dec ecx
 jnz .Lfind_row
.Lfind_bad:
 xor eax,eax
 pop rbx
 ret
.Lfind_good:
 mov rax,rbx
 pop rbx
 ret

a_spawn:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 lea rdi,[rip+a_k_name]
 lea rsi,[rip+a_child_name]
 mov edx,128
 call a_string
 test rax,rax
 jle .Lspawn_args
 lea rdi,[rip+a_k_prompt]
 lea rsi,[rip+a_prompt]
 mov edx,65537
 call a_string
 test rax,rax
 jle .Lspawn_args
 mov QWORD PTR [rip+a_child_policy],0
 # Inherited workers use a parent-owned per-action approval broker.
 mov rdi,QWORD PTR [rip+a_args]
 lea rsi,[rip+a_tokens]
 xor edx,edx
 lea rcx,[rip+a_k_mode]
 call json_find@PLT
 test rax,rax
 js .Lspawn_capacity
 lea rdi,[rip+a_k_mode]
 lea rsi,[rip+a_mode]
 mov edx,32
 call a_string
 test rax,rax
 js .Lspawn_mode
 lea rdi,[rip+a_mode]
 lea rsi,[rip+a_readonly]
 call a_equal
 test eax,eax
 jnz .Lspawn_capacity
 lea rdi,[rip+a_mode]
 lea rsi,[rip+a_inherit]
 call a_equal
 test eax,eax
 jnz .Lspawn_inherited
 lea rdi,[rip+a_mode]
 lea rsi,[rip+a_write]
 call a_equal
 test eax,eax
 jz .Lspawn_mode
.Lspawn_inherited:
 mov QWORD PTR [rip+a_child_policy],1
.Lspawn_capacity:
 mov BYTE PTR [rip+a_child_type],0
 mov rdi,QWORD PTR [rip+a_args]
 lea rsi,[rip+a_tokens]
 xor edx,edx
 lea rcx,[rip+a_k_type]
 call json_find@PLT
 test rax,rax
 js .Lspawn_try_subtype
 lea rdi,[rip+a_k_type]
 jmp .Lspawn_decode_type
.Lspawn_try_subtype:
 mov rdi,QWORD PTR [rip+a_args]
 lea rsi,[rip+a_tokens]
 xor edx,edx
 lea rcx,[rip+a_k_subtype]
 call json_find@PLT
 test rax,rax
 js .Lspawn_type_ready
 lea rdi,[rip+a_k_subtype]
.Lspawn_decode_type:
 lea rsi,[rip+a_child_type]
 mov edx,128
 call a_string
 test rax,rax
 jle .Lspawn_args
 # Explicit named general/statusline agents inherit policy. Explore
 # never acquires mutation privileges through a conflicting mode parameter.
 lea rdi,[rip+a_child_type]
 lea rsi,[rip+a_explore_type]
 call a_equal
 test eax,eax
 jnz .Lspawn_force_readonly
 mov QWORD PTR [rip+a_child_policy],1
 jmp .Lspawn_type_ready
.Lspawn_force_readonly:
 mov QWORD PTR [rip+a_child_policy],0
.Lspawn_type_ready:
 call a_running_count
 cmp rax,QWORD PTR [rip+a_max]
 jae .Lspawn_limit
 lea r12,[rip+a_jobs]
 xor ebx,ebx
.Lspawn_slot:
 cmp QWORD PTR [r12+A_ID],0
 je .Lspawn_selected
 add r12,A_SIZE
 inc ebx
 cmp ebx,A_SLOTS
 jb .Lspawn_slot
 lea r12,[rip+a_jobs]
 xor ebx,ebx
 xor r13d,r13d
 mov r14,-1
.Lspawn_recycle:
 cmp QWORD PTR [r12+A_REAPED],0
 je .Lspawn_recycle_next
 mov rax,QWORD PTR [r12+A_ID]
 cmp rax,r14
 jae .Lspawn_recycle_next
 mov r14,rax
 mov r13,r12
.Lspawn_recycle_next:
 add r12,A_SIZE
 inc ebx
 cmp ebx,A_SLOTS
 jb .Lspawn_recycle
 test r13,r13
 jz .Lspawn_limit
 mov r12,r13
.Lspawn_selected:
 mov rdi,r12
 call a_clear_job
 mov rax,QWORD PTR [rip+a_child_policy]
 mov QWORD PTR [r12+A_POLICY],rax
 lea rdi,[r12+A_TYPE]
 lea rsi,[rip+a_child_type]
 call a_copy_z
 mov rax,QWORD PTR [rip+a_next_id]
 mov QWORD PTR [r12+A_ID],rax
 inc QWORD PTR [rip+a_next_id]
 lea rdi,[r12+A_NAME]
 lea rsi,[rip+a_child_name]
 call a_copy_z
 mov BYTE PTR [rip+a_child_resume],0
 mov rdi,r12
 call a_launch
 test rax,rax
 js .Lspawn_fork
 mov rdi,r12
 call a_snapshot
 jmp .Lspawn_done
.Lspawn_args:
 lea rdi,[rip+a_e_args]
 jmp .Lspawn_error
.Lspawn_mode:
 lea rdi,[rip+a_e_mode]
 jmp .Lspawn_error
.Lspawn_limit:
 lea rdi,[rip+a_e_limit]
 jmp .Lspawn_error
.Lspawn_fork:
 lea rdi,[rip+a_e_fork]
.Lspawn_error:
 call a_error
.Lspawn_done:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

a_clear_job:
 mov r8,rdi
 mov rdi,QWORD PTR [r8+A_APPROVAL]
 cmp rdi,0
 jl .Lclear_approval_done
 mov eax,3
 syscall
.Lclear_approval_done:
 mov rdi,r8
 mov QWORD PTR [rdi+A_APPROVAL],-1
 mov QWORD PTR [rdi+A_PID],0
 mov QWORD PTR [rdi+A_FD],-1
 mov QWORD PTR [rdi+A_STATUS],0
 mov QWORD PTR [rdi+A_EXIT],0
 mov QWORD PTR [rdi+A_RLEN],0
 mov QWORD PTR [rdi+A_MLEN],0
 mov QWORD PTR [rdi+A_META],0
 mov QWORD PTR [rdi+A_REAPED],1
 mov QWORD PTR [rdi+A_TRUNC],0
 mov BYTE PTR [rdi+A_SESSION],0
 mov BYTE PTR [rdi+A_REPORT],0
 ret

a_copy_z:
 mov al,BYTE PTR [rsi]
 mov BYTE PTR [rdi],al
 inc rsi
 inc rdi
 test al,al
 jnz a_copy_z
 ret

# Public nonblocking refresh/count for session-switch guards.
.global agents_running_count
agents_running_count:
 sub rsp,8
 call a_pump_all
 add rsp,8
 jmp a_running_count

a_running_count:
 lea rdx,[rip+a_jobs]
 xor eax,eax
 mov ecx,A_SLOTS
.Lrunning_row:
 cmp QWORD PTR [rdx+A_STATUS],A_RUNNING
 jne .Lrunning_next
 cmp QWORD PTR [rdx+A_REAPED],0
 jne .Lrunning_next
 inc eax
.Lrunning_next:
 add rdx,A_SIZE
 dec ecx
 jnz .Lrunning_row
 ret

# Launch a worker for the prepared prompt/name/resume, preserving one job row.
a_launch:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov eax,39
 syscall
 mov QWORD PTR [rip+a_parent_pid],rax
 mov QWORD PTR [rip+a_approval_pair],-1
 cmp QWORD PTR [r12+A_POLICY],0
 je .Llaunch_pipe
 mov eax,53
 mov edi,1
 mov esi,0x80805
 xor edx,edx
 lea r10,[rip+a_approval_pair]
 syscall
 test rax,rax
 js .Llaunch_failed
.Llaunch_pipe:
 lea rdi,[rip+a_pipe]
 mov esi,0x80800
 mov eax,293
 syscall
 test rax,rax
 js .Llaunch_pair_failed
 mov eax,57
 syscall
 test rax,rax
 jz .Llaunch_child
 js .Llaunch_close_failed
 mov rbx,rax
 mov edi,DWORD PTR [rip+a_approval_pair+4]
 cmp edi,0
 jl .Llaunch_no_child_broker
 mov eax,3
 syscall
.Llaunch_no_child_broker:
 movsxd rax,DWORD PTR [rip+a_approval_pair]
 mov QWORD PTR [r12+A_APPROVAL],rax
 mov rdi,rbx
 mov rsi,rbx
 mov eax,109
 syscall
 mov edi,DWORD PTR [rip+a_pipe+4]
 mov eax,3
 syscall
 mov eax,DWORD PTR [rip+a_pipe]
 mov QWORD PTR [r12+A_FD],rax
 mov QWORD PTR [r12+A_PID],rbx
 mov QWORD PTR [r12+A_REAPED],0
 mov QWORD PTR [r12+A_STATUS],A_RUNNING
 xor eax,eax
 jmp .Llaunch_done
.Llaunch_close_failed:
 mov edi,DWORD PTR [rip+a_pipe]
 mov eax,3
 syscall
 mov edi,DWORD PTR [rip+a_pipe+4]
 mov eax,3
 syscall
.Llaunch_pair_failed:
 mov edi,DWORD PTR [rip+a_approval_pair]
 cmp edi,0
 jl .Llaunch_pair_right
 mov eax,3
 syscall
.Llaunch_pair_right:
 mov edi,DWORD PTR [rip+a_approval_pair+4]
 cmp edi,0
 jl .Llaunch_failed
 mov eax,3
 syscall
.Llaunch_failed:
 mov QWORD PTR [r12+A_STATUS],A_FAILED
 mov rax,-1
.Llaunch_done:
 pop r13
 pop r12
 pop rbx
 ret
.Llaunch_child:
 mov r13,QWORD PTR [rip+a_entry]
 mov rax,QWORD PTR [r12+A_POLICY]
 mov QWORD PTR [rip+a_child_policy],rax
 lea rdi,[rip+a_child_type]
 lea rsi,[r12+A_TYPE]
 call a_copy_z
 mov edi,DWORD PTR [rip+a_approval_pair]
 cmp edi,0
 jl .Lchild_broker_ready
 mov eax,3
 syscall
.Lchild_broker_ready:
 movsxd rdi,DWORD PTR [rip+a_approval_pair+4]
 mov QWORD PTR [rip+a_child_approval_fd],rdi
 cmp rdi,0
 jl .Lchild_broker_bound
 mov eax,72
 mov esi,4
 xor edx,edx
 syscall
.Lchild_broker_bound:
 # Bind kernel parent-death cleanup before any worker I/O or callback.
 mov edi,1
 mov esi,9
 xor edx,edx
 xor r10d,r10d
 xor r8d,r8d
 mov eax,157
 syscall
 test rax,rax
 js .Lchild_exit_error
 mov eax,110
 syscall
 cmp rax,QWORD PTR [rip+a_parent_pid]
 jne .Lchild_exit_error
 xor edi,edi
 xor esi,esi
 mov eax,109
 syscall
 # Close every inherited parent read endpoint before private state is reset.
 lea rbx,[rip+a_jobs]
 mov r12d,A_SLOTS
.Lchild_close_rows:
 mov rdi,QWORD PTR [rbx+A_FD]
 cmp rdi,0
 jl .Lchild_next_row
 mov eax,3
 syscall
.Lchild_next_row:
 mov rdi,QWORD PTR [rbx+A_APPROVAL]
 cmp rdi,0
 jl .Lchild_next_broker
 mov eax,3
 syscall
.Lchild_next_broker:
 add rbx,A_SIZE
 dec r12d
 jnz .Lchild_close_rows
 mov edi,DWORD PTR [rip+a_pipe]
 mov eax,3
 syscall
 # Clear O_NONBLOCK only on the worker's write endpoint, then route stdout.
 mov edi,DWORD PTR [rip+a_pipe+4]
 mov esi,4
 xor edx,edx
 mov eax,72
 syscall
 mov edi,DWORD PTR [rip+a_pipe+4]
 mov esi,1
 mov eax,33
 syscall
 mov edi,DWORD PTR [rip+a_pipe+4]
 cmp edi,2
 jle .Lchild_null
 mov eax,3
 syscall
.Lchild_null:
 lea rdi,[rip+a_devnull]
 mov esi,0x80002
 xor edx,edx
 mov eax,2
 syscall
 test rax,rax
 js .Lchild_exit_error
 mov rbx,rax
 mov rdi,rax
 xor esi,esi
 mov eax,33
 syscall
 mov rdi,rbx
 mov esi,2
 mov eax,33
 syscall
 cmp rbx,2
 jle .Lchild_reset
 mov rdi,rbx
 mov eax,3
 syscall
.Lchild_reset:
 call a_reset_rows
 mov QWORD PTR [rip+a_entry],0
 lea rdi,[rip+a_prompt]
 xor esi,esi
 cmp BYTE PTR [rip+a_child_resume],0
 je .Lchild_callback
 lea rsi,[rip+a_child_resume]
.Lchild_callback:
 lea rdx,[rip+a_child_name]
 mov rcx,QWORD PTR [rip+a_child_policy]
 lea r8,[rip+a_child_type]
 call r13
.Lchild_exit_error:
 mov edi,1
 mov eax,60
 syscall

# Drain all ready pipes; then reap completed children without blocking.
a_pump_all:
 push rbx
 push r12
 sub rsp,8
 call agents_service_approvals
 lea r12,[rip+a_jobs]
 mov ebx,A_SLOTS
.Lpump_row:
 cmp QWORD PTR [r12+A_ID],0
 je .Lpump_next
 mov rdi,r12
 call a_collect
.Lpump_next:
 add r12,A_SIZE
 dec ebx
 jnz .Lpump_row
 add rsp,8
 pop r12
 pop rbx
 ret

a_collect:
 push rbx
 push r12
 push r13
 mov r12,rdi
.Lcollect_read:
 mov rdi,QWORD PTR [r12+A_FD]
 cmp rdi,0
 jl .Lcollect_wait
 lea rsi,[rip+a_readbuf]
 mov edx,8192
 xor eax,eax
 syscall
 cmp rax,-4
 je .Lcollect_read
 cmp rax,-11
 je .Lcollect_wait
 test rax,rax
 jle .Lcollect_eof
 mov r13,rax
 xor ebx,ebx
.Lcollect_bytes:
 lea rdx,[rip+a_readbuf]
 movzx esi,BYTE PTR [rdx+rbx]
 mov rdi,r12
 call a_capture
 inc rbx
 cmp rbx,r13
 jb .Lcollect_bytes
 jmp .Lcollect_read
.Lcollect_eof:
 mov rdi,QWORD PTR [r12+A_FD]
 mov eax,3
 syscall
 mov QWORD PTR [r12+A_FD],-1
.Lcollect_wait:
 cmp QWORD PTR [r12+A_REAPED],0
 jne .Lcollect_finalize
 mov rdi,QWORD PTR [r12+A_PID]
 cmp rdi,0
 jle .Lcollect_done
 lea rsi,[r12+A_EXIT]
 mov edx,1
 xor r10d,r10d
 mov eax,61
 syscall
 cmp rax,QWORD PTR [r12+A_PID]
 jne .Lcollect_done
 mov QWORD PTR [r12+A_REAPED],1
 # A finished worker may have used an external native/CLI executor. Kill any
 # remaining members of its owned group before final drain; they cannot become
 # detached or hold the report pipe after the worker has finished.
 mov rdi,QWORD PTR [r12+A_PID]
 neg rdi
 mov esi,9
 mov eax,62
 syscall
 # Once reaped no worker can add bytes; drain before classifying metadata.
 cmp QWORD PTR [r12+A_FD],0
 jge .Lcollect_read
.Lcollect_finalize:
 cmp QWORD PTR [r12+A_ID],0
 je .Lcollect_done
 cmp QWORD PTR [r12+A_STATUS],A_CANCELLED
 je .Lcollect_done
 mov QWORD PTR [r12+A_STATUS],A_DONE
 cmp DWORD PTR [r12+A_EXIT],0
 jne .Lcollect_failed
 cmp QWORD PTR [r12+A_META],1
 je .Lcollect_done
 cmp QWORD PTR [r12+A_META],3
 je .Lcollect_done
.Lcollect_failed:
 mov QWORD PTR [r12+A_STATUS],A_FAILED
.Lcollect_done:
 pop r13
 pop r12
 pop rbx
 ret

# Capture trusted first-line metadata separately, then a bounded report.
a_capture:
 push rbx
 mov rbx,rdi
 cmp QWORD PTR [rbx+A_META],0
 jne .Lcapture_report
 cmp sil,10
 je .Lcapture_metadata
 mov rax,QWORD PTR [rbx+A_MLEN]
 cmp rax,4104
 jae .Lcapture_bad_meta
 lea rdx,[rbx+A_REPORT]
 mov BYTE PTR [rdx+rax],sil
 inc QWORD PTR [rbx+A_MLEN]
 jmp .Lcapture_done
.Lcapture_metadata:
 mov rcx,QWORD PTR [rbx+A_MLEN]
 cmp rcx,9
 jb .Lcapture_bad_meta
 lea rsi,[rbx+A_REPORT]
 lea rdi,[rip+a_metadata_prefix]
 push rcx
 mov ecx,9
 repe cmpsb
 pop rcx
 jne .Lcapture_bad_meta
 sub rcx,9
 cmp rcx,4095
 ja .Lcapture_bad_meta
 test rcx,rcx
 jz .Lcapture_stateless
 lea rsi,[rbx+A_REPORT+9]
 cmp BYTE PTR [rsi],47
 je .Lcapture_path_start
 cmp rcx,8
 jne .Lcapture_bad_meta
 lea rdi,[rip+a_disabled]
 push rcx
 mov ecx,8
 repe cmpsb
 pop rcx
 jne .Lcapture_bad_meta
.Lcapture_stateless:
 mov QWORD PTR [rbx+A_META],3
 mov BYTE PTR [rbx+A_SESSION],0
 jmp .Lcapture_done
.Lcapture_path_start:
 lea rdi,[rbx+A_SESSION]
 xor r8d,r8d
.Lcapture_path:
 cmp r8,rcx
 jae .Lcapture_meta_done
 mov al,BYTE PTR [rsi+r8]
 cmp al,32
 jb .Lcapture_bad_meta
 cmp al,127
 je .Lcapture_bad_meta
 mov BYTE PTR [rdi+r8],al
 inc r8
 jmp .Lcapture_path
.Lcapture_meta_done:
 mov BYTE PTR [rdi+rcx],0
 mov QWORD PTR [rbx+A_META],1
 jmp .Lcapture_done
.Lcapture_bad_meta:
 mov QWORD PTR [rbx+A_META],2
 mov BYTE PTR [rbx+A_SESSION],0
 jmp .Lcapture_done
.Lcapture_report:
 mov rax,QWORD PTR [rbx+A_RLEN]
 cmp rax,65536
 jae .Lcapture_truncate
 lea rdx,[rbx+A_REPORT]
 mov BYTE PTR [rdx+rax],sil
 inc rax
 mov QWORD PTR [rbx+A_RLEN],rax
 mov BYTE PTR [rdx+rax],0
 jmp .Lcapture_done
.Lcapture_truncate:
 mov QWORD PTR [rbx+A_TRUNC],1
.Lcapture_done:
 pop rbx
 ret

# Return one job as JSON. Report clipping is explicit and leaves validUTF8/JSON.
a_snapshot:
 push rbx
 push r12
 push r13
 mov r12,rdi
 call a_builder_begin
 ACAT a_json_id
 mov rdi,QWORD PTR [r12+A_ID]
 call a_append_number
 test rax,rax
 js .Lsnapshot_bad
 ACAT a_json_pid
 mov rdi,QWORD PTR [r12+A_PID]
 call a_append_number
 test rax,rax
 js .Lsnapshot_bad
 ACAT a_json_status
 mov rdi,r12
 call a_append_status
 test rax,rax
 js .Lsnapshot_bad
 ACAT a_json_name
 lea rdi,[r12+A_NAME]
 call a_append_string
 test rax,rax
 js .Lsnapshot_bad
 ACAT a_json_session
 lea rdi,[r12+A_SESSION]
 call a_append_string
 test rax,rax
 js .Lsnapshot_bad
 ACAT a_json_report
 mov rbx,QWORD PTR [rip+a_builder+8]
 sub rbx,QWORD PTR [rip+a_builder+16]
 cmp rbx,64
 jb .Lsnapshot_bad
 sub rbx,64
 mov rax,rbx
 xor edx,edx
 mov ecx,6
 div rcx
 mov rbx,rax
 cmp rbx,QWORD PTR [r12+A_RLEN]
 cmova rbx,QWORD PTR [r12+A_RLEN]
 mov r13,QWORD PTR [r12+A_TRUNC]
 cmp rbx,QWORD PTR [r12+A_RLEN]
 je .Lsnapshot_report
 mov r13d,1
.Lsnapshot_report:
 lea rdi,[r12+A_REPORT]
 mov rsi,rbx
 call a_safe_prefix
 mov rbx,rax
 lea rdi,[rip+a_builder]
 lea rsi,[r12+A_REPORT]
 mov rdx,rbx
 call qx_quote_cat@PLT
 test rax,rax
 js .Lsnapshot_bad
 test r13,r13
 jz .Lsnapshot_false
 ACAT a_json_true
 jmp .Lsnapshot_end
.Lsnapshot_false:
 ACAT a_json_false
.Lsnapshot_end:
 call a_builder_end
 jmp .Lsnapshot_done
.Lsnapshot_bad:
 lea rdi,[rip+a_e_capacity]
 call a_error
.Lsnapshot_done:
 pop r13
 pop r12
 pop rbx
 ret

a_builder_begin:
 mov rax,QWORD PTR [rip+a_out]
 mov QWORD PTR [rip+a_builder],rax
 mov rax,QWORD PTR [rip+a_cap]
 dec rax
 mov QWORD PTR [rip+a_builder+8],rax
 mov QWORD PTR [rip+a_builder+16],0
 ret

a_builder_end:
 mov rax,QWORD PTR [rip+a_builder+16]
 mov rdx,QWORD PTR [rip+a_out]
 mov BYTE PTR [rdx+rax],0
 ret

a_append_number:
 push rbx
 mov rsi,rdi
 lea rdi,[rip+a_number]
 call qx_uint@PLT
 mov rdx,rax
 lea rsi,[rip+a_number]
 lea rdi,[rip+a_builder]
 call qx_cat@PLT
 pop rbx
 ret

a_append_status:
 mov rax,QWORD PTR [rdi+A_STATUS]
 dec rax
 cmp rax,3
 ja .Lstatus_bad
 lea rdx,[rip+a_statuses]
 movsxd rdi,DWORD PTR [rdx+rax*4]
 add rdi,rdx
 jmp a_append_string
.Lstatus_bad:
 lea rdi,[rip+a_st_failed]
 jmp a_append_string

a_append_string:
 push rbx
 mov rbx,rdi
 call qx_strlen@PLT
 mov rdx,rax
 mov rsi,rbx
 lea rdi,[rip+a_builder]
 call qx_quote_cat@PLT
 pop rbx
 ret

# Largest complete UTF8 prefix at or before requested length.
a_safe_prefix:
 mov rax,rsi
 test rsi,rsi
 jz .Lsafe_done
 lea rcx,[rsi-1]
 mov r8,rcx
.Lsafe_back:
 movzx edx,BYTE PTR [rdi+rcx]
 and edx,0xc0
 cmp edx,0x80
 jne .Lsafe_lead
 test rcx,rcx
 jz .Lsafe_empty
 dec rcx
 jmp .Lsafe_back
.Lsafe_lead:
 movzx edx,BYTE PTR [rdi+rcx]
 mov r9d,1
 cmp edx,0xc0
 jb .Lsafe_width
 mov r9d,2
 cmp edx,0xe0
 jb .Lsafe_width
 mov r9d,3
 cmp edx,0xf0
 jb .Lsafe_width
 mov r9d,4
.Lsafe_width:
 sub rsi,rcx
 cmp rsi,r9
 jae .Lsafe_done
 mov rax,rcx
 ret
.Lsafe_empty:
 xor eax,eax
.Lsafe_done:
 ret

a_error:
 push rbx
 mov rbx,rdi
 call qx_strlen@PLT
 mov rcx,QWORD PTR [rip+a_cap]
 dec rcx
 cmp rax,rcx
 cmova rax,rcx
 mov rcx,rax
 mov rsi,rbx
 mov rdi,QWORD PTR [rip+a_out]
 rep movsb
 mov BYTE PTR [rdi],0
 pop rbx
 ret

a_list:
 push rbx
 push r12
 push r13
 call a_builder_begin
 ACAT a_open
 lea r12,[rip+a_jobs]
 mov ebx,A_SLOTS
 xor r13d,r13d
.Llist_row:
 cmp QWORD PTR [r12+A_ID],0
 je .Llist_next
 test r13d,r13d
 jz .Llist_no_comma
 ACAT a_comma
.Llist_no_comma:
 ACAT a_json_id
 mov rdi,QWORD PTR [r12+A_ID]
 call a_append_number
 test rax,rax
 js .Llist_bad
 ACAT a_json_status
 mov rdi,r12
 call a_append_status
 test rax,rax
 js .Llist_bad
 ACAT a_json_name
 lea rdi,[r12+A_NAME]
 call a_append_string
 test rax,rax
 js .Llist_bad
 ACAT a_brace
 inc r13d
.Llist_next:
 add r12,A_SIZE
 dec ebx
 jnz .Llist_row
 ACAT a_close
 call a_builder_end
 jmp .Llist_done
.Llist_bad:
 lea rdi,[rip+a_e_capacity]
 call a_error
.Llist_done:
 pop r13
 pop r12
 pop rbx
 ret

a_wait:
 push rbx
 push r12
 sub rsp,8
 call a_find_job
 test rax,rax
 jz .Lwait_unknown
 mov r12,rax
 mov QWORD PTR [rip+a_timeout],30
 mov rdi,QWORD PTR [rip+a_args]
 lea rsi,[rip+a_tokens]
 xor edx,edx
 lea rcx,[rip+a_k_timeout]
 call json_find@PLT
 test rax,rax
 js .Lwait_time_default
 lea rdi,[rip+a_k_timeout]
 call a_integer
 test rax,rax
 js .Lwait_args
 cmp rax,120
 ja .Lwait_args
 mov QWORD PTR [rip+a_timeout],rax
.Lwait_time_default:
 mov edi,1
 lea rsi,[rip+a_clock]
 mov eax,228
 syscall
 test rax,rax
 js .Lwait_args
 mov rax,QWORD PTR [rip+a_clock]
 mov QWORD PTR [rip+a_start_sec],rax
 mov rax,QWORD PTR [rip+a_clock+8]
 mov QWORD PTR [rip+a_start_nsec],rax
.Lwait_loop:
 call a_pump_all
 cmp QWORD PTR [r12+A_STATUS],A_RUNNING
 jne .Lwait_snapshot
 mov edi,1
 lea rsi,[rip+a_clock]
 mov eax,228
 syscall
 mov rax,QWORD PTR [rip+a_clock]
 sub rax,QWORD PTR [rip+a_start_sec]
 cmp rax,QWORD PTR [rip+a_timeout]
 ja .Lwait_snapshot
 jb .Lwait_poll
 mov rax,QWORD PTR [rip+a_clock+8]
 cmp rax,QWORD PTR [rip+a_start_nsec]
 jae .Lwait_snapshot
.Lwait_poll:
 call a_poll
 jmp .Lwait_loop
.Lwait_snapshot:
 mov rdi,r12
 call a_snapshot
 jmp .Lwait_done
.Lwait_args:
 lea rdi,[rip+a_e_args]
 jmp .Lwait_error
.Lwait_unknown:
 lea rdi,[rip+a_e_unknown]
.Lwait_error:
 call a_error
.Lwait_done:
 add rsp,8
 pop r12
 pop rbx
 ret

a_poll:
 lea rdi,[rip+a_jobs]
 lea rsi,[rip+a_pollfds]
 mov ecx,A_SLOTS
.Lpoll_row:
 mov rax,QWORD PTR [rdi+A_FD]
 mov rdx,-1
 cmp QWORD PTR [rdi+A_ID],0
 cmove rax,rdx
 mov DWORD PTR [rsi],eax
 mov WORD PTR [rsi+4],1
 mov WORD PTR [rsi+6],0
 add rdi,A_SIZE
 add rsi,8
 dec ecx
 jnz .Lpoll_row
 lea rdi,[rip+a_pollfds]
 mov esi,A_SLOTS
 mov edx,50
 mov eax,7
 syscall
 ret

a_cancel:
 push rbx
 call a_find_job
 test rax,rax
 jz .Lcancel_unknown
 mov rbx,rax
 mov rdi,rbx
 call a_cancel_job
 mov rdi,rbx
 call a_snapshot
 pop rbx
 ret
.Lcancel_unknown:
 lea rdi,[rip+a_e_unknown]
 call a_error
 pop rbx
 ret

a_cancel_job:
 push rbx
 mov rbx,rdi
 cmp QWORD PTR [rbx+A_REAPED],0
 jne .Lcancel_job_done
 mov rdi,QWORD PTR [rbx+A_PID]
 test rdi,rdi
 jle .Lcancel_job_done
 neg rdi
 mov esi,9
 mov eax,62
 syscall
 mov QWORD PTR [rbx+A_STATUS],A_CANCELLED
.Lcancel_reap:
 mov rdi,QWORD PTR [rbx+A_PID]
 lea rsi,[rbx+A_EXIT]
 xor edx,edx
 xor r10d,r10d
 mov eax,61
 syscall
 cmp rax,-4
 je .Lcancel_reap
 mov QWORD PTR [rbx+A_REAPED],1
 mov rdi,rbx
 call a_collect
.Lcancel_job_done:
 pop rbx
 ret

a_message:
 push rbx
 push r12
 sub rsp,8
 call a_find_job
 test rax,rax
 jz .Lmessage_unknown
 mov r12,rax
 lea rdi,[r12+A_TYPE]
 lea rsi,[rip+a_codex_type]
 call a_equal
 test eax,eax
 jnz .Lmessage_oneshot
 cmp QWORD PTR [r12+A_REAPED],0
 je .Lmessage_running
 cmp QWORD PTR [r12+A_META],1
 jne .Lmessage_session
 lea rdi,[rip+a_k_message]
 lea rsi,[rip+a_prompt]
 mov edx,65537
 call a_string
 test rax,rax
 jle .Lmessage_args
 call a_running_count
 cmp rax,QWORD PTR [rip+a_max]
 jae .Lmessage_limit
 lea rdi,[rip+a_child_name]
 lea rsi,[r12+A_NAME]
 call a_copy_z
 lea rdi,[rip+a_child_resume]
 lea rsi,[r12+A_SESSION]
 call a_copy_z
 mov rdi,r12
 call a_clear_job
 mov rdi,r12
 call a_launch
 test rax,rax
 js .Lmessage_fork
 mov rdi,r12
 call a_snapshot
 jmp .Lmessage_done
.Lmessage_oneshot:
 lea rdi,[rip+a_e_oneshot]
 jmp .Lmessage_error
.Lmessage_unknown:
 lea rdi,[rip+a_e_unknown]
 jmp .Lmessage_error
.Lmessage_running:
 lea rdi,[rip+a_e_running]
 jmp .Lmessage_error
.Lmessage_session:
 lea rdi,[rip+a_e_session]
 jmp .Lmessage_error
.Lmessage_args:
 lea rdi,[rip+a_e_args]
 jmp .Lmessage_error
.Lmessage_limit:
 lea rdi,[rip+a_e_limit]
 jmp .Lmessage_error
.Lmessage_fork:
 lea rdi,[rip+a_e_fork]
.Lmessage_error:
 call a_error
.Lmessage_done:
 add rsp,8
 pop r12
 pop rbx
 ret

agents_close:
 push rbx
 push r12
 sub rsp,8
 mov QWORD PTR [rip+a_entry],0
 lea r12,[rip+a_jobs]
 mov ebx,A_SLOTS
.Lclose_row:
 cmp QWORD PTR [r12+A_ID],0
 je .Lclose_broker_done
 mov rdi,r12
 call a_cancel_job
 mov rdi,QWORD PTR [r12+A_FD]
 cmp rdi,0
 jl .Lclose_next
 mov eax,3
 syscall
 mov QWORD PTR [r12+A_FD],-1
.Lclose_next:
 mov rdi,QWORD PTR [r12+A_APPROVAL]
 cmp rdi,0
 jl .Lclose_broker_done
 mov eax,3
 syscall
 mov QWORD PTR [r12+A_APPROVAL],-1
.Lclose_broker_done:
 add r12,A_SIZE
 dec ebx
 jnz .Lclose_row
 add rsp,8
 pop r12
 pop rbx
 ret

.section .note.GNU-stack,"",@progbits

.section .text
.global agents_set_approval,agents_service_approvals,agents_request_approval
agents_set_approval:
 mov [rip+a_approval_callback],rdi
 xor eax,eax
 ret
# Parent services bounded SOCK_SEQPACKET requests, never worker code callbacks.
# callback(previewZ,toolNameZ,argsPtr,argsLen)->0deny/1allow. Guard nested UI ticks.
agents_service_approvals:
 push rbx
 push r12
 push r13
 push r14
 push r15
 cmp QWORD PTR [rip+a_approval_busy],0
 jne .Lapproval_service_zero
 mov QWORD PTR [rip+a_approval_busy],1
 xor r15d,r15d
 lea r12,[rip+a_jobs]
 mov r13d,A_SLOTS
.Lapproval_service_row:
 cmp QWORD PTR [r12+A_ID],0
 je .Lapproval_service_next
 mov rdi,[r12+A_APPROVAL]
 cmp rdi,0
 jl .Lapproval_service_next
 mov eax,45
 lea rsi,[rip+a_approval_packet]
 mov edx,131232
 mov r10d,0x60 # DONTWAIT|TRUNC: oversize packets are denied, never truncated grants
 xor r8d,r8d
 xor r9d,r9d
 syscall
 cmp rax,-4
 je .Lapproval_service_row
 cmp rax,-11
 je .Lapproval_service_next
 test rax,rax
 jle .Lapproval_service_close
 mov r14,rax
 xor ebx,ebx
 cmp rax,131232
 ja .Lapproval_service_reply
 cmp rax,26
 jb .Lapproval_service_reply
 lea rax,[rip+a_approval_packet]
 mov rcx,[rax]
 cmp rcx,65535
 ja .Lapproval_service_reply
 mov rdx,[rax+8]
 cmp rdx,127
 ja .Lapproval_service_reply
 mov r8,[rax+16]
 cmp r8,65535
 ja .Lapproval_service_reply
 lea r9,[rcx+rdx+26]
 add r9,r8
 cmp r9,r14
 jne .Lapproval_service_reply
 lea rdi,[rax+24]
 cmp BYTE PTR [rdi+rcx],0
 jne .Lapproval_service_reply
 lea rsi,[rdi+rcx+1]
 cmp BYTE PTR [rsi+rdx],0
 jne .Lapproval_service_reply
 lea rdx,[rsi+rdx+1]
 mov rcx,r8
 mov rax,[rip+a_approval_callback]
 test rax,rax
 jz .Lapproval_service_reply
 call rax
 cmp eax,1
 sete bl
.Lapproval_service_reply:
 mov [rip+a_approval_reply],bl
 mov eax,44
 mov rdi,[r12+A_APPROVAL]
 lea rsi,[rip+a_approval_reply]
 mov edx,1
 mov r10d,0x4040 # NOSIGNAL|DONTWAIT
 xor r8d,r8d
 xor r9d,r9d
 syscall
 inc r15
 jmp .Lapproval_service_next
.Lapproval_service_close:
 mov eax,3
 mov rdi,[r12+A_APPROVAL]
 syscall
 mov QWORD PTR [r12+A_APPROVAL],-1
.Lapproval_service_next:
 add r12,A_SIZE
 dec r13d
 jnz .Lapproval_service_row
 mov QWORD PTR [rip+a_approval_busy],0
 mov rax,r15
 jmp .Lapproval_service_done
.Lapproval_service_zero:
 xor eax,eax
.Lapproval_service_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Child only, blocks until parent policy answer. EOF/oversize/any error deny.
# previewZ,toolNameZ,argsPtr,argsLen ->1allowed/0denied.
agents_request_approval:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 cmp QWORD PTR [rip+a_child_approval_fd],0
 jl .Lapproval_request_deny
 test rdi,rdi
 jz .Lapproval_request_deny
 test rsi,rsi
 jz .Lapproval_request_deny
 cmp rcx,65535
 ja .Lapproval_request_deny
 test rdx,rdx
 jz .Lapproval_request_deny
 xor ebx,ebx
.Lapproval_preview_len:
 cmp ebx,65535
 jae .Lapproval_request_deny
 cmp BYTE PTR [r12+rbx],0
 je .Lapproval_preview_done
 inc ebx
 jmp .Lapproval_preview_len
.Lapproval_preview_done:
 xor ecx,ecx
.Lapproval_name_len:
 cmp ecx,127
 jae .Lapproval_request_deny
 cmp BYTE PTR [r13+rcx],0
 je .Lapproval_name_done
 inc ecx
 jmp .Lapproval_name_len
.Lapproval_name_done:
 lea rdi,[rip+a_approval_packet]
 mov [rdi],rbx
 mov [rdi+8],rcx
 mov [rdi+16],r15
 mov r8,rcx
 add rdi,24
 mov rsi,r12
 lea rcx,[rbx+1]
 rep movsb
 mov rsi,r13
 lea rcx,[r8+1]
 rep movsb
 mov rsi,r14
 mov rcx,r15
 rep movsb
 lea rsi,[rip+a_approval_packet]
 mov rdx,rdi
 sub rdx,rsi
 mov r14,rdx
 mov eax,44
 mov rdi,[rip+a_child_approval_fd]
 mov r10d,0x4000
 xor r8d,r8d
 xor r9d,r9d
 syscall
 cmp rax,r14
 jne .Lapproval_request_deny
.Lapproval_read_reply:
 xor eax,eax
 mov rdi,[rip+a_child_approval_fd]
 lea rsi,[rip+a_approval_reply]
 mov edx,1
 syscall
 cmp rax,-4
 je .Lapproval_read_reply
 cmp rax,1
 jne .Lapproval_request_deny
 xor eax,eax
 cmp BYTE PTR [rip+a_approval_reply],1
 sete al
 jmp .Lapproval_request_done
.Lapproval_request_deny:
 xor eax,eax
.Lapproval_request_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
