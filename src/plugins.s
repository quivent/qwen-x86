# [open integration] Native prompt/skill plugin loader. No code, hooks or MCP
# commands are executed. Cache is per process; fork workers inherit read-only data.
.intel_syntax noprefix
.equ P_MAP_BYTES,0x220000
.equ P_PLUGIN,384
.equ P_CMD,128
.equ P_CMDS,0x1800
.equ P_POOL,0x3000
.equ P_POOL_END,0x203000
.equ P_SCRATCH,0x203000
.equ P_TOKENS,0x213000
.equ P_DIR_FLAGS,0xb0000
.equ P_FILE_FLAGS,0xa0800
.section .bss
.balign 8
.Lpg_map: .skip 8
.Lpg_plugins: .skip 8
.Lpg_commands: .skip 8
.Lpg_pool: .skip 8
.Lpg_rejected: .skip 8
.section .rodata
.Lpg_slash: .asciz "/"
.Lpg_dot: .asciz "."
.Lpg_config: .asciz ".config"
.Lpg_qwengo: .asciz "qwen-go"
.Lpg_project: .asciz ".qwen-go"
.Lpg_plugins_dir: .asciz "plugins"
.Lpg_commands_dir: .asciz "commands"
.Lpg_skills_dir: .asciz "skills"
.Lpg_manifest: .asciz "qwen-extension.json"
.Lpg_skill_file: .asciz "SKILL.md"
.Lpg_name_key: .asciz "name"
.Lpg_desc_key: .asciz "description"
.Lpg_mcp_key: .asciz "mcpServers"
.Lpg_arguments: .ascii "$ARGUMENTS"
.Lpg_arg_label: .asciz "\n\nArguments: "
.Lpg_list_header: .asciz "Native prompt/skill plugins (explicit invocation only):\n"
.Lpg_list_none: .asciz "No prompt or skill plugins loaded.\n"
.Lpg_list_mcp: .asciz "  MCP configured: unsupported in this native build; no server started.\n"
.Lpg_list_command: .asciz "  /"
.Lpg_list_skill: .asciz "  /skill "
.Lpg_list_separator: .asciz " — "
.Lpg_list_rejected: .asciz "Some invalid, duplicate or over-limit plugin entries were skipped.\n"
.section .text
.Lpg_zlen:
 xor eax,eax
.Lpg_znext:
 cmp byte ptr [rdi+rax],0
 je .Lpg_zdone
 inc rax
 cmp rax,4096
 jb .Lpg_znext
 mov rax,-1
.Lpg_zdone:
 ret
# ASCII qualified name [A-Za-z0-9_-],length1..63 ->length/-1.
.Lpg_name:
 xor eax,eax
.Lpg_name_next:
 movzx edx,byte ptr [rdi+rax]
 test edx,edx
 jz .Lpg_name_end
 cmp eax,63
 jae .Lpg_name_bad
 cmp edx,45
 je .Lpg_name_char
 cmp edx,95
 je .Lpg_name_char
 mov ecx,edx
 sub ecx,48
 cmp ecx,9
 jbe .Lpg_name_char
 or edx,32
 sub edx,97
 cmp edx,25
 ja .Lpg_name_bad
.Lpg_name_char:
 inc eax
 jmp .Lpg_name_next
.Lpg_name_end:
 test eax,eax
 jz .Lpg_name_bad
 ret
.Lpg_name_bad:
 mov rax,-1
 ret
# Safe single directory/file component; no slash, controls, . or ..;max255.
.Lpg_component:
 xor eax,eax
.Lpg_component_next:
 movzx edx,byte ptr [rdi+rax]
 test edx,edx
 jz .Lpg_component_end
 cmp eax,255
 jae .Lpg_name_bad
 cmp edx,33
 jb .Lpg_name_bad
 cmp edx,127
 jae .Lpg_name_bad
 cmp edx,47
 je .Lpg_name_bad
 inc eax
 jmp .Lpg_component_next
.Lpg_component_end:
 test eax,eax
 jz .Lpg_name_bad
 cmp byte ptr [rdi],46
 jne .Lpg_component_ok
 cmp eax,1
 je .Lpg_name_bad
 cmp eax,2
 jne .Lpg_component_ok
 cmp byte ptr [rdi+1],46
 je .Lpg_name_bad
.Lpg_component_ok:
 ret
.Lpg_eq:
 xor eax,eax
.Lpg_eq_next:
 mov dl,byte ptr [rdi+rax]
 cmp dl,byte ptr [rsi+rax]
 jne .Lpg_eq_no
 test dl,dl
 jz .Lpg_eq_yes
 inc rax
 jmp .Lpg_eq_next
.Lpg_eq_yes:
 mov eax,1
 ret
.Lpg_eq_no:
 xor eax,eax
 ret
# Open one directory component, never following a symlink.
.Lpg_child_dir:
 mov eax,257
 mov edx,P_DIR_FLAGS
 xor r10d,r10d
 syscall
 ret
# Walk every component of a root path with O_NOFOLLOW; no ../ traversal.
.Lpg_path_dir:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,256
 mov r12,rdi
 test r12,r12
 jz .Lpg_path_bad
 call .Lpg_zlen
 test rax,rax
 jle .Lpg_path_bad
 mov r15,rax
 mov rdi,-100
 lea rsi,[rip+.Lpg_dot]
 cmp byte ptr [r12],47
 jne .Lpg_path_open
 lea rsi,[rip+.Lpg_slash]
.Lpg_path_open:
 call .Lpg_child_dir
 test rax,rax
 js .Lpg_path_bad
 mov r13,rax
 xor ebx,ebx
.Lpg_path_part:
 cmp rbx,r15
 jae .Lpg_path_ok
 cmp byte ptr [r12+rbx],47
 jne .Lpg_path_collect
 inc rbx
 jmp .Lpg_path_part
