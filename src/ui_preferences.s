# Native UI preferences in application-owned files only. Unknown JSON keys are
# preserved byte-for-byte when themeName is changed. Workspace overrides User.
.include "abi.inc"
.section .rodata
.Pr_config: .asciz ".config"
.Pr_userdir: .asciz "qwen-x86"
.Pr_projectdir: .asciz ".qwen-x86"
.Pr_filename: .asciz "ui.json"
.Pr_legacy_dir: .asciz ".qwen"
.Pr_legacy_file: .asciz "settings.json"
.Pr_theme_key: .asciz "themeName"
.Pr_key: .ascii "\"themeName\":"
.equ PR_KEY,.-.Pr_key
.Pr_new: .ascii "{\"schemaVersion\":1,"
.equ PR_NEW,.-.Pr_new
.Pr_hex: .ascii "0123456789abcdef"
.section .bss
.balign 16
.Pr_home: .skip 4096
.Pr_cwd: .skip 4096
.Pr_allowed: .skip 8
.Pr_ready: .skip 8
.Pr_scope: .skip 8
.Pr_create: .skip 8
.Pr_dir: .skip 8
.Pr_fd: .skip 8
.Pr_created: .skip 8
.Pr_length: .skip 8
.Pr_quote_length: .skip 8
.Pr_newlength: .skip 8
.Pr_start: .skip 8
.Pr_end: .skip 8
.Pr_result: .skip 8
.Pr_bulk: .skip 8
.Pr_staged_ready: .skip 8
.Pr_staged_length: .skip 8
.Pr_staged_json: .skip 65537
.Pr_legacy: .skip 8
.Pr_user_only: .skip 8
.Pr_sensitive: .skip 8
.Pr_active_key: .skip 8
.Pr_active_literal: .skip 8
.Pr_active_keylen: .skip 8
.Pr_name: .skip 4096
.Pr_value: .skip 4096
.Pr_quote: .skip 24578
.Pr_temp: .skip 64
.Pr_random: .skip 16
.Pr_stat: .skip 144
.Pr_json: .skip 65537
.Pr_newjson: .skip 65537
.Pr_tokens: .skip 8192*32
.text
.global ui_preferences_config
ui_preferences_config:
 push r12
 push r13
 push r14
 mov qword ptr [rip+.Pr_ready],0
 mov [rip+.Pr_allowed],rdx
 mov r12,rdi
 mov r13,rsi
 test rdi,rdi
 jz .Pr_config_bad
 test rsi,rsi
 jz .Pr_config_bad
 cmp byte ptr [rdi],47
 jne .Pr_config_bad
 cmp byte ptr [rsi],47
 jne .Pr_config_bad
 mov rsi,r12
 lea rdi,[rip+.Pr_home]
 call .Pr_copy_path
 test rax,rax
 js .Pr_config_return
 mov rsi,r13
 lea rdi,[rip+.Pr_cwd]
 call .Pr_copy_path
 test rax,rax
 js .Pr_config_return
 mov qword ptr [rip+.Pr_ready],1
 xor eax,eax
 jmp .Pr_config_return
.Pr_config_bad:
 mov rax,-22
.Pr_config_return:
 pop r14
 pop r13
 pop r12
 ret
.Pr_copy_path:
 xor ecx,ecx
.Pr_copy_path_loop:
 cmp ecx,4000
 jae .Pr_copy_path_bad
 lodsb
 cmp al,32
 jb .Pr_copy_path_control
 cmp al,127
 je .Pr_copy_path_bad
.Pr_copy_path_store:
 stosb
 inc ecx
 test al,al
 jnz .Pr_copy_path_loop
 xor eax,eax
 ret
.Pr_copy_path_control:
 test al,al
 jz .Pr_copy_path_store
.Pr_copy_path_bad:
 mov rax,-22
 ret
# Open HOME/.config/qwen-x86 or WORKSPACE/.qwen-x86 without symlinks.
.Pr_open_dir:
 mov qword ptr [rip+.Pr_dir],-1
 mov qword ptr [rip+.Pr_fd],-1
 mov qword ptr [rip+.Pr_created],0
 lea rdi,[rip+.Pr_home]
 cmp qword ptr [rip+.Pr_scope],0
 je .Pr_open_base
 lea rdi,[rip+.Pr_cwd]
.Pr_open_base:
 mov eax,2
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .Pr_open_return
 mov [rip+.Pr_dir],rax
 cmp qword ptr [rip+.Pr_legacy],0
 jne .Pr_open_legacy
 cmp qword ptr [rip+.Pr_scope],0
 jne .Pr_open_project
 lea rsi,[rip+.Pr_config]
 call .Pr_open_component
 test rax,rax
 js .Pr_open_return
 lea rsi,[rip+.Pr_userdir]
 jmp .Pr_open_component
