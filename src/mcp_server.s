.include "abi.inc"
.text
.global mcp_server_run
# Native read-only workspace MCP server. stdout is JSON-RPC only.
# All file effects use the same compiled tool handlers as the main client.
mcp_server_run:
    push rbx
    push r12
    push r13
    push r14
    push r15
    xor ebx,ebx
.L_srv_read:
    xor eax,eax
    xor edi,edi
    lea rsi,[rip+srv_read_buffer]
    mov edx,4096
    syscall
    cmp rax,-4
    je .L_srv_read
    test rax,rax
    js .L_srv_fail
    jz .L_srv_eof
    mov r12,rax
    xor r13d,r13d
.L_srv_scan:
    cmp r13,r12
    jae .L_srv_read
    lea rdx,[rip+srv_read_buffer]
    mov al,[rdx+r13]
    inc r13
    cmp al,10
    je .L_srv_line
    cmp rbx,MAX_JSON-1
    jae .L_srv_fail
    lea rdx,[rip+srv_line]
    mov [rdx+rbx],al
    inc rbx
    jmp .L_srv_scan
.L_srv_line:
    test rbx,rbx
    jz .L_srv_scan
    mov rdi,rbx
    call .L_srv_handle
    test rax,rax
    js .L_srv_fail
    xor ebx,ebx
    jmp .L_srv_scan
.L_srv_eof:
    test rbx,rbx
    jz .L_srv_ok
    mov rdi,rbx
    call .L_srv_handle
    test rax,rax
    js .L_srv_fail
.L_srv_ok:
    xor eax,eax
    jmp .L_srv_return
.L_srv_fail:
    mov eax,1
.L_srv_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.L_srv_find:
    mov rdx,rdi
    mov rcx,rsi
    mov rdi,[rip+srv_source]
    lea rsi,[rip+srv_tokens]
    jmp json_find
# token index,destination,capacity ->decoded length; reserveNUL.
.L_srv_string:
    push rbx
    push r12
    push r13
    mov r12,rsi
    mov r13,rdx
    test rdi,rdi
    js .L_srv_string_bad
    shl rdi,5
    lea rbx,[rip+srv_tokens]
    add rbx,rdi
    cmp qword ptr [rbx],JT_STRING
    jne .L_srv_string_bad
    mov rsi,[rbx+T_START]
    add rsi,[rip+srv_source]
    mov rdx,[rbx+T_LEN]
    mov rdi,r12
    lea rcx,[r13-1]
    call json_decode
    test rax,rax
    js .L_srv_string_bad
    mov byte ptr [r12+rax],0
    pop r13
    pop r12
    pop rbx
    ret
.L_srv_string_bad:
    mov rax,-1
    pop r13
    pop r12
    pop rbx
    ret
.L_srv_cat:
    lea rdi,[rip+srv_builder]
    jmp qx_cat
.L_srv_quote:
    lea rdi,[rip+srv_builder]
    jmp qx_quote_cat
.L_srv_handle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rsi,rdi
    lea rdi,[rip+srv_line]
    mov [rip+srv_source],rdi
    lea rdx,[rip+srv_tokens]
    mov ecx,MAX_TOKENS
    call json_parse
    test rax,rax
    js .L_srv_handle_bad
    cmp qword ptr [rip+srv_tokens],JT_OBJECT
    jne .L_srv_handle_bad
    xor edi,edi
    lea rsi,[rip+srv_id_key]
    call .L_srv_find
    test rax,rax
    js .L_srv_notification
    mov r12,rax
    mov qword ptr [rip+srv_builder+16],0
    lea rsi,[rip+srv_header]
    mov edx,OFFSET FLAT:srv_header_len
    call .L_srv_cat
    test rax,rax
    js .L_srv_handle_bad
    mov rdi,r12
    shl rdi,5
    lea rax,[rip+srv_tokens]
    add rax,rdi
    cmp qword ptr [rax],JT_STRING
    jne .L_srv_raw_id
    mov rdi,r12
    lea rsi,[rip+srv_id]
    mov edx,256
    call .L_srv_string
    test rax,rax
    js .L_srv_handle_bad
    lea rsi,[rip+srv_id]
    mov rdx,rax
    call .L_srv_quote
    jmp .L_srv_method
