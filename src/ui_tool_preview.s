# Typed tool descriptions and plain-text previews. JSON/text is never evaluated.
# Existing-file context is copied by the serialized UI owner, not read here.
.include "abi.inc"
.equ P_MAX,1048576
.equ P_FIELD,65536
.equ P_OUT,0
.equ P_CAP,8
.equ P_LEN,16
.equ P_ERR,24
.equ P_SRC,32
.equ P_SLEN,40
.equ P_KIND,48
.equ P_PATHLEN,56
.equ P_OLDLEN,64
.equ P_NEWLEN,72
.equ P_CMDLEN,80
.equ P_OLDPTR,88
.equ P_NEWPTR,96
.equ P_FILELEN,104
.equ P_HASCTX,112
.equ P_START,120
.equ P_OLDEND,128
.equ P_NEWEND,136
.equ P_CTXSTART,144
.equ P_ENDCTX,152
.equ P_WIDTH,160
.equ P_OFFSET,168
.equ P_LINE,176
.equ P_COUNT,184
.equ P_PREFIX,192
.equ P_SUFFIX,200
.equ P_NUMBER,208
.equ P_TOKENS,256
.equ P_PATH,P_TOKENS+8192*32
.equ P_OLD,P_PATH+4096
.equ P_NEW,P_OLD+P_FIELD+1
.equ P_CMD,P_NEW+P_FIELD+1
.equ P_FILE,P_CMD+P_FIELD+1
.equ P_KMP,P_FILE+P_MAX+1
.equ P_FRAME,((P_KMP+P_FIELD*4+15)/16)*16+8
.macro PE
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,P_FRAME
 mov rbx,rsp
.endm
.macro PL
 add rsp,P_FRAME
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.endm
.macro PC label
 lea rdi,[rip+\label]
 mov esi,OFFSET FLAT:\label\()_len
 call .P_put
.endm
.text
.globl ui_tool_describe,ui_tool_preview,ui_tool_set_file_context
ui_tool_set_file_context:
 cmp rsi,P_MAX
 ja .P_context_bad
 test rdi,rdi
 jnz .P_context_copy
 test rsi,rsi
 jnz .P_context_bad
 mov qword ptr [rip+.p_has_context],0
 mov qword ptr [rip+.p_context_len],0
 xor eax,eax
 ret
.P_context_copy:
 mov [rip+.p_context_len],rsi
 mov qword ptr [rip+.p_has_context],1
 mov rcx,rsi
 mov rsi,rdi
 lea rdi,[rip+.p_context]
 rep movsb
 xor eax,eax
 ret
.P_context_bad:
 mov qword ptr [rip+.p_has_context],0
 mov qword ptr [rip+.p_context_len],0
 mov rax,-22
 ret
.P_put:
 cmp qword ptr [rbx+P_ERR],0
 jne .P_put_done
 mov rax,[rbx+P_LEN]
 add rax,rsi
 jc .P_cap
 cmp rax,[rbx+P_CAP]
 ja .P_cap
 mov rdx,rdi
 mov rdi,[rbx+P_OUT]
 add rdi,[rbx+P_LEN]
 mov rcx,rsi
 mov rsi,rdx
 rep movsb
 mov [rbx+P_LEN],rax
.P_put_done:
 ret
.P_cap:
 mov qword ptr [rbx+P_ERR],-28
 ret
# Safe text append; RDX1 flattens LF for a single-line title.
.P_safe:
 push r12
 push r13
 push r14
 mov r14,rdx
 mov r12,[rbx+P_LEN]
 cmp qword ptr [rbx+P_ERR],0
 jne .P_safe_done
 mov rdx,[rbx+P_OUT]
 add rdx,r12
 mov rcx,[rbx+P_CAP]
 sub rcx,r12
 call ui_sanitize
 test rax,rax
 js .P_safe_bad
 mov r13,rax
 add [rbx+P_LEN],rax
 test r14,r14
 jz .P_safe_done
 mov rdi,[rbx+P_OUT]
 add rdi,r12
 xor ecx,ecx
