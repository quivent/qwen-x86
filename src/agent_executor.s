# Native JSON-RPC adapters for explicitly selected installed external agents.
# Core stays syscall-only. External CLIs keep their own authentication/settings.
.include "abi.inc"
.macro EFRAME label,text
\label: .ascii "\text"
.equ \label\()_len,.-\label
.endm
.macro ECAT label
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+\label]
 mov edx,OFFSET FLAT:\label\()_len
 call qx_cat@PLT
 test rax,rax
 js .Ex_protocol_fail
.endm
.section .rodata
.Ex_codex: .asciz "codex"
.Ex_claude: .asciz "claude-code"
.Ex_acp_command: .asciz "claude-agent-acp"
.Ex_path_key: .asciz "PATH="
.Ex_path_default: .asciz "/usr/local/bin:/usr/bin:/bin"
.Ex_app_server: .asciz "app-server"
.Ex_stdio: .asciz "--stdio"
.Ex_null: .asciz "/dev/null"
.Ex_secrets: .asciz "QWEN_SERVER_TOKEN="
.asciz "QWEN_DAEMON_TOKEN="
.asciz "QWEN_CODE_EXTERNAL_TOOL_GUARD_TOKEN="
.asciz "QWEN_CODE_PRIVATE_ACP_CAPABILITY="
.asciz "CODEX_THREAD_ID="
.asciz "CLAUDECODE="
.asciz "NODE_OPTIONS="
.byte 0
.Ex_k_id: .asciz "id"
.Ex_k_method: .asciz "method"
.Ex_k_error: .asciz "error"
.Ex_k_result: .asciz "result"
.Ex_k_params: .asciz "params"
.Ex_k_thread: .asciz "thread"
.Ex_k_ephemeral: .asciz "ephemeral"
.Ex_k_turn: .asciz "turn"
.Ex_k_thread_id: .asciz "threadId"
.Ex_k_turn_id: .asciz "turnId"
.Ex_k_item: .asciz "item"
.Ex_k_type: .asciz "type"
.Ex_k_text: .asciz "text"
.Ex_k_phase: .asciz "phase"
.Ex_k_status: .asciz "status"
.Ex_k_session_id: .asciz "sessionId"
.Ex_k_capabilities: .asciz "agentCapabilities"
.Ex_k_load: .asciz "loadSession"
.Ex_k_protocol: .asciz "protocolVersion"
.Ex_k_update: .asciz "update"
.Ex_k_session_update: .asciz "sessionUpdate"
.Ex_k_content: .asciz "content"
.Ex_k_stop: .asciz "stopReason"
.Ex_m_item: .asciz "item/completed"
.Ex_m_turn_started: .asciz "turn/started"
.Ex_m_turn_completed: .asciz "turn/completed"
.Ex_m_session_update: .asciz "session/update"
.Ex_agent_message: .asciz "agentMessage"
.Ex_final_answer: .asciz "final_answer"
.Ex_completed: .asciz "completed"
.Ex_end_turn: .asciz "end_turn"
.Ex_message_chunk: .asciz "agent_message_chunk"
.Ex_text: .asciz "text"
.Ex_newline: .byte 10
EFRAME .Ex_initialize,"{\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"qwen-code\",\"version\":\"1.0.0\"},\"capabilities\":{\"experimentalApi\":false}}}\n"
EFRAME .Ex_initialized,"{\"method\":\"initialized\"}\n"
EFRAME .Ex_thread_start,"{\"id\":2,\"method\":\"thread/start\",\"params\":{\"ephemeral\":true,\"approvalPolicy\":\"never\",\"cwd\":"
EFRAME .Ex_sandbox_read,",\"sandbox\":\"read-only\"}}\n"
EFRAME .Ex_sandbox_write,",\"sandbox\":\"workspace-write\"}}\n"
EFRAME .Ex_sandbox_full,",\"sandbox\":\"danger-full-access\"}}\n"
EFRAME .Ex_turn_start,"{\"id\":3,\"method\":\"turn/start\",\"params\":{\"threadId\":"
EFRAME .Ex_turn_prompt,",\"input\":[{\"type\":\"text\",\"text\":"
EFRAME .Ex_turn_tail,",\"text_elements\":[]}]}}\n"
EFRAME .Ex_acp_initialize,"{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":1,\"clientCapabilities\":{\"fs\":{\"readTextFile\":false,\"writeTextFile\":false}}}}\n"
EFRAME .Ex_acp_new,"{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"session/new\",\"params\":{\"cwd\":"
EFRAME .Ex_acp_new_tail,",\"mcpServers\":[]}}\n"
EFRAME .Ex_acp_prompt,"{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"session/prompt\",\"params\":{\"sessionId\":"
EFRAME .Ex_acp_prompt_text,",\"prompt\":[{\"type\":\"text\",\"text\":"
EFRAME .Ex_acp_prompt_tail,"}]}}\n"
EFRAME .Ex_reply_prefix,"{\"jsonrpc\":\"2.0\",\"id\":"
EFRAME .Ex_unsupported,",\"error\":{\"code\":-32601,\"message\":\"Unsupported unattended request.\"}}\n"
.section .bss
.balign 16
.Ex_kind: .skip 8
.Ex_mode: .skip 8
.Ex_cancel: .skip 8
.Ex_approve: .skip 8
.Ex_cwd: .skip 8
.Ex_cwd_owned: .skip 4096
.Ex_prompt: .skip 8
.Ex_output: .skip 8
.Ex_capacity: .skip 8
.Ex_answer_len: .skip 8
.Ex_answer_final: .skip 8
.Ex_env: .skip 8
.Ex_command: .skip 8
.Ex_executable: .skip 4096
.Ex_envclean: .skip 8200
.Ex_stat: .skip 144
.Ex_pair: .skip 8
.Ex_fd: .skip 8
.Ex_pid: .skip 8
.Ex_parent: .skip 8
.Ex_argv: .skip 32
.Ex_poll: .skip 8
.Ex_clock: .skip 16
.Ex_started: .skip 8
.Ex_rxlen: .skip 8
.Ex_rxpos: .skip 8
.Ex_expected: .skip 8
.Ex_terminal: .skip 8
.Ex_result: .skip 8
.Ex_builder: .skip 24
.Ex_rx: .skip MAX_JSON+1
.Ex_frame: .skip MAX_JSON+1
.Ex_tx: .skip MAX_JSON+1
.Ex_tokens: .skip MAX_TOKENS*TOKEN_SIZE
.Ex_thread: .skip 256
.Ex_turn: .skip 256
.Ex_method: .skip 256
.Ex_textbuf: .skip MAX_JSON+1
.Ex_answer: .skip 65536
.section .text
.global agent_executor_available,agent_executor_execute,agent_executor_set_mode,agent_executor_set_cancel,agent_executor_set_approval
agent_executor_set_mode:
 cmp rdi,3
 ja .Ex_invalid
 mov [rip+.Ex_mode],rdi
 xor eax,eax
 ret
agent_executor_set_cancel:
 mov [rip+.Ex_cancel],rdi
 xor eax,eax
 ret
agent_executor_set_approval:
 mov [rip+.Ex_approve],rdi
 xor eax,eax
 ret
.Ex_invalid:
 mov rax,-22
 ret
.Ex_zlen:
 xor eax,eax
 test rdi,rdi
 jz .Ex_zbad
.Ex_zloop:
 cmp rax,rsi
 jae .Ex_zbad
 cmp byte ptr [rdi+rax],0
 je .Ex_zret
 inc rax
 jmp .Ex_zloop
.Ex_zbad:
 mov rax,-22
.Ex_zret:
 ret
.Ex_equal:
 xor eax,eax
.Ex_eq_loop:
 mov dl,[rdi+rax]
 cmp dl,[rsi+rax]
 jne .Ex_eq_no
 test dl,dl
 jz .Ex_eq_yes
 inc rax
 jmp .Ex_eq_loop
.Ex_eq_yes:
 mov eax,1
 ret
.Ex_eq_no:
 xor eax,eax
 ret
# Availability checks executable PATH entries; no process starts here.
agent_executor_available:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 test rdi,rdi
 jz .Ex_available_no
 test rsi,rsi
 jz .Ex_available_no
 lea rsi,[rip+.Ex_codex]
 call .Ex_equal
 test eax,eax
 jz .Ex_available_acp
 mov qword ptr [rip+.Ex_kind],0
 lea r14,[rip+.Ex_codex]
 jmp .Ex_available_env
.Ex_available_acp:
 mov rdi,r12
 lea rsi,[rip+.Ex_claude]
 call .Ex_equal
 test eax,eax
 jz .Ex_available_no
 mov qword ptr [rip+.Ex_kind],1
 lea r14,[rip+.Ex_acp_command]
.Ex_available_env:
 mov [rip+.Ex_command],r14
 lea r15,[rip+.Ex_path_default]
 xor ebx,ebx
.Ex_env_find_path:
 cmp ebx,1024
 jae .Ex_available_path
 mov rdi,[r13+rbx*8]
 test rdi,rdi
 jz .Ex_available_path
 cmp dword ptr [rdi],0x48544150
 jne .Ex_env_next
 cmp byte ptr [rdi+4],61
 jne .Ex_env_next
 lea r15,[rdi+5]
 jmp .Ex_available_path
