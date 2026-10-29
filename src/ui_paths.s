# Native bounded workspace path completion, metadata only. No subprocesses.
# Prefix matches precede ASCII-insensitive fuzzy scalar-subsequence matches. Unicode
# matches exact Unicode scalars; this is deliberately not dictionary/case folding.
.include "abi.inc"
.equ P_MAX,128
.equ P_DEPTH,12
.equ P_LIMIT,16384
.section .rodata
.P_file: .asciz "file"
.P_directory: .asciz "directory"
.P_ignore: .asciz ".git"
 .asciz "node_modules"
 .asciz ".venv"
 .asciz "venv"
 .asciz "__pycache__"
 .asciz ".cache"
 .asciz "cache"
 .asciz "build"
 .asciz "dist"
 .asciz ".next"
 .asciz ".nuxt"
 .asciz ".turbo"
 .asciz "target"
 .byte 0
.section .bss
.balign 16
.P_out: .skip 8
.P_cap: .skip 8
.P_count: .skip 8
.P_depth: .skip 8
.P_seen: .skip 8
.P_qlen: .skip 8
.P_candlen: .skip 8
.P_kind: .skip 8
.P_score: .skip 8
.P_name: .skip 8
.P_result: .skip 8
.P_fds: .skip P_DEPTH*8
.P_pos: .skip P_DEPTH*8
.P_end: .skip P_DEPTH*8
.P_lens: .skip P_DEPTH*8
.P_scores: .skip P_MAX*8
.P_kinds: .skip P_MAX*8
.P_order: .skip P_MAX*8
.P_query: .skip 513
.P_prefix: .skip 1024
.P_candidate: .skip 1024
.P_stat: .skip 144
.P_paths: .skip P_MAX*1024
.P_entries: .skip P_DEPTH*8192
.P_quote: .skip 6146
.text
.global ui_path_catalog
.type ui_path_catalog,@function
ui_path_catalog:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov [rip+.P_out],rcx
 cmp r8,P_MAX
 jbe .P_cap_ok
 mov r8d,P_MAX
.P_cap_ok:
 mov [rip+.P_cap],r8
 mov qword ptr [rip+.P_count],0
 mov qword ptr [rip+.P_depth],-1
 mov qword ptr [rip+.P_seen],0
 mov qword ptr [rip+.P_result],-22
 test r8,r8
 jz .P_empty
 test rdi,rdi
 jz .P_done
 test rcx,rcx
 jz .P_done
 cmp rdx,512
 ja .P_done
 test rsi,rsi
 jz .P_done
 mov r12,rdi
 mov [rip+.P_qlen],rdx
 # Reject NULs, absolute paths and literal parent components.
 test rdx,rdx
 jz .P_query_copy
 cmp byte ptr [rsi],47
 je .P_done
.P_query_copy:
 lea rdi,[rip+.P_query]
 xor ebx,ebx
 xor ebp,ebp
.P_query_byte:
 cmp rbx,rdx
 jae .P_query_end
 mov al,[rsi+rbx]
 test al,al
 jz .P_done
 cmp al,32
 jb .P_done
 cmp al,47
 jne .P_query_next
 mov rax,rbx
 sub rax,rbp
 cmp rax,2
 jne .P_query_component_done
 cmp word ptr [rsi+rbp],0x2e2e
 je .P_done
.P_query_component_done:
 lea rbp,[rbx+1]
 mov al,47
.P_query_next:
 stosb
 inc rbx
 jmp .P_query_byte
.P_query_end:
 mov rax,rbx
 sub rax,rbp
 cmp rax,2
 jne .P_query_good
 cmp word ptr [rsi+rbp],0x2e2e
 je .P_done
.P_query_good:
 mov byte ptr [rdi],0
 lea rdi,[rip+.P_quote]
 lea rsi,[rip+.P_query]
 mov rdx,[rip+.P_qlen]
 mov ecx,6146
 call json_quote
 test rax,rax
 js .P_done
 mov eax,2
 mov rdi,r12
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .P_error
 mov qword ptr [rip+.P_depth],0
 mov [rip+.P_fds],rax
 mov qword ptr [rip+.P_pos],0
 mov qword ptr [rip+.P_end],0
 mov qword ptr [rip+.P_lens],0
 mov byte ptr [rip+.P_prefix],0
