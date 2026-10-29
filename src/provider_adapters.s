# Native provider wire adapters. Production uses only our JSON/SSE/HTTP ASM.
# Anthropic Messages protocol ->common native OpenAI chat representation.
.include "abi.inc"
.equ A_MAX,4194304
.equ A_EVENT_MAX,1048576
.section .bss
.a_src: .skip 8
.a_tokens: .skip 8
.a_out: .skip 8
.a_cap: .skip 8
.a_len: .skip 8
.a_err: .skip 8
.a_protocol: .skip 8
.a_request_tokens: .skip 65536*32
.a_stream_tokens: .skip 8192*32
.a_arg_tokens: .skip 8192*32
.a_arguments: .skip 65536
.a_name: .skip 4096
.a_line: .skip A_EVENT_MAX
.a_line_len: .skip 8
.a_data: .skip A_EVENT_MAX
.a_data_len: .skip 8
.a_tool_map: .skip 64*8
.a_tool_count: .skip 8
.a_stream_done: .skip 8
.a_error_text: .skip 4096
.a_input_len: .skip 8
.a_message: .skip 8
.a_call: .skip 8
.a_content_count: .skip 8
.a_event: .skip 8
.a_delta: .skip 8
.a_block: .skip 8
.a_index: .skip 8
.a_arg_len: .skip 8
.text
.globl provider_translate_request,provider_translate_stream,provider_stream_reset,provider_stream_error
.macro AL name
 lea rdi,[rip+\name]
 mov esi,OFFSET FLAT:\name\()_len
 call .A_put
.endm
# protocol name ->0 openai/qwen-oauth,1anthropic,-22unsupported.
.A_protocol_kind:
 push rbx
 mov rbx,rdi
 lea rsi,[rip+.a_anthropic]
 call .A_equal
 test eax,eax
 jnz .A_kind_anthropic
 mov rdi,rbx
 lea rsi,[rip+.o_protocol]
 call .A_equal
 test eax,eax
 jnz .A_kind_responses
 mov rdi,rbx
 lea rsi,[rip+.g_protocol]
 call .A_equal
 test eax,eax
 jnz .A_kind_gemini
 mov rdi,rbx
 lea rsi,[rip+.a_openai]
 call .A_equal
 test eax,eax
 jnz .A_kind_openai
 mov rdi,rbx
 lea rsi,[rip+.a_oauth]
 call .A_equal
 test eax,eax
 jnz .A_kind_openai
 mov rax,-22
 jmp .A_kind_return
.A_kind_responses:
 mov eax,3
 jmp .A_kind_return
.A_kind_gemini:
 mov eax,2
 jmp .A_kind_return
.A_kind_anthropic:
 mov eax,1
 jmp .A_kind_return
.A_kind_openai:
 xor eax,eax
.A_kind_return:
 pop rbx
 ret
provider_stream_error:
 cmp byte ptr [rip+.a_error_text],0
 je .A_error_generic
 lea rax,[rip+.a_error_text]
 ret
.A_error_generic:
 lea rax,[rip+.a_invalid_error]
 ret
provider_stream_reset:
 sub rsp,8
 call .A_protocol_kind
 test rax,rax
 js .A_reset_return
 mov [rip+.a_protocol],rax
 mov qword ptr [rip+.a_line_len],0
 mov qword ptr [rip+.a_data_len],0
 mov qword ptr [rip+.a_tool_count],0
 mov qword ptr [rip+.m_meta_count],0
 mov qword ptr [rip+.m_meta_length],0
 mov qword ptr [rip+.g_generated_count],0
 mov qword ptr [rip+.a_stream_done],0
 mov byte ptr [rip+.a_error_text],0
 lea rdi,[rip+.a_tool_map]
 mov rax,-1
 mov ecx,64
 rep stosq
 xor eax,eax
.A_reset_return:
 add rsp,8
 ret
# protocolZ,OpenAIJSON,length,out,cap ->native-provider JSON length/-error.
provider_translate_request:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov r12,rsi
 mov r13,rdx
 mov [rip+.a_src],rsi
 mov [rip+.a_out],rcx
 mov [rip+.a_cap],r8
 mov qword ptr [rip+.a_len],0
 mov qword ptr [rip+.a_err],0
 mov byte ptr [rip+.a_error_text],0
 cmp r13,A_MAX
 ja .A_request_bad
 call .A_protocol_kind
 test rax,rax
 js .A_request_bad
 cmp eax,3
 je .O_request
 cmp eax,2
 je .G_request
 test eax,eax
 jnz .A_request_anthropic
 mov rdi,r12
 mov rsi,r13
 call .A_put
 jmp .A_request_finish