.P_flatten:
 cmp rcx,r13
 jae .P_safe_done
 cmp byte ptr [rdi+rcx],10
 jne .P_flatten_next
 mov byte ptr [rdi+rcx],' '
.P_flatten_next:
 inc rcx
 jmp .P_flatten
.P_safe_bad:
 mov [rbx+P_ERR],rax
.P_safe_done:
 pop r14
 pop r13
 pop r12
 ret
.P_finish:
 mov rax,[rbx+P_ERR]
 test rax,rax
 jnz .P_finish_done
 mov rax,[rbx+P_LEN]
 cmp rax,[rbx+P_CAP]
 jae .P_finish_done
 mov rdx,[rbx+P_OUT]
 mov byte ptr [rdx+rax],0
.P_finish_done:
 ret
# keyZ,dst,cap ->decoded length/-1missing/-22malformed. No source NUL required.
.P_field:
 push r12
 push r13
 push r14
 mov r12,rsi
 mov r13,rdx
 mov rcx,rdi
 mov rdi,[rbx+P_SRC]
 lea rsi,[rbx+P_TOKENS]
 xor edx,edx
 call json_find
 test rax,rax
 js .P_field_missing
 shl rax,5
 lea rdx,[rbx+P_TOKENS]
 add rdx,rax
 cmp qword ptr [rdx+T_TYPE],JT_STRING
 jne .P_field_bad
 mov rsi,[rbx+P_SRC]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 mov rdi,r12
 lea rcx,[r13-1]
 call json_decode
 test rax,rax
 js .P_field_bad
 mov byte ptr [r12+rax],0
 jmp .P_field_return
.P_field_missing:
 mov rax,-1
 jmp .P_field_return
.P_field_bad:
 mov rax,-22
.P_field_return:
 pop r14
 pop r13
 pop r12
 ret
# Initialize from original public args. The only persistent state is filecontext.
.P_init:
 push r12
 push r13
 push r14
 mov [rbx+P_OUT],rcx
 mov [rbx+P_CAP],r8
 mov [rbx+P_SRC],rsi
 mov [rbx+P_SLEN],rdx
 mov qword ptr [rbx+P_LEN],0
 mov qword ptr [rbx+P_ERR],0
 mov qword ptr [rbx+P_WIDTH],1
 mov r12,rdi
 mov rax,[rip+.p_has_context]
 mov [rbx+P_HASCTX],rax
 lea r13,[rip+.p_names]
.P_kind_loop:
 mov rsi,[r13]
 test rsi,rsi
 jz .P_unsupported
 lea rax,[rip+.p_names]
 add rsi,rax
 mov rdi,r12
 call qx_streq
 test eax,eax
 jnz .P_kind_found
 add r13,16
 jmp .P_kind_loop
.P_kind_found:
 mov rax,[r13+8]
 mov [rbx+P_KIND],rax
 mov rdi,[rbx+P_SRC]
 mov rsi,[rbx+P_SLEN]
 cmp rsi,P_MAX
 ja .P_invalid
 lea rdx,[rbx+P_TOKENS]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .P_invalid
 cmp qword ptr [rbx+P_TOKENS],JT_OBJECT
 jne .P_invalid
 cmp qword ptr [rbx+P_KIND],4
 je .P_load_command
 lea rdi,[rip+.p_path_key]
 lea rsi,[rbx+P_PATH]
 mov edx,4096
 call .P_field
 cmp rax,-1
 jne .P_have_path
 lea rdi,[rip+.p_file_path_key]
 lea rsi,[rbx+P_PATH]
 mov edx,4096
 call .P_field
.P_have_path:
 test rax,rax
 jle .P_invalid
 mov [rbx+P_PATHLEN],rax
 xor ecx,ecx
.P_path_nul:
 cmp rcx,rax
 jae .P_load_kind
 cmp byte ptr [rbx+rcx+P_PATH],0
 je .P_invalid
 inc rcx
 jmp .P_path_nul