.Lpg_path_collect:
 xor r14d,r14d
.Lpg_path_copy:
 cmp rbx,r15
 jae .Lpg_path_collected
 mov al,byte ptr [r12+rbx]
 cmp al,47
 je .Lpg_path_collected
 cmp r14,255
 jae .Lpg_path_close_bad
 mov byte ptr [rsp+r14],al
 inc r14
 inc rbx
 jmp .Lpg_path_copy
.Lpg_path_collected:
 mov byte ptr [rsp+r14],0
 cmp r14,1
 jne .Lpg_path_validate
 cmp byte ptr [rsp],46
 je .Lpg_path_part
.Lpg_path_validate:
 mov rdi,rsp
 call .Lpg_component
 test rax,rax
 js .Lpg_path_close_bad
 mov rdi,r13
 mov rsi,rsp
 call .Lpg_child_dir
 mov r14,rax
 mov eax,3
 mov rdi,r13
 syscall
 test r14,r14
 js .Lpg_path_bad
 mov r13,r14
 jmp .Lpg_path_part
.Lpg_path_close_bad:
 mov eax,3
 mov rdi,r13
 syscall
.Lpg_path_bad:
 mov rax,-1
 jmp .Lpg_path_return
.Lpg_path_ok:
 mov rax,r13
.Lpg_path_return:
 add rsp,256
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Read one regular file(dirfd,name,dst,cap),NUL terminate,returnlen/-1.
.Lpg_read_file:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,144
 mov r12,rdx
 mov r13,rcx
 test r13,r13
 jz .Lpg_file_bad
 mov eax,257
 mov edx,P_FILE_FLAGS
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lpg_file_bad
 mov r14,rax
 mov eax,5
 mov rdi,r14
 mov rsi,rsp
 syscall
 test rax,rax
 js .Lpg_file_close_bad
 mov eax,dword ptr [rsp+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lpg_file_close_bad
 xor ebx,ebx
.Lpg_file_read:
 mov eax,0
 mov rdi,r14
 lea rsi,[r12+rbx]
 mov rdx,r13
 sub rdx,rbx
 jz .Lpg_file_close_bad
 syscall
 cmp rax,-4
 je .Lpg_file_read
 test rax,rax
 js .Lpg_file_close_bad
 jz .Lpg_file_ok
 add rbx,rax
 jmp .Lpg_file_read
.Lpg_file_ok:
 mov byte ptr [r12+rbx],0
 mov eax,3
 mov rdi,r14
 syscall
 mov rax,rbx
 jmp .Lpg_file_return
.Lpg_file_close_bad:
 mov eax,3
 mov rdi,r14
 syscall
.Lpg_file_bad:
 mov rax,-1
.Lpg_file_return:
 add rsp,144
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Walk bounded128 directory entries with a bound callback(fd,name,type,user1,user2).
.Lpg_walk:
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
.Lpg_walk_batch:
 mov eax,217
 mov rdi,r12
 mov rsi,rsp
 mov edx,8192
 syscall
 cmp rax,-4
 je .Lpg_walk_batch
 test rax,rax
 jle .Lpg_walk_done
 mov rbx,rsp
 lea rbp,[rsp+rax]
.Lpg_walk_entry:
 mov rax,rbp
 sub rax,rbx
 cmp rax,20
 jb .Lpg_walk_done
 movzx ecx,word ptr [rbx+16]
 cmp ecx,20
 jb .Lpg_walk_done
 cmp rcx,rax
 ja .Lpg_walk_done
 lea rax,[rbx+rcx]
 mov qword ptr [rsp+8200],rax
 inc qword ptr [rsp+8192]
 cmp qword ptr [rsp+8192],128
 ja .Lpg_walk_done
 sub ecx,19
 xor eax,eax
.Lpg_walk_nul:
 cmp byte ptr [rbx+rax+19],0
 je .Lpg_walk_component
 inc eax
 cmp eax,ecx
 jb .Lpg_walk_nul
 jmp .Lpg_walk_next
.Lpg_walk_component:
 lea rdi,[rbx+19]
 call .Lpg_component
 test rax,rax
 js .Lpg_walk_next
 mov rdi,r12
 lea rsi,[rbx+19]
 movzx edx,byte ptr [rbx+18]
 mov rcx,r14
 mov r8,r15
 call r13
.Lpg_walk_next:
 mov rbx,qword ptr [rsp+8200]
 cmp rbx,rbp
 jb .Lpg_walk_entry
 jmp .Lpg_walk_batch
.Lpg_walk_done:
 add rsp,8248
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# JSON manifest field decode(out,cap,key) from private scratch/tokens ->len/-1.
.Lpg_manifest_field:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 mov rbx,rdx
 mov rax,qword ptr [rip+.Lpg_map]
 lea rdi,[rax+P_SCRATCH]
 lea rsi,[rax+P_TOKENS]
 xor edx,edx
 mov rcx,rbx
 call json_find
 test rax,rax
 js .Lpg_field_bad
 shl rax,5
 mov rdx,qword ptr [rip+.Lpg_map]
 lea rdx,[rdx+rax+P_TOKENS]
 cmp qword ptr [rdx],3
 jne .Lpg_field_bad
 mov rax,qword ptr [rip+.Lpg_map]
 lea rsi,[rax+P_SCRATCH]
 add rsi,qword ptr [rdx+8]
 mov rdx,qword ptr [rdx+16]
 mov rdi,r12
 lea rcx,[r13-1]
 call json_decode
 test rax,rax
 js .Lpg_field_bad
 mov byte ptr [r12+rax],0
 jmp .Lpg_field_return
.Lpg_field_bad:
 mov rax,-1
.Lpg_field_return:
 pop r13
 pop r12
 pop rbx
 ret

# Root-directory callback. Project roots are scanned before user roots.
.Lpg_root_entry:
 cmp edx,4
 je .Lpg_load_plugin
 test edx,edx
 jne .Lpg_callback_done
.Lpg_load_plugin:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,4128
 mov r15,rcx
 cmp qword ptr [rip+.Lpg_plugins],16
 jae .Lpg_plugin_return
 call .Lpg_child_dir
 test rax,rax
 js .Lpg_plugin_return
 mov r12,rax
 mov r14,qword ptr [rip+.Lpg_map]
 mov rax,qword ptr [rip+.Lpg_plugins]
 imul rax,rax,P_PLUGIN
 lea r13,[r14+rax]
 mov rdi,r13
 xor eax,eax
 mov ecx,P_PLUGIN/8
 rep stosq
 mov rdi,r12
 lea rsi,[rip+.Lpg_manifest]
 lea rdx,[r14+P_SCRATCH]
 mov ecx,16384
 call .Lpg_read_file
 test rax,rax
 jle .Lpg_plugin_bad
 lea rdi,[r14+P_SCRATCH]
 mov rsi,rax
 lea rdx,[r14+P_TOKENS]
 mov ecx,1024
 call json_parse
 test rax,rax
 js .Lpg_plugin_bad
 cmp qword ptr [r14+P_TOKENS],1
 jne .Lpg_plugin_bad
 mov rdi,r13
 mov esi,64
 lea rdx,[rip+.Lpg_name_key]
 call .Lpg_manifest_field
 test rax,rax
 jle .Lpg_plugin_bad
 mov rbx,rax
 mov rdi,r13
 call .Lpg_name
 cmp rax,rbx
 jne .Lpg_plugin_bad
 xor ebx,ebx
.Lpg_plugin_duplicate:
 cmp rbx,qword ptr [rip+.Lpg_plugins]
 jae .Lpg_plugin_description
 mov rax,rbx
 imul rax,rax,P_PLUGIN
 lea rdi,[r14+rax]
 mov rsi,r13
 call .Lpg_eq
 test rax,rax
 jnz .Lpg_plugin_bad
 inc rbx
 jmp .Lpg_plugin_duplicate
.Lpg_plugin_description:
 lea rdi,[r14+P_SCRATCH]
 lea rsi,[r14+P_TOKENS]
 xor edx,edx
 lea rcx,[rip+.Lpg_desc_key]
 call json_find
 test rax,rax
 js .Lpg_plugin_mcp
 lea rdi,[r13+64]
 mov esi,256
 lea rdx,[rip+.Lpg_desc_key]
 call .Lpg_manifest_field
 test rax,rax
 js .Lpg_plugin_bad
 xor ecx,ecx
.Lpg_description_char:
 cmp rcx,rax
 jae .Lpg_plugin_mcp
 movzx edx,byte ptr [r13+rcx+64]
 cmp edx,32
 jb .Lpg_plugin_bad
 cmp edx,127
 je .Lpg_plugin_bad
 inc rcx
 jmp .Lpg_description_char
.Lpg_plugin_mcp:
 lea rdi,[r14+P_SCRATCH]
 lea rsi,[r14+P_TOKENS]
 xor edx,edx
 lea rcx,[rip+.Lpg_mcp_key]
 call json_find
 test rax,rax
 js .Lpg_plugin_register
 mov qword ptr [r13+320],1
 cmp qword ptr [rip+.Lpg_mcp_callback],0
 je .Lpg_plugin_register
 shl rax,5
 lea rdx,[r14+rax+P_TOKENS]
 cmp qword ptr [rdx],1
 jne .Lpg_plugin_mcp_bad
 mov rax,qword ptr [rdx+8]
 lea rax,[r14+rax+P_SCRATCH]
 mov qword ptr [rsp+4096],rax
 mov rax,qword ptr [rdx+16]
 mov qword ptr [rsp+4104],rax
 mov rdi,r12
 mov rsi,rsp
 mov edx,4096
 call .Lpg_fd_path
 test rax,rax
 js .Lpg_plugin_mcp_bad
 mov rdi,r13
 mov rsi,rsp
 mov rdx,qword ptr [rsp+4096]
 mov rcx,qword ptr [rsp+4104]
 call qword ptr [rip+.Lpg_mcp_callback]
 test rax,rax
 jne .Lpg_plugin_mcp_bad
 mov qword ptr [r13+320],2
 jmp .Lpg_plugin_register
.Lpg_plugin_mcp_bad:
 mov qword ptr [r13+320],3
.Lpg_plugin_register:
 mov qword ptr [r13+328],r15
 inc qword ptr [rip+.Lpg_plugins]
 mov rdi,r12
 lea rsi,[rip+.Lpg_commands_dir]
 call .Lpg_child_dir
 test rax,rax
 js .Lpg_plugin_skills
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Lpg_command_entry]
 mov rdx,r13
 xor ecx,ecx
 call .Lpg_walk
 mov eax,3
 mov rdi,rbx
 syscall
