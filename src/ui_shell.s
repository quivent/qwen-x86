# Direct user shell mode. Executor uses the existing native shell tool; root
# temporarily grants its explicitly submitted command and restores policy.
# Shell input history is independent of model prompts:100 MRU unique commands.
.include "abi.inc"
.section .rodata
.Sh_name: .asciz "run_shell"
.Sh_json_prefix: .ascii "{\"command\":"
.equ SH_JSON_PREFIX,11
.Sh_json_suffix: .ascii ",\"timeout_seconds\":120}"
.equ SH_JSON_SUFFIX,23
.Sh_before: .ascii "I ran the following shell command:\n```sh\n"
.equ SH_BEFORE,41
.Sh_between: .ascii "\n```\n\nThis produced the following result:\n```\n"
.equ SH_BETWEEN,46
.Sh_after: .ascii "\n```"
.equ SH_AFTER,4
.Sh_empty: .asciz "(Command produced no output)"
.Sh_binary: .asciz "[Command produced binary output, which is not shown.]"
.Sh_truncated: .ascii "\n... (truncated)"
.equ SH_TRUNCATED,16
.section .bss
.balign 16
.Sh_args: .skip 393300
.Sh_quote: .skip 393218
.Sh_hcount: .skip 8
.Sh_hpos: .skip 8
.Sh_hinitialized: .skip 8
.Sh_hlens: .skip 100*8
.Sh_horder: .skip 100*8
.Sh_htext: .skip 100*65536
.text
.global ui_shell_execute
ui_shell_execute:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 cmp rsi,65535
 ja .Sh_execute_invalid
 test rdi,rdi
 jz .Sh_execute_invalid
 lea rdi,[rip+.Sh_args]
 lea rsi,[rip+.Sh_json_prefix]
 mov ecx,SH_JSON_PREFIX
 rep movsb
 mov rsi,r12
 mov rdx,r13
 mov ecx,393218
 call json_quote
 test rax,rax
 js .Sh_execute_done
 mov rbx,rax
 lea rdi,[rip+.Sh_args+SH_JSON_PREFIX]
 add rdi,rbx
 lea rsi,[rip+.Sh_json_suffix]
 mov ecx,SH_JSON_SUFFIX
 rep movsb
 lea rdx,[rbx+SH_JSON_PREFIX+SH_JSON_SUFFIX]
 lea rdi,[rip+.Sh_name]
 lea rsi,[rip+.Sh_args]
 mov rcx,r14
 mov r8,r15
 call tool_execute
 jmp .Sh_execute_done
.Sh_execute_invalid:
 mov rax,-22
.Sh_execute_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Source-format LLM user history. Trailing/leading ASCII shell whitespace is
# trimmed; output is UTF-8 safe and capped at10,000 UTF16 code units like source.
.global ui_shell_history_message
ui_shell_history_message:
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
 mov r15,rcx
 mov [rsp],r8
 mov [rsp+8],r9
 mov qword ptr [rsp+16],0
 cmp r13,65535
 ja .Sh_message_bad
 cmp r15,65536
 ja .Sh_message_bad
 test r12,r12
 jz .Sh_message_bad
 test r14,r14
 jz .Sh_message_bad
 test r8,r8
 jz .Sh_message_bad
 lea rdi,[rip+.Sh_quote]
 mov rsi,r12
 mov rdx,r13
 mov ecx,393218
 call json_quote
 test rax,rax
 js .Sh_message_bad
 # Invalid UTF8 or NUL data is represented as binary, never injected as JSON.
 xor ecx,ecx
.Sh_binary_check:
 cmp rcx,r15
 jae .Sh_validate_output
 cmp byte ptr [r14+rcx],0
 je .Sh_binary_output
 inc rcx
 jmp .Sh_binary_check
.Sh_validate_output:
 lea rdi,[rip+.Sh_quote]
 mov rsi,r14
 mov rdx,r15
 mov ecx,393218
 call json_quote
 test rax,rax
 js .Sh_binary_output
