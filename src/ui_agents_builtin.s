# Native immutable source builtin catalog, prompt and full metadata views.
.include "abi.inc"
.include "ui_agents_builtin.inc"
.section .text
.global ui_agent_builtin_catalog,ui_agent_builtin_read,ui_agent_builtin_prompt,ui_agent_builtin_policy
ui_agent_builtin_catalog:
 xor eax,eax
 test rdi,rdi
 jz .Mb_catalog_ret
 cmp rsi,6
 jbe .Mb_catalog_cap
 mov esi,6
.Mb_catalog_cap:
 lea r8,[rip+.Mb_name_table]
 lea r9,[rip+.Mb_desc_table]
 lea r10,[rip+.Mb_value_table]
.Mb_catalog_next:
 cmp rax,rsi
 jae .Mb_catalog_ret
 imul rcx,rax,24
 mov rdx,[r8+rax*8]
 mov [rdi+rcx],rdx
 mov rdx,[r9+rax*8]
 mov [rdi+rcx+8],rdx
 mov rdx,[r10+rax*8]
 mov [rdi+rcx+16],rdx
 inc rax
 jmp .Mb_catalog_next
.Mb_catalog_ret:
 ret
# nameZ or <builtin:name> lookup, ASCII case-insensitive as source loadSubagent.
.Mb_lookup:
 test rdi,rdi
 jz .Mb_missing
 mov r8,rdi
 cmp byte ptr [rdi],60
 jne .Mb_lookup_direct
 movabs rax,0x6e69746c6975623c
 cmp qword ptr [rdi],rax
 jne .Mb_missing
 cmp byte ptr [rdi+8],58
 jne .Mb_missing
 add r8,9
.Mb_lookup_direct:
 xor eax,eax
 lea r9,[rip+.Mb_name_table]
.Mb_lookup_next:
 cmp eax,6
 jae .Mb_missing
 mov rsi,[r9+rax*8]
 xor ecx,ecx
.Mb_lookup_char:
 mov dl,[rsi+rcx]
 test dl,dl
 jz .Mb_lookup_end
 mov r10b,[r8+rcx]
 cmp dl,65
 jb .Mb_lookup_fold_input
 cmp dl,90
 ja .Mb_lookup_fold_input
 add dl,32
.Mb_lookup_fold_input:
 cmp r10b,65
 jb .Mb_lookup_compare
 cmp r10b,90
 ja .Mb_lookup_compare
 add r10b,32
.Mb_lookup_compare:
 cmp dl,r10b
 jne .Mb_lookup_advance
 inc ecx
 jmp .Mb_lookup_char
.Mb_lookup_end:
 cmp byte ptr [r8+rcx],0
 je .Mb_lookup_ret
 cmp byte ptr [rdi],60
 jne .Mb_lookup_advance
 cmp byte ptr [r8+rcx],62
 jne .Mb_lookup_advance
 cmp byte ptr [r8+rcx+1],0
 je .Mb_lookup_ret
.Mb_lookup_advance:
 inc eax
 jmp .Mb_lookup_next
.Mb_missing:
 mov rax,-2
.Mb_lookup_ret:
 ret
ui_agent_builtin_policy:
 sub rsp,8
 call .Mb_lookup
 add rsp,8
 test rax,rax
 js .Mb_policy_ret
 cmp eax,1
 je .Mb_policy_readonly
 cmp eax,4
 je .Mb_policy_acp
 cmp eax,5
 je .Mb_policy_codex
 mov eax,1
 ret
.Mb_policy_readonly:
 xor eax,eax
 ret
.Mb_policy_acp:
 mov rax,-3
 ret
.Mb_policy_codex:
 mov rax,-4
.Mb_policy_ret:
 ret
ui_agent_builtin_read:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 call .Mb_lookup
 test rax,rax
 js .Mb_copy_ret
 lea rbx,[rip+.Mb_detail_table]
 jmp .Mb_copy_table
ui_agent_builtin_prompt:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 call .Mb_lookup
 test rax,rax
 js .Mb_copy_ret
 lea rbx,[rip+.Mb_prompt_table]
.Mb_copy_table:
 test r12,r12
 jz .Mb_copy_bad
 mov rsi,[rbx+rax*8]
 xor ecx,ecx
.Mb_copy_length:
 cmp byte ptr [rsi+rcx],0
 je .Mb_copy_ready
 inc rcx
 jmp .Mb_copy_length
.Mb_copy_ready:
 cmp rcx,r13
 jae .Mb_copy_full
 mov rax,rcx
 mov rdi,r12
 rep movsb
 mov byte ptr [rdi],0
 jmp .Mb_copy_ret
.Mb_copy_full:
 mov rax,-28
 jmp .Mb_copy_ret
.Mb_copy_bad:
 mov rax,-22
.Mb_copy_ret:
 pop r13
 pop r12
 pop rbx
 ret
.section .note.GNU-stack,"",@progbits