.L_srv_raw_id:
    cmp qword ptr [rax],JT_NUMBER
    je .L_srv_copy_id
    cmp qword ptr [rax],JT_NULL
    jne .L_srv_handle_bad
.L_srv_copy_id:
    mov rsi,[rax+T_START]
    add rsi,[rip+srv_source]
    mov rdx,[rax+T_LEN]
    cmp rdx,32
    ja .L_srv_handle_bad
    call .L_srv_cat
.L_srv_method:
    xor edi,edi
    lea rsi,[rip+srv_version_key]
    call .L_srv_find
    mov rdi,rax
    lea rsi,[rip+srv_method]
    mov edx,64
    call .L_srv_string
    test rax,rax
    js .L_srv_invalid
    lea rdi,[rip+srv_method]
    lea rsi,[rip+srv_version]
    call qx_streq
    test eax,eax
    jz .L_srv_invalid
    xor edi,edi
    lea rsi,[rip+srv_method_key]
    call .L_srv_find
    mov rdi,rax
    lea rsi,[rip+srv_method]
    mov edx,64
    call .L_srv_string
    test rax,rax
    js .L_srv_invalid
    lea r14,[rip+srv_routes]
.L_srv_route:
    mov rsi,[r14]
    test rsi,rsi
    jz .L_srv_unknown
    lea rdi,[rip+srv_method]
    call qx_streq
    test eax,eax
    jnz .L_srv_dispatch
    add r14,16
    jmp .L_srv_route
.L_srv_dispatch:
    jmp qword ptr [r14+8]
.L_srv_initialize:
    lea rsi,[rip+srv_initialize_json]
    mov edx,OFFSET FLAT:srv_initialize_json_len
    call .L_srv_cat
    jmp .L_srv_send
.L_srv_ping:
    lea rsi,[rip+srv_ping_json]
    mov edx,OFFSET FLAT:srv_ping_json_len
    call .L_srv_cat
    jmp .L_srv_send
.L_srv_tools_list:
    lea rsi,[rip+srv_tools_open]
    mov edx,OFFSET FLAT:srv_tools_open_len
    call .L_srv_cat
    # Canonical tool metadata is shared with child agents, not independently redefined.
    lea rdi,[rip+srv_readonly_source]
    mov [rip+srv_source],rdi
    mov esi,OFFSET FLAT:srv_readonly_source_len
    lea rdx,[rip+srv_tokens]
    mov ecx,MAX_TOKENS
    call json_parse
    test rax,rax
    js .L_srv_handle_bad
    mov r13d,1
    xor r15d,r15d
.L_srv_definition:
    cmp r15d,2
    jae .L_srv_definition_done
    test r15d,r15d
    jz .L_srv_definition_first
    lea rsi,[rip+srv_comma]
    mov edx,1
    call .L_srv_cat
