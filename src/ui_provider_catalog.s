# Native modelProviders/providerProtocol registry from actual Qwen settings.
# Record4096: id0[256],name256[256],provider512[128],auth640[64],
# baseURL704[2048],envKey2752[256],description3008[512],context3520u64,
# nativeProtocolSupported3528u64 (OpenAI chat-completions or Qwen OAuth).
# No API-key values are read, stored, or displayed by this registry.
.include "abi.inc"
.equ PM_RECORD,4096
.equ PM_MAX,64
.section .bss
.pm_count: .skip 8
.pm_initial_count: .skip 8
.pm_records: .skip PM_MAX*PM_RECORD
.pm_temp: .skip PM_RECORD
.pm_src: .skip 8
.pm_tokens: .skip 8192*32
.pm_mapping: .skip 8
.pm_provider: .skip 128
.pm_protocol: .skip 64
.pm_model: .skip 8
.pm_next: .skip 8
.pm_array_end: .skip 8
.pm_outer_end: .skip 8
.pm_outer_next: .skip 8
.text
.globl ui_provider_models_reset,ui_provider_models_load,ui_provider_model_catalog,ui_provider_model_get
ui_provider_models_reset:
 mov qword ptr [rip+.pm_count],0
 xor eax,eax
 ret
ui_provider_models_load:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 mov rax,[rip+.pm_count]
 mov [rip+.pm_initial_count],rax
 cmp rsi,65536
 ja .PM_bad
 mov [rip+.pm_src],rdi
 lea rdx,[rip+.pm_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .PM_bad
 cmp qword ptr [rip+.pm_tokens],JT_OBJECT
 jne .PM_bad
 xor edx,edx
 lea rcx,[rip+.pm_protocol_key]
 call .PM_find
 mov [rip+.pm_mapping],rax
 xor edx,edx
 lea rcx,[rip+.pm_models_key]
 call .PM_find
 test rax,rax
 js .PM_done
 mov r12,rax
 call .PM_token
 cmp qword ptr [rdx],JT_OBJECT
 jne .PM_bad
 mov r13,[rdx+T_END]
 inc r12
.PM_provider:
 cmp r12,r13
 jae .PM_done
 mov rax,r12
 lea rdi,[rip+.pm_provider]
 mov ecx,63
 call .PM_decode
 test rax,rax
 jle .PM_bad
 lea rsi,[rip+.pm_provider]
 lea rdi,[rip+.pm_protocol]
 call .PM_copyz
 mov rdx,[rip+.pm_mapping]
 test rdx,rdx
 js .PM_provider_protocol_ready
 lea rcx,[rip+.pm_provider]
 call .PM_find
 test rax,rax
 js .PM_provider_protocol_ready
 lea rdi,[rip+.pm_protocol]
 mov ecx,63
 call .PM_decode
 test rax,rax
 jle .PM_bad
.PM_provider_protocol_ready:
 inc r12
 mov rax,r12
 call .PM_token
 mov r14,[rdx+T_END]
 cmp qword ptr [rdx],JT_ARRAY
 jne .PM_provider_next
 mov rbp,r12
 inc rbp
.PM_model:
 cmp rbp,r14
 jae .PM_provider_next
 mov [rip+.pm_model],rbp
 mov rax,rbp
 call .PM_token
 mov rbp,[rdx+T_END]
 cmp qword ptr [rdx],JT_OBJECT
 jne .PM_model
 lea rdi,[rip+.pm_temp]
 xor eax,eax
 mov ecx,PM_RECORD/8
 rep stosq
 mov rdx,[rip+.pm_model]
 lea rcx,[rip+.pm_id_key]
 call .PM_find
 test rax,rax
 js .PM_model
 lea rdi,[rip+.pm_temp]
 mov ecx,255
 call .PM_decode
 test rax,rax
 jle .PM_model
 lea rsi,[rip+.pm_temp]
 lea rdi,[rip+.pm_temp+256]
 call .PM_copyz
 lea rsi,[rip+.pm_provider]
 lea rdi,[rip+.pm_temp+512]
 call .PM_copyz
 lea rsi,[rip+.pm_protocol]
 lea rdi,[rip+.pm_temp+640]
 call .PM_copyz
 # Optional wireApi overrides only OpenAI-compatible protocol.
 mov rdx,[rip+.pm_model]
 lea rcx,[rip+.pm_wire_key]
 call .PM_find
 test rax,rax
 js .PM_fields
 lea rdi,[rip+.pm_wire_value]
 mov ecx,63
 call .PM_decode
 test rax,rax
 jle .PM_model
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_openai]
 call .PM_equal
 test eax,eax
 jnz .PM_wire_allowed
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_responses]
 call .PM_equal
 test eax,eax
 jz .PM_model
