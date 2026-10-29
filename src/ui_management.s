# Native local agent/extension management. No hooks, processes or remote fetches.
.include "abi.inc"
.equ MG_MAX,64
.equ MG_STRIDE,4608
.section .rodata
.Mg_slash: .asciz "/"
.Mg_dot: .asciz "."
.Mg_qwen: .asciz ".qwen"
.Mg_agents: .asciz "agents"
.Mg_extensions: .asciz "extensions"
.Mg_agent_suffix: .asciz "/.qwen/agents/"
.Mg_extension_suffix: .asciz "/.qwen/extensions/"
.Mg_manifest: .asciz "qwen-extension.json"
.Mg_md: .asciz ".md"
.Mg_user: .asciz "User"
.Mg_project: .asciz "Project"
.Mg_disabled: .asciz ".qwen-x86-disabled"
.Mg_enabled_text: .asciz " · enabled"
.Mg_disabled_text: .asciz " · disabled"
.Mg_empty_object: .ascii "{}"
.Mg_hex: .ascii "0123456789abcdef"
.Mg_temp_prefix: .ascii ".qwen-tmp-"
.section .bss
.balign 16
.Mg_roots: .skip 8192
.Mg_prefixes: .skip 16384
.Mg_allow: .skip 8
.Mg_count: .skip 8
.Mg_cap: .skip 8
.Mg_out: .skip 8
.Mg_kind: .skip 8
.Mg_scope: .skip 8
.Mg_fd: .skip 8
.Mg_namebuf: .skip 256
.Mg_temp: .skip 64
.Mg_random: .skip 16
.Mg_strings: .skip MG_MAX*MG_STRIDE
.Mg_scopes: .skip MG_MAX*8
.Mg_raw: .skip 65537
.Mg_quote: .skip 393224
.Mg_tokens: .skip 262144
.Mg_stat: .skip 144
.section .text
.Mg_zlen:
 xor eax,eax
.Mg_znext:
 cmp byte ptr [rdi+rax],0
 je .Mg_zdone
 inc rax
 cmp rax,4096
 jb .Mg_znext
 mov rax,-1
.Mg_zdone:
 ret
# ASCII qualified name [A-Za-z0-9_-],length1..63 ->length/-1.
.Mg_name:
 xor eax,eax
.Mg_name_next:
 movzx edx,byte ptr [rdi+rax]
 test edx,edx
 jz .Mg_name_end
 cmp eax,63
 jae .Mg_name_bad
 cmp edx,45
 je .Mg_name_char
 cmp edx,95
 je .Mg_name_char
 mov ecx,edx
 sub ecx,48
 cmp ecx,9
 jbe .Mg_name_char
 or edx,32
 sub edx,97
 cmp edx,25
 ja .Mg_name_bad
.Mg_name_char:
 inc eax
 jmp .Mg_name_next
.Mg_name_end:
 test eax,eax
 jz .Mg_name_bad
 ret
.Mg_name_bad:
 mov rax,-1
 ret
# Safe single directory/file component; no slash, controls, . or ..;max255.
.Mg_component:
 xor eax,eax
.Mg_component_next:
 movzx edx,byte ptr [rdi+rax]
 test edx,edx
 jz .Mg_component_end
 cmp eax,255
 jae .Mg_name_bad
 cmp edx,33
 jb .Mg_name_bad
 cmp edx,127
 jae .Mg_name_bad
 cmp edx,47
 je .Mg_name_bad
 inc eax
 jmp .Mg_component_next
.Mg_component_end:
 test eax,eax
 jz .Mg_name_bad
 cmp byte ptr [rdi],46
 jne .Mg_component_ok
 cmp eax,1
 je .Mg_name_bad
 cmp eax,2
 jne .Mg_component_ok
 cmp byte ptr [rdi+1],46
 je .Mg_name_bad
.Mg_component_ok:
 ret
.Mg_eq:
 xor eax,eax
.Mg_eq_next:
 mov dl,byte ptr [rdi+rax]
 cmp dl,byte ptr [rsi+rax]
 jne .Mg_eq_no
 test dl,dl
 jz .Mg_eq_yes
 inc rax
 jmp .Mg_eq_next
.Mg_eq_yes:
 mov eax,1
 ret
.Mg_eq_no:
 xor eax,eax
 ret
# Open one directory component, never following a symlink.
.Mg_child_dir:
 mov eax,257
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 ret
# Walk every component of a root path with O_NOFOLLOW; no ../ traversal.
.Mg_path_dir:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,256
 mov r12,rdi
 test r12,r12
 jz .Mg_path_bad
 call .Mg_zlen
 test rax,rax
 jle .Mg_path_bad
 mov r15,rax
 mov rdi,-100
 lea rsi,[rip+.Mg_dot]
 cmp byte ptr [r12],47
 jne .Mg_path_open
 lea rsi,[rip+.Mg_slash]
.Mg_path_open:
 call .Mg_child_dir
 test rax,rax
 js .Mg_path_bad
 mov r13,rax
 xor ebx,ebx
.Mg_path_part:
 cmp rbx,r15
 jae .Mg_path_ok
 cmp byte ptr [r12+rbx],47
 jne .Mg_path_collect
 inc rbx
 jmp .Mg_path_part
.Mg_path_collect:
 xor r14d,r14d
.Mg_path_copy:
 cmp rbx,r15
 jae .Mg_path_collected
 mov al,byte ptr [r12+rbx]
 cmp al,47
 je .Mg_path_collected
 cmp r14,255
 jae .Mg_path_close_bad
 mov byte ptr [rsp+r14],al
 inc r14
 inc rbx
 jmp .Mg_path_copy
.Mg_path_collected:
 mov byte ptr [rsp+r14],0
 cmp r14,1
 jne .Mg_path_validate
 cmp byte ptr [rsp],46
 je .Mg_path_part
.Mg_path_validate:
 mov rdi,rsp
 call .Mg_component
 test rax,rax
 js .Mg_path_close_bad
 mov rdi,r13
 mov rsi,rsp
 call .Mg_child_dir
 mov r14,rax
 mov eax,3
 mov rdi,r13
 syscall
 test r14,r14
 js .Mg_path_bad
 mov r13,r14
 jmp .Mg_path_part
.Mg_path_close_bad:
 mov eax,3
 mov rdi,r13
 syscall
.Mg_path_bad:
 mov rax,-1
 jmp .Mg_path_return
.Mg_path_ok:
 mov rax,r13
.Mg_path_return:
 add rsp,256
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Read one regular file(dirfd,name,dst,cap),NUL terminate,returnlen/-1.
.Mg_read_file:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,144
 mov r12,rdx
 mov r13,rcx
 test r13,r13
 jz .Mg_file_bad
 mov eax,257
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Mg_file_bad
 mov r14,rax
 mov eax,5
 mov rdi,r14
 mov rsi,rsp
 syscall
 test rax,rax
 js .Mg_file_close_bad
 mov eax,dword ptr [rsp+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Mg_file_close_bad
 mov eax,107
 syscall
 cmp eax,dword ptr [rsp+28]
 jne .Mg_file_close_bad
 xor ebx,ebx
.Mg_file_read:
 mov eax,0
 mov rdi,r14
 lea rsi,[r12+rbx]
 mov rdx,r13
 sub rdx,rbx
 jz .Mg_file_close_bad
 syscall
 cmp rax,-4
 je .Mg_file_read
 test rax,rax
 js .Mg_file_close_bad
 jz .Mg_file_ok
 add rbx,rax
 jmp .Mg_file_read
.Mg_file_ok:
 mov byte ptr [r12+rbx],0
 mov eax,3
 mov rdi,r14
 syscall
 mov rax,rbx
 jmp .Mg_file_return
.Mg_file_close_bad:
 mov eax,3
 mov rdi,r14
 syscall
.Mg_file_bad:
 mov rax,-1
.Mg_file_return:
 add rsp,144
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Walk bounded128 directory entries with a bound callback(fd,name,type,user1,user2).
.Mg_walk:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8248
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 mov qword ptr [rsp+8192],0
.Mg_walk_batch:
 mov eax,217
 mov rdi,r12
 mov rsi,rsp
 mov edx,8192
 syscall
 cmp rax,-4
 je .Mg_walk_batch
 test rax,rax
 jle .Mg_walk_done
 mov rbx,rsp
 lea rbp,[rsp+rax]
.Mg_walk_entry:
 mov rax,rbp
 sub rax,rbx
 cmp rax,20
 jb .Mg_walk_done
 movzx ecx,word ptr [rbx+16]
 cmp ecx,20
 jb .Mg_walk_done
 cmp rcx,rax
 ja .Mg_walk_done
 lea rax,[rbx+rcx]
 mov qword ptr [rsp+8200],rax
 inc qword ptr [rsp+8192]
 cmp qword ptr [rsp+8192],128
 ja .Mg_walk_done
 sub ecx,19
 xor eax,eax
.Mg_walk_nul:
 cmp byte ptr [rbx+rax+19],0
 je .Mg_walk_component
 inc eax
 cmp eax,ecx
 jb .Mg_walk_nul
 jmp .Mg_walk_next
.Mg_walk_component:
 lea rdi,[rbx+19]
 call .Mg_component
 test rax,rax
 js .Mg_walk_next
 mov rdi,r12
 lea rsi,[rbx+19]
 movzx edx,byte ptr [rbx+18]
 mov rcx,r14
 mov r8,r15
 call r13
.Mg_walk_next:
 mov rbx,qword ptr [rsp+8200]
 cmp rbx,rbp
 jb .Mg_walk_entry
 jmp .Mg_walk_batch
.Mg_walk_done:
 add rsp,8248
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

.global ui_management_config
ui_management_config:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 mov [rip+.Mg_allow],rdx
 xor ebx,ebx
.Mg_cfg_root:
 mov rdi,r12
 test rbx,rbx
 jz .Mg_cfg_root_ptr
 mov rdi,r13
.Mg_cfg_root_ptr:
 test rdi,rdi
 jz .Mg_cfg_bad
 cmp byte ptr [rdi],47
 jne .Mg_cfg_bad
 call .Mg_zlen
 cmp rax,3500
 ja .Mg_cfg_bad
 test rax,rax
 jle .Mg_cfg_bad
 mov rcx,rax
 mov rsi,r12
 test rbx,rbx
 jz .Mg_cfg_copy
 mov rsi,r13
.Mg_cfg_copy:
 mov rdx,rbx
 shl rdx,12
 lea rdi,[rip+.Mg_roots]
 add rdi,rdx
 rep movsb
 mov byte ptr [rdi],0
 # Prefix index scope*2+kind; each4096.
 xor r8d,r8d
.Mg_cfg_prefix:
 mov rax,rbx
 shl rax,1
 add rax,r8
 shl rax,12
 lea rdi,[rip+.Mg_prefixes]
 add rdi,rax
 lea rsi,[rip+.Mg_roots]
 add rsi,rdx
.Mg_cfg_prefix_root:
 lodsb
 test al,al
 jz .Mg_cfg_prefix_suffix
 stosb
 jmp .Mg_cfg_prefix_root
.Mg_cfg_prefix_suffix:
 lea rsi,[rip+.Mg_agent_suffix]
 test r8,r8
 jz .Mg_cfg_prefix_scopy
 lea rsi,[rip+.Mg_extension_suffix]
.Mg_cfg_prefix_scopy:
 lodsb
 stosb
 test al,al
 jnz .Mg_cfg_prefix_scopy
 inc r8
 cmp r8,2
 jb .Mg_cfg_prefix
 inc rbx
 cmp rbx,2
 jb .Mg_cfg_root
 xor eax,eax
 jmp .Mg_cfg_return
.Mg_cfg_bad:
 mov qword ptr [rip+.Mg_allow],0
 mov rax,-22
.Mg_cfg_return:
 pop r13
 pop r12
 pop rbx
 ret

# scope RDI kind RSI create RDX -> directoryfd/-1. All components nofollow.
.Mg_open_tree:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 cmp rdi,1
 ja .Mg_tree_bad
 shl rdi,12
 lea rax,[rip+.Mg_roots]
 add rdi,rax
 call .Mg_path_dir
 test rax,rax
 js .Mg_tree_return
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Mg_qwen]
 call .Mg_open_or_create
 test rax,rax
 js .Mg_tree_close
 mov rbx,rax
 lea rsi,[rip+.Mg_agents]
 test r12,r12
 jz .Mg_tree_leaf
 lea rsi,[rip+.Mg_extensions]
