# Native session picker catalog and explicitly invoked session management.
# Borrowed strings last until next catalog call.
# Directory components and regular session files opened without following links.
.include "abi.inc"
.equ S_MAX,64
.equ S_STRIDE,9216
.equ S_LABEL,0
.equ S_DESC,512
.equ S_PATH,5120
.section .rodata
.Ls_local: .asciz ".local"
.Ls_state: .asciz "state"
.Ls_app: .asciz "qwen-x86"
.Ls_suffix: .asciz "/.local/state/qwen-x86/"
.Ls_role: .asciz "role"
.Ls_content: .asciz "content"
.Ls_default: .asciz "Untitled session"
.section .bss
.balign 16
.Ls_dir: .skip 8
.Ls_file: .skip 8
.Ls_out: .skip 8
.Ls_cap: .skip 8
.Ls_count: .skip 8
.Ls_uid: .skip 8
.Ls_now: .skip 16
.Ls_home_len: .skip 8
.Ls_prefix_len: .skip 8
.Ls_pos: .skip 8
.Ls_end: .skip 8
.Ls_name: .skip 8
.Ls_size: .skip 8
.Ls_slot: .skip 8
.Ls_jsonlen: .skip 8
.Ls_stat: .skip 144
.Ls_times: .skip S_MAX*8
.Ls_nanos: .skip S_MAX*8
.Ls_order: .skip S_MAX*8
.Ls_prefix: .skip 4096
.Ls_entries: .skip 32768
.Ls_strings: .skip S_MAX*S_STRIDE
.Ls_json: .skip MAX_JSON+1
.Ls_decoded: .skip MAX_JSON+1
.Ls_tokens: .skip MAX_TOKENS*TOKEN_SIZE
.section .text
.global ui_session_catalog
.type ui_session_catalog,@function
ui_session_catalog:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov qword ptr [rip+.Ls_dir],-1
 mov qword ptr [rip+.Ls_file],-1
 mov qword ptr [rip+.Ls_count],0
 mov [rip+.Ls_out],rsi
 cmp rdx,S_MAX
 jbe .Ls_cap_ok
 mov edx,S_MAX
.Ls_cap_ok:
 mov [rip+.Ls_cap],rdx
 test rdx,rdx
 jz .Ls_success
 test rdi,rdi
 jz .Ls_invalid
 test rsi,rsi
 jz .Ls_invalid
 cmp byte ptr [rdi],47
 jne .Ls_invalid
 mov r12,rdi
 xor ecx,ecx
.Ls_home_copy:
 cmp ecx,3500
 jae .Ls_invalid
 mov al,[r12+rcx]
 test al,al
 jz .Ls_home_done
 cmp al,32
 jb .Ls_invalid
 cmp al,127
 je .Ls_invalid
 lea rdx,[rip+.Ls_prefix]
 mov [rdx+rcx],al
 inc ecx
 jmp .Ls_home_copy
.Ls_home_done:
 mov [rip+.Ls_home_len],rcx
 lea rdi,[rip+.Ls_prefix]
 add rdi,rcx
 lea rsi,[rip+.Ls_suffix]
.Ls_suffix_copy:
 lodsb
 stosb
 test al,al
 jnz .Ls_suffix_copy
 lea rax,[rip+.Ls_prefix]
 sub rdi,rax
 dec rdi
 mov [rip+.Ls_prefix_len],rdi
 mov eax,107
 syscall
 mov [rip+.Ls_uid],rax
 mov eax,228
 xor edi,edi
 lea rsi,[rip+.Ls_now]
 syscall
 test rax,rax
 js .Ls_failure
 # Open each directory component independently to reject symlink traversal.
 mov eax,2
 mov rdi,r12
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .Ls_open_error
 mov [rip+.Ls_dir],rax
 lea rsi,[rip+.Ls_local]
 call .Ls_open_component
 test rax,rax
 js .Ls_open_error
 lea rsi,[rip+.Ls_state]
 call .Ls_open_component
 test rax,rax
 js .Ls_open_error
 lea rsi,[rip+.Ls_app]
 call .Ls_open_component
 test rax,rax
 js .Ls_open_error
.Ls_getdents:
 mov eax,217
 mov rdi,[rip+.Ls_dir]
 lea rsi,[rip+.Ls_entries]
 mov edx,32768
 syscall
 cmp rax,-4
 je .Ls_getdents
 test rax,rax
 js .Ls_failure
 jz .Ls_sort
 mov [rip+.Ls_end],rax
 mov qword ptr [rip+.Ls_pos],0
.Ls_entry:
 mov rax,[rip+.Ls_pos]
 cmp rax,[rip+.Ls_end]
 jae .Ls_getdents
 lea rbx,[rip+.Ls_entries]
 add rbx,rax
 movzx ecx,word ptr [rbx+16]
 cmp ecx,20
 jb .Ls_io_error
 add rax,rcx
 cmp rax,[rip+.Ls_end]
 ja .Ls_io_error
 mov [rip+.Ls_pos],rax
 lea rbx,[rbx+19]
 sub ecx,19
 xor eax,eax
.Ls_name_len:
 cmp eax,ecx
 jae .Ls_io_error
 cmp byte ptr [rbx+rax],0
 je .Ls_name_end
 inc eax
 jmp .Ls_name_len
