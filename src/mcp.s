# Native MCP stdio manager. Protocol2024-11-05, one sequential caller per process.
# Loading configuration never starts a process. Startup AND every discovered tool
# call pass the caller's approval boundary. No shell or lifecycle script is added.
.include "abi.inc"
.intel_syntax noprefix
.ifndef MCP_TIMEOUT_MS
.equ MCP_TIMEOUT_MS,30000
.endif
.equ M_SERVERS,4
.equ M_TOOLS,16
.equ M_MESSAGE,1048576
.equ M_SERVER_SIZE,1114112
.equ S_PID,0
.equ S_IN,8
.equ S_OUT,16
.equ S_CONNECTED,24
.equ S_TOOLS,32
.equ S_RAWLEN,40
.equ S_RXLEN,48
.equ S_RXPOS,56
.equ S_NEXTID,64
.equ S_UNSUPPORTED,72
.equ S_NAME,128
.equ S_ROOT,256
.equ S_RAW,8192
.equ S_RX,65536
.equ M_TOOL_SIZE,33280
.equ T_SERVER,0
.equ T_NAME,8
.equ T_ORIGINAL,72
.equ T_DEFLEN,200
.equ T_DEFINITION,208
.equ M_POOL_CAP,262144
.macro ME frame=8
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,\frame
.endm
.macro ML frame=8
 add rsp,\frame
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.endm
.macro MA reg,label
 lea \reg,[rip+\label]
.endm
.macro MCAT label
 MA rsi,\label
 mov edx,OFFSET FLAT:\label\()_len
 call .Lm_cat
.endm
.macro MQUOTE ptr,len
 mov rsi,\ptr
 mov rdx,\len
 call .Lm_quote
.endm
.macro MSTR label,text
\label: .ascii "\text"
.equ \label\()_len,.-\label
.endm

.text
.globl mcp_init,mcp_register,mcp_handles,mcp_execute,mcp_definitions,mcp_close,mcp_after_fork

# zlen(pointer,max) -> length/-22. Null pointers and unterminated data reject.
.Lm_zlen:
 test rdi,rdi
 jz .Lm_invalid
 xor eax,eax
.Lm_zlen_loop:
 cmp rax,rsi
 jae .Lm_invalid
 cmp byte ptr [rdi+rax],0
 je .Lm_zlen_done
 inc rax
 jmp .Lm_zlen_loop
.Lm_zlen_done:
 ret
.Lm_invalid:
 mov rax,-22
 ret
.Lm_name:
 xor ecx,ecx
.Lm_name_loop:
 cmp ecx,63
 ja .Lm_invalid
 movzx eax,byte ptr [rdi+rcx]
 test al,al
 jz .Lm_name_done
 cmp al,'-'
 je .Lm_name_next
 cmp al,'_'
 je .Lm_name_next
 mov edx,eax
 sub edx,'0'
 cmp edx,9
 jbe .Lm_name_next
 or eax,32
 sub eax,'a'
 cmp eax,25
 ja .Lm_invalid
.Lm_name_next:
 inc ecx
 jmp .Lm_name_loop
.Lm_name_done:
 test ecx,ecx
 jz .Lm_invalid
 mov eax,ecx
 ret

# Builders are bounded {base,capacity,length}; all failures remain sticky until
# reset and no partially built protocol message is sent.
.Lm_builder:
 mov [rip+.Lm_build],rdi
 mov [rip+.Lm_build+8],rsi
 mov qword ptr [rip+.Lm_build+16],0
 mov qword ptr [rip+.Lm_build_error],0
 ret
.Lm_cat:
 sub rsp,8
 MA rdi,.Lm_build
 call qx_cat
 test rax,rax
 jns .Lm_cat_done
 mov qword ptr [rip+.Lm_build_error],1
.Lm_cat_done:
 add rsp,8
 ret
.Lm_quote:
 sub rsp,8
 MA rdi,.Lm_build
 call qx_quote_cat
 test rax,rax
 jns .Lm_quote_done
 mov qword ptr [rip+.Lm_build_error],1
.Lm_quote_done:
 add rsp,8
 ret
.Lm_catz:
 push rsi
 mov rdi,rsi
 mov esi,M_MESSAGE
 call .Lm_zlen
 pop rsi
 test rax,rax
 js .Lm_catz_bad
 mov rdx,rax
 jmp .Lm_cat
.Lm_catz_bad:
 mov qword ptr [rip+.Lm_build_error],1
 ret
.Lm_number:
 sub rsp,8
 mov rsi,rdi
 MA rdi,.Lm_number_buf
 call qx_uint
 mov rdx,rax
 MA rsi,.Lm_number_buf
 call .Lm_cat
 add rsp,8
 ret
.Lm_finish:
 cmp qword ptr [rip+.Lm_build_error],0
 jne .Lm_capacity
 mov rax,[rip+.Lm_build+16]
 mov rdx,[rip+.Lm_build]
 mov byte ptr [rdx+rax],0
 ret
.Lm_capacity:
 mov rax,-28
 ret

.Lm_parse:
 mov [rip+.Lm_source],rdi
 MA rdx,.Lm_tokens
 mov ecx,MAX_TOKENS
 jmp json_parse
.Lm_find:
 mov rdx,rdi
 mov rcx,rsi
 mov rdi,[rip+.Lm_source]
 MA rsi,.Lm_tokens
 jmp json_find
# token index, output, capacity -> length/-22. Metadata/config C strings cannot
# contain embedded NUL; prompt/tool-result text uses a separate length API.
.Lm_decode:
 ME
 mov r12,rsi
 mov r13,rdx
 test r13,r13
 jz .Lm_decode_bad
 cmp rdi,MAX_TOKENS
 jae .Lm_decode_bad
 mov rax,rdi
 shl rax,5
 MA rcx,.Lm_tokens
 add rax,rcx
 cmp qword ptr [rax+T_TYPE],JT_STRING
 jne .Lm_decode_bad
 mov rsi,[rax+T_START]
 add rsi,[rip+.Lm_source]
 mov rdx,[rax+T_LEN]
 mov rdi,r12
 lea rcx,[r13-1]
 call json_decode
 test rax,rax
 js .Lm_decode_return
 xor ecx,ecx
.Lm_decode_nul:
 cmp rcx,rax
 jae .Lm_decode_done
 cmp byte ptr [r12+rcx],0
 je .Lm_decode_bad
 inc rcx
 jmp .Lm_decode_nul
.Lm_decode_done:
 mov byte ptr [r12+rax],0
 jmp .Lm_decode_return
.Lm_decode_bad:
 mov rax,-22
.Lm_decode_return:
 ML
# token index -> rax complete raw JSON pointer, rdx raw length.
.Lm_span:
 shl rdi,5
 MA rax,.Lm_tokens
 add rax,rdi
 mov rdx,[rax+T_LEN]
 mov rcx,[rax+T_START]
 cmp qword ptr [rax+T_TYPE],JT_STRING
 jne .Lm_span_other
 dec rcx
 add rdx,2
.Lm_span_other:
 add rcx,[rip+.Lm_source]
 mov rax,rcx
 ret

# Optional callback()->0 or negative cancellation. No network-layer dependency.
.globl mcp_set_cancel
mcp_set_cancel:
 mov [rip+.Lm_cancel_callback],rdi
 xor eax,eax
 ret

mcp_init:
 ME
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 call mcp_close
 mov [rip+.Lm_approval],r12
 mov [rip+.Lm_allow],r13
 mov [rip+.Lm_envp],r14
 mov qword ptr [rip+.Lm_count],0
 mov qword ptr [rip+.Lm_cancel_callback],0
 # Only metadata is touched. Payload/configuration BSS pages stay lazy.
 MA rdi,.Lm_ioctl
 mov eax,16
 xor edi,edi
 mov esi,0x5401
 MA rdx,.Lm_ioctl
 syscall
 xor ecx,ecx
 test rax,rax
 sete cl
 mov [rip+.Lm_interactive],rcx
 xor eax,eax
 ML

mcp_register:
 ME 40
 mov [rsp+8],rdi
 mov [rsp+16],rsi
 mov [rsp+24],rdx
 mov [rsp+32],rcx
 mov rax,[rip+.Lm_count]
 mov [rsp],rax
 call .Lm_name
 test rax,rax
 js .Lm_register_bad
 mov rdi,[rsp+16]
 mov esi,4096
 call .Lm_zlen
 test rax,rax
 js .Lm_register_bad
 mov rdi,[rsp+24]
 mov rsi,[rsp+32]
 call .Lm_parse
 test rax,rax
 js .Lm_register_bad
 cmp qword ptr [rip+.Lm_tokens+T_TYPE],JT_OBJECT
 jne .Lm_register_bad
 mov r12d,1
 mov r13,[rip+.Lm_tokens+T_END]
.Lm_register_loop:
 cmp r12,r13
 jae .Lm_register_done
 mov rdi,r12
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_register_bad
 MA rdi,.Lm_temp_name
 call .Lm_name
 test rax,rax
 js .Lm_register_bad
 mov rbx,[rip+.Lm_count]
 cmp rbx,M_SERVERS
 jae .Lm_register_bad
 imul r14,rbx,M_SERVER_SIZE
 MA r15,.Lm_servers
 add r14,r15
 mov qword ptr [r14+S_PID],0
 mov qword ptr [r14+S_IN],-1
 mov qword ptr [r14+S_OUT],-1
 mov qword ptr [r14+S_CONNECTED],0
 mov qword ptr [r14+S_TOOLS],0
 mov qword ptr [r14+S_RXLEN],0
 mov qword ptr [r14+S_RXPOS],0
 mov qword ptr [r14+S_NEXTID],0
 mov qword ptr [r14+S_UNSUPPORTED],0
 lea rdi,[r14+S_NAME]
 mov esi,127
 call .Lm_builder
 mov rsi,[rsp+8]
 call .Lm_catz
 MCAT .Lm_colon
 MA rsi,.Lm_temp_name
 call .Lm_catz
 call .Lm_finish
 test rax,rax
 js .Lm_register_bad
 xor ebp,ebp
.Lm_register_duplicate:
 cmp rbp,rbx
 jae .Lm_register_unique
 imul rax,rbp,M_SERVER_SIZE
 MA rsi,.Lm_servers+S_NAME
 add rsi,rax
 lea rdi,[r14+S_NAME]
 call qx_streq
 test eax,eax
 jnz .Lm_register_bad
 inc ebp
 jmp .Lm_register_duplicate
