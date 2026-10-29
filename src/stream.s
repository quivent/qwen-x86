.include "abi.inc"
.equ CALL_SIZE,33024
.equ CALL_IDLEN,128
.equ CALL_NAME,136
.equ CALL_NAMELEN,200
.equ CALL_ARGS,208
.equ CALL_ARGLEN,32976
.text
.global stream_begin,stream_feed,stream_finish,stream_result,stream_calls,stream_usage,stream_usage_snapshot
# Single process-owned SSE state; parallel agents use private forked pages.
stream_begin:
    mov [rip+s_callback],rdi
    mov qword ptr [rip+s_line_len],0
    mov qword ptr [rip+s_event_len],0
    mov qword ptr [rip+s_content_len],0
    mov qword ptr [rip+s_call_count],0
    mov qword ptr [rip+s_done],0
    mov qword ptr [rip+s_finished],0
    mov qword ptr [rip+s_error],0
    mov qword ptr [rip+s_usage_prompt],0
    mov qword ptr [rip+s_usage_completion],0
    mov qword ptr [rip+s_usage_total],0
    mov qword ptr [rip+s_usage_present],0
    lea rdi,[rip+s_call_table]
    mov ecx,8
.L_stream_reset_call:
    mov byte ptr [rdi],0
    mov qword ptr [rdi+CALL_IDLEN],0
    mov byte ptr [rdi+CALL_NAME],0
    mov qword ptr [rdi+CALL_NAMELEN],0
    mov byte ptr [rdi+CALL_ARGS],0
    mov qword ptr [rdi+CALL_ARGLEN],0
    add rdi,CALL_SIZE
    dec ecx
    jnz .L_stream_reset_call
    xor eax,eax
    ret
stream_result:
    lea rax,[rip+s_content]
    mov rdx,[rip+s_content_len]
    ret
stream_calls:
    lea rax,[rip+s_call_table]
    mov rdx,[rip+s_call_count]
    ret
# Real provider-reported counters only; absent/partial/invalid metadata is not
# synthesized. Registers mirror the compact native stream-result interfaces.
stream_usage:
    mov rax,[rip+s_usage_prompt]
    mov rdx,[rip+s_usage_completion]
    mov rcx,[rip+s_usage_total]
    mov r8,[rip+s_usage_present]
    ret
stream_usage_snapshot:
    mov rax,[rip+s_usage_prompt]
    mov [rdi],rax
    mov rax,[rip+s_usage_completion]
    mov [rdi+8],rax
    mov rax,[rip+s_usage_total]
    mov [rdi+16],rax
    mov rax,[rip+s_usage_present]
    mov [rdi+24],rax
    ret
stream_feed:
    push rbx
    push r12
    push r13
    mov r12,rdi
    mov r13,rsi
    cmp qword ptr [rip+s_error],0
    jne .L_feed_bad
.L_feed_next:
    test r13,r13
    jz .L_feed_ok
    mov al,[r12]
    inc r12
    dec r13
    cmp al,10
    je .L_feed_line
    mov rbx,[rip+s_line_len]
    cmp rbx,65535
    jae .L_feed_bad
    lea rdx,[rip+s_line]
    mov [rdx+rbx],al
    inc qword ptr [rip+s_line_len]
    jmp .L_feed_next
.L_feed_line:
    call .L_sse_line
    test rax,rax
    js .L_feed_bad
    jmp .L_feed_next
.L_feed_ok:
    xor eax,eax
    jmp .L_feed_return
.L_feed_bad:
    mov qword ptr [rip+s_error],1
    mov rax,-1
.L_feed_return:
    pop r13
    pop r12
    pop rbx
    ret
stream_finish:
    sub rsp,8
    cmp qword ptr [rip+s_error],0
    jne .L_finish_bad
    cmp qword ptr [rip+s_line_len],0
    je .L_finish_event
    call .L_sse_line
    test rax,rax
    js .L_finish_bad
.L_finish_event:
    cmp qword ptr [rip+s_event_len],0
    je .L_finish_marker
    call .L_sse_event
    test rax,rax
    js .L_finish_bad
.L_finish_marker:
    mov rax,[rip+s_done]
    or rax,[rip+s_finished]
    jz .L_finish_bad
    xor eax,eax
    add rsp,8
    ret
.L_finish_bad:
    mov rax,-1
    add rsp,8
    ret