.Ls_name_end:
 cmp eax,14
 jb .Ls_entry
 cmp eax,255
 ja .Ls_entry
 movabs rdx,0x2d6e6f6973736573 # session-
 cmp [rbx],rdx
 jne .Ls_entry
 cmp dword ptr [rbx+rax-5],0x6f736a2e # .jso
 jne .Ls_entry
 cmp byte ptr [rbx+rax-1],110
 jne .Ls_entry
 mov [rip+.Ls_name],rbx
 mov eax,257
 mov rdi,[rip+.Ls_dir]
 mov rsi,rbx
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Ls_entry
 mov [rip+.Ls_file],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Ls_stat]
 syscall
 test rax,rax
 js .Ls_skip_file
 mov eax,[rip+.Ls_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Ls_skip_file
 mov eax,[rip+.Ls_stat+28]
 cmp rax,[rip+.Ls_uid]
 jne .Ls_skip_file
 mov rax,[rip+.Ls_stat+48]
 cmp rax,MAX_JSON
 ja .Ls_skip_file
 mov qword ptr [rip+.Ls_jsonlen],0
.Ls_read:
 mov rdx,MAX_JSON+1
 sub rdx,[rip+.Ls_jsonlen]
 jz .Ls_skip_file
 lea rsi,[rip+.Ls_json]
 add rsi,[rip+.Ls_jsonlen]
 mov rdi,[rip+.Ls_file]
 xor eax,eax
 syscall
 cmp rax,-4
 je .Ls_read
 test rax,rax
 js .Ls_skip_file
 jz .Ls_validate
 add [rip+.Ls_jsonlen],rax
 jmp .Ls_read
.Ls_validate:
 cmp qword ptr [rip+.Ls_jsonlen],MAX_JSON
 ja .Ls_skip_file
 lea rdi,[rip+.Ls_json]
 mov rsi,[rip+.Ls_jsonlen]
 lea rdx,[rip+.Ls_tokens]
 mov ecx,MAX_TOKENS
 call json_parse
 test rax,rax
 js .Ls_skip_file
 cmp qword ptr [rip+.Ls_tokens+T_TYPE],JT_ARRAY
 jne .Ls_skip_file
 # Retain the newest bounded set regardless of filesystem iteration order.
 mov rbx,[rip+.Ls_count]
 cmp rbx,[rip+.Ls_cap]
 jb .Ls_new_slot
 xor ebx,ebx
 mov ecx,1
 lea r8,[rip+.Ls_times]
 lea r9,[rip+.Ls_nanos]
.Ls_oldest:
 cmp rcx,[rip+.Ls_count]
 jae .Ls_check_newer
 mov rax,[r8+rcx*8]
 cmp rax,[r8+rbx*8]
 jl .Ls_older
 jne .Ls_oldest_next
 mov rax,[r9+rcx*8]
 cmp rax,[r9+rbx*8]
 jae .Ls_oldest_next
.Ls_older:
 mov rbx,rcx
.Ls_oldest_next:
 inc ecx
 jmp .Ls_oldest
.Ls_check_newer:
 mov rax,[rip+.Ls_stat+88]
 cmp rax,[r8+rbx*8]
 jl .Ls_skip_file
 jne .Ls_fill
 mov rax,[rip+.Ls_stat+96]
 cmp rax,[r9+rbx*8]
 jbe .Ls_skip_file
 jmp .Ls_fill
.Ls_new_slot:
 inc qword ptr [rip+.Ls_count]
.Ls_fill:
 mov [rip+.Ls_slot],rbx
 lea r8,[rip+.Ls_times]
 mov rax,[rip+.Ls_stat+88]
 mov [r8+rbx*8],rax
 lea r8,[rip+.Ls_nanos]
 mov rax,[rip+.Ls_stat+96]
 mov [r8+rbx*8],rax
 imul rbx,rbx,S_STRIDE
 lea r12,[rip+.Ls_strings]
 add r12,rbx
 # Full path is constructed from the same safely opened directory and basename.
 lea rdi,[r12+S_PATH]
 lea rsi,[rip+.Ls_prefix]
 mov rcx,[rip+.Ls_prefix_len]
 rep movsb
 mov rsi,[rip+.Ls_name]
.Ls_filename_copy:
 lodsb
 stosb
 test al,al
 jnz .Ls_filename_copy
 lea rdi,[r12+S_LABEL]
 lea rsi,[rip+.Ls_default]
.Ls_default_copy:
 lodsb
 stosb
 test al,al
 jnz .Ls_default_copy
 # Find first user message's string content in the top-level history array.
 mov r13d,1
.Ls_message:
 cmp r13,[rip+.Ls_tokens+T_END]
 jae .Ls_description
 mov r14,r13
 shl r14,5
 lea r15,[rip+.Ls_tokens]
 add r14,r15
 cmp qword ptr [r14+T_TYPE],JT_OBJECT
 jne .Ls_message_next
 lea rdi,[rip+.Ls_json]
 mov rsi,r15
 mov rdx,r13
 lea rcx,[rip+.Ls_role]
 call json_find
 test rax,rax
 js .Ls_message_next
 shl rax,5
 call .Ls_text_content
 test rax,rax
 js .Ls_message_next
 lea rsi,[rip+.Ls_json]
 add rsi,[r15+rax+T_START]
 mov rdx,[r15+rax+T_LEN]
 lea rdi,[rip+.Ls_decoded]
 mov ecx,MAX_JSON
 call json_decode
 cmp rax,4
 jne .Ls_message_next
 cmp dword ptr [rip+.Ls_decoded],0x72657375
 jne .Ls_message_next
 lea rdi,[rip+.Ls_json]
 mov rsi,r15
 mov rdx,r13
 lea rcx,[rip+.Ls_content]
 call json_find
 test rax,rax
 js .Ls_message_next
 shl rax,5
 call .Ls_text_content
 test rax,rax
 js .Ls_message_next
 lea rsi,[rip+.Ls_json]
 add rsi,[r15+rax+T_START]
 mov rdx,[r15+rax+T_LEN]
 lea rdi,[rip+.Ls_decoded]
 mov ecx,MAX_JSON
 call json_decode
 test rax,rax
 jle .Ls_message_next
 # At most100 codepoints; clamp on UTF-8 boundaries, clean display controls.
 mov rdx,rax
 lea rsi,[rip+.Ls_decoded]
 mov rdi,r12
 xor ecx,ecx
 xor r8d,r8d
.Ls_label_copy:
 cmp rcx,rdx
 jae .Ls_label_end
 mov al,[rsi+rcx]
 mov r9d,eax
 and r9d,192
 cmp r9d,128
 je .Ls_label_byte
 cmp r8d,100
 jae .Ls_label_end
 inc r8d
.Ls_label_byte:
 cmp al,32
 jb .Ls_label_space
 cmp al,127
 jne .Ls_label_store
.Ls_label_space:
 mov al,32
.Ls_label_store:
 stosb
 inc rcx
 jmp .Ls_label_copy
.Ls_label_end:
 mov byte ptr [rdi],0
.Ls_description:
 call .Lm_catalog_title
 # Use one realtime snapshot for the whole catalog. Borrow one second when
 # nanoseconds require it, matching floor((now-mtime)/1000) in source.
 mov rdi,[rip+.Ls_now]
 mov rax,[rip+.Ls_now+8]
 cmp rax,[rip+.Ls_stat+96]
 jae .Ls_relative_seconds
 dec rdi
.Ls_relative_seconds:
 mov rsi,[rip+.Ls_stat+88]
 lea rdx,[r12+S_DESC]
 mov ecx,128
 call ui_relative_time
.Ls_skip_file:
 mov eax,3
 mov rdi,[rip+.Ls_file]
 syscall
 mov qword ptr [rip+.Ls_file],-1
 jmp .Ls_entry
.Ls_message_next:
 mov r13,[r14+T_END]
 jmp .Ls_message
.Ls_sort:
 # Insertion-sort tiny pointer index table by seconds then nanoseconds descending.
 xor ebx,ebx
 lea r12,[rip+.Ls_order]
 lea r13,[rip+.Ls_times]
 lea r14,[rip+.Ls_nanos]
.Ls_sort_outer:
 cmp rbx,[rip+.Ls_count]
 jae .Ls_output
 mov rcx,rbx
.Ls_sort_inner:
 test rcx,rcx
 jz .Ls_sort_place
 mov rdx,[r12+rcx*8-8]
 mov rax,[r13+rbx*8]
 cmp rax,[r13+rdx*8]
 jl .Ls_sort_place
 jg .Ls_sort_shift
 mov rax,[r14+rbx*8]
 cmp rax,[r14+rdx*8]
 jbe .Ls_sort_place
.Ls_sort_shift:
 mov [r12+rcx*8],rdx
 dec rcx
 jmp .Ls_sort_inner
.Ls_sort_place:
 mov [r12+rcx*8],rbx
 inc rbx
 jmp .Ls_sort_outer
.Ls_output:
 mov rdi,[rip+.Ls_out]
 xor ecx,ecx
.Ls_output_loop:
 cmp rcx,[rip+.Ls_count]
 jae .Ls_success
 mov rax,[r12+rcx*8]
 imul rax,rax,S_STRIDE
 lea rdx,[rip+.Ls_strings]
 add rdx,rax
 mov [rdi],rdx
 lea rax,[rdx+S_DESC]
 mov [rdi+8],rax
 lea rax,[rdx+S_PATH]
 mov [rdi+16],rax
 add rdi,24
 inc rcx
 jmp .Ls_output_loop
.Ls_success:
 mov rbx,[rip+.Ls_count]
 jmp .Ls_close
.Ls_open_error:
 # A missing session directory is a valid empty catalog.
 cmp rax,-2
 je .Ls_success
.Ls_failure:
 mov rbx,rax
 jmp .Ls_close
.Ls_invalid:
 mov rbx,-22
 jmp .Ls_close
.Ls_io_error:
 mov rbx,-5
.Ls_close:
 mov rdi,[rip+.Ls_dir]
 test rdi,rdi
 js .Ls_return
 mov eax,3
 syscall
.Ls_return:
 mov rax,rbx
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
# rsi componentZ; close previous directory only once new component opens.
.Ls_open_component:
 mov eax,257
 mov rdi,[rip+.Ls_dir]
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 js .Ls_component_ret
 mov rbx,rax
 mov rdi,[rip+.Ls_dir]
 mov eax,3
 syscall
 mov [rip+.Ls_dir],rbx
 xor eax,eax
.Ls_component_ret:
 ret
.section .note.GNU-stack,"",@progbits
# Read-only full-session preview. Shared JSON scratch does not invalidate the
# catalog's borrowed label/path strings; no model/session/history state changes.
.section .rodata
.Lpv_user: .ascii "> User\n"
.equ PV_USER,.-.Lpv_user
.Lpv_assistant: .ascii "◆ Qwen\n"
.equ PV_ASSISTANT,.-.Lpv_assistant
.Lpv_tool: .ascii "Tool\n"
.equ PV_TOOL,.-.Lpv_tool
.Lpv_empty: .ascii "No text messages in this session.\n"
.equ PV_EMPTY,.-.Lpv_empty
.section .bss
.balign 16
.Lpv_fd: .skip 8
.Lpv_out: .skip 8
.Lpv_cap: .skip 8
.Lpv_jsonlen: .skip 8
.Lpv_length: .skip 8
.Lpv_result: .skip 8
.Lpv_text: .skip MAX_JSON+1
.text
.global ui_session_preview
ui_session_preview:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov qword ptr [rip+.Lpv_fd],-1
 mov qword ptr [rip+.Lpv_result],-22
 mov qword ptr [rip+.Lpv_jsonlen],0
 mov qword ptr [rip+.Lpv_length],0
 mov [rip+.Lpv_out],rsi
 mov [rip+.Lpv_cap],rdx
 test rdi,rdi
 jz .Lpv_done
 test rsi,rsi
 jz .Lpv_done
 test rdx,rdx
 jz .Lpv_full
 mov eax,2
 mov esi,0xa0800
 xor edx,edx
 syscall
 test rax,rax
 js .Lpv_error
 mov [rip+.Lpv_fd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Ls_stat]
 syscall
 test rax,rax
 js .Lpv_error
 mov eax,[rip+.Ls_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lpv_done
 mov eax,107
 syscall
 cmp eax,[rip+.Ls_stat+28]
 jne .Lpv_done
 cmp qword ptr [rip+.Ls_stat+48],MAX_JSON
 ja .Lpv_full
.Lpv_read:
 xor eax,eax
 mov rdi,[rip+.Lpv_fd]
 lea rsi,[rip+.Ls_json]
 add rsi,[rip+.Lpv_jsonlen]
 mov edx,MAX_JSON+1
 sub rdx,[rip+.Lpv_jsonlen]
 jz .Lpv_full
 syscall
 cmp rax,-4
 je .Lpv_read
 test rax,rax
 js .Lpv_error
 jz .Lpv_parse
 add [rip+.Lpv_jsonlen],rax
 jmp .Lpv_read
.Lpv_parse:
 cmp qword ptr [rip+.Lpv_jsonlen],MAX_JSON
 ja .Lpv_full
 lea rdi,[rip+.Ls_json]
 mov rsi,[rip+.Lpv_jsonlen]
 lea rdx,[rip+.Ls_tokens]
 mov ecx,MAX_TOKENS
 call json_parse
 test rax,rax
 js .Lpv_done
 cmp qword ptr [rip+.Ls_tokens+T_TYPE],JT_ARRAY
 jne .Lpv_done
 mov ebx,1
.Lpv_message:
 cmp rbx,[rip+.Ls_tokens+T_END]
 jae .Lpv_transcript_done
 mov r12,rbx
 shl r12,5
 lea r15,[rip+.Ls_tokens]
 add r12,r15
 cmp qword ptr [r12+T_TYPE],JT_OBJECT
 jne .Lpv_next
 lea rdi,[rip+.Ls_json]
 mov rsi,r15
 mov rdx,rbx
 lea rcx,[rip+.Ls_role]
 call json_find
 test rax,rax
 js .Lpv_next
 shl rax,5
 cmp qword ptr [r15+rax+T_TYPE],JT_STRING
 jne .Lpv_next
 lea rdi,[rip+.Ls_decoded]
 lea rsi,[rip+.Ls_json]
 add rsi,[r15+rax+T_START]
 mov rdx,[r15+rax+T_LEN]
 mov ecx,MAX_JSON
 call json_decode
 cmp rax,4
 je .Lpv_role_four
 cmp rax,9
 jne .Lpv_next
 movabs rdx,0x6e61747369737361 # assistan
 cmp [rip+.Ls_decoded],rdx
 jne .Lpv_next
 cmp byte ptr [rip+.Ls_decoded+8],116
 jne .Lpv_next
 lea r13,[rip+.Lpv_assistant]
 mov r14d,PV_ASSISTANT
 jmp .Lpv_content
.Lpv_role_four:
 cmp dword ptr [rip+.Ls_decoded],0x72657375
 jne .Lpv_role_tool
 lea r13,[rip+.Lpv_user]
 mov r14d,PV_USER
 jmp .Lpv_content
.Lpv_role_tool:
 cmp dword ptr [rip+.Ls_decoded],0x6c6f6f74
 jne .Lpv_next
 lea r13,[rip+.Lpv_tool]
 mov r14d,PV_TOOL
.Lpv_content:
 lea rdi,[rip+.Ls_json]
 mov rsi,r15
 mov rdx,rbx
 lea rcx,[rip+.Ls_content]
 call json_find
 test rax,rax
 js .Lpv_next
 shl rax,5
 call .Ls_text_content
 test rax,rax
 js .Lpv_next
 mov rbp,rax
 mov rdi,[rip+.Lpv_length]
 add rdi,r14
 cmp rdi,MAX_JSON-3
 ja .Lpv_full
 lea rdi,[rip+.Lpv_text]
 add rdi,[rip+.Lpv_length]
 mov rsi,r13
 mov rcx,r14
 rep movsb
 lea rsi,[rip+.Ls_json]
 add rsi,[r15+rbp+T_START]
 mov rdx,[r15+rbp+T_LEN]
 mov rcx,MAX_JSON-2
 sub rcx,[rip+.Lpv_length]
 sub rcx,r14
 call json_decode
 test rax,rax
 js .Lpv_full
 add rax,r14
 add rax,[rip+.Lpv_length]
 lea rdi,[rip+.Lpv_text]
 mov word ptr [rdi+rax],0x0a0a
 add rax,2
 mov [rip+.Lpv_length],rax
.Lpv_next:
 mov rbx,[r12+T_END]
 jmp .Lpv_message
.Lpv_transcript_done:
 mov rcx,[rip+.Lpv_length]
 test rcx,rcx
 jnz .Lpv_copy
 lea rdi,[rip+.Lpv_text]
 lea rsi,[rip+.Lpv_empty]
 mov ecx,PV_EMPTY
 rep movsb
 mov ecx,PV_EMPTY
.Lpv_copy:
 cmp rcx,[rip+.Lpv_cap]
 jae .Lpv_full
 mov [rip+.Lpv_result],rcx
 mov rdi,[rip+.Lpv_out]
 lea rsi,[rip+.Lpv_text]
 rep movsb
 mov byte ptr [rdi],0
 jmp .Lpv_done
.Lpv_full:
 mov qword ptr [rip+.Lpv_result],-28
 jmp .Lpv_done
.Lpv_error:
 mov [rip+.Lpv_result],rax
.Lpv_done:
 mov rdi,[rip+.Lpv_fd]
 test rdi,rdi
 js .Lpv_return
 mov eax,3
 syscall
.Lpv_return:
 mov rax,[rip+.Lpv_result]
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

.section .rodata
.Lrt_now: .ascii "just now"
.Lrt_month: .ascii " month"
.Lrt_week: .ascii " week"
.Lrt_day: .ascii " day"
.Lrt_hour: .ascii " hour"
.Lrt_minute: .ascii " minute"
.text
.global ui_relative_time
# nowSeconds,mtimeSeconds,out,cap ->length/-errno; unchanged output on error.
# Exact formatRelativeTime thresholds:30day months,7day weeks,days,hours,
# minutes,then justnow. Future dates are justnow. No calendar arithmetic.
ui_relative_time:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,64
 mov r12,rdx
 mov r13,rcx
 test rdx,rdx
 jz .Lrt_invalid
 cmp rsi,rdi
 jge .Lrt_just_now
 mov rax,rdi
 sub rax,rsi
 cmp rax,2592000
 jae .Lrt_months
 cmp rax,604800
 jae .Lrt_weeks
 cmp rax,86400
 jae .Lrt_days
 cmp rax,3600
 jae .Lrt_hours
 cmp rax,60
 jb .Lrt_just_now
 mov r9d,60
 lea r14,[rip+.Lrt_minute]
 mov r15d,7
 jmp .Lrt_divide
.Lrt_months:
 mov r9d,2592000
 lea r14,[rip+.Lrt_month]
 mov r15d,6
 jmp .Lrt_divide
.Lrt_weeks:
 mov r9d,604800
 lea r14,[rip+.Lrt_week]
 mov r15d,5
 jmp .Lrt_divide
.Lrt_days:
 mov r9d,86400
 lea r14,[rip+.Lrt_day]
 mov r15d,4
 jmp .Lrt_divide
.Lrt_hours:
 mov r9d,3600
 lea r14,[rip+.Lrt_hour]
 mov r15d,5
.Lrt_divide:
 xor edx,edx
 div r9
 mov rbx,rax
 lea rdi,[rsp+32]
 xor ecx,ecx
 mov r9d,10
.Lrt_digits:
 xor edx,edx
 div r9
 add dl,48
 dec rdi
 mov [rdi],dl
 inc ecx
 test rax,rax
 jnz .Lrt_digits
 mov r8,rdi
 lea r10,[rcx+r15+4]
 cmp rbx,1
 je .Lrt_capacity
 inc r10
.Lrt_capacity:
 cmp r10,r13
 jae .Lrt_full
 mov rdi,r12
 mov rsi,r8
 rep movsb
 mov rsi,r14
 mov rcx,r15
 rep movsb
 cmp rbx,1
 je .Lrt_ago
 mov byte ptr [rdi],115
 inc rdi
.Lrt_ago:
 mov dword ptr [rdi],0x6f676120
 mov byte ptr [rdi+4],0
 mov rax,r10
 jmp .Lrt_return
.Lrt_just_now:
 cmp r13,8
 jbe .Lrt_full
 mov rdi,r12
 lea rsi,[rip+.Lrt_now]
 mov ecx,8
 rep movsb
 mov byte ptr [rdi],0
 mov eax,8
 jmp .Lrt_return
.Lrt_invalid:
 mov rax,-22
 jmp .Lrt_return
.Lrt_full:
 mov rax,-28
.Lrt_return:
 add rsp,64
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Management APIs only touch files in the explicitly configured session directory.
# Titles are JSON-string sidecars: no provider-visible message is introduced and
# later transcript saves cannot silently discard a rename.
.section .rodata
.Lm_title_suffix: .asciz ".title"
.Lm_agent_suffix: .asciz ".agent.json"
.Lm_session_prefix: .ascii "session-"
.Lm_json_suffix: .ascii ".json"
.Lm_temp_prefix: .ascii ".title-"
.Lm_hex: .ascii "0123456789abcdef"
.section .bss
.balign 16
.Lm_home: .skip 4096
.Lm_prefix: .skip 4096
.Lm_prefixlen: .skip 8
.Lm_allow: .skip 8
.Lm_dir: .skip 8
.Lm_fd: .skip 8
.Lm_name: .skip 256
.Lm_title_name: .skip 272
.Lm_temp: .skip 48
.Lm_random: .skip 16
.Lm_stat: .skip 144
.Lm_quoted: .skip 2048
.Lm_title: .skip 512
.Lm_tokens: .skip 128
.section .text
.global ui_session_mutations_config
ui_session_mutations_config:
 mov qword ptr [rip+.Lm_allow],0
 mov qword ptr [rip+.Lm_prefixlen],0
 test rdi,rdi
 jz .Lm_cfg_bad
 cmp byte ptr [rdi],47
 jne .Lm_cfg_bad
 mov r8,rsi
 lea rdx,[rip+.Lm_home]
 lea r9,[rip+.Lm_prefix]
 xor ecx,ecx
.Lm_cfg_copy:
 cmp ecx,3500
 jae .Lm_cfg_bad
 mov al,[rdi+rcx]
 test al,al
 jz .Lm_cfg_done
 cmp al,32
 jb .Lm_cfg_bad
 mov [rdx+rcx],al
 mov [r9+rcx],al
 inc ecx
 jmp .Lm_cfg_copy
.Lm_cfg_done:
 mov byte ptr [rdx+rcx],0
 lea rdi,[r9+rcx]
 lea rsi,[rip+.Ls_suffix]
.Lm_cfg_suffix:
 lodsb
 stosb
 test al,al
 jnz .Lm_cfg_suffix
 sub rdi,r9
 dec rdi
 mov [rip+.Lm_prefixlen],rdi
 test r8,r8
 setnz al
 movzx eax,al
 mov [rip+.Lm_allow],rax
 xor eax,eax
 ret
.Lm_cfg_bad:
 mov rax,-22
 ret

# rdi absolute session path -> validated basename + opened owner regular source.
# Caller closes .Lm_fd and .Lm_dir on all branches.
.Lm_open:
 mov qword ptr [rip+.Lm_dir],-1
 mov qword ptr [rip+.Lm_fd],-1
 cmp qword ptr [rip+.Lm_allow],0
 je .Lm_denied
 test rdi,rdi
 jz .Lm_invalid
 mov rcx,[rip+.Lm_prefixlen]
 test rcx,rcx
 jz .Lm_invalid
 lea rsi,[rip+.Lm_prefix]
.Lm_match_prefix:
 mov al,[rdi]
 test al,al
 jz .Lm_invalid
 cmp al,[rsi]
 jne .Lm_invalid
 inc rdi
 inc rsi
 dec rcx
 jnz .Lm_match_prefix
 mov r8,rdi
 xor ecx,ecx
 lea rdx,[rip+.Lm_name]
.Lm_basename:
 cmp ecx,240
 jae .Lm_invalid
 mov al,[r8+rcx]
 test al,al
 jz .Lm_basename_done
 cmp al,47
 je .Lm_invalid
 cmp al,32
 jb .Lm_invalid
 cmp al,127
 je .Lm_invalid
 mov [rdx+rcx],al
 inc ecx
 jmp .Lm_basename
.Lm_basename_done:
 cmp ecx,13
 jb .Lm_invalid
 mov byte ptr [rdx+rcx],0
 mov r9,rcx
 lea rsi,[rip+.Lm_session_prefix]
 mov rdi,rdx
 mov ecx,8
 repe cmpsb
 jne .Lm_invalid
 lea rdi,[rdx+r9-5]
 lea rsi,[rip+.Lm_json_suffix]
 mov ecx,5
 repe cmpsb
 jne .Lm_invalid
 lea rsi,[rip+.Lm_name]
 lea rdi,[rip+.Lm_title_name]
 mov rcx,r9
 rep movsb
 lea rsi,[rip+.Lm_title_suffix]
 mov ecx,7
 rep movsb
 mov eax,2
 lea rdi,[rip+.Lm_home]
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .Lm_open_return
 mov [rip+.Lm_dir],rax
 lea rsi,[rip+.Ls_local]
 call .Lm_component
 test rax,rax
 js .Lm_open_return
 lea rsi,[rip+.Ls_state]
 call .Lm_component
 test rax,rax
 js .Lm_open_return
 lea rsi,[rip+.Ls_app]
 call .Lm_component
 test rax,rax
 js .Lm_open_return
 mov eax,257
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_name]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lm_open_return
 mov [rip+.Lm_fd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Lm_stat]
 syscall
 test rax,rax
 js .Lm_open_return
 mov eax,[rip+.Lm_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lm_invalid
 mov eax,107
 syscall
 cmp eax,[rip+.Lm_stat+28]
 jne .Lm_denied
 xor eax,eax
.Lm_open_return:
 ret
.Lm_invalid:
 mov rax,-22
 ret
.Lm_denied:
 mov rax,-13
 ret
.Lm_component:
 mov eax,257
 mov rdi,[rip+.Lm_dir]
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lm_component_ret
 mov r8,rax
 mov eax,3
 mov rdi,[rip+.Lm_dir]
 syscall
 mov [rip+.Lm_dir],r8
 xor eax,eax
.Lm_component_ret:
 ret
.Lm_cleanup:
 push rax
 mov rdi,[rip+.Lm_fd]
 cmp rdi,0
 jl .Lm_cleanup_dir
 mov eax,3
 syscall
.Lm_cleanup_dir:
 mov rdi,[rip+.Lm_dir]
 cmp rdi,0
 jl .Lm_cleanup_done
 mov eax,3
 syscall
.Lm_cleanup_done:
 pop rax
 ret
.global ui_session_delete
ui_session_delete:
 push rbx
 call .Lm_open
 test rax,rax
 js .Lm_delete_done
 # unlinkat does not follow the target; a replacement symlink is only removed.
 mov eax,263
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_name]
 xor edx,edx
 syscall
 test rax,rax
 js .Lm_delete_done
 mov eax,263
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_title_name]
 xor edx,edx
 syscall
 cmp rax,-2
 je .Lm_delete_agent_state
 test rax,rax
 js .Lm_delete_done