.L_srv_definition_first:
    mov rdi,r13
    lea rsi,[rip+srv_function_key]
    call .L_srv_find
    test rax,rax
    js .L_srv_handle_bad
    mov r12,rax
    lea rsi,[rip+srv_name_open]
    mov edx,OFFSET FLAT:srv_name_open_len
    call .L_srv_cat
    mov rdi,r12
    lea rsi,[rip+srv_name_key]
    call .L_srv_find
    mov rdi,rax
    lea rsi,[rip+srv_temp]
    mov edx,4096
    call .L_srv_string
    test rax,rax
    js .L_srv_handle_bad
    lea rsi,[rip+srv_temp]
    mov rdx,rax
    call .L_srv_quote
    lea rsi,[rip+srv_description_open]
    mov edx,OFFSET FLAT:srv_description_open_len
    call .L_srv_cat
    mov rdi,r12
    lea rsi,[rip+srv_description_key]
    call .L_srv_find
    mov rdi,rax
    lea rsi,[rip+srv_temp]
    mov edx,4096
    call .L_srv_string
    test rax,rax
    js .L_srv_handle_bad
    lea rsi,[rip+srv_temp]
    mov rdx,rax
    call .L_srv_quote
    lea rsi,[rip+srv_schema_open]
    mov edx,OFFSET FLAT:srv_schema_open_len
    call .L_srv_cat
    mov rdi,r12
    lea rsi,[rip+srv_parameters_key]
    call .L_srv_find
    test rax,rax
    js .L_srv_handle_bad
    shl rax,5
    lea rdx,[rip+srv_tokens]
    add rdx,rax
    mov rsi,[rdx+T_START]
    add rsi,[rip+srv_source]
    mov rdx,[rdx+T_LEN]
    call .L_srv_cat
    lea rsi,[rip+srv_object_end]
    mov edx,1
    call .L_srv_cat
    mov rax,r13
    shl rax,5
    lea rdx,[rip+srv_tokens]
    mov r13,[rdx+rax+T_END]
    inc r15d
    jmp .L_srv_definition
.L_srv_definition_done:
    lea rsi,[rip+srv_tools_end]
    mov edx,OFFSET FLAT:srv_tools_end_len
    call .L_srv_cat
    jmp .L_srv_send
.L_srv_tools_call:
    xor edi,edi
    lea rsi,[rip+srv_params_key]
    call .L_srv_find
    test rax,rax
    js .L_srv_invalid
    mov r12,rax
    mov rdi,r12
    lea rsi,[rip+srv_name_key]
    call .L_srv_find
    mov rdi,rax
    lea rsi,[rip+srv_temp]
    mov edx,4096
    call .L_srv_string
    test rax,rax
    js .L_srv_invalid
    lea rdi,[rip+srv_temp]
    lea rsi,[rip+srv_read_name]
    call qx_streq
    test eax,eax
    jnz .L_srv_allowed_tool
    lea rdi,[rip+srv_temp]
    lea rsi,[rip+srv_list_name]
    call qx_streq
    test eax,eax
    jz .L_srv_invalid
.L_srv_allowed_tool:
    mov rdi,r12
    lea rsi,[rip+srv_arguments_key]
    call .L_srv_find
    test rax,rax
    js .L_srv_invalid
    shl rax,5
    lea rdx,[rip+srv_tokens]
    add rdx,rax
    cmp qword ptr [rdx],JT_OBJECT
    jne .L_srv_invalid
    mov rsi,[rdx+T_START]
    add rsi,[rip+srv_source]
    mov rdx,[rdx+T_LEN]
    lea rdi,[rip+srv_temp]
    lea rcx,[rip+srv_result]
    mov r8d,65537
    call tool_execute
    test rax,rax
    js .L_srv_invalid
    mov r12,rax
    lea rsi,[rip+srv_content_open]
    mov edx,OFFSET FLAT:srv_content_open_len
    call .L_srv_cat
    lea rsi,[rip+srv_result]
    mov rdx,r12
    call .L_srv_quote
    lea rsi,[rip+srv_content_end]
    mov edx,OFFSET FLAT:srv_content_end_len
    call .L_srv_cat
    jmp .L_srv_send
.L_srv_invalid:
    lea rsi,[rip+srv_invalid_json]
    mov edx,OFFSET FLAT:srv_invalid_json_len
    call .L_srv_cat
    jmp .L_srv_send
.L_srv_unknown:
    lea rsi,[rip+srv_unknown_json]
    mov edx,OFFSET FLAT:srv_unknown_json_len
    call .L_srv_cat