.P_load_kind:
 cmp qword ptr [rbx+P_KIND],1
 je .P_load_write
 cmp qword ptr [rbx+P_KIND],2
 je .P_load_edit
 xor eax,eax
 jmp .P_init_return
.P_load_write:
 lea rdi,[rip+.p_content_key]
 lea rsi,[rbx+P_NEW]
 mov edx,P_FIELD+1
 call .P_field
 test rax,rax
 js .P_invalid
 mov [rbx+P_NEWLEN],rax
 xor eax,eax
 jmp .P_init_return
.P_load_edit:
 lea rdi,[rip+.p_old_key]
 lea rsi,[rbx+P_OLD]
 mov edx,P_FIELD+1
 call .P_field
 test rax,rax
 js .P_invalid
 mov [rbx+P_OLDLEN],rax
 lea rdi,[rip+.p_new_key]
 lea rsi,[rbx+P_NEW]
 mov edx,P_FIELD+1
 call .P_field
 test rax,rax
 js .P_invalid
 mov [rbx+P_NEWLEN],rax
 xor eax,eax
 jmp .P_init_return
.P_load_command:
 lea rdi,[rip+.p_command_key]
 lea rsi,[rbx+P_CMD]
 mov edx,P_FIELD+1
 call .P_field
 test rax,rax
 jle .P_invalid
 mov [rbx+P_CMDLEN],rax
 xor eax,eax
 jmp .P_init_return
.P_unsupported:
 mov rax,-1
 jmp .P_init_return
.P_invalid:
 mov rax,-22
.P_init_return:
 pop r14
 pop r13
 pop r12
 ret

ui_tool_describe:
 PE
 call .P_init
 test rax,rax
 js .P_describe_return
 cmp qword ptr [rbx+P_KIND],1
 je .P_describe_write
 cmp qword ptr [rbx+P_KIND],2
 je .P_describe_edit
 cmp qword ptr [rbx+P_KIND],3
 je .P_describe_read
 PC .p_shell_label
 lea rdi,[rbx+P_CMD]
 mov rsi,[rbx+P_CMDLEN]
 mov edx,1
 call .P_safe
 jmp .P_describe_arrow
.P_describe_write:
 PC .p_write_label
 jmp .P_describe_path
.P_describe_read:
 PC .p_read_label
 jmp .P_describe_path
.P_describe_edit:
 PC .p_edit_label
 cmp qword ptr [rbx+P_OLDLEN],0
 jne .P_describe_edit_change
 PC .p_create
 jmp .P_describe_path
.P_describe_edit_change:
 mov rcx,[rbx+P_OLDLEN]
 cmp rcx,[rbx+P_NEWLEN]
 jne .P_describe_path
 lea rdi,[rbx+P_OLD]
 lea rsi,[rbx+P_NEW]
 repe cmpsb
 jne .P_describe_path
 PC .p_unchanged
.P_describe_path:
 lea rdi,[rbx+P_PATH]
 mov rsi,[rbx+P_PATHLEN]
 mov edx,1
 call .P_safe
.P_describe_arrow:
 PC .p_arrow
 call .P_finish
.P_describe_return:
 PL

# Line count and byteprefix line-number helpers; final LF does not add a line.
.P_count_lines:
 mov eax,1
 xor ecx,ecx
.P_count_loop:
 cmp rcx,rsi
 jae .P_count_done
 cmp byte ptr [rdi+rcx],10
 jne .P_count_next
 inc rax
.P_count_next:
 inc rcx
 jmp .P_count_loop
.P_count_done:
 test rsi,rsi
 jz .P_count_return
 cmp byte ptr [rdi+rsi-1],10
 jne .P_count_return
 dec rax
 test rax,rax
 jnz .P_count_return
 inc rax
.P_count_return:
 ret
.P_prefix_line:
 mov eax,1
 xor ecx,ecx
.P_prefix_loop:
 cmp rcx,rsi
 jae .P_prefix_done
 cmp byte ptr [rdi+rcx],10
 jne .P_prefix_next
 inc rax