.Pr_open_project:
 lea rsi,[rip+.Pr_projectdir]
 jmp .Pr_open_component
.Pr_open_legacy:
 lea rsi,[rip+.Pr_legacy_dir]
.Pr_open_component:
 push rbx
 push r12
 sub rsp,8
 mov r12,rsi
.Pr_component_again:
 mov eax,257
 mov rdi,[rip+.Pr_dir]
 mov rsi,r12
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 jns .Pr_component_success
 cmp rax,-2
 jne .Pr_component_return
 cmp qword ptr [rip+.Pr_create],0
 je .Pr_component_return
 mov eax,258
 mov rdi,[rip+.Pr_dir]
 mov rsi,r12
 mov edx,0700
 syscall
 test rax,rax
 jns .Pr_component_again
 cmp rax,-17
 je .Pr_component_again
 jmp .Pr_component_return
.Pr_component_success:
 mov rbx,rax
 mov eax,3
 mov rdi,[rip+.Pr_dir]
 syscall
 mov [rip+.Pr_dir],rbx
 xor eax,eax
.Pr_component_return:
 add rsp,8
 pop r12
 pop rbx
.Pr_open_return:
 ret
.Pr_close:
 mov rdi,[rip+.Pr_fd]
 test rdi,rdi
 js .Pr_close_dir
 mov eax,3
 syscall
 mov qword ptr [rip+.Pr_fd],-1
.Pr_close_dir:
 mov rdi,[rip+.Pr_dir]
 test rdi,rdi
 js .Pr_close_return
 mov eax,3
 syscall
 mov qword ptr [rip+.Pr_dir],-1
.Pr_close_return:
 ret
# Read and validate an owner-regular <=64KiB JSON object using the opened dir.
.Pr_load:
 sub rsp,8
 cmp qword ptr [rip+.Pr_staged_ready],0
 je .Pr_load_filesystem
 lea rdi,[rip+.Pr_json]
 lea rsi,[rip+.Pr_staged_json]
 mov rcx,[rip+.Pr_staged_length]
 mov [rip+.Pr_length],rcx
 rep movsb
 jmp .Pr_load_parse
.Pr_load_filesystem:
 mov eax,257
 mov rdi,[rip+.Pr_dir]
 lea rsi,[rip+.Pr_filename]
 cmp qword ptr [rip+.Pr_legacy],0
 je .Pr_load_filename_ready
 lea rsi,[rip+.Pr_legacy_file]