.L_srv_send:
    test rax,rax
    js .L_srv_handle_bad
    lea rsi,[rip+srv_response_end]
    mov edx,OFFSET FLAT:srv_response_end_len
    call .L_srv_cat
    test rax,rax
    js .L_srv_handle_bad
    mov edi,1
    lea rsi,[rip+srv_output]
    mov rdx,[rip+srv_builder+16]
    call qx_write_all
    test rax,rax
    js .L_srv_handle_bad
.L_srv_notification:
    xor eax,eax
    jmp .L_srv_handle_return
.L_srv_handle_bad:
    mov rax,-1
.L_srv_handle_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.section .rodata
srv_id_key: .asciz "id"
srv_version_key: .asciz "jsonrpc"
srv_method_key: .asciz "method"
srv_params_key: .asciz "params"
srv_function_key: .asciz "function"
srv_name_key: .asciz "name"
srv_description_key: .asciz "description"
srv_parameters_key: .asciz "parameters"
srv_arguments_key: .asciz "arguments"
srv_version: .asciz "2.0"
srv_read_name: .asciz "read_file"
srv_list_name: .asciz "list_directory"
srv_method_initialize: .asciz "initialize"
srv_method_ping: .asciz "ping"
srv_method_list: .asciz "tools/list"
srv_method_call: .asciz "tools/call"
.p2align 3
srv_routes: .quad srv_method_initialize,.L_srv_initialize,srv_method_ping,.L_srv_ping,srv_method_list,.L_srv_tools_list,srv_method_call,.L_srv_tools_call,0,0
srv_header: .ascii "{\"jsonrpc\":\"2.0\",\"id\":"
.equ srv_header_len,.-srv_header
srv_initialize_json: .ascii ",\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"qwen-x86-workspace\",\"version\":\"0.1.0\"}}"
.equ srv_initialize_json_len,.-srv_initialize_json
srv_ping_json: .ascii ",\"result\":{}"
.equ srv_ping_json_len,.-srv_ping_json
srv_tools_open: .ascii ",\"result\":{\"tools\":["
.equ srv_tools_open_len,.-srv_tools_open
srv_tools_end: .ascii "]}"
.equ srv_tools_end_len,.-srv_tools_end
srv_name_open: .ascii "{\"name\":"
.equ srv_name_open_len,.-srv_name_open
srv_description_open: .ascii ",\"description\":"
.equ srv_description_open_len,.-srv_description_open
srv_schema_open: .ascii ",\"inputSchema\":"
.equ srv_schema_open_len,.-srv_schema_open
srv_content_open: .ascii ",\"result\":{\"content\":[{\"type\":\"text\",\"text\":"
.equ srv_content_open_len,.-srv_content_open
srv_content_end: .ascii "}],\"isError\":false}"
.equ srv_content_end_len,.-srv_content_end
srv_invalid_json: .ascii ",\"error\":{\"code\":-32602,\"message\":\"Invalid method parameters or unsupported tool\"}"
.equ srv_invalid_json_len,.-srv_invalid_json
srv_unknown_json: .ascii ",\"error\":{\"code\":-32601,\"message\":\"Method not found\"}"
.equ srv_unknown_json_len,.-srv_unknown_json
srv_response_end: .ascii "}\n"
.equ srv_response_end_len,.-srv_response_end
srv_object_end: .ascii "}"
srv_comma: .ascii ","
srv_readonly_source: .incbin "src/tools_readonly.json"
.equ srv_readonly_source_len,.-srv_readonly_source
.data
.p2align 3
srv_builder: .quad srv_output,MAX_JSON,0
.bss
.p2align 3
srv_source: .zero 8
.p2align 4
srv_read_buffer: .zero 4096
srv_line: .zero MAX_JSON
srv_output: .zero MAX_JSON
srv_tokens: .zero MAX_TOKENS*TOKEN_SIZE
srv_id: .zero 256
srv_method: .zero 64
srv_temp: .zero 4096
srv_result: .zero 65537
.section .note.GNU-stack,"",@progbits