.Mg_tree_leaf:
 mov rdi,rbx
 call .Mg_open_or_create
 test rax,rax
 js .Mg_tree_close
 jmp .Mg_tree_return
.Mg_tree_close:
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Mg_tree_return
.Mg_tree_bad:
 mov rax,-1
.Mg_tree_return:
 pop r13
 pop r12
 pop rbx
 ret
# Open child and close old parent on success; create only when R13 authorized.
.Mg_open_or_create:
 push rbx
 push r12
 push r14
 mov rbx,rdi
 mov r12,rsi
 call .Mg_child_dir
 cmp rax,-2
 jne .Mg_oc_opened
 test r13,r13
 jz .Mg_oc_done
 mov eax,258
 mov rdi,rbx
 mov rsi,r12
 mov edx,448
 syscall
 test rax,rax
 js .Mg_oc_done
 mov rdi,rbx
 mov rsi,r12
 call .Mg_child_dir
.Mg_oc_opened:
 test rax,rax
 js .Mg_oc_done
 mov r14,rax
 mov eax,3
 mov rdi,rbx
 syscall
 mov rax,r14
.Mg_oc_done:
 pop r14
 pop r12
 pop rbx
 ret

.global ui_agent_catalog,ui_extension_catalog
ui_agent_catalog:
 xor edx,edx
 jmp .Mg_catalog
ui_extension_catalog:
 mov edx,1
.Mg_catalog:
 push rbx
 push r12
 push r13
 mov [rip+.Mg_out],rdi
 mov [rip+.Mg_kind],rdx
 mov qword ptr [rip+.Mg_count],0
 cmp rsi,MG_MAX
 jbe .Mg_cat_cap
 mov esi,MG_MAX
.Mg_cat_cap:
 mov [rip+.Mg_cap],rsi
 test rsi,rsi
 jz .Mg_cat_done
 test rdi,rdi
 jz .Mg_cat_bad
 # Project before user, matching source definition precedence.
 mov ebx,1
.Mg_cat_scope:
 mov [rip+.Mg_scope],rbx
 mov rdi,rbx
 mov rsi,[rip+.Mg_kind]
 xor edx,edx
 call .Mg_open_tree
 test rax,rax
 js .Mg_cat_next_scope
 mov r12,rax
 mov rdi,rax
 lea rsi,[rip+.Mg_catalog_entry]
 xor edx,edx
 xor ecx,ecx
 call .Mg_walk
 mov eax,3
 mov rdi,r12
 syscall
.Mg_cat_next_scope:
 dec rbx
 jns .Mg_cat_scope
.Mg_cat_done:
 mov rax,[rip+.Mg_count]
 jmp .Mg_cat_return
.Mg_cat_bad:
 mov rax,-22
.Mg_cat_return:
 pop r13
 pop r12
 pop rbx
 ret

.Mg_catalog_entry:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov rax,[rip+.Mg_count]
 cmp rax,[rip+.Mg_cap]
 jae .Mg_ce_return
 cmp qword ptr [rip+.Mg_kind],0
 jne .Mg_ce_extension
 mov rdi,r13
 call .Mg_zlen
 cmp rax,4
 jb .Mg_ce_return
 cmp word ptr [r13+rax-3],0x6d2e
 jne .Mg_ce_return
 cmp byte ptr [r13+rax-1],100
 jne .Mg_ce_return
 mov r14,rax
 sub r14,3
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 test rax,rax
 jle .Mg_ce_return
 mov rdi,rax
 call .Mg_validate_agent
 test rax,rax
 js .Mg_ce_return
 jmp .Mg_ce_keep
.Mg_ce_extension:
 mov rdi,r13
 call .Mg_name
 test rax,rax
 js .Mg_ce_return
 mov r14,rax
 mov rdi,r12
 mov rsi,r13
 call .Mg_child_dir
 test rax,rax
 js .Mg_ce_return
 mov r15,rax
 mov rdi,rax
 call .Mg_extension_fd_enabled
 mov [rip+.Mg_row_enabled],rax
 mov rdi,r15
 lea rsi,[rip+.Mg_manifest]
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 mov rbx,rax
 mov eax,3
 mov rdi,r15
 syscall
 test rbx,rbx
 jle .Mg_ce_return
 lea rdi,[rip+.Mg_raw]
 mov rsi,rbx
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Mg_ce_return
 cmp qword ptr [rip+.Mg_tokens+T_TYPE],JT_OBJECT
 jne .Mg_ce_return
.Mg_ce_keep:
 # Keep scope-specific definitions as separate rows; UI can group explicitly.
 mov rbx,[rip+.Mg_count]
 imul r15,rbx,MG_STRIDE
 lea rax,[rip+.Mg_strings]
 add r15,rax
 mov rdi,r15
 mov rsi,r13
 mov rcx,r14
 rep movsb
 mov byte ptr [rdi],0
 lea rdi,[r15+128]
 lea rsi,[rip+.Mg_user]
 mov rax,[rip+.Mg_scope]
 test rax,rax
 jz .Mg_ce_desc
 lea rsi,[rip+.Mg_project]
.Mg_ce_desc:
 lodsb
 stosb
 test al,al
 jnz .Mg_ce_desc
 cmp qword ptr [rip+.Mg_kind],0
 je .Mg_ce_desc_done
 dec rdi
 lea rsi,[rip+.Mg_enabled_text]
 cmp qword ptr [rip+.Mg_row_enabled],1
 je .Mg_ce_state_copy
 lea rsi,[rip+.Mg_disabled_text]
.Mg_ce_state_copy:
 lodsb
 stosb
 test al,al
 jnz .Mg_ce_state_copy
.Mg_ce_desc_done:
 lea rdi,[r15+512]
 mov rax,[rip+.Mg_scope]
 shl rax,1
 add rax,[rip+.Mg_kind]
 shl rax,12
 lea rsi,[rip+.Mg_prefixes]
 add rsi,rax
.Mg_ce_path:
 lodsb
 test al,al
 jz .Mg_ce_path_name
 stosb
 jmp .Mg_ce_path
.Mg_ce_path_name:
 mov rsi,r13
.Mg_ce_namecopy:
 lodsb
 stosb
 test al,al
 jnz .Mg_ce_namecopy
 cmp qword ptr [rip+.Mg_kind],0
 je .Mg_ce_output
 dec rdi
 mov al,47
 stosb
 lea rsi,[rip+.Mg_manifest]
.Mg_ce_manifest:
 lodsb
 stosb
 test al,al
 jnz .Mg_ce_manifest
.Mg_ce_output:
 mov rax,[rip+.Mg_out]
 imul rcx,rbx,24
 add rax,rcx
 mov [rax],r15
 lea rdx,[r15+128]
 mov [rax+8],rdx
 lea rdx,[r15+512]
 mov [rax+16],rdx
 lea rax,[rip+.Mg_scopes]
 mov rdx,[rip+.Mg_scope]
 mov [rax+rbx*8],rdx
 inc qword ptr [rip+.Mg_count]
.Mg_ce_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.global ui_management_item_scope
ui_management_item_scope:
 cmp rdi,[rip+.Mg_count]
 jae .Mg_scope_bad
 lea rax,[rip+.Mg_scopes]
 mov rax,[rax+rdi*8]
 ret
.Mg_scope_bad:
 mov rax,-22
 ret

# Minimal Markdown/frontmatter framing plus strict UTF8. Preserve all YAML bytes
# for source-compatible external editing; no fake partial YAML interpretation.
.Mg_validate_agent:
 push rbx
 mov rbx,rdi
 cmp rbx,9
 jb .Mg_validate_bad
 cmp dword ptr [rip+.Mg_raw],0x0a2d2d2d
 jne .Mg_validate_bad
 lea rsi,[rip+.Mg_raw]
 mov ecx,4
.Mg_find_frontmatter_end:
 lea rax,[rcx+4]
 cmp rax,rbx
 jae .Mg_validate_bad
 cmp dword ptr [rsi+rcx],0x2d2d2d0a
 je .Mg_frontmatter_found
 inc rcx
 jmp .Mg_find_frontmatter_end
.Mg_frontmatter_found:
 cmp byte ptr [rsi+rcx+4],10
 jne .Mg_validate_bad
 # quote+parse validates UTF8 and rejects embedded NUL separately.
 xor ecx,ecx
.Mg_agent_nul:
 cmp rcx,rbx
 jae .Mg_agent_utf8
 cmp byte ptr [rsi+rcx],0
 je .Mg_validate_bad
 inc rcx
 jmp .Mg_agent_nul
.Mg_agent_utf8:
 lea rdi,[rip+.Mg_quote]
 mov rdx,rbx
 mov ecx,393224
 call json_quote
 test rax,rax
 js .Mg_validate_bad
 lea rdi,[rip+.Mg_quote]
 mov rsi,rax
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 cmp rax,1
 jne .Mg_validate_bad
 xor eax,eax
 pop rbx
 ret
.Mg_validate_bad:
 mov rax,-22
 pop rbx
 ret

# Resolve only configured path roots, and separately open every component.
# RDI path -> RSI basename .Mg_namebuf, RAX parentfd. Never arbitrary paths.
.Mg_resolve:
 push rbx
 push r12
 push r13
 mov r12,rdi
 xor ebx,ebx
.Mg_resolve_scope:
 mov rax,rbx
 shl rax,1
 add rax,[rip+.Mg_kind]
 shl rax,12
 lea rsi,[rip+.Mg_prefixes]
 add rsi,rax
 mov rdi,r12
.Mg_resolve_match:
 mov al,[rsi]
 test al,al
 jz .Mg_resolve_basename
 cmp al,[rdi]
 jne .Mg_resolve_next
 inc rsi
 inc rdi
 jmp .Mg_resolve_match
.Mg_resolve_next:
 inc rbx
 cmp rbx,2
 jb .Mg_resolve_scope
 jmp .Mg_resolve_bad
.Mg_resolve_basename:
 mov r13,rdi
 call .Mg_component
 test rax,rax
 js .Mg_resolve_bad
 lea rdi,[rip+.Mg_namebuf]
 mov rsi,r13
 inc rax
 mov rcx,rax
 rep movsb
 mov rdi,rbx
 mov rsi,[rip+.Mg_kind]
 xor edx,edx
 call .Mg_open_tree
 lea rsi,[rip+.Mg_namebuf]
 jmp .Mg_resolve_return
.Mg_resolve_bad:
 mov rax,-22
.Mg_resolve_return:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_agent_read
ui_agent_read:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 mov qword ptr [rip+.Mg_kind],0
 call .Mg_resolve
 test rax,rax
 js .Mg_read_return
 mov rbx,rax
 mov rdi,rax
 mov rdx,r12
 mov rcx,r13
 call .Mg_read_file
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
.Mg_read_return:
 pop r13
 pop r12
 pop rbx
 ret

# Atomic private write(parentFD,name,bytes,len). Replaces symlink itself, never
# opens/truncates its target. Unknown YAML/manifest settings survive verbatim.
.Mg_atomic_write:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 mov eax,318
 lea rdi,[rip+.Mg_random]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,16
 jne .Mg_atomic_io
 lea rdi,[rip+.Mg_temp]
 lea rsi,[rip+.Mg_temp_prefix]
 mov ecx,10
 rep movsb
 lea rsi,[rip+.Mg_random]
 lea r8,[rip+.Mg_hex]
 mov ecx,16
.Mg_atomic_hex:
 lodsb
 movzx edx,al
 shr edx,4
 mov dl,[r8+rdx]
 mov [rdi],dl
 inc rdi
 and eax,15
 mov al,[r8+rax]
 stosb
 loop .Mg_atomic_hex
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,r12
 lea rsi,[rip+.Mg_temp]
 mov edx,0xa00c1
 mov r10d,384
 syscall
 test rax,rax
 js .Mg_atomic_return
 mov rbx,rax
 mov eax,91
 mov rdi,rbx
 mov esi,384
 syscall
 test rax,rax
 js .Mg_atomic_fail