.Lm_register_unique:
 mov rsi,[rsp+16]
 mov rdi,rsi
 mov esi,4096
 call .Lm_zlen
 mov rcx,rax
 inc rcx
 mov rsi,[rsp+16]
 lea rdi,[r14+S_ROOT]
 rep movsb
 inc r12
 mov rax,r12
 shl rax,5
 MA rdx,.Lm_tokens
 add rax,rdx
 cmp qword ptr [rax+T_TYPE],JT_OBJECT
 jne .Lm_register_bad
 mov rcx,[rax+T_LEN]
 cmp rcx,32767
 ja .Lm_register_bad
 mov [r14+S_RAWLEN],rcx
 mov rsi,[rax+T_START]
 add rsi,[rip+.Lm_source]
 lea rdi,[r14+S_RAW]
 rep movsb
 mov byte ptr [rdi],0
 mov rdi,r12
 MA rsi,.Lm_key_url
 call .Lm_find
 test rax,rax
 js .Lm_register_no_url
 mov qword ptr [r14+S_UNSUPPORTED],1
.Lm_register_no_url:
 mov rdi,r12
 MA rsi,.Lm_key_command
 call .Lm_find
 test rax,rax
 jns .Lm_register_command
 mov qword ptr [r14+S_UNSUPPORTED],1
 jmp .Lm_register_advance
.Lm_register_command:
 shl rax,5
 MA rdx,.Lm_tokens
 cmp qword ptr [rdx+rax+T_TYPE],JT_STRING
 jne .Lm_register_bad
.Lm_register_advance:
 inc qword ptr [rip+.Lm_count]
 mov rax,r12
 shl rax,5
 MA rdx,.Lm_tokens
 mov r12,[rdx+rax+T_END]
 jmp .Lm_register_loop
.Lm_register_done:
 xor eax,eax
 ML 40
.Lm_register_bad:
 mov rax,[rsp]
 mov [rip+.Lm_count],rax
 mov rax,-22
 ML 40

# Close only this process's servers; inherited descriptors are detached by the
# distinct after_fork path, which never signals or waits on a parent-owned PID.
.Lm_clear_tools:
 imul rax,rdi,M_TOOLS*M_TOOL_SIZE
 MA rdx,.Lm_tools
 add rdx,rax
 test rsi,rsi
 jz .Lm_clear_tools_done
 mov rcx,rsi
.Lm_clear_tools_loop:
 mov qword ptr [rdx+T_DEFLEN],0
 add rdx,M_TOOL_SIZE
 dec ecx
 jnz .Lm_clear_tools_loop
.Lm_clear_tools_done:
 ret
.Lm_stop_server:
 ME
 mov r12,rdi
 mov r13,[r12+S_PID]
 test r13,r13
 jle .Lm_stop_metadata
 mov rdi,[r12+S_IN]
 test rdi,rdi
 js .Lm_stop_out
 mov eax,3
 syscall
.Lm_stop_out:
 mov rdi,[r12+S_OUT]
 test rdi,rdi
 js .Lm_stop_kill
 mov eax,3
 syscall
.Lm_stop_kill:
 mov eax,62
 mov rdi,r13
 neg rdi
 mov esi,9
 syscall
 cmp rax,-3
 jne .Lm_stop_wait
 mov eax,62
 mov rdi,r13
 mov esi,9
 syscall
.Lm_stop_wait:
 mov eax,61
 mov rdi,r13
 MA rsi,.Lm_wait_status
 xor edx,edx
 xor r10d,r10d
 syscall
 cmp rax,-4
 je .Lm_stop_wait
.Lm_stop_metadata:
 mov qword ptr [r12+S_PID],0
 mov qword ptr [r12+S_IN],-1
 mov qword ptr [r12+S_OUT],-1
 mov qword ptr [r12+S_CONNECTED],0
 mov rsi,[r12+S_TOOLS]
 mov qword ptr [r12+S_TOOLS],0
 mov qword ptr [r12+S_RXLEN],0
 mov qword ptr [r12+S_RXPOS],0
 mov rax,r12
 MA rcx,.Lm_servers
 sub rax,rcx
 xor edx,edx
 mov ecx,M_SERVER_SIZE
 div rcx
 mov rdi,rax
 call .Lm_clear_tools
 ML
mcp_close:
 ME
 xor r12d,r12d
.Lm_close_loop:
 cmp r12,[rip+.Lm_count]
 jae .Lm_close_done
 imul rdi,r12,M_SERVER_SIZE
 MA rax,.Lm_servers
 add rdi,rax
 call .Lm_stop_server
 inc r12d
 jmp .Lm_close_loop
.Lm_close_done:
 xor eax,eax
 ML
mcp_after_fork:
 ME
 xor r12d,r12d
.Lm_fork_loop:
 cmp r12,[rip+.Lm_count]
 jae .Lm_fork_done
 imul r13,r12,M_SERVER_SIZE
 MA rax,.Lm_servers
 add r13,rax
 cmp qword ptr [r13+S_PID],0
 jle .Lm_fork_metadata
 mov rdi,[r13+S_IN]
 mov eax,3
 syscall
 mov rdi,[r13+S_OUT]
 mov eax,3
 syscall
.Lm_fork_metadata:
 mov qword ptr [r13+S_PID],0
 mov qword ptr [r13+S_IN],-1
 mov qword ptr [r13+S_OUT],-1
 mov qword ptr [r13+S_CONNECTED],0
 mov rsi,[r13+S_TOOLS]
 mov qword ptr [r13+S_TOOLS],0
 mov qword ptr [r13+S_RXLEN],0
 mov qword ptr [r13+S_RXPOS],0
 mov rdi,r12
 call .Lm_clear_tools
 inc r12d
 jmp .Lm_fork_loop
.Lm_fork_done:
 mov qword ptr [rip+.Lm_approval],0
 mov qword ptr [rip+.Lm_allow],0
 mov qword ptr [rip+.Lm_cancel_callback],0
 xor eax,eax
 ML

# Timeouts are per RPC and do not restart after notifications or partial reads.
.Lm_deadline:
 mov eax,228
 mov edi,1
 MA rsi,.Lm_clock
 syscall
 test rax,rax
 js .Lm_deadline_bad
 mov rax,[rip+.Lm_clock]
 mov ecx,1000000000
 mul rcx
 add rax,[rip+.Lm_clock+8]
 mov rcx,MCP_TIMEOUT_MS*1000000
 add rax,rcx
 mov [rip+.Lm_deadline_ns],rax
 xor eax,eax
 ret
.Lm_deadline_bad:
 mov rax,-5
 ret
.Lm_wait:
 ME
 mov r12d,edi
 mov r13d,esi
.Lm_wait_loop:
 mov rax,[rip+.Lm_cancel_callback]
 test rax,rax
 jz .Lm_wait_clock
 call rax
 test rax,rax
 js .Lm_wait_cancel
.Lm_wait_clock:
 mov eax,228
 mov edi,1
 MA rsi,.Lm_clock
 syscall
 test rax,rax
 js .Lm_wait_io
 mov rax,[rip+.Lm_clock]
 mov ecx,1000000000
 mul rcx
 add rax,[rip+.Lm_clock+8]
 mov rdx,[rip+.Lm_deadline_ns]
 sub rdx,rax
 jbe .Lm_wait_timeout
 lea rax,[rdx+999999]
 xor edx,edx
 mov ecx,1000000
 div rcx
 mov ebp,eax
 cmp ebp,100
 mov eax,100
 cmova ebp,eax
 MA rdi,.Lm_pollfds
 mov [rdi],r12d
 mov [rdi+4],r13w
 mov word ptr [rdi+6],0
 mov dword ptr [rdi+8],-1
 cmp qword ptr [rip+.Lm_cancel_callback],0
 jne .Lm_wait_poll
 cmp qword ptr [rip+.Lm_interactive],0
 je .Lm_wait_poll
 mov dword ptr [rdi+8],0
.Lm_wait_poll:
 mov word ptr [rdi+12],1
 mov word ptr [rdi+14],0
 mov eax,7
 mov esi,2
 mov edx,ebp
 syscall
 cmp rax,-4
 je .Lm_wait_loop
 test rax,rax
 js .Lm_wait_return
 jz .Lm_wait_loop
 test word ptr [rip+.Lm_pollfds+14],1
 jz .Lm_wait_server
 xor eax,eax
 xor edi,edi
 MA rsi,.Lm_input_char
 mov edx,1
 syscall
 cmp rax,1
 jne .Lm_wait_server
 cmp byte ptr [rip+.Lm_input_char],3
 jne .Lm_wait_server
 mov rax,-125
 jmp .Lm_wait_return
.Lm_wait_server:
 test word ptr [rip+.Lm_pollfds+6],0x3d
 jz .Lm_wait_loop
 xor eax,eax
 jmp .Lm_wait_return
.Lm_wait_cancel:
 mov rax,-125
 jmp .Lm_wait_return
.Lm_wait_timeout:
 mov rax,-110
 jmp .Lm_wait_return
.Lm_wait_io:
 mov rax,-5
.Lm_wait_return:
 ML

# Pipe writes block SIGPIPE only in this thread and consume their own pending
# EPIPE signal before restoring the old mask. No global signal policy changes.
.Lm_write:
 ME 40
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rdx
 mov qword ptr [rsp+8],4096
 mov qword ptr [rsp+16],0
 mov qword ptr [rsp+24],0
 mov eax,14
 xor edi,edi
 lea rsi,[rsp+8]
 mov rdx,rsp
 mov r10d,8
 syscall
 test rax,rax
 js .Lm_write_return
.Lm_write_loop:
 test r14,r14
 jz .Lm_write_ok
 mov eax,1
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 syscall
 cmp rax,-4
 je .Lm_write_loop
 cmp rax,-11
 je .Lm_write_wait
 test rax,rax
 js .Lm_write_unblock
 jz .Lm_write_zero
 add r13,rax
 sub r14,rax
 jmp .Lm_write_loop
.Lm_write_wait:
 mov rdi,r12
 mov esi,4
 call .Lm_wait
 test rax,rax
 jns .Lm_write_loop
 jmp .Lm_write_unblock
.Lm_write_zero:
 mov rax,-32
 jmp .Lm_write_unblock
.Lm_write_ok:
 mov rax,r15
.Lm_write_unblock:
 mov rbx,rax
 cmp rbx,-32
 jne .Lm_write_restore
 test qword ptr [rsp],4096
 jnz .Lm_write_restore
 mov eax,128
 lea rdi,[rsp+8]
 xor esi,esi
 lea rdx,[rsp+16]
 mov r10d,8
 syscall
.Lm_write_restore:
 mov eax,14
 mov edi,2
 mov rsi,rsp
 xor edx,edx
 mov r10d,8
 syscall
 mov rax,rbx
.Lm_write_return:
 ML 40

# .Lm_current points to the selected server. RX queues retain surplus lines.
.Lm_readline:
 ME
 mov r12,[rip+.Lm_current]
.Lm_line_again:
 mov r13,[r12+S_RXPOS]
 mov r14,[r12+S_RXLEN]
 mov rbx,r13
 lea r15,[r12+S_RX]