.Ex_env_next:
 inc ebx
 jmp .Ex_env_find_path
.Ex_available_path:
 lea rdi,[rip+.Ex_executable]
 xor ecx,ecx
.Ex_path_component:
 cmp ecx,3500
 jae .Ex_available_no
 mov al,[r15]
 test al,al
 jz .Ex_path_command
 cmp al,58
 je .Ex_path_separator
 stosb
 inc r15
 inc ecx
 jmp .Ex_path_component
.Ex_path_separator:
 inc r15
.Ex_path_command:
 test ecx,ecx
 jz .Ex_path_dot
 mov al,47
 stosb
 jmp .Ex_path_name
.Ex_path_dot:
 mov word ptr [rdi],0x2f2e
 add rdi,2
.Ex_path_name:
 mov rsi,r14
.Ex_path_namecopy:
 lodsb
 stosb
 test al,al
 jnz .Ex_path_namecopy
 mov eax,21
 lea rdi,[rip+.Ex_executable]
 mov esi,1
 syscall
 test rax,rax
 js .Ex_path_next
 mov eax,4
 lea rdi,[rip+.Ex_executable]
 lea rsi,[rip+.Ex_stat]
 syscall
 test rax,rax
 js .Ex_path_next
 mov eax,[rip+.Ex_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Ex_path_next
 mov eax,1
 jmp .Ex_available_return
.Ex_path_next:
 cmp byte ptr [r15],0
 jne .Ex_available_path
.Ex_available_no:
 xor eax,eax
.Ex_available_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# nameZ,promptZ,cwdZ,envp,out,cap ->final UTF8len/error. Caller selected mode.
agent_executor_execute:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 mov [rip+.Ex_prompt],rsi
 mov [rip+.Ex_cwd],rdx
 mov [rip+.Ex_env],rcx
 mov [rip+.Ex_output],r8
 mov [rip+.Ex_capacity],r9
 mov qword ptr [rip+.Ex_fd],-1
 mov qword ptr [rip+.Ex_pid],-1
 mov qword ptr [rip+.Ex_result],-22
 mov qword ptr [rip+.Ex_answer_len],0
 mov qword ptr [rip+.Ex_answer_final],0
 mov qword ptr [rip+.Ex_rxlen],0
 mov qword ptr [rip+.Ex_rxpos],0
 mov qword ptr [rip+.Ex_terminal],0
 mov byte ptr [rip+.Ex_thread],0
 mov byte ptr [rip+.Ex_turn],0
 test rsi,rsi
 jz .Ex_cleanup
 test rdx,rdx
 jz .Ex_cleanup
 test rcx,rcx
 jz .Ex_cleanup
 test r8,r8
 jz .Ex_cleanup
 test r9,r9
 jz .Ex_cleanup
 mov rdi,[rip+.Ex_cwd]
 cmp byte ptr [rdi],47
 jne .Ex_cleanup
 mov esi,4096
 call .Ex_zlen
 test rax,rax
 jle .Ex_cleanup
 lea rcx,[rax+1]
 lea rdi,[rip+.Ex_cwd_owned]
 mov rsi,[rip+.Ex_cwd]
 rep movsb
 lea rax,[rip+.Ex_cwd_owned]
 mov [rip+.Ex_cwd],rax
 mov rdi,r12
 mov rsi,[rip+.Ex_env]
 call agent_executor_available
 test eax,eax
 jnz .Ex_spawn
 mov qword ptr [rip+.Ex_result],-2
 jmp .Ex_cleanup
.Ex_spawn:
 call .Ex_sanitize_env
 mov eax,39
 syscall
 mov [rip+.Ex_parent],rax
 mov eax,53
 mov edi,1
 mov esi,0x80801
 xor edx,edx
 lea r10,[rip+.Ex_pair]
 syscall
 test rax,rax
 js .Ex_fail_code
 mov eax,57
 syscall
 test rax,rax
 js .Ex_fork_failed
 jz .Ex_child
 mov [rip+.Ex_pid],rax
 mov eax,3
 mov edi,[rip+.Ex_pair+4]
 syscall
 movsxd rax,dword ptr [rip+.Ex_pair]
 mov [rip+.Ex_fd],rax
 cmp qword ptr [rip+.Ex_kind],0
 jne .Ex_acp_start
 lea rdi,[rip+.Ex_initialize]
 mov esi,OFFSET FLAT:.Ex_initialize_len
 call .Ex_send
 test rax,rax
 js .Ex_fail_code
 mov edi,1
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 lea rdi,[rip+.Ex_initialized]
 mov esi,OFFSET FLAT:.Ex_initialized_len
 call .Ex_send
 test rax,rax
 js .Ex_fail_code
 call .Ex_build_begin
 ECAT .Ex_thread_start
 mov rdi,[rip+.Ex_cwd]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 cmp qword ptr [rip+.Ex_mode],1
 je .Ex_thread_write
 cmp qword ptr [rip+.Ex_mode],3
 je .Ex_thread_full
 ECAT .Ex_sandbox_read
 jmp .Ex_thread_send
.Ex_thread_write:
 ECAT .Ex_sandbox_write
 jmp .Ex_thread_send
.Ex_thread_full:
 ECAT .Ex_sandbox_full
.Ex_thread_send:
 call .Ex_send_builder
 test rax,rax
 js .Ex_fail_code
 mov edi,2
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 # Thread response requires explicit ephemeral=true; never resume userthreads.
 mov rdi,rax
 lea rsi,[rip+.Ex_k_thread]
 call .Ex_find
 test rax,rax
 js .Ex_protocol_fail
 mov r12,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_ephemeral]
 call .Ex_find
 test rax,rax
 js .Ex_protocol_fail
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_TRUE
 jne .Ex_protocol_fail
 mov rdi,r12
 lea rsi,[rip+.Ex_k_id]
 lea rdx,[rip+.Ex_thread]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_protocol_fail
 call .Ex_build_begin
 ECAT .Ex_turn_start
 lea rdi,[rip+.Ex_thread]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_turn_prompt
 mov rdi,[rip+.Ex_prompt]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_turn_tail
 call .Ex_send_builder
 test rax,rax
 js .Ex_fail_code
 mov edi,3
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 mov rdi,rax
 lea rsi,[rip+.Ex_k_turn]
 call .Ex_find
 test rax,rax
 js .Ex_protocol_fail
 call .Ex_associate_turn
 test rax,rax
 js .Ex_fail_code
.Ex_codex_finish_loop:
 cmp qword ptr [rip+.Ex_terminal],0
 jne .Ex_completed_result
 call .Ex_next
 test rax,rax
 js .Ex_fail_code
 call .Ex_notification
 test rax,rax
 js .Ex_fail_code
 jmp .Ex_codex_finish_loop
.Ex_acp_start:
 # ACP handshake and permissions are implemented in the following chain.
 jmp .Ex_acp_connect
.Ex_completed_result:
 mov rax,[rip+.Ex_answer_len]
 test rax,rax
 jz .Ex_protocol_fail
 mov r12,rax
 call .Ex_has_nonblank
 test eax,eax
 jz .Ex_protocol_fail
 mov rax,r12
 cmp rax,[rip+.Ex_capacity]
 jae .Ex_full_fail
 mov [rip+.Ex_result],rax
 mov rcx,rax
 mov rdi,[rip+.Ex_output]
 lea rsi,[rip+.Ex_answer]
 rep movsb
 mov byte ptr [rdi],0
 jmp .Ex_cleanup
.Ex_protocol_fail:
 mov rax,-71
 jmp .Ex_fail_code
.Ex_full_fail:
 mov rax,-28
.Ex_fail_code:
 mov [rip+.Ex_result],rax
.Ex_cleanup:
 mov rdi,[rip+.Ex_fd]
 cmp rdi,0
 jl .Ex_cleanup_child
 mov eax,3
 syscall
.Ex_cleanup_child:
 mov rdi,[rip+.Ex_pid]
 cmp rdi,0
 jl .Ex_execute_return
 mov eax,62
 mov esi,9
 syscall
.Ex_cleanup_reap:
 mov eax,61
 mov rdi,[rip+.Ex_pid]
 lea rsi,[rip+.Ex_stat]
 xor edx,edx
 xor r10d,r10d
 syscall
 cmp rax,-4
 je .Ex_cleanup_reap
.Ex_execute_return:
 mov rax,[rip+.Ex_result]
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.Ex_fork_failed:
 mov r12,rax
 mov eax,3
 mov edi,[rip+.Ex_pair]
 syscall
 mov eax,3
 mov edi,[rip+.Ex_pair+4]
 syscall
 mov rax,r12
 jmp .Ex_fail_code

.Ex_sanitize_env:
 push rbx
 push r12
 push r13
 mov r12,[rip+.Ex_env]
 xor ebx,ebx
 xor r13d,r13d