.P_walk:
 cmp qword ptr [rip+.P_seen],P_LIMIT
 jae .P_sort
 mov r12,[rip+.P_depth]
 test r12,r12
 js .P_sort
 lea rax,[rip+.P_pos]
 mov r13,[rax+r12*8]
 lea rax,[rip+.P_end]
 cmp r13,[rax+r12*8]
 jb .P_entry
 mov eax,217
 lea rdi,[rip+.P_fds]
 mov rdi,[rdi+r12*8]
 mov rsi,r12
 shl rsi,13
 lea rdx,[rip+.P_entries]
 add rsi,rdx
 mov edx,8192
 syscall
 cmp rax,-4
 je .P_walk
 test rax,rax
 jle .P_pop
 lea rdx,[rip+.P_end]
 mov [rdx+r12*8],rax
 lea rdx,[rip+.P_pos]
 mov qword ptr [rdx+r12*8],0
 xor r13d,r13d
.P_entry:
 mov rbx,r12
 shl rbx,13
 lea rax,[rip+.P_entries]
 add rbx,rax
 add rbx,r13
 movzx ecx,word ptr [rbx+16]
 cmp ecx,20
 jb .P_pop
 add r13,rcx
 lea rax,[rip+.P_end]
 cmp r13,[rax+r12*8]
 ja .P_pop
 lea rax,[rip+.P_pos]
 mov [rax+r12*8],r13
 inc qword ptr [rip+.P_seen]
 lea rbx,[rbx+19]
 sub ecx,19
 xor eax,eax
.P_namelen:
 cmp eax,ecx
 jae .P_walk
 movzx edx,byte ptr [rbx+rax]
 test edx,edx
 jz .P_name_end
 cmp edx,32
 jb .P_walk
 cmp edx,127
 je .P_walk
 cmp edx,194
 jne .P_name_next_byte
 lea r8,[rax+1]
 cmp r8,rcx
 jae .P_walk
 movzx r8d,byte ptr [rbx+r8]
 sub r8d,128
 cmp r8d,31
 jbe .P_walk
.P_name_next_byte:
 inc eax
 jmp .P_namelen
.P_name_end:
 test eax,eax
 jz .P_walk
 cmp byte ptr [rbx],46
 jne .P_name_valid
 cmp eax,1
 je .P_walk
 cmp eax,2
 jne .P_name_valid
 cmp byte ptr [rbx+1],46
 je .P_walk
.P_name_valid:
 mov [rip+.P_name],rbx
 lea rdx,[rip+.P_lens]
 mov r13,[rdx+r12*8]
 add rax,r13
 cmp rax,1022
 ja .P_walk
 mov [rip+.P_candlen],rax
 lea rdi,[rip+.P_candidate]
 lea rsi,[rip+.P_prefix]
 mov rcx,r13
 rep movsb
 mov rsi,rbx
.P_name_copy:
 lodsb
 stosb
 test al,al
 jnz .P_name_copy
 mov eax,262
 lea rdi,[rip+.P_fds]
 mov rdi,[rdi+r12*8]
 mov rsi,rbx
 lea rdx,[rip+.P_stat]
 mov r10d,256
 syscall
 test rax,rax
 js .P_walk
 mov eax,[rip+.P_stat+24]
 and eax,0xf000
 cmp eax,0x4000
 je .P_is_directory
 cmp eax,0x8000
 jne .P_walk
 mov qword ptr [rip+.P_kind],0
 jmp .P_candidate_ready
.P_is_directory:
 call .P_ignored
 test eax,eax
 jnz .P_walk
 mov qword ptr [rip+.P_kind],1
 mov rax,[rip+.P_candlen]
 lea rdx,[rip+.P_candidate]
 mov byte ptr [rdx+rax],47
 inc rax
 mov byte ptr [rdx+rax],0
 mov [rip+.P_candlen],rax
.P_candidate_ready:
 # Drop ill-formed filesystem names rather than inserting broken UTF-8.
 lea rdi,[rip+.P_quote]
 lea rsi,[rip+.P_candidate]
 mov rdx,[rip+.P_candlen]
 mov ecx,6146
 call json_quote
 test rax,rax
 js .P_recurse
 call .P_match
 test eax,eax
 js .P_recurse
 mov [rip+.P_score],rax
 call .P_retain
.P_recurse:
 cmp qword ptr [rip+.P_kind],1
 jne .P_walk
 mov r12,[rip+.P_depth]
 cmp r12,P_DEPTH-1
 jae .P_walk
 mov eax,257
 lea rdi,[rip+.P_fds]
 mov rdi,[rdi+r12*8]
 mov rsi,[rip+.P_name]
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 js .P_walk
 inc r12
 mov [rip+.P_depth],r12
 lea rdx,[rip+.P_fds]
 mov [rdx+r12*8],rax
 lea rdx,[rip+.P_pos]
 mov qword ptr [rdx+r12*8],0
 lea rdx,[rip+.P_end]
 mov qword ptr [rdx+r12*8],0
 lea rdx,[rip+.P_lens]
 mov rcx,[rip+.P_candlen]
 mov [rdx+r12*8],rcx
 inc rcx
 lea rdi,[rip+.P_prefix]
 lea rsi,[rip+.P_candidate]
 rep movsb
 jmp .P_walk