.Lm_line_scan:
 cmp rbx,r14
 jae .Lm_line_read
 cmp byte ptr [r15+rbx],10
 je .Lm_line_found
 inc rbx
 jmp .Lm_line_scan
.Lm_line_found:
 lea rax,[rbx+1]
 mov [r12+S_RXPOS],rax
 mov rbp,rbx
 sub rbp,r13
 test rbp,rbp
 jz .Lm_line_again
 cmp byte ptr [r15+rbx-1],13
 jne .Lm_line_copy
 dec rbp
 jz .Lm_line_again
.Lm_line_copy:
 MA rdi,.Lm_response
 lea rsi,[r15+r13]
 mov rcx,rbp
 rep movsb
 mov byte ptr [rdi],0
 mov rax,rbp
 jmp .Lm_line_return
.Lm_line_read:
 test r13,r13
 jz .Lm_line_space
 mov rcx,r14
 sub rcx,r13
 mov r14,rcx
 mov rdi,r15
 lea rsi,[r15+r13]
 rep movsb
 mov [r12+S_RXLEN],r14
 mov qword ptr [r12+S_RXPOS],0
.Lm_line_space:
 cmp r14,M_MESSAGE-1
 jae .Lm_line_large
 mov rdi,[r12+S_OUT]
 mov esi,1
 call .Lm_wait
 test rax,rax
 js .Lm_line_return
 xor eax,eax
 mov rdi,[r12+S_OUT]
 lea rsi,[r15+r14]
 mov edx,M_MESSAGE-1
 sub rdx,r14
 syscall
 cmp rax,-4
 je .Lm_line_again
 cmp rax,-11
 je .Lm_line_again
 test rax,rax
 js .Lm_line_return
 jz .Lm_line_eof
 add r14,rax
 mov [r12+S_RXLEN],r14
 jmp .Lm_line_again
.Lm_line_large:
 mov rax,-90
 jmp .Lm_line_return
.Lm_line_eof:
 mov rax,-32
.Lm_line_return:
 ML

# Prefix match on a known acquired byte span, not unbounded look-ahead.
.Lm_bytes_equal:
 xor eax,eax
 xor ecx,ecx
.Lm_bytes_loop:
 cmp rcx,rdx
 jae .Lm_bytes_yes
 mov al,[rdi+rcx]
 cmp al,[rsi+rcx]
 jne .Lm_bytes_no
 inc rcx
 jmp .Lm_bytes_loop
.Lm_bytes_yes:
 mov eax,1
 ret
.Lm_bytes_no:
 xor eax,eax
 ret

# Source string, destination, capacity, plugin root -> bytes/-28.
.Lm_expand:
 ME 24
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 mov esi,4096
 call .Lm_zlen
 test rax,rax
 js .Lm_expand_return
 mov [rsp],rax
 mov rdi,r15
 mov esi,4096
 call .Lm_zlen
 test rax,rax
 js .Lm_expand_return
 mov [rsp+8],rax
 xor ebx,ebx
 xor ebp,ebp
.Lm_expand_loop:
 cmp rbp,[rsp]
 jae .Lm_expand_done
 mov rax,[rsp]
 sub rax,rbp
 cmp rax,OFFSET FLAT:.Lm_var_root_len
 jb .Lm_expand_plugin_var
 lea rdi,[r12+rbp]
 MA rsi,.Lm_var_root
 mov edx,OFFSET FLAT:.Lm_var_root_len
 call .Lm_bytes_equal
 test eax,eax
 jnz .Lm_expand_root
.Lm_expand_plugin_var:
 mov rax,[rsp]
 sub rax,rbp
 cmp rax,OFFSET FLAT:.Lm_var_claude_len
 jb .Lm_expand_byte
 lea rdi,[r12+rbp]
 MA rsi,.Lm_var_claude
 mov edx,OFFSET FLAT:.Lm_var_claude_len
 call .Lm_bytes_equal
 test eax,eax
 jz .Lm_expand_byte
 add rbp,OFFSET FLAT:.Lm_var_claude_len
 jmp .Lm_expand_copy_root
.Lm_expand_root:
 add rbp,OFFSET FLAT:.Lm_var_root_len
.Lm_expand_copy_root:
 mov rcx,[rsp+8]
 lea rax,[rbx+rcx]
 cmp rax,r14
 jae .Lm_expand_cap
 lea rdi,[r13+rbx]
 mov rsi,r15
 rep movsb
 mov rbx,rax
 jmp .Lm_expand_loop
.Lm_expand_byte:
 lea rax,[rbx+1]
 cmp rax,r14
 jae .Lm_expand_cap
 mov al,[r12+rbp]
 mov [r13+rbx],al
 inc rbx
 inc rbp
 jmp .Lm_expand_loop
.Lm_expand_done:
 mov byte ptr [r13+rbx],0
 mov rax,rbx
 jmp .Lm_expand_return
.Lm_expand_cap:
 mov rax,-28
.Lm_expand_return:
 ML 24

# Decode+expand one string into the parent's temporary exec pool. The child gets
# its own forked copy before any later configuration can reuse that pool.
.Lm_pool_decode:
 ME
 MA rsi,.Lm_temp_string
 mov edx,4096
 call .Lm_decode
 test rax,rax
 js .Lm_pool_return
 mov rbx,[rip+.Lm_pool_used]
 cmp rbx,M_POOL_CAP-4096
 ja .Lm_pool_bad
 MA r13,.Lm_pool
 add r13,rbx
 MA rdi,.Lm_temp_string
 mov rsi,r13
 mov edx,4096
 mov rax,[rip+.Lm_current]
 lea rcx,[rax+S_ROOT]
 call .Lm_expand
 test rax,rax
 js .Lm_pool_return
 lea rdx,[rax+1]
 add rdx,rbx
 mov [rip+.Lm_pool_used],rdx
 mov rdx,rax
 mov rax,r13
 jmp .Lm_pool_return
.Lm_pool_bad:
 mov rax,-28
.Lm_pool_return:
 ML

# Merge explicit KEY=value overrides into the inherited pointer vector. Values
# are never included in approval/status output. Key syntax is shell-independent.
.Lm_environment:
 ME 24
 xor r12d,r12d
 mov r13,[rip+.Lm_envp]
 MA r14,.Lm_envvec
 test r13,r13
 jz .Lm_environment_base_done
.Lm_environment_base:
 cmp r12,1024
 jae .Lm_environment_bad
 mov rax,[r13+r12*8]
 test rax,rax
 jz .Lm_environment_base_done
 mov [r14+r12*8],rax
 inc r12
 jmp .Lm_environment_base
.Lm_environment_base_done:
 mov [rip+.Lm_envcount],r12
 xor edi,edi
 MA rsi,.Lm_key_env
 call .Lm_find
 test rax,rax
 js .Lm_environment_done
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 add rdx,rcx
 cmp qword ptr [rdx+T_TYPE],JT_OBJECT
 jne .Lm_environment_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
 mov qword ptr [rsp+16],0
.Lm_environment_override:
 cmp r12,r13
 jae .Lm_environment_done
 inc qword ptr [rsp+16]
 cmp qword ptr [rsp+16],32
 ja .Lm_environment_bad
 mov rdi,r12
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 jle .Lm_environment_bad
 mov [rsp],rax
 MA rdi,.Lm_temp_name
 xor ecx,ecx
.Lm_environment_key:
 cmp rcx,[rsp]
 jae .Lm_environment_value
 movzx eax,byte ptr [rdi+rcx]
 cmp al,'_'
 je .Lm_environment_key_next
 mov edx,eax
 or edx,32
 sub edx,'a'
 cmp edx,25
 jbe .Lm_environment_key_next
 test rcx,rcx
 jz .Lm_environment_bad
 sub eax,'0'
 cmp eax,9
 ja .Lm_environment_bad
.Lm_environment_key_next:
 inc rcx
 jmp .Lm_environment_key
.Lm_environment_value:
 inc r12
 mov rdi,r12
 call .Lm_pool_decode
 test rax,rax
 js .Lm_environment_return
 mov r15,rax
 mov rbx,rdx
 mov rax,[rip+.Lm_pool_used]
 MA rbp,.Lm_pool
 add rbp,rax
 add rax,[rsp]
 add rax,rbx
 add rax,2
 cmp rax,M_POOL_CAP
 ja .Lm_environment_bad
 mov [rip+.Lm_pool_used],rax
 mov rdi,rbp
 MA rsi,.Lm_temp_name
 mov rcx,[rsp]
 rep movsb
 mov byte ptr [rdi],'='
 inc rdi
 mov rsi,r15
 mov rcx,rbx
 rep movsb
 mov byte ptr [rdi],0
 xor r15d,r15d
.Lm_environment_replace:
 cmp r15,[rip+.Lm_envcount]
 jae .Lm_environment_add
 mov rdi,[r14+r15*8]
 MA rsi,.Lm_temp_name
 mov rdx,[rsp]
 call .Lm_bytes_equal
 test eax,eax
 jz .Lm_environment_next
 mov rdi,[r14+r15*8]
 mov rcx,[rsp]
 cmp byte ptr [rdi+rcx],'='
 jne .Lm_environment_next
 mov [r14+r15*8],rbp
 jmp .Lm_environment_advance
.Lm_environment_next:
 inc r15
 jmp .Lm_environment_replace
.Lm_environment_add:
 cmp r15,1056
 jae .Lm_environment_bad
 mov [r14+r15*8],rbp
 inc qword ptr [rip+.Lm_envcount]
.Lm_environment_advance:
 inc r12
 jmp .Lm_environment_override
.Lm_environment_done:
 mov rax,[rip+.Lm_envcount]
 mov qword ptr [r14+rax*8],0
 xor eax,eax
 jmp .Lm_environment_return
.Lm_environment_bad:
 mov rax,-22
.Lm_environment_return:
 ML 24

.Lm_build_exec:
 ME
 mov rbx,[rip+.Lm_current]
 cmp qword ptr [rbx+S_UNSUPPORTED],0
 jne .Lm_exec_bad
 mov qword ptr [rip+.Lm_pool_used],0
 lea rdi,[rbx+S_RAW]
 mov rsi,[rbx+S_RAWLEN]
 call .Lm_parse
 test rax,rax
 js .Lm_exec_return
 # Local stdio only; even a manifest's trusted:true cannot enable execution.
 xor edi,edi
 MA rsi,.Lm_key_transport
 call .Lm_find
 test rax,rax
 js .Lm_exec_type
 mov rdi,rax
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_exec_return
 MA rdi,.Lm_temp_name
 MA rsi,.Lm_stdio
 call qx_streq
 test eax,eax
 jz .Lm_exec_bad