.P_prefix_next:
 inc rcx
 jmp .P_prefix_loop
.P_prefix_done:
 ret
.P_set_width:
 mov ecx,1
 mov r8d,10
.P_width_digit:
 xor edx,edx
 div r8
 test rax,rax
 jz .P_width_done
 inc rcx
 jmp .P_width_digit
.P_width_done:
 mov [rbx+P_WIDTH],rcx
 ret
# Lines(ptr,len,start-number,prefixchar); char0 newfile vs'-','+',' ' diff.
.P_lines:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,16
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov [rsp],rcx
 xor r15d,r15d
 test r13,r13
 jnz .P_lines_loop
 test rcx,rcx
 jnz .P_lines_done
.P_lines_loop:
 mov rbp,r15
.P_line_end:
 cmp rbp,r13
 jae .P_line_emit
 cmp byte ptr [r12+rbp],10
 je .P_line_emit
 inc rbp
 jmp .P_line_end
.P_line_emit:
 PC .p_space
 lea rdi,[rbx+P_NUMBER]
 mov rsi,r14
 call qx_uint
 mov [rsp+8],rax
 mov r8,[rbx+P_WIDTH]
 sub r8,rax
 jbe .P_line_number
 mov rax,r8
.P_line_pad:
 push rax
 sub rsp,8
 PC .p_space
 add rsp,8
 pop rax
 dec rax
 jnz .P_line_pad
.P_line_number:
 lea rdi,[rbx+P_NUMBER]
 mov rsi,[rsp+8]
 call .P_put
 PC .p_space
 cmp qword ptr [rsp],0
 je .P_line_content
 lea rdi,[rsp]
 mov esi,1
 call .P_put
 PC .p_space
.P_line_content:
 lea rdi,[r12+r15]
 mov rsi,rbp
 sub rsi,r15
 xor edx,edx
 call .P_safe
 PC .p_newline
 inc r14
 lea r15,[rbp+1]
 cmp r15,r13
 jb .P_lines_loop
.P_lines_done:
 add rsp,16
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

# Native edit has one exact occurrence. KMP avoids quadratic repeated-prefix
# searches, reports missing or ambiguous context rather than inventing a diff.
.P_replace:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12,[rbx+P_OLDLEN]
 test r12,r12
 jz .P_replace_bad
 lea r13,[rbx+P_OLD]
 lea r14,[rbx+P_KMP]
 mov dword ptr [r14],0
 mov r8d,1
 xor r9d,r9d
.P_kmp_build:
 cmp r8,r12
 jae .P_kmp_search_start
 mov al,[r13+r8]
 cmp al,[r13+r9]
 je .P_kmp_equal
 test r9,r9
 jz .P_kmp_zero
 mov r9d,[r14+r9*4-4]
 jmp .P_kmp_build
.P_kmp_equal:
 inc r9
 mov [r14+r8*4],r9d
 inc r8
 jmp .P_kmp_build
.P_kmp_zero:
 mov dword ptr [r14+r8*4],0
 inc r8
 jmp .P_kmp_build
.P_kmp_search_start:
 lea r15,[rip+.p_context]
 mov rbp,[rip+.p_context_len]
 xor r8d,r8d
 xor r9d,r9d
 mov r10,-1
.P_kmp_search:
 cmp r8,rbp
 jae .P_kmp_done
 mov al,[r15+r8]
 cmp al,[r13+r9]
 je .P_kmp_search_equal
 test r9,r9
 jz .P_kmp_search_next
 mov r9d,[r14+r9*4-4]
 jmp .P_kmp_search
.P_kmp_search_next:
 inc r8
 jmp .P_kmp_search
.P_kmp_search_equal:
 inc r8
 inc r9
 cmp r9,r12
 jb .P_kmp_search
 cmp r10,-1
 jne .P_replace_bad
 mov r10,r8
 sub r10,r12
 mov r9d,[r14+r9*4-4]
 jmp .P_kmp_search