# Strip a final CR, append data fields; dispatch only at event boundary.
.L_sse_line:
    push rbx
    mov rbx,[rip+s_line_len]
    mov qword ptr [rip+s_line_len],0
    lea rsi,[rip+s_line]
    test rbx,rbx
    jz .L_sse_blank
    cmp byte ptr [rsi+rbx-1],13
    jne .L_sse_cr_done
    dec rbx
.L_sse_cr_done:
    test rbx,rbx
    jz .L_sse_blank
    cmp rbx,5
    jb .L_sse_line_ok
    cmp dword ptr [rsi],0x61746164
    jne .L_sse_line_ok
    cmp byte ptr [rsi+4],':'
    jne .L_sse_line_ok
    add rsi,5
    sub rbx,5
    test rbx,rbx
    jz .L_sse_data
    cmp byte ptr [rsi],' '
    jne .L_sse_data
    inc rsi
    dec rbx
.L_sse_data:
    mov rax,[rip+s_event_len]
    mov rdx,rax
    add rdx,rbx
    inc rdx
    cmp rdx,65536
    ja .L_sse_line_bad
    lea rdi,[rip+s_event]
    add rdi,rax
    mov rcx,rbx
    rep movsb
    mov byte ptr [rdi],10
    mov [rip+s_event_len],rdx
    jmp .L_sse_line_ok
.L_sse_blank:
    cmp qword ptr [rip+s_event_len],0
    je .L_sse_line_ok
    call .L_sse_event
    pop rbx
    ret
.L_sse_line_ok:
    xor eax,eax
    pop rbx
    ret
.L_sse_line_bad:
    mov rax,-1
    pop rbx
    ret
.L_stream_find:
    mov rdx,rdi
    mov rcx,rsi
    lea rdi,[rip+s_event]
    lea rsi,[rip+s_tokens]
    jmp json_find
# Decode token index into dst+*len, reserving a final NUL in cap.
.L_stream_append:
    push rbx
    push r12
    push r13
    mov rbx,rdx
    mov r12,rsi
    mov r13,rcx
    shl rdi,5
    lea rax,[rip+s_tokens]
    add rax,rdi
    cmp qword ptr [rax+T_TYPE],JT_STRING
    jne .L_stream_append_bad
    mov rdx,[rax+T_LEN]
    mov rsi,[rax+T_START]
    lea rdi,[rip+s_event]
    add rsi,rdi
    mov rdi,r12
    add rdi,[rbx]
    mov rcx,r13
    sub rcx,[rbx]
    jbe .L_stream_append_bad
    dec rcx
    call json_decode
    test rax,rax
    js .L_stream_append_bad
    add [rbx],rax
    mov rdx,[rbx]
    mov byte ptr [r12+rdx],0
    jmp .L_stream_append_return
.L_stream_append_bad:
    mov rax,-1
.L_stream_append_return:
    pop r13
    pop r12
    pop rbx
    ret
.L_sse_event:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rsi,[rip+s_event_len]
    mov qword ptr [rip+s_event_len],0
    test rsi,rsi
    jz .L_event_ok
    dec rsi
    cmp rsi,6
    jne .L_event_json
    lea rax,[rip+s_event]
    cmp dword ptr [rax],0x4e4f445b
    jne .L_event_json
    cmp word ptr [rax+4],0x5d45
    jne .L_event_json
    mov qword ptr [rip+s_done],1
    jmp .L_event_ok
.L_event_json:
    lea rdi,[rip+s_event]
    lea rdx,[rip+s_tokens]
    mov ecx,MAX_TOKENS
    call json_parse
    test rax,rax
    js .L_event_bad
    call .L_stream_extract_usage
    xor edi,edi
    lea rsi,[rip+k_choices]
    call .L_stream_find
    test rax,rax
    js .L_event_bad
    mov rbx,rax
    shl rax,5
    lea rdx,[rip+s_tokens]
    cmp qword ptr [rdx+rax],JT_ARRAY
    jne .L_event_bad
    inc rbx
    cmp rbx,[rdx+rax+T_END]
    jae .L_event_ok
    mov rdi,rbx
    lea rsi,[rip+k_finish]
    call .L_stream_find
    test rax,rax
    js .L_event_delta
    shl rax,5
    lea rdx,[rip+s_tokens]
    cmp qword ptr [rdx+rax],JT_STRING
    jne .L_event_delta
    add rdx,rax
    mov rsi,[rdx+T_START]
    lea rdi,[rip+s_event]
    add rsi,rdi
    mov rdx,[rdx+T_LEN]
    lea rdi,[rip+s_finish_reason]
    mov ecx,15
    call json_decode
    test rax,rax
    js .L_event_bad
    lea rdi,[rip+s_finish_reason]
    mov byte ptr [rdi+rax],0
    lea rsi,[rip+finish_stop]
    call qx_streq
    test eax,eax
    jnz .L_event_finished_ok
    lea rdi,[rip+s_finish_reason]
    lea rsi,[rip+finish_tool_calls]
    call qx_streq
    test eax,eax
    jz .L_event_bad