.Lm_exec_type:
 xor edi,edi
 MA rsi,.Lm_key_type
 call .Lm_find
 test rax,rax
 js .Lm_exec_command
 mov rdi,rax
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_exec_return
 MA rdi,.Lm_temp_name
 MA rsi,.Lm_stdio
 call qx_streq
 test eax,eax
 jz .Lm_exec_bad
.Lm_exec_command:
 xor edi,edi
 MA rsi,.Lm_key_command
 call .Lm_find
 test rax,rax
 js .Lm_exec_bad
 mov rdi,rax
 call .Lm_pool_decode
 test rax,rax
 js .Lm_exec_return
 test rdx,rdx
 jz .Lm_exec_bad
 mov [rip+.Lm_command],rax
 MA r12,.Lm_argv
 mov [r12],rax
 mov qword ptr [rip+.Lm_argc],1
 xor edi,edi
 MA rsi,.Lm_key_args
 call .Lm_find
 test rax,rax
 js .Lm_exec_env
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 add rdx,rcx
 cmp qword ptr [rdx+T_TYPE],JT_ARRAY
 jne .Lm_exec_bad
 mov r13,[rdx+T_END]
 lea r14,[rax+1]
.Lm_exec_argument:
 cmp r14,r13
 jae .Lm_exec_env
 mov r15,[rip+.Lm_argc]
 cmp r15,33
 jae .Lm_exec_bad
 mov rdi,r14
 call .Lm_pool_decode
 test rax,rax
 js .Lm_exec_return
 mov [r12+r15*8],rax
 inc qword ptr [rip+.Lm_argc]
 inc r14
 jmp .Lm_exec_argument
.Lm_exec_env:
 mov rax,[rip+.Lm_argc]
 mov qword ptr [r12+rax*8],0
 call .Lm_environment
 jmp .Lm_exec_return
.Lm_exec_bad:
 mov rax,-22
.Lm_exec_return:
 ML

# Recognize common secret-bearing CLI flags/header values for permission display.
# Only the displayed copy is redacted; argv itself remains exact.
.Lm_sensitive:
 ME
 mov r12,rdi
 mov esi,4096
 call .Lm_zlen
 test rax,rax
 js .Lm_sensitive_yes
 mov r13,rax
 xor r14d,r14d
.Lm_sensitive_pattern:
 cmp r14,7
 jae .Lm_sensitive_no
 MA rax,.Lm_sensitive_table
 movsxd r15,dword ptr [rax+r14*4]
 add r15,rax
 mov rdi,r15
 mov esi,64
 call .Lm_zlen
 mov rbp,rax
 xor ebx,ebx
.Lm_sensitive_position:
 lea rax,[rbx+rbp]
 cmp rax,r13
 ja .Lm_sensitive_next
 xor ecx,ecx
.Lm_sensitive_byte:
 cmp rcx,rbp
 jae .Lm_sensitive_yes
 movzx eax,byte ptr [r12+rbx]
 # Match from current candidate + pattern offset.
 lea rdx,[rbx+rcx]
 movzx eax,byte ptr [r12+rdx]
 or eax,32
 cmp al,[r15+rcx]
 jne .Lm_sensitive_advance
 inc ecx
 jmp .Lm_sensitive_byte
.Lm_sensitive_advance:
 inc rbx
 jmp .Lm_sensitive_position
.Lm_sensitive_next:
 inc r14
 jmp .Lm_sensitive_pattern
.Lm_sensitive_yes:
 mov eax,1
 jmp .Lm_sensitive_return
.Lm_sensitive_no:
 xor eax,eax
.Lm_sensitive_return:
 ML

.Lm_start_approval:
 ME
 cmp qword ptr [rip+.Lm_allow],0
 jne .Lm_approval_yes
 cmp qword ptr [rip+.Lm_approval],0
 je .Lm_approval_no
 MA rdi,.Lm_preview
 mov esi,65535
 call .Lm_builder
 MCAT .Lm_start_text
 mov rax,[rip+.Lm_current]
 lea rsi,[rax+S_NAME]
 call .Lm_catz
 MCAT .Lm_exec_text
 mov rsi,[rip+.Lm_command]
 call .Lm_catz
 MCAT .Lm_args_text
 xor r12d,r12d
 xor r13d,r13d
 MA r14,.Lm_argv
.Lm_preview_arg:
 cmp r12,[rip+.Lm_argc]
 jae .Lm_preview_done
 test r12,r12
 jz .Lm_preview_arg_text
 MCAT .Lm_space
.Lm_preview_arg_text:
 mov r15,[r14+r12*8]
 test r13d,r13d
 jnz .Lm_preview_redacted_value
 mov rdi,r15
 call .Lm_sensitive
 test eax,eax
 jz .Lm_preview_plain
 cmp byte ptr [r15],'-'
 jne .Lm_preview_redacted_value
 mov rdi,r15
 mov esi,4096
 call .Lm_zlen
 xor ecx,ecx
.Lm_preview_equals:
 cmp rcx,rax
 jae .Lm_preview_secret_flag
 cmp byte ptr [r15+rcx],'='
 je .Lm_preview_secret_equals
 inc rcx
 jmp .Lm_preview_equals
.Lm_preview_secret_equals:
 mov rsi,r15
 mov rdx,rcx
 inc rdx
 call .Lm_cat
 MCAT .Lm_redacted
 jmp .Lm_preview_next
.Lm_preview_secret_flag:
 mov r13d,1
 jmp .Lm_preview_quote
.Lm_preview_plain:
 xor r13d,r13d
.Lm_preview_quote:
 mov rdi,r15
 mov esi,4096
 call .Lm_zlen
 mov rsi,r15
 mov rdx,rax
 call .Lm_quote
 jmp .Lm_preview_next
.Lm_preview_redacted_value:
 xor r13d,r13d
 MCAT .Lm_redacted
.Lm_preview_next:
 inc r12
 jmp .Lm_preview_arg
.Lm_preview_done:
 MCAT .Lm_permissions_text
 call .Lm_finish
 test rax,rax
 js .Lm_approval_no
 MA rdi,.Lm_preview
 mov rax,[rip+.Lm_approval]
 call rax
 test rax,rax
 setne al
 movzx eax,al
 jmp .Lm_approval_return
.Lm_approval_yes:
 mov eax,1
 jmp .Lm_approval_return
.Lm_approval_no:
 xor eax,eax
.Lm_approval_return:
 ML

# Child-only explicit execve/PATH resolution. No ENOEXEC shell fallback.
.Lm_child_exec:
 mov rdi,[rip+.Lm_command]
 mov esi,4096
 call .Lm_zlen
 test rax,rax
 js .Lm_child_exit
 mov r12,rax
 mov r13,[rip+.Lm_command]
 xor ecx,ecx
.Lm_child_slash:
 cmp rcx,r12
 jae .Lm_child_path
 cmp byte ptr [r13+rcx],'/'
 je .Lm_child_direct
 inc rcx
 jmp .Lm_child_slash
.Lm_child_direct:
 mov eax,59
 mov rdi,r13
 MA rsi,.Lm_argv
 MA rdx,.Lm_envvec
 syscall
 jmp .Lm_child_exit
.Lm_child_path:
 MA rdi,.Lm_envvec
 MA rsi,.Lm_key_path
 call qx_env_get
 test rax,rax
 jnz .Lm_child_path_found
 MA rax,.Lm_default_path
.Lm_child_path_found:
 mov r14,rax
 xor r15d,r15d
.Lm_child_component:
 MA rdi,.Lm_exec_path
 xor ebx,ebx
.Lm_child_path_byte:
 cmp r15,65536
 jae .Lm_child_exit
 mov al,[r14+r15]
 test al,al
 jz .Lm_child_path_end
 cmp al,':'
 je .Lm_child_path_end
 cmp ebx,4000
 jae .Lm_child_exit
 mov [rdi+rbx],al
 inc ebx
 inc r15
 jmp .Lm_child_path_byte
.Lm_child_path_end:
 mov [rip+.Lm_path_delimiter],al
 test ebx,ebx
 jz .Lm_child_path_command
 mov byte ptr [rdi+rbx],'/'
 inc ebx
.Lm_child_path_command:
 lea rax,[rbx+r12]
 cmp rax,4095
 ja .Lm_child_exit
 add rdi,rbx
 mov rsi,r13
 mov rcx,r12
 rep movsb
 mov byte ptr [rdi],0
 mov eax,59
 MA rdi,.Lm_exec_path
 MA rsi,.Lm_argv
 MA rdx,.Lm_envvec
 syscall
 cmp byte ptr [rip+.Lm_path_delimiter],0
 je .Lm_child_exit
 inc r15
 jmp .Lm_child_component
.Lm_child_exit:
 mov eax,60
 mov edi,127
 syscall
 ud2

.Lm_spawn:
 ME
 mov r12,[rip+.Lm_current]
 mov eax,293
 MA rdi,.Lm_pipes
 mov esi,0x80000
 syscall
 test rax,rax
 js .Lm_spawn_return
 mov eax,293
 MA rdi,.Lm_pipes+8
 mov esi,0x80000
 syscall
 test rax,rax
 js .Lm_spawn_first_cleanup
 mov eax,39
 syscall
 mov [rip+.Lm_parent_pid],rax
 mov eax,57
 syscall
 test rax,rax
 js .Lm_spawn_all_cleanup
 jz .Lm_spawn_child
 mov [r12+S_PID],rax
 mov eax,dword ptr [rip+.Lm_pipes+4]
 mov [r12+S_IN],rax
 mov eax,dword ptr [rip+.Lm_pipes+8]
 mov [r12+S_OUT],rax
 mov eax,3
 mov edi,dword ptr [rip+.Lm_pipes]
 syscall
 mov eax,3
 mov edi,dword ptr [rip+.Lm_pipes+12]
 syscall
 mov eax,72
 mov rdi,[r12+S_IN]
 mov esi,4
 mov edx,0x800
 syscall
 test rax,rax
 js .Lm_spawn_failed
 mov eax,72
 mov rdi,[r12+S_OUT]
 mov esi,4
 mov edx,0x800
 syscall
 test rax,rax
 js .Lm_spawn_failed
 mov qword ptr [r12+S_RXLEN],0
 mov qword ptr [r12+S_RXPOS],0
 xor eax,eax
 jmp .Lm_spawn_return
.Lm_spawn_failed:
 mov rdi,r12
 call .Lm_stop_server
 mov rax,-5
 jmp .Lm_spawn_return
.Lm_spawn_all_cleanup:
 mov r13,rax
 mov eax,3
 mov edi,dword ptr [rip+.Lm_pipes+8]
 syscall
 mov eax,3
 mov edi,dword ptr [rip+.Lm_pipes+12]
 syscall
 jmp .Lm_spawn_first_saved
.Lm_spawn_first_cleanup:
 mov r13,rax