.P_kmp_done:
 cmp r10,-1
 je .P_replace_bad
 mov rax,rbp
 sub rax,r12
 add rax,[rbx+P_NEWLEN]
 cmp rax,P_MAX
 ja .P_replace_bad
 mov [rbx+P_FILELEN],rax
 lea rdi,[rbx+P_FILE]
 mov rsi,r15
 mov rcx,r10
 rep movsb
 lea rsi,[rbx+P_NEW]
 mov rcx,[rbx+P_NEWLEN]
 rep movsb
 lea rsi,[r15+r10]
 add rsi,r12
 mov rcx,rbp
 sub rcx,r10
 sub rcx,r12
 rep movsb
 lea rax,[rbx+P_FILE]
 mov [rbx+P_NEWPTR],rax
 xor eax,eax
 jmp .P_replace_done
.P_replace_bad:
 mov rax,-22
.P_replace_done:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

# Expand exclusive changed-byte endpoint to a full line, without reading pastEOF.
.P_expand_end:
 cmp rdx,rsi
 jae .P_expand_done
 test rdx,rdx
 jz .P_expand_scan
 cmp byte ptr [rdi+rdx-1],10
 je .P_expand_done
.P_expand_scan:
 cmp rdx,rsi
 jae .P_expand_done
 cmp byte ptr [rdi+rdx],10
 je .P_expand_lf
 inc rdx
 jmp .P_expand_scan
.P_expand_lf:
 inc rdx
.P_expand_done:
 mov rax,rdx
 ret

.P_diff:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12,[rbx+P_OLDPTR]
 mov r13,[rip+.p_context_len]
 mov r14,[rbx+P_NEWPTR]
 mov r15,[rbx+P_FILELEN]
 xor ebp,ebp
.P_diff_prefix:
 cmp rbp,r13
 jae .P_diff_prefix_done
 cmp rbp,r15
 jae .P_diff_prefix_done
 mov al,[r12+rbp]
 cmp al,[r14+rbp]
 jne .P_diff_prefix_done
 inc rbp
 jmp .P_diff_prefix
.P_diff_prefix_done:
 mov [rbx+P_PREFIX],rbp
 cmp rbp,r13
 jne .P_diff_suffix_start
 cmp rbp,r15
 jne .P_diff_suffix_start
 PC .p_no_changes
 jmp .P_diff_return
.P_diff_suffix_start:
 xor r8d,r8d
.P_diff_suffix:
 mov rax,r13
 sub rax,r8
 cmp rax,rbp
 jbe .P_diff_suffix_done
 mov rdx,r15
 sub rdx,r8
 cmp rdx,rbp
 jbe .P_diff_suffix_done
 mov al,[r12+rax-1]
 cmp al,[r14+rdx-1]
 jne .P_diff_suffix_done
 inc r8
 jmp .P_diff_suffix
.P_diff_suffix_done:
 mov [rbx+P_SUFFIX],r8
.P_diff_line_start:
 test rbp,rbp
 jz .P_diff_start_done
 cmp byte ptr [r12+rbp-1],10
 je .P_diff_start_done
 dec rbp
 jmp .P_diff_line_start
.P_diff_start_done:
 mov [rbx+P_START],rbp
 mov rdi,r12
 mov rsi,r13
 mov rdx,r13
 sub rdx,[rbx+P_SUFFIX]
 cmp rdx,rbp
 jbe .P_diff_old_end_same
 call .P_expand_end
 jmp .P_diff_old_end_set
.P_diff_old_end_same:
 mov rax,rbp
.P_diff_old_end_set:
 mov [rbx+P_OLDEND],rax
 mov rdi,r14
 mov rsi,r15
 mov rdx,r15
 sub rdx,[rbx+P_SUFFIX]
 cmp rdx,rbp
 jbe .P_diff_new_end_same
 call .P_expand_end
 jmp .P_diff_new_end_set
.P_diff_new_end_same:
 mov rax,rbp
.P_diff_new_end_set:
 mov [rbx+P_NEWEND],rax
 mov r8d,3