.A_request_anthropic:
 lea rax,[rip+.a_request_tokens]
 mov [rip+.a_tokens],rax
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 mov ecx,65536
 call json_parse
 test rax,rax
 js .A_request_bad
 cmp qword ptr [rip+.a_request_tokens],JT_OBJECT
 jne .A_request_bad
 AL .a_req_start
 xor edx,edx
 lea rcx,[rip+.a_model_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_req_stream
 xor edx,edx
 lea rcx,[rip+.a_max_key]
 call .A_find
 test rax,rax
 jns .A_request_max
 xor edx,edx
 lea rcx,[rip+.a_max_completion_key]
 call .A_find
 test rax,rax
 jns .A_request_max
 AL .a_default_max
 jmp .A_request_system
.A_request_max:
 call .A_token
 cmp qword ptr [rdx],JT_NUMBER
 jne .A_request_bad
 call .A_raw
.A_request_system:
 # Anthropic system content is separate from its user/assistant messages.
 AL .a_system_start
 call .A_messages_array
 test rax,rax
 js .A_request_bad
 mov r12,rax
 mov r13,rdx
 xor r14d,r14d
.A_system_loop:
 cmp r12,r13
 jae .A_system_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 mov rdi,r12
 call .A_message_role
 cmp eax,1
 je .A_system_text
 cmp eax,5
 jne .A_system_next
.A_system_text:
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 mov [rsp],rax
 test r14,r14
 jz .A_system_no_comma
 AL .a_comma
.A_system_no_comma:
 AL .a_text_start
 mov rax,[rsp]
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_object_end
 inc r14
.A_system_next:
 mov r12,r15
 jmp .A_system_loop
.A_system_done:
 AL .a_messages_start
 call .A_messages_array
 mov r12,rax
 mov r13,rdx
 xor r14d,r14d
.A_messages_loop:
 cmp r12,r13
 jae .A_messages_done
 mov [rip+.a_message],r12
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 mov rdi,r12
 call .A_message_role
 cmp eax,1
 je .A_messages_next
 cmp eax,5
 je .A_messages_next
 cmp eax,2
 je .A_user_message
 cmp eax,3
 je .A_assistant_message
 cmp eax,4
 je .A_tool_message
 jmp .A_request_bad
.A_user_message:
 call .A_message_separator
 AL .a_user_start
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_content_blocks
 test rax,rax
 js .A_request_bad
 AL .a_array_object_end
 jmp .A_messages_next
.A_assistant_message:
 call .A_message_separator
 AL .a_assistant_start
 mov qword ptr [rip+.a_content_count],0
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_assistant_tools
 mov [rsp],rax
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 jne .A_assistant_tools
 cmp qword ptr [rdx+T_LEN],0
 je .A_assistant_tools
 AL .a_text_start
 mov rax,[rsp]
 call .A_string
 AL .a_object_end
 inc qword ptr [rip+.a_content_count]
.A_assistant_tools:
 mov rdx,r12
 lea rcx,[rip+.a_calls_key]
 call .A_find
 test rax,rax
 js .A_assistant_end
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_request_bad
 mov [rsp+8],r12
 mov [rsp+16],r13
 mov r13,[rdx+T_END]
 inc rax
 mov r12,rax
.A_calls_loop:
 cmp r12,r13
 jae .A_calls_done
 mov rax,r12
 call .A_token
 mov rbx,[rdx+T_END]
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_request_bad
 cmp qword ptr [rip+.a_content_count],0
 je .A_call_no_comma
 AL .a_comma
.A_call_no_comma:
 AL .a_tool_use_start
 mov rdx,r12
 lea rcx,[rip+.a_id_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_name_field
 mov rdx,r12
 lea rcx,[rip+.a_function_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 mov rbp,rax
 mov rdx,rax
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_input_field
 mov rdx,rbp
 lea rcx,[rip+.a_arguments_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 lea rdi,[rip+.a_arguments]
 mov ecx,65536
 call .A_decode
 test rax,rax
 js .A_request_bad
 mov [rip+.a_arg_len],rax
 lea rdi,[rip+.a_arguments]
 mov rsi,rax
 lea rdx,[rip+.a_arg_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .A_request_bad
 cmp qword ptr [rip+.a_arg_tokens],JT_OBJECT
 jne .A_request_bad
 lea rdi,[rip+.a_arguments]
 mov rsi,[rip+.a_arg_len]
 call .A_put
 AL .a_object_end
 inc qword ptr [rip+.a_content_count]
 mov r12,rbx
 jmp .A_calls_loop
.A_calls_done:
 mov r12,[rsp+8]
 mov r13,[rsp+16]
.A_assistant_end:
 AL .a_array_object_end
 jmp .A_messages_next
.A_tool_message:
 call .A_message_separator
 AL .a_user_start
.A_tool_result_group:
 AL .a_tool_result_start
 mov rdx,r12
 lea rcx,[rip+.a_call_id_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_content_field
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_object_end
 cmp r15,r13
 jae .A_tool_group_done
 mov rdi,r15
 call .A_message_role
 cmp eax,4
 jne .A_tool_group_done
 mov r12,r15
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 AL .a_comma
 jmp .A_tool_result_group
.A_tool_group_done:
 AL .a_array_object_end
.A_messages_next:
 mov r12,r15
 jmp .A_messages_loop
.A_messages_done:
 AL .a_array_end
 xor edx,edx
 lea rcx,[rip+.a_tools_key]
 call .A_find
 test rax,rax
 js .A_request_options
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_request_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
 cmp r12,r13
 jae .A_request_options
 AL .a_tools_start
 xor r14d,r14d
.A_tools_loop:
 cmp r12,r13
 jae .A_tools_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 mov rdx,r12
 lea rcx,[rip+.a_function_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 mov rbp,rax
 test r14,r14
 jz .A_tool_def_no_comma
 AL .a_comma
.A_tool_def_no_comma:
 AL .a_def_start
 mov rdx,rbp
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 mov rdx,rbp
 lea rcx,[rip+.a_description_key]
 call .A_find
 test rax,rax
 js .A_tool_schema
 mov [rsp],rax
 AL .a_description_field
 mov rax,[rsp]
 call .A_string
 test rax,rax
 js .A_request_bad
.A_tool_schema:
 AL .a_schema_field
 mov rdx,rbp
 lea rcx,[rip+.a_parameters_key]
 call .A_find
 test rax,rax
 js .A_empty_schema
 call .A_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_request_bad
 call .A_raw
 jmp .A_schema_done
.A_empty_schema:
 AL .a_empty_object
.A_schema_done:
 AL .a_object_end
 inc r14
 mov r12,r15
 jmp .A_tools_loop
.A_tools_done:
 AL .a_array_end
.A_request_options:
 xor edx,edx
 lea rcx,[rip+.a_temperature_key]
 call .A_find
 test rax,rax
 js .A_option_top_p
 mov [rsp],rax
 AL .a_temperature_field
 mov rax,[rsp]
 call .A_raw
.A_option_top_p:
 xor edx,edx
 lea rcx,[rip+.a_top_p_key]
 call .A_find
 test rax,rax
 js .A_request_close
 mov [rsp],rax
 AL .a_top_p_field
 mov rax,[rsp]
 call .A_raw
.A_request_close:
 AL .a_object_end
 jmp .A_request_finish
.A_request_bad:
 mov qword ptr [rip+.a_err],-22
.A_request_finish:
 mov rax,[rip+.a_err]
 test rax,rax
 jnz .A_request_return
 mov rax,[rip+.a_len]
.A_request_return:
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.A_message_separator:
 test r14,r14
 jz .A_separator_first
 AL .a_comma
.A_separator_first:
 inc r14
 ret
.A_messages_array:
 xor edx,edx
 lea rcx,[rip+.a_messages_key]
 call .A_find
 test rax,rax
 js .A_messages_bad
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_messages_bad
 mov rdx,[rdx+T_END]
 inc rax
 ret
.A_messages_bad:
 mov rax,-22
 ret
# Message token ->role enum1system2user3assistant4tool5developer,0invalid.
.A_message_role:
 sub rsp,8
 mov rdx,rdi
 lea rcx,[rip+.a_role_key]
 call .A_find
 test rax,rax
 js .A_role_bad
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .A_role_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea r8,[rip+.a_roles]
 mov r9d,1
.A_role_loop:
 mov rsi,[r8]
 add rsi,r8
 lea rdi,[rip+.a_name]
 call .A_equal
 test eax,eax
 jnz .A_role_found
 add r8,8
 inc r9
 cmp r9,6
 jb .A_role_loop
.A_role_bad:
 xor eax,eax
 jmp .A_role_return
.A_role_found:
 mov eax,r9d
.A_role_return:
 add rsp,8
 ret
.A_find:
 mov rdi,[rip+.a_src]
 mov rsi,[rip+.a_tokens]
 jmp json_find
.A_token:
 shl rax,5
 mov rdx,[rip+.a_tokens]
 add rdx,rax
 shr rax,5
 ret
# Emit exactly one valid JSON token including string quote delimiters.
.A_raw:
 call .A_token
 mov rdi,[rip+.a_src]
 add rdi,[rdx+T_START]
 mov rsi,[rdx+T_LEN]
 cmp qword ptr [rdx],JT_STRING
 jne .A_put
 dec rdi
 add rsi,2
 jmp .A_put
.A_string:
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 jne .A_string_bad
 call .A_raw
 xor eax,eax
 ret
.A_string_bad:
 mov rax,-22
 ret
# Tokenindex,dst,cap ->decodedlength, no automatic NUL.
.A_decode:
 push rdi
 push rcx
 sub rsp,8
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 jne .A_decode_bad
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 mov rcx,[rsp+8]
 call json_decode
 jmp .A_decode_done
.A_decode_bad:
 mov rax,-22
.A_decode_done:
 add rsp,24
 ret
.A_equal:
 xor ecx,ecx
.A_equal_loop:
 mov al,[rdi+rcx]
 cmp al,[rsi+rcx]
 jne .A_unequal
 inc rcx
 test al,al
 jnz .A_equal_loop
 mov eax,1
 ret
.A_unequal:
 xor eax,eax
 ret
.A_put:
 cmp qword ptr [rip+.a_err],0
 jne .A_put_done
 mov rax,[rip+.a_len]
 add rax,rsi
 jc .A_put_cap
 cmp rax,[rip+.a_cap]
 ja .A_put_cap
 mov rdx,[rip+.a_out]
 test rdx,rdx
 jz .A_put_bad
 mov rcx,rsi
 mov rsi,rdi
 mov rdi,rdx
 add rdi,[rip+.a_len]
 rep movsb
 mov [rip+.a_len],rax
.A_put_done:
 ret
.A_put_cap:
 mov qword ptr [rip+.a_err],-28
 ret
.A_put_bad:
 mov qword ptr [rip+.a_err],-22
 ret
# protocolZ,HTTPbodyChunk,length,out,cap ->complete common SSE bytes/-error.
# State is private to process. Reset at the start of every HTTP response.
provider_translate_stream:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rsi
 mov r13,rdx
 mov [rip+.a_out],rcx
 mov [rip+.a_cap],r8
 mov qword ptr [rip+.a_len],0
 mov qword ptr [rip+.a_err],0
 call .A_protocol_kind
 test rax,rax
 js .A_stream_bad
 cmp rax,[rip+.a_protocol]
 jne .A_stream_bad
 test rax,rax
 jnz .A_stream_anthropic
 mov rdi,r12
 mov rsi,r13
 call .A_put
 jmp .A_stream_finish
.A_stream_anthropic:
 xor r14d,r14d
.A_stream_byte:
 cmp r14,r13
 jae .A_stream_finish
 mov al,[r12+r14]
 inc r14
 cmp al,10
 je .A_stream_line
 mov rdx,[rip+.a_line_len]
 cmp rdx,A_EVENT_MAX
 jae .A_stream_cap
 lea rcx,[rip+.a_line]
 mov [rcx+rdx],al
 inc qword ptr [rip+.a_line_len]
 jmp .A_stream_byte
.A_stream_line:
 mov r15,[rip+.a_line_len]
 mov qword ptr [rip+.a_line_len],0
 test r15,r15
 jz .A_stream_event
 lea rbx,[rip+.a_line]
 cmp byte ptr [rbx+r15-1],13
 jne .A_stream_line_plain
 dec r15
.A_stream_line_plain:
 test r15,r15
 jz .A_stream_event
 cmp r15,5
 jb .A_stream_byte
 cmp dword ptr [rbx],0x61746164
 jne .A_stream_byte
 cmp byte ptr [rbx+4],':'
 jne .A_stream_byte
 add rbx,5
 sub r15,5
 test r15,r15
 jz .A_stream_byte
 cmp byte ptr [rbx],' '
 jne .A_stream_data_ready
 inc rbx
 dec r15
.A_stream_data_ready:
 mov rax,[rip+.a_data_len]
 test rax,rax
 jz .A_stream_data_first
 cmp rax,A_EVENT_MAX
 jae .A_stream_cap
 lea rdi,[rip+.a_data]
 mov byte ptr [rdi+rax],10
 inc rax
.A_stream_data_first:
 lea rdx,[rax+r15]
 cmp rdx,A_EVENT_MAX
 ja .A_stream_cap
 mov [rip+.a_data_len],rdx
 lea rdi,[rip+.a_data]
 add rdi,rax
 mov rsi,rbx
 mov rcx,r15
 rep movsb
 jmp .A_stream_byte
.A_stream_event:
 cmp qword ptr [rip+.a_data_len],0
 je .A_stream_byte
 cmp qword ptr [rip+.a_protocol],3
 je .A_dispatch_responses
 cmp qword ptr [rip+.a_protocol],2
 je .A_dispatch_gemini
 call .A_anthropic_event
 jmp .A_event_dispatched
.A_dispatch_responses:
 call .O_event
 jmp .A_event_dispatched
.A_dispatch_gemini:
 call .G_event
.A_event_dispatched:
 mov qword ptr [rip+.a_data_len],0
 cmp qword ptr [rip+.a_err],0
 jne .A_stream_finish
 jmp .A_stream_byte
.A_stream_cap:
 mov qword ptr [rip+.a_err],-28
 jmp .A_stream_finish
.A_stream_bad:
 mov qword ptr [rip+.a_err],-22
.A_stream_finish:
 mov rax,[rip+.a_err]
 test rax,rax
 jnz .A_stream_return
 mov rax,[rip+.a_len]
.A_stream_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.A_anthropic_event:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 cmp qword ptr [rip+.a_stream_done],0
 jne .A_event_return
 lea rdi,[rip+.a_data]
 mov rsi,[rip+.a_data_len]
 mov [rip+.a_src],rdi
 lea rdx,[rip+.a_stream_tokens]
 mov [rip+.a_tokens],rdx
 mov ecx,8192
 call json_parse
 test rax,rax
 js .A_event_bad
 cmp qword ptr [rip+.a_stream_tokens],JT_OBJECT
 jne .A_event_bad
 xor edx,edx
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov ecx,127
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_block_start_type]
 call .A_equal
 test eax,eax
 jnz .A_event_block_start
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_block_delta_type]
 call .A_equal
 test eax,eax
 jnz .A_event_block_delta
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_message_stop_type]
 call .A_equal
 test eax,eax
 jnz .A_event_stop
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_message_delta_type]
 call .A_equal
 test eax,eax
 jnz .A_event_message_delta
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_error_type]
 call .A_equal
 test eax,eax
 jnz .A_event_error
 jmp .A_event_return
.A_event_block_start:
 call .A_block_index
 test rax,rax
 js .A_event_bad
 mov r12,rax
 xor edx,edx
 lea rcx,[rip+.a_block_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov r13,rax
 mov rdx,rax
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov ecx,127
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_tool_use_type]
 call .A_equal
 test eax,eax
 jnz .A_event_tool_start
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_text_type]
 call .A_equal
 test eax,eax
 jz .A_event_return
 mov rdx,r13
 lea rcx,[rip+.a_text_key]
 call .A_find
 test rax,rax
 js .A_event_return
 jmp .A_event_text
.A_event_tool_start:
 mov r14,[rip+.a_tool_count]
 cmp r14,64
 jae .A_event_bad
 lea rax,[rip+.a_tool_map]
 cmp qword ptr [rax+r12*8],-1
 jne .A_event_bad
 mov [rax+r12*8],r14
 inc qword ptr [rip+.a_tool_count]
 AL .a_sse_tool_start
 mov rdi,r14
 call .A_emit_number
 AL .a_sse_tool_id
 mov rdx,r13
 lea rcx,[rip+.a_id_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .a_sse_function_name
 mov rdx,r13
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .a_sse_empty_arguments
 AL .a_sse_tool_end
 # Nonempty initial input is legal. Re-encode it as arguments string.
 mov rdx,r13
 lea rcx,[rip+.a_input_key]
 call .A_find
 test rax,rax
 js .A_event_return
 call .A_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_event_bad
 cmp qword ptr [rdx+T_END],0
 je .A_event_return
 mov rax,rdx
 sub rax,[rip+.a_tokens]
 shr rax,5
 inc rax
 cmp rax,[rdx+T_END]
 jae .A_event_return
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 lea rdi,[rip+.a_arguments]
 mov ecx,65536
 call json_quote
 test rax,rax
 js .A_event_bad
 mov r15,rax
 AL .a_sse_tool_start
 mov rdi,r14
 call .A_emit_number
 AL .a_sse_arguments_start
 lea rdi,[rip+.a_arguments]
 mov rsi,r15
 call .A_put
 AL .a_sse_tool_end
 jmp .A_event_return
.A_event_block_delta:
 call .A_block_index
 test rax,rax
 js .A_event_bad
 mov r12,rax
 xor edx,edx
 lea rcx,[rip+.a_delta_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov r13,rax
 mov rdx,rax
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov ecx,127
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_text_delta_type]
 call .A_equal
 test eax,eax
 jnz .A_event_delta_text
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_input_delta_type]
 call .A_equal
 test eax,eax
 jz .A_event_return
 lea rdx,[rip+.a_tool_map]
 mov r14,[rdx+r12*8]
 cmp r14,64
 jae .A_event_bad
 mov rdx,r13
 lea rcx,[rip+.a_partial_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov r15,rax
 AL .a_sse_tool_start
 mov rdi,r14
 call .A_emit_number
 AL .a_sse_arguments_start
 mov rax,r15
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .a_sse_tool_end
 jmp .A_event_return
.A_event_delta_text:
 mov rdx,r13
 lea rcx,[rip+.a_text_key]
 call .A_find
 test rax,rax
 js .A_event_bad
.A_event_text:
 mov r15,rax
 AL .a_sse_text_start
 mov rax,r15
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .a_sse_text_end
 jmp .A_event_return
.A_event_message_delta:
 xor edx,edx
 lea rcx,[rip+.a_delta_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov rdx,rax
 lea rcx,[rip+.a_stop_reason_key]
 call .A_find
 test rax,rax
 js .A_event_return
 call .A_token
 cmp qword ptr [rdx],JT_NULL
 je .A_event_return
 lea rdi,[rip+.a_name]
 mov ecx,127
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_tool_use_type]
 call .A_equal
 test eax,eax
 jnz .A_event_finish_tools
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_max_tokens_type]
 call .A_equal
 test eax,eax
 jnz .A_event_finish_length
 AL .a_sse_finish_stop
 jmp .A_event_return
.A_event_finish_tools:
 AL .a_sse_finish_tools
 jmp .A_event_return
.A_event_finish_length:
 AL .a_sse_finish_length
 jmp .A_event_return
.A_event_stop:
 AL .a_sse_done
 mov qword ptr [rip+.a_stream_done],1
 jmp .A_event_return
.A_event_error:
 xor edx,edx
 lea rcx,[rip+.a_error_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov rdx,rax
 lea rcx,[rip+.a_message_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_error_text]
 mov ecx,4095
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_error_text]
 mov byte ptr [rdi+rax],0
.A_event_bad:
 mov qword ptr [rip+.a_err],-22
.A_event_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.A_block_index:
 sub rsp,8
 xor edx,edx
 lea rcx,[rip+.a_index_key]
 call .A_find
 test rax,rax
 js .A_block_index_bad
 call .A_token
 cmp qword ptr [rdx],JT_NUMBER
 jne .A_block_index_bad
 cmp qword ptr [rdx+T_LEN],2
 ja .A_block_index_bad
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 mov rcx,[rdx+T_LEN]
 xor eax,eax
.A_block_index_digit:
 test rcx,rcx
 jz .A_block_index_done
 movzx edi,byte ptr [rsi]
 sub edi,'0'
 cmp edi,9
 ja .A_block_index_bad
 imul eax,eax,10
 add eax,edi
 inc rsi
 dec rcx
 jmp .A_block_index_digit
.A_block_index_done:
 cmp rax,64
 jb .A_block_index_return
.A_block_index_bad:
 mov rax,-22
.A_block_index_return:
 add rsp,8
 ret
.A_emit_number:
 sub rsp,40
 mov rsi,rdi
 mov rdi,rsp
 call qx_uint
 mov rdi,rsp
 mov rsi,rax
 call .A_put
 add rsp,40
 ret
.section .rodata
.a_anthropic: .asciz "anthropic"
.a_openai: .asciz "openai"
.a_oauth: .asciz "qwen-oauth"
.a_invalid_error: .asciz "Malformed or unsupported provider response."
.a_model_key: .asciz "model"
.a_messages_key: .asciz "messages"
.a_role_key: .asciz "role"
.a_content_key: .asciz "content"
.a_calls_key: .asciz "tool_calls"
.a_call_id_key: .asciz "tool_call_id"
.a_id_key: .asciz "id"
.a_function_key: .asciz "function"
.a_name_key: .asciz "name"
.a_arguments_key: .asciz "arguments"
.a_tools_key: .asciz "tools"
.a_description_key: .asciz "description"
.a_parameters_key: .asciz "parameters"
.a_max_key: .asciz "max_tokens"
.a_max_completion_key: .asciz "max_completion_tokens"
.a_temperature_key: .asciz "temperature"
.a_top_p_key: .asciz "top_p"
.a_type_key: .asciz "type"
.a_block_key: .asciz "content_block"
.a_delta_key: .asciz "delta"
.a_input_key: .asciz "input"
.a_text_key: .asciz "text"
.a_partial_key: .asciz "partial_json"
.a_stop_reason_key: .asciz "stop_reason"
.a_error_key: .asciz "error"
.a_message_key: .asciz "message"
.a_index_key: .asciz "index"
.a_block_start_type: .asciz "content_block_start"
.a_block_delta_type: .asciz "content_block_delta"
.a_message_delta_type: .asciz "message_delta"
.a_message_stop_type: .asciz "message_stop"
.a_tool_use_type: .asciz "tool_use"
.a_text_type: .asciz "text"
.a_text_delta_type: .asciz "text_delta"
.a_input_delta_type: .asciz "input_json_delta"
.a_error_type: .asciz "error"
.a_max_tokens_type: .asciz "max_tokens"
.a_req_start: .ascii "{\"model\":"
.equ .a_req_start_len,.-.a_req_start
.a_req_stream: .ascii ",\"stream\":true,\"max_tokens\":"
.equ .a_req_stream_len,.-.a_req_stream
.a_default_max: .ascii "8192"
.equ .a_default_max_len,.-.a_default_max
.a_system_start: .ascii ",\"system\":["
.equ .a_system_start_len,.-.a_system_start
.a_messages_start: .ascii "],\"messages\":["
.equ .a_messages_start_len,.-.a_messages_start
.a_user_start: .ascii "{\"role\":\"user\",\"content\":["
.equ .a_user_start_len,.-.a_user_start
.a_assistant_start: .ascii "{\"role\":\"assistant\",\"content\":["
.equ .a_assistant_start_len,.-.a_assistant_start
.a_text_start: .ascii "{\"type\":\"text\",\"text\":"
.equ .a_text_start_len,.-.a_text_start
.a_tool_use_start: .ascii "{\"type\":\"tool_use\",\"id\":"
.equ .a_tool_use_start_len,.-.a_tool_use_start
.a_name_field: .ascii ",\"name\":"
.equ .a_name_field_len,.-.a_name_field
.a_input_field: .ascii ",\"input\":"
.equ .a_input_field_len,.-.a_input_field
.a_tool_result_start: .ascii "{\"type\":\"tool_result\",\"tool_use_id\":"
.equ .a_tool_result_start_len,.-.a_tool_result_start
.a_content_field: .ascii ",\"content\":"
.equ .a_content_field_len,.-.a_content_field
.a_content_end: .ascii "}]}"
.equ .a_content_end_len,.-.a_content_end
.a_object_end: .ascii "}"
.equ .a_object_end_len,.-.a_object_end
.a_array_object_end: .ascii "]}"
.equ .a_array_object_end_len,.-.a_array_object_end
.a_array_end: .ascii "]"
.equ .a_array_end_len,.-.a_array_end
.a_comma: .ascii ","
.equ .a_comma_len,.-.a_comma
.a_tools_start: .ascii ",\"tools\":["
.equ .a_tools_start_len,.-.a_tools_start
.a_def_start: .ascii "{\"name\":"
.equ .a_def_start_len,.-.a_def_start
.a_description_field: .ascii ",\"description\":"
.equ .a_description_field_len,.-.a_description_field
.a_schema_field: .ascii ",\"input_schema\":"
.equ .a_schema_field_len,.-.a_schema_field
.a_empty_object: .ascii "{}"
.equ .a_empty_object_len,.-.a_empty_object
.a_temperature_field: .ascii ",\"temperature\":"
.equ .a_temperature_field_len,.-.a_temperature_field
.a_top_p_field: .ascii ",\"top_p\":"
.equ .a_top_p_field_len,.-.a_top_p_field
.a_sse_text_start: .ascii "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":"
.equ .a_sse_text_start_len,.-.a_sse_text_start
.a_sse_text_end: .ascii "}}]}\n\n"
.equ .a_sse_text_end_len,.-.a_sse_text_end
.a_sse_tool_start: .ascii "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":"
.equ .a_sse_tool_start_len,.-.a_sse_tool_start
.a_sse_tool_id: .ascii ",\"id\":"
.equ .a_sse_tool_id_len,.-.a_sse_tool_id
.a_sse_function_name: .ascii ",\"type\":\"function\",\"function\":{\"name\":"
.equ .a_sse_function_name_len,.-.a_sse_function_name
.a_sse_empty_arguments: .ascii ",\"arguments\":\"\""
.equ .a_sse_empty_arguments_len,.-.a_sse_empty_arguments
.a_sse_arguments_start: .ascii ",\"function\":{\"arguments\":"
.equ .a_sse_arguments_start_len,.-.a_sse_arguments_start
.a_sse_tool_end: .ascii "}}]}}]}\n\n"
.equ .a_sse_tool_end_len,.-.a_sse_tool_end
.a_sse_finish_stop: .ascii "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
.equ .a_sse_finish_stop_len,.-.a_sse_finish_stop
.a_sse_finish_tools: .ascii "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\n"
.equ .a_sse_finish_tools_len,.-.a_sse_finish_tools
.a_sse_finish_length: .ascii "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"length\"}]}\n\n"
.equ .a_sse_finish_length_len,.-.a_sse_finish_length
.a_sse_done: .ascii "data: [DONE]\n\n"
.equ .a_sse_done_len,.-.a_sse_done
.balign 8
.a_roles:
 .quad .a_role_0-.
 .quad .a_role_1-.
 .quad .a_role_2-.
 .quad .a_role_3-.
 .quad .a_role_4-.
.a_role_0: .asciz "system"
.a_role_1: .asciz "user"
.a_role_2: .asciz "assistant"
.a_role_3: .asciz "tool"
.a_role_4: .asciz "developer"
.section .note.GNU-stack,"",@progbits
.section .bss
.a_image_url: .skip A_MAX+1
.a_image_mime: .skip 64
.text
# OpenAI user content token ->Anthropic content objects, preserving images.
.A_content_blocks:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rax
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 je .A_content_string
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_content_bad
 mov r13,[rdx+T_END]
 inc r12
 xor r14d,r14d
.A_content_loop:
 cmp r12,r13
 jae .A_content_ok
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_content_bad
 test r14,r14
 jz .A_content_first
 AL .a_comma
.A_content_first:
 inc r14
 mov rdx,r12
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .A_content_bad
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .A_content_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_text_type]
 call .A_equal
 test eax,eax
 jnz .A_content_text
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_image_url_key]
 call .A_equal
 test eax,eax
 jz .A_content_bad
 mov rdx,r12
 lea rcx,[rip+.a_image_url_key]
 call .A_find
 test rax,rax
 js .A_content_bad
 call .A_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_content_image_token
 mov rdx,rax
 lea rcx,[rip+.a_url_key]
 call .A_find
 test rax,rax
 js .A_content_bad