.Lm_spawn_first_saved:
 mov eax,3
 mov edi,dword ptr [rip+.Lm_pipes]
 syscall
 mov eax,3
 mov edi,dword ptr [rip+.Lm_pipes+4]
 syscall
 mov rax,r13
 jmp .Lm_spawn_return
.Lm_spawn_child:
 mov eax,109
 xor edi,edi
 xor esi,esi
 syscall
 test rax,rax
 js .Lm_child_exit
 mov eax,157
 mov edi,1
 mov esi,9
 xor edx,edx
 xor r10d,r10d
 xor r8d,r8d
 syscall
 test rax,rax
 js .Lm_child_exit
 mov eax,110
 syscall
 cmp rax,[rip+.Lm_parent_pid]
 jne .Lm_child_exit
 mov eax,33
 mov edi,dword ptr [rip+.Lm_pipes]
 xor esi,esi
 syscall
 test rax,rax
 js .Lm_child_exit
 mov eax,33
 mov edi,dword ptr [rip+.Lm_pipes+12]
 mov esi,1
 syscall
 test rax,rax
 js .Lm_child_exit
 mov eax,2
 MA rdi,.Lm_devnull
 mov esi,0x80001
 xor edx,edx
 syscall
 test rax,rax
 js .Lm_child_exit
 mov edi,eax
 mov eax,33
 mov esi,2
 syscall
 test rax,rax
 js .Lm_child_exit
 # dup2(oldfd,oldfd) preserves CLOEXEC; ensure all standard FDs survive exec.
 xor r14d,r14d
.Lm_child_stdio_flags:
 mov eax,72
 mov edi,r14d
 mov esi,2
 xor edx,edx
 syscall
 test rax,rax
 js .Lm_child_exit
 inc r14d
 cmp r14d,3
 jb .Lm_child_stdio_flags
 mov eax,436
 mov edi,3
 mov esi,-1
 xor edx,edx
 syscall
 # Fail closed if the kernel cannot guarantee every inherited extra FD closes.
 test rax,rax
 js .Lm_child_exit
 jmp .Lm_child_exec
.Lm_spawn_return:
 ML

# Build a request prefix and reserve a monotonically increasing numeric ID.
.Lm_request_start:
 ME
 mov r12,rdi
 mov rbx,[rip+.Lm_current]
 inc qword ptr [rbx+S_NEXTID]
 mov rax,[rbx+S_NEXTID]
 test rax,rax
 jz .Lm_request_bad
 mov [rip+.Lm_expected_id],rax
 MA rdi,.Lm_send
 mov esi,M_MESSAGE-1
 call .Lm_builder
 MCAT .Lm_rpc_prefix
 mov rdi,[rip+.Lm_expected_id]
 call .Lm_number
 MCAT .Lm_method_prefix
 mov rdi,r12
 mov esi,128
 call .Lm_zlen
 mov rsi,r12
 mov rdx,rax
 call .Lm_quote
 MCAT .Lm_params_prefix
 xor eax,eax
 jmp .Lm_request_return
.Lm_request_bad:
 mov rax,-71
.Lm_request_return:
 ML
.Lm_request_end:
 sub rsp,8
 MCAT .Lm_rpc_close
 call .Lm_finish
 add rsp,8
 ret

# Answer server requests while awaiting a response; ping is the sole supported
# client capability. No unknown request is silently left waiting indefinitely.
.Lm_server_request:
 ME
 mov r12,rdi
 xor edi,edi
 MA rsi,.Lm_key_id
 call .Lm_find
 test rax,rax
 js .Lm_server_notification
 mov r13,rax
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 mov rax,[rcx+rdx+T_TYPE]
 cmp eax,JT_STRING
 je .Lm_server_id_ok
 cmp eax,JT_NUMBER
 je .Lm_server_id_ok
 cmp eax,JT_NULL
 jne .Lm_server_request_bad
.Lm_server_id_ok:
 mov rdi,r12
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_server_request_return
 MA rdi,.Lm_temp_name
 MA rsi,.Lm_method_ping
 call qx_streq
 mov r14d,eax
 MA rdi,.Lm_send
 mov esi,M_MESSAGE-1
 call .Lm_builder
 MCAT .Lm_rpc_prefix
 mov rdi,r13
 call .Lm_span
 mov rsi,rax
 call .Lm_cat
 test r14d,r14d
 jz .Lm_server_unknown
 MCAT .Lm_ping_response
 jmp .Lm_server_write
.Lm_server_unknown:
 MCAT .Lm_unknown_response
.Lm_server_write:
 call .Lm_finish
 test rax,rax
 js .Lm_server_request_return
 mov rdx,rax
 MA rsi,.Lm_send
 mov rax,[rip+.Lm_current]
 mov rdi,[rax+S_IN]
 call .Lm_write
 test rax,rax
 js .Lm_server_request_return
.Lm_server_notification:
 xor eax,eax
 jmp .Lm_server_request_return
.Lm_server_request_bad:
 mov rax,-71
.Lm_server_request_return:
 ML

# Send the already built newline frame, then correlate response IDs. Parser and
# notification limits are independent of the absolute 30-second deadline.
.Lm_rpc:
 ME
 mov qword ptr [rip+.Lm_remote_error],0
 call .Lm_deadline
 test rax,rax
 js .Lm_rpc_return
 call .Lm_finish
 test rax,rax
 js .Lm_rpc_return
 mov rdx,rax
 MA rsi,.Lm_send
 mov rax,[rip+.Lm_current]
 mov rdi,[rax+S_IN]
 call .Lm_write
 test rax,rax
 js .Lm_rpc_return
 xor r15d,r15d
.Lm_rpc_wait:
 inc r15d
 cmp r15d,128
 ja .Lm_rpc_bad
 call .Lm_readline
 test rax,rax
 js .Lm_rpc_return
 mov rsi,rax
 MA rdi,.Lm_response
 call .Lm_parse
 test rax,rax
 js .Lm_rpc_return
 cmp qword ptr [rip+.Lm_tokens+T_TYPE],JT_OBJECT
 jne .Lm_rpc_bad
 xor edi,edi
 MA rsi,.Lm_key_jsonrpc
 call .Lm_find
 test rax,rax
 js .Lm_rpc_bad
 mov rdi,rax
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_rpc_return
 MA rdi,.Lm_temp_name
 MA rsi,.Lm_jsonrpc_version
 call qx_streq
 test eax,eax
 jz .Lm_rpc_bad
 xor edi,edi
 MA rsi,.Lm_key_method
 call .Lm_find
 test rax,rax
 js .Lm_rpc_response
 mov rdi,rax
 call .Lm_server_request
 test rax,rax
 js .Lm_rpc_return
 jmp .Lm_rpc_wait
.Lm_rpc_response:
 xor edi,edi
 MA rsi,.Lm_key_id
 call .Lm_find
 test rax,rax
 js .Lm_rpc_bad
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 add rdx,rcx
 cmp qword ptr [rdx+T_TYPE],JT_NUMBER
 jne .Lm_rpc_wait
 mov rsi,[rdx+T_LEN]
 mov rdi,[rdx+T_START]
 add rdi,[rip+.Lm_source]
 call qx_parse_uint
 cmp rax,[rip+.Lm_expected_id]
 jne .Lm_rpc_wait
 xor edi,edi
 MA rsi,.Lm_key_error
 call .Lm_find
 test rax,rax
 js .Lm_rpc_result
 shl rax,5
 MA rcx,.Lm_tokens
 cmp qword ptr [rcx+rax+T_TYPE],JT_NULL
 je .Lm_rpc_result
 mov qword ptr [rip+.Lm_remote_error],1
 mov rax,-5
 jmp .Lm_rpc_return
.Lm_rpc_result:
 xor edi,edi
 MA rsi,.Lm_key_result
 call .Lm_find
 test rax,rax
 js .Lm_rpc_bad
 jmp .Lm_rpc_return
.Lm_rpc_bad:
 mov rax,-71
.Lm_rpc_return:
 ML

# Stable native function names: hash(server NUL original-name), then a bounded
# ASCII suffix. Collisions are rejected rather than silently overwriting tools.
.Lm_export_name:
 ME
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 movabs rax,0xcbf29ce484222325
 movabs r9,0x100000001b3
 xor ecx,ecx
.Lm_hash_server:
 movzx edx,byte ptr [r12+rcx]
 xor rax,rdx
 imul rax,r9
 inc ecx
 test edx,edx
 jnz .Lm_hash_server
 xor ecx,ecx
.Lm_hash_tool:
 movzx edx,byte ptr [r13+rcx]
 test edx,edx
 jz .Lm_hash_done
 xor rax,rdx
 imul rax,r9
 inc ecx
 jmp .Lm_hash_tool
.Lm_hash_done:
 mov dword ptr [r14],0x5f70636d
 MA r8,.Lm_hex
 xor ecx,ecx
.Lm_hash_hex:
 rol rax,4
 mov edx,eax
 and edx,15
 mov dl,[r8+rdx]
 mov [r14+rcx+4],dl
 inc ecx
 cmp ecx,16
 jb .Lm_hash_hex
 mov byte ptr [r14+20],'_'
 xor ecx,ecx
.Lm_hash_suffix:
 cmp ecx,32
 jae .Lm_hash_suffix_done
 movzx edx,byte ptr [r13+rcx]
 test edx,edx
 jz .Lm_hash_suffix_done
 mov eax,edx
 sub eax,'0'
 cmp eax,9
 jbe .Lm_hash_suffix_keep
 mov eax,edx
 or eax,32
 sub eax,'a'
 cmp eax,25
 jbe .Lm_hash_suffix_keep
 mov edx,'_'
.Lm_hash_suffix_keep:
 mov [r14+rcx+21],dl
 inc ecx
 jmp .Lm_hash_suffix
.Lm_hash_suffix_done:
 mov byte ptr [r14+rcx+21],0
 xor eax,eax
 ML

.Lm_discover:
 ME 40
 mov r12,rax
 mov rbx,[rip+.Lm_current]
 mov qword ptr [rbx+S_TOOLS],0
 mov rdi,r12
 MA rsi,.Lm_key_cursor
 call .Lm_find
 test rax,rax
 js .Lm_discover_tools
 mov rdi,rax
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 jne .Lm_discover_bad
.Lm_discover_tools:
 mov rdi,r12
 MA rsi,.Lm_key_tools
 call .Lm_find
 test rax,rax
 js .Lm_discover_bad
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 add rdx,rcx
 cmp qword ptr [rdx+T_TYPE],JT_ARRAY
 jne .Lm_discover_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