.Ex_clean_next:
 cmp ebx,1024
 jae .Ex_clean_done
 mov rdi,[r12+rbx*8]
 test rdi,rdi
 jz .Ex_clean_done
 lea r8,[rip+.Ex_secrets]
 mov r9d,4
 cmp qword ptr [rip+.Ex_kind],0
 jne .Ex_clean_check
 mov r9d,7
.Ex_clean_check:
 xor ecx,ecx
.Ex_clean_prefix:
 mov al,[r8+rcx]
 test al,al
 jz .Ex_clean_skip
 mov dl,[rdi+rcx]
 cmp dl,97
 jb .Ex_clean_compare
 cmp dl,122
 ja .Ex_clean_compare
 sub dl,32
.Ex_clean_compare:
 cmp al,dl
 jne .Ex_clean_prefix_next
 inc ecx
 jmp .Ex_clean_prefix
.Ex_clean_prefix_next:
 cmp byte ptr [r8],0
 je .Ex_clean_after_prefix
 inc r8
 jmp .Ex_clean_prefix_next
.Ex_clean_after_prefix:
 inc r8
 dec r9d
 jnz .Ex_clean_check
 lea rax,[rip+.Ex_envclean]
 mov [rax+r13*8],rdi
 inc r13
.Ex_clean_skip:
 inc ebx
 jmp .Ex_clean_next
.Ex_clean_done:
 lea rax,[rip+.Ex_envclean]
 mov qword ptr [rax+r13*8],0
 pop r13
 pop r12
 pop rbx
 ret
.Ex_child:
 mov eax,157
 mov edi,1
 mov esi,9
 xor edx,edx
 xor r10d,r10d
 xor r8d,r8d
 syscall
 mov eax,110
 syscall
 cmp rax,[rip+.Ex_parent]
 jne .Ex_child_fail
 mov eax,72
 mov edi,[rip+.Ex_pair+4]
 mov esi,4
 xor edx,edx
 syscall
 mov eax,33
 mov edi,[rip+.Ex_pair+4]
 xor esi,esi
 syscall
 mov eax,33
 mov edi,[rip+.Ex_pair+4]
 mov esi,1
 syscall
 mov eax,3
 mov edi,[rip+.Ex_pair]
 syscall
 mov eax,3
 mov edi,[rip+.Ex_pair+4]
 syscall
 mov eax,2
 lea rdi,[rip+.Ex_null]
 mov esi,0x80001
 xor edx,edx
 syscall
 mov rbx,rax
 test rax,rax
 js .Ex_child_fail
 mov eax,33
 mov rdi,rbx
 mov esi,2
 syscall
 mov eax,3
 mov rdi,rbx
 syscall
 mov eax,80
 mov rdi,[rip+.Ex_cwd]
 syscall
 test rax,rax
 js .Ex_child_fail
 lea rdi,[rip+.Ex_argv]
 mov rax,[rip+.Ex_command]
 mov [rdi],rax
 mov qword ptr [rdi+8],0
 cmp qword ptr [rip+.Ex_kind],0
 jne .Ex_child_exec
 lea rax,[rip+.Ex_app_server]
 mov [rdi+8],rax
 lea rax,[rip+.Ex_stdio]
 mov [rdi+16],rax
 mov qword ptr [rdi+24],0
.Ex_child_exec:
 mov eax,59
 lea rdi,[rip+.Ex_executable]
 lea rsi,[rip+.Ex_argv]
 lea rdx,[rip+.Ex_envclean]
 syscall
.Ex_child_fail:
 mov eax,60
 mov edi,127
 syscall
 ud2
.Ex_build_begin:
 lea rax,[rip+.Ex_tx]
 mov [rip+.Ex_builder],rax
 mov qword ptr [rip+.Ex_builder+8],MAX_JSON
 mov qword ptr [rip+.Ex_builder+16],0
 ret
.Ex_quote_z:
 push rbx
 mov rbx,rdi
 mov esi,MAX_JSON
 call .Ex_zlen
 test rax,rax
 js .Ex_quote_return
 lea rdi,[rip+.Ex_builder]
 mov rsi,rbx
 mov rdx,rax
 call qx_quote_cat@PLT
.Ex_quote_return:
 pop rbx
 ret
.Ex_send_builder:
 lea rdi,[rip+.Ex_tx]
 mov rsi,[rip+.Ex_builder+16]
 jmp .Ex_send
.Ex_start_clock:
 mov eax,228
 mov edi,1
 lea rsi,[rip+.Ex_clock]
 syscall
 mov rax,[rip+.Ex_clock]
 mov [rip+.Ex_started],rax
 ret
.Ex_wait:
 push rbx
 mov ebx,esi
 mov rax,[rip+.Ex_cancel]
 test rax,rax
 jz .Ex_wait_clock
 call rax
 cmp rax,-125
 je .Ex_wait_return
.Ex_wait_clock:
 mov eax,228
 mov edi,1
 lea rsi,[rip+.Ex_clock]
 syscall
 mov rax,[rip+.Ex_clock]
 sub rax,[rip+.Ex_started]
 cmp rax,120
 jae .Ex_wait_timeout
 mov eax,dword ptr [rip+.Ex_fd]
 mov [rip+.Ex_poll],eax
 mov [rip+.Ex_poll+4],bx
 mov word ptr [rip+.Ex_poll+6],0
 mov eax,7
 lea rdi,[rip+.Ex_poll]
 mov esi,1
 mov edx,50
 syscall
 cmp rax,-4
 je .Ex_wait_clock
 test rax,rax
 js .Ex_wait_return
 xor eax,eax
 jmp .Ex_wait_return
.Ex_wait_timeout:
 mov rax,-110
.Ex_wait_return:
 pop rbx
 ret
.Ex_send:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 call .Ex_start_clock
.Ex_send_loop:
 mov eax,44
 mov rdi,[rip+.Ex_fd]
 mov rsi,r12
 mov rdx,r13
 mov r10d,0x4040
 xor r8d,r8d
 xor r9d,r9d
 syscall
 cmp rax,-4
 je .Ex_send_loop
 cmp rax,-11
 je .Ex_send_wait
 test rax,rax
 jle .Ex_send_return
 add r12,rax
 sub r13,rax
 jnz .Ex_send_loop
 xor eax,eax
 jmp .Ex_send_return
.Ex_send_wait:
 mov esi,4
 call .Ex_wait
 test rax,rax
 jns .Ex_send_loop
.Ex_send_return:
 pop r13
 pop r12
 pop rbx
 ret
.Ex_next:
 push rbx
 push r12
 push r13
 call .Ex_start_clock
.Ex_next_scan:
 mov r12,[rip+.Ex_rxpos]
 mov r13,[rip+.Ex_rxlen]
 mov rbx,r12
 lea rdx,[rip+.Ex_rx]
.Ex_line_scan:
 cmp rbx,r13
 jae .Ex_read_more
 cmp byte ptr [rdx+rbx],10
 je .Ex_line_found
 inc rbx
 jmp .Ex_line_scan
.Ex_line_found:
 lea rax,[rbx+1]
 mov [rip+.Ex_rxpos],rax
 mov rcx,rbx
 sub rcx,r12
 test rcx,rcx
 jz .Ex_next_scan
 lea rsi,[rdx+r12]
 lea rdi,[rip+.Ex_frame]
 mov r12,rcx
 rep movsb
 mov byte ptr [rdi],0
 lea rdi,[rip+.Ex_frame]
 mov rsi,r12
 lea rdx,[rip+.Ex_tokens]
 mov ecx,MAX_TOKENS
 call json_parse@PLT
 test rax,rax
 js .Ex_next_bad
 cmp qword ptr [rip+.Ex_tokens+T_TYPE],JT_OBJECT
 jne .Ex_next_bad
 xor eax,eax
 jmp .Ex_next_return
.Ex_read_more:
 test r12,r12
 jz .Ex_read_space
 mov rcx,r13
 sub rcx,r12
 lea rdi,[rip+.Ex_rx]
 lea rsi,[rdi+r12]
 mov r13,rcx
 rep movsb
 mov [rip+.Ex_rxlen],r13
 mov qword ptr [rip+.Ex_rxpos],0
.Ex_read_space:
 cmp r13,MAX_JSON
 jae .Ex_next_full
 xor eax,eax
 mov rdi,[rip+.Ex_fd]
 lea rsi,[rip+.Ex_rx]
 add rsi,r13
 mov edx,MAX_JSON
 sub rdx,r13
 syscall
 cmp rax,-4
 je .Ex_read_space
 cmp rax,-11
 je .Ex_read_wait
 test rax,rax
 jle .Ex_next_closed
 add [rip+.Ex_rxlen],rax
 jmp .Ex_next_scan
.Ex_read_wait:
 mov esi,1
 call .Ex_wait
 test rax,rax
 jns .Ex_next_scan
 jmp .Ex_next_return
.Ex_next_full:
 mov rax,-28
 jmp .Ex_next_return
.Ex_next_bad:
 mov rax,-71
 jmp .Ex_next_return
.Ex_next_closed:
 mov rax,-32
.Ex_next_return:
 pop r13
 pop r12
 pop rbx
 ret