.Lpg_plugin_skills:
 mov rdi,r12
 lea rsi,[rip+.Lpg_skills_dir]
 call .Lpg_child_dir
 test rax,rax
 js .Lpg_plugin_close
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Lpg_skill_entry]
 mov rdx,r13
 xor ecx,ecx
 call .Lpg_walk
 mov eax,3
 mov rdi,rbx
 syscall
 jmp .Lpg_plugin_close
.Lpg_plugin_bad:
 inc qword ptr [rip+.Lpg_rejected]
.Lpg_plugin_close:
 mov eax,3
 mov rdi,r12
 syscall
.Lpg_plugin_return:
 add rsp,4128
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
.Lpg_callback_done:
 ret

# Strip optional YAML frontmatter, without interpreting executable YAML.
# input,len -> bodyptrrax,bodylenrdx,headerptrr8,headerlenr9;0 malformed.
.Lpg_strip:
 mov rax,rdi
 mov rdx,rsi
 xor r8d,r8d
 xor r9d,r9d
 cmp rsi,4
 jb .Lpg_strip_done
 cmp word ptr [rdi],0x2d2d
 jne .Lpg_strip_done
 cmp byte ptr [rdi+2],45
 jne .Lpg_strip_done
 lea r10,[rdi+4]
 cmp byte ptr [rdi+3],10
 je .Lpg_strip_header
 cmp rsi,5
 jb .Lpg_strip_done
 cmp word ptr [rdi+3],0x0a0d
 jne .Lpg_strip_done
 lea r10,[rdi+5]