.P_diff_context_before:
 test rbp,rbp
 jz .P_diff_context_ready
 dec rbp
.P_diff_prev_line:
 test rbp,rbp
 jz .P_diff_previous_done
 cmp byte ptr [r12+rbp-1],10
 je .P_diff_previous_done
 dec rbp
 jmp .P_diff_prev_line
.P_diff_previous_done:
 dec r8
 jnz .P_diff_context_before
.P_diff_context_ready:
 mov [rbx+P_CTXSTART],rbp
 mov rdi,r12
 mov rsi,r13
 call .P_count_lines
 mov rbp,rax
 mov rdi,r14
 mov rsi,r15
 call .P_count_lines
 cmp rax,rbp
 cmovb rax,rbp
 call .P_set_width
 # Unchanged leading context, physical line numbering from the actual file.
 mov rdi,r12
 mov rsi,[rbx+P_CTXSTART]
 call .P_prefix_line
 mov rdx,rax
 mov rsi,[rbx+P_START]
 sub rsi,[rbx+P_CTXSTART]
 mov rdi,r12
 add rdi,[rbx+P_CTXSTART]
 mov ecx,' '
 call .P_lines
 mov rdi,r12
 mov rsi,[rbx+P_START]
 call .P_prefix_line
 mov [rbx+P_LINE],rax
 mov rdx,rax
 mov rsi,[rbx+P_OLDEND]
 sub rsi,[rbx+P_START]
 mov rdi,r12
 add rdi,[rbx+P_START]
 mov ecx,'-'
 call .P_lines
 mov rdx,[rbx+P_LINE]
 mov rsi,[rbx+P_NEWEND]
 sub rsi,[rbx+P_START]
 mov rdi,r14
 add rdi,[rbx+P_START]
 mov ecx,'+'
 call .P_lines
 # Three unchanged trailing context lines in the post-edit file.
 mov rbp,[rbx+P_NEWEND]
 mov r8d,3
.P_diff_after:
 cmp rbp,r15
 jae .P_diff_after_ready
 mov al,[r14+rbp]
 inc rbp
 cmp al,10
 jne .P_diff_after
 dec r8
 jnz .P_diff_after
.P_diff_after_ready:
 mov [rbx+P_ENDCTX],rbp
 mov rdi,r14
 mov rsi,[rbx+P_NEWEND]
 call .P_prefix_line
 mov rdx,rax
 mov rsi,[rbx+P_ENDCTX]
 sub rsi,[rbx+P_NEWEND]
 mov rdi,r14
 add rdi,[rbx+P_NEWEND]
 mov ecx,' '
 call .P_lines
.P_diff_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

ui_tool_preview:
 PE
 call .P_init
 test rax,rax
 js .P_preview_return
 cmp qword ptr [rbx+P_KIND],3
 je .P_preview_unsupported
 cmp qword ptr [rbx+P_KIND],4
 je .P_preview_shell
 PC .p_newline
 cmp qword ptr [rbx+P_HASCTX],0
 je .P_preview_no_context
 lea rax,[rip+.p_context]
 mov [rbx+P_OLDPTR],rax
 cmp qword ptr [rbx+P_KIND],2
 je .P_preview_replace
 lea rax,[rbx+P_NEW]
 mov [rbx+P_NEWPTR],rax
 mov rax,[rbx+P_NEWLEN]
 mov [rbx+P_FILELEN],rax
 jmp .P_preview_diff
.P_preview_replace:
 call .P_replace
 test rax,rax
 js .P_preview_return
.P_preview_diff:
 call .P_diff
 jmp .P_preview_question
.P_preview_no_context:
 cmp qword ptr [rbx+P_KIND],2
 je .P_preview_unsupported
 lea rdi,[rbx+P_NEW]
 mov rsi,[rbx+P_NEWLEN]
 call .P_count_lines
 call .P_set_width
 lea rdi,[rbx+P_NEW]
 mov rsi,[rbx+P_NEWLEN]
 mov edx,1
 xor ecx,ecx
 call .P_lines