.Lm_delete_agent_state:
 # Session deletion includes native ACP continuation state introduced with the
 # external adapter; unlink the name itself, never dereference a sidecar link.
 lea rdi,[rip+.Lm_title_name]
 lea rsi,[rip+.Lm_name]
.Lm_delete_namecopy:
 lodsb
 test al,al
 jz .Lm_delete_agent_suffix
 stosb
 jmp .Lm_delete_namecopy
.Lm_delete_agent_suffix:
 lea rsi,[rip+.Lm_agent_suffix]
.Lm_delete_suffixcopy:
 lodsb
 stosb
 test al,al
 jnz .Lm_delete_suffixcopy
 mov eax,263
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_title_name]
 xor edx,edx
 syscall
 cmp rax,-2
 je .Lm_delete_sync
 test rax,rax
 js .Lm_delete_done
.Lm_delete_sync:
 mov eax,74
 mov rdi,[rip+.Lm_dir]
 syscall
.Lm_delete_done:
 call .Lm_cleanup
 pop rbx
 ret
.global ui_session_delete_many
ui_session_delete_many:
 push rbx
 push r12
 push r13
 push r14
 push r15
 test rdi,rdi
 jz .Lm_many_bad
 test rdx,rdx
 jz .Lm_many_bad
 cmp rsi,64
 ja .Lm_many_bad
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 xor ebx,ebx
 xor r15d,r15d