.Lm_discover_next:
 cmp r12,r13
 jae .Lm_discover_done
 mov r14,[rbx+S_TOOLS]
 cmp r14,M_TOOLS
 jae .Lm_discover_bad
 mov rax,[rip+.Lm_current_index]
 imul rax,rax,M_TOOLS
 add rax,r14
 imul rax,rax,M_TOOL_SIZE
 MA r15,.Lm_tools
 add r15,rax
 mov rax,[rip+.Lm_current_index]
 mov [r15+T_SERVER],rax
 mov qword ptr [r15+T_DEFLEN],0
 mov rdi,r12
 MA rsi,.Lm_key_name
 call .Lm_find
 test rax,rax
 js .Lm_discover_bad
 mov rdi,rax
 lea rsi,[r15+T_ORIGINAL]
 mov edx,128
 call .Lm_decode
 test rax,rax
 jle .Lm_discover_bad
 xor ecx,ecx
.Lm_discover_name_check:
 cmp rcx,rax
 jae .Lm_discover_name_ok
 mov dl,[r15+rcx+T_ORIGINAL]
 cmp dl,33
 jb .Lm_discover_bad
 cmp dl,126
 ja .Lm_discover_bad
 inc ecx
 jmp .Lm_discover_name_check
.Lm_discover_name_ok:
 lea rdi,[rbx+S_NAME]
 lea rsi,[r15+T_ORIGINAL]
 lea rdx,[r15+T_NAME]
 call .Lm_export_name
 xor ebp,ebp
.Lm_discover_collision:
 cmp ebp,M_SERVERS*M_TOOLS
 jae .Lm_discover_unique
 imul rax,rbp,M_TOOL_SIZE
 MA rdx,.Lm_tools
 add rdx,rax
 cmp qword ptr [rdx+T_DEFLEN],0
 je .Lm_discover_collision_next
 lea rdi,[rdx+T_NAME]
 lea rsi,[r15+T_NAME]
 call qx_streq
 test eax,eax
 jnz .Lm_discover_bad
.Lm_discover_collision_next:
 inc ebp
 jmp .Lm_discover_collision
.Lm_discover_unique:
 mov rdi,r12
 MA rsi,.Lm_key_description
 call .Lm_find
 test rax,rax
 js .Lm_discover_default_description
 mov rdi,rax
 MA rsi,.Lm_description
 mov edx,4096
 call .Lm_decode
 test rax,rax
 js .Lm_discover_bad
 mov [rsp+16],rax
 jmp .Lm_discover_schema
.Lm_discover_default_description:
 MA rdi,.Lm_description
 MA rsi,.Lm_external_description
 mov ecx,OFFSET FLAT:.Lm_external_description_len
 rep movsb
 mov byte ptr [rdi],0
 mov qword ptr [rsp+16],OFFSET FLAT:.Lm_external_description_len
.Lm_discover_schema:
 mov rdi,r12
 MA rsi,.Lm_key_schema
 call .Lm_find
 test rax,rax
 js .Lm_discover_default_schema
 mov rdi,rax
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 cmp qword ptr [rcx+rdx+T_TYPE],JT_OBJECT
 jne .Lm_discover_bad
 call .Lm_span
 mov [rsp],rax
 mov [rsp+8],rdx
 jmp .Lm_discover_definition
.Lm_discover_default_schema:
 MA rax,.Lm_default_schema
 mov [rsp],rax
 mov qword ptr [rsp+8],OFFSET FLAT:.Lm_default_schema_len
.Lm_discover_definition:
 lea rdi,[r15+T_DEFINITION]
 mov esi,32767
 call .Lm_builder
 MCAT .Lm_def_prefix
 lea rdi,[r15+T_NAME]
 mov esi,64
 call .Lm_zlen
 lea rsi,[r15+T_NAME]
 mov rdx,rax
 call .Lm_quote
 MCAT .Lm_description_prefix
 MA rsi,.Lm_description
 mov rdx,[rsp+16]
 call .Lm_quote
 MCAT .Lm_parameters_prefix
 mov rsi,[rsp]
 mov rdx,[rsp+8]
 call .Lm_cat
 MCAT .Lm_def_close
 call .Lm_finish
 test rax,rax
 js .Lm_discover_bad
 mov [r15+T_DEFLEN],rax
 inc qword ptr [rbx+S_TOOLS]
 mov rax,r12
 shl rax,5
 MA rdx,.Lm_tokens
 mov r12,[rdx+rax+T_END]
 jmp .Lm_discover_next
.Lm_discover_done:
 xor eax,eax
 jmp .Lm_discover_return
.Lm_discover_bad:
 mov rax,-71
.Lm_discover_return:
 ML 40

.Lm_connect:
 ME
 mov rbx,[rip+.Lm_current]
 cmp qword ptr [rbx+S_CONNECTED],0
 jne .Lm_connect_done
 call .Lm_build_exec
 test rax,rax
 js .Lm_connect_unsupported
 call .Lm_start_approval
 test rax,rax
 jz .Lm_connect_denied
 call .Lm_spawn
 test rax,rax
 js .Lm_connect_io
 MA rdi,.Lm_method_initialize
 call .Lm_request_start
 MCAT .Lm_initialize_params
 call .Lm_request_end
 call .Lm_rpc
 test rax,rax
 js .Lm_connect_protocol
 mov r12,rax
 mov rdi,r12
 MA rsi,.Lm_key_protocol
 call .Lm_find
 test rax,rax
 js .Lm_connect_protocol
 mov rdi,rax
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_connect_protocol
 MA rdi,.Lm_temp_name
 MA rsi,.Lm_protocol_version
 call qx_streq
 test eax,eax
 jz .Lm_connect_protocol
 # Initialize notification has no ID and is not mistaken for a request.
 call .Lm_deadline
 # Tool discovery is legal only when the server negotiated the tools capability.
 mov rdi,r12
 MA rsi,.Lm_key_capabilities
 call .Lm_find
 test rax,rax
 js .Lm_connect_protocol
 mov rdi,rax
 MA rsi,.Lm_key_tools
 call .Lm_find
 test rax,rax
 js .Lm_connect_protocol
 shl rax,5
 MA rdx,.Lm_tokens
 cmp qword ptr [rdx+rax+T_TYPE],JT_OBJECT
 jne .Lm_connect_protocol
 MA rdi,.Lm_send
 mov esi,M_MESSAGE-1
 call .Lm_builder
 MCAT .Lm_initialized
 call .Lm_finish
 test rax,rax
 js .Lm_connect_protocol
 mov rdx,rax
 MA rsi,.Lm_send
 mov rdi,[rbx+S_IN]
 call .Lm_write
 test rax,rax
 js .Lm_connect_protocol
 MA rdi,.Lm_method_tools_list
 call .Lm_request_start
 MCAT .Lm_empty_object
 call .Lm_request_end
 call .Lm_rpc
 test rax,rax
 js .Lm_connect_protocol
 call .Lm_discover
 test rax,rax
 js .Lm_connect_protocol
 mov qword ptr [rbx+S_CONNECTED],1
.Lm_connect_done:
 xor eax,eax
 jmp .Lm_connect_return
.Lm_connect_protocol:
 mov rdi,rbx
 call .Lm_stop_server
 mov rax,-71
 jmp .Lm_connect_return
.Lm_connect_denied:
 mov rax,-13
 jmp .Lm_connect_return
.Lm_connect_unsupported:
 mov rax,-95
 jmp .Lm_connect_return
.Lm_connect_io:
 mov rax,-5
.Lm_connect_return:
 ML

# Tool lookup touches metadata only for registered/discovered tools.
.Lm_lookup:
 ME
 mov r12,rdi
 xor r13d,r13d
.Lm_lookup_server:
 cmp r13,[rip+.Lm_count]
 jae .Lm_lookup_missing
 imul rax,r13,M_SERVER_SIZE
 MA rbx,.Lm_servers
 add rbx,rax
 xor r14d,r14d
.Lm_lookup_tool:
 cmp r14,[rbx+S_TOOLS]
 jae .Lm_lookup_next
 imul rax,r13,M_TOOLS
 add rax,r14
 imul rax,rax,M_TOOL_SIZE
 MA r15,.Lm_tools
 add r15,rax
 lea rdi,[r15+T_NAME]
 mov rsi,r12
 call qx_streq
 test eax,eax
 jnz .Lm_lookup_found
 inc r14
 jmp .Lm_lookup_tool
.Lm_lookup_next:
 inc r13
 jmp .Lm_lookup_server
.Lm_lookup_found:
 mov rax,r15
 jmp .Lm_lookup_return
.Lm_lookup_missing:
 xor eax,eax
.Lm_lookup_return:
 ML
mcp_handles:
 ME
 mov r12,rdi
 MA rsi,.Lm_core_list
 call qx_streq
 test eax,eax
 jnz .Lm_handles_yes
 mov rdi,r12
 MA rsi,.Lm_core_connect
 call qx_streq
 test eax,eax
 jnz .Lm_handles_yes
 mov rdi,r12
 call .Lm_lookup
 test rax,rax
 setne al
 movzx eax,al
 ML
.Lm_handles_yes:
 mov eax,1
 ML

mcp_definitions:
 ME
 test rsi,rsi
 jz .Lm_def_capacity
 dec rsi
 call .Lm_builder
 xor r12d,r12d
 xor r15d,r15d
.Lm_def_server:
 cmp r12,[rip+.Lm_count]
 jae .Lm_def_done
 imul rax,r12,M_SERVER_SIZE
 MA rbx,.Lm_servers
 add rbx,rax
 xor r13d,r13d
.Lm_def_tool:
 cmp r13,[rbx+S_TOOLS]
 jae .Lm_def_next
 imul rax,r12,M_TOOLS
 add rax,r13
 imul rax,rax,M_TOOL_SIZE
 MA r14,.Lm_tools
 add r14,rax
 test r15d,r15d
 jz .Lm_def_first
 MCAT .Lm_comma
.Lm_def_first:
 lea rsi,[r14+T_DEFINITION]
 mov rdx,[r14+T_DEFLEN]
 call .Lm_cat
 inc r15d
 inc r13
 jmp .Lm_def_tool
.Lm_def_next:
 inc r12
 jmp .Lm_def_server
.Lm_def_done:
 call .Lm_finish
 ML
.Lm_def_capacity:
 mov rax,-28
 ML

# Every discovered call has its own authorization boundary, even if startup was
# already approved. Arguments are deliberately excluded from the approval text.
.Lm_tool_approval:
 ME
 cmp qword ptr [rip+.Lm_allow],0
 jne .Lm_tool_yes
 cmp qword ptr [rip+.Lm_approval],0
 je .Lm_tool_no
 mov r12,rdi
 MA rdi,.Lm_preview
 mov esi,65535
 call .Lm_builder
 MCAT .Lm_call_text
 lea rsi,[r12+T_NAME]
 call .Lm_catz
 MCAT .Lm_call_permissions
 call .Lm_finish
 test rax,rax
 js .Lm_tool_no
 MA rdi,.Lm_preview
 call [rip+.Lm_approval]
 test rax,rax
 setne al
 movzx eax,al
 ML
.Lm_tool_yes:
 mov eax,1
 ML