.PM_wire_allowed:
 lea rdi,[rip+.pm_wire_value]
 lea rsi,[rip+.pm_chat_wire]
 call .PM_equal
 test eax,eax
 jnz .PM_chat_protocol
 lea rdi,[rip+.pm_wire_value]
 lea rsi,[rip+.pm_responses_wire]
 call .PM_equal
 test eax,eax
 jz .PM_model
 lea rsi,[rip+.pm_responses]
 jmp .PM_wire_copy
.PM_chat_protocol:
 lea rsi,[rip+.pm_openai]
.PM_wire_copy:
 lea rdi,[rip+.pm_temp+640]
 call .PM_copyz
.PM_fields:
 xor ebx,ebx
.PM_field:
 lea rax,[rip+.pm_field_map]
 mov rdi,rbx
 shl rdi,5
 add rdi,rax
 mov [rip+.pm_field_current],rdi
 mov rcx,[rdi]
 add rcx,rax
 mov rdx,[rip+.pm_model]
 call .PM_find
 test rax,rax
 js .PM_field_next
 mov rdx,[rip+.pm_field_current]
 mov rdi,[rdx+8]
 lea rsi,[rip+.pm_temp]
 add rdi,rsi
 mov rcx,[rdx+16]
 call .PM_decode
.PM_field_next:
 inc rbx
 cmp rbx,4
 jb .PM_field
 # Name empty uses actual id.
 cmp byte ptr [rip+.pm_temp+256],0
 jne .PM_context
 lea rsi,[rip+.pm_temp]
 lea rdi,[rip+.pm_temp+256]
 call .PM_copyz
.PM_context:
 mov rdx,[rip+.pm_model]
 lea rcx,[rip+.pm_generation_key]
 call .PM_find
 test rax,rax
 js .PM_native_flag
 mov rdx,rax
 lea rcx,[rip+.pm_context_key]
 call .PM_find
 test rax,rax
 js .PM_native_flag
 call .PM_token
 cmp qword ptr [rdx],JT_NUMBER
 jne .PM_native_flag
 mov rsi,[rip+.pm_src]
 add rsi,[rdx+T_START]
 mov rcx,[rdx+T_LEN]
 cmp rcx,12
 ja .PM_native_flag
 xor eax,eax
.PM_context_digit:
 test rcx,rcx
 jz .PM_context_set
 movzx edi,byte ptr [rsi]
 sub edi,'0'
 cmp edi,9
 ja .PM_native_flag
 imul rax,rax,10
 add rax,rdi
 inc rsi
 dec rcx
 jmp .PM_context_digit
.PM_context_set:
 mov [rip+.pm_temp+3520],rax
.PM_native_flag:
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_openai]
 call .PM_equal
 test eax,eax
 jnz .PM_supported
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_oauth]
 call .PM_equal
 test eax,eax
 jnz .PM_supported
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_anthropic]
 call .PM_equal
 test eax,eax
 jnz .PM_supported
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_responses]
 call .PM_equal
 test eax,eax
 jnz .PM_supported
 lea rdi,[rip+.pm_temp+640]
 lea rsi,[rip+.pm_gemini]
 call .PM_equal
 test eax,eax
 jz .PM_store
.PM_supported:
 mov qword ptr [rip+.pm_temp+3528],1
.PM_store:
 # Layered settings replace exact protocol+model+endpoint; distinct endpoints
 # remain distinct, as in modelRegistryKey(id,baseUrl).
 xor ebx,ebx
.PM_duplicate:
 cmp rbx,[rip+.pm_count]
 jae .PM_new
 imul rax,rbx,PM_RECORD
 lea rdi,[rip+.pm_records]
 add rdi,rax
 mov [rip+.pm_dest],rdi
 lea rsi,[rip+.pm_temp]
 call .PM_equal
 test eax,eax
 jz .PM_duplicate_next
 mov rdi,[rip+.pm_dest]
 add rdi,640
 lea rsi,[rip+.pm_temp+640]
 call .PM_equal
 test eax,eax
 jz .PM_duplicate_next
 mov rdi,[rip+.pm_dest]
 add rdi,704
 lea rsi,[rip+.pm_temp+704]
 call .PM_equal
 test eax,eax
 jz .PM_duplicate_next
 cmp rbx,[rip+.pm_initial_count]
 jae .PM_model
 jmp .PM_save
.PM_duplicate_next:
 inc rbx
 jmp .PM_duplicate