# Object index/key ->value token index. Strict tokens are process-owned.
.Ex_find:
 sub rsp,8
 mov rcx,rsi
 mov rdx,rdi
 lea rdi,[rip+.Ex_frame]
 lea rsi,[rip+.Ex_tokens]
 call json_find@PLT
 add rsp,8
 ret
.Ex_string:
 push rbx
 push r12
 push r13
 mov r12,rdx
 mov r13,rcx
 call .Ex_find
 test rax,rax
 js .Ex_string_bad
 mov rdi,rax
 mov rsi,r12
 mov rdx,r13
 call .Ex_decode
 jmp .Ex_string_return
.Ex_string_bad:
 mov rax,-71
.Ex_string_return:
 pop r13
 pop r12
 pop rbx
 ret
.Ex_decode:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 shl rdi,5
 lea rbx,[rip+.Ex_tokens]
 add rbx,rdi
 cmp qword ptr [rbx+T_TYPE],JT_STRING
 jne .Ex_decode_bad
 mov rdi,r12
 lea rsi,[rip+.Ex_frame]
 add rsi,[rbx+T_START]
 mov rdx,[rbx+T_LEN]
 lea rcx,[r13-1]
 call json_decode@PLT
 test rax,rax
 js .Ex_decode_bad
 mov byte ptr [r12+rax],0
 xor ecx,ecx
.Ex_decode_nul:
 cmp rcx,rax
 jae .Ex_decode_return
 cmp byte ptr [r12+rcx],0
 je .Ex_decode_bad
 inc rcx
 jmp .Ex_decode_nul
.Ex_decode_bad:
 mov rax,-71
.Ex_decode_return:
 pop r13
 pop r12
 pop rbx
 ret
# Await exact numeric client request ID while handling all intermediate events.
# Success returns object token index of result, never a foreign/stale response.
.Ex_await:
 push rbx
 push r12
 push r13
 mov [rip+.Ex_expected],rdi
.Ex_await_next:
 call .Ex_next
 test rax,rax
 js .Ex_await_return
 xor edi,edi
 lea rsi,[rip+.Ex_k_method]
 call .Ex_find
 test rax,rax
 js .Ex_await_response
 call .Ex_notification
 test rax,rax
 js .Ex_await_return
 jmp .Ex_await_next
.Ex_await_response:
 xor edi,edi
 lea rsi,[rip+.Ex_k_id]
 call .Ex_find
 test rax,rax
 js .Ex_await_next
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_NUMBER
 jne .Ex_await_next
 cmp qword ptr [rdx+rax+T_LEN],1
 jne .Ex_await_next
 mov rcx,[rdx+rax+T_START]
 lea rdx,[rip+.Ex_frame]
 movzx eax,byte ptr [rdx+rcx]
 sub eax,48
 cmp rax,[rip+.Ex_expected]
 jne .Ex_await_next
 xor edi,edi
 lea rsi,[rip+.Ex_k_error]
 call .Ex_find
 test rax,rax
 jns .Ex_await_bad
 xor edi,edi
 lea rsi,[rip+.Ex_k_result]
 call .Ex_find
 test rax,rax
 js .Ex_await_bad
 mov rdx,rax
 shl rdx,5
 lea rcx,[rip+.Ex_tokens]
 cmp qword ptr [rcx+rdx+T_TYPE],JT_OBJECT
 je .Ex_await_return
.Ex_await_bad:
 mov rax,-71
.Ex_await_return:
 pop r13
 pop r12
 pop rbx
 ret
# Associate or verify nonempty turn ID from a turn object token index.
.Ex_associate_turn:
 push rbx
 push r12
 push r13
 mov rdi,rax
 lea rsi,[rip+.Ex_k_id]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_associate_bad
 cmp byte ptr [rip+.Ex_turn],0
 je .Ex_associate_first
 lea rdi,[rip+.Ex_turn]
 lea rsi,[rip+.Ex_textbuf]
 call .Ex_equal
 test eax,eax
 jz .Ex_associate_bad
 xor eax,eax
 jmp .Ex_associate_return
.Ex_associate_first:
 lea rdi,[rip+.Ex_turn]
 lea rsi,[rip+.Ex_textbuf]
 inc rax
 mov rcx,rax
 rep movsb
 xor eax,eax
 jmp .Ex_associate_return
.Ex_associate_bad:
 mov rax,-71
.Ex_associate_return:
 pop r13
 pop r12
 pop rbx
 ret
.Ex_notification:
 push rbx
 push r12
 push r13
 push r14
 push r15
 xor edi,edi
 lea rsi,[rip+.Ex_k_method]
 lea rdx,[rip+.Ex_method]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 xor edi,edi
 lea rsi,[rip+.Ex_k_id]
 call .Ex_find
 test rax,rax
 jns .Ex_server_request
 xor edi,edi
 lea rsi,[rip+.Ex_k_params]
 call .Ex_find
 test rax,rax
 js .Ex_notification_done
 mov r12,rax
 cmp qword ptr [rip+.Ex_kind],0
 jne .Ex_acp_notification
 # Ignore unrelated thread events; never let them satisfy this operation.
 mov rdi,r12
 lea rsi,[rip+.Ex_k_thread_id]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_notification_done
 lea rdi,[rip+.Ex_thread]
 lea rsi,[rip+.Ex_textbuf]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_m_item]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_item
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_m_turn_started]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_turn
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_m_turn_completed]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
.Ex_codex_turn:
 mov rdi,r12
 lea rsi,[rip+.Ex_k_turn]
 call .Ex_find
 test rax,rax
 js .Ex_notification_bad
 mov r13,rax
 call .Ex_associate_turn
 test rax,rax
 js .Ex_notification_return
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_m_turn_completed]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 mov rdi,r13
 lea rsi,[rip+.Ex_k_status]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_completed]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_bad
 mov qword ptr [rip+.Ex_terminal],1
 jmp .Ex_notification_done
.Ex_codex_item:
 mov rdi,r12
 lea rsi,[rip+.Ex_k_turn_id]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_notification_bad
 # Item turnId must match an associated turn; source also binds first observation.
 cmp byte ptr [rip+.Ex_turn],0
 je .Ex_codex_item_first_turn
 lea rdi,[rip+.Ex_turn]
 lea rsi,[rip+.Ex_textbuf]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_bad
 jmp .Ex_codex_item_body
.Ex_codex_item_first_turn:
 lea rdi,[rip+.Ex_turn]
 lea rsi,[rip+.Ex_textbuf]
 inc rax
 mov rcx,rax
 rep movsb
.Ex_codex_item_body:
 mov rdi,r12
 lea rsi,[rip+.Ex_k_item]
 call .Ex_find
 test rax,rax
 js .Ex_notification_bad
 mov r13,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_type]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_agent_message]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 mov rdi,r13
 lea rsi,[rip+.Ex_k_phase]
 call .Ex_find
 test rax,rax
 js .Ex_codex_unphased
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_NULL
 je .Ex_codex_unphased
 mov rdi,r13
 lea rsi,[rip+.Ex_k_phase]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_final_answer]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 mov qword ptr [rip+.Ex_answer_final],1
 jmp .Ex_codex_answer
.Ex_codex_unphased:
 cmp qword ptr [rip+.Ex_answer_final],0
 jne .Ex_notification_done
.Ex_codex_answer:
 mov rdi,r13
 lea rsi,[rip+.Ex_k_text]
 lea rdx,[rip+.Ex_answer]
 mov ecx,65536
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 mov [rip+.Ex_answer_len],rax
 jmp .Ex_notification_done
.Ex_notification_done:
 xor eax,eax
 jmp .Ex_notification_return
.Ex_notification_bad:
 mov rax,-71
.Ex_notification_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# All explicit server requests are answered fail-closed until a supported
# permission/input branch below chooses an exact source outcome.
.Ex_server_request:
 mov r12,rax
 cmp qword ptr [rip+.Ex_kind],0
 jne .Ex_acp_permission
 lea r14,[rip+.Ex_unsupported]
 mov r15d,OFFSET FLAT:.Ex_unsupported_len
 xor r13d,r13d
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_codex_cmd_approval]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_reject_request
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_codex_file_approval]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_reject_request
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_codex_perm_approval]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_reject_permissions
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_codex_user_input]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_reject_input
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_codex_elicitation]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_reject_elicitation
 jmp .Ex_codex_reply
.Ex_codex_reject_request:
 lea r14,[rip+.Ex_decline]
 mov r15d,OFFSET FLAT:.Ex_decline_len
 mov r13d,1
 xor edi,edi
 lea rsi,[rip+.Ex_k_params]
 call .Ex_find
 test rax,rax
 js .Ex_codex_reply
 mov rdi,rax
 lea rsi,[rip+.Ex_k_decisions]
 call .Ex_find
 test rax,rax
 js .Ex_codex_reply
 mov rbx,rax
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_ARRAY
 jne .Ex_notification_bad
 mov r14,[rdx+rax+T_END]
 inc rbx
 xor r15d,r15d
.Ex_codex_decision_next:
 cmp rbx,r14
 jae .Ex_codex_decision_end
 mov rdi,rbx
 lea rsi,[rip+.Ex_textbuf]
 mov edx,256
 call .Ex_decode
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_decline_word]
 call .Ex_equal
 test eax,eax
 jnz .Ex_codex_decision_decline
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_cancel_word]
 call .Ex_equal
 test eax,eax
 jz .Ex_codex_decision_advance
 mov r15d,1