.Sh_trim_left:
 test r15,r15
 jz .Sh_empty_output
 mov al,[r14]
 cmp al,32
 je .Sh_trim_left_byte
 cmp al,9
 jb .Sh_trim_right
 cmp al,13
 ja .Sh_trim_right
.Sh_trim_left_byte:
 inc r14
 dec r15
 jmp .Sh_trim_left
.Sh_trim_right:
 test r15,r15
 jz .Sh_empty_output
 mov al,[r14+r15-1]
 cmp al,32
 je .Sh_trim_right_byte
 cmp al,9
 jb .Sh_truncate_output
 cmp al,13
 ja .Sh_truncate_output
.Sh_trim_right_byte:
 dec r15
 jmp .Sh_trim_right
.Sh_empty_output:
 lea r14,[rip+.Sh_empty]
 mov r15d,28
 jmp .Sh_build_message
.Sh_binary_output:
 lea r14,[rip+.Sh_binary]
 mov r15d,53
 jmp .Sh_build_message
.Sh_truncate_output:
 xor ebx,ebx
 xor ecx,ecx
.Sh_units_loop:
 cmp rbx,r15
 jae .Sh_build_message
 movzx eax,byte ptr [r14+rbx]
 mov edx,1
 mov ebp,1
 cmp eax,128
 jb .Sh_units_ready
 mov edx,2
 cmp eax,224
 jb .Sh_units_ready
 inc edx
 cmp eax,240
 jb .Sh_units_ready
 inc edx
 inc ebp
.Sh_units_ready:
 add ecx,ebp
 cmp ecx,10000
 ja .Sh_truncate_here
 add rbx,rdx
 jmp .Sh_units_loop
.Sh_truncate_here:
 mov r15,rbx
 mov qword ptr [rsp+16],1
.Sh_build_message:
 mov rax,r13
 add rax,r15
 add rax,SH_BEFORE+SH_BETWEEN+SH_AFTER
 cmp qword ptr [rsp+16],0
 je .Sh_message_capacity
 add rax,SH_TRUNCATED
.Sh_message_capacity:
 cmp rax,[rsp+8]
 jae .Sh_message_full
 mov [rsp+24],rax
 mov rdi,[rsp]
 lea rsi,[rip+.Sh_before]
 mov ecx,SH_BEFORE
 rep movsb
 mov rsi,r12
 mov rcx,r13
 rep movsb
 lea rsi,[rip+.Sh_between]
 mov ecx,SH_BETWEEN
 rep movsb
 mov rsi,r14
 mov rcx,r15
 rep movsb
 cmp qword ptr [rsp+16],0
 je .Sh_message_after
 lea rsi,[rip+.Sh_truncated]
 mov ecx,SH_TRUNCATED
 rep movsb
.Sh_message_after:
 lea rsi,[rip+.Sh_after]
 mov ecx,SH_AFTER
 rep movsb
 mov byte ptr [rdi],0
 mov rax,[rsp+24]
 jmp .Sh_message_done
.Sh_message_full:
 mov rax,-28
 jmp .Sh_message_done
.Sh_message_bad:
 mov rax,-22
.Sh_message_done:
 add rsp,40
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.global ui_shell_history_add
ui_shell_history_add:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 test rdi,rdi
 jz .Sh_history_add_done
 test rsi,rsi
 jz .Sh_history_add_done
 cmp rsi,65535
 ja .Sh_history_add_done
 xor ecx,ecx
.Sh_history_nonempty:
 cmp rcx,r13
 jae .Sh_history_add_done
 mov al,[r12+rcx]
 inc rcx
 cmp al,32
 je .Sh_history_nonempty
 cmp al,9
 jb .Sh_history_nonempty_found
 cmp al,13
 jbe .Sh_history_nonempty
.Sh_history_nonempty_found:
 call ui_shell_history_reset_nav
 xor ebx,ebx
 lea r14,[rip+.Sh_horder]