.Pr_load_filename_ready:
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Pr_load_return
 mov [rip+.Pr_fd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Pr_stat]
 syscall
 test rax,rax
 js .Pr_load_return
 mov eax,[rip+.Pr_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Pr_load_invalid
 mov eax,107
 syscall
 cmp eax,[rip+.Pr_stat+28]
 jne .Pr_load_invalid
 cmp qword ptr [rip+.Pr_sensitive],0
 je .Pr_load_permissions_done
 cmp qword ptr [rip+.Pr_sensitive],2
 jne .Pr_load_public_permissions
 test dword ptr [rip+.Pr_stat+24],077
 jnz .Pr_load_invalid
 jmp .Pr_load_permissions_done
.Pr_load_public_permissions:
 test dword ptr [rip+.Pr_stat+24],022
 jnz .Pr_load_invalid
.Pr_load_permissions_done:
 cmp qword ptr [rip+.Pr_stat+48],65536
 ja .Pr_load_full
 mov qword ptr [rip+.Pr_length],0
.Pr_load_read:
 xor eax,eax
 mov rdi,[rip+.Pr_fd]
 lea rsi,[rip+.Pr_json]
 add rsi,[rip+.Pr_length]
 mov edx,65537
 sub rdx,[rip+.Pr_length]
 jz .Pr_load_full
 syscall
 cmp rax,-4
 je .Pr_load_read
 test rax,rax
 js .Pr_load_return
 jz .Pr_load_parse
 add [rip+.Pr_length],rax
 jmp .Pr_load_read
.Pr_load_parse:
 cmp qword ptr [rip+.Pr_length],65536
 ja .Pr_load_full
 lea rdi,[rip+.Pr_json]
 mov rsi,[rip+.Pr_length]
 lea rdx,[rip+.Pr_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Pr_load_invalid
 cmp qword ptr [rip+.Pr_tokens],JT_OBJECT
 jne .Pr_load_invalid
 xor eax,eax
 jmp .Pr_load_return
.Pr_load_invalid:
 mov rax,-22
 jmp .Pr_load_return
.Pr_load_full:
 mov rax,-28
.Pr_load_return:
 add rsp,8
 ret
.global ui_preferences_get_theme
ui_preferences_get_theme:
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],0
 lea rax,[rip+.Pr_theme_key]
 mov [rip+.Pr_active_key],rax
.Pr_get_string:
 mov qword ptr [rip+.Pr_legacy],0
 push rbx
 sub rsp,16
 xor ebx,ebx
 cmp qword ptr [rip+.Pr_ready],0
 je .Pr_get_return
 mov qword ptr [rip+.Pr_create],0
 mov qword ptr [rip+.Pr_scope],1
 cmp qword ptr [rip+.Pr_user_only],0
 je .Pr_get_scope
 mov qword ptr [rip+.Pr_scope],0
.Pr_get_scope:
 call .Pr_open_dir
 test rax,rax
 js .Pr_get_next
 call .Pr_load
 test rax,rax
 js .Pr_get_next
 lea rdi,[rip+.Pr_json]
 lea rsi,[rip+.Pr_tokens]
 xor edx,edx
 mov rcx,[rip+.Pr_active_key]
 call json_find
 test rax,rax
 js .Pr_get_next
 shl rax,5
 lea rdx,[rip+.Pr_tokens]
 add rdx,rax
 cmp qword ptr [rdx+T_TYPE],JT_STRING
 jne .Pr_get_next
 lea rdi,[rip+.Pr_value]
 lea rsi,[rip+.Pr_json]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 mov ecx,4095
 call json_decode
 test rax,rax
 jle .Pr_get_next
 lea rdi,[rip+.Pr_value]
 mov byte ptr [rdi+rax],0
 mov rcx,rax
 call .Pr_name_valid
 test eax,eax
 jz .Pr_get_next
 lea rbx,[rip+.Pr_value]
 call .Pr_close
 jmp .Pr_get_return
.Pr_get_next:
 call .Pr_close
 cmp qword ptr [rip+.Pr_scope],0
 je .Pr_get_return
 mov qword ptr [rip+.Pr_scope],0
 jmp .Pr_get_scope
.Pr_get_return:
 mov rax,rbx
 add rsp,16
 pop rbx
 ret
# rdi ptr,rcx byte count ->eax1 nonempty name without display controls/NUL.
.Pr_name_valid:
 test rcx,rcx
 jz .Pr_name_no
.Pr_name_valid_loop:
 mov al,[rdi]
 cmp al,32
 jb .Pr_name_no
 cmp al,127
 je .Pr_name_no
 inc rdi
 dec rcx
 jnz .Pr_name_valid_loop
 mov eax,1
 ret
.Pr_name_no:
 xor eax,eax
 ret
.global ui_preferences_set_theme
ui_preferences_set_theme:
 lea rax,[rip+.Pr_theme_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_key]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],PR_KEY
.Pr_set_string:
 mov qword ptr [rip+.Pr_legacy],0
 mov qword ptr [rip+.Pr_sensitive],0
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov qword ptr [rip+.Pr_result],-22
 mov qword ptr [rip+.Pr_dir],-1
 mov qword ptr [rip+.Pr_fd],-1
 mov qword ptr [rip+.Pr_created],0
 cmp qword ptr [rip+.Pr_ready],0
 je .Pr_set_return
 cmp rsi,1
 ja .Pr_set_return
 mov [rip+.Pr_scope],rsi
 test rdi,rdi
 jz .Pr_set_return
 mov rsi,rdi
 lea rdi,[rip+.Pr_name]
 xor ecx,ecx
.Pr_set_name_copy:
 cmp ecx,4095
 jae .Pr_set_return
 lodsb
 test al,al
 jz .Pr_set_name_end
 cmp al,32
 jb .Pr_set_return
 cmp al,127
 je .Pr_set_return
 stosb
 inc ecx
 jmp .Pr_set_name_copy
.Pr_set_name_end:
 test ecx,ecx
 jnz .Pr_set_name_nonempty
 lea rax,[rip+.Pr_api_key_key]
 cmp rax,[rip+.Pr_active_key]
 je .Pr_set_name_nonempty
 lea rax,[rip+.Pr_api_key_env_key]
 cmp rax,[rip+.Pr_active_key]
 jne .Pr_set_return