.Mg_atomic_write_loop:
 mov eax,1
 mov rdi,rbx
 mov rsi,r14
 mov rdx,r15
 syscall
 cmp rax,-4
 je .Mg_atomic_write_loop
 test rax,rax
 jle .Mg_atomic_write_io
 add r14,rax
 sub r15,rax
 jnz .Mg_atomic_write_loop
 mov eax,74
 mov rdi,rbx
 syscall
 test rax,rax
 js .Mg_atomic_fail
 mov eax,3
 mov rdi,rbx
 syscall
 mov rbx,-1
 mov eax,264
 mov rdi,r12
 lea rsi,[rip+.Mg_temp]
 mov rdx,r12
 mov r10,r13
 syscall
 test rax,rax
 js .Mg_atomic_fail
 mov eax,74
 mov rdi,r12
 syscall
 jmp .Mg_atomic_return
.Mg_atomic_write_io:
 mov rax,-5
.Mg_atomic_fail:
 mov r14,rax
 cmp rbx,0
 jl .Mg_atomic_unlink
 mov eax,3
 mov rdi,rbx
 syscall
.Mg_atomic_unlink:
 mov eax,263
 mov rdi,r12
 lea rsi,[rip+.Mg_temp]
 xor edx,edx
 syscall
 mov rax,r14
 jmp .Mg_atomic_return
.Mg_atomic_io:
 mov rax,-5
.Mg_atomic_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.global ui_agent_save
# nameZ,rawMarkdown,len,scope0user1project.
ui_agent_save:
 push rbx
 push r12
 push r13
 push r14
 push r15
 cmp qword ptr [rip+.Mg_allow],0
 je .Mg_save_denied
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 cmp r15,1
 ja .Mg_save_bad
 test rsi,rsi
 jz .Mg_save_bad
 cmp rdx,65535
 ja .Mg_save_bad
 call .Mg_name
 test rax,rax
 js .Mg_save_bad
 lea rdi,[rip+.Mg_namebuf]
 mov rsi,r12
 mov rcx,rax
 rep movsb
 lea rsi,[rip+.Mg_md]
 mov ecx,4
 rep movsb
 lea rdi,[rip+.Mg_raw]
 mov rsi,r13
 mov rcx,r14
 rep movsb
 mov rdi,r14
 call .Mg_validate_agent
 test rax,rax
 js .Mg_save_return
 mov rdi,r15
 xor esi,esi
 mov edx,1
 call .Mg_open_tree
 test rax,rax
 js .Mg_save_return
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Mg_namebuf]
 lea rdx,[rip+.Mg_raw]
 mov rcx,r14
 call .Mg_atomic_write
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Mg_save_return
.Mg_save_denied:
 mov rax,-13
 jmp .Mg_save_return
.Mg_save_bad:
 mov rax,-22
.Mg_save_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.global ui_agent_delete
ui_agent_delete:
 push rbx
 cmp qword ptr [rip+.Mg_allow],0
 je .Mg_delete_denied
 mov qword ptr [rip+.Mg_kind],0
 call .Mg_resolve
 test rax,rax
 js .Mg_delete_return
 mov rbx,rax
 # Verify owner regular before unlink, without reading/executing definition.
 mov eax,257
 mov rdi,rbx
 lea rsi,[rip+.Mg_namebuf]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Mg_delete_close
 mov r8,rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Mg_stat]
 syscall
 mov r9,rax
 mov eax,3
 mov rdi,r8
 syscall
 test r9,r9
 js .Mg_delete_bad_close
 mov eax,[rip+.Mg_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Mg_delete_bad_close
 mov eax,107
 syscall
 cmp eax,[rip+.Mg_stat+28]
 jne .Mg_delete_bad_close
 mov eax,263
 mov rdi,rbx
 lea rsi,[rip+.Mg_namebuf]
 xor edx,edx
 syscall
 test rax,rax
 js .Mg_delete_close
 mov eax,74
 mov rdi,rbx
 syscall
 jmp .Mg_delete_close
.Mg_delete_bad_close:
 mov rax,-22
.Mg_delete_close:
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Mg_delete_return
.Mg_delete_denied:
 mov rax,-13
.Mg_delete_return:
 pop rbx
 ret

# Extension identifiers are the real manifest paths returned by catalog.
# The native enable marker deliberately does not rewrite Qwen's journaled store.
.Mg_resolve_extension:
 push rbx
 push r12
 push r13
 mov r12,rdi
 xor ebx,ebx
.Mg_ext_scope:
 mov rax,rbx
 shl rax,1
 inc rax
 shl rax,12
 lea rsi,[rip+.Mg_prefixes]
 add rsi,rax
 mov rdi,r12
.Mg_ext_match:
 mov al,[rsi]
 test al,al
 jz .Mg_ext_name
 cmp al,[rdi]
 jne .Mg_ext_nextscope
 inc rsi
 inc rdi
 jmp .Mg_ext_match
.Mg_ext_nextscope:
 inc rbx
 cmp rbx,2
 jb .Mg_ext_scope
 jmp .Mg_ext_bad
.Mg_ext_name:
 lea rsi,[rip+.Mg_namebuf]
 xor ecx,ecx
.Mg_ext_copy:
 cmp ecx,63
 jae .Mg_ext_bad
 mov al,[rdi]
 test al,al
 jz .Mg_ext_bad
 cmp al,47
 je .Mg_ext_tail
 mov [rsi+rcx],al
 inc ecx
 inc rdi
 jmp .Mg_ext_copy
.Mg_ext_tail:
 mov byte ptr [rsi+rcx],0
 inc rdi
 lea rsi,[rip+.Mg_manifest]
 call .Mg_eq
 test rax,rax
 jz .Mg_ext_bad
 lea rdi,[rip+.Mg_namebuf]
 call .Mg_name
 test rax,rax
 js .Mg_ext_bad
 mov rdi,rbx
 mov esi,1
 xor edx,edx
 call .Mg_open_tree
 test rax,rax
 js .Mg_ext_return
 mov r13,rax
 mov rdi,rax
 lea rsi,[rip+.Mg_namebuf]
 call .Mg_child_dir
 mov rbx,rax
 mov eax,3
 mov rdi,r13
 syscall
 test rbx,rbx
 js .Mg_ext_bad
 mov rdi,rbx
 mov eax,5
 lea rsi,[rip+.Mg_stat]
 syscall
 test rax,rax
 js .Mg_ext_close_bad
 mov eax,107
 syscall
 cmp eax,[rip+.Mg_stat+28]
 jne .Mg_ext_close_bad
 # Require real, owner-regular valid manifest before any action.
 mov rdi,rbx
 lea rsi,[rip+.Mg_manifest]
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 test rax,rax
 jle .Mg_ext_close_bad
 lea rdi,[rip+.Mg_raw]
 mov rsi,rax
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Mg_ext_close_bad
 cmp qword ptr [rip+.Mg_tokens+T_TYPE],JT_OBJECT
 jne .Mg_ext_close_bad
 mov rax,rbx
 jmp .Mg_ext_return
.Mg_ext_close_bad:
 mov eax,3
 mov rdi,rbx
 syscall
.Mg_ext_bad:
 mov rax,-22
.Mg_ext_return:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_extension_read
ui_extension_read:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 call .Mg_resolve_extension
 test rax,rax
 js .Mg_er_return
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Mg_manifest]
 mov rdx,r12
 mov rcx,r13
 call .Mg_read_file
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
.Mg_er_return:
 pop r13
 pop r12
 pop rbx
 ret
# fd ->1enabled,0disabled. Any existing marker fails closed, no dereference.
.Mg_extension_fd_enabled:
 mov eax,262
 lea rsi,[rip+.Mg_disabled]
 lea rdx,[rip+.Mg_stat]
 mov r10d,256
 syscall
 cmp rax,-2
 je .Mg_ee_yes
 test rax,rax
 js .Mg_ee_return
 xor eax,eax
 ret
.Mg_ee_yes:
 mov eax,1
.Mg_ee_return:
 ret
.global ui_extension_enabled
ui_extension_enabled:
 push rbx
 call .Mg_resolve_extension
 test rax,rax
 js .Mg_ee_done
 mov rbx,rax
 mov rdi,rax
 call .Mg_extension_fd_enabled
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
.Mg_ee_done:
 pop rbx
 ret
.global ui_extension_set_enabled
# pathZ,enabledBool ->0/error, atomic native-owned marker; effective next reload.
ui_extension_set_enabled:
 push rbx
 push r12
 push r13
 mov r12,rsi
 cmp qword ptr [rip+.Mg_allow],0
 je .Mg_es_denied
 call .Mg_resolve_extension
 test rax,rax
 js .Mg_es_return
 mov rbx,rax
 test r12,r12
 jnz .Mg_es_enable
 mov rdi,rbx
 lea rsi,[rip+.Mg_disabled]
 lea rdx,[rip+.Mg_empty_object]
 mov ecx,2
 call .Mg_atomic_write
 jmp .Mg_es_close
.Mg_es_enable:
 mov eax,263
 mov rdi,rbx
 lea rsi,[rip+.Mg_disabled]
 xor edx,edx
 syscall
 cmp rax,-2
 jne .Mg_es_sync
 xor eax,eax
.Mg_es_sync:
 test rax,rax
 js .Mg_es_close
 mov eax,74
 mov rdi,rbx
 syscall
.Mg_es_close:
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Mg_es_return
.Mg_es_denied:
 mov rax,-13
.Mg_es_return:
 pop r13
 pop r12
 pop rbx
 ret

# Bounded native recursive removal. FD traversal never follows links. Preserve
# partial failure diagnostics rather than claiming removed when entries remain.
.section .bss
.Mg_rm_budget: .skip 8
.Mg_row_enabled: .skip 8
.section .text
.global ui_extension_uninstall
ui_extension_uninstall:
 push rbx
 push r12
 push r13
 cmp qword ptr [rip+.Mg_allow],0
 je .Mg_un_denied
 mov r12,rdi
 call .Mg_resolve_extension
 test rax,rax
 js .Mg_un_return
 mov rbx,rax
 mov qword ptr [rip+.Mg_rm_budget],8192
 mov rdi,rax
 xor esi,esi
 call .Mg_remove_contents
 mov r13,rax
 mov eax,3
 mov rdi,rbx
 syscall
 test r13,r13
 js .Mg_un_result
 # resolve original parent from path without re-opening deleted manifest.
 mov rdi,r12
 xor ebx,ebx
.Mg_un_parent_scope:
 mov rax,rbx
 shl rax,1
 inc rax
 shl rax,12
 lea rsi,[rip+.Mg_prefixes]
 add rsi,rax
 mov rdi,r12
.Mg_un_parent_match:
 mov al,[rsi]
 test al,al
 jz .Mg_un_parent_open
 cmp al,[rdi]
 jne .Mg_un_parent_next
 inc rdi
 inc rsi
 jmp .Mg_un_parent_match
.Mg_un_parent_next:
 inc rbx
 cmp rbx,2
 jb .Mg_un_parent_scope
 mov rax,-22
 jmp .Mg_un_return
.Mg_un_parent_open:
 mov rdi,rbx
 mov esi,1
 xor edx,edx
 call .Mg_open_tree
 test rax,rax
 js .Mg_un_return
 mov rbx,rax
 mov eax,263
 mov rdi,rbx
 lea rsi,[rip+.Mg_namebuf]
 mov edx,512
 syscall
 test rax,rax
 js .Mg_un_parent_close
 mov eax,74
 mov rdi,rbx
 syscall
.Mg_un_parent_close:
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Mg_un_return
.Mg_un_result:
 mov rax,r13
 jmp .Mg_un_return
.Mg_un_denied:
 mov rax,-13
.Mg_un_return:
 pop r13
 pop r12
 pop rbx
 ret
.Mg_remove_contents:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8200
 mov r12,rdi
 mov r13,rsi
 cmp r13,16
 jae .Mg_rm_limit
.Mg_rm_batch:
 mov eax,217
 mov rdi,r12
 mov rsi,rsp
 mov edx,8192
 syscall
 cmp rax,-4
 je .Mg_rm_batch
 test rax,rax
 js .Mg_rm_return
 jz .Mg_rm_ok
 lea r14,[rsp+rax]
 mov rbx,rsp