.Sh_history_find:
 cmp rbx,[rip+.Sh_hcount]
 jae .Sh_history_new
 mov rbp,[r14+rbx*8]
 lea rax,[rip+.Sh_hlens]
 cmp r13,[rax+rbp*8]
 jne .Sh_history_find_next
 mov rsi,rbp
 shl rsi,16
 lea rax,[rip+.Sh_htext]
 add rsi,rax
 mov rdi,r12
 mov rcx,r13
 repe cmpsb
 je .Sh_history_reorder
.Sh_history_find_next:
 inc ebx
 jmp .Sh_history_find
.Sh_history_new:
 mov rbp,[rip+.Sh_hcount]
 cmp rbp,100
 jb .Sh_history_grow
 mov ebx,99
 mov rbp,[r14+rbx*8]
 jmp .Sh_history_store
.Sh_history_grow:
 mov rbx,rbp
 inc qword ptr [rip+.Sh_hcount]
.Sh_history_store:
 lea rax,[rip+.Sh_hlens]
 mov [rax+rbp*8],r13
 mov rdi,rbp
 shl rdi,16
 lea rax,[rip+.Sh_htext]
 add rdi,rax
 mov rsi,r12
 mov rcx,r13
 rep movsb
 mov byte ptr [rdi],0
.Sh_history_reorder:
 test rbx,rbx
 jz .Sh_history_at_front
 mov rax,[r14+rbx*8-8]
 mov [r14+rbx*8],rax
 dec ebx
 jmp .Sh_history_reorder
.Sh_history_at_front:
 mov [r14],rbp
 call ui_shell_history_save
.Sh_history_add_done:
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.global ui_shell_history_reset_nav
ui_shell_history_reset_nav:
 mov qword ptr [rip+.Sh_hpos],-1
 mov qword ptr [rip+.Sh_hinitialized],1
 ret
.global ui_shell_history_prev
ui_shell_history_prev:
 cmp qword ptr [rip+.Sh_hinitialized],0
 jne .Sh_prev_initialized
 call ui_shell_history_reset_nav
.Sh_prev_initialized:
 cmp qword ptr [rip+.Sh_hcount],0
 je .Sh_history_none
 mov rax,[rip+.Sh_hpos]
 inc rax
 cmp rax,[rip+.Sh_hcount]
 jb .Sh_history_select
 dec rax
 jmp .Sh_history_select
.global ui_shell_history_next
ui_shell_history_next:
 cmp qword ptr [rip+.Sh_hinitialized],0
 jne .Sh_next_initialized
 call ui_shell_history_reset_nav
.Sh_next_initialized:
 mov rax,[rip+.Sh_hpos]
 test rax,rax
 js .Sh_history_none
 dec rax
 js .Sh_history_empty
.Sh_history_select:
 mov [rip+.Sh_hpos],rax
 lea rdx,[rip+.Sh_horder]
 mov rax,[rdx+rax*8]
 lea rdx,[rip+.Sh_hlens]
 mov rdx,[rdx+rax*8]
 shl rax,16
 lea rcx,[rip+.Sh_htext]
 add rax,rcx
 ret
.Sh_history_empty:
 mov qword ptr [rip+.Sh_hpos],-1
 lea rax,[rip+.Sh_empty+28]
 xor edx,edx
 ret
.Sh_history_none:
 xor eax,eax
 xor edx,edx
 ret
.section .note.GNU-stack,"",@progbits
.text
.global ui_shell_history_clear
ui_shell_history_clear:
 mov qword ptr [rip+.Sh_hcount],0
 jmp ui_shell_history_reset_nav