.Lpg_strip_header:
 add rsi,rdi
 mov r8,r10
.Lpg_strip_line:
 cmp r10,rsi
 jae .Lpg_strip_bad
 mov r11,r10
.Lpg_strip_line_end:
 cmp r11,rsi
 jae .Lpg_strip_check
 cmp byte ptr [r11],10
 je .Lpg_strip_check
 inc r11
 jmp .Lpg_strip_line_end
.Lpg_strip_check:
 mov rcx,r11
 cmp rcx,r10
 je .Lpg_strip_next
 cmp byte ptr [rcx-1],13
 jne .Lpg_strip_length
 dec rcx
.Lpg_strip_length:
 sub rcx,r10
 cmp rcx,3
 jne .Lpg_strip_next
 cmp word ptr [r10],0x2d2d
 jne .Lpg_strip_next
 cmp byte ptr [r10+2],45
 jne .Lpg_strip_next
 mov r9,r10
 sub r9,r8
 mov rax,r11
 cmp rax,rsi
 jae .Lpg_strip_body
 inc rax
.Lpg_strip_body:
 mov rdx,rsi
 sub rdx,rax
 ret
.Lpg_strip_next:
 lea r10,[r11+1]
 jmp .Lpg_strip_line
.Lpg_strip_bad:
 xor eax,eax
.Lpg_strip_done:
 ret

# Simple bounded YAML name field, headerptr,len,dst64 ->0absent,1present,-1bad.
.Lpg_skill_metadata:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 lea r13,[rdi+rsi]
 mov r14,rdx
 xor r15d,r15d
.Lpg_meta_line:
 cmp r12,r13
 jae .Lpg_meta_done
 mov rbx,r12
.Lpg_meta_end:
 cmp rbx,r13
 jae .Lpg_meta_check
 cmp byte ptr [rbx],10
 je .Lpg_meta_check
 inc rbx
 jmp .Lpg_meta_end
.Lpg_meta_check:
 mov rax,rbx
 sub rax,r12
 cmp rax,5
 jb .Lpg_meta_next
 cmp dword ptr [r12],0x656d616e
 jne .Lpg_meta_next
 cmp byte ptr [r12+4],58
 jne .Lpg_meta_next
 test r15d,r15d
 jnz .Lpg_meta_bad
 lea rdi,[r12+5]
 mov rsi,rbx
.Lpg_meta_trim_start:
 cmp rdi,rsi
 jae .Lpg_meta_bad
 mov al,byte ptr [rdi]
 cmp al,32
 je .Lpg_meta_trim_one
 cmp al,9
 jne .Lpg_meta_trim_end
.Lpg_meta_trim_one:
 inc rdi
 jmp .Lpg_meta_trim_start
.Lpg_meta_trim_end:
 cmp rsi,rdi
 jbe .Lpg_meta_bad
 mov al,byte ptr [rsi-1]
 cmp al,13
 je .Lpg_meta_trim_last
 cmp al,32
 je .Lpg_meta_trim_last
 cmp al,9
 jne .Lpg_meta_quotes
.Lpg_meta_trim_last:
 dec rsi
 jmp .Lpg_meta_trim_end
.Lpg_meta_quotes:
 mov al,byte ptr [rdi]
 cmp al,34
 je .Lpg_meta_quoted
 cmp al,39
 jne .Lpg_meta_copy
.Lpg_meta_quoted:
 cmp al,byte ptr [rsi-1]
 jne .Lpg_meta_bad
 inc rdi
 dec rsi
.Lpg_meta_copy:
 sub rsi,rdi
 test rsi,rsi
 jz .Lpg_meta_bad
 cmp rsi,63
 ja .Lpg_meta_bad
 mov r15,rsi
 mov rcx,rsi
 mov rsi,rdi
 mov rdi,r14
 rep movsb
 mov byte ptr [rdi],0
 mov rdi,r14
 call .Lpg_name
 cmp rax,r15
 jne .Lpg_meta_bad
 mov r15d,1
.Lpg_meta_next:
 lea r12,[rbx+1]
 jmp .Lpg_meta_line
.Lpg_meta_done:
 mov rax,r15
 jmp .Lpg_meta_return
.Lpg_meta_bad:
 mov rax,-1
.Lpg_meta_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Register one prompt(plugin,namefallback,kind,fullbody,len),immutable copiedcache.
.Lpg_add_prompt:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,40
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 cmp qword ptr [rip+.Lpg_commands],32
 jae .Lpg_add_bad
 mov rdi,rcx
 mov rsi,r8
 call .Lpg_strip
 test rax,rax
 jz .Lpg_add_bad
 test rdx,rdx
 jz .Lpg_add_bad
 mov r15,rax
 mov rbx,rdx
 xor ecx,ecx
.Lpg_add_check_nul:
 cmp rcx,rbx
 jae .Lpg_add_nul_checked
 cmp byte ptr [r15+rcx],0
 je .Lpg_add_bad
 inc rcx
 jmp .Lpg_add_check_nul