.A_content_image_token:
 call .A_image_block
 test rax,rax
 js .A_content_bad
 jmp .A_content_next
.A_content_text:
 AL .a_text_start
 mov rdx,r12
 lea rcx,[rip+.a_text_key]
 call .A_find
 test rax,rax
 js .A_content_bad
 call .A_string
 test rax,rax
 js .A_content_bad
 AL .a_object_end
.A_content_next:
 mov r12,r15
 jmp .A_content_loop
.A_content_string:
 AL .a_text_start
 mov rax,r12
 call .A_string
 test rax,rax
 js .A_content_bad
 AL .a_object_end
.A_content_ok:
 xor eax,eax
 jmp .A_content_return
.A_content_bad:
 mov rax,-22
.A_content_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.A_image_block:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rax
 lea rdi,[rip+.a_image_url]
 mov ecx,A_MAX
 call .A_decode
 test rax,rax
 jle .A_image_bad
 mov r13,rax
 lea rbx,[rip+.a_image_url]
 mov byte ptr [rbx+rax],0
 cmp r13,8
 jb .A_image_bad
 cmp dword ptr [rbx],0x70747468
 jne .A_image_data
 cmp dword ptr [rbx+4],0x2f2f3a73
 jne .A_image_bad
 AL .a_image_url_start
 mov rax,r12
 call .A_string
 AL .a_image_end
 jmp .A_image_ok