.Mg_rm_entry:
 movzx ebp,word ptr [rbx+16]
 cmp ebp,20
 jb .Mg_rm_invalid
 lea rax,[rbx+rbp]
 cmp rax,r14
 ja .Mg_rm_invalid
 cmp byte ptr [rbx+19],46
 jne .Mg_rm_real
 cmp byte ptr [rbx+20],0
 je .Mg_rm_next
 cmp byte ptr [rbx+20],46
 jne .Mg_rm_real
 cmp byte ptr [rbx+21],0
 je .Mg_rm_next
.Mg_rm_real:
 dec qword ptr [rip+.Mg_rm_budget]
 js .Mg_rm_limit
 mov rdi,r12
 lea rsi,[rbx+19]
 call .Mg_child_dir
 test rax,rax
 js .Mg_rm_file
 mov r15,rax
 mov rdi,rax
 lea rsi,[r13+1]
 call .Mg_remove_contents
 push rax
 mov eax,3
 mov rdi,r15
 syscall
 pop rax
 test rax,rax
 js .Mg_rm_return
 mov eax,263
 mov rdi,r12
 lea rsi,[rbx+19]
 mov edx,512
 syscall
 jmp .Mg_rm_unlinked
.Mg_rm_file:
 mov eax,263
 mov rdi,r12
 lea rsi,[rbx+19]
 xor edx,edx
 syscall
.Mg_rm_unlinked:
 test rax,rax
 js .Mg_rm_return
.Mg_rm_next:
 add rbx,rbp
 cmp rbx,r14
 jb .Mg_rm_entry
 jmp .Mg_rm_batch
.Mg_rm_ok:
 xor eax,eax
 jmp .Mg_rm_return
.Mg_rm_limit:
 mov rax,-7
 jmp .Mg_rm_return
.Mg_rm_invalid:
 mov rax,-22
.Mg_rm_return:
 add rsp,8200
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.section .note.GNU-stack,"",@progbits
.section .rodata
.Mg_favorite: .asciz ".qwen-x86-favorite"
.section .text
.global ui_extension_favorite,ui_extension_is_favorite
ui_extension_is_favorite:
 push rbx
 call .Mg_resolve_extension
 test rax,rax
 js .Mg_fav_get_return
 mov rbx,rax
 mov eax,262
 mov rdi,rbx
 lea rsi,[rip+.Mg_favorite]
 lea rdx,[rip+.Mg_stat]
 mov r10d,256
 syscall
 cmp rax,-2
 je .Mg_fav_get_no
 test rax,rax
 js .Mg_fav_get_close
 mov eax,1
 jmp .Mg_fav_get_close
.Mg_fav_get_no:
 xor eax,eax
.Mg_fav_get_close:
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
.Mg_fav_get_return:
 pop rbx
 ret
ui_extension_favorite:
 push rbx
 push r12
 push r13
 mov r12,rsi
 cmp qword ptr [rip+.Mg_allow],0
 je .Mg_fav_denied
 call .Mg_resolve_extension
 test rax,rax
 js .Mg_fav_return
 mov rbx,rax
 test r12,r12
 jz .Mg_fav_clear
 mov rdi,rbx
 lea rsi,[rip+.Mg_favorite]
 lea rdx,[rip+.Mg_empty_object]
 mov ecx,2
 call .Mg_atomic_write
 jmp .Mg_fav_close
.Mg_fav_clear:
 mov eax,263
 mov rdi,rbx
 lea rsi,[rip+.Mg_favorite]
 xor edx,edx
 syscall
 cmp rax,-2
 jne .Mg_fav_sync
 xor eax,eax
.Mg_fav_sync:
 test rax,rax
 js .Mg_fav_close
 mov eax,74
 mov rdi,rbx
 syscall
.Mg_fav_close:
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Mg_fav_return
.Mg_fav_denied:
 mov rax,-13
.Mg_fav_return:
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Ms_file: .asciz "marketplaces.json"
.Ms_name_key: .asciz "name"
.Ms_source_key: .asciz "source"
.Ms_prefix: .ascii "{\"name\":"
.Ms_between: .ascii ",\"source\":"
.Ms_empty: .ascii "[]"
.section .bss
.balign 16
.Ms_json: .skip 65537
.Ms_length: .skip 8
.Ms_tokens: .skip 262144
.Ms_name: .skip 256
.Ms_source: .skip 4096
.Ms_new: .skip 65537
.Ms_strings: .skip 64*4608
.Ms_count: .skip 8
.section .text
# Read actual source registry only; absence is an empty array, malformed fails.
.Ms_load:
 push rbx
 push r12
 push r13
 xor edi,edi
 mov esi,1
 xor edx,edx
 call .Mg_open_tree
 test rax,rax
 js .Ms_load_empty
 mov rbx,rax
 mov eax,262
 mov rdi,rbx
 lea rsi,[rip+.Ms_file]
 lea rdx,[rip+.Mg_stat]
 mov r10d,256
 syscall
 cmp rax,-2
 je .Ms_load_close_empty
 test rax,rax
 js .Ms_load_close_error
 mov rdi,rbx
 lea rsi,[rip+.Ms_file]
 lea rdx,[rip+.Ms_json]
 mov ecx,65537
 call .Mg_read_file
 mov r12,rax
 mov eax,3
 mov rdi,rbx
 syscall
 test r12,r12
 jle .Ms_load_bad
 mov [rip+.Ms_length],r12
 lea rdi,[rip+.Ms_json]
 mov rsi,r12
 lea rdx,[rip+.Ms_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Ms_load_bad
 cmp qword ptr [rip+.Ms_tokens+T_TYPE],JT_ARRAY
 jne .Ms_load_bad
 xor eax,eax
 jmp .Ms_load_return
.Ms_load_close_empty:
 mov eax,3
 mov rdi,rbx
 syscall
.Ms_load_empty:
 mov word ptr [rip+.Ms_json],0x5d5b
 mov qword ptr [rip+.Ms_length],2
 lea rdi,[rip+.Ms_json]
 mov esi,2
 lea rdx,[rip+.Ms_tokens]
 mov ecx,8192
 call json_parse
 xor eax,eax
 jmp .Ms_load_return
.Ms_load_close_error:
 mov eax,3
 mov rdi,rbx
 syscall
.Ms_load_bad:
 mov rax,-22
.Ms_load_return:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_extension_sources_read
ui_extension_sources_read:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 call .Ms_load
 test rax,rax
 js .Ms_read_return
 mov rax,[rip+.Ms_length]
 cmp rax,r13
 jae .Ms_read_full
 test r12,r12
 jz .Ms_read_full
 mov rdi,r12
 lea rsi,[rip+.Ms_json]
 mov rcx,rax
 rep movsb
 mov byte ptr [rdi],0
 jmp .Ms_read_return
.Ms_read_full:
 mov rax,-28
.Ms_read_return:
 pop r13
 pop r12
 pop rbx
 ret
# Extract one string field objectindex,keyZ,out,cap ->len/error.
.Ms_field:
 push rbx
 push r12
 push r13
 mov r12,rdx
 mov r13,rcx
 mov rcx,rsi
 mov rdx,rdi
 lea rdi,[rip+.Ms_json]
 lea rsi,[rip+.Ms_tokens]
 call json_find
 test rax,rax
 js .Ms_field_bad
 shl rax,5
 lea rbx,[rip+.Ms_tokens]
 cmp qword ptr [rbx+rax+T_TYPE],JT_STRING
 jne .Ms_field_bad
 mov rdi,r12
 lea rsi,[rip+.Ms_json]
 add rsi,[rbx+rax+T_START]
 mov rdx,[rbx+rax+T_LEN]
 mov rcx,r13
 dec rcx
 call json_decode
 test rax,rax
 js .Ms_field_return
 mov byte ptr [r12+rax],0
 jmp .Ms_field_return
.Ms_field_bad:
 mov rax,-22
.Ms_field_return:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_extension_source_catalog
ui_extension_source_catalog:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 xor r15d,r15d
 cmp r13,64
 jbe .Ms_catalog_cap
 mov r13d,64
.Ms_catalog_cap:
 test r13,r13
 jz .Ms_catalog_done
 test r12,r12
 jz .Ms_catalog_bad
 call .Ms_load
 test rax,rax
 js .Ms_catalog_return
 mov ebx,1
.Ms_catalog_next:
 cmp rbx,[rip+.Ms_tokens+T_END]
 jae .Ms_catalog_done
 cmp r15,r13
 jae .Ms_catalog_done
 mov rax,rbx
 shl rax,5
 lea r14,[rip+.Ms_tokens]
 add r14,rax
 cmp qword ptr [r14+T_TYPE],JT_OBJECT
 jne .Ms_catalog_advance
 imul rax,r15,4608
 lea rdx,[rip+.Ms_strings]
 add rdx,rax
 mov rdi,rbx
 lea rsi,[rip+.Ms_name_key]
 mov ecx,256
 call .Ms_field
 test rax,rax
 jle .Ms_catalog_advance
 imul rax,r15,4608
 lea rdx,[rip+.Ms_strings+512]
 add rdx,rax
 mov rdi,rbx
 lea rsi,[rip+.Ms_source_key]
 mov ecx,4096
 call .Ms_field
 test rax,rax
 jle .Ms_catalog_advance
 imul rax,r15,4608
 lea rdx,[rip+.Ms_strings]
 add rdx,rax
 imul rax,r15,24
 mov [r12+rax],rdx
 add rdx,512
 mov [r12+rax+8],rdx
 mov [r12+rax+16],rdx
 inc r15
.Ms_catalog_advance:
 mov rbx,[r14+T_END]
 jmp .Ms_catalog_next
.Ms_catalog_done:
 mov rax,r15
 jmp .Ms_catalog_return
.Ms_catalog_bad:
 mov rax,-22
.Ms_catalog_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.global ui_extension_source_add,ui_extension_source_remove
# Source add replaces same name/source while preserving all unrelated raw entries.
ui_extension_source_add:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r15d,1
 jmp .Ms_mutate
ui_extension_source_remove:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 xor r13d,r13d
 xor r15d,r15d
.Ms_mutate:
 cmp qword ptr [rip+.Mg_allow],0
 je .Ms_mutate_denied
 test r12,r12
 jz .Ms_mutate_bad
 mov rdi,r12
 call .Mg_name
 test rax,rax
 js .Ms_mutate_bad
 test r15,r15
 jz .Ms_mutate_load
 test r13,r13
 jz .Ms_mutate_bad
 mov rdi,r13
 call .Mg_zlen
 test rax,rax
 jle .Ms_mutate_bad
 cmp rax,4095
 ja .Ms_mutate_bad
.Ms_mutate_load:
 call .Ms_load
 test rax,rax
 js .Ms_mutate_return
 lea r14,[rip+.Ms_new]
 mov byte ptr [r14],91
 mov r14d,1
 mov ebx,1
.Ms_filter_next:
 cmp rbx,[rip+.Ms_tokens+T_END]
 jae .Ms_filter_done
 mov rax,rbx
 shl rax,5
 lea rdx,[rip+.Ms_tokens]
 cmp qword ptr [rdx+rax+T_TYPE],JT_OBJECT
 jne .Ms_filter_keep
 mov rdi,rbx
 lea rsi,[rip+.Ms_name_key]
 lea rdx,[rip+.Ms_name]
 mov ecx,256
 call .Ms_field
 test rax,rax
 js .Ms_filter_source
 lea rdi,[rip+.Ms_name]
 mov rsi,r12
 call .Mg_eq
 test eax,eax
 jnz .Ms_filter_skip
.Ms_filter_source:
 test r15,r15
 jz .Ms_filter_keep
 mov rdi,rbx
 lea rsi,[rip+.Ms_source_key]
 lea rdx,[rip+.Ms_source]
 mov ecx,4096
 call .Ms_field
 test rax,rax
 js .Ms_filter_keep
 lea rdi,[rip+.Ms_source]
 mov rsi,r13
 call .Mg_eq
 test eax,eax
 jnz .Ms_filter_skip
.Ms_filter_keep:
 cmp r14,1
 je .Ms_filter_nocomma
 lea rdi,[rip+.Ms_new]
 mov byte ptr [rdi+r14],44
 inc r14
.Ms_filter_nocomma:
 mov rax,rbx
 shl rax,5
 lea rdx,[rip+.Ms_tokens]
 mov rsi,[rdx+rax+T_START]
 mov rcx,[rdx+rax+T_LEN]
 # Object/array token LEN spans the complete container including delimiters.
 mov r8,r14
 add r8,rcx
 cmp r8,65535
 jae .Ms_mutate_full
 lea rdi,[rip+.Ms_new]
 add rdi,r14
 add r14,rcx
 lea rax,[rip+.Ms_json]
 add rsi,rax
 rep movsb
.Ms_filter_skip:
 mov rax,rbx
 shl rax,5
 lea rdx,[rip+.Ms_tokens]
 mov rbx,[rdx+rax+T_END]
 jmp .Ms_filter_next
.Ms_filter_done:
 test r15,r15
 jz .Ms_close_array
 cmp r14,1
 je .Ms_add_prefix
 lea rdi,[rip+.Ms_new]
 mov byte ptr [rdi+r14],44
 inc r14
.Ms_add_prefix:
 # Leave room for the maximum safe name and fixed JSON framing before writing.
 cmp r14,65440
 ja .Ms_mutate_full
 lea rdi,[rip+.Ms_new]
 add rdi,r14
 lea rsi,[rip+.Ms_prefix]
 mov ecx,8
 rep movsb
 add r14,8
 mov rdi,r12
 call .Mg_zlen
 lea rdi,[rip+.Ms_new]
 add rdi,r14
 mov rsi,r12
 mov rdx,rax
 mov ecx,65520
 sub rcx,r14
 call json_quote
 test rax,rax
 js .Ms_mutate_full
 add r14,rax
 lea rdi,[rip+.Ms_new]
 add rdi,r14
 lea rsi,[rip+.Ms_between]
 mov ecx,10
 rep movsb
 add r14,10
 mov rdi,r13
 call .Mg_zlen
 lea rdi,[rip+.Ms_new]
 add rdi,r14
 mov rsi,r13
 mov rdx,rax
 mov ecx,65534
 sub rcx,r14
 call json_quote
 test rax,rax
 js .Ms_mutate_full
 add r14,rax
 lea rdi,[rip+.Ms_new]
 mov byte ptr [rdi+r14],125
 inc r14
.Ms_close_array:
 cmp r14,65535
 jae .Ms_mutate_full
 lea rdi,[rip+.Ms_new]
 mov byte ptr [rdi+r14],93
 inc r14
 mov rsi,r14
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Ms_mutate_bad
 xor edi,edi
 mov esi,1
 mov edx,1
 call .Mg_open_tree
 test rax,rax
 js .Ms_mutate_return
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Ms_file]
 lea rdx,[rip+.Ms_new]
 mov rcx,r14
 call .Mg_atomic_write
 push rax
 mov eax,3
 mov rdi,rbx
 syscall
 pop rax
 jmp .Ms_mutate_return