.Lm_many_next:
 cmp rbx,r13
 jae .Lm_many_done
 mov rdi,[r12+rbx*8]
 call ui_session_delete
 mov [r14+rbx*8],rax
 test rax,rax
 jne .Lm_many_advance
 inc r15
.Lm_many_advance:
 inc rbx
 jmp .Lm_many_next
.Lm_many_done:
 mov rax,r15
 jmp .Lm_many_return
.Lm_many_bad:
 mov rax,-22
.Lm_many_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.global ui_session_rename
ui_session_rename:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 test rsi,rsi
 jz .Lm_rename_bad
 test rdx,rdx
 jz .Lm_rename_bad
 cmp rdx,400
 ja .Lm_rename_bad
 xor ecx,ecx
.Lm_title_check:
 cmp rcx,r14
 jae .Lm_title_quote
 mov al,[r13+rcx]
 cmp al,32
 jb .Lm_rename_bad
 cmp al,127
 je .Lm_rename_bad
 inc rcx
 jmp .Lm_title_check
.Lm_title_quote:
 lea rdi,[rip+.Lm_quoted]
 mov rsi,r13
 mov rdx,r14
 mov ecx,2048
 call json_quote
 test rax,rax
 js .Lm_rename_bad
 mov r15,rax
 lea rdi,[rip+.Lm_quoted]
 mov rsi,rax
 lea rdx,[rip+.Lm_tokens]
 mov ecx,4
 call json_parse
 cmp rax,1
 jne .Lm_rename_bad
 mov rdi,r12
 call .Lm_open
 test rax,rax
 js .Lm_rename_done
 # Unique private sidecar temp, no arbitrary old-file truncation.
 mov eax,318
 lea rdi,[rip+.Lm_random]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,16
 jne .Lm_rename_io
 lea rdi,[rip+.Lm_temp]
 lea rsi,[rip+.Lm_temp_prefix]
 mov ecx,7
 rep movsb
 lea rsi,[rip+.Lm_random]
 lea r8,[rip+.Lm_hex]
 mov ecx,16