.Ex_codex_decision_advance:
 mov rax,rbx
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 mov rbx,[rdx+rax+T_END]
 jmp .Ex_codex_decision_next
.Ex_codex_decision_end:
 test r15,r15
 jz .Ex_notification_bad
 lea r14,[rip+.Ex_cancel_decision]
 mov r15d,OFFSET FLAT:.Ex_cancel_decision_len
 jmp .Ex_codex_reply
.Ex_codex_decision_decline:
 lea r14,[rip+.Ex_decline]
 mov r15d,OFFSET FLAT:.Ex_decline_len
 jmp .Ex_codex_reply
.Ex_codex_reject_permissions:
 lea r14,[rip+.Ex_deny_permissions]
 mov r15d,OFFSET FLAT:.Ex_deny_permissions_len
 mov r13d,1
 jmp .Ex_codex_reply
.Ex_codex_reject_input:
 lea r14,[rip+.Ex_empty_answers]
 mov r15d,OFFSET FLAT:.Ex_empty_answers_len
 mov r13d,1
 jmp .Ex_codex_reply
.Ex_codex_reject_elicitation:
 lea r14,[rip+.Ex_decline_elicitation]
 mov r15d,OFFSET FLAT:.Ex_decline_elicitation_len
 mov r13d,1
.Ex_codex_reply:
 call .Ex_reply_begin
 test rax,rax
 js .Ex_notification_return
 lea rdi,[rip+.Ex_builder]
 mov rsi,r14
 mov rdx,r15
 call qx_cat@PLT
 test rax,rax
 js .Ex_notification_bad
 call .Ex_send_builder
 test rax,rax
 js .Ex_notification_return
 test r13,r13
 jz .Ex_notification_bad
 jmp .Ex_notification_done

.section .rodata
.Ex_k_decisions: .asciz "availableDecisions"
.Ex_decline_word: .asciz "decline"
.Ex_cancel_word: .asciz "cancel"
EFRAME .Ex_cancel_decision,",\"result\":{\"decision\":\"cancel\"}}\n"
.Ex_k_modes: .asciz "modes"
.Ex_k_available_modes: .asciz "availableModes"
.Ex_k_options: .asciz "options"
.Ex_k_kind: .asciz "kind"
.Ex_k_option_id: .asciz "optionId"
.Ex_k_tool_call: .asciz "toolCall"
.Ex_k_title: .asciz "title"
.Ex_k_raw_input: .asciz "rawInput"
.Ex_m_permission: .asciz "session/request_permission"
.Ex_mode_default: .asciz "default"
.Ex_mode_plan: .asciz "plan"
.Ex_mode_accept: .asciz "acceptEdits"
.Ex_mode_autoedit: .asciz "auto-edit"
.Ex_mode_auto: .asciz "auto"
.Ex_mode_bypass: .asciz "bypassPermissions"
.Ex_mode_yolo: .asciz "yolo"
.Ex_allow_once: .asciz "allow_once"
.Ex_reject_once: .asciz "reject_once"
.Ex_reject_always: .asciz "reject_always"
.Ex_external_tool: .asciz "external_tool"
EFRAME .Ex_acp_mode,"{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"session/set_mode\",\"params\":{\"sessionId\":"
EFRAME .Ex_acp_mode_id,",\"modeId\":"
EFRAME .Ex_object_end,"}}\n"
EFRAME .Ex_acp_selected,",\"result\":{\"outcome\":{\"outcome\":\"selected\",\"optionId\":"
EFRAME .Ex_acp_selected_end,"}}}\n"
EFRAME .Ex_acp_cancelled,",\"result\":{\"outcome\":{\"outcome\":\"cancelled\"}}}\n"
.Ex_codex_cmd_approval: .asciz "item/commandExecution/requestApproval"
.Ex_codex_file_approval: .asciz "item/fileChange/requestApproval"
.Ex_codex_perm_approval: .asciz "item/permissions/requestApproval"
.Ex_codex_user_input: .asciz "item/tool/requestUserInput"
.Ex_codex_elicitation: .asciz "mcpServer/elicitation/request"
EFRAME .Ex_decline,",\"result\":{\"decision\":\"decline\"}}\n"
EFRAME .Ex_deny_permissions,",\"result\":{\"permissions\":{},\"scope\":\"turn\"}}\n"
EFRAME .Ex_empty_answers,",\"result\":{\"answers\":{}}}\n"
EFRAME .Ex_decline_elicitation,",\"result\":{\"action\":\"decline\",\"content\":null,\"_meta\":null}}\n"
.section .bss
.Ex_peer_mode: .skip 256
.Ex_resume: .skip 256
.Ex_option_allow: .skip 256
.Ex_option_reject: .skip 256
.Ex_permission_title: .skip 4096
.Ex_option_ids: .skip 64*256
.Ex_option_count: .skip 8
.Ex_acp_running: .skip 8
.section .text
.Ex_acp_resume_unsupported:
 mov rax,-95
 jmp .Ex_fail_code
.Ex_acp_connect:
 mov qword ptr [rip+.Ex_acp_running],0
 lea rdi,[rip+.Ex_acp_initialize]
 mov esi,OFFSET FLAT:.Ex_acp_initialize_len
 call .Ex_send
 test rax,rax
 js .Ex_fail_code
 mov edi,1
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 mov r12,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_protocol]
 call .Ex_find
 test rax,rax
 js .Ex_protocol_fail
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_NUMBER
 jne .Ex_protocol_fail
 cmp qword ptr [rdx+rax+T_LEN],1
 jne .Ex_protocol_fail
 mov rax,[rdx+rax+T_START]
 lea rdx,[rip+.Ex_frame]
 cmp byte ptr [rdx+rax],49
 jne .Ex_protocol_fail
 cmp byte ptr [rip+.Ex_resume],0
 je .Ex_acp_new_session
 mov rdi,r12
 lea rsi,[rip+.Ex_k_capabilities]
 call .Ex_find
 test rax,rax
 js .Ex_acp_resume_unsupported
 mov rdi,rax
 lea rsi,[rip+.Ex_k_load]
 call .Ex_find
 test rax,rax
 js .Ex_acp_resume_unsupported
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_TRUE
 jne .Ex_acp_resume_unsupported
 call .Ex_build_begin
 ECAT .Ex_acp_load
 lea rdi,[rip+.Ex_resume]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_acp_load_cwd
 jmp .Ex_acp_session_cwd
.Ex_acp_new_session:
 call .Ex_build_begin
 ECAT .Ex_acp_new
.Ex_acp_session_cwd:
 mov rdi,[rip+.Ex_cwd]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_acp_new_tail
 call .Ex_send_builder
 test rax,rax
 js .Ex_fail_code
 mov edi,2
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 mov r12,rax
 cmp byte ptr [rip+.Ex_resume],0
 jne .Ex_acp_loaded_session
 mov rdi,rax
 lea rsi,[rip+.Ex_k_session_id]
 lea rdx,[rip+.Ex_thread]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_protocol_fail
 jmp .Ex_acp_session_ready
.Ex_acp_loaded_session:
 lea rdi,[rip+.Ex_thread]
 lea rsi,[rip+.Ex_resume]
.Ex_acp_resume_copy:
 lodsb
 stosb
 test al,al
 jnz .Ex_acp_resume_copy
.Ex_acp_session_ready:
 mov rdi,r12
 lea rsi,[rip+.Ex_k_modes]
 call .Ex_find
 test rax,rax
 js .Ex_protocol_fail
 mov rdi,rax
 lea rsi,[rip+.Ex_k_available_modes]
 call .Ex_find
 test rax,rax
 js .Ex_protocol_fail
 mov r12,rax
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_ARRAY
 jne .Ex_protocol_fail
 mov r13,[rdx+rax+T_END]
 inc r12
 mov r14,r12
 lea r15,[rip+.Ex_mode_default]
 cmp qword ptr [rip+.Ex_mode],1
 jne .Ex_acp_check_plan
 lea r15,[rip+.Ex_mode_accept]
 jmp .Ex_acp_mode_search
.Ex_acp_check_plan:
 cmp qword ptr [rip+.Ex_mode],2
 jne .Ex_acp_check_yolo
 lea r15,[rip+.Ex_mode_plan]
 jmp .Ex_acp_mode_search
.Ex_acp_check_yolo:
 cmp qword ptr [rip+.Ex_mode],3
 jne .Ex_acp_mode_search
 lea r15,[rip+.Ex_mode_bypass]
.Ex_acp_mode_search:
 mov r12,r14
.Ex_acp_mode_next:
 cmp r12,r13
 jae .Ex_acp_mode_alias
 mov rdi,r12
 lea rsi,[rip+.Ex_k_id]
 lea rdx,[rip+.Ex_peer_mode]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_protocol_fail
 lea rdi,[rip+.Ex_peer_mode]
 mov rsi,r15
 call .Ex_equal
 test eax,eax
 jnz .Ex_acp_mode_found
 mov rax,r12
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 mov r12,[rdx+rax+T_END]
 jmp .Ex_acp_mode_next