.Ms_mutate_full:
 mov rax,-28
 jmp .Ms_mutate_return
.Ms_mutate_bad:
 mov rax,-22
 jmp .Ms_mutate_return
.Ms_mutate_denied:
 mov rax,-13
.Ms_mutate_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Explicit extension install/update invokes the user's installed git executable
# directly (argv, no shell), as upstream does. No lifecycle hook is executed.
.section .rodata
.Mi_git: .asciz "/usr/bin/git"
.Mi_clone: .asciz "clone"
.Mi_depth: .asciz "--depth"
.Mi_one: .asciz "1"
.Mi_sep: .asciz "--"
.Mi_null: .asciz "/dev/null"
.Mi_install_file: .asciz ".qwen-extension-install.json"
.Mi_native_source: .asciz ".qwen-x86-source.json"
.Mi_stage_prefix: .ascii ".install-"
.Mi_default_error: .asciz "Extension operation failed; git output is unavailable."
.Mi_https: .asciz "https://"
.Mi_http: .asciz "http://"
.Mi_ssh: .asciz "ssh://"
.Mi_git_scheme: .asciz "git://"
.section .bss
.balign 16
.Mi_source: .skip 4096
.Mi_name: .skip 64
.Mi_stage: .skip 64
.Mi_scope: .skip 8
.Mi_env: .skip 8
.Mi_update: .skip 8
.Mi_parentfd: .skip 8
.Mi_stagefd: .skip 8
.Mi_pid: .skip 8
.Mi_parentpid: .skip 8
.Mi_pipe: .skip 8
.Mi_status: .skip 8
.Mi_reaped: .skip 8
.Mi_outputlen: .skip 8
.Mi_laststatus: .skip 8
.Mi_cancel: .skip 8
.Mi_staged: .skip 8
.Mi_disabled: .skip 8
.Mi_favorite: .skip 8
.Mi_argv: .skip 64
.Mi_poll: .skip 8
.Mi_clock: .skip 16
.Mi_start: .skip 8
.Mi_output: .skip 65536
.Mi_readbuf: .skip 8192
.section .text
.global ui_management_set_cancel,ui_management_last_error,ui_management_last_status
ui_management_set_cancel:
 mov [rip+.Mi_cancel],rdi
 xor eax,eax
 ret
ui_management_last_error:
 lea rax,[rip+.Mi_output]
 cmp byte ptr [rax],0
 jne .Mi_last_error_return
 lea rax,[rip+.Mi_default_error]
.Mi_last_error_return:
 ret
ui_management_last_status:
 mov rax,[rip+.Mi_laststatus]
 ret
# sourceZ,nameZ,scope0user1project,envp ->0/error. Destination never overwritten.
.global ui_extension_install
ui_extension_install:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov qword ptr [rip+.Mi_update],0
 mov qword ptr [rip+.Mi_disabled],0
 mov qword ptr [rip+.Mi_favorite],0
 jmp .Mi_prepare
# manifestPathZ,envp ->0/error. Validated stage atomically swaps with old tree;
# the previous tree is removed only AFTER the replacement is fully committed.
.global ui_extension_update
ui_extension_update:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov [rip+.Mi_env],rsi
 cmp qword ptr [rip+.Mg_allow],0
 je .Mi_denied
 call .Mg_resolve_extension
 test rax,rax
 js .Mi_return
 mov rbx,rax
 lea rdi,[rip+.Mi_name]
 lea rsi,[rip+.Mg_namebuf]
.Mi_update_namecopy:
 lodsb
 stosb
 test al,al
 jnz .Mi_update_namecopy
 mov rdi,rbx
 call .Mg_extension_fd_enabled
 cmp eax,1
 setne al
 movzx eax,al
 mov [rip+.Mi_disabled],rax
 mov eax,262
 mov rdi,rbx
 lea rsi,[rip+.Mg_favorite]
 lea rdx,[rip+.Mg_stat]
 mov r10d,256
 syscall
 test rax,rax
 setns al
 movzx eax,al
 mov [rip+.Mi_favorite],rax
 mov rdi,rbx
 lea rsi,[rip+.Mi_native_source]
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 test rax,rax
 jle .Mi_update_source_metadata
 # Own native source metadata is a strict JSON string, not a shell fragment.
 mov r13,rax
 lea rdi,[rip+.Mg_raw]
 mov rsi,rax
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 cmp rax,1
 jne .Mi_update_badclose
 cmp qword ptr [rip+.Mg_tokens+T_TYPE],JT_STRING
 jne .Mi_update_badclose
 lea rdi,[rip+.Mi_source]
 lea rsi,[rip+.Mg_raw]
 add rsi,[rip+.Mg_tokens+T_START]
 mov rdx,[rip+.Mg_tokens+T_LEN]
 mov ecx,4095
 call json_decode
 test rax,rax
 js .Mi_update_badclose
 lea rdi,[rip+.Mi_source]
 mov byte ptr [rdi+rax],0
 jmp .Mi_update_have_source
.Mi_update_source_metadata:
 # Read upstream's real install metadata when updating an existing Qwen install.
 mov rdi,rbx
 lea rsi,[rip+.Mi_install_file]
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 test rax,rax
 jle .Mi_update_badclose
 lea rdi,[rip+.Mg_raw]
 mov rsi,rax
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Mi_update_badclose
 cmp qword ptr [rip+.Mg_tokens+T_TYPE],JT_OBJECT
 jne .Mi_update_badclose
 lea rdi,[rip+.Mg_raw]
 lea rsi,[rip+.Mg_tokens]
 xor edx,edx
 lea rcx,[rip+.Ms_source_key]
 call json_find
 test rax,rax
 js .Mi_update_badclose
 shl rax,5
 lea r8,[rip+.Mg_tokens]
 cmp qword ptr [r8+rax+T_TYPE],JT_STRING
 jne .Mi_update_badclose
 lea rdi,[rip+.Mi_source]
 lea rsi,[rip+.Mg_raw]
 add rsi,[r8+rax+T_START]
 mov rdx,[r8+rax+T_LEN]
 mov ecx,4095
 call json_decode
 test rax,rax
 js .Mi_update_badclose
 lea rdi,[rip+.Mi_source]
 mov byte ptr [rdi+rax],0
.Mi_update_have_source:
 mov eax,3
 mov rdi,rbx
 syscall
 # The source-specific scope is retained from the actual configured path.
 lea rsi,[rip+.Mg_prefixes+4096]
 mov rdi,r12
.Mi_update_scope_match:
 mov al,[rsi]
 test al,al
 jz .Mi_update_user_scope
 cmp al,[rdi]
 jne .Mi_update_project_scope
 inc rdi
 inc rsi
 jmp .Mi_update_scope_match
.Mi_update_user_scope:
 xor edx,edx
 jmp .Mi_update_prepare
.Mi_update_project_scope:
 mov edx,1
.Mi_update_prepare:
 mov qword ptr [rip+.Mi_update],1
 lea rdi,[rip+.Mi_source]
 lea rsi,[rip+.Mi_name]
 mov rcx,[rip+.Mi_env]
 jmp .Mi_prepare
.Mi_update_badclose:
 mov eax,3
 mov rdi,rbx
 syscall
 mov rax,-22
 jmp .Mi_return
.Mi_prepare:
 cmp qword ptr [rip+.Mg_allow],0
 je .Mi_denied
 test rdi,rdi
 jz .Mi_bad
 test rsi,rsi
 jz .Mi_bad
 test rcx,rcx
 jz .Mi_bad
 cmp rdx,1
 ja .Mi_bad
 mov [rip+.Mi_env],rcx
 mov [rip+.Mi_scope],rdx
 mov r12,rdi
 mov r13,rsi
 mov rdi,rsi
 call .Mg_name
 test rax,rax
 js .Mi_bad
 lea rdi,[rip+.Mi_name]
 mov rsi,r13
 inc rax
 mov rcx,rax
 rep movsb
 lea rdi,[rip+.Mi_source]
 mov rsi,r12
 xor ecx,ecx
.Mi_source_copy:
 cmp ecx,4095
 jae .Mi_bad
 mov al,[rsi+rcx]
 test al,al
 jz .Mi_source_done
 cmp al,32
 jb .Mi_bad
 cmp al,127
 je .Mi_bad
 mov [rdi+rcx],al
 inc ecx
 jmp .Mi_source_copy
.Mi_source_done:
 mov byte ptr [rdi+rcx],0
 test ecx,ecx
 jz .Mi_bad
 # Reject option injection and executable git remote-helper protocols.
 cmp byte ptr [rdi],47
 je .Mi_source_valid
 lea rsi,[rip+.Mi_https]
 call .Mi_has_prefix
 test eax,eax
 jnz .Mi_source_valid
 lea rsi,[rip+.Mi_http]
 call .Mi_has_prefix
 test eax,eax
 jnz .Mi_source_valid
 lea rsi,[rip+.Mi_ssh]
 call .Mi_has_prefix
 test eax,eax
 jnz .Mi_source_valid
 lea rsi,[rip+.Mi_git_scheme]
 call .Mi_has_prefix
 test eax,eax
 jz .Mi_bad
.Mi_source_valid:
 mov eax,21
 lea rdi,[rip+.Mi_git]
 mov esi,1
 syscall
 test rax,rax
 js .Mi_return
 mov qword ptr [rip+.Mi_parentfd],-1
 mov qword ptr [rip+.Mi_stagefd],-1
 mov qword ptr [rip+.Mi_staged],0
 mov qword ptr [rip+.Mi_outputlen],0
 mov byte ptr [rip+.Mi_output],0
 mov qword ptr [rip+.Mi_laststatus],-1
 mov rdi,[rip+.Mi_scope]
 mov esi,1
 mov edx,1
 call .Mg_open_tree
 test rax,rax
 js .Mi_return
 mov [rip+.Mi_parentfd],rax
 # Random staging sibling, created0700 before git sees it.
 mov eax,318
 lea rdi,[rip+.Mg_random]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,16
 jne .Mi_io_cleanup
 lea rdi,[rip+.Mi_stage]
 lea rsi,[rip+.Mi_stage_prefix]
 mov ecx,9
 rep movsb
 lea rsi,[rip+.Mg_random]
 lea r8,[rip+.Mg_hex]
 mov ecx,16