.Pr_set_name_nonempty:
 mov byte ptr [rdi],0
 lea rdi,[rip+.Pr_quote]
 lea rsi,[rip+.Pr_name]
 mov rdx,rcx
 mov ecx,24578
 call json_quote
 test rax,rax
 js .Pr_set_return
 mov [rip+.Pr_quote_length],rax
 # --no-save applies themes for this process through root but never writes.
 cmp qword ptr [rip+.Pr_allowed],0
 je .Pr_set_success
 mov qword ptr [rip+.Pr_create],1
 call .Pr_open_dir
 test rax,rax
 js .Pr_set_error
 call .Pr_load
 test rax,rax
 jns .Pr_set_existing
 cmp rax,-2
 jne .Pr_set_error
 lea rdi,[rip+.Pr_newjson]
 lea rsi,[rip+.Pr_new]
 mov ecx,PR_NEW
 rep movsb
 mov rsi,[rip+.Pr_active_literal]
 mov rcx,[rip+.Pr_active_keylen]
 rep movsb
 lea rsi,[rip+.Pr_quote]
 mov rcx,[rip+.Pr_quote_length]
 rep movsb
 mov word ptr [rdi],0x0a7d
 add rdi,2
 lea rax,[rip+.Pr_newjson]
 sub rdi,rax
 mov [rip+.Pr_newlength],rdi
 jmp .Pr_set_write
.Pr_set_existing:
 lea rdi,[rip+.Pr_json]
 lea rsi,[rip+.Pr_tokens]
 xor edx,edx
 mov rcx,[rip+.Pr_active_key]
 call json_find
 test rax,rax
 js .Pr_set_insert_key
 shl rax,5
 lea rdx,[rip+.Pr_tokens]
 add rdx,rax
 mov r12,[rdx+T_START]
 mov r13,r12
 add r13,[rdx+T_LEN]
 cmp qword ptr [rdx+T_TYPE],JT_STRING
 jne .Pr_set_replace_range
 dec r12
 inc r13
.Pr_set_replace_range:
 mov r14,[rip+.Pr_length]
 sub r14,r13
 add r14,r12
 add r14,[rip+.Pr_quote_length]
 cmp r14,65536
 ja .Pr_set_full
 lea rdi,[rip+.Pr_newjson]
 lea rsi,[rip+.Pr_json]
 mov rcx,r12
 rep movsb
 lea rsi,[rip+.Pr_quote]
 mov rcx,[rip+.Pr_quote_length]
 rep movsb
 lea rsi,[rip+.Pr_json]
 add rsi,r13
 mov rcx,[rip+.Pr_length]
 sub rcx,r13
 rep movsb
 mov [rip+.Pr_newlength],r14
 jmp .Pr_set_write
.Pr_set_insert_key:
 mov r12,[rip+.Pr_tokens+T_START]
 add r12,[rip+.Pr_tokens+T_LEN]
 dec r12
 mov r14,[rip+.Pr_length]
 add r14,[rip+.Pr_active_keylen]
 add r14,[rip+.Pr_quote_length]
 xor r13d,r13d
 cmp qword ptr [rip+.Pr_tokens+T_END],1
 jbe .Pr_set_insert_size
 mov r13d,1
 inc r14
.Pr_set_insert_size:
 cmp r14,65536
 ja .Pr_set_full
 lea rdi,[rip+.Pr_newjson]
 lea rsi,[rip+.Pr_json]
 mov rcx,r12
 rep movsb
 test r13,r13
 jz .Pr_set_insert_literal
 mov byte ptr [rdi],44
 inc rdi
.Pr_set_insert_literal:
 mov rsi,[rip+.Pr_active_literal]
 mov rcx,[rip+.Pr_active_keylen]
 rep movsb
 lea rsi,[rip+.Pr_quote]
 mov rcx,[rip+.Pr_quote_length]
 rep movsb
 lea rsi,[rip+.Pr_json]
 add rsi,r12
 mov rcx,[rip+.Pr_length]
 sub rcx,r12
 rep movsb
 mov [rip+.Pr_newlength],r14
.Pr_set_write:
 cmp qword ptr [rip+.Pr_bulk],0
 je .Pr_set_write_commit
 lea rdi,[rip+.Pr_staged_json]
 lea rsi,[rip+.Pr_newjson]
 mov rcx,[rip+.Pr_newlength]
 mov [rip+.Pr_staged_length],rcx
 rep movsb
 mov qword ptr [rip+.Pr_staged_ready],1
 jmp .Pr_set_success
.Pr_set_write_commit:
 # Close the old read descriptor before opening a fresh private atomic write.
 mov rdi,[rip+.Pr_fd]
 test rdi,rdi
 js .Pr_set_random
 mov eax,3
 syscall
 mov qword ptr [rip+.Pr_fd],-1
.Pr_set_random:
 xor ebx,ebx