.Ex_acp_mode_alias:
 lea rax,[rip+.Ex_mode_accept]
 cmp r15,rax
 jne .Ex_acp_mode_alias_autoedit
 lea r15,[rip+.Ex_mode_autoedit]
 jmp .Ex_acp_mode_search
.Ex_acp_mode_alias_autoedit:
 lea rax,[rip+.Ex_mode_autoedit]
 cmp r15,rax
 jne .Ex_acp_mode_alias_bypass
 lea r15,[rip+.Ex_mode_auto]
 jmp .Ex_acp_mode_search
.Ex_acp_mode_alias_bypass:
 lea rax,[rip+.Ex_mode_bypass]
 cmp r15,rax
 jne .Ex_protocol_fail
 lea r15,[rip+.Ex_mode_yolo]
 jmp .Ex_acp_mode_search
.Ex_acp_mode_found:
 call .Ex_build_begin
 ECAT .Ex_acp_mode
 lea rdi,[rip+.Ex_thread]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_acp_mode_id
 lea rdi,[rip+.Ex_peer_mode]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_object_end
 call .Ex_send_builder
 test rax,rax
 js .Ex_fail_code
 mov edi,3
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 call .Ex_build_begin
 ECAT .Ex_acp_prompt
 lea rdi,[rip+.Ex_thread]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_acp_prompt_text
 mov rdi,[rip+.Ex_prompt]
 call .Ex_quote_z
 test rax,rax
 js .Ex_protocol_fail
 ECAT .Ex_acp_prompt_tail
 mov qword ptr [rip+.Ex_acp_running],1
 call .Ex_send_builder
 test rax,rax
 js .Ex_fail_code
 mov edi,4
 call .Ex_await
 test rax,rax
 js .Ex_fail_code
 mov rdi,rax
 lea rsi,[rip+.Ex_k_stop]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_protocol_fail
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_end_turn]
 call .Ex_equal
 test eax,eax
 jz .Ex_protocol_fail
 mov qword ptr [rip+.Ex_acp_running],0
 jmp .Ex_completed_result

.Ex_acp_notification:
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_m_session_update]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 cmp qword ptr [rip+.Ex_acp_running],0
 je .Ex_notification_done
 mov rdi,r12
 lea rsi,[rip+.Ex_k_session_id]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_thread]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 mov rdi,r12
 lea rsi,[rip+.Ex_k_update]
 call .Ex_find
 test rax,rax
 js .Ex_notification_bad
 mov r13,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_session_update]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_message_chunk]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 mov rdi,r13
 lea rsi,[rip+.Ex_k_content]
 call .Ex_find
 test rax,rax
 js .Ex_notification_bad
 mov r13,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_type]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_text]
 call .Ex_equal
 test eax,eax
 jz .Ex_notification_done
 mov rdi,r13
 lea rsi,[rip+.Ex_k_text]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,MAX_JSON
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 mov rcx,[rip+.Ex_answer_len]
 add rcx,rax
 cmp rcx,65535
 ja .Ex_notification_bad
 lea rdi,[rip+.Ex_answer]
 add rdi,[rip+.Ex_answer_len]
 add [rip+.Ex_answer_len],rax
 mov rcx,rax
 lea rsi,[rip+.Ex_textbuf]
 rep movsb
 mov byte ptr [rdi],0
 jmp .Ex_notification_done

# Permission replies retain exact server request IDs and offered option IDs.
.Ex_acp_permission:
 lea rdi,[rip+.Ex_method]
 lea rsi,[rip+.Ex_m_permission]
 call .Ex_equal
 test eax,eax
 jz .Ex_acp_unknown_request
 mov byte ptr [rip+.Ex_option_allow],0
 mov byte ptr [rip+.Ex_option_reject],0
 mov qword ptr [rip+.Ex_option_count],0
 xor edi,edi
 lea rsi,[rip+.Ex_k_params]
 call .Ex_find
 test rax,rax
 js .Ex_notification_bad
 mov r13,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_session_id]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_thread]
 lea rsi,[rip+.Ex_textbuf]
 call .Ex_equal
 test eax,eax
 jz .Ex_acp_permission_cancel
 cmp qword ptr [rip+.Ex_acp_running],0
 je .Ex_acp_permission_cancel
 mov rdi,r13
 lea rsi,[rip+.Ex_k_options]
 call .Ex_find
 test rax,rax
 js .Ex_notification_bad
 mov r14,rax
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_ARRAY
 jne .Ex_notification_bad
 mov r15,[rdx+rax+T_END]
 inc r14
.Ex_acp_option_next:
 cmp r14,r15
 jae .Ex_acp_choose_option
 cmp qword ptr [rip+.Ex_option_count],64
 jae .Ex_notification_bad
 mov rdi,r14
 lea rsi,[rip+.Ex_k_option_id]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Ex_notification_bad
 xor ebx,ebx
.Ex_acp_option_unique:
 cmp rbx,[rip+.Ex_option_count]
 jae .Ex_acp_option_store
 mov rax,rbx
 shl rax,8
 lea rdi,[rip+.Ex_option_ids]
 add rdi,rax
 lea rsi,[rip+.Ex_textbuf]
 call .Ex_equal
 test eax,eax
 jnz .Ex_notification_bad
 inc rbx
 jmp .Ex_acp_option_unique
.Ex_acp_option_store:
 mov rax,[rip+.Ex_option_count]
 shl rax,8
 lea rdi,[rip+.Ex_option_ids]
 add rdi,rax
 lea rsi,[rip+.Ex_textbuf]
.Ex_acp_option_copy:
 lodsb
 stosb
 test al,al
 jnz .Ex_acp_option_copy
 inc qword ptr [rip+.Ex_option_count]
 mov rdi,r14
 lea rsi,[rip+.Ex_k_kind]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_allow_once]
 call .Ex_equal
 test eax,eax
 jz .Ex_acp_option_reject
 lea rdi,[rip+.Ex_option_allow]
 jmp .Ex_acp_option_save_kind
.Ex_acp_option_reject:
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_reject_once]
 call .Ex_equal
 test eax,eax
 jz .Ex_acp_option_reject_always
 lea rdi,[rip+.Ex_option_reject]
 jmp .Ex_acp_option_save_kind
.Ex_acp_option_reject_always:
 cmp byte ptr [rip+.Ex_option_reject],0
 jne .Ex_acp_option_advance
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Ex_reject_always]
 call .Ex_equal
 test eax,eax
 jz .Ex_acp_option_advance
 lea rdi,[rip+.Ex_option_reject]
.Ex_acp_option_save_kind:
 mov rax,[rip+.Ex_option_count]
 dec rax
 shl rax,8
 lea rsi,[rip+.Ex_option_ids]
 add rsi,rax
.Ex_acp_option_save_copy:
 lodsb
 stosb
 test al,al
 jnz .Ex_acp_option_save_copy
.Ex_acp_option_advance:
 mov rax,r14
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 mov r14,[rdx+rax+T_END]
 jmp .Ex_acp_option_next
.Ex_acp_choose_option:
 mov rax,[rip+.Ex_approve]
 test rax,rax
 jz .Ex_acp_permission_reject
 cmp byte ptr [rip+.Ex_option_allow],0
 je .Ex_acp_permission_reject
 mov rdi,r13
 lea rsi,[rip+.Ex_k_tool_call]
 call .Ex_find
 test rax,rax
 js .Ex_acp_permission_reject
 mov r14,rax
 mov rdi,rax
 lea rsi,[rip+.Ex_k_title]
 lea rdx,[rip+.Ex_permission_title]
 mov ecx,4096
 call .Ex_string
 test rax,rax
 jle .Ex_acp_permission_reject
 mov rdi,r14
 lea rsi,[rip+.Ex_k_raw_input]
 call .Ex_find
 test rax,rax
 js .Ex_acp_permission_reject
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_OBJECT
 jne .Ex_acp_permission_reject
 mov rcx,[rdx+rax+T_LEN]
 cmp rcx,65535
 ja .Ex_acp_permission_reject
 mov r8,[rdx+rax+T_START]
 lea rdx,[rip+.Ex_frame]
 add rdx,r8
 lea rdi,[rip+.Ex_permission_title]
 lea rsi,[rip+.Ex_external_tool]
 call qword ptr [rip+.Ex_approve]
 cmp eax,1
 jne .Ex_acp_permission_reject
 lea r14,[rip+.Ex_option_allow]
 jmp .Ex_acp_permission_selected
.Ex_acp_permission_reject:
 cmp byte ptr [rip+.Ex_option_reject],0
 je .Ex_acp_permission_cancel
 lea r14,[rip+.Ex_option_reject]
.Ex_acp_permission_selected:
 call .Ex_reply_begin
 test rax,rax
 js .Ex_notification_return
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Ex_acp_selected]
 mov edx,OFFSET FLAT:.Ex_acp_selected_len
 call qx_cat@PLT
 test rax,rax
 js .Ex_notification_bad
 mov rdi,r14
 call .Ex_quote_z
 test rax,rax
 js .Ex_notification_bad
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Ex_acp_selected_end]
 mov edx,OFFSET FLAT:.Ex_acp_selected_end_len
 call qx_cat@PLT
 test rax,rax
 js .Ex_notification_bad
 call .Ex_send_builder
 jmp .Ex_notification_return