.P_preview_question:
 PC .p_apply_question
 call .P_finish
 jmp .P_preview_return
.P_preview_shell:
 PC .p_shell_prefix
 lea rdi,[rbx+P_CMD]
 mov rsi,[rbx+P_CMDLEN]
 xor edx,edx
 call .P_safe
 PC .p_execution_question
 xor r12d,r12d
.P_shell_root:
 cmp r12,[rbx+P_CMDLEN]
 jae .P_shell_question
 cmp byte ptr [rbx+r12+P_CMD],' '
 je .P_shell_question
 cmp byte ptr [rbx+r12+P_CMD],10
 je .P_shell_question
 inc r12
 jmp .P_shell_root
.P_shell_question:
 lea rdi,[rbx+P_CMD]
 mov rsi,r12
 mov edx,1
 call .P_safe
 PC .p_question_end
 call .P_finish
 jmp .P_preview_return
.P_preview_unsupported:
 mov rax,-1
.P_preview_return:
 PL

.section .rodata
.p_path_key: .asciz "path"
.equ .p_path_key_len,.-.p_path_key-1
.p_file_path_key: .asciz "file_path"
.equ .p_file_path_key_len,.-.p_file_path_key-1
.p_content_key: .asciz "content"
.equ .p_content_key_len,.-.p_content_key-1
.p_old_key: .asciz "old_string"
.equ .p_old_key_len,.-.p_old_key-1
.p_new_key: .asciz "new_string"
.equ .p_new_key_len,.-.p_new_key-1
.p_command_key: .asciz "command"
.equ .p_command_key_len,.-.p_command_key-1
.p_space: .asciz " "
.equ .p_space_len,.-.p_space-1
.p_newline: .asciz "\012"
.equ .p_newline_len,.-.p_newline-1
.p_write_label: .asciz "WriteFile Writing to "
.equ .p_write_label_len,.-.p_write_label-1
.p_edit_label: .asciz "Edit "
.equ .p_edit_label_len,.-.p_edit_label-1
.p_read_label: .asciz "ReadFile "
.equ .p_read_label_len,.-.p_read_label-1
.p_shell_label: .asciz "Shell "
.equ .p_shell_label_len,.-.p_shell_label-1
.p_create: .asciz "Create "
.equ .p_create_len,.-.p_create-1
.p_unchanged: .asciz "No file changes to "
.equ .p_unchanged_len,.-.p_unchanged-1
.p_arrow: .asciz " \342\206\220"
.equ .p_arrow_len,.-.p_arrow-1
.p_apply_question: .asciz "\012Apply this change?"
.equ .p_apply_question_len,.-.p_apply_question-1
.p_shell_prefix: .asciz "\012  "
.equ .p_shell_prefix_len,.-.p_shell_prefix-1
.p_execution_question: .asciz "\012\012Allow execution of: '"
.equ .p_execution_question_len,.-.p_execution_question-1
.p_question_end: .asciz "'?"
.equ .p_question_end_len,.-.p_question_end-1
.p_no_changes: .asciz "No changes detected.\012"
.equ .p_no_changes_len,.-.p_no_changes-1
.balign 8
.p_names:
 .quad .p_name_write_file-.p_names,1
 .quad .p_name_edit_file-.p_names,2
 .quad .p_name_replace-.p_names,2
 .quad .p_name_read_file-.p_names,3
 .quad .p_name_run_shell-.p_names,4
 .quad .p_name_run_shell_command-.p_names,4
 .quad 0,0
.p_name_write_file: .asciz "write_file"
.p_name_edit_file: .asciz "edit_file"
.p_name_replace: .asciz "replace"
.p_name_read_file: .asciz "read_file"
.p_name_run_shell: .asciz "run_shell"
.p_name_run_shell_command: .asciz "run_shell_command"
.bss
.balign 8
.p_has_context: .skip 8
.p_context_len: .skip 8
.balign 16
.p_context: .skip 1048576
.section .note.GNU-stack,"",@progbits