.Lpg_add_nul_checked:
 mov qword ptr [rsp],r8
 mov qword ptr [rsp+8],r9
 mov rax,qword ptr [rip+.Lpg_commands]
 shl rax,7
 add rax,qword ptr [rip+.Lpg_map]
 add rax,P_CMDS
 mov qword ptr [rsp+16],rax
 mov rdi,r13
 call .Lpg_name
 test rax,rax
 js .Lpg_add_bad
 mov rcx,rax
 mov rsi,r13
 mov rdi,qword ptr [rsp+16]
 add rdi,32
 rep movsb
 mov byte ptr [rdi],0
 test r14,r14
 jz .Lpg_add_duplicate_start
 cmp qword ptr [rsp+8],0
 je .Lpg_add_duplicate_start
 mov rdi,qword ptr [rsp]
 mov rsi,qword ptr [rsp+8]
 mov rdx,qword ptr [rsp+16]
 add rdx,32
 call .Lpg_skill_metadata
 test rax,rax
 js .Lpg_add_bad
.Lpg_add_duplicate_start:
 xor ebp,ebp
.Lpg_add_duplicate:
 cmp rbp,qword ptr [rip+.Lpg_commands]
 jae .Lpg_add_copy
 mov rax,rbp
 shl rax,7
 add rax,qword ptr [rip+.Lpg_map]
 add rax,P_CMDS
 cmp qword ptr [rax],r12
 jne .Lpg_add_duplicate_next
 cmp qword ptr [rax+24],r14
 jne .Lpg_add_duplicate_next
 lea rdi,[rax+32]
 mov rsi,qword ptr [rsp+16]
 add rsi,32
 call .Lpg_eq
 test rax,rax
 jnz .Lpg_add_bad
.Lpg_add_duplicate_next:
 inc rbp
 jmp .Lpg_add_duplicate
.Lpg_add_copy:
 mov rbp,qword ptr [rip+.Lpg_pool]
 lea rax,[rbp+rbx+1]
 cmp rax,P_POOL_END
 ja .Lpg_add_bad
 mov qword ptr [rip+.Lpg_pool],rax
 add rbp,qword ptr [rip+.Lpg_map]
 mov rdi,rbp
 mov rsi,r15
 mov rcx,rbx
 rep movsb
 mov byte ptr [rdi],0
 mov rax,qword ptr [rsp+16]
 mov qword ptr [rax],r12
 mov qword ptr [rax+8],rbp
 mov qword ptr [rax+16],rbx
 mov qword ptr [rax+24],r14
 inc qword ptr [rip+.Lpg_commands]
 inc qword ptr [r12+344]
 xor eax,eax
 jmp .Lpg_add_return
.Lpg_add_bad:
 inc qword ptr [rip+.Lpg_rejected]
 mov rax,-1
.Lpg_add_return:
 add rsp,40
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# Flat Markdown command directory callback.
.Lpg_command_entry:
 cmp edx,8
 je .Lpg_command_load
 test edx,edx
 jne .Lpg_callback_done
.Lpg_command_load:
 push rbx
 push r12
 push r13
 sub rsp,64
 mov r12,rdi
 mov r13,rcx
 mov rbx,rsi
 mov rdi,rsi
 call .Lpg_zlen
 cmp rax,4
 jb .Lpg_command_return
 cmp rax,66
 ja .Lpg_command_return
 cmp byte ptr [rbx+rax-3],46
 jne .Lpg_command_return
 cmp word ptr [rbx+rax-2],0x646d
 jne .Lpg_command_return
 sub rax,3
 mov rcx,rax
 mov rsi,rbx
 mov rdi,rsp
 rep movsb
 mov byte ptr [rdi],0
 mov rdi,rsp
 call .Lpg_name
 test rax,rax
 js .Lpg_command_return
 mov rdi,r12
 mov rsi,rbx
 mov rdx,qword ptr [rip+.Lpg_map]
 add rdx,P_SCRATCH
 mov ecx,65536
 call .Lpg_read_file
 test rax,rax
 jle .Lpg_command_bad
 mov rdi,r13
 mov rsi,rsp
 xor edx,edx
 mov rcx,qword ptr [rip+.Lpg_map]
 add rcx,P_SCRATCH
 mov r8,rax
 call .Lpg_add_prompt
 jmp .Lpg_command_return
.Lpg_command_bad:
 inc qword ptr [rip+.Lpg_rejected]
.Lpg_command_return:
 add rsp,64
 pop r13
 pop r12
 pop rbx
 ret

# Skill directory callback; never follows directory or SKILL.md symlinks.
.Lpg_skill_entry:
 cmp edx,4
 je .Lpg_skill_load
 test edx,edx
 jne .Lpg_callback_done
.Lpg_skill_load:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r14,rdi
 mov r12,rsi
 mov r13,rcx
 mov rdi,rsi
 call .Lpg_name
 test rax,rax
 js .Lpg_skill_return
 mov rdi,r14
 mov rsi,r12
 call .Lpg_child_dir
 test rax,rax
 js .Lpg_skill_return
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Lpg_skill_file]
 mov rdx,qword ptr [rip+.Lpg_map]
 add rdx,P_SCRATCH
 mov ecx,65536
 call .Lpg_read_file
 mov r14,rax
 mov eax,3
 mov rdi,rbx
 syscall
 test r14,r14
 jle .Lpg_skill_bad
 mov rdi,r13
 mov rsi,r12
 mov edx,1
 mov rcx,qword ptr [rip+.Lpg_map]
 add rcx,P_SCRATCH
 mov r8,r14
 call .Lpg_add_prompt
 jmp .Lpg_skill_return
.Lpg_skill_bad:
 inc qword ptr [rip+.Lpg_rejected]
.Lpg_skill_return:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Scan project (.qwen-go/plugins) or user (.config/qwen-go/plugins) tree.
.Lpg_scan_tree:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r13,rsi
 call .Lpg_path_dir
 test rax,rax
 js .Lpg_tree_done
 mov r12,rax
 mov rdi,rax
 lea rsi,[rip+.Lpg_project]
 test r13,r13
 jnz .Lpg_tree_first
 lea rsi,[rip+.Lpg_config]