.A_image_data:
 cmp dword ptr [rbx],0x61746164
 jne .A_image_bad
 cmp byte ptr [rbx+4],':'
 jne .A_image_bad
 mov r14d,5
.A_image_mime:
 cmp r14,r13
 jae .A_image_bad
 cmp r14,60
 jae .A_image_bad
 cmp byte ptr [rbx+r14],';'
 je .A_image_mime_end
 inc r14
 jmp .A_image_mime
.A_image_mime_end:
 lea rax,[r14+8]
 cmp rax,r13
 jae .A_image_bad
 mov r15,rax
 mov rax,[rbx+r14]
 movabs rdx,0x2c3436657361623b # ;base64,
 cmp rax,rdx
 jne .A_image_bad
 lea rsi,[rbx+5]
 lea rdi,[rip+.a_image_mime]
 lea rcx,[r14-5]
 rep movsb
 mov byte ptr [rdi],0
 lea rdi,[rip+.a_image_mime]
 lea rsi,[rip+.a_mime_png]
 call .A_equal
 test eax,eax
 jnz .A_image_base64
 lea rdi,[rip+.a_image_mime]
 lea rsi,[rip+.a_mime_jpeg]
 call .A_equal
 test eax,eax
 jnz .A_image_base64
 lea rdi,[rip+.a_image_mime]
 lea rsi,[rip+.a_mime_webp]
 call .A_equal
 test eax,eax
 jnz .A_image_base64
 lea rdi,[rip+.a_image_mime]
 lea rsi,[rip+.a_mime_gif]
 call .A_equal
 test eax,eax
 jz .A_image_bad
.A_image_base64:
 mov rbp,r13
 sub rbp,r15
 test rbp,3
 jnz .A_image_bad
 mov rcx,r15
.A_image_base64_byte:
 cmp rcx,r13
 jae .A_image_emit
 mov al,[rbx+rcx]
 cmp al,'A'
 jb .A_image_base64_digit
 cmp al,'Z'
 jbe .A_image_base64_next
 cmp al,'a'
 jb .A_image_base64_digit
 cmp al,'z'
 jbe .A_image_base64_next
.A_image_base64_digit:
 cmp al,'0'
 jb .A_image_base64_special
 cmp al,'9'
 jbe .A_image_base64_next
.A_image_base64_special:
 cmp al,'+'
 je .A_image_base64_next
 cmp al,'/'
 je .A_image_base64_next
 cmp al,'='
 jne .A_image_bad
 lea rax,[r13-2]
 cmp rcx,rax
 jb .A_image_bad
 lea rax,[r13-1]
 cmp rcx,rax
 je .A_image_base64_next
 cmp byte ptr [rbx+rcx+1],'='
 jne .A_image_bad
.A_image_base64_next:
 inc rcx
 jmp .A_image_base64_byte
.A_image_emit:
 AL .a_image_base64_start
 lea rdi,[rip+.a_image_mime]
 mov rsi,r14
 sub rsi,5
 call .A_put
 AL .a_image_data_field
 lea rdi,[rbx+r15]
 mov rsi,rbp
 call .A_put
 AL .a_image_base64_end
.A_image_ok:
 xor eax,eax
 jmp .A_image_return
.A_image_bad:
 mov rax,-22
.A_image_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.section .rodata
.a_image_url_key: .asciz "image_url"
.a_url_key: .asciz "url"
.a_mime_png: .asciz "image/png"
.a_mime_jpeg: .asciz "image/jpeg"
.a_mime_webp: .asciz "image/webp"
.a_mime_gif: .asciz "image/gif"
.a_image_url_start: .ascii "{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":"
.equ .a_image_url_start_len,.-.a_image_url_start
.a_image_base64_start: .ascii "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\""
.equ .a_image_base64_start_len,.-.a_image_base64_start
.a_image_data_field: .ascii "\",\"data\":\""
.equ .a_image_data_field_len,.-.a_image_data_field
.a_image_base64_end: .ascii "\"}}"
.equ .a_image_base64_end_len,.-.a_image_base64_end
.a_image_end: .ascii "}}"
.equ .a_image_end_len,.-.a_image_end
.section .note.GNU-stack,"",@progbits

.text
.section .rodata
.g_protocol: .asciz "gemini"
.o_protocol: .asciz "openai-responses"
.text
# Responses keeps complete native history; store=false avoids server-side state.
.O_request:
 lea rax,[rip+.a_request_tokens]
 mov [rip+.a_tokens],rax
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 mov ecx,65536
 call json_parse
 test rax,rax
 js .A_request_bad
 cmp qword ptr [rip+.a_request_tokens],JT_OBJECT
 jne .A_request_bad
 AL .a_req_start
 xor edx,edx
 lea rcx,[rip+.a_model_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .o_req_stream
 call .A_messages_array
 test rax,rax
 js .A_request_bad
 mov r12,rax
 mov r13,rdx
 xor r14d,r14d
.O_message:
 cmp r12,r13
 jae .O_messages_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 mov rdi,r12
 call .A_message_role
 cmp eax,1
 je .O_system
 cmp eax,5
 je .O_developer
 cmp eax,2
 je .O_user
 cmp eax,3
 je .O_assistant
 cmp eax,4
 je .O_tool_result
 jmp .A_request_bad
.O_system:
 call .A_message_separator
 AL .o_system_message
 jmp .O_input_text
.O_developer:
 call .A_message_separator
 AL .o_developer_message
 jmp .O_input_text
.O_user:
 call .A_message_separator
 AL .a_user_start
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .O_content
 test rax,rax
 js .A_request_bad
 AL .a_array_object_end
 jmp .O_next_message
.O_input_text:
 AL .o_input_text
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_content_end
 jmp .O_next_message
.O_assistant:
 call .O_replay_metadata
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .O_calls
 mov [rsp],rax
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 jne .O_calls
 cmp qword ptr [rdx+T_LEN],0
 je .O_calls
 call .A_message_separator
 AL .a_assistant_start
 AL .o_output_text
 mov rax,[rsp]
 call .A_string
 AL .a_content_end
.O_calls:
 mov rdx,r12
 lea rcx,[rip+.a_calls_key]
 call .A_find
 test rax,rax
 js .O_next_message
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_request_bad
 mov [rsp+8],r12
 mov [rsp+16],r13
 mov r13,[rdx+T_END]
 inc rax
 mov r12,rax
.O_call:
 cmp r12,r13
 jae .O_calls_done
 mov rax,r12
 call .A_token
 mov rbx,[rdx+T_END]
 call .A_message_separator
 AL .o_function_call
 mov rdx,r12
 lea rcx,[rip+.a_id_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_name_field
 mov rdx,r12
 lea rcx,[rip+.a_function_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 mov rbp,rax
 mov rdx,rax
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .o_arguments_field
 mov rdx,rbp
 lea rcx,[rip+.a_arguments_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_object_end
 mov r12,rbx
 jmp .O_call
.O_calls_done:
 mov r12,[rsp+8]
 mov r13,[rsp+16]
 jmp .O_next_message
.O_tool_result:
 call .A_message_separator
 AL .o_function_output
 mov rdx,r12
 lea rcx,[rip+.a_call_id_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .o_output_field
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 AL .a_object_end
.O_next_message:
 mov r12,r15
 jmp .O_message
.O_messages_done:
 AL .a_array_end
 xor edx,edx
 lea rcx,[rip+.a_tools_key]
 call .A_find
 test rax,rax
 js .O_options
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_request_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
 cmp r12,r13
 jae .O_options
 AL .a_tools_start
 xor r14d,r14d
.O_tool:
 cmp r12,r13
 jae .O_tools_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 mov rdx,r12
 lea rcx,[rip+.a_function_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 mov rbp,rax
 test r14,r14
 jz .O_tool_first
 AL .a_comma
.O_tool_first:
 inc r14
 AL .o_tool_start
 mov rdx,rbp
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 mov rdx,rbp
 lea rcx,[rip+.a_description_key]
 call .A_find
 test rax,rax
 js .O_tool_parameters
 mov [rsp],rax
 AL .a_description_field
 mov rax,[rsp]
 call .A_string
 test rax,rax
 js .A_request_bad
.O_tool_parameters:
 AL .o_parameters_field
 mov rdx,rbp
 lea rcx,[rip+.a_parameters_key]
 call .A_find
 test rax,rax
 js .O_empty_parameters
 call .A_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_request_bad
 call .A_raw
 jmp .O_parameters_done
.O_empty_parameters:
 AL .a_empty_object
.O_parameters_done:
 AL .o_strict_false
 mov r12,r15
 jmp .O_tool
.O_tools_done:
 AL .a_array_end
.O_options:
 xor edx,edx
 lea rcx,[rip+.a_max_key]
 call .A_find
 test rax,rax
 jns .O_max_tokens
 xor edx,edx
 lea rcx,[rip+.a_max_completion_key]
 call .A_find
 test rax,rax
 js .O_temperature
.O_max_tokens:
 mov [rsp],rax
 AL .o_max_field
 mov rax,[rsp]
 call .A_raw
.O_temperature:
 xor edx,edx
 lea rcx,[rip+.a_temperature_key]
 call .A_find
 test rax,rax
 js .O_close
 mov [rsp],rax
 AL .a_temperature_field
 mov rax,[rsp]
 call .A_raw
.O_close:
 AL .a_object_end
 jmp .A_request_finish
# OpenAI multipart user content ->Responses input_text/input_image blocks.
.O_content:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rax
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 je .O_content_string
 cmp qword ptr [rdx],JT_ARRAY
 jne .O_content_bad
 mov r13,[rdx+T_END]
 inc r12
 xor r14d,r14d
.O_content_loop:
 cmp r12,r13
 jae .O_content_ok
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 test r14,r14
 jz .O_content_first
 AL .a_comma
.O_content_first:
 inc r14
 mov rdx,r12
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .O_content_bad
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .O_content_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_text_type]
 call .A_equal
 test eax,eax
 jnz .O_content_text
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_image_url_key]
 call .A_equal
 test eax,eax
 jz .O_content_bad
 AL .o_input_image
 mov rdx,r12
 lea rcx,[rip+.a_image_url_key]
 call .A_find
 test rax,rax
 js .O_content_bad
 call .A_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .O_content_image_value
 mov rdx,rax
 lea rcx,[rip+.a_url_key]
 call .A_find
 test rax,rax
 js .O_content_bad
.O_content_image_value:
 call .A_string
 test rax,rax
 js .O_content_bad
 AL .a_object_end
 jmp .O_content_next
.O_content_text:
 AL .o_input_text
 mov rdx,r12
 lea rcx,[rip+.a_text_key]
 call .A_find
 test rax,rax
 js .O_content_bad
 call .A_string
 test rax,rax
 js .O_content_bad
 AL .a_object_end
.O_content_next:
 mov r12,r15
 jmp .O_content_loop
.O_content_string:
 AL .o_input_text
 mov rax,r12
 call .A_string
 test rax,rax
 js .O_content_bad
 AL .a_object_end
.O_content_ok:
 xor eax,eax
 jmp .O_content_return
.O_content_bad:
 mov rax,-22
.O_content_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .bss
.o_arg_seen: .skip 64*8
.text
.O_event:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 cmp qword ptr [rip+.a_stream_done],0
 jne .A_event_return
 lea rdi,[rip+.a_data]
 mov rsi,[rip+.a_data_len]
 mov [rip+.a_src],rdi
 lea rdx,[rip+.a_stream_tokens]
 mov [rip+.a_tokens],rdx
 mov ecx,8192
 call json_parse
 test rax,rax
 js .A_event_bad
 xor edx,edx
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov ecx,127
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.o_text_delta_type]
 call .A_equal
 test eax,eax
 jnz .O_text
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_refusal_delta_type]
 call .A_equal
 test eax,eax
 jnz .O_text
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_added_type]
 call .A_equal
 test eax,eax
 jnz .O_added
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_arguments_delta_type]
 call .A_equal
 test eax,eax
 jnz .O_delta
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_item_done_type]
 call .A_equal
 test eax,eax
 jnz .O_item_done
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_completed_type]
 call .A_equal
 test eax,eax
 jnz .O_completed
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_incomplete_type]
 call .A_equal
 test eax,eax
 jnz .O_incomplete
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.o_failed_type]
 call .A_equal
 test eax,eax
 jnz .O_failed
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_error_type]
 call .A_equal
 test eax,eax
 jnz .O_error_root
 jmp .A_event_return