# Private per-workspace MRU persistence. JSON order remains oldest-to-newest,
# matching original useShellHistory. Disabled config never creates/writes files.
.section .rodata
.Sh_phlocal: .asciz ".local"
.Sh_phstate: .asciz "state"
.Sh_phapp: .asciz "qwen-x86"
.Sh_phcomponents: .long .Sh_phlocal-.Sh_phcomponents,.Sh_phstate-.Sh_phcomponents,.Sh_phapp-.Sh_phcomponents
.Sh_phprefix: .ascii "shell-history-"
.Sh_phhex: .ascii "0123456789abcdef"
.section .bss
.balign 16
.Sh_penabled: .skip 8
.Sh_pconfigured: .skip 8
.Sh_ploading: .skip 8
.Sh_perror: .skip 8
.Sh_pdir: .skip 8
.Sh_pfd: .skip 8
.Sh_pcreated: .skip 8
.Sh_plen: .skip 8
.Sh_phome: .skip 4096
.Sh_pname: .skip 80
.Sh_ptemp: .skip 112
.Sh_prandom: .skip 16
.Sh_pstat: .skip 144
.Sh_pjson: .skip 1048577
.Sh_ptokens: .skip 8192*32
.Sh_pdecoded: .skip 65536
.text
.global ui_shell_history_config
# homeZ,cwdZ,allowSave; NULL disables persistence without changing memory MRU.
ui_shell_history_config:
 push rbx
 push r12
 push r13
 mov [rip+.Sh_penabled],rdx
 mov qword ptr [rip+.Sh_pconfigured],0
 mov qword ptr [rip+.Sh_perror],0
 test rdi,rdi
 jz .Sh_config_disabled
 test rsi,rsi
 jz .Sh_config_disabled
 cmp byte ptr [rdi],47
 jne .Sh_config_bad
 mov r12,rsi
 mov rsi,rdi
 lea rdi,[rip+.Sh_phome]
 xor ecx,ecx
.Sh_homecopy:
 cmp ecx,3500
 jae .Sh_config_bad
 lodsb
 stosb
 test al,al
 jz .Sh_hash_start
 inc ecx
 jmp .Sh_homecopy
.Sh_hash_start:
 movabs rbx,0xcbf29ce484222325
 movabs r13,0x100000001b3
 xor ecx,ecx
.Sh_hash_byte:
 cmp ecx,4096
 jae .Sh_config_bad
 movzx eax,byte ptr [r12+rcx]
 test al,al
 jz .Sh_hash_name
 xor rbx,rax
 imul rbx,r13
 inc ecx
 jmp .Sh_hash_byte
.Sh_hash_name:
 lea rdi,[rip+.Sh_pname]
 lea rsi,[rip+.Sh_phprefix]
 mov ecx,14
 rep movsb
 mov ecx,16
 lea rsi,[rip+.Sh_phhex]
.Sh_hash_hex:
 rol rbx,4
 mov rax,rbx
 and eax,15
 mov al,[rsi+rax]
 stosb
 loop .Sh_hash_hex
 mov dword ptr [rdi],0x6f736a2e
 mov word ptr [rdi+4],110
 mov qword ptr [rip+.Sh_pconfigured],1
 call ui_shell_history_clear
 call ui_shell_history_load
 jmp .Sh_config_return
.Sh_config_bad:
 mov rax,-22
 jmp .Sh_config_return
.Sh_config_disabled:
 xor eax,eax
.Sh_config_return:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_shell_history_last_error
ui_shell_history_last_error:
 mov rax,[rip+.Sh_perror]
 ret
# Open each private state directory without following symlinks. May create
# missing components only when allowSave was explicitly enabled by root.
.Sh_popen_dir:
 mov qword ptr [rip+.Sh_pdir],-1
 mov qword ptr [rip+.Sh_pfd],-1
 mov qword ptr [rip+.Sh_pcreated],0
 mov eax,2
 lea rdi,[rip+.Sh_phome]
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .Sh_popen_return
 mov [rip+.Sh_pdir],rax
 push rbx
 push r12
 sub rsp,8
 xor ebx,ebx
.Sh_popen_component:
 lea rax,[rip+.Sh_phcomponents]
 movsxd r12,dword ptr [rax+rbx*4]
 add r12,rax