.Lpg_tree_first:
 call .Lpg_child_dir
 mov r14,rax
 mov eax,3
 mov rdi,r12
 syscall
 test r14,r14
 js .Lpg_tree_done
 mov r12,r14
 test r13,r13
 jnz .Lpg_tree_plugins
 mov rdi,r12
 lea rsi,[rip+.Lpg_qwengo]
 call .Lpg_child_dir
 mov r14,rax
 mov eax,3
 mov rdi,r12
 syscall
 test r14,r14
 js .Lpg_tree_done
 mov r12,r14
.Lpg_tree_plugins:
 mov rdi,r12
 lea rsi,[rip+.Lpg_plugins_dir]
 call .Lpg_child_dir
 mov r14,rax
 mov eax,3
 mov rdi,r12
 syscall
 test r14,r14
 js .Lpg_tree_done
 mov rdi,r14
 lea rsi,[rip+.Lpg_root_entry]
 mov rdx,r13
 xor ecx,ecx
 call .Lpg_walk
 mov eax,3
 mov rdi,r14
 syscall
.Lpg_tree_done:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.globl plugins_init
.type plugins_init,@function
plugins_init:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 cmp qword ptr [rip+.Lpg_map],0
 je .Lpg_init_map
 mov eax,11
 mov rdi,qword ptr [rip+.Lpg_map]
 mov esi,P_MAP_BYTES
 syscall
.Lpg_init_map:
 mov qword ptr [rip+.Lpg_map],0
 mov qword ptr [rip+.Lpg_plugins],0
 mov qword ptr [rip+.Lpg_commands],0
 mov qword ptr [rip+.Lpg_rejected],0
 mov qword ptr [rip+.Lpg_pool],P_POOL
 mov eax,9
 xor edi,edi
 mov esi,P_MAP_BYTES
 mov edx,3
 mov r10d,34
 mov r8,-1
 xor r9d,r9d
 syscall
 test rax,rax
 js .Lpg_init_bad
 mov qword ptr [rip+.Lpg_map],rax
 mov rdi,r12
 mov esi,1
 call .Lpg_scan_tree
 mov rdi,r13
 xor esi,esi
 call .Lpg_scan_tree
 xor eax,eax
 jmp .Lpg_init_return
.Lpg_init_bad:
 mov rax,-2
.Lpg_init_return:
 pop r13
 pop r12
 pop rbx
 ret
.size plugins_init,.-plugins_init

# append(out,capacity,current,source,count)->newlength/-2,always reserveNUL.
.Lpg_append:
 test rdi,rdi
 jz .Lpg_append_bad
 mov r9,rdx
 add r9,r8
 jc .Lpg_append_bad
 cmp r9,rsi
 jae .Lpg_append_bad
 add rdi,rdx
 mov rsi,rcx
 mov rcx,r8
 rep movsb
 mov byte ptr [rdi],0
 mov rax,r9
 ret
.Lpg_append_bad:
 mov rax,-2
 ret
.Lpg_appendz:
 sub rsp,8
 mov r10,rdi
 mov r11,rcx
 mov rdi,rcx
 call .Lpg_zlen
 mov rdi,r10
 mov rcx,r11
 add rsp,8
 test rax,rax
 js .Lpg_append_bad
 mov r8,rax
 jmp .Lpg_append
.Lpg_span_eq:
 xor eax,eax
.Lpg_span_eq_next:
 cmp rax,rdx
 jae .Lpg_eq_yes
 mov cl,byte ptr [rdi+rax]
 cmp cl,byte ptr [rsi+rax]
 jne .Lpg_eq_no
 inc rax
 jmp .Lpg_span_eq_next

.globl plugins_expand
.type plugins_expand,@function
# Inputz,out,cap ->expandedlength/-1notmatched/-2invalid. No implicit loading.
plugins_expand:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,200
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 cmp r12,r13
 je .Lpg_expand_bad
 test r13,r13
 jz .Lpg_expand_bad
 test r14,r14
 jz .Lpg_expand_bad
 mov byte ptr [r13],0
 test r12,r12
 jz .Lpg_expand_bad
 cmp qword ptr [rip+.Lpg_map],0
 je .Lpg_expand_unmatched
 cmp byte ptr [r12],47
 jne .Lpg_expand_unmatched
 xor eax,eax
.Lpg_expand_input_len:
 cmp byte ptr [r12+rax],0
 je .Lpg_expand_input_end
 inc rax
 cmp rax,65536
 jb .Lpg_expand_input_len
 jmp .Lpg_expand_bad
.Lpg_expand_input_end:
 lea r15,[r12+1]
 lea rbx,[r12+rax]
 mov qword ptr [rsp+144],0
 cmp rax,7
 jb .Lpg_expand_token
 cmp dword ptr [r12],0x696b732f
 jne .Lpg_expand_token
 cmp word ptr [r12+4],0x6c6c
 jne .Lpg_expand_token
 cmp byte ptr [r12+6],32
 je .Lpg_expand_skill
 cmp byte ptr [r12+6],9
 jne .Lpg_expand_token
.Lpg_expand_skill:
 lea r15,[r12+7]
 mov qword ptr [rsp+144],1
.Lpg_expand_skip_leading:
 cmp r15,rbx
 jae .Lpg_expand_bad
 cmp byte ptr [r15],32
 ja .Lpg_expand_token
 inc r15
 jmp .Lpg_expand_skip_leading
.Lpg_expand_token:
 mov r12,r15
 xor ebp,ebp
.Lpg_expand_find_colon:
 cmp r12,rbx
 jae .Lpg_expand_token_end
 movzx eax,byte ptr [r12]
 cmp eax,32
 jbe .Lpg_expand_token_end
 cmp eax,58
 jne .Lpg_expand_token_next
 test rbp,rbp
 jnz .Lpg_expand_bad
 mov rbp,r12
.Lpg_expand_token_next:
 inc r12
 jmp .Lpg_expand_find_colon