.PM_new:
 cmp rbx,PM_MAX
 jae .PM_full
 imul rax,rbx,PM_RECORD
 lea rdi,[rip+.pm_records]
 add rdi,rax
 mov [rip+.pm_dest],rdi
 inc qword ptr [rip+.pm_count]
.PM_save:
 mov rdi,[rip+.pm_dest]
 lea rsi,[rip+.pm_temp]
 mov ecx,PM_RECORD/8
 rep movsq
 inc r15
 jmp .PM_model
.PM_provider_next:
 mov r12,r14
 jmp .PM_provider
.PM_full:
 mov r15,-28
 jmp .PM_done
.PM_bad:
 mov r15,-22
.PM_done:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.PM_find:
 mov rdi,[rip+.pm_src]
 lea rsi,[rip+.pm_tokens]
 jmp json_find
.PM_token:
 shl rax,5
 lea rdx,[rip+.pm_tokens]
 add rdx,rax
 ret
.PM_decode:
 push rdi
 push rcx
 sub rsp,8
 call .PM_token
 cmp qword ptr [rdx],JT_STRING
 jne .PM_decode_bad
 mov rsi,[rip+.pm_src]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 mov rcx,[rsp+8]
 call json_decode
 test rax,rax
 js .PM_decode_bad
 mov rdi,[rsp+16]
 mov byte ptr [rdi+rax],0
 xor ecx,ecx
.PM_decode_valid:
 cmp rcx,rax
 jae .PM_decode_done
 cmp byte ptr [rdi+rcx],32
 jb .PM_decode_bad
 cmp byte ptr [rdi+rcx],127
 je .PM_decode_bad
 inc rcx
 jmp .PM_decode_valid
.PM_decode_bad:
 mov rdi,[rsp+16]
 mov byte ptr [rdi],0
 mov rax,-1
.PM_decode_done:
 add rsp,24
 ret
.PM_copyz:
 lodsb
 stosb
 test al,al
 jnz .PM_copyz
 ret
.PM_equal:
 xor ecx,ecx
.PM_equal_loop:
 mov al,[rdi+rcx]
 cmp al,[rsi+rcx]
 jne .PM_unequal
 inc rcx
 test al,al
 jnz .PM_equal_loop
 mov eax,1
 ret
.PM_unequal:
 xor eax,eax
 ret
ui_provider_model_catalog:
 mov rax,[rip+.pm_count]
 test rsi,rsi
 jz .PM_catalog_done
 test rdi,rdi
 jz .PM_catalog_bad
 cmp rsi,rax
 cmova rsi,rax
 mov rax,rsi
 lea rdx,[rip+.pm_records]
 xor ecx,ecx
.PM_catalog_loop:
 cmp rcx,rax
 jae .PM_catalog_done
 lea r8,[rdx+256]
 mov [rdi],r8
 lea r8,[rdx+3008]
 mov [rdi+8],r8
 mov [rdi+16],rdx
 add rdi,24
 add rdx,PM_RECORD
 inc rcx
 jmp .PM_catalog_loop
.PM_catalog_bad:
 mov rax,-22
.PM_catalog_done:
 ret
ui_provider_model_get:
 cmp rdi,[rip+.pm_count]
 jae .PM_get_bad
 imul rax,rdi,PM_RECORD
 lea rdx,[rip+.pm_records]
 add rax,rdx
 ret
.PM_get_bad:
 xor eax,eax
 ret
.section .bss
.pm_dest: .skip 8
.pm_wire_value: .skip 64
.pm_field_current: .skip 8
.section .rodata
.pm_models_key: .asciz "modelProviders"
.pm_protocol_key: .asciz "providerProtocol"
.pm_id_key: .asciz "id"
.pm_name_key: .asciz "name"
.pm_base_key: .asciz "baseUrl"
.pm_env_key: .asciz "envKey"
.pm_description_key: .asciz "description"
.pm_generation_key: .asciz "generationConfig"
.pm_context_key: .asciz "contextWindowSize"
.pm_wire_key: .asciz "wireApi"
.pm_openai: .asciz "openai"
.pm_responses: .asciz "openai-responses"
.pm_oauth: .asciz "qwen-oauth"
.pm_anthropic: .asciz "anthropic"
.pm_gemini: .asciz "gemini"
.pm_chat_wire: .asciz "chat-completions"
.pm_responses_wire: .asciz "responses"
.balign 8
.pm_field_map:
 .quad .pm_name_key-.pm_field_map,256,255,0
 .quad .pm_base_key-.pm_field_map,704,2047,0
 .quad .pm_env_key-.pm_field_map,2752,255,0
 .quad .pm_description_key-.pm_field_map,3008,511,0
.section .note.GNU-stack,"",@progbits