.L_event_finished_ok:
    mov qword ptr [rip+s_finished],1
.L_event_delta:
    mov rdi,rbx
    lea rsi,[rip+k_delta]
    call .L_stream_find
    test rax,rax
    js .L_event_ok
    mov r12,rax
    mov rdi,r12
    lea rsi,[rip+k_content]
    call .L_stream_find
    test rax,rax
    js .L_event_tools
    mov rdx,rax
    shl rdx,5
    lea rcx,[rip+s_tokens]
    cmp qword ptr [rcx+rdx],JT_NULL
    je .L_event_tools
    mov rdi,rax
    lea rsi,[rip+s_content]
    lea rdx,[rip+s_content_len]
    mov ecx,MAX_JSON
    mov r13,[rdx]
    call .L_stream_append
    test rax,rax
    js .L_event_bad
    test rax,rax
    jz .L_event_tools
    mov rsi,rax
    lea rdi,[rip+s_content]
    add rdi,r13
    mov rax,[rip+s_callback]
    test rax,rax
    jz .L_event_tools
    call rax
    test rax,rax
    js .L_event_bad
.L_event_tools:
    mov rdi,r12
    lea rsi,[rip+k_tool_calls]
    call .L_stream_find
    test rax,rax
    js .L_event_ok
    mov rbx,rax
    shl rax,5
    lea rdx,[rip+s_tokens]
    cmp qword ptr [rdx+rax],JT_ARRAY
    jne .L_event_bad
    mov r15,[rdx+rax+T_END]
    inc rbx
.L_event_tool_next:
    cmp rbx,r15
    jae .L_event_ok
    mov rdi,rbx
    lea rsi,[rip+k_index]
    call .L_stream_find
    test rax,rax
    js .L_event_bad
    shl rax,5
    lea rdx,[rip+s_tokens]
    add rdx,rax
    cmp qword ptr [rdx],JT_NUMBER
    jne .L_event_bad
    mov rsi,[rdx+T_LEN]
    mov rdi,[rdx+T_START]
    lea rax,[rip+s_event]
    add rdi,rax
    call qx_parse_uint
    cmp rax,8
    jae .L_event_bad
    lea rdx,[rax+1]
    cmp rdx,[rip+s_call_count]
    jbe .L_event_tool_known
    mov [rip+s_call_count],rdx
.L_event_tool_known:
    imul rax,rax,CALL_SIZE
    lea r14,[rip+s_call_table]
    add r14,rax
    mov rdi,rbx
    lea rsi,[rip+k_id]
    call .L_stream_find
    test rax,rax
    js .L_event_tool_function
    mov rdi,rax
    mov rsi,r14
    lea rdx,[r14+CALL_IDLEN]
    mov ecx,128
    call .L_stream_append
    test rax,rax
    js .L_event_bad
.L_event_tool_function:
    mov rdi,rbx
    lea rsi,[rip+k_function]
    call .L_stream_find
    test rax,rax
    js .L_event_tool_advance
    mov r13,rax
    mov rdi,r13
    lea rsi,[rip+k_name]
    call .L_stream_find
    test rax,rax
    js .L_event_tool_arguments
    mov rdi,rax
    lea rsi,[r14+CALL_NAME]
    lea rdx,[r14+CALL_NAMELEN]
    mov ecx,64
    call .L_stream_append
    test rax,rax
    js .L_event_bad
.L_event_tool_arguments:
    mov rdi,r13
    lea rsi,[rip+k_arguments]
    call .L_stream_find
    test rax,rax
    js .L_event_tool_advance
    mov rdi,rax
    lea rsi,[r14+CALL_ARGS]
    lea rdx,[r14+CALL_ARGLEN]
    mov ecx,32768
    call .L_stream_append
    test rax,rax
    js .L_event_bad