.Sh_popen_again:
 mov eax,257
 mov rdi,[rip+.Sh_pdir]
 mov rsi,r12
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 jns .Sh_popen_success
 cmp rax,-2
 jne .Sh_popen_component_error
 cmp qword ptr [rip+.Sh_penabled],0
 je .Sh_popen_component_error
 mov eax,258
 mov rdi,[rip+.Sh_pdir]
 mov rsi,r12
 mov edx,0700
 syscall
 test rax,rax
 jns .Sh_popen_again
 cmp rax,-17
 je .Sh_popen_again
 jmp .Sh_popen_component_error
.Sh_popen_success:
 push rax
 mov eax,3
 mov rdi,[rip+.Sh_pdir]
 syscall
 pop rax
 mov [rip+.Sh_pdir],rax
 inc ebx
 cmp ebx,3
 jb .Sh_popen_component
 xor eax,eax
.Sh_popen_component_error:
 add rsp,8
 pop r12
 pop rbx
.Sh_popen_return:
 ret
.Sh_pclose:
 mov rdi,[rip+.Sh_pfd]
 test rdi,rdi
 js .Sh_pclose_dir
 mov eax,3
 syscall
 mov qword ptr [rip+.Sh_pfd],-1
.Sh_pclose_dir:
 mov rdi,[rip+.Sh_pdir]
 test rdi,rdi
 js .Sh_pclose_return
 mov eax,3
 syscall
 mov qword ptr [rip+.Sh_pdir],-1
.Sh_pclose_return:
 ret