.Lm_hex_loop:
 lodsb
 movzx edx,al
 shr edx,4
 mov dl,[r8+rdx]
 mov [rdi],dl
 inc rdi
 and eax,15
 mov al,[r8+rax]
 stosb
 loop .Lm_hex_loop
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_temp]
 mov edx,0xa00c1
 mov r10d,384
 syscall
 test rax,rax
 js .Lm_rename_done
 mov rbx,rax
 mov eax,91
 mov rdi,rbx
 mov esi,384
 syscall
 test rax,rax
 js .Lm_temp_error
 xor r13d,r13d
.Lm_write:
 mov eax,1
 mov rdi,rbx
 lea rsi,[rip+.Lm_quoted]
 add rsi,r13
 mov rdx,r15
 sub rdx,r13
 syscall
 cmp rax,-4
 je .Lm_write
 test rax,rax
 jle .Lm_temp_io
 add r13,rax
 cmp r13,r15
 jb .Lm_write
 mov eax,74
 mov rdi,rbx
 syscall
 test rax,rax
 js .Lm_temp_error
 mov eax,3
 mov rdi,rbx
 syscall
 mov rbx,-1
 mov eax,264
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_temp]
 mov rdx,rdi
 lea r10,[rip+.Lm_title_name]
 syscall
 test rax,rax
 js .Lm_temp_error
 mov eax,74
 mov rdi,[rip+.Lm_dir]
 syscall
 jmp .Lm_rename_done