.Ex_acp_permission_cancel:
 call .Ex_reply_begin
 test rax,rax
 js .Ex_notification_return
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Ex_acp_cancelled]
 mov edx,OFFSET FLAT:.Ex_acp_cancelled_len
 call qx_cat@PLT
 test rax,rax
 js .Ex_notification_bad
 call .Ex_send_builder
 jmp .Ex_notification_return
.Ex_acp_unknown_request:
 call .Ex_reply_begin
 test rax,rax
 js .Ex_notification_return
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Ex_unsupported]
 mov edx,OFFSET FLAT:.Ex_unsupported_len
 call qx_cat@PLT
 test rax,rax
 js .Ex_notification_bad
 call .Ex_send_builder
 jmp .Ex_notification_return
# ID index R12 -> common response prefix, preserving IDs without interpolation.
.Ex_reply_begin:
 sub rsp,8
 call .Ex_build_begin
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Ex_reply_prefix]
 mov edx,OFFSET FLAT:.Ex_reply_prefix_len
 call qx_cat@PLT
 test rax,rax
 js .Ex_reply_begin_return
 mov rax,r12
 shl rax,5
 lea rdx,[rip+.Ex_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_STRING
 je .Ex_reply_begin_string
 cmp qword ptr [rdx+rax+T_TYPE],JT_NUMBER
 jne .Ex_reply_begin_bad
 lea rsi,[rip+.Ex_frame]
 add rsi,[rdx+rax+T_START]
 mov rdx,[rdx+rax+T_LEN]
 lea rdi,[rip+.Ex_builder]
 call qx_cat@PLT
 jmp .Ex_reply_begin_return
.Ex_reply_begin_string:
 mov rdi,r12
 lea rsi,[rip+.Ex_textbuf]
 mov edx,MAX_JSON
 call .Ex_decode
 test rax,rax
 js .Ex_reply_begin_return
 lea rdi,[rip+.Ex_textbuf]
 call .Ex_quote_z
 jmp .Ex_reply_begin_return
.Ex_reply_begin_bad:
 mov rax,-71
.Ex_reply_begin_return:
 add rsp,8
 ret
.section .note.GNU-stack,"",@progbits

.section .text
# ECMAScript trim whitespace used by source to reject an empty final report.
.Ex_has_nonblank:
 lea rdi,[rip+.Ex_answer]
 mov rdx,[rip+.Ex_answer_len]
 xor ecx,ecx
.Ex_blank_next:
 cmp rcx,rdx
 jae .Ex_blank_no
 movzx eax,byte ptr [rdi+rcx]
 cmp al,32
 je .Ex_blank_one
 cmp al,9
 jb .Ex_blank_yes
 cmp al,13
 jbe .Ex_blank_one
 cmp al,0xc2
 je .Ex_blank_c2
 cmp al,0xe1
 je .Ex_blank_e1
 cmp al,0xe2
 je .Ex_blank_e2
 cmp al,0xe3
 je .Ex_blank_e3
 cmp al,0xef
 jne .Ex_blank_yes
 lea rax,[rcx+3]
 cmp rax,rdx
 ja .Ex_blank_yes
 cmp word ptr [rdi+rcx+1],0xbfbb
 jne .Ex_blank_yes
 jmp .Ex_blank_three
.Ex_blank_c2:
 lea rax,[rcx+2]
 cmp rax,rdx
 ja .Ex_blank_yes
 cmp byte ptr [rdi+rcx+1],0xa0
 jne .Ex_blank_yes
 add rcx,2
 jmp .Ex_blank_next
.Ex_blank_e1:
 lea rax,[rcx+3]
 cmp rax,rdx
 ja .Ex_blank_yes
 cmp word ptr [rdi+rcx+1],0x809a
 jne .Ex_blank_yes
 jmp .Ex_blank_three
.Ex_blank_e3:
 lea rax,[rcx+3]
 cmp rax,rdx
 ja .Ex_blank_yes
 cmp word ptr [rdi+rcx+1],0x8080
 jne .Ex_blank_yes
 jmp .Ex_blank_three
.Ex_blank_e2:
 lea rax,[rcx+3]
 cmp rax,rdx
 ja .Ex_blank_yes
 cmp byte ptr [rdi+rcx+1],0x80
 jne .Ex_blank_e281
 mov al,[rdi+rcx+2]
 cmp al,0x80
 jb .Ex_blank_yes
 cmp al,0x8a
 jbe .Ex_blank_three
 cmp al,0xa8
 je .Ex_blank_three
 cmp al,0xa9
 je .Ex_blank_three
 cmp al,0xaf
 je .Ex_blank_three
 jmp .Ex_blank_yes
.Ex_blank_e281:
 cmp word ptr [rdi+rcx+1],0x9f81
 jne .Ex_blank_yes
.Ex_blank_three:
 add rcx,3
 jmp .Ex_blank_next
.Ex_blank_one:
 inc rcx
 jmp .Ex_blank_next
.Ex_blank_yes:
 mov eax,1
 ret
.Ex_blank_no:
 xor eax,eax
 ret

.section .rodata
EFRAME .Ex_acp_load,"{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"session/load\",\"params\":{\"sessionId\":"
EFRAME .Ex_acp_load_cwd,",\"cwd\":"
.section .text
.global agent_executor_set_session,agent_executor_session_id
agent_executor_session_id:
 lea rax,[rip+.Ex_thread]
 ret
agent_executor_set_session:
 test rdi,rdi
 jz .Ex_session_clear
 mov r8,rdi
 xor ecx,ecx
.Ex_session_check:
 cmp ecx,255
 jae .Ex_invalid
 cmp byte ptr [r8+rcx],0
 je .Ex_session_copy
 inc ecx
 jmp .Ex_session_check
.Ex_session_copy:
 lea rdi,[rip+.Ex_resume]
 mov rsi,r8
 inc ecx
 rep movsb
 xor eax,eax
 ret
.Ex_session_clear:
 mov byte ptr [rip+.Ex_resume],0
 xor eax,eax
 ret

# Persistent native continuation sidecar. Paths must identify an existing owned
# session-*.json; every directory component is opened with O_NOFOLLOW.
.section .rodata
.Es_root: .asciz "/"
.Es_suffix: .asciz ".agent.json"
.Es_session_prefix: .ascii "session-"
.Es_json_suffix: .ascii ".json"
.Es_hex: .ascii "0123456789abcdef"
.Es_temp_prefix: .ascii ".agent-"
.Es_kind_key: .asciz "kind"
.Es_cwd_key: .asciz "cwd"
.Es_acp: .asciz "acp"
EFRAME .Es_prefix,"{\"kind\":\"acp\",\"sessionId\":"
EFRAME .Es_cwd_field,",\"cwd\":"
EFRAME .Es_end,"}\n"
.section .bss
.Es_parent: .skip 8
.Es_fd: .skip 8
.Es_created: .skip 8
.Es_name: .skip 272
.Es_state_name: .skip 288
.Es_temp: .skip 64
.Es_random: .skip 16
.Es_cwd: .skip 4096
.Es_session: .skip 256
.section .text
.Es_open:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,256
 mov qword ptr [rip+.Es_parent],-1
 mov qword ptr [rip+.Es_fd],-1
 mov qword ptr [rip+.Es_created],0
 test rdi,rdi
 jz .Es_open_bad
 cmp byte ptr [rdi],47
 jne .Es_open_bad
 mov r12,rdi
 xor ebx,ebx
 mov eax,2
 lea rdi,[rip+.Es_root]
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .Es_open_return
 mov [rip+.Es_parent],rax
.Es_component_next:
 cmp byte ptr [r12+rbx],47
 jne .Es_component_copy_start
 inc rbx
 jmp .Es_component_next
.Es_component_copy_start:
 xor r13d,r13d
.Es_component_copy:
 cmp r13d,240
 jae .Es_open_bad
 mov al,[r12+rbx]
 test al,al
 jz .Es_last_component
 cmp al,47
 je .Es_open_component
 mov [rsp+r13],al
 inc r13
 inc rbx
 jmp .Es_component_copy
.Es_open_component:
 mov byte ptr [rsp+r13],0
 cmp r13d,1
 jne .Es_component_not_dot
 cmp byte ptr [rsp],46
 je .Es_open_bad
.Es_component_not_dot:
 cmp r13d,2
 jne .Es_component_regular
 cmp word ptr [rsp],0x2e2e
 je .Es_open_bad
.Es_component_regular:
 mov eax,257
 mov rdi,[rip+.Es_parent]
 mov rsi,rsp
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 js .Es_open_return
 mov r14,rax
 mov eax,3
 mov rdi,[rip+.Es_parent]
 syscall
 mov [rip+.Es_parent],r14
 jmp .Es_component_next
.Es_last_component:
 cmp r13d,13
 jb .Es_open_bad
 mov byte ptr [rsp+r13],0
 lea rdi,[rip+.Es_name]
 mov rsi,rsp
 lea rcx,[r13+1]
 rep movsb
 lea rdi,[rip+.Es_session_prefix]
 mov rsi,rsp
 mov ecx,8
 repe cmpsb
 jne .Es_open_bad
 lea rsi,[rsp+r13-5]
 lea rdi,[rip+.Es_json_suffix]
 mov ecx,5
 repe cmpsb
 jne .Es_open_bad
 mov eax,257
 mov rdi,[rip+.Es_parent]
 lea rsi,[rip+.Es_name]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Es_open_return
 mov [rip+.Es_fd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Ex_stat]
 syscall
 test rax,rax
 js .Es_open_return
 mov eax,[rip+.Ex_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Es_open_bad
 mov eax,107
 syscall
 cmp eax,[rip+.Ex_stat+28]
 jne .Es_open_bad
 mov eax,3
 mov rdi,[rip+.Es_fd]
 syscall
 mov qword ptr [rip+.Es_fd],-1
 lea rdi,[rip+.Es_state_name]
 lea rsi,[rip+.Es_name]
 mov rcx,r13
 rep movsb
 lea rsi,[rip+.Es_suffix]
.Es_suffix_copy:
 lodsb
 stosb
 test al,al
 jnz .Es_suffix_copy
 xor eax,eax
 jmp .Es_open_return
.Es_open_bad:
 mov rax,-22
.Es_open_return:
 add rsp,256
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Es_close:
 push rax
 mov rdi,[rip+.Es_fd]
 cmp rdi,0
 jl .Es_close_parent
 mov eax,3
 syscall
 mov qword ptr [rip+.Es_fd],-1
.Es_close_parent:
 mov rdi,[rip+.Es_parent]
 cmp rdi,0
 jl .Es_close_done
 mov eax,3
 syscall
 mov qword ptr [rip+.Es_parent],-1
.Es_close_done:
 pop rax
 ret
.global agent_executor_save_session,agent_executor_load_session
agent_executor_save_session:
 push rbx
 push r12
 push r13
 push r14
 push r15
 test rsi,rsi
 jz .Es_save_disabled
 cmp qword ptr [rip+.Ex_kind],1
 jne .Es_save_unsupported
 cmp byte ptr [rip+.Ex_thread],0
 je .Es_save_invalid
 mov r12,rdi
 call .Ex_build_begin
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Es_prefix]
 mov edx,OFFSET FLAT:.Es_prefix_len
 call qx_cat@PLT
 test rax,rax
 js .Es_save_invalid
 lea rdi,[rip+.Ex_thread]
 call .Ex_quote_z
 test rax,rax
 js .Es_save_invalid
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Es_cwd_field]
 mov edx,OFFSET FLAT:.Es_cwd_field_len
 call qx_cat@PLT
 test rax,rax
 js .Es_save_invalid
 mov rdi,[rip+.Ex_cwd]
 call .Ex_quote_z
 test rax,rax
 js .Es_save_invalid
 lea rdi,[rip+.Ex_builder]
 lea rsi,[rip+.Es_end]
 mov edx,OFFSET FLAT:.Es_end_len
 call qx_cat@PLT
 test rax,rax
 js .Es_save_invalid
 mov rdi,r12
 call .Es_open
 test rax,rax
 js .Es_save_close
 mov eax,318
 lea rdi,[rip+.Es_random]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,16
 jne .Es_save_io
 lea rdi,[rip+.Es_temp]
 lea rsi,[rip+.Es_temp_prefix]
 mov ecx,7
 rep movsb
 lea rsi,[rip+.Es_random]
 lea r8,[rip+.Es_hex]
 mov ecx,16