.Lpg_expand_token_end:
 test rbp,rbp
 jz .Lpg_expand_unmatched
 mov rcx,rbp
 sub rcx,r15
 test rcx,rcx
 jz .Lpg_expand_bad
 cmp rcx,63
 ja .Lpg_expand_bad
 mov rsi,r15
 mov rdi,rsp
 rep movsb
 mov byte ptr [rdi],0
 mov rcx,r12
 sub rcx,rbp
 dec rcx
 jle .Lpg_expand_bad
 cmp rcx,63
 ja .Lpg_expand_bad
 lea rsi,[rbp+1]
 lea rdi,[rsp+64]
 rep movsb
 mov byte ptr [rdi],0
 mov rdi,rsp
 call .Lpg_name
 test rax,rax
 js .Lpg_expand_bad
 lea rdi,[rsp+64]
 call .Lpg_name
 test rax,rax
 js .Lpg_expand_bad
.Lpg_expand_args:
 cmp r12,rbx
 jae .Lpg_expand_args_ready
 cmp byte ptr [r12],32
 ja .Lpg_expand_args_ready
 inc r12
 jmp .Lpg_expand_args
.Lpg_expand_args_ready:
 mov qword ptr [rsp+128],r12
 sub rbx,r12
 mov qword ptr [rsp+136],rbx
 xor ebp,ebp
.Lpg_expand_lookup:
 cmp rbp,qword ptr [rip+.Lpg_commands]
 jae .Lpg_expand_unmatched
 mov rax,rbp
 shl rax,7
 add rax,qword ptr [rip+.Lpg_map]
 add rax,P_CMDS
 mov qword ptr [rsp+168],rax
 mov rcx,qword ptr [rsp+144]
 cmp rcx,qword ptr [rax+24]
 jne .Lpg_expand_lookup_next
 mov rdi,qword ptr [rax]
 mov rsi,rsp
 call .Lpg_eq
 test rax,rax
 jz .Lpg_expand_lookup_next
 mov rdi,qword ptr [rsp+168]
 add rdi,32
 lea rsi,[rsp+64]
 call .Lpg_eq
 test rax,rax
 jnz .Lpg_expand_found
.Lpg_expand_lookup_next:
 inc rbp
 jmp .Lpg_expand_lookup
.Lpg_expand_found:
 mov rax,qword ptr [rsp+168]
 mov r15,qword ptr [rax+8]
 mov rbx,qword ptr [rax+16]
 xor ebp,ebp
 mov qword ptr [rsp+176],0
 mov qword ptr [rsp+184],0
 mov qword ptr [rsp+192],0
.Lpg_expand_body:
 cmp rbp,rbx
 jae .Lpg_expand_tail
 mov rax,rbx
 sub rax,rbp
 cmp rax,10
 jb .Lpg_expand_body_next
 cmp byte ptr [r15+rbp],36
 jne .Lpg_expand_body_next
 lea rdi,[r15+rbp]
 lea rsi,[rip+.Lpg_arguments]
 mov edx,10
 call .Lpg_span_eq
 test rax,rax
 jz .Lpg_expand_body_next
 mov rdi,r13
 mov rsi,r14
 mov rdx,qword ptr [rsp+176]
 mov rcx,qword ptr [rsp+192]
 lea rcx,[r15+rcx]
 mov r8,rbp
 sub r8,qword ptr [rsp+192]
 call .Lpg_append
 test rax,rax
 js .Lpg_expand_bad
 mov rdx,rax
 mov rdi,r13
 mov rsi,r14
 mov rcx,qword ptr [rsp+128]
 mov r8,qword ptr [rsp+136]
 call .Lpg_append
 test rax,rax
 js .Lpg_expand_bad
 mov qword ptr [rsp+176],rax
 mov qword ptr [rsp+184],1
 add rbp,10
 mov qword ptr [rsp+192],rbp
 jmp .Lpg_expand_body
.Lpg_expand_body_next:
 inc rbp
 jmp .Lpg_expand_body
.Lpg_expand_tail:
 mov rdi,r13
 mov rsi,r14
 mov rdx,qword ptr [rsp+176]
 mov rcx,qword ptr [rsp+192]
 lea rcx,[r15+rcx]
 mov r8,rbx
 sub r8,qword ptr [rsp+192]
 call .Lpg_append
 test rax,rax
 js .Lpg_expand_bad
 mov qword ptr [rsp+176],rax
 cmp qword ptr [rsp+184],0
 jne .Lpg_expand_return
 cmp qword ptr [rsp+136],0
 je .Lpg_expand_return
 mov rdi,r13
 mov rsi,r14
 mov rdx,rax
 lea rcx,[rip+.Lpg_arg_label]
 call .Lpg_appendz
 test rax,rax
 js .Lpg_expand_bad
 mov rdi,r13
 mov rsi,r14
 mov rdx,rax
 mov rcx,qword ptr [rsp+128]
 mov r8,qword ptr [rsp+136]
 call .Lpg_append
 test rax,rax
 js .Lpg_expand_bad
 jmp .Lpg_expand_return
.Lpg_expand_unmatched:
 mov rax,-1
 jmp .Lpg_expand_return
.Lpg_expand_bad:
 test r13,r13
 jz .Lpg_expand_bad_code
 test r14,r14
 jz .Lpg_expand_bad_code
 mov byte ptr [r13],0
.Lpg_expand_bad_code:
 mov rax,-2
.Lpg_expand_return:
 add rsp,200
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.size plugins_expand,.-plugins_expand

.globl plugins_list
.type plugins_list,@function
plugins_list:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 test r12,r12
 jz .Lpg_list_bad
 test r13,r13
 jz .Lpg_list_bad
 mov byte ptr [r12],0
 mov rdi,r12
 mov rsi,r13
 xor edx,edx
 lea rcx,[rip+.Lpg_list_header]
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov r14,rax
 cmp qword ptr [rip+.Lpg_plugins],0
 jne .Lpg_list_plugins
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 lea rcx,[rip+.Lpg_list_none]
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov r14,rax
.Lpg_list_plugins:
 xor r15d,r15d