.O_text:
 xor edx,edx
 lea rcx,[rip+.a_delta_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 jmp .A_event_text
.O_item:
 xor edx,edx
 lea rcx,[rip+.o_item_key]
 call .A_find
 test rax,rax
 js .O_item_missing
 mov r13,rax
 mov rdx,rax
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .O_item_missing
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .O_item_missing
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.o_function_type]
 call .A_equal
 ret
.O_item_missing:
 xor eax,eax
 ret
.O_added:
 call .O_item
 test eax,eax
 jz .A_event_return
 call .O_output_index
 test rax,rax
 js .A_event_bad
 mov r12,rax
 mov r14,[rip+.a_tool_count]
 cmp r14,64
 jae .A_event_bad
 lea rdx,[rip+.a_tool_map]
 cmp qword ptr [rdx+r12*8],-1
 jne .A_event_bad
 mov [rdx+r12*8],r14
 inc qword ptr [rip+.a_tool_count]
 lea rdx,[rip+.o_arg_seen]
 mov qword ptr [rdx+r14*8],0
 AL .a_sse_tool_start
 mov rdi,r14
 call .A_emit_number
 AL .a_sse_tool_id
 mov rdx,r13
 lea rcx,[rip+.o_call_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .a_sse_function_name
 mov rdx,r13
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .o_arguments_field
 mov rdx,r13
 lea rcx,[rip+.a_arguments_key]
 call .A_find
 test rax,rax
 js .O_initial_empty
 call .A_token
 cmp qword ptr [rdx+T_LEN],0
 je .O_initial_arguments
 lea rcx,[rip+.o_arg_seen]
 mov qword ptr [rcx+r14*8],1
.O_initial_arguments:
 call .A_string
 test rax,rax
 js .A_event_bad
 jmp .O_added_end
.O_initial_empty:
 AL .o_empty_string
.O_added_end:
 AL .a_sse_tool_end
 jmp .A_event_return
.O_delta:
 call .O_output_index
 test rax,rax
 js .A_event_bad
 lea rdx,[rip+.a_tool_map]
 mov r14,[rdx+rax*8]
 cmp r14,64
 jae .A_event_bad
 xor edx,edx
 lea rcx,[rip+.a_delta_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov r15,rax
 call .O_emit_arguments
 jmp .A_event_return
.O_item_done:
 call .O_item
 test eax,eax
 jnz .O_function_item_done
 call .O_capture_reasoning
 jmp .A_event_return
.O_function_item_done:
 call .O_output_index
 test rax,rax
 js .A_event_bad
 lea rdx,[rip+.a_tool_map]
 mov r14,[rdx+rax*8]
 cmp r14,64
 jae .A_event_bad
 lea rdx,[rip+.o_arg_seen]
 cmp qword ptr [rdx+r14*8],0
 jne .A_event_return
 mov rdx,r13
 lea rcx,[rip+.a_arguments_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov r15,rax
 call .O_emit_arguments
 jmp .A_event_return
.O_emit_arguments:
 AL .a_sse_tool_start
 mov rdi,r14
 call .A_emit_number
 AL .a_sse_arguments_start
 mov rax,r15
 call .A_string
 test rax,rax
 js .O_emit_arguments_bad
 AL .a_sse_tool_end
 lea rdx,[rip+.o_arg_seen]
 mov qword ptr [rdx+r14*8],1
 ret
.O_emit_arguments_bad:
 mov qword ptr [rip+.a_err],-22
 ret
.O_completed:
 cmp qword ptr [rip+.a_tool_count],0
 je .O_completed_text
 AL .a_sse_finish_tools
 jmp .O_complete_end
.O_completed_text:
 AL .a_sse_finish_stop
.O_complete_end:
 AL .a_sse_done
 mov qword ptr [rip+.a_stream_done],1
 jmp .A_event_return
.O_incomplete:
 AL .a_sse_finish_length
 jmp .O_complete_end
.O_failed:
 xor edx,edx
 lea rcx,[rip+.o_response_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov rdx,rax
 lea rcx,[rip+.a_error_key]
 call .A_find
 test rax,rax
 js .A_event_bad
 mov rdx,rax
 lea rcx,[rip+.a_message_key]
 call .A_find
 jmp .O_error_message
.O_error_root:
 xor edx,edx
 lea rcx,[rip+.a_message_key]
 call .A_find
.O_error_message:
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_error_text]
 mov ecx,4095
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_error_text]
 mov byte ptr [rdi+rax],0
 jmp .A_event_bad
.O_output_index:
 # Same bounded integer parser as Anthropic with a different field name.
 sub rsp,8
 xor edx,edx
 lea rcx,[rip+.o_output_index_key]
 call .A_find
 test rax,rax
 js .A_block_index_bad
 call .A_token
 cmp qword ptr [rdx],JT_NUMBER
 jne .A_block_index_bad
 cmp qword ptr [rdx+T_LEN],2
 ja .A_block_index_bad
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 mov rcx,[rdx+T_LEN]
 xor eax,eax
 jmp .A_block_index_digit
.section .rodata
.o_text_delta_type: .asciz "response.output_text.delta"
.o_refusal_delta_type: .asciz "response.refusal.delta"
.o_added_type: .asciz "response.output_item.added"
.o_item_done_type: .asciz "response.output_item.done"
.o_arguments_delta_type: .asciz "response.function_call_arguments.delta"
.o_completed_type: .asciz "response.completed"
.o_incomplete_type: .asciz "response.incomplete"
.o_failed_type: .asciz "response.failed"
.o_function_type: .asciz "function_call"
.o_call_key: .asciz "call_id"
.o_item_key: .asciz "item"
.o_response_key: .asciz "response"
.o_output_index_key: .asciz "output_index"
.o_req_stream: .ascii ",\"stream\":true,\"store\":false,\"include\":[\"reasoning.encrypted_content\"],\"input\":["
.equ .o_req_stream_len,.-.o_req_stream
.o_system_message: .ascii "{\"role\":\"system\",\"content\":["
.equ .o_system_message_len,.-.o_system_message
.o_developer_message: .ascii "{\"role\":\"developer\",\"content\":["
.equ .o_developer_message_len,.-.o_developer_message
.o_input_text: .ascii "{\"type\":\"input_text\",\"text\":"
.equ .o_input_text_len,.-.o_input_text
.o_output_text: .ascii "{\"type\":\"output_text\",\"text\":"
.equ .o_output_text_len,.-.o_output_text
.o_input_image: .ascii "{\"type\":\"input_image\",\"image_url\":"
.equ .o_input_image_len,.-.o_input_image
.o_function_call: .ascii "{\"type\":\"function_call\",\"call_id\":"
.equ .o_function_call_len,.-.o_function_call
.o_arguments_field: .ascii ",\"arguments\":"
.equ .o_arguments_field_len,.-.o_arguments_field
.o_function_output: .ascii "{\"type\":\"function_call_output\",\"call_id\":"
.equ .o_function_output_len,.-.o_function_output
.o_output_field: .ascii ",\"output\":"
.equ .o_output_field_len,.-.o_output_field
.o_tool_start: .ascii "{\"type\":\"function\",\"name\":"
.equ .o_tool_start_len,.-.o_tool_start
.o_parameters_field: .ascii ",\"parameters\":"
.equ .o_parameters_field_len,.-.o_parameters_field
.o_strict_false: .ascii ",\"strict\":false}"
.equ .o_strict_false_len,.-.o_strict_false
.o_max_field: .ascii ",\"max_output_tokens\":"
.equ .o_max_field_len,.-.o_max_field
.o_empty_string: .ascii "\"\""
.equ .o_empty_string_len,.-.o_empty_string
.section .note.GNU-stack,"",@progbits
.section .bss
.m_meta_count: .skip 8
.m_meta_length: .skip 8
.m_meta_entries: .skip 65536*16
.m_meta_arena: .skip A_MAX
.text
.globl provider_stream_metadata
# out,cap ->raw provider_metadata JSON length/0none/-error. No credentials.
provider_stream_metadata:
 cmp qword ptr [rip+.m_meta_count],0
 jne .M_metadata_present
 xor eax,eax
 ret
.M_metadata_present:
 push r12
 push r13
 push r14
 mov [rip+.a_out],rdi
 mov [rip+.a_cap],rsi
 mov qword ptr [rip+.a_len],0
 mov qword ptr [rip+.a_err],0
 cmp qword ptr [rip+.a_protocol],3
 je .M_metadata_openai
 cmp qword ptr [rip+.a_protocol],2
 jne .M_metadata_none
 AL .m_meta_gemini
 jmp .M_metadata_body
.M_metadata_openai:
 AL .m_meta_openai
.M_metadata_body:
 xor r12d,r12d
 lea r13,[rip+.m_meta_entries]
.M_metadata_loop:
 cmp r12,[rip+.m_meta_count]
 jae .M_metadata_end
 test r12,r12
 jz .M_metadata_first
 AL .a_comma
.M_metadata_first:
 lea rdi,[rip+.m_meta_arena]
 add rdi,[r13]
 mov rsi,[r13+8]
 call .A_put
 add r13,16
 inc r12
 jmp .M_metadata_loop
.M_metadata_end:
 AL .a_array_end
 cmp qword ptr [rip+.a_protocol],2
 jne .M_metadata_close
 cmp qword ptr [rip+.g_generated_count],0
 je .M_metadata_close
 AL .g_generated_ids_start
 xor r12d,r12d
 lea r13,[rip+.g_generated_strings]
.M_metadata_gen_loop:
 cmp r12,[rip+.g_generated_count]
 jae .M_metadata_gen_done
 test r12,r12
 jz .M_metadata_gen_first
 AL .a_comma
.M_metadata_gen_first:
 xor esi,esi
.M_metadata_gen_len:
 cmp byte ptr [r13+rsi],0
 je .M_metadata_gen_copy
 inc rsi
 jmp .M_metadata_gen_len
.M_metadata_gen_copy:
 mov rdi,r13
 call .A_put
 inc r12
 add r13,64
 jmp .M_metadata_gen_loop
.M_metadata_gen_done:
 AL .a_array_end
.M_metadata_close:
 AL .a_object_end
 mov rax,[rip+.a_err]
 test rax,rax
 jnz .M_metadata_return
 mov rax,[rip+.a_len]
 jmp .M_metadata_return
.M_metadata_none:
 xor eax,eax
.M_metadata_return:
 pop r14
 pop r13
 pop r12
 ret
# Capture current parsed JSON token object exactly; SSE source is reused later.
.M_capture_token:
 push r12
 mov r12,rax
 call .A_token
 mov r8,[rip+.m_meta_count]
 cmp r8,65536
 jae .M_capture_full
 mov r9,[rip+.m_meta_length]
 mov rcx,[rdx+T_LEN]
 lea rax,[r9+rcx]
 cmp rax,A_MAX
 ja .M_capture_full
 mov [rip+.m_meta_length],rax
 shl r8,4
 lea rax,[rip+.m_meta_entries]
 mov [rax+r8],r9
 mov [rax+r8+8],rcx
 inc qword ptr [rip+.m_meta_count]
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 lea rdi,[rip+.m_meta_arena]
 add rdi,r9
 rep movsb
 xor eax,eax
 pop r12
 ret
.M_capture_full:
 mov qword ptr [rip+.a_err],-28
 mov rax,-28
 pop r12
 ret
.O_capture_reasoning:
 sub rsp,8
 xor edx,edx
 lea rcx,[rip+.o_item_key]
 call .A_find
 test rax,rax
 js .O_capture_done
 mov r13,rax
 mov rdx,rax
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .O_capture_done
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .O_capture_done
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.o_reasoning_type]
 call .A_equal
 test eax,eax
 jz .O_capture_done
 mov rax,r13
 call .M_capture_token
.O_capture_done:
 add rsp,8
 ret
.O_replay_metadata:
 push rbx
 push rbp
 push r12
 push r13
 push r15
 mov rdx,r12
 lea rcx,[rip+.m_metadata_key]
 call .A_find
 test rax,rax
 js .O_replay_done
 mov rbp,rax
 mov rdx,rax
 lea rcx,[rip+.m_protocol_key]
 call .A_find
 test rax,rax
 js .O_replay_done
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .O_replay_done
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.o_protocol]
 call .A_equal
 test eax,eax
 jz .O_replay_done
 mov rdx,rbp
 lea rcx,[rip+.m_items_key]
 call .A_find
 test rax,rax
 js .O_replay_done
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .O_replay_done
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
.O_replay_item:
 cmp r12,r13
 jae .O_replay_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 call .A_message_separator
 mov rax,r12
 call .A_raw
 mov r12,r15
 jmp .O_replay_item