.Pr_set_random_more:
 mov eax,318
 lea rdi,[rip+.Pr_random]
 add rdi,rbx
 mov esi,16
 sub rsi,rbx
 xor edx,edx
 syscall
 cmp rax,-4
 je .Pr_set_random_more
 test rax,rax
 jle .Pr_set_io
 add rbx,rax
 cmp rbx,16
 jb .Pr_set_random_more
 lea rdi,[rip+.Pr_temp]
 movabs rax,0x006e6f736a2e6975 # ui.json +NUL
 stosq
 dec rdi
 mov dword ptr [rdi],0x706d742e
 add rdi,4
 mov byte ptr [rdi],45
 inc rdi
 lea rsi,[rip+.Pr_random]
 lea r8,[rip+.Pr_hex]
 mov ecx,16
.Pr_set_hex:
 movzx eax,byte ptr [rsi]
 inc rsi
 mov edx,eax
 shr eax,4
 and edx,15
 mov al,[r8+rax]
 stosb
 mov al,[r8+rdx]
 stosb
 loop .Pr_set_hex
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,[rip+.Pr_dir]
 lea rsi,[rip+.Pr_temp]
 mov edx,0xa00c1
 mov r10d,0600
 syscall
 test rax,rax
 js .Pr_set_error
 mov [rip+.Pr_fd],rax
 mov qword ptr [rip+.Pr_created],1
 mov rdi,rax
 mov eax,91
 mov esi,0600
 syscall
 test rax,rax
 js .Pr_set_error
 xor ebx,ebx
.Pr_set_write_more:
 cmp rbx,[rip+.Pr_newlength]
 jae .Pr_set_fsync
 mov eax,1
 mov rdi,[rip+.Pr_fd]
 lea rsi,[rip+.Pr_newjson]
 add rsi,rbx
 mov rdx,[rip+.Pr_newlength]
 sub rdx,rbx
 syscall
 cmp rax,-4
 je .Pr_set_write_more
 test rax,rax
 jle .Pr_set_io
 add rbx,rax
 jmp .Pr_set_write_more
.Pr_set_fsync:
 mov eax,74
 mov rdi,[rip+.Pr_fd]
 syscall
 cmp rax,-4
 je .Pr_set_fsync
 test rax,rax
 js .Pr_set_error
 mov eax,3
 mov rdi,[rip+.Pr_fd]
 syscall
 mov qword ptr [rip+.Pr_fd],-1
 mov eax,264
 mov rdi,[rip+.Pr_dir]
 lea rsi,[rip+.Pr_temp]
 mov rdx,rdi
 lea r10,[rip+.Pr_filename]
 syscall
 test rax,rax
 js .Pr_set_error
 mov qword ptr [rip+.Pr_created],0
 mov eax,74
 mov rdi,[rip+.Pr_dir]
 syscall
 test rax,rax
 js .Pr_set_error
.Pr_set_success:
 mov qword ptr [rip+.Pr_result],0
 jmp .Pr_set_return
.Pr_set_full:
 mov rax,-28
 jmp .Pr_set_error
.Pr_set_io:
 mov rax,-5
.Pr_set_error:
 mov [rip+.Pr_result],rax
.Pr_set_return:
 cmp qword ptr [rip+.Pr_created],0
 je .Pr_set_close
 mov eax,263
 mov rdi,[rip+.Pr_dir]
 lea rsi,[rip+.Pr_temp]
 xor edx,edx
 syscall
.Pr_set_close:
 call .Pr_close
 mov rax,[rip+.Pr_result]
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.section .note.GNU-stack,"",@progbits

.section .text
.globl ui_preferences_get_model,ui_preferences_set_model
ui_preferences_get_model:
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],1
 push r12
 lea rax,[rip+.Pr_model_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_model_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_model_value]
 mov r12,rdi
.Pr_model_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_model_get_copy
 mov rax,r12
.Pr_model_get_done:
 pop r12
 ret
ui_preferences_set_model:
 lea rax,[rip+.Pr_model_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_model_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_model_literal_len
 jmp .Pr_set_string
.section .rodata
.Pr_model_key: .asciz "model"
.Pr_model_literal: .ascii "\"model\":"
.equ .Pr_model_literal_len,.-.Pr_model_literal
.section .bss
.Pr_model_value: .skip 4096
.section .text
.globl ui_preferences_get_base_url,ui_preferences_set_base_url
ui_preferences_get_base_url:
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],1
 push r12
 lea rax,[rip+.Pr_base_url_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_base_url_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_base_url_value]
 mov r12,rdi
.Pr_base_url_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_base_url_get_copy
 mov rax,r12
.Pr_base_url_get_done:
 pop r12
 ret