.Lm_tool_no:
 xor eax,eax
 ML

# Decode text content directly into the bounded caller builder, preserving UTF8.
.Lm_result_text:
 ME
 mov r12,rax
 mov rdi,rax
 MA rsi,.Lm_key_content
 call .Lm_find
 test rax,rax
 js .Lm_result_structured
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 add rdx,rcx
 cmp qword ptr [rdx+T_TYPE],JT_ARRAY
 jne .Lm_result_bad
 mov r13,[rdx+T_END]
 lea r14,[rax+1]
.Lm_result_block:
 cmp r14,r13
 jae .Lm_result_finished
 mov rdi,r14
 MA rsi,.Lm_key_text
 call .Lm_find
 test rax,rax
 js .Lm_result_binary
 mov rdx,rax
 shl rdx,5
 MA rcx,.Lm_tokens
 add rdx,rcx
 cmp qword ptr [rdx+T_TYPE],JT_STRING
 jne .Lm_result_bad
 mov rsi,[rdx+T_START]
 add rsi,[rip+.Lm_source]
 mov rdx,[rdx+T_LEN]
 mov rax,[rip+.Lm_build+16]
 mov rcx,[rip+.Lm_build+8]
 sub rcx,rax
 mov rdi,[rip+.Lm_build]
 add rdi,rax
 call json_decode
 test rax,rax
 js .Lm_result_return
 add [rip+.Lm_build+16],rax
 jmp .Lm_result_advance
.Lm_result_binary:
 MCAT .Lm_binary_label
.Lm_result_advance:
 mov rax,r14
 shl rax,5
 MA rdx,.Lm_tokens
 mov r14,[rdx+rax+T_END]
 cmp r14,r13
 jae .Lm_result_finished
 MCAT .Lm_newline
 jmp .Lm_result_block
.Lm_result_finished:
 cmp qword ptr [rip+.Lm_build+16],0
 jne .Lm_result_finish
.Lm_result_structured:
 mov rdi,r12
 MA rsi,.Lm_key_structured
 call .Lm_find
 test rax,rax
 js .Lm_result_finish
 mov rdi,rax
 call .Lm_span
 mov rsi,rax
 call .Lm_cat
.Lm_result_finish:
 call .Lm_finish
 jmp .Lm_result_return
.Lm_result_bad:
 mov rax,-71
.Lm_result_return:
 ML

mcp_execute:
 ME 40
 mov [rsp],rdi
 mov [rsp+8],rsi
 mov [rsp+16],rdx
 mov [rsp+24],rcx
 mov [rsp+32],r8
 test r8,r8
 jz .Lm_execute_cap
 cmp rdx,65535
 ja .Lm_execute_invalid
 mov rdi,rsi
 mov rsi,rdx
 call .Lm_parse
 test rax,rax
 js .Lm_execute_invalid
 cmp qword ptr [rip+.Lm_tokens+T_TYPE],JT_OBJECT
 jne .Lm_execute_invalid
 # Preserve arguments because discovery/RPC will reuse the token/source buffers.
 mov rsi,[rsp+8]
 mov rcx,[rsp+16]
 MA rdi,.Lm_arguments
 rep movsb
 mov byte ptr [rdi],0
 mov rax,[rsp+16]
 mov [rip+.Lm_arguments_len],rax
 mov rdi,[rsp]
 MA rsi,.Lm_core_list
 call qx_streq
 test eax,eax
 jnz .Lm_execute_list
 mov rdi,[rsp]
 MA rsi,.Lm_core_connect
 call qx_streq
 test eax,eax
 jnz .Lm_execute_connect
 mov rdi,[rsp]
 call .Lm_lookup
 test rax,rax
 jz .Lm_execute_missing
 mov r14,rax
 mov rax,[r14+T_SERVER]
 mov [rip+.Lm_current_index],rax
 imul rax,rax,M_SERVER_SIZE
 MA rbx,.Lm_servers
 add rbx,rax
 mov [rip+.Lm_current],rbx
 cmp qword ptr [rbx+S_CONNECTED],0
 je .Lm_execute_disconnected
 mov rdi,r14
 call .Lm_tool_approval
 test rax,rax
 jz .Lm_execute_denied
 MA rdi,.Lm_method_call
 call .Lm_request_start
 MCAT .Lm_call_prefix
 lea rdi,[r14+T_ORIGINAL]
 mov esi,128
 call .Lm_zlen
 lea rsi,[r14+T_ORIGINAL]
 mov rdx,rax
 call .Lm_quote
 MCAT .Lm_arguments_prefix
 MA rsi,.Lm_arguments
 mov rdx,[rip+.Lm_arguments_len]
 call .Lm_cat
 MCAT .Lm_object_close
 call .Lm_request_end
 call .Lm_rpc
 test rax,rax
 js .Lm_execute_rpc_error
 mov r15,rax
 mov rdi,[rsp+24]
 mov rsi,[rsp+32]
 dec rsi
 call .Lm_builder
 mov rax,r15
 call .Lm_result_text
 jmp .Lm_execute_return
.Lm_execute_rpc_error:
 cmp qword ptr [rip+.Lm_remote_error],0
 jne .Lm_execute_remote
 mov rdi,[rip+.Lm_current]
 call .Lm_stop_server
 MA rsi,.Lm_io_error
 jmp .Lm_execute_message
.Lm_execute_remote:
 MA rsi,.Lm_remote_message
 jmp .Lm_execute_message
.Lm_execute_connect:
 xor edi,edi
 MA rsi,.Lm_key_server
 call .Lm_find
 test rax,rax
 js .Lm_execute_invalid
 mov rdi,rax
 MA rsi,.Lm_temp_name
 mov edx,128
 call .Lm_decode
 test rax,rax
 js .Lm_execute_invalid
 xor r12d,r12d
.Lm_execute_find_server:
 cmp r12,[rip+.Lm_count]
 jae .Lm_execute_missing
 imul rax,r12,M_SERVER_SIZE
 MA rbx,.Lm_servers
 add rbx,rax
 lea rdi,[rbx+S_NAME]
 MA rsi,.Lm_temp_name
 call qx_streq
 test eax,eax
 jnz .Lm_execute_found_server
 inc r12
 jmp .Lm_execute_find_server
.Lm_execute_found_server:
 mov [rip+.Lm_current],rbx
 mov [rip+.Lm_current_index],r12
 call .Lm_connect
 test rax,rax
 jz .Lm_execute_connected
 cmp rax,-13
 je .Lm_execute_denied
 cmp rax,-95
 je .Lm_execute_unsupported
 MA rsi,.Lm_io_error
 jmp .Lm_execute_message
.Lm_execute_connected:
 MA rsi,.Lm_connected_message
 jmp .Lm_execute_message
.Lm_execute_list:
 mov rdi,[rsp+24]
 mov rsi,[rsp+32]
 dec rsi
 call .Lm_builder
 xor r12d,r12d
.Lm_execute_list_loop:
 cmp r12,[rip+.Lm_count]
 jae .Lm_execute_list_done
 imul rax,r12,M_SERVER_SIZE
 MA rbx,.Lm_servers
 add rbx,rax
 lea rsi,[rbx+S_NAME]
 call .Lm_catz
 cmp qword ptr [rbx+S_UNSUPPORTED],0
 jne .Lm_execute_list_unsupported
 cmp qword ptr [rbx+S_CONNECTED],0
 je .Lm_execute_list_disconnected
 MCAT .Lm_list_connected
 jmp .Lm_execute_list_next
.Lm_execute_list_disconnected:
 MCAT .Lm_list_disconnected
 jmp .Lm_execute_list_next
.Lm_execute_list_unsupported:
 MCAT .Lm_list_unsupported
.Lm_execute_list_next:
 inc r12
 jmp .Lm_execute_list_loop
.Lm_execute_list_done:
 call .Lm_finish
 jmp .Lm_execute_return
.Lm_execute_denied:
 MA rsi,.Lm_denied_message
 jmp .Lm_execute_message
.Lm_execute_disconnected:
 MA rsi,.Lm_disconnected_message
 jmp .Lm_execute_message
.Lm_execute_unsupported:
 MA rsi,.Lm_unsupported_message
 jmp .Lm_execute_message
.Lm_execute_missing:
 MA rsi,.Lm_missing_message
.Lm_execute_message:
 mov r12,rsi
 mov rdi,[rsp+24]
 mov rsi,[rsp+32]
 dec rsi
 call .Lm_builder
 mov rsi,r12
 call .Lm_catz
 call .Lm_finish
 jmp .Lm_execute_return
.Lm_execute_invalid:
 mov rax,-22
 jmp .Lm_execute_return
.Lm_execute_cap:
 mov rax,-28
.Lm_execute_return:
 ML 40