.P_pop:
 mov eax,3
 lea rdi,[rip+.P_fds]
 mov rdi,[rdi+r12*8]
 syscall
 dec qword ptr [rip+.P_depth]
 mov r12,[rip+.P_depth]
 test r12,r12
 js .P_sort
 lea rdx,[rip+.P_lens]
 mov rax,[rdx+r12*8]
 lea rdx,[rip+.P_prefix]
 mov byte ptr [rdx+rax],0
 jmp .P_walk
# basename in .P_name; exact ignored directory names only.
.P_ignored:
 lea r8,[rip+.P_ignore]
.P_ignore_next:
 cmp byte ptr [r8],0
 je .P_not_ignored
 mov rdi,[rip+.P_name]
 mov rsi,r8
.P_ignore_compare:
 mov al,[rsi]
 cmp al,[rdi]
 jne .P_ignore_skip
 test al,al
 jz .P_yes_ignored
 inc rsi
 inc rdi
 jmp .P_ignore_compare
.P_ignore_skip:
 cmp byte ptr [r8],0
 je .P_ignore_advance
 inc r8
 jmp .P_ignore_skip
.P_ignore_advance:
 inc r8
 jmp .P_ignore_next
.P_yes_ignored:
 mov eax,1
 ret
.P_not_ignored:
 xor eax,eax
 ret
# Fold ASCII A-Z only. AL -> AL.
.P_fold:
 cmp al,65
 jb .P_fold_done
 cmp al,90
 ja .P_fold_done
 add al,32
.P_fold_done:
 ret
# Return 0 prefix,1 fuzzy,-1 no match. Data is bounded NUL-terminated UTF-8.
.P_match:
 lea r8,[rip+.P_query]
 lea r9,[rip+.P_candidate]
 xor ecx,ecx
.P_prefix_loop:
 cmp rcx,[rip+.P_qlen]
 jae .P_prefix_yes
 mov al,[r8+rcx]
 call .P_fold
 mov dl,al
 mov al,[r9+rcx]
 test al,al
 jz .P_match_no
 call .P_fold
 cmp al,dl
 jne .P_fuzzy
 inc rcx
 jmp .P_prefix_loop
.P_prefix_yes:
 xor eax,eax
 ret
.P_fuzzy:
 xor ecx,ecx
 xor edi,edi
.P_fuzzy_query:
 cmp rcx,[rip+.P_qlen]
 jae .P_fuzzy_yes
 mov al,[r8+rcx]
 call .P_cp_len
 mov r10d,eax
.P_fuzzy_path:
 mov al,[r9+rdi]
 test al,al
 jz .P_match_no
 call .P_cp_len
 mov r11d,eax
 cmp r10d,r11d
 jne .P_fuzzy_advance
 cmp r10d,1
 jne .P_fuzzy_unicode
 mov al,[r8+rcx]
 call .P_fold
 mov dl,al
 mov al,[r9+rdi]
 call .P_fold
 cmp al,dl
 jne .P_fuzzy_advance
 jmp .P_fuzzy_take
.P_fuzzy_unicode:
 xor edx,edx
.P_fuzzy_scalar_byte:
 cmp edx,r10d
 jae .P_fuzzy_take
 lea rsi,[r8+rcx]
 mov al,[rsi+rdx]
 lea rsi,[r9+rdi]
 cmp al,[rsi+rdx]
 jne .P_fuzzy_advance
 inc edx
 jmp .P_fuzzy_scalar_byte
.P_fuzzy_take:
 add rcx,r10
 add rdi,r11
 jmp .P_fuzzy_query
.P_fuzzy_advance:
 add rdi,r11
 jmp .P_fuzzy_path
.P_fuzzy_yes:
 mov eax,1
 ret
# UTF-8 was validated before matching; scalar width in bytes from leading AL.
.P_cp_len:
 cmp al,128
 jae .P_cp_multi
 mov eax,1
 ret
.P_cp_multi:
 cmp al,224
 jae .P_cp_three
 mov eax,2
 ret
.P_cp_three:
 cmp al,240
 jae .P_cp_four
 mov eax,3
 ret
.P_cp_four:
 mov eax,4
 ret
.P_match_no:
 mov rax,-1
 ret