ui_preferences_set_base_url:
 lea rax,[rip+.Pr_base_url_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_base_url_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_base_url_literal_len
 jmp .Pr_set_string
.section .rodata
.Pr_base_url_key: .asciz "baseUrl"
.Pr_base_url_literal: .ascii "\"baseUrl\":"
.equ .Pr_base_url_literal_len,.-.Pr_base_url_literal
.section .bss
.Pr_base_url_value: .skip 4096
.section .text
.globl ui_preferences_get_auth_type,ui_preferences_set_auth_type
ui_preferences_get_auth_type:
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],1
 push r12
 lea rax,[rip+.Pr_auth_type_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_auth_type_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_auth_type_value]
 mov r12,rdi
.Pr_auth_type_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_auth_type_get_copy
 mov rax,r12
.Pr_auth_type_get_done:
 pop r12
 ret
ui_preferences_set_auth_type:
 lea rax,[rip+.Pr_auth_type_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_auth_type_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_auth_type_literal_len
 jmp .Pr_set_string
.section .rodata
.Pr_auth_type_key: .asciz "authType"
.Pr_auth_type_literal: .ascii "\"authType\":"
.equ .Pr_auth_type_literal_len,.-.Pr_auth_type_literal
.section .bss
.Pr_auth_type_value: .skip 4096
.section .text
.globl ui_preferences_get_api_key_env,ui_preferences_set_api_key_env
ui_preferences_get_api_key_env:
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],1
 push r12
 lea rax,[rip+.Pr_api_key_env_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_api_key_env_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_api_key_env_value]
 mov r12,rdi
.Pr_api_key_env_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_api_key_env_get_copy
 mov rax,r12
.Pr_api_key_env_get_done:
 pop r12
 ret
ui_preferences_set_api_key_env:
 test rdi,rdi
 jz .Pr_env_bad
 cmp byte ptr [rdi],0
 je .Pr_env_valid
 xor ecx,ecx
.Pr_env_char:
 mov al,[rdi+rcx]
 test al,al
 jz .Pr_env_end
 cmp al,'_'
 je .Pr_env_next
 cmp al,'0'
 jb .Pr_env_alpha
 cmp al,'9'
 ja .Pr_env_alpha
 test rcx,rcx
 jz .Pr_env_bad
 jmp .Pr_env_next
.Pr_env_alpha:
 or al,32
 cmp al,'a'
 jb .Pr_env_bad
 cmp al,'z'
 ja .Pr_env_bad
.Pr_env_next:
 inc rcx
 cmp rcx,255
 jb .Pr_env_char
.Pr_env_bad:
 mov rax,-22
 ret
.Pr_env_end:
 test rcx,rcx
 jz .Pr_env_bad