.O_replay_done:
 pop r15
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.section .rodata
.m_metadata_key: .asciz "provider_metadata"
.m_protocol_key: .asciz "protocol"
.m_items_key: .asciz "items"
.m_parts_key: .asciz "parts"
.o_reasoning_type: .asciz "reasoning"
.m_meta_openai: .ascii "{\"protocol\":\"openai-responses\",\"items\":["
.equ .m_meta_openai_len,.-.m_meta_openai
.m_meta_gemini: .ascii "{\"protocol\":\"gemini\",\"parts\":["
.equ .m_meta_gemini_len,.-.m_meta_gemini
.section .note.GNU-stack,"",@progbits
.section .bss
.g_intermediate: .skip A_MAX
.g_target: .skip 8
.g_capacity: .skip 8
.g_history_count: .skip 8
.g_history_length: .skip 8
.g_history_items: .skip 4096*16
.g_history_arena: .skip A_MAX
.g_assistant_index: .skip 8
.g_tools_count: .skip 8
.g_tools: .skip 4096*16
.g_call_id: .skip 1024
.g_next_call: .skip 8
.text
.G_request:
 mov rax,[rip+.a_out]
 mov [rip+.g_target],rax
 mov rax,[rip+.a_cap]
 mov [rip+.g_capacity],rax
 # Keep exact signed Gemini model parts from native assistant metadata.
 call .G_cache_metadata
 test rax,rax
 js .A_request_bad
 lea rdi,[rip+.a_anthropic]
 mov rsi,r12
 mov rdx,r13
 lea rcx,[rip+.g_intermediate]
 mov r8d,A_MAX
 call provider_translate_request
 test rax,rax
 js .A_request_finish
 mov rsi,rax
 lea rdi,[rip+.g_intermediate]
 mov [rip+.a_src],rdi
 lea rdx,[rip+.a_request_tokens]
 mov [rip+.a_tokens],rdx
 mov ecx,65536
 call json_parse
 test rax,rax
 js .A_request_bad
 mov rax,[rip+.g_target]
 mov [rip+.a_out],rax
 mov rax,[rip+.g_capacity]
 mov [rip+.a_cap],rax
 mov qword ptr [rip+.a_len],0
 mov qword ptr [rip+.a_err],0
 mov qword ptr [rip+.g_tools_count],0
 mov qword ptr [rip+.g_assistant_index],0
 AL .g_request_start
 xor edx,edx
 lea rcx,[rip+.a_max_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_raw
 xor edx,edx
 lea rcx,[rip+.a_temperature_key]
 call .A_find
 test rax,rax
 js .G_config_top_p
 mov [rsp],rax
 AL .a_temperature_field
 mov rax,[rsp]
 call .A_raw
.G_config_top_p:
 xor edx,edx
 lea rcx,[rip+.a_top_p_key]
 call .A_find
 test rax,rax
 js .G_config_done
 mov [rsp],rax
 AL .g_top_p_field
 mov rax,[rsp]
 call .A_raw
.G_config_done:
 AL .g_contents_start
 call .A_messages_array
 test rax,rax
 js .A_request_bad
 mov r12,rax
 mov r13,rdx
 xor r14d,r14d
.G_message:
 cmp r12,r13
 jae .G_messages_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 call .A_message_separator
 mov rdi,r12
 call .A_message_role
 cmp eax,3
 je .G_model_message
 cmp eax,2
 jne .A_request_bad
 AL .g_user_start
 jmp .G_message_parts
.G_model_message:
 AL .g_model_start
 mov rax,[rip+.g_assistant_index]
 inc qword ptr [rip+.g_assistant_index]
 cmp rax,[rip+.g_history_count]
 jae .G_message_parts
 shl rax,4
 lea rdx,[rip+.g_history_items]
 add rdx,rax
 cmp qword ptr [rdx+8],0
 je .G_message_parts
 mov rbx,rdx
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .G_register_parts
 lea rdi,[rip+.g_history_arena]
 add rdi,[rbx]
 mov rsi,[rbx+8]
 call .A_put
 AL .a_object_end
 jmp .G_next_message
.G_message_parts:
 AL .a_array_open
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .G_parts
 test rax,rax
 js .A_request_bad
 AL .a_array_object_end
.G_next_message:
 mov r12,r15
 jmp .G_message
.G_messages_done:
 AL .a_array_end
 xor edx,edx
 lea rcx,[rip+.g_system_key]
 call .A_find
 test rax,rax
 js .G_tool_definitions
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_request_bad
 mov rcx,[rdx+T_END]
 lea rdx,[rax+1]
 cmp rdx,rcx
 jae .G_tool_definitions
 mov [rsp],rax
 AL .g_system_start
 mov rax,[rsp]
 call .G_parts
 test rax,rax
 js .A_request_bad
 AL .a_array_object_end
.G_tool_definitions:
 xor edx,edx
 lea rcx,[rip+.a_tools_key]
 call .A_find
 test rax,rax
 js .G_request_close
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_request_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
 cmp r12,r13
 jae .G_request_close
 AL .g_tools_start
 xor r14d,r14d
.G_tool_definition:
 cmp r12,r13
 jae .G_tools_done
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 test r14,r14
 jz .G_tool_first
 AL .a_comma
.G_tool_first:
 inc r14
 AL .a_def_start
 mov rdx,r12
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_string
 test rax,rax
 js .A_request_bad
 mov rdx,r12
 lea rcx,[rip+.a_description_key]
 call .A_find
 test rax,rax
 js .G_tool_schema
 mov [rsp],rax
 AL .a_description_field
 mov rax,[rsp]
 call .A_string
.G_tool_schema:
 AL .g_schema_field
 mov rdx,r12
 lea rcx,[rip+.g_input_schema_key]
 call .A_find
 test rax,rax
 js .A_request_bad
 call .A_raw
 AL .a_object_end
 mov r12,r15
 jmp .G_tool_definition
.G_tools_done:
 AL .g_tools_end
.G_request_close:
 AL .a_object_end
 jmp .A_request_finish
# Copy original per-assistant Gemini parts arrays before intermediate conversion.
.G_cache_metadata:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov qword ptr [rip+.g_history_count],0
 mov qword ptr [rip+.g_history_length],0
 mov qword ptr [rip+.g_generated_history_count],0
 lea rdx,[rip+.a_request_tokens]
 mov [rip+.a_tokens],rdx
 mov rdi,[rip+.a_src]
 mov rsi,r13
 mov ecx,65536
 call json_parse
 test rax,rax
 js .G_cache_bad
 call .A_messages_array
 test rax,rax
 js .G_cache_bad
 mov r12,rax
 mov r13,rdx
.G_cache_message:
 cmp r12,r13
 jae .G_cache_ok
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 mov rdi,r12
 call .A_message_role
 cmp eax,3
 jne .G_cache_next
 mov r14,[rip+.g_history_count]
 cmp r14,4096
 jae .G_cache_bad
 inc qword ptr [rip+.g_history_count]
 shl r14,4
 lea rbx,[rip+.g_history_items]
 add rbx,r14
 mov qword ptr [rbx],0
 mov qword ptr [rbx+8],0
 mov rdx,r12
 lea rcx,[rip+.m_metadata_key]
 call .A_find
 test rax,rax
 js .G_cache_next
 mov rbp,rax
 mov rdx,rax
 lea rcx,[rip+.m_protocol_key]
 call .A_find
 test rax,rax
 js .G_cache_next
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .G_cache_next
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.g_protocol]
 call .A_equal
 test eax,eax
 jz .G_cache_next
 mov rdx,rbp
 lea rcx,[rip+.m_parts_key]
 call .A_find
 test rax,rax
 js .G_cache_next
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .G_cache_bad
 mov rcx,[rdx+T_LEN]
 mov r8,[rip+.g_history_length]
 lea rax,[r8+rcx]
 cmp rax,A_MAX
 ja .G_cache_bad
 mov [rip+.g_history_length],rax
 mov [rbx],r8
 mov [rbx+8],rcx
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 lea rdi,[rip+.g_history_arena]
 add rdi,r8
 rep movsb
 mov rdi,rbp
 call .G_cache_generated_ids
 test rax,rax
 js .G_cache_bad