.Lm_temp_io:
 mov rax,-5
.Lm_temp_error:
 mov r12,rax
 cmp rbx,0
 jl .Lm_temp_unlink
 mov eax,3
 mov rdi,rbx
 syscall
.Lm_temp_unlink:
 mov eax,263
 mov rdi,[rip+.Lm_dir]
 lea rsi,[rip+.Lm_temp]
 xor edx,edx
 syscall
 mov rax,r12
 jmp .Lm_rename_done
.Lm_rename_io:
 mov rax,-5
.Lm_rename_done:
 call .Lm_cleanup
 jmp .Lm_rename_return
.Lm_rename_bad:
 mov rax,-22
.Lm_rename_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Catalog title lookup uses its already safely opened directory. Untrusted,
# oversized, non-regular or malformed sidecars never hide a valid session.
.Lm_catalog_title:
 push rbx
 push r13
 push r14
 sub rsp,16
 lea rdi,[rip+.Lm_title_name]
 mov rsi,[rip+.Ls_name]
 xor ecx,ecx
.Lm_cat_name:
 mov al,[rsi+rcx]
 test al,al
 jz .Lm_cat_suffix
 cmp ecx,240
 jae .Lm_cat_done
 mov [rdi+rcx],al
 inc ecx
 jmp .Lm_cat_name