.global ui_shell_history_load
ui_shell_history_load:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 cmp qword ptr [rip+.Sh_pconfigured],0
 je .Sh_load_return
 call .Sh_popen_dir
 test rax,rax
 js .Sh_load_open_error
 mov eax,257
 mov rdi,[rip+.Sh_pdir]
 lea rsi,[rip+.Sh_pname]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .Sh_load_open_error
 mov [rip+.Sh_pfd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.Sh_pstat]
 syscall
 test rax,rax
 js .Sh_load_error
 mov eax,[rip+.Sh_pstat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Sh_load_invalid
 mov eax,107
 syscall
 cmp eax,[rip+.Sh_pstat+28]
 jne .Sh_load_invalid
 cmp qword ptr [rip+.Sh_pstat+48],1048576
 ja .Sh_load_full
 xor r12d,r12d
.Sh_load_read:
 mov eax,0
 mov rdi,[rip+.Sh_pfd]
 lea rsi,[rip+.Sh_pjson]
 add rsi,r12
 mov edx,1048577
 sub rdx,r12
 jz .Sh_load_full
 syscall
 cmp rax,-4
 je .Sh_load_read
 test rax,rax
 js .Sh_load_error
 jz .Sh_load_parse
 add r12,rax
 jmp .Sh_load_read
.Sh_load_parse:
 cmp r12,1048576
 ja .Sh_load_full
 lea rdi,[rip+.Sh_pjson]
 mov rsi,r12
 lea rdx,[rip+.Sh_ptokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .Sh_load_invalid
 cmp qword ptr [rip+.Sh_ptokens],JT_ARRAY
 jne .Sh_load_invalid
 mov ebx,1
 xor r13d,r13d
.Sh_load_validate:
 cmp rbx,[rip+.Sh_ptokens+T_END]
 jae .Sh_load_valid
 lea r12,[rip+.Sh_ptokens]
 mov rax,rbx
 shl rax,5
 add r12,rax
 cmp qword ptr [r12+T_TYPE],JT_STRING
 jne .Sh_load_invalid
 call .Sh_load_decode
 test rax,rax
 js .Sh_load_invalid
 cmp rax,65535
 ja .Sh_load_full
 mov rbx,[r12+T_END]
 inc r13
 jmp .Sh_load_validate
.Sh_load_valid:
 call ui_shell_history_clear
 mov qword ptr [rip+.Sh_ploading],1
 mov ebx,1
.Sh_load_commit:
 cmp rbx,[rip+.Sh_ptokens+T_END]
 jae .Sh_load_committed
 lea r12,[rip+.Sh_ptokens]
 mov rax,rbx
 shl rax,5
 add r12,rax
 call .Sh_load_decode
 mov rsi,rax
 lea rdi,[rip+.Sh_pdecoded]
 call ui_shell_history_add
 mov rbx,[r12+T_END]
 jmp .Sh_load_commit
.Sh_load_committed:
 mov qword ptr [rip+.Sh_ploading],0
 mov r15,[rip+.Sh_hcount]
 jmp .Sh_load_cleanup
.Sh_load_decode:
 lea rdi,[rip+.Sh_pdecoded]
 lea rsi,[rip+.Sh_pjson]
 add rsi,[r12+T_START]
 mov rdx,[r12+T_LEN]
 mov ecx,65536
 jmp json_decode
.Sh_load_open_error:
 cmp rax,-2
 je .Sh_load_cleanup
.Sh_load_error:
 mov r15,rax
 jmp .Sh_load_cleanup
.Sh_load_invalid:
 mov r15,-22
 jmp .Sh_load_cleanup
.Sh_load_full:
 mov r15,-28
.Sh_load_cleanup:
 call .Sh_pclose
 xor eax,eax
 test r15,r15
 cmovs rax,r15
 mov [rip+.Sh_perror],rax
.Sh_load_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.global ui_shell_history_save
ui_shell_history_save:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 cmp qword ptr [rip+.Sh_penabled],0
 je .Sh_save_return
 cmp qword ptr [rip+.Sh_pconfigured],0
 je .Sh_save_return
 cmp qword ptr [rip+.Sh_ploading],0
 jne .Sh_save_return
 # Serialize complete JSON before touching the previous history file.
 lea r14,[rip+.Sh_pjson]
 mov byte ptr [r14],91
 mov r12d,1
 mov rbx,[rip+.Sh_hcount]
.Sh_save_entry:
 test rbx,rbx
 jz .Sh_save_json_done
 dec rbx
 mov rax,[rip+.Sh_hcount]
 dec rax
 cmp rbx,rax
 je .Sh_save_no_comma
 mov byte ptr [r14+r12],44
 inc r12
.Sh_save_no_comma:
 lea rax,[rip+.Sh_horder]
 mov rbp,[rax+rbx*8]
 lea rdi,[r14+r12]
 lea rax,[rip+.Sh_hlens]
 mov rdx,[rax+rbp*8]
 mov rsi,rbp
 shl rsi,16
 lea rax,[rip+.Sh_htext]
 add rsi,rax
 mov ecx,1048574
 sub rcx,r12
 jbe .Sh_save_full
 call json_quote
 test rax,rax
 js .Sh_save_full
 add r12,rax
 jmp .Sh_save_entry
.Sh_save_json_done:
 mov word ptr [r14+r12],0x0a5d
 add r12,2
 mov [rip+.Sh_plen],r12
 call .Sh_popen_dir
 test rax,rax
 js .Sh_save_error
 # Random O_EXCL temporary file inside the already-bound private directory.
.Sh_save_random:
 mov eax,318
 lea rdi,[rip+.Sh_prandom]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,-4
 je .Sh_save_random
 cmp rax,16
 jne .Sh_save_io
 lea rdi,[rip+.Sh_ptemp]
 lea rsi,[rip+.Sh_pname]
 mov ecx,36
 rep movsb
 mov dword ptr [rdi-1],0x706d742e
 add rdi,3
 mov byte ptr [rdi],45
 inc rdi
 lea rsi,[rip+.Sh_prandom]
 lea r8,[rip+.Sh_phhex]
 mov ecx,16
.Sh_save_hex:
 movzx eax,byte ptr [rsi]
 inc rsi
 mov edx,eax
 shr eax,4
 and edx,15
 mov al,[r8+rax]
 stosb
 mov al,[r8+rdx]
 stosb
 loop .Sh_save_hex
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,[rip+.Sh_pdir]
 lea rsi,[rip+.Sh_ptemp]
 mov edx,0xa00c1
 mov r10d,0600
 syscall
 test rax,rax
 js .Sh_save_error
 mov [rip+.Sh_pfd],rax
 mov qword ptr [rip+.Sh_pcreated],1
 mov rdi,rax
 mov eax,91
 mov esi,0600
 syscall
 test rax,rax
 js .Sh_save_error
 xor ebx,ebx
.Sh_save_write:
 cmp rbx,[rip+.Sh_plen]
 jae .Sh_save_fsync
 mov eax,1
 mov rdi,[rip+.Sh_pfd]
 lea rsi,[rip+.Sh_pjson]
 add rsi,rbx
 mov rdx,[rip+.Sh_plen]
 sub rdx,rbx
 syscall
 cmp rax,-4
 je .Sh_save_write
 test rax,rax
 jle .Sh_save_io
 add rbx,rax
 jmp .Sh_save_write
.Sh_save_fsync:
 mov eax,74
 mov rdi,[rip+.Sh_pfd]
 syscall
 cmp rax,-4
 je .Sh_save_fsync
 test rax,rax
 js .Sh_save_error
 mov eax,3
 mov rdi,[rip+.Sh_pfd]
 syscall
 mov qword ptr [rip+.Sh_pfd],-1
 mov eax,264
 mov rdi,[rip+.Sh_pdir]
 lea rsi,[rip+.Sh_ptemp]
 mov rdx,rdi
 lea r10,[rip+.Sh_pname]
 syscall
 test rax,rax
 js .Sh_save_error
 mov qword ptr [rip+.Sh_pcreated],0
 jmp .Sh_save_cleanup
.Sh_save_full:
 mov r15,-28
 jmp .Sh_save_return
.Sh_save_io:
 mov rax,-5
.Sh_save_error:
 mov r15,rax
.Sh_save_cleanup:
 cmp qword ptr [rip+.Sh_pcreated],0
 je .Sh_save_close
 mov eax,263
 mov rdi,[rip+.Sh_pdir]
 lea rsi,[rip+.Sh_ptemp]
 xor edx,edx
 syscall
.Sh_save_close:
 call .Sh_pclose
 mov [rip+.Sh_perror],r15
.Sh_save_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.text
.global ui_shell_parse_history
# raw,len,out32 ->1 exact wrapper,0 ordinary text. Borrowed spans only.
# Wrapper format is unescaped; the first exact delimiter separates command.
# Result may contain arbitrary fences/delimiters and ends at the final suffix.
ui_shell_parse_history:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 xor ebx,ebx
 test rdi,rdi
 jz .Sh_parse_done
 test rdx,rdx
 jz .Sh_parse_done
 cmp rsi,SH_BEFORE+SH_BETWEEN+SH_AFTER+2
 jb .Sh_parse_done
 cmp rsi,131072
 ja .Sh_parse_done
 xor edi,edi
 mov rsi,r12
 mov rdx,r13
 mov ecx,1048576
 call json_quote
 test rax,rax
 js .Sh_parse_done
 mov rdi,r12
 lea rsi,[rip+.Sh_before]
 mov ecx,SH_BEFORE
 repe cmpsb
 jne .Sh_parse_done
 cmp dword ptr [r12+r13-SH_AFTER],0x6060600a
 jne .Sh_parse_done
 mov r15d,SH_BEFORE+1
.Sh_parse_scan:
 mov rax,r15
 add rax,SH_BETWEEN+SH_AFTER+1
 cmp rax,r13
 ja .Sh_parse_done
 lea rdi,[r12+r15]
 lea rsi,[rip+.Sh_between]
 mov ecx,SH_BETWEEN
 repe cmpsb
 je .Sh_parse_match
 inc r15
 jmp .Sh_parse_scan
.Sh_parse_match:
 lea rax,[r12+SH_BEFORE]
 mov [r14],rax
 mov rax,r15
 sub rax,SH_BEFORE
 mov [r14+8],rax
 lea rax,[r12+r15+SH_BETWEEN]
 mov [r14+16],rax
 mov rax,r13
 sub rax,r15
 sub rax,SH_BETWEEN+SH_AFTER
 mov [r14+24],rax
 mov ebx,1
.Sh_parse_done:
 mov eax,ebx
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