.Lpg_list_plugin:
 cmp r15,qword ptr [rip+.Lpg_plugins]
 jae .Lpg_list_finish
 mov rax,r15
 imul rax,rax,P_PLUGIN
 add rax,qword ptr [rip+.Lpg_map]
 mov rbx,rax
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 mov rcx,rbx
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 lea rcx,[rip+.Lpg_list_separator]
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 lea rcx,[rbx+64]
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov r14,rax
 mov byte ptr [rsp],10
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 mov rcx,rsp
 mov r8d,1
 call .Lpg_append
 test rax,rax
 js .Lpg_list_bad
 mov r14,rax
 cmp qword ptr [rbx+320],0
 je .Lpg_list_commands
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 lea rcx,[rip+.Lpg_list_mcp]
 cmp qword ptr [rbx+320],2
 jne .Lpg_list_mcp_error
 lea rcx,[rip+.Lpg_list_mcp_ready]
 jmp .Lpg_list_mcp_selected
.Lpg_list_mcp_error:
 cmp qword ptr [rbx+320],3
 jne .Lpg_list_mcp_selected
 lea rcx,[rip+.Lpg_list_mcp_bad]
.Lpg_list_mcp_selected:
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov r14,rax
.Lpg_list_commands:
 xor ebp,ebp
.Lpg_list_command_loop:
 cmp rbp,qword ptr [rip+.Lpg_commands]
 jae .Lpg_list_next_plugin
 mov rax,rbp
 shl rax,7
 add rax,qword ptr [rip+.Lpg_map]
 add rax,P_CMDS
 cmp qword ptr [rax],rbx
 jne .Lpg_list_command_next
 mov qword ptr [rsp+8],rax
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 lea rcx,[rip+.Lpg_list_command]
 cmp qword ptr [rax+24],0
 je .Lpg_list_cmd_prefix
 lea rcx,[rip+.Lpg_list_skill]
.Lpg_list_cmd_prefix:
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 mov rcx,rbx
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov byte ptr [rsp],58
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 mov rcx,rsp
 mov r8d,1
 call .Lpg_append
 test rax,rax
 js .Lpg_list_bad
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 mov rcx,qword ptr [rsp+8]
 add rcx,32
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 mov byte ptr [rsp],10
 mov rdi,r12
 mov rsi,r13
 mov rdx,rax
 mov rcx,rsp
 mov r8d,1
 call .Lpg_append
 test rax,rax
 js .Lpg_list_bad
 mov r14,rax
.Lpg_list_command_next:
 inc rbp
 jmp .Lpg_list_command_loop
.Lpg_list_next_plugin:
 inc r15
 jmp .Lpg_list_plugin
.Lpg_list_finish:
 mov rax,r14
 cmp qword ptr [rip+.Lpg_rejected],0
 je .Lpg_list_return
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 lea rcx,[rip+.Lpg_list_rejected]
 call .Lpg_appendz
 test rax,rax
 js .Lpg_list_bad
 jmp .Lpg_list_return
.Lpg_list_bad:
 test r12,r12
 jz .Lpg_list_bad_code
 test r13,r13
 jz .Lpg_list_bad_code
 mov byte ptr [r12],0
.Lpg_list_bad_code:
 mov rax,-2
.Lpg_list_return:
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.size plugins_list,.-plugins_list

# Register metadata-only MCP callback; loader never starts external programs.
.globl plugins_set_mcp_callback
plugins_set_mcp_callback:
 mov qword ptr [rip+.Lpg_mcp_callback],rdi
 xor eax,eax
 ret

# Canonical opened-directory path via the kernel's own fd link (not user paths).
.Lpg_fd_path:
 push rbx
 push r12
 push r13
 sub rsp,64
 mov r12,rsi
 mov r13,rdx
 test r13,r13
 jz .Lpg_fd_path_bad
 mov rax,rdi
 mov rbx,rax
 lea rsi,[rip+.Lpg_proc_prefix]
 mov rdi,rsp
 mov ecx,14
 rep movsb
 mov eax,ebx
 xor ecx,ecx
 mov r8d,10
.Lpg_fd_digits:
 xor edx,edx
 div r8d
 add dl,48
 mov byte ptr [rsp+rcx+32],dl
 inc ecx
 test eax,eax
 jnz .Lpg_fd_digits
 xor edx,edx
.Lpg_fd_reverse:
 dec ecx
 mov al,byte ptr [rsp+rcx+32]
 mov byte ptr [rsp+rdx+14],al
 inc edx
 test ecx,ecx
 jnz .Lpg_fd_reverse
 mov byte ptr [rsp+rdx+14],0
 mov eax,267
 mov rdi,-100
 mov rsi,rsp
 mov rdx,r12
 lea r10,[r13-1]
 syscall
 test rax,rax
 js .Lpg_fd_path_bad
 lea rdx,[r13-1]
 cmp rax,rdx
 jae .Lpg_fd_path_bad
 mov byte ptr [r12+rax],0
 jmp .Lpg_fd_path_return
.Lpg_fd_path_bad:
 mov rax,-1
.Lpg_fd_path_return:
 add rsp,64
 pop r13
 pop r12
 pop rbx
 ret
.section .bss
.balign 8
.Lpg_mcp_callback: .skip 8
.section .rodata
.Lpg_proc_prefix: .ascii "/proc/self/fd/"
.Lpg_list_mcp_ready: .asciz "  MCP configured: server startup and tool calls require approval.\n"
.Lpg_list_mcp_bad: .asciz "  MCP configuration rejected or unavailable; no server started.\n"
.section .note.GNU-stack,"",@progbits