.Lm_cat_suffix:
 add rdi,rcx
 lea rsi,[rip+.Lm_title_suffix]
 mov ecx,7
 rep movsb
 mov eax,257
 mov rdi,[rip+.Ls_dir]
 lea rsi,[rip+.Lm_title_name]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lm_cat_done
 mov rbx,rax
 mov eax,5
 mov rdi,rbx
 lea rsi,[rip+.Lm_stat]
 syscall
 test rax,rax
 js .Lm_cat_close
 mov eax,[rip+.Lm_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lm_cat_close
 mov eax,107
 syscall
 cmp eax,[rip+.Lm_stat+28]
 jne .Lm_cat_close
 cmp qword ptr [rip+.Lm_stat+48],2047
 ja .Lm_cat_close
 xor eax,eax
 mov rdi,rbx
 lea rsi,[rip+.Lm_quoted]
 mov edx,2048
 syscall
 test rax,rax
 jle .Lm_cat_close
 mov r13,rax
 lea rdi,[rip+.Lm_quoted]
 mov rsi,rax
 lea rdx,[rip+.Lm_tokens]
 mov ecx,4
 call json_parse
 cmp rax,1
 jne .Lm_cat_close
 cmp qword ptr [rip+.Lm_tokens+T_TYPE],JT_STRING
 jne .Lm_cat_close
 lea rdi,[rip+.Lm_title]
 lea rsi,[rip+.Lm_quoted]
 add rsi,[rip+.Lm_tokens+T_START]
 mov rdx,[rip+.Lm_tokens+T_LEN]
 mov ecx,401
 call json_decode
 test rax,rax
 jle .Lm_cat_close
 cmp rax,400
 ja .Lm_cat_close
 mov r14,rax
 xor ecx,ecx
 lea rsi,[rip+.Lm_title]
.Lm_cat_validate:
 cmp rcx,r14
 jae .Lm_cat_copy
 mov al,[rsi+rcx]
 cmp al,32
 jb .Lm_cat_close
 cmp al,127
 je .Lm_cat_close
 inc rcx
 jmp .Lm_cat_validate
.Lm_cat_copy:
 mov rdi,r12
 mov rcx,r14
 rep movsb
 mov byte ptr [rdi],0
.Lm_cat_close:
 mov eax,3
 mov rdi,rbx
 syscall
.Lm_cat_done:
 add rsp,16
 pop r14
 pop r13
 pop rbx
 ret

# Accept legacy string or first OpenAI text part; never expose image/data parts.
# Input token byte offset in RAX, tokens base R15. Output text offset/-1.
.Ls_text_content:
 cmp qword ptr [r15+rax+T_TYPE],JT_STRING
 je .Ls_text_ret
 cmp qword ptr [r15+rax+T_TYPE],JT_ARRAY
 jne .Ls_text_missing
 mov rdx,rax
 shr rdx,5
 inc rdx
 cmp rdx,[r15+rax+T_END]
 jae .Ls_text_missing
 mov rax,rdx
 shl rax,5
 cmp qword ptr [r15+rax+T_TYPE],JT_OBJECT
 jne .Ls_text_missing
 sub rsp,8
 lea rdi,[rip+.Ls_json]
 mov rsi,r15
 lea rcx,[rip+.Ls_text_key]
 call json_find
 add rsp,8
 test rax,rax
 js .Ls_text_missing
 shl rax,5
 cmp qword ptr [r15+rax+T_TYPE],JT_STRING
 jne .Ls_text_missing
.Ls_text_ret:
 ret
.Ls_text_missing:
 mov rax,-1
 ret
.section .rodata
.Ls_text_key: .asciz "text"