.Es_temp_hex:
 lodsb
 movzx edx,al
 shr edx,4
 mov dl,[r8+rdx]
 mov [rdi],dl
 inc rdi
 and eax,15
 mov al,[r8+rax]
 stosb
 loop .Es_temp_hex
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,[rip+.Es_parent]
 lea rsi,[rip+.Es_temp]
 mov edx,0xa00c1
 mov r10d,384
 syscall
 test rax,rax
 js .Es_save_close
 mov [rip+.Es_fd],rax
 mov qword ptr [rip+.Es_created],1
 mov rdi,rax
 mov eax,91
 mov esi,384
 syscall
 test rax,rax
 js .Es_save_cleanup
 xor ebx,ebx
.Es_write:
 mov eax,1
 mov rdi,[rip+.Es_fd]
 lea rsi,[rip+.Ex_tx]
 add rsi,rbx
 mov rdx,[rip+.Ex_builder+16]
 sub rdx,rbx
 syscall
 cmp rax,-4
 je .Es_write
 test rax,rax
 jle .Es_save_io
 add rbx,rax
 cmp rbx,[rip+.Ex_builder+16]
 jb .Es_write
 mov eax,74
 mov rdi,[rip+.Es_fd]
 syscall
 test rax,rax
 js .Es_save_cleanup
 mov eax,3
 mov rdi,[rip+.Es_fd]
 syscall
 mov qword ptr [rip+.Es_fd],-1
 mov eax,264
 mov rdi,[rip+.Es_parent]
 lea rsi,[rip+.Es_temp]
 mov rdx,rdi
 lea r10,[rip+.Es_state_name]
 syscall
 test rax,rax
 js .Es_save_cleanup
 mov qword ptr [rip+.Es_created],0
 mov eax,74
 mov rdi,[rip+.Es_parent]
 syscall
 jmp .Es_save_cleanup
.Es_save_io:
 mov rax,-5
.Es_save_cleanup:
 mov r12,rax
 cmp qword ptr [rip+.Es_created],0
 je .Es_save_cleanup_result
 mov eax,263
 mov rdi,[rip+.Es_parent]
 lea rsi,[rip+.Es_temp]
 xor edx,edx
 syscall
.Es_save_cleanup_result:
 mov rax,r12
.Es_save_close:
 call .Es_close
 jmp .Es_save_return
.Es_save_unsupported:
 mov rax,-95
 jmp .Es_save_return
.Es_save_invalid:
 mov rax,-22
 jmp .Es_save_return
.Es_save_disabled:
 xor eax,eax
.Es_save_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
agent_executor_load_session:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov byte ptr [rip+.Ex_resume],0
 mov r12,rsi
 test rsi,rsi
 jz .Es_load_invalid
 call .Es_open
 test rax,rax
 js .Es_load_close
 mov eax,257
 mov rdi,[rip+.Es_parent]
 lea rsi,[rip+.Es_state_name]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Es_load_close
 mov [rip+.Es_fd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Ex_stat]
 syscall
 test rax,rax
 js .Es_load_close
 mov eax,[rip+.Ex_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Es_load_invalid_close
 mov eax,107
 syscall
 cmp eax,[rip+.Ex_stat+28]
 jne .Es_load_invalid_close
 cmp qword ptr [rip+.Ex_stat+48],65536
 ja .Es_load_invalid_close
 xor ebx,ebx
.Es_load_read:
 cmp ebx,65536
 jae .Es_load_invalid_close
 xor eax,eax
 mov rdi,[rip+.Es_fd]
 lea rsi,[rip+.Ex_frame]
 add rsi,rbx
 mov edx,65536
 sub rdx,rbx
 syscall
 cmp rax,-4
 je .Es_load_read
 test rax,rax
 js .Es_load_close
 jz .Es_load_parse
 add rbx,rax
 jmp .Es_load_read
.Es_load_parse:
 lea rdi,[rip+.Ex_frame]
 mov rsi,rbx
 lea rdx,[rip+.Ex_tokens]
 mov ecx,MAX_TOKENS
 call json_parse@PLT
 test rax,rax
 js .Es_load_invalid_close
 cmp qword ptr [rip+.Ex_tokens+T_TYPE],JT_OBJECT
 jne .Es_load_invalid_close
 xor edi,edi
 lea rsi,[rip+.Es_kind_key]
 lea rdx,[rip+.Ex_textbuf]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Es_load_invalid_close
 lea rdi,[rip+.Ex_textbuf]
 lea rsi,[rip+.Es_acp]
 call .Ex_equal
 test eax,eax
 jz .Es_load_invalid_close
 xor edi,edi
 lea rsi,[rip+.Es_cwd_key]
 lea rdx,[rip+.Es_cwd]
 mov ecx,4096
 call .Ex_string
 test rax,rax
 jle .Es_load_invalid_close
 lea rdi,[rip+.Es_cwd]
 mov rsi,r12
 call .Ex_equal
 test eax,eax
 jz .Es_load_invalid_close
 xor edi,edi
 lea rsi,[rip+.Ex_k_session_id]
 lea rdx,[rip+.Es_session]
 mov ecx,256
 call .Ex_string
 test rax,rax
 jle .Es_load_invalid_close
 lea rdi,[rip+.Es_session]
 call agent_executor_set_session
 jmp .Es_load_close
.Es_load_invalid_close:
 mov rax,-22
.Es_load_close:
 call .Es_close
 jmp .Es_load_return
.Es_load_invalid:
 mov rax,-22
.Es_load_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