.L_event_tool_advance:
    mov rax,rbx
    shl rax,5
    lea rdx,[rip+s_tokens]
    mov rbx,[rdx+rax+T_END]
    jmp .L_event_tool_next
.L_event_bad:
    mov qword ptr [rip+s_error],1
    mov rax,-1
    jmp .L_event_return
.L_event_ok:
    xor eax,eax
.L_event_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# Metadata extraction is transactional. A malformed optional usage field never
# corrupts an earlier valid report or turns otherwise valid content into error.
.L_stream_extract_usage:
    push rbx
    push r12
    push r13
    push r14
    push r15
    xor edi,edi
    lea rsi,[rip+k_usage]
    call .L_stream_find
    test rax,rax
    js .L_usage_absent
    mov r12,rax
    shl rax,5
    lea rdx,[rip+s_tokens]
    cmp qword ptr [rdx+rax+T_TYPE],JT_OBJECT
    jne .L_usage_absent
    mov rdi,r12
    lea rsi,[rip+k_prompt_tokens]
    call .L_stream_find
    test rax,rax
    js .L_usage_absent
    call .L_usage_integer
    test rdx,rdx
    jz .L_usage_absent
    mov r13,rax
    mov rdi,r12
    lea rsi,[rip+k_completion_tokens]
    call .L_stream_find
    test rax,rax
    js .L_usage_absent
    call .L_usage_integer
    test rdx,rdx
    jz .L_usage_absent
    mov r14,rax
    mov rdi,r12
    lea rsi,[rip+k_total_tokens]
    call .L_stream_find
    test rax,rax
    js .L_usage_absent
    call .L_usage_integer
    test rdx,rdx
    jz .L_usage_absent
    mov [rip+s_usage_prompt],r13
    mov [rip+s_usage_completion],r14
    mov [rip+s_usage_total],rax
    mov qword ptr [rip+s_usage_present],1
    mov eax,1
    jmp .L_usage_return
.L_usage_absent:
    xor eax,eax
.L_usage_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# Token index RAX -> unsigned decimal integer<=INT64_MAX inRAX, validityRDX.
# Reject negative/fraction/exponent/string/overflow counters rather than guessing.
.L_usage_integer:
    shl rax,5
    lea rdx,[rip+s_tokens]
    add rdx,rax
    cmp qword ptr [rdx+T_TYPE],JT_NUMBER
    jne .L_usage_integer_bad
    mov rcx,[rdx+T_LEN]
    test rcx,rcx
    jz .L_usage_integer_bad
    cmp rcx,19
    ja .L_usage_integer_bad
    lea rsi,[rip+s_event]
    add rsi,[rdx+T_START]
    xor eax,eax
.L_usage_integer_digit:
    movzx edi,byte ptr [rsi]
    sub edi,48
    cmp edi,9
    ja .L_usage_integer_bad
    imul rax,rax,10
    jo .L_usage_integer_bad
    add rax,rdi
    jo .L_usage_integer_bad
    inc rsi
    dec rcx
    jnz .L_usage_integer_digit
    mov edx,1
    ret
.L_usage_integer_bad:
    xor eax,eax
    xor edx,edx
    ret
.section .rodata
finish_stop: .asciz "stop"
finish_tool_calls: .asciz "tool_calls"
k_choices: .asciz "choices"
k_usage: .asciz "usage"
k_prompt_tokens: .asciz "prompt_tokens"
k_completion_tokens: .asciz "completion_tokens"
k_total_tokens: .asciz "total_tokens"
k_finish: .asciz "finish_reason"
k_delta: .asciz "delta"
k_content: .asciz "content"
k_tool_calls: .asciz "tool_calls"
k_index: .asciz "index"
k_id: .asciz "id"
k_function: .asciz "function"
k_name: .asciz "name"
k_arguments: .asciz "arguments"
.bss
.p2align 3
s_finish_reason: .zero 16
s_callback: .zero 8
s_line_len: .zero 8
s_event_len: .zero 8
s_content_len: .zero 8
s_call_count: .zero 8
s_done: .zero 8
s_finished: .zero 8
s_error: .zero 8
s_usage_prompt: .zero 8
s_usage_completion: .zero 8
s_usage_total: .zero 8
s_usage_present: .zero 8
.p2align 4
s_line: .zero 65536
s_event: .zero 65536
s_content: .zero MAX_JSON
s_call_table: .zero CALL_SIZE*8
s_tokens: .zero MAX_TOKENS*TOKEN_SIZE
.section .note.GNU-stack,"",@progbits