.G_cache_next:
 mov r12,r15
 jmp .G_cache_message
.G_cache_ok:
 xor eax,eax
 jmp .G_cache_return
.G_cache_bad:
 mov rax,-22
.G_cache_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
# Array of Anthropic content blocks ->Gemini parts (without outer brackets).
.G_parts:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .G_parts_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
 xor r14d,r14d
.G_parts_loop:
 cmp r12,r13
 jae .G_parts_ok
 mov rax,r12
 call .A_token
 mov r15,[rdx+T_END]
 test r14,r14
 jz .G_parts_first
 AL .a_comma
.G_parts_first:
 inc r14
 mov rax,r12
 call .G_part
 test rax,rax
 js .G_parts_bad
 mov r12,r15
 jmp .G_parts_loop
.G_parts_ok:
 xor eax,eax
 jmp .G_parts_return
.G_parts_bad:
 mov rax,-22
.G_parts_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.G_part:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rax
 mov rdx,rax
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .G_part_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_text_type]
 call .A_equal
 test eax,eax
 jnz .G_part_text
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.a_tool_use_type]
 call .A_equal
 test eax,eax
 jnz .G_part_call
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.g_result_type]
 call .A_equal
 test eax,eax
 jnz .G_part_result
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.g_image_type]
 call .A_equal
 test eax,eax
 jnz .G_part_image
 jmp .G_part_bad