# Compare path indices EDI,ESI. Return eax<0 when first ranks before second.
.P_compare:
 lea r8,[rip+.P_scores]
 mov rax,[r8+rdi*8]
 sub rax,[r8+rsi*8]
 test rax,rax
 jnz .P_cmp_done
 shl rdi,10
 shl rsi,10
 lea r8,[rip+.P_paths]
 add rdi,r8
 add rsi,r8
.P_cmp_str:
 movzx eax,byte ptr [rdi]
 movzx edx,byte ptr [rsi]
 sub eax,edx
 jnz .P_cmp_done
 cmp byte ptr [rdi],0
 je .P_cmp_done
 inc rdi
 inc rsi
 jmp .P_cmp_str
.P_cmp_done:
 ret
.P_retain:
 mov rbx,[rip+.P_count]
 cmp rbx,[rip+.P_cap]
 jb .P_slot_new
 # Select worst retained rank and compare candidate against it.
 xor ebx,ebx
 mov ebp,1
.P_find_worst:
 cmp rbp,[rip+.P_count]
 jae .P_check_candidate
 mov rdi,rbp
 mov rsi,rbx
 call .P_compare
 test eax,eax
 jle .P_worst_next
 mov rbx,rbp
.P_worst_next:
 inc ebp
 jmp .P_find_worst
.P_check_candidate:
 lea r8,[rip+.P_scores]
 mov rax,[rip+.P_score]
 cmp rax,[r8+rbx*8]
 ja .P_retain_done
 jb .P_store_slot
 lea rdi,[rip+.P_candidate]
 mov rsi,rbx
 shl rsi,10
 lea r8,[rip+.P_paths]
 add rsi,r8
.P_cmp_candidate:
 movzx eax,byte ptr [rdi]
 movzx edx,byte ptr [rsi]
 cmp eax,edx
 ja .P_retain_done
 jb .P_store_slot
 test eax,eax
 jz .P_retain_done
 inc rdi
 inc rsi
 jmp .P_cmp_candidate
.P_slot_new:
 inc qword ptr [rip+.P_count]
.P_store_slot:
 lea r8,[rip+.P_scores]
 mov rax,[rip+.P_score]
 mov [r8+rbx*8],rax
 lea r8,[rip+.P_kinds]
 mov rax,[rip+.P_kind]
 mov [r8+rbx*8],rax
 mov rdi,rbx
 shl rdi,10
 lea r8,[rip+.P_paths]
 add rdi,r8
 lea rsi,[rip+.P_candidate]
 mov rcx,[rip+.P_candlen]
 inc rcx
 rep movsb
.P_retain_done:
 ret
.P_sort:
 xor ebx,ebx
 lea r12,[rip+.P_order]
.P_sort_outer:
 cmp rbx,[rip+.P_count]
 jae .P_output
 mov rbp,rbx
.P_sort_inner:
 test rbp,rbp
 jz .P_sort_place
 mov rdi,rbx
 mov rsi,[r12+rbp*8-8]
 call .P_compare
 test eax,eax
 jge .P_sort_place
 mov rax,[r12+rbp*8-8]
 mov [r12+rbp*8],rax
 dec rbp
 jmp .P_sort_inner
.P_sort_place:
 mov [r12+rbp*8],rbx
 inc rbx
 jmp .P_sort_outer
.P_output:
 mov rdi,[rip+.P_out]
 xor ecx,ecx
 lea r13,[rip+.P_kinds]
.P_output_loop:
 cmp rcx,[rip+.P_count]
 jae .P_success
 mov rax,[r12+rcx*8]
 mov rdx,rax
 shl rdx,10
 lea rsi,[rip+.P_paths]
 add rsi,rdx
 mov [rdi],rsi
 mov [rdi+16],rsi
 lea rsi,[rip+.P_file]
 cmp qword ptr [r13+rax*8],0
 je .P_output_desc
 lea rsi,[rip+.P_directory]
.P_output_desc:
 mov [rdi+8],rsi
 add rdi,24
 inc rcx
 jmp .P_output_loop
.P_success:
 mov rax,[rip+.P_count]
 mov [rip+.P_result],rax
 jmp .P_done
.P_empty:
 mov qword ptr [rip+.P_result],0
 jmp .P_done
.P_error:
 mov [rip+.P_result],rax
.P_done:
 # Close every still-open directory even after walk bound/error.
 mov rbx,[rip+.P_depth]
.P_close_loop:
 test rbx,rbx
 js .P_return
 mov eax,3
 lea rdi,[rip+.P_fds]
 mov rdi,[rdi+rbx*8]
 syscall
 dec rbx
 jmp .P_close_loop
.P_return:
 mov rax,[rip+.P_result]
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.section .note.GNU-stack,"",@progbits