.Mi_stage_hex:
 lodsb
 movzx edx,al
 shr edx,4
 mov dl,[r8+rdx]
 mov [rdi],dl
 inc rdi
 and eax,15
 mov al,[r8+rax]
 stosb
 loop .Mi_stage_hex
 mov byte ptr [rdi],0
 mov eax,258
 mov rdi,[rip+.Mi_parentfd]
 lea rsi,[rip+.Mi_stage]
 mov edx,448
 syscall
 test rax,rax
 js .Mi_error_cleanup
 mov qword ptr [rip+.Mi_staged],1
 # argv: git clone --depth 1 -- SOURCE STAGE
 lea rdi,[rip+.Mi_argv]
 lea rax,[rip+.Mi_git]
 mov [rdi],rax
 lea rax,[rip+.Mi_clone]
 mov [rdi+8],rax
 lea rax,[rip+.Mi_depth]
 mov [rdi+16],rax
 lea rax,[rip+.Mi_one]
 mov [rdi+24],rax
 lea rax,[rip+.Mi_sep]
 mov [rdi+32],rax
 lea rax,[rip+.Mi_source]
 mov [rdi+40],rax
 lea rax,[rip+.Mi_stage]
 mov [rdi+48],rax
 mov qword ptr [rdi+56],0
 call .Mi_git_run
 test rax,rax
 js .Mi_error_cleanup
 mov rdi,[rip+.Mi_parentfd]
 lea rsi,[rip+.Mi_stage]
 call .Mg_child_dir
 test rax,rax
 js .Mi_error_cleanup
 mov [rip+.Mi_stagefd],rax
 mov rdi,rax
 lea rsi,[rip+.Mg_manifest]
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 test rax,rax
 jle .Mi_bad_cleanup
 lea rdi,[rip+.Mg_raw]
 mov rsi,rax
 lea rdx,[rip+.Mg_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Mi_bad_cleanup
 cmp qword ptr [rip+.Mg_tokens+T_TYPE],JT_OBJECT
 jne .Mi_bad_cleanup
 # Manifest identity must agree with the explicitly chosen destination name.
 lea rdi,[rip+.Mg_raw]
 lea rsi,[rip+.Mg_tokens]
 xor edx,edx
 lea rcx,[rip+.Ms_name_key]
 call json_find
 test rax,rax
 js .Mi_bad_cleanup
 shl rax,5
 lea r8,[rip+.Mg_tokens]
 cmp qword ptr [r8+rax+T_TYPE],JT_STRING
 jne .Mi_bad_cleanup
 lea rdi,[rip+.Ms_name]
 lea rsi,[rip+.Mg_raw]
 add rsi,[r8+rax+T_START]
 mov rdx,[r8+rax+T_LEN]
 mov ecx,255
 call json_decode
 test rax,rax
 js .Mi_bad_cleanup
 lea rdi,[rip+.Ms_name]
 mov byte ptr [rdi+rax],0
 mov r13,rax
 call .Mg_name
 cmp rax,r13
 jne .Mi_bad_cleanup
 lea rdi,[rip+.Ms_name]
 lea rsi,[rip+.Mi_name]
 call .Mg_eq
 test eax,eax
 jz .Mi_bad_cleanup
 lea rdi,[rip+.Mi_source]
 call .Mg_zlen
 lea rdi,[rip+.Mg_quote]
 lea rsi,[rip+.Mi_source]
 mov rdx,rax
 mov ecx,393224
 call json_quote
 test rax,rax
 js .Mi_bad_cleanup
 mov rdi,[rip+.Mi_stagefd]
 lea rsi,[rip+.Mi_native_source]
 lea rdx,[rip+.Mg_quote]
 mov rcx,rax
 call .Mg_atomic_write
 test rax,rax
 js .Mi_error_cleanup
 cmp qword ptr [rip+.Mi_disabled],0
 je .Mi_restore_favorite
 mov rdi,[rip+.Mi_stagefd]
 lea rsi,[rip+.Mg_disabled]
 lea rdx,[rip+.Mg_empty_object]
 mov ecx,2
 call .Mg_atomic_write
 test rax,rax
 js .Mi_error_cleanup
.Mi_restore_favorite:
 cmp qword ptr [rip+.Mi_favorite],0
 je .Mi_commit
 mov rdi,[rip+.Mi_stagefd]
 lea rsi,[rip+.Mg_favorite]
 lea rdx,[rip+.Mg_empty_object]
 mov ecx,2
 call .Mg_atomic_write
 test rax,rax
 js .Mi_error_cleanup
.Mi_commit:
 mov eax,3
 mov rdi,[rip+.Mi_stagefd]
 syscall
 mov qword ptr [rip+.Mi_stagefd],-1
 mov eax,316 # renameat2: never replace on install; exchange atomically onupdate
 mov rdi,[rip+.Mi_parentfd]
 lea rsi,[rip+.Mi_stage]
 mov rdx,rdi
 lea r10,[rip+.Mi_name]
 mov r8d,1
 cmp qword ptr [rip+.Mi_update],0
 je .Mi_commit_syscall
 mov r8d,2
.Mi_commit_syscall:
 syscall
 test rax,rax
 js .Mi_error_cleanup
 cmp qword ptr [rip+.Mi_update],0
 jne .Mi_remove_old
 mov qword ptr [rip+.Mi_staged],0
 mov eax,74
 mov rdi,[rip+.Mi_parentfd]
 syscall
 jmp .Mi_error_cleanup
.Mi_remove_old:
 xor eax,eax
 jmp .Mi_error_cleanup
.Mi_bad_cleanup:
 mov rax,-22
 jmp .Mi_error_cleanup
.Mi_io_cleanup:
 mov rax,-5
.Mi_error_cleanup:
 mov r15,rax
 mov rdi,[rip+.Mi_stagefd]
 cmp rdi,0
 jl .Mi_cleanup_stage
 mov eax,3
 syscall
.Mi_cleanup_stage:
 cmp qword ptr [rip+.Mi_staged],0
 je .Mi_cleanup_parent
 mov rdi,[rip+.Mi_parentfd]
 lea rsi,[rip+.Mi_stage]
 call .Mg_child_dir
 test rax,rax
 js .Mi_cleanup_parent
 mov rbx,rax
 mov qword ptr [rip+.Mg_rm_budget],65536
 mov rdi,rax
 xor esi,esi
 call .Mg_remove_contents
 mov r14,rax
 mov eax,3
 mov rdi,rbx
 syscall
 test r14,r14
 js .Mi_cleanup_failed
 mov eax,263
 mov rdi,[rip+.Mi_parentfd]
 lea rsi,[rip+.Mi_stage]
 mov edx,512
 syscall
 test rax,rax
 jns .Mi_cleanup_parent
 mov r14,rax
.Mi_cleanup_failed:
 test r15,r15
 jne .Mi_cleanup_parent
 mov r15,r14
.Mi_cleanup_parent:
 mov rdi,[rip+.Mi_parentfd]
 cmp rdi,0
 jl .Mi_cleanup_result
 mov eax,74
 syscall
 mov eax,3
 mov rdi,[rip+.Mi_parentfd]
 syscall
.Mi_cleanup_result:
 mov rax,r15
 jmp .Mi_return
.Mi_bad:
 mov rax,-22
 jmp .Mi_return
.Mi_denied:
 mov rax,-13
.Mi_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Mi_has_prefix:
 push rdi
.Mi_prefix_loop:
 mov al,[rsi]
 test al,al
 jz .Mi_prefix_yes
 cmp al,[rdi]
 jne .Mi_prefix_no
 inc rdi
 inc rsi
 jmp .Mi_prefix_loop
.Mi_prefix_yes:
 mov eax,1
 pop rdi
 ret
.Mi_prefix_no:
 xor eax,eax
 pop rdi
 ret

# Direct native git child lifecycle. No shells, startup scripts or hooks.
.Mi_git_run:
 push rbx
 push r12
 push r13
 mov qword ptr [rip+.Mi_reaped],0
 mov eax,39
 syscall
 mov [rip+.Mi_parentpid],rax
 mov eax,228
 mov edi,1
 lea rsi,[rip+.Mi_clock]
 syscall
 mov rax,[rip+.Mi_clock]
 mov [rip+.Mi_start],rax
 mov eax,293
 lea rdi,[rip+.Mi_pipe]
 mov esi,0x80800
 syscall
 test rax,rax
 js .Mi_git_return
 mov eax,57
 syscall
 test rax,rax
 js .Mi_git_fork_error
 jz .Mi_git_child
 mov [rip+.Mi_pid],rax
 mov rdi,rax
 mov rsi,rax
 mov eax,109
 syscall
 mov eax,3
 mov edi,[rip+.Mi_pipe+4]
 syscall
 mov eax,[rip+.Mi_pipe]
 mov [rip+.Mi_poll],eax
 mov word ptr [rip+.Mi_poll+4],1
.Mi_git_loop:
 mov rax,[rip+.Mi_cancel]
 test rax,rax
 jz .Mi_git_clock
 call rax
 cmp rax,-125
 je .Mi_git_cancelled
.Mi_git_clock:
 mov eax,228
 mov edi,1
 lea rsi,[rip+.Mi_clock]
 syscall
 mov rax,[rip+.Mi_clock]
 sub rax,[rip+.Mi_start]
 cmp rax,120
 jae .Mi_git_timeout
.Mi_git_drain:
 xor eax,eax
 mov edi,[rip+.Mi_pipe]
 lea rsi,[rip+.Mi_readbuf]
 mov edx,8192
 syscall
 cmp rax,-4
 je .Mi_git_drain
 test rax,rax
 jle .Mi_git_check
 mov rcx,65535
 sub rcx,[rip+.Mi_outputlen]
 cmp rcx,rax
 cmova rcx,rax
 lea rdi,[rip+.Mi_output]
 add rdi,[rip+.Mi_outputlen]
 add [rip+.Mi_outputlen],rcx
 lea rsi,[rip+.Mi_readbuf]
 rep movsb
 mov byte ptr [rdi],0
 jmp .Mi_git_drain
.Mi_git_check:
 cmp qword ptr [rip+.Mi_reaped],0
 jne .Mi_git_finished
 mov eax,61
 mov rdi,[rip+.Mi_pid]
 lea rsi,[rip+.Mi_status]
 mov edx,1
 xor r10d,r10d
 syscall
 test rax,rax
 jle .Mi_git_poll
 mov qword ptr [rip+.Mi_reaped],1
 # Reap descendants holding output pipe before final bounded drain.
 mov rdi,[rip+.Mi_pid]
 neg rdi
 mov eax,62
 mov esi,9
 syscall
 jmp .Mi_git_drain
.Mi_git_poll:
 mov eax,7
 lea rdi,[rip+.Mi_poll]
 mov esi,1
 mov edx,50
 syscall
 jmp .Mi_git_loop
.Mi_git_finished:
 mov eax,[rip+.Mi_status]
 mov edx,eax
 and edx,127
 test edx,edx
 jnz .Mi_git_signaled
 shr eax,8
 and eax,255
 mov [rip+.Mi_laststatus],rax
 test eax,eax
 jz .Mi_git_close
 mov rax,-5
 jmp .Mi_git_close
.Mi_git_signaled:
 neg rdx
 mov [rip+.Mi_laststatus],rdx
 mov rax,-5
 jmp .Mi_git_close
.Mi_git_cancelled:
 mov r12,-125
 jmp .Mi_git_kill
.Mi_git_timeout:
 mov r12,-110
.Mi_git_kill:
 mov rdi,[rip+.Mi_pid]
 neg rdi
 mov eax,62
 mov esi,9
 syscall
 mov rdi,[rip+.Mi_pid]
 mov eax,62
 mov esi,9
 syscall
.Mi_git_reap:
 mov eax,61
 mov rdi,[rip+.Mi_pid]
 lea rsi,[rip+.Mi_status]
 xor edx,edx
 xor r10d,r10d
 syscall
 cmp rax,-4
 je .Mi_git_reap
 mov rax,r12
.Mi_git_close:
 mov r13,rax
 mov eax,3
 mov edi,[rip+.Mi_pipe]
 syscall
 mov rax,r13
 jmp .Mi_git_return
.Mi_git_fork_error:
 mov r13,rax
 mov eax,3
 mov edi,[rip+.Mi_pipe]
 syscall
 mov eax,3
 mov edi,[rip+.Mi_pipe+4]
 syscall
 mov rax,r13
.Mi_git_return:
 pop r13
 pop r12
 pop rbx
 ret
.Mi_git_child:
 mov eax,157
 mov edi,1
 mov esi,9
 xor edx,edx
 xor r10d,r10d
 xor r8d,r8d
 syscall
 mov eax,110
 syscall
 cmp rax,[rip+.Mi_parentpid]
 jne .Mi_git_child_fail
 mov eax,109
 xor edi,edi
 xor esi,esi
 syscall
 mov eax,72
 mov edi,[rip+.Mi_pipe+4]
 mov esi,4
 xor edx,edx
 syscall
 mov eax,33
 mov edi,[rip+.Mi_pipe+4]
 mov esi,1
 syscall
 mov eax,33
 mov edi,[rip+.Mi_pipe+4]
 mov esi,2
 syscall
 mov eax,3
 mov edi,[rip+.Mi_pipe]
 syscall
 mov eax,3
 mov edi,[rip+.Mi_pipe+4]
 syscall
 mov eax,2
 lea rdi,[rip+.Mi_null]
 mov esi,0x80000
 xor edx,edx
 syscall
 test rax,rax
 js .Mi_git_child_fail
 mov rbx,rax
 mov rdi,rax
 xor esi,esi
 mov eax,33
 syscall
 mov eax,3
 mov rdi,rbx
 syscall
 mov eax,81
 mov rdi,[rip+.Mi_parentfd]
 syscall
 test rax,rax
 js .Mi_git_child_fail
 mov eax,59
 lea rdi,[rip+.Mi_git]
 lea rsi,[rip+.Mi_argv]
 mov rdx,[rip+.Mi_env]
 syscall
.Mi_git_child_fail:
 mov eax,60
 mov edi,127
 syscall
 ud2

# Read-only marketplace discovery. GET uses the native TLS/HTTP stack and never
# inherits model Authorization headers. Local roots/components are nofollow.
.section .rodata
.Md_dir: .asciz ".claude-plugin"
.Md_file: .asciz "marketplace.json"
.Md_plugins_key: .asciz "plugins"
.Md_desc_key: .asciz "description"
.Md_repo_key: .asciz "repo"
.Md_url_key: .asciz "url"
.Md_github: .asciz "github"
.Md_github_url: .asciz "https://github.com/"
.Md_raw_url: .asciz "https://raw.githubusercontent.com/"
.Md_raw_tail: .asciz "/HEAD/.claude-plugin/marketplace.json"
.Md_git_suffix: .asciz ".git"
.section .bss
.balign 16
.Md_source: .skip 4096
.Md_url: .skip 4096
.Md_base: .skip 4096
.Md_length: .skip 8
.Md_local: .skip 8
.Md_count: .skip 8
.Md_out: .skip 8
.Md_cap: .skip 8
.Md_json: .skip 65537
.Md_tokens: .skip 262144
.Md_strings: .skip 64*8704
.Md_offsets: .skip 64*16
.Md_text: .skip 4096
.section .text
.global ui_extension_discover,ui_extension_discover_item_read
# sourceZ,out24Bitems,cap,envp(reserved for git-backed discovery) ->count/error.
ui_extension_discover:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov [rip+.Md_out],rsi
 mov [rip+.Md_cap],rdx
 mov qword ptr [rip+.Md_count],0
 mov qword ptr [rip+.Md_length],0
 mov qword ptr [rip+.Md_local],0
 test rdi,rdi
 jz .Md_bad
 test rsi,rsi
 jz .Md_bad
 cmp rdx,64
 jbe .Md_cap_ok
 mov qword ptr [rip+.Md_cap],64
.Md_cap_ok:
 mov r12,rdi
 call .Mg_zlen
 test rax,rax
 jle .Md_bad
 cmp rax,3500
 ja .Md_bad
 lea rdi,[rip+.Md_source]
 mov rsi,r12
 inc rax
 mov rcx,rax
 rep movsb
 lea rdi,[rip+.Md_source]
 cmp byte ptr [rdi],47
 je .Md_local_read
 # Owner/repo shorthand or GitHub URL resolves the source's raw manifest.
 lea rsi,[rip+.Md_github_url]
 call .Mi_has_prefix
 test eax,eax
 jnz .Md_github_source
 lea rsi,[rip+.Mi_https]
 call .Mi_has_prefix
 test eax,eax
 jnz .Md_direct_http
 lea rsi,[rip+.Mi_http]
 call .Mi_has_prefix
 test eax,eax
 jnz .Md_direct_http
 # Strict owner/repo shorthand; no query/fragment/option or extra slash.
 lea rsi,[rip+.Md_source]
 xor ecx,ecx
 xor edx,edx
.Md_shorthand_check:
 mov al,[rsi+rcx]
 test al,al
 jz .Md_shorthand_done
 cmp al,47
 jne .Md_shorthand_character
 inc edx
 cmp edx,1
 ja .Md_bad
 jmp .Md_shorthand_next
.Md_shorthand_character:
 cmp al,45
 je .Md_shorthand_next
 cmp al,46
 je .Md_shorthand_next
 cmp al,95
 je .Md_shorthand_next
 mov r8b,al
 or r8b,32
 sub r8b,97
 cmp r8b,25
 jbe .Md_shorthand_next
 sub al,48
 cmp al,9
 ja .Md_bad
.Md_shorthand_next:
 inc ecx
 cmp ecx,255
 ja .Md_bad
 jmp .Md_shorthand_check
.Md_shorthand_done:
 cmp edx,1
 jne .Md_bad
 test ecx,ecx
 jz .Md_bad
 cmp byte ptr [rsi],47
 je .Md_bad
 cmp byte ptr [rsi+rcx-1],47
 je .Md_bad
 lea rsi,[rip+.Md_source]
 jmp .Md_build_raw
.Md_github_source:
 lea rsi,[rip+.Md_source+19]
.Md_build_raw:
 lea rdi,[rip+.Md_url]
 lea rdx,[rip+.Md_raw_url]
 mov ecx,34
 # Copy NUL-terminated prefix without relying on a hand-counted literal.
.Md_raw_prefix:
 mov al,[rdx]
 inc rdx
 test al,al
 jz .Md_raw_repo
 stosb
 jmp .Md_raw_prefix
.Md_raw_repo:
 xor ecx,ecx
.Md_raw_repo_copy:
 lodsb
 test al,al
 jz .Md_raw_repo_done
 cmp al,35
 je .Md_bad
 cmp al,63
 je .Md_bad
 stosb
 inc ecx
 cmp ecx,255
 ja .Md_bad
 jmp .Md_raw_repo_copy
.Md_raw_repo_done:
 cmp ecx,4
 jb .Md_append_raw_tail
 cmp dword ptr [rdi-4],0x7469672e
 jne .Md_append_raw_tail
 sub rdi,4
.Md_append_raw_tail:
 lea rsi,[rip+.Md_raw_tail]
.Md_raw_tail_copy:
 lodsb
 stosb
 test al,al
 jnz .Md_raw_tail_copy
 lea rdi,[rip+.Md_url]
 jmp .Md_fetch
.Md_direct_http:
 lea rdi,[rip+.Md_source]
.Md_fetch:
 lea rsi,[rip+.Md_receive]
 call http_get@PLT
 cmp rax,200
 jne .Md_fetch_error
 jmp .Md_parse
.Md_fetch_error:
 test rax,rax
 js .Md_return
 mov rax,-5
 jmp .Md_return
.Md_local_read:
 mov qword ptr [rip+.Md_local],1
 call .Mg_path_dir
 test rax,rax
 js .Md_local_file
 mov rbx,rax
 lea rdi,[rip+.Md_base]
 lea rsi,[rip+.Md_source]
.Md_base_copy:
 lodsb
 stosb
 test al,al
 jnz .Md_base_copy
 mov rdi,rbx
 lea rsi,[rip+.Md_dir]
 call .Mg_child_dir
 mov r12,rax
 mov eax,3
 mov rdi,rbx
 syscall
 test r12,r12
 js .Md_bad
 mov rdi,r12
 lea rsi,[rip+.Md_file]
 lea rdx,[rip+.Md_json]
 mov ecx,65537
 call .Mg_read_file
 mov r13,rax
 mov eax,3
 mov rdi,r12
 syscall
 mov rax,r13
 test rax,rax
 jle .Md_bad
 mov [rip+.Md_length],rax
 jmp .Md_parse
.Md_local_file:
 # Split an absolute local manifest path at its last slash; nofollow parent.
 lea rsi,[rip+.Md_source]
 lea rdi,[rip+.Md_base]
 xor ecx,ecx
 xor ebx,ebx
.Md_split_copy:
 mov al,[rsi+rcx]
 mov [rdi+rcx],al
 test al,al
 jz .Md_split_done
 cmp al,47
 jne .Md_split_next
 mov ebx,ecx
.Md_split_next:
 inc ecx
 jmp .Md_split_copy
.Md_split_done:
 test ebx,ebx
 jz .Md_bad
 mov byte ptr [rdi+rbx],0
 call .Mg_path_dir
 test rax,rax
 js .Md_bad
 mov r12,rax
 lea rsi,[rip+.Md_source]
 lea rsi,[rsi+rbx+1]
 mov rdi,r12
 lea rdx,[rip+.Md_json]
 mov ecx,65537
 call .Mg_read_file
 mov r13,rax
 mov eax,3
 mov rdi,r12
 syscall
 test r13,r13
 jle .Md_bad
 mov [rip+.Md_length],r13
.Md_parse:
 lea rdi,[rip+.Md_json]
 mov rsi,[rip+.Md_length]
 lea rdx,[rip+.Md_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Md_bad
 cmp qword ptr [rip+.Md_tokens+T_TYPE],JT_OBJECT
 jne .Md_bad
 lea rdi,[rip+.Md_json]
 lea rsi,[rip+.Md_tokens]
 xor edx,edx
 lea rcx,[rip+.Md_plugins_key]
 call json_find
 test rax,rax
 js .Md_bad
 mov rbx,rax
 shl rax,5
 lea r15,[rip+.Md_tokens]
 cmp qword ptr [r15+rax+T_TYPE],JT_ARRAY
 jne .Md_bad
 mov r14,[r15+rax+T_END]
 inc rbx
.Md_entry:
 cmp rbx,r14
 jae .Md_success
 mov rax,[rip+.Md_count]
 cmp rax,[rip+.Md_cap]
 jae .Md_success
 mov rax,rbx
 shl rax,5
 cmp qword ptr [r15+rax+T_TYPE],JT_OBJECT
 jne .Md_entry_next
 mov rdi,rbx
 lea rsi,[rip+.Ms_name_key]
 lea rdx,[rip+.Md_text]
 mov ecx,256
 call .Md_field
 test rax,rax
 jle .Md_entry_next
 lea rdi,[rip+.Md_text]
 call .Mg_name
 test rax,rax
 js .Md_entry_next
 mov r12,[rip+.Md_count]
 imul r12,r12,8704
 lea rax,[rip+.Md_strings]
 add r12,rax
 mov rdi,r12
 lea rsi,[rip+.Md_text]
.Md_label:
 lodsb
 stosb
 test al,al
 jnz .Md_label
 mov byte ptr [r12+512],0
 mov rdi,rbx
 lea rsi,[rip+.Md_desc_key]
 lea rdx,[r12+512]
 mov ecx,4096
 call .Md_field
 # Missing descriptions are genuinely empty; source metadata is not invented.
 mov rdi,rbx
 lea rsi,[rip+.Ms_source_key]
 lea rdx,[rip+.Md_text]
 mov ecx,4096
 call .Md_field
 test rax,rax
 js .Md_source_object
 cmp qword ptr [rip+.Md_local],0
 je .Md_remote_source
 cmp byte ptr [rip+.Md_text],46
 je .Md_relative_source
 cmp byte ptr [rip+.Md_text],47
 je .Md_plain_source
 jmp .Md_remote_source
.Md_relative_source:
 lea rdi,[rip+.Md_base]
 call .Mg_zlen
 mov r13,rax
 lea rdi,[rip+.Md_text]
 call .Mg_zlen
 add rax,r13
 dec rax # base+'/'+source after removing its './'
 cmp rax,4095
 ja .Md_entry_next
 # Reject all dot-dot components; these are metadata, never executable paths.
 lea rsi,[rip+.Md_text]
 cmp byte ptr [rsi],46
 jne .Md_entry_next
 cmp byte ptr [rsi+1],47
 jne .Md_entry_next
 add rsi,2
 lea rdi,[r12+4608]
 lea rdx,[rip+.Md_base]
.Md_relative_base:
 mov al,[rdx]
 inc rdx
 test al,al
 jz .Md_relative_slash
 stosb
 jmp .Md_relative_base
.Md_relative_slash:
 mov al,47
 stosb
 mov r13,rsi
.Md_relative_check:
 cmp byte ptr [rsi],0
 je .Md_relative_copy
 cmp byte ptr [rsi],46
 jne .Md_relative_check_next
 cmp byte ptr [rsi+1],46
 jne .Md_relative_check_next
 jmp .Md_entry_next
.Md_relative_check_next:
 inc rsi
 jmp .Md_relative_check
.Md_relative_copy:
 mov rsi,r13
 jmp .Md_source_copy
.Md_remote_source:
 cmp byte ptr [rip+.Md_text],46
 je .Md_entry_next
 cmp byte ptr [rip+.Md_text],47
 je .Md_entry_next
 cmp byte ptr [rip+.Md_text],126
 je .Md_entry_next
.Md_plain_source:
 lea rdi,[r12+4608]
 lea rsi,[rip+.Md_text]
 jmp .Md_source_copy
.Md_source_object:
 # Common source object {source:"github",repo:"owner/repo"} or {url:...}.
 lea rdi,[rip+.Md_json]
 lea rsi,[rip+.Md_tokens]
 mov rdx,rbx
 lea rcx,[rip+.Ms_source_key]
 call json_find
 test rax,rax
 js .Md_fallback_source
 mov r13,rax
 shl rax,5
 cmp qword ptr [r15+rax+T_TYPE],JT_OBJECT
 jne .Md_entry_next
 mov rdi,r13
 lea rsi,[rip+.Md_url_key]
 lea rdx,[rip+.Md_text]
 mov ecx,4096
 call .Md_field
 test rax,rax
 jg .Md_remote_source
 mov rdi,r13
 lea rsi,[rip+.Md_repo_key]
 lea rdx,[rip+.Md_text]
 mov ecx,4096
 call .Md_field
 test rax,rax
 jle .Md_entry_next
 cmp rax,4076 # GitHub prefix plus repository must fit one4096B value.
 ja .Md_entry_next
 lea rdi,[r12+4608]
 lea rsi,[rip+.Md_github_url]
.Md_repo_prefix:
 lodsb
 test al,al
 jz .Md_repo_body
 stosb
 jmp .Md_repo_prefix
.Md_repo_body:
 lea rsi,[rip+.Md_text]
 jmp .Md_source_copy
.Md_fallback_source:
 lea rdi,[r12+4608]
 lea rsi,[rip+.Md_source]
.Md_source_copy:
 lodsb
 stosb
 test al,al
 jnz .Md_source_copy
 mov rcx,[rip+.Md_count]
 mov rax,[rip+.Md_out]
 imul rdx,rcx,24
 add rax,rdx
 mov [rax],r12
 lea rdx,[r12+512]
 mov [rax+8],rdx
 lea rdx,[r12+4608]
 mov [rax+16],rdx
 shl rcx,4
 lea rax,[rip+.Md_offsets]
 mov rdx,rbx
 shl rdx,5
 mov rsi,[r15+rdx+T_START]
 mov [rax+rcx],rsi
 mov rsi,[r15+rdx+T_LEN]
 mov [rax+rcx+8],rsi
 inc qword ptr [rip+.Md_count]
.Md_entry_next:
 mov rax,rbx
 shl rax,5
 mov rbx,[r15+rax+T_END]
 jmp .Md_entry
.Md_success:
 mov rax,[rip+.Md_count]
 jmp .Md_return
.Md_bad:
 mov rax,-22
.Md_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Md_receive:
 mov rax,[rip+.Md_length]
 add rax,rsi
 cmp rax,65536
 ja .Md_receive_full
 mov [rip+.Md_length],rax
 lea rdx,[rip+.Md_json]
 add rdx,rax
 sub rdx,rsi
 mov rcx,rsi
 mov rsi,rdi
 mov rdi,rdx
 rep movsb
 xor eax,eax
 ret
.Md_receive_full:
 mov eax,1
 ret
.Md_field:
 push rbx
 push r12
 push r13
 mov r12,rdx
 mov r13,rcx
 mov rcx,rsi
 mov rdx,rdi
 lea rdi,[rip+.Md_json]
 lea rsi,[rip+.Md_tokens]
 call json_find
 test rax,rax
 js .Md_field_bad
 shl rax,5
 lea rbx,[rip+.Md_tokens]
 cmp qword ptr [rbx+rax+T_TYPE],JT_STRING
 jne .Md_field_bad
 mov rdi,r12
 lea rsi,[rip+.Md_json]
 add rsi,[rbx+rax+T_START]
 mov rdx,[rbx+rax+T_LEN]
 lea rcx,[r13-1]
 call json_decode
 test rax,rax
 js .Md_field_return
 mov byte ptr [r12+rax],0
 # No hidden NUL can change a displayed source into a different exec argv.
 xor ecx,ecx
.Md_field_nul:
 cmp rcx,rax
 jae .Md_field_return
 cmp byte ptr [r12+rcx],0
 je .Md_field_bad
 inc rcx
 jmp .Md_field_nul
.Md_field_bad:
 mov rax,-22
.Md_field_return:
 pop r13
 pop r12
 pop rbx
 ret
# index,out,cap ->strict raw plugin metadata JSON; real detail panes use this.
ui_extension_discover_item_read:
 cmp rdi,[rip+.Md_count]
 jae .Md_detail_bad
 test rsi,rsi
 jz .Md_detail_bad
 shl rdi,4
 lea r8,[rip+.Md_offsets]
 mov rax,[r8+rdi+8]
 cmp rax,rdx
 jae .Md_detail_full
 mov rcx,rax
 lea rdx,[rip+.Md_json]
 add rdx,[r8+rdi]
 mov rdi,rsi
 mov rsi,rdx
 rep movsb
 mov byte ptr [rdi],0
 ret
.Md_detail_full:
 mov rax,-28
 ret
.Md_detail_bad:
 mov rax,-22
 ret

# Resolve the actual project-then-user definition by safe filename. Raw YAML is
# retained for editing; advanced executors are never silently downgraded to a
# local worker when their native adapter has not been selected.
.section .rodata
.Ma_executor: .asciz "executor:"
.Ma_backend: .asciz "executionBackend:"
.Ma_mcp: .asciz "mcpServers:"
.Ma_hooks: .asciz "hooks:"
.section .bss
.Ma_name: .skip 68
.Ma_path: .skip 4096
.Ma_length: .skip 8
.section .text
.global ui_agent_definition_read,ui_agent_definition_path,ui_agent_prompt
ui_agent_definition_path:
 lea rax,[rip+.Ma_path]
 ret
ui_agent_definition_read:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 call .Mg_name
 test rax,rax
 js .Ma_bad
 lea rdi,[rip+.Ma_name]
 mov rsi,r12
 mov rcx,rax
 rep movsb
 lea rsi,[rip+.Mg_md]
 mov ecx,4
 rep movsb
 mov ebx,1
.Ma_read_scope:
 mov rdi,rbx
 xor esi,esi
 xor edx,edx
 call .Mg_open_tree
 test rax,rax
 js .Ma_next_scope
 mov r15,rax
 mov rdi,rax
 lea rsi,[rip+.Ma_name]
 lea rdx,[rip+.Mg_raw]
 mov ecx,65537
 call .Mg_read_file
 mov r12,rax
 mov eax,3
 mov rdi,r15
 syscall
 test r12,r12
 jle .Ma_next_scope
 mov rdi,r12
 call .Mg_validate_agent
 test rax,rax
 js .Ma_bad
 test r13,r13
 jz .Ma_bad
 cmp r12,r14
 jae .Ma_full
 mov rdi,r13
 lea rsi,[rip+.Mg_raw]
 mov rcx,r12
 rep movsb
 mov byte ptr [rdi],0
 lea rdi,[rip+.Ma_path]
 mov rax,rbx
 shl rax,13
 lea rsi,[rip+.Mg_prefixes]
 add rsi,rax
.Ma_path_copy:
 lodsb
 test al,al
 jz .Ma_path_name
 stosb
 jmp .Ma_path_copy
.Ma_path_name:
 lea rsi,[rip+.Ma_name]
.Ma_path_namecopy:
 lodsb
 stosb
 test al,al
 jnz .Ma_path_namecopy
 mov [rip+.Ma_length],r12
 mov rax,r12
 jmp .Ma_return
.Ma_next_scope:
 dec ebx
 jns .Ma_read_scope
 mov rax,-2
 jmp .Ma_return
.Ma_full:
 mov rax,-28
 jmp .Ma_return
.Ma_bad:
 mov rax,-22
.Ma_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
ui_agent_prompt:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 lea rsi,[rip+.Mg_quote]
 mov edx,65537
 call ui_agent_definition_read
 test rax,rax
 js .Ma_prompt_return
 mov rbx,rax
 lea r8,[rip+.Mg_quote]
 mov ecx,4
.Ma_header_line:
 cmp rcx,rbx
 jae .Ma_prompt_bad
 # Source field spelling is case sensitive. Fail closed on unsupported advanced
 # machinery instead of discarding it and using another execution backend.
 lea rdi,[r8+rcx]
 lea rsi,[rip+.Ma_executor]
 call .Mi_has_prefix
 test eax,eax
 jnz .Ma_prompt_unsupported
 lea rdi,[r8+rcx]
 lea rsi,[rip+.Ma_backend]
 call .Mi_has_prefix
 test eax,eax
 jnz .Ma_prompt_unsupported
 lea rdi,[r8+rcx]
 lea rsi,[rip+.Ma_mcp]
 call .Mi_has_prefix
 test eax,eax
 jnz .Ma_prompt_unsupported
 lea rdi,[r8+rcx]
 lea rsi,[rip+.Ma_hooks]
 call .Mi_has_prefix
 test eax,eax
 jnz .Ma_prompt_unsupported
.Ma_header_next:
 cmp rcx,rbx
 jae .Ma_prompt_bad
 cmp byte ptr [r8+rcx],10
 je .Ma_header_after_lf
 inc rcx
 jmp .Ma_header_next
.Ma_header_after_lf:
 inc rcx
 lea rax,[rcx+4]
 cmp rax,rbx
 ja .Ma_prompt_bad
 cmp dword ptr [r8+rcx],0x0a2d2d2d
 je .Ma_body
 jmp .Ma_header_line
.Ma_body:
 add rcx,4
 # Serializer uses one blank line after frontmatter; it is framing, not prompt.
 cmp rcx,rbx
 jae .Ma_prompt_bad
 cmp byte ptr [r8+rcx],10
 jne .Ma_body_copy
 inc rcx
.Ma_body_copy:
 mov rax,rbx
 sub rax,rcx
 test rax,rax
 jz .Ma_prompt_bad
 cmp rax,r13
 jae .Ma_prompt_full
 test r12,r12
 jz .Ma_prompt_bad
 lea rsi,[r8+rcx]
 mov rcx,rax
 mov rdi,r12
 rep movsb
 mov byte ptr [rdi],0
 jmp .Ma_prompt_return
.Ma_prompt_unsupported:
 mov rax,-95
 jmp .Ma_prompt_return
.Ma_prompt_bad:
 mov rax,-22
 jmp .Ma_prompt_return
.Ma_prompt_full:
 mov rax,-28
.Ma_prompt_return:
 pop r13
 pop r12
 pop rbx
 ret
