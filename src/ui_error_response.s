# Bounded provider HTTP errors: plain sanitized UTF8, no terminal/model escapes.
.include "abi.inc"
.equ E_MAX,16384
.equ E_TOKENS,128
.equ E_DECODE,E_TOKENS+8192*32
.equ E_CLEAN,E_DECODE+E_MAX
.equ E_FRAME,((E_CLEAN+E_MAX*4+15)/16)*16+8
.text
.globl ui_error_describe
# status,body,length,out,capacity ->output length/-22/-28.
ui_error_describe:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,E_FRAME
 mov rbx,rsp
 mov [rbx],rdi
 mov [rbx+8],rsi
 mov [rbx+16],rdx
 mov [rbx+24],rcx
 mov [rbx+32],r8
 mov qword ptr [rbx+40],0
 mov qword ptr [rbx+48],0
 cmp rdx,E_MAX
 jbe .E_input_bound
 mov qword ptr [rbx+16],E_MAX
 mov qword ptr [rbx+48],1
.E_input_bound:
 test rdx,rdx
 jz .E_generic
 test rsi,rsi
 jz .E_invalid
 mov rdi,rsi
 mov rsi,[rbx+16]
 lea rdx,[rbx+E_TOKENS]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .E_raw
 cmp qword ptr [rbx+E_TOKENS],1
 jne .E_raw
 xor edx,edx
 lea rcx,[rip+.e_error]
 call .E_find
 test rax,rax
 js .E_root_message
 mov r12,rax
 shl rax,5
 cmp qword ptr [rbx+rax+E_TOKENS],3
 je .E_decode
 cmp qword ptr [rbx+rax+E_TOKENS],1
 jne .E_root_message
 mov rdx,r12
 lea rcx,[rip+.e_message]
 call .E_find
 test rax,rax
 js .E_root_message
 shl rax,5
 cmp qword ptr [rbx+rax+E_TOKENS],3
 je .E_decode
.E_root_message:
 xor edx,edx
 lea rcx,[rip+.e_message]
 call .E_find
 test rax,rax
 js .E_raw
 shl rax,5
 cmp qword ptr [rbx+rax+E_TOKENS],3
 jne .E_raw
.E_decode:
 mov rsi,[rbx+8]
 add rsi,[rbx+rax+E_TOKENS+8]
 mov rdx,[rbx+rax+E_TOKENS+16]
 lea rdi,[rbx+E_DECODE]
 mov ecx,E_MAX
 call json_decode
 test rax,rax
 jle .E_raw
 lea rdi,[rbx+E_DECODE]
 mov rsi,rax
 jmp .E_sanitize
.E_raw:
 mov rdi,[rbx+8]
 mov rsi,[rbx+16]
.E_sanitize:
 lea rdx,[rbx+E_CLEAN]
 mov ecx,E_MAX*4
 call ui_sanitize
 test rax,rax
 js .E_return
 mov r12,rax
 lea r13,[rbx+E_CLEAN]
 # Whitespace-only output should still describe the failed request.
 xor ecx,ecx
.E_nonempty:
 cmp rcx,r12
 jae .E_generic
 cmp byte ptr [r13+rcx],32
 ja .E_prefix
 inc rcx
 jmp .E_nonempty
.E_generic:
 lea r13,[rip+.e_failed]
 mov r12d,OFFSET FLAT:.e_failed_len
.E_prefix:
 lea rdi,[rip+.e_http]
 mov esi,5
 call .E_put
 lea rdi,[rbx+64]
 mov rsi,[rbx]
 call qx_uint
 lea rdi,[rbx+64]
 mov rsi,rax
 call .E_put
 lea rdi,[rip+.e_colon]
 mov esi,2
 call .E_put
 mov rdi,r13
 mov rsi,r12
 call .E_put
 cmp qword ptr [rbx+48],0
 je .E_complete
 lea rdi,[rip+.e_truncated]
 mov esi,OFFSET FLAT:.e_truncated_len
 call .E_put
.E_complete:
 mov rax,[rbx+40]
 jmp .E_return
.E_find:
 mov rdi,[rbx+8]
 lea rsi,[rbx+E_TOKENS]
 jmp json_find
.E_put:
 cmp qword ptr [rbx+40],0
 js .E_put_done
 mov rax,[rbx+40]
 add rax,rsi
 jc .E_capacity
 cmp rax,[rbx+32]
 ja .E_capacity
 mov rcx,rsi
 mov rsi,rdi
 mov rdi,[rbx+24]
 test rdi,rdi
 jz .E_bad_output
 add rdi,[rbx+40]
 rep movsb
 mov [rbx+40],rax
.E_put_done:
 ret
.E_capacity:
 mov qword ptr [rbx+40],-28
 ret
.E_bad_output:
 mov qword ptr [rbx+40],-22
 ret
.E_invalid:
 mov rax,-22
.E_return:
 add rsp,E_FRAME
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.section .rodata
.e_error: .asciz "error"
.e_message: .asciz "message"
.e_http: .ascii "HTTP "
.e_colon: .ascii ": "
.e_failed: .ascii "request failed"
.equ .e_failed_len,.-.e_failed
.e_truncated: .ascii " [response truncated]"
.equ .e_truncated_len,.-.e_truncated
.section .note.GNU-stack,"",@progbits