.section .rodata
.Lm_core_list: .asciz "list_mcp_servers"
.equ .Lm_core_list_len,.-.Lm_core_list-1
.Lm_core_connect: .asciz "connect_mcp_server"
.equ .Lm_core_connect_len,.-.Lm_core_connect-1
.Lm_colon: .asciz ":"
.equ .Lm_colon_len,.-.Lm_colon-1
.Lm_comma: .asciz ","
.equ .Lm_comma_len,.-.Lm_comma-1
.Lm_space: .asciz " "
.equ .Lm_space_len,.-.Lm_space-1
.Lm_newline: .asciz "\n"
.equ .Lm_newline_len,.-.Lm_newline-1
.Lm_object_close: .asciz "}"
.equ .Lm_object_close_len,.-.Lm_object_close-1
.Lm_rpc_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":"
.equ .Lm_rpc_prefix_len,.-.Lm_rpc_prefix-1
.Lm_method_prefix: .asciz ",\"method\":"
.equ .Lm_method_prefix_len,.-.Lm_method_prefix-1
.Lm_params_prefix: .asciz ",\"params\":"
.equ .Lm_params_prefix_len,.-.Lm_params_prefix-1
.Lm_rpc_close: .asciz "}\n"
.equ .Lm_rpc_close_len,.-.Lm_rpc_close-1
.Lm_ping_response: .asciz ",\"result\":{}}\n"
.equ .Lm_ping_response_len,.-.Lm_ping_response-1
.Lm_unknown_response: .asciz ",\"error\":{\"code\":-32601,\"message\":\"Unsupported client method\"}}\n"
.equ .Lm_unknown_response_len,.-.Lm_unknown_response-1
.Lm_jsonrpc_version: .asciz "2.0"
.equ .Lm_jsonrpc_version_len,.-.Lm_jsonrpc_version-1
.Lm_protocol_version: .asciz "2024-11-05"
.equ .Lm_protocol_version_len,.-.Lm_protocol_version-1
.Lm_method_initialize: .asciz "initialize"
.equ .Lm_method_initialize_len,.-.Lm_method_initialize-1
.Lm_method_ping: .asciz "ping"
.equ .Lm_method_ping_len,.-.Lm_method_ping-1
.Lm_method_tools_list: .asciz "tools/list"
.equ .Lm_method_tools_list_len,.-.Lm_method_tools_list-1
.Lm_method_call: .asciz "tools/call"
.equ .Lm_method_call_len,.-.Lm_method_call-1
.Lm_initialize_params: .asciz "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"qwen-x86\",\"version\":\"0.1\"}}"
.equ .Lm_initialize_params_len,.-.Lm_initialize_params-1
.Lm_initialized: .asciz "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n"
.equ .Lm_initialized_len,.-.Lm_initialized-1
.Lm_empty_object: .asciz "{}"
.equ .Lm_empty_object_len,.-.Lm_empty_object-1
.Lm_def_prefix: .asciz "{\"type\":\"function\",\"function\":{\"name\":"
.equ .Lm_def_prefix_len,.-.Lm_def_prefix-1
.Lm_description_prefix: .asciz ",\"description\":"
.equ .Lm_description_prefix_len,.-.Lm_description_prefix-1
.Lm_parameters_prefix: .asciz ",\"parameters\":"
.equ .Lm_parameters_prefix_len,.-.Lm_parameters_prefix-1
.Lm_def_close: .asciz "}}"
.equ .Lm_def_close_len,.-.Lm_def_close-1
.Lm_call_prefix: .asciz "{\"name\":"
.equ .Lm_call_prefix_len,.-.Lm_call_prefix-1
.Lm_arguments_prefix: .asciz ",\"arguments\":"
.equ .Lm_arguments_prefix_len,.-.Lm_arguments_prefix-1
.Lm_default_schema: .asciz "{\"type\":\"object\",\"properties\":{}}"
.equ .Lm_default_schema_len,.-.Lm_default_schema-1
.Lm_external_description: .asciz "External MCP tool; explicit approval required."
.equ .Lm_external_description_len,.-.Lm_external_description-1
.Lm_var_root: .asciz "${extensionPath}"
.equ .Lm_var_root_len,.-.Lm_var_root-1
.Lm_var_claude: .asciz "${CLAUDE_PLUGIN_ROOT}"
.equ .Lm_var_claude_len,.-.Lm_var_claude-1
.Lm_hex: .asciz "0123456789abcdef"
.equ .Lm_hex_len,.-.Lm_hex-1
.Lm_stdio: .asciz "stdio"
.equ .Lm_stdio_len,.-.Lm_stdio-1
.Lm_default_path: .asciz "/usr/local/bin:/usr/bin:/bin"
.equ .Lm_default_path_len,.-.Lm_default_path-1
.Lm_devnull: .asciz "/dev/null"
.equ .Lm_devnull_len,.-.Lm_devnull-1
.Lm_start_text: .asciz "Start external MCP server "
.equ .Lm_start_text_len,.-.Lm_start_text-1
.Lm_exec_text: .asciz "\nExecutable: "
.equ .Lm_exec_text_len,.-.Lm_exec_text-1
.Lm_args_text: .asciz "\nArguments: "
.equ .Lm_args_text_len,.-.Lm_args_text-1
.Lm_redacted: .asciz "[redacted]"
.equ .Lm_redacted_len,.-.Lm_redacted-1
.Lm_permissions_text: .asciz "\nThis process can access your user account, files, and network. Environment values are hidden."
.equ .Lm_permissions_text_len,.-.Lm_permissions_text-1
.Lm_call_text: .asciz "Run external MCP tool "
.equ .Lm_call_text_len,.-.Lm_call_text-1
.Lm_call_permissions: .asciz "\nThe configured server executes this tool with your user account permissions."
.equ .Lm_call_permissions_len,.-.Lm_call_permissions-1
.Lm_binary_label: .asciz "[non-text MCP content omitted]"
.equ .Lm_binary_label_len,.-.Lm_binary_label-1
.Lm_connected_message: .asciz "MCP server connected; discovered tools are now available."
.equ .Lm_connected_message_len,.-.Lm_connected_message-1
.Lm_denied_message: .asciz "MCP operation denied; no command or tool was executed."
.equ .Lm_denied_message_len,.-.Lm_denied_message-1
.Lm_disconnected_message: .asciz "MCP server is disconnected. Connect it before calling tools."
.equ .Lm_disconnected_message_len,.-.Lm_disconnected_message-1
.Lm_unsupported_message: .asciz "Unsupported MCP configuration: this client accepts stdio command servers only."
.equ .Lm_unsupported_message_len,.-.Lm_unsupported_message-1
.Lm_missing_message: .asciz "MCP server or tool was not found."
.equ .Lm_missing_message_len,.-.Lm_missing_message-1
.Lm_io_error: .asciz "MCP server failed, timed out, closed its stream, or sent invalid protocol data."
.equ .Lm_io_error_len,.-.Lm_io_error-1
.Lm_remote_message: .asciz "MCP server returned a JSON-RPC error."
.equ .Lm_remote_message_len,.-.Lm_remote_message-1
.Lm_list_connected: .asciz " (connected)\n"
.equ .Lm_list_connected_len,.-.Lm_list_connected-1
.Lm_list_disconnected: .asciz " (disconnected; approval required)\n"
.equ .Lm_list_disconnected_len,.-.Lm_list_disconnected-1
.Lm_list_unsupported: .asciz " (unsupported remote or missing command)\n"
.equ .Lm_list_unsupported_len,.-.Lm_list_unsupported-1
.Lm_key_capabilities: .asciz "capabilities"
.Lm_key_args: .asciz "args"
.equ .Lm_key_args_len,.-.Lm_key_args-1
.Lm_key_command: .asciz "command"
.equ .Lm_key_command_len,.-.Lm_key_command-1
.Lm_key_content: .asciz "content"
.equ .Lm_key_content_len,.-.Lm_key_content-1
.Lm_key_cursor: .asciz "nextCursor"
.equ .Lm_key_cursor_len,.-.Lm_key_cursor-1
.Lm_key_description: .asciz "description"
.equ .Lm_key_description_len,.-.Lm_key_description-1
.Lm_key_env: .asciz "env"
.equ .Lm_key_env_len,.-.Lm_key_env-1
.Lm_key_error: .asciz "error"
.equ .Lm_key_error_len,.-.Lm_key_error-1
.Lm_key_id: .asciz "id"
.equ .Lm_key_id_len,.-.Lm_key_id-1
.Lm_key_jsonrpc: .asciz "jsonrpc"
.equ .Lm_key_jsonrpc_len,.-.Lm_key_jsonrpc-1
.Lm_key_method: .asciz "method"
.equ .Lm_key_method_len,.-.Lm_key_method-1
.Lm_key_name: .asciz "name"
.equ .Lm_key_name_len,.-.Lm_key_name-1
.Lm_key_path: .asciz "PATH"
.equ .Lm_key_path_len,.-.Lm_key_path-1
.Lm_key_protocol: .asciz "protocolVersion"
.equ .Lm_key_protocol_len,.-.Lm_key_protocol-1
.Lm_key_result: .asciz "result"
.equ .Lm_key_result_len,.-.Lm_key_result-1
.Lm_key_schema: .asciz "inputSchema"
.equ .Lm_key_schema_len,.-.Lm_key_schema-1
.Lm_key_server: .asciz "server"
.equ .Lm_key_server_len,.-.Lm_key_server-1
.Lm_key_structured: .asciz "structuredContent"
.equ .Lm_key_structured_len,.-.Lm_key_structured-1
.Lm_key_text: .asciz "text"
.equ .Lm_key_text_len,.-.Lm_key_text-1
.Lm_key_tools: .asciz "tools"
.equ .Lm_key_tools_len,.-.Lm_key_tools-1
.Lm_key_transport: .asciz "transport"
.equ .Lm_key_transport_len,.-.Lm_key_transport-1
.Lm_key_type: .asciz "type"
.equ .Lm_key_type_len,.-.Lm_key_type-1
.Lm_key_url: .asciz "url"
.equ .Lm_key_url_len,.-.Lm_key_url-1
.Lm_secret_0: .asciz "token"
.Lm_secret_1: .asciz "secret"
.Lm_secret_2: .asciz "password"
.Lm_secret_3: .asciz "api-key"
.Lm_secret_4: .asciz "api_key"
.Lm_secret_5: .asciz "authorization"
.Lm_secret_6: .asciz "credential"
.balign 4
.Lm_sensitive_table:
 .long .Lm_secret_0-.Lm_sensitive_table
 .long .Lm_secret_1-.Lm_sensitive_table
 .long .Lm_secret_2-.Lm_sensitive_table
 .long .Lm_secret_3-.Lm_sensitive_table
 .long .Lm_secret_4-.Lm_sensitive_table
 .long .Lm_secret_5-.Lm_sensitive_table
 .long .Lm_secret_6-.Lm_sensitive_table

.bss
.balign 4096
.Lm_cancel_callback: .skip 8
.Lm_allow: .skip 8
.Lm_approval: .skip 8
.Lm_argc: .skip 8
.Lm_arguments_len: .skip 8
.Lm_build_error: .skip 8
.Lm_command: .skip 8
.Lm_count: .skip 8
.Lm_current: .skip 8
.Lm_current_index: .skip 8
.Lm_deadline_ns: .skip 8
.Lm_envcount: .skip 8
.Lm_envp: .skip 8
.Lm_expected_id: .skip 8
.Lm_interactive: .skip 8
.Lm_parent_pid: .skip 8
.Lm_path_delimiter: .skip 8
.Lm_pool_used: .skip 8
.Lm_remote_error: .skip 8
.Lm_source: .skip 8
.Lm_wait_status: .skip 8
.balign 16
.Lm_build: .skip 24
.balign 16
.Lm_clock: .skip 16
.balign 16
.Lm_input_char: .skip 8
.balign 16
.Lm_ioctl: .skip 64
.balign 16
.Lm_pipes: .skip 16
.balign 16
.Lm_pollfds: .skip 16
.balign 16
.Lm_number_buf: .skip 32
.balign 16
.Lm_argv: .skip 272
.balign 16
.Lm_envvec: .skip 8456
.balign 16
.Lm_temp_name: .skip 128
.balign 16
.Lm_temp_string: .skip 4096
.balign 16
.Lm_description: .skip 4096
.balign 16
.Lm_exec_path: .skip 4096
.balign 16
.Lm_preview: .skip 65536
.balign 16
.Lm_arguments: .skip 65536
.balign 16
.Lm_tokens: .skip 262144
.balign 16
.Lm_pool: .skip 262144
.balign 16
.Lm_send: .skip 1048576
.balign 16
.Lm_response: .skip 1048576
.balign 16
.Lm_servers: .skip 4456448
.balign 16
.Lm_tools: .skip 2129920
.section .note.GNU-stack,"",@progbits