.G_part_text:
 AL .g_text_start
 mov rdx,r12
 lea rcx,[rip+.a_text_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_string
 test rax,rax
 js .G_part_bad
 AL .a_object_end
 jmp .G_part_ok
.G_part_call:
 mov rax,r12
 call .G_register_tool
 test rax,rax
 js .G_part_bad
 mov rdx,r12
 lea rcx,[rip+.a_id_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 mov r13,rax
 call .G_is_generated_id
 test eax,eax
 jnz .G_part_call_no_id
 AL .g_call_start
 mov rax,r13
 call .A_string
 AL .a_name_field
 jmp .G_part_call_name
.G_part_call_no_id:
 AL .g_call_no_id
.G_part_call_name:
 mov rdx,r12
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_string
 AL .g_args_field
 mov rdx,r12
 lea rcx,[rip+.a_input_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_raw
 AL .a_image_end
 jmp .G_part_ok
.G_part_result:
 mov rdx,r12
 lea rcx,[rip+.g_tool_use_id_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 mov r13,rax
 call .G_is_generated_id
 test eax,eax
 jnz .G_part_result_no_id
 AL .g_response_start
 mov rax,r13
 call .A_string
 AL .a_name_field
 jmp .G_part_result_name
.G_part_result_no_id:
 AL .g_response_no_id
.G_part_result_name:
 mov rax,r13
 call .G_result_name
 test rax,rax
 js .G_part_bad
 call .A_string
 AL .g_response_output
 mov rdx,r12
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_string
 AL .g_three_end
 jmp .G_part_ok
.G_part_image:
 mov rdx,r12
 lea rcx,[rip+.g_source_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 mov r13,rax
 mov rdx,rax
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .G_part_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.g_base64_type]
 call .A_equal
 test eax,eax
 jz .G_part_file_image
 AL .g_inline_start
 mov rdx,r13
 lea rcx,[rip+.g_media_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_string
 AL .g_data_field
 mov rdx,r13
 lea rcx,[rip+.g_data_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_string
 AL .a_image_end
 jmp .G_part_ok
.G_part_file_image:
 AL .g_file_start
 mov rdx,r13
 lea rcx,[rip+.a_url_key]
 call .A_find
 test rax,rax
 js .G_part_bad
 call .A_string
 AL .a_image_end
.G_part_ok:
 xor eax,eax
 jmp .G_part_return
.G_part_bad:
 mov rax,-22
.G_part_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
# Remember native tool ids ->names so functionResponse returns correct name.
.G_register_tool:
 push r12
 push r13
 sub rsp,8
 mov r12,rax
 mov rdx,rax
 lea rcx,[rip+.a_id_key]
 call .A_find
 test rax,rax
 js .G_register_bad
 mov r13,rax
 mov rdx,r12
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .G_register_bad
 mov r8,[rip+.g_tools_count]
 cmp r8,4096
 jae .G_register_bad
 shl r8,4
 lea rdx,[rip+.g_tools]
 mov [rdx+r8],r13
 mov [rdx+r8+8],rax
 inc qword ptr [rip+.g_tools_count]
 xor eax,eax
 jmp .G_register_return
.G_register_bad:
 mov rax,-22
.G_register_return:
 add rsp,8
 pop r13
 pop r12
 ret
.G_register_parts:
 push r12
 push r13
 push r14
 call .A_token
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
.G_register_part:
 cmp r12,r13
 jae .G_register_parts_done
 mov rax,r12
 call .A_token
 mov r14,[rdx+T_END]
 mov rdx,r12
 lea rcx,[rip+.a_type_key]
 call .A_find
 test rax,rax
 js .G_register_part_next
 lea rdi,[rip+.a_name]
 mov ecx,63
 call .A_decode
 test rax,rax
 js .G_register_part_next
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.a_tool_use_type]
 call .A_equal
 test eax,eax
 jz .G_register_part_next
 mov rax,r12
 call .G_register_tool
.G_register_part_next:
 mov r12,r14
 jmp .G_register_part
.G_register_parts_done:
 pop r14
 pop r13
 pop r12
 ret
.G_result_name:
 push r12
 push r13
 sub rsp,8
 lea rdi,[rip+.g_call_id]
 mov ecx,1023
 call .A_decode
 test rax,rax
 js .G_result_missing
 lea rdi,[rip+.g_call_id]
 mov byte ptr [rdi+rax],0
 xor r12d,r12d
 lea r13,[rip+.g_tools]
.G_result_lookup:
 cmp r12,[rip+.g_tools_count]
 jae .G_result_missing
 mov rax,[r13]
 lea rdi,[rip+.a_name]
 mov ecx,4095
 call .A_decode
 test rax,rax
 js .G_result_next
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.g_call_id]
 call .A_equal
 test eax,eax
 jnz .G_result_found
.G_result_next:
 inc r12
 add r13,16
 jmp .G_result_lookup
.G_result_found:
 mov rax,[r13+8]
 jmp .G_result_return
.G_result_missing:
 mov rax,-22
.G_result_return:
 add rsp,8
 pop r13
 pop r12
 ret
.section .rodata
.g_request_start: .ascii "{\"generationConfig\":{\"maxOutputTokens\":"
.equ .g_request_start_len,.-.g_request_start
.g_top_p_field: .ascii ",\"topP\":"
.equ .g_top_p_field_len,.-.g_top_p_field
.g_contents_start: .ascii "},\"contents\":["
.equ .g_contents_start_len,.-.g_contents_start
.g_user_start: .ascii "{\"role\":\"user\",\"parts\":"
.equ .g_user_start_len,.-.g_user_start
.g_model_start: .ascii "{\"role\":\"model\",\"parts\":"
.equ .g_model_start_len,.-.g_model_start
.g_system_start: .ascii ",\"systemInstruction\":{\"parts\":["
.equ .g_system_start_len,.-.g_system_start
.g_tools_start: .ascii ",\"tools\":[{\"functionDeclarations\":["
.equ .g_tools_start_len,.-.g_tools_start
.g_tools_end: .ascii "]}]"
.equ .g_tools_end_len,.-.g_tools_end
.g_schema_field: .ascii ",\"parametersJsonSchema\":"
.equ .g_schema_field_len,.-.g_schema_field
.g_text_start: .ascii "{\"text\":"
.equ .g_text_start_len,.-.g_text_start
.g_call_start: .ascii "{\"functionCall\":{\"id\":"
.equ .g_call_start_len,.-.g_call_start
.g_args_field: .ascii ",\"args\":"
.equ .g_args_field_len,.-.g_args_field
.g_response_start: .ascii "{\"functionResponse\":{\"id\":"
.equ .g_response_start_len,.-.g_response_start
.g_response_output: .ascii ",\"response\":{\"output\":"
.equ .g_response_output_len,.-.g_response_output
.g_three_end: .ascii "}}}"
.equ .g_three_end_len,.-.g_three_end
.g_inline_start: .ascii "{\"inlineData\":{\"mimeType\":"
.equ .g_inline_start_len,.-.g_inline_start
.g_data_field: .ascii ",\"data\":"
.equ .g_data_field_len,.-.g_data_field
.g_file_start: .ascii "{\"fileData\":{\"fileUri\":"
.equ .g_file_start_len,.-.g_file_start
.a_array_open: .ascii "["
.equ .a_array_open_len,.-.a_array_open
.g_system_key: .asciz "system"
.g_input_schema_key: .asciz "input_schema"
.g_result_type: .asciz "tool_result"
.g_image_type: .asciz "image"
.g_source_key: .asciz "source"
.g_media_key: .asciz "media_type"
.g_data_key: .asciz "data"
.g_base64_type: .asciz "base64"
.g_tool_use_id_key: .asciz "tool_use_id"
.section .note.GNU-stack,"",@progbits
.text
.G_event:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 cmp qword ptr [rip+.a_stream_done],0
 jne .A_event_return
 lea rdi,[rip+.a_data]
 mov rsi,[rip+.a_data_len]
 mov [rip+.a_src],rdi
 lea rdx,[rip+.a_stream_tokens]
 mov [rip+.a_tokens],rdx
 mov ecx,8192
 call json_parse
 test rax,rax
 js .A_event_bad
 cmp qword ptr [rip+.a_stream_tokens],JT_OBJECT
 jne .A_event_bad
 xor edx,edx
 lea rcx,[rip+.a_error_key]
 call .A_find
 test rax,rax
 jns .A_event_error
 xor edx,edx
 lea rcx,[rip+.g_candidates_key]
 call .A_find
 test rax,rax
 js .G_prompt_feedback
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_event_bad
 mov rcx,[rdx+T_END]
 inc rax
 cmp rax,rcx
 jae .G_prompt_feedback
 mov r12,rax
 mov rdx,rax
 lea rcx,[rip+.a_content_key]
 call .A_find
 test rax,rax
 js .G_finish_candidate
 mov rdx,rax
 lea rcx,[rip+.m_parts_key]
 call .A_find
 test rax,rax
 js .G_finish_candidate
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .A_event_bad
 mov r13,[rdx+T_END]
 lea rbx,[rax+1]
.G_event_part:
 cmp rbx,r13
 jae .G_finish_candidate
 mov rax,rbx
 call .A_token
 mov rbp,[rdx+T_END]
 cmp qword ptr [rdx],JT_OBJECT
 jne .A_event_bad
 mov rax,rbx
 call .M_capture_token
 test rax,rax
 js .A_event_bad
 mov rdx,rbx
 lea rcx,[rip+.g_thought_key]
 call .A_find
 test rax,rax
 js .G_event_visible_part
 call .A_token
 cmp qword ptr [rdx],JT_TRUE
 je .G_event_part_next
.G_event_visible_part:
 mov rdx,rbx
 lea rcx,[rip+.a_text_key]
 call .A_find
 test rax,rax
 js .G_event_function
 mov r15,rax
 AL .a_sse_text_start
 mov rax,r15
 call .A_string
 test rax,rax
 js .A_event_bad
 AL .a_sse_text_end
.G_event_function:
 mov rdx,rbx
 lea rcx,[rip+.g_function_call_key]
 call .A_find
 test rax,rax
 js .G_event_part_next
 mov r15,rax
 call .G_emit_function
 test rax,rax
 js .A_event_bad
.G_event_part_next:
 mov rbx,rbp
 jmp .G_event_part
.G_finish_candidate:
 mov rdx,r12
 lea rcx,[rip+.g_finish_key]
 call .A_find
 test rax,rax
 js .A_event_return
 lea rdi,[rip+.a_name]
 mov ecx,127
 call .A_decode
 test rax,rax
 jle .A_event_bad
 lea rdi,[rip+.a_name]
 mov byte ptr [rdi+rax],0
 lea rsi,[rip+.g_stop_type]
 call .A_equal
 test eax,eax
 jnz .O_completed
 lea rdi,[rip+.a_name]
 lea rsi,[rip+.g_max_type]
 call .A_equal
 test eax,eax
 jnz .O_incomplete
 lea rsi,[rip+.a_name]
 lea rdi,[rip+.a_error_text]
.G_finish_error_copy:
 lodsb
 stosb
 test al,al
 jnz .G_finish_error_copy
 jmp .A_event_bad
.G_prompt_feedback:
 xor edx,edx
 lea rcx,[rip+.g_feedback_key]
 call .A_find
 test rax,rax
 js .A_event_return
 mov rdx,rax
 lea rcx,[rip+.g_block_reason_key]
 call .A_find
 test rax,rax
 js .A_event_return
 lea rdi,[rip+.a_error_text]
 mov ecx,4095
 call .A_decode
 test rax,rax
 js .A_event_bad
 lea rdi,[rip+.a_error_text]
 mov byte ptr [rdi+rax],0
 jmp .A_event_bad
.G_emit_function:
 push r12
 push r13
 push r14
 mov r13,r15
 mov r14,[rip+.a_tool_count]
 cmp r14,64
 jae .G_emit_bad
 inc qword ptr [rip+.a_tool_count]
 AL .a_sse_tool_start
 mov rdi,r14
 call .A_emit_number
 AL .a_sse_tool_id
 mov rdx,r13
 lea rcx,[rip+.a_id_key]
 call .A_find
 test rax,rax
 js .G_emit_generated_id
 call .A_string
 test rax,rax
 js .G_emit_bad
 jmp .G_emit_function_name
.G_emit_generated_id:
 call .G_new_generated_id
 test rax,rax
 js .G_emit_bad
.G_emit_function_name:
 AL .a_sse_function_name
 mov rdx,r13
 lea rcx,[rip+.a_name_key]
 call .A_find
 test rax,rax
 js .G_emit_bad
 call .A_string
 test rax,rax
 js .G_emit_bad
 AL .o_arguments_field
 mov rdx,r13
 lea rcx,[rip+.g_args_key]
 call .A_find
 test rax,rax
 js .G_emit_empty_args
 call .A_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .G_emit_bad
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 lea rdi,[rip+.a_arguments]
 mov ecx,65536
 call json_quote
 test rax,rax
 js .G_emit_bad
 mov rsi,rax
 lea rdi,[rip+.a_arguments]
 call .A_put
 jmp .G_emit_end
.G_emit_empty_args:
 AL .g_empty_arguments
.G_emit_end:
 AL .a_sse_tool_end
 xor eax,eax
 jmp .G_emit_return
.G_emit_bad:
 mov rax,-22
.G_emit_return:
 pop r14
 pop r13
 pop r12
 ret
.section .rodata
.g_candidates_key: .asciz "candidates"
.g_function_call_key: .asciz "functionCall"
.g_args_key: .asciz "args"
.g_finish_key: .asciz "finishReason"
.g_thought_key: .asciz "thought"
.g_stop_type: .asciz "STOP"
.g_max_type: .asciz "MAX_TOKENS"
.g_feedback_key: .asciz "promptFeedback"
.g_block_reason_key: .asciz "blockReason"
.g_generated_id: .ascii "\"gemini-call-"
.equ .g_generated_id_len,.-.g_generated_id
.g_quote: .ascii "\""
.equ .g_quote_len,.-.g_quote
.g_empty_arguments: .ascii "\"{}\""
.equ .g_empty_arguments_len,.-.g_empty_arguments
.section .note.GNU-stack,"",@progbits
.section .bss
.g_generated_count: .skip 8
.g_generated_strings: .skip 64*64
.g_generated_history_count: .skip 8
.g_generated_history_entries: .skip 4096*16
.text
.G_new_generated_id:
 push r12
 push r13
 sub rsp,8
 mov rax,[rip+.g_generated_count]
 cmp rax,64
 jae .G_generated_bad
 shl rax,6
 lea r12,[rip+.g_generated_strings]
 add r12,rax
 inc qword ptr [rip+.g_generated_count]
 mov rdi,r12
 lea rsi,[rip+.g_generated_id]
 mov ecx,OFFSET FLAT:.g_generated_id_len
 rep movsb
 mov r13,rdi
 mov rsi,[rip+.g_next_call]
 inc qword ptr [rip+.g_next_call]
 call qx_uint
 lea rdi,[r13+rax]
 mov byte ptr [rdi],'"'
 mov byte ptr [rdi+1],0
 lea rsi,[rdi+1]
 sub rsi,r12
 mov rdi,r12
 call .A_put
 xor eax,eax
 jmp .G_generated_return
.G_generated_bad:
 mov rax,-28
.G_generated_return:
 add rsp,8
 pop r13
 pop r12
 ret
.G_cache_generated_ids:
 push r12
 push r13
 push r14
 mov rdx,rdi
 lea rcx,[rip+.g_generated_ids_key]
 call .A_find
 test rax,rax
 js .G_cache_gen_ok
 call .A_token
 cmp qword ptr [rdx],JT_ARRAY
 jne .G_cache_gen_bad
 mov r13,[rdx+T_END]
 lea r12,[rax+1]
.G_cache_gen_item:
 cmp r12,r13
 jae .G_cache_gen_ok
 mov rax,r12
 call .A_token
 mov r14,[rdx+T_END]
 cmp qword ptr [rdx],JT_STRING
 jne .G_cache_gen_bad
 mov rcx,[rdx+T_LEN]
 cmp rcx,1023
 ja .G_cache_gen_bad
 add rcx,2
 mov r8,[rip+.g_history_length]
 lea rax,[r8+rcx]
 cmp rax,A_MAX
 ja .G_cache_gen_bad
 mov r9,[rip+.g_generated_history_count]
 cmp r9,4096
 jae .G_cache_gen_bad
 inc qword ptr [rip+.g_generated_history_count]
 shl r9,4
 lea rdi,[rip+.g_generated_history_entries]
 mov [rdi+r9],r8
 mov [rdi+r9+8],rcx
 mov [rip+.g_history_length],rax
 mov rsi,[rip+.a_src]
 add rsi,[rdx+T_START]
 dec rsi
 lea rdi,[rip+.g_history_arena]
 add rdi,r8
 rep movsb
 mov r12,r14
 jmp .G_cache_gen_item
.G_cache_gen_ok:
 xor eax,eax
 jmp .G_cache_gen_return
.G_cache_gen_bad:
 mov rax,-22
.G_cache_gen_return:
 pop r14
 pop r13
 pop r12
 ret
.G_is_generated_id:
 push r12
 push r13
 push r14
 call .A_token
 cmp qword ptr [rdx],JT_STRING
 jne .G_is_gen_no
 mov r12,[rip+.a_src]
 add r12,[rdx+T_START]
 dec r12
 mov r13,[rdx+T_LEN]
 add r13,2
 lea r14,[rip+.g_generated_history_entries]
 xor r8d,r8d
.G_is_gen_next:
 cmp r8,[rip+.g_generated_history_count]
 jae .G_is_gen_no
 cmp r13,[r14+8]
 jne .G_is_gen_advance
 lea rsi,[rip+.g_history_arena]
 add rsi,[r14]
 xor ecx,ecx
.G_is_gen_byte:
 cmp rcx,r13
 jae .G_is_gen_yes
 mov al,[r12+rcx]
 cmp al,[rsi+rcx]
 jne .G_is_gen_advance
 inc rcx
 jmp .G_is_gen_byte
.G_is_gen_advance:
 inc r8
 add r14,16
 jmp .G_is_gen_next
.G_is_gen_yes:
 mov eax,1
 jmp .G_is_gen_return
.G_is_gen_no:
 xor eax,eax
.G_is_gen_return:
 pop r14
 pop r13
 pop r12
 ret
.section .rodata
.g_generated_ids_key: .asciz "generated_ids"
.g_generated_ids_start: .ascii ",\"generated_ids\":["
.equ .g_generated_ids_start_len,.-.g_generated_ids_start
.g_call_no_id: .ascii "{\"functionCall\":{\"name\":"
.equ .g_call_no_id_len,.-.g_call_no_id
.g_response_no_id: .ascii "{\"functionResponse\":{\"name\":"
.equ .g_response_no_id_len,.-.g_response_no_id
.section .note.GNU-stack,"",@progbits