.Pr_env_valid:
 lea rax,[rip+.Pr_api_key_env_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_api_key_env_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_api_key_env_literal_len
 jmp .Pr_set_string
.section .rodata
.Pr_api_key_env_key: .asciz "apiKeyEnv"
.Pr_api_key_env_literal: .ascii "\"apiKeyEnv\":"
.equ .Pr_api_key_env_literal_len,.-.Pr_api_key_env_literal
.section .bss
.Pr_api_key_env_value: .skip 4096
.section .text

.globl ui_preferences_read_settings
# scope0User1Workspace,kind0native1originalQwen,out,cap ->len/error.
# Read only, no symlinks, owner regular file, no group/world writable settings.
ui_preferences_read_settings:
 push r12
 push r13
 push r14
 mov r12,rdx
 mov r13,rcx
 mov r14,-22
 cmp qword ptr [rip+.Pr_ready],0
 je .Pr_read_settings_done
 cmp rdi,1
 ja .Pr_read_settings_done
 cmp rsi,1
 ja .Pr_read_settings_done
 test r12,r12
 jz .Pr_read_settings_done
 mov [rip+.Pr_scope],rdi
 mov [rip+.Pr_legacy],rsi
 mov qword ptr [rip+.Pr_sensitive],1
 mov qword ptr [rip+.Pr_create],0
 call .Pr_open_dir
 test rax,rax
 js .Pr_read_settings_error
 call .Pr_load
 test rax,rax
 js .Pr_read_settings_error
 mov r14,[rip+.Pr_length]
 cmp r14,r13
 ja .Pr_read_settings_capacity
 mov rdi,r12
 lea rsi,[rip+.Pr_json]
 mov rcx,r14
 rep movsb
 jmp .Pr_read_settings_close
.Pr_read_settings_capacity:
 mov rax,-28
.Pr_read_settings_error:
 mov r14,rax
.Pr_read_settings_close:
 call .Pr_close
.Pr_read_settings_done:
 mov qword ptr [rip+.Pr_legacy],0
 mov rax,r14
 pop r14
 pop r13
 pop r12
 ret

.globl ui_preferences_get_api_key,ui_preferences_set_api_key
# API key is always User scope, returned only to transport/account controller.
# UI must render configured/missing, never this raw value.
ui_preferences_get_api_key:
 push r12
 mov qword ptr [rip+.Pr_user_only],1
 mov qword ptr [rip+.Pr_sensitive],2
 lea rax,[rip+.Pr_api_key_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_api_key_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_api_key_value]
 mov r12,rdi
.Pr_api_key_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_api_key_get_copy
 mov rax,r12
.Pr_api_key_get_done:
 pop r12
 ret
ui_preferences_set_api_key:
 test rsi,rsi
 jnz .Pr_api_key_bad_scope
 lea rax,[rip+.Pr_api_key_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_api_key_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_api_key_literal_len
 jmp .Pr_set_string
.Pr_api_key_bad_scope:
 mov rax,-22
 ret
.section .rodata
.Pr_api_key_key: .asciz "apiKey"
.Pr_api_key_literal: .ascii "\"apiKey\":"
.equ .Pr_api_key_literal_len,.-.Pr_api_key_literal
.section .bss
.Pr_api_key_value: .skip 4096
.section .text

.section .text
.globl ui_preferences_get_key_source,ui_preferences_set_key_source
ui_preferences_get_key_source:
 push r12
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],1
 lea rax,[rip+.Pr_key_source_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_key_source_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_key_source_value]
 mov r12,rdi
.Pr_key_source_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_key_source_get_copy
 mov rax,r12
.Pr_key_source_get_done:
 pop r12
 ret
ui_preferences_set_key_source:
 lea rax,[rip+.Pr_key_source_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_key_source_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_key_source_literal_len
 jmp .Pr_set_string
.section .rodata
.Pr_key_source_key: .asciz "apiKeySource"
.Pr_key_source_literal: .ascii "\"apiKeySource\":"
.equ .Pr_key_source_literal_len,.-.Pr_key_source_literal
.section .bss
.Pr_key_source_value: .skip 4096

.section .text
.globl ui_preferences_get_approval_mode,ui_preferences_set_approval_mode
ui_preferences_get_approval_mode:
 push r12
 mov qword ptr [rip+.Pr_user_only],0
 mov qword ptr [rip+.Pr_sensitive],1
 lea rax,[rip+.Pr_approval_mode_key]
 mov [rip+.Pr_active_key],rax
 call .Pr_get_string
 test rax,rax
 jz .Pr_approval_mode_get_done
 mov rsi,rax
 lea rdi,[rip+.Pr_approval_mode_value]
 mov r12,rdi
.Pr_approval_mode_get_copy:
 lodsb
 stosb
 test al,al
 jnz .Pr_approval_mode_get_copy
 mov rax,r12
.Pr_approval_mode_get_done:
 pop r12
 ret
ui_preferences_set_approval_mode:
 lea rax,[rip+.Pr_approval_mode_key]
 mov [rip+.Pr_active_key],rax
 lea rax,[rip+.Pr_approval_mode_literal]
 mov [rip+.Pr_active_literal],rax
 mov qword ptr [rip+.Pr_active_keylen],OFFSET FLAT:.Pr_approval_mode_literal_len
 jmp .Pr_set_string
.section .rodata
.Pr_approval_mode_key: .asciz "approvalMode"
.Pr_approval_mode_literal: .ascii "\"approvalMode\":"
.equ .Pr_approval_mode_literal_len,.-.Pr_approval_mode_literal
.section .bss
.Pr_approval_mode_value: .skip 4096

.text
.globl ui_preferences_set_connection
# record6ptrs={protocol,model,baseURL,keyEnv,rawKey,keySource},User scope0 only.
# All edits stage in memory; one final private atomic file replacement commits.
ui_preferences_set_connection:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r14,-22
 test rsi,rsi
 jnz .Pr_connection_done
 test rdi,rdi
 jz .Pr_connection_done
 mov r12,rdi
 xor r13d,r13d
 mov qword ptr [rip+.Pr_bulk],1
 mov qword ptr [rip+.Pr_staged_ready],0
.Pr_connection_field:
 mov rdi,[r12+r13*8]
 test rdi,rdi
 jnz .Pr_connection_value
 cmp r13,3
 je .Pr_connection_empty
 cmp r13,4
 jne .Pr_connection_fail
.Pr_connection_empty:
 lea rdi,[rip+.Pr_empty]
.Pr_connection_value:
 xor esi,esi
 lea rax,[rip+.Pr_connection_setters]
 mov rax,[rax+r13*8]
 call rax
 test rax,rax
 js .Pr_connection_error
 inc r13
 cmp r13,6
 jb .Pr_connection_field
 mov qword ptr [rip+.Pr_bulk],0
 mov rdi,[r12]
 xor esi,esi
 call ui_preferences_set_auth_type
 mov r14,rax
 jmp .Pr_connection_clear
.Pr_connection_fail:
 mov rax,-22
.Pr_connection_error:
 mov r14,rax
.Pr_connection_clear:
 mov qword ptr [rip+.Pr_bulk],0
 mov qword ptr [rip+.Pr_staged_ready],0
 mov qword ptr [rip+.Pr_staged_length],0
.Pr_connection_done:
 mov rax,r14
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Pr_empty: .asciz ""
.balign 8
.Pr_connection_setters: .quad ui_preferences_set_auth_type,ui_preferences_set_model,ui_preferences_set_base_url,ui_preferences_set_api_key_env,ui_preferences_set_api_key,ui_preferences_set_key_source
.section .note.GNU-stack,"",@progbits
.text
.globl ui_preferences_get_api_key_for
# protocolZ,baseURLz ->User-only key orNULL. Endpoint-bound credential routing:
# untrusted workspace base/auth overrides cannot redirect the User saved key.
ui_preferences_get_api_key_for:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 test rdi,rdi
 jz .Pr_bound_done
 test rsi,rsi
 jz .Pr_bound_done
 cmp qword ptr [rip+.Pr_ready],0
 je .Pr_bound_done
 mov qword ptr [rip+.Pr_scope],0
 mov qword ptr [rip+.Pr_legacy],0
 mov qword ptr [rip+.Pr_create],0
 mov qword ptr [rip+.Pr_sensitive],2
 call .Pr_open_dir
 test rax,rax
 js .Pr_bound_close
 call .Pr_load
 test rax,rax
 js .Pr_bound_close
 lea rdi,[rip+.Pr_json]
 lea rsi,[rip+.Pr_tokens]
 xor edx,edx
 lea rcx,[rip+.Pr_auth_type_key]
 call json_find
 test rax,rax
 js .Pr_bound_close
 mov rdi,r12
 call .Pr_bound_match
 test eax,eax
 jz .Pr_bound_close
 lea rdi,[rip+.Pr_json]
 lea rsi,[rip+.Pr_tokens]
 xor edx,edx
 lea rcx,[rip+.Pr_base_url_key]
 call json_find
 test rax,rax
 js .Pr_bound_close
 mov rdi,r13
 call .Pr_bound_match
 test eax,eax
 jz .Pr_bound_close
 lea rdi,[rip+.Pr_json]
 lea rsi,[rip+.Pr_tokens]
 xor edx,edx
 lea rcx,[rip+.Pr_api_key_key]
 call json_find
 test rax,rax
 js .Pr_bound_close
 shl rax,5
 lea rbx,[rip+.Pr_tokens]
 add rbx,rax
 cmp qword ptr [rbx],JT_STRING
 jne .Pr_bound_close
 lea rdi,[rip+.Pr_api_key_value]
 lea rsi,[rip+.Pr_json]
 add rsi,[rbx+T_START]
 mov rdx,[rbx+T_LEN]
 mov ecx,4095
 call json_decode
 test rax,rax
 jle .Pr_bound_close
 lea rdi,[rip+.Pr_api_key_value]
 mov byte ptr [rdi+rax],0
 mov rcx,rax
 call .Pr_name_valid
 test eax,eax
 jz .Pr_bound_close
 lea r14,[rip+.Pr_api_key_value]
.Pr_bound_close:
 call .Pr_close
.Pr_bound_done:
 mov rax,r14
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# tokenindex,targetZ ->1 exact decoded match,0other.
.Pr_bound_match:
 push r12
 mov r12,rdi
 shl rax,5
 lea rdx,[rip+.Pr_tokens]
 add rdx,rax
 cmp qword ptr [rdx],JT_STRING
 jne .Pr_bound_no
 lea rdi,[rip+.Pr_value]
 lea rsi,[rip+.Pr_json]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 mov ecx,4095
 call json_decode
 test rax,rax
 js .Pr_bound_no
 lea rdx,[rip+.Pr_value]
 mov byte ptr [rdx+rax],0
 xor ecx,ecx
.Pr_bound_compare:
 mov al,[rdx+rcx]
 cmp al,[r12+rcx]
 jne .Pr_bound_no
 inc rcx
 test al,al
 jnz .Pr_bound_compare
 mov eax,1
 pop r12
 ret
.Pr_bound_no:
 xor eax,eax
 pop r12
 ret
.section .note.GNU-stack,"",@progbits
