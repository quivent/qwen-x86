# Native persisted exact shell-command permissions. Explicit rule adds only.
# Separate user/project stores; no guessed shell-prefix grants or AST claims.
.include "abi.inc"

.section .bss
.balign 16
.PrU_hcount: .skip 8
.PrU_hpos: .skip 8
.PrU_hinitialized: .skip 8
.PrU_hlens: .skip 800
.PrU_horder: .skip 800
.PrU_htext: .skip 6553600
.section .text
.local .PrU_add
.PrU_add:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 test rdi,rdi
 jz .PrU_history_add_done
 test rsi,rsi
 jz .PrU_history_add_done
 cmp rsi,65535
 ja .PrU_history_add_done
 xor ecx,ecx
.PrU_history_nonempty:
 cmp rcx,r13
 jae .PrU_history_add_done
 mov al,[r12+rcx]
 inc rcx
 cmp al,32
 je .PrU_history_nonempty
 cmp al,9
 jb .PrU_history_nonempty_found
 cmp al,13
 jbe .PrU_history_nonempty
.PrU_history_nonempty_found:
 call .PrU_reset_nav
 xor ebx,ebx
 lea r14,[rip+.PrU_horder]
.PrU_history_find:
 cmp rbx,[rip+.PrU_hcount]
 jae .PrU_history_new
 mov rbp,[r14+rbx*8]
 lea rax,[rip+.PrU_hlens]
 cmp r13,[rax+rbp*8]
 jne .PrU_history_find_next
 mov rsi,rbp
 shl rsi,16
 lea rax,[rip+.PrU_htext]
 add rsi,rax
 mov rdi,r12
 mov rcx,r13
 repe cmpsb
 je .PrU_history_reorder
.PrU_history_find_next:
 inc ebx
 jmp .PrU_history_find
.PrU_history_new:
 mov rbp,[rip+.PrU_hcount]
 cmp rbp,100
 jb .PrU_history_grow
 mov ebx,99
 mov rbp,[r14+rbx*8]
 jmp .PrU_history_store
.PrU_history_grow:
 mov rbx,rbp
 xor ebp,ebp
.PrU_free_slot:
 xor ecx,ecx
.PrU_slot_used:
 cmp rcx,[rip+.PrU_hcount]
 jae .PrU_slot_free
 cmp rbp,[r14+rcx*8]
 je .PrU_slot_advance
 inc rcx
 jmp .PrU_slot_used
.PrU_slot_advance:
 inc rbp
 jmp .PrU_free_slot
.PrU_slot_free:
 inc qword ptr [rip+.PrU_hcount]
.PrU_history_store:
 lea rax,[rip+.PrU_hlens]
 mov [rax+rbp*8],r13
 mov rdi,rbp
 shl rdi,16
 lea rax,[rip+.PrU_htext]
 add rdi,rax
 mov rsi,r12
 mov rcx,r13
 rep movsb
 mov byte ptr [rdi],0
.PrU_history_reorder:
 test rbx,rbx
 jz .PrU_history_at_front
 mov rax,[r14+rbx*8-8]
 mov [r14+rbx*8],rax
 dec ebx
 jmp .PrU_history_reorder
.PrU_history_at_front:
 mov [r14],rbp
 call .PrU_save
.PrU_history_add_done:
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.local .PrU_reset_nav
.PrU_reset_nav:
 mov qword ptr [rip+.PrU_hpos],-1
 mov qword ptr [rip+.PrU_hinitialized],1
 ret
.local .PrU_prev
.PrU_prev:
 cmp qword ptr [rip+.PrU_hinitialized],0
 jne .PrU_prev_initialized
 call .PrU_reset_nav
.PrU_prev_initialized:
 cmp qword ptr [rip+.PrU_hcount],0
 je .PrU_history_none
 mov rax,[rip+.PrU_hpos]
 inc rax
 cmp rax,[rip+.PrU_hcount]
 jb .PrU_history_select
 dec rax
 jmp .PrU_history_select
.local .PrU_next
.PrU_next:
 cmp qword ptr [rip+.PrU_hinitialized],0
 jne .PrU_next_initialized
 call .PrU_reset_nav
.PrU_next_initialized:
 mov rax,[rip+.PrU_hpos]
 test rax,rax
 js .PrU_history_none
 dec rax
 js .PrU_history_empty
.PrU_history_select:
 mov [rip+.PrU_hpos],rax
 lea rdx,[rip+.PrU_horder]
 mov rax,[rdx+rax*8]
 lea rdx,[rip+.PrU_hlens]
 mov rdx,[rdx+rax*8]
 shl rax,16
 lea rcx,[rip+.PrU_htext]
 add rax,rcx
 ret
.PrU_history_empty:
 mov qword ptr [rip+.PrU_hpos],-1
 lea rax,[rip+.PrU_empty+28]
 xor edx,edx
 ret
.PrU_history_none:
 xor eax,eax
 xor edx,edx
 ret
.section .note.GNU-stack,"",@progbits
.text
.local .PrU_clear
.PrU_clear:
 mov qword ptr [rip+.PrU_hcount],0
 jmp .PrU_reset_nav
# Private per-workspace MRU persistence. JSON order remains oldest-to-newest,
# matching original useShellHistory. Disabled config never creates/writes files.
.section .rodata
.PrU_phlocal: .asciz ".local"
.PrU_phstate: .asciz "state"
.PrU_phapp: .asciz "qwen-x86"
.PrU_phcomponents: .long .PrU_phlocal-.PrU_phcomponents,.PrU_phstate-.PrU_phcomponents,.PrU_phapp-.PrU_phcomponents
.PrU_phprefix: .ascii "shell-allow---"
.PrU_phhex: .ascii "0123456789abcdef"
.section .bss
.balign 16
.PrU_penabled: .skip 8
.PrU_pconfigured: .skip 8
.PrU_ploading: .skip 8
.PrU_perror: .skip 8
.PrU_pdir: .skip 8
.PrU_pfd: .skip 8
.PrU_pcreated: .skip 8
.PrU_plen: .skip 8
.PrU_phome: .skip 4096
.PrU_pname: .skip 80
.PrU_ptemp: .skip 112
.PrU_prandom: .skip 16
.PrU_pstat: .skip 144
.PrU_pjson: .skip 1048577
.PrU_ptokens: .skip 8192*32
.PrU_pdecoded: .skip 65536
.text
.local .PrU_config
# homeZ,cwdZ,allowSave; NULL disables persistence without changing memory MRU.
.PrU_config:
 push rbx
 push r12
 push r13
 mov [rip+.PrU_penabled],rdx
 mov qword ptr [rip+.PrU_pconfigured],0
 mov qword ptr [rip+.PrU_perror],0
 test rdi,rdi
 jz .PrU_config_disabled
 test rsi,rsi
 jz .PrU_config_disabled
 cmp byte ptr [rdi],47
 jne .PrU_config_bad
 mov r12,rsi
 mov rsi,rdi
 lea rdi,[rip+.PrU_phome]
 xor ecx,ecx
.PrU_homecopy:
 cmp ecx,3500
 jae .PrU_config_bad
 lodsb
 stosb
 test al,al
 jz .PrU_hash_start
 inc ecx
 jmp .PrU_homecopy
.PrU_hash_start:
 movabs rbx,0xcbf29ce484222325
 movabs r13,0x100000001b3
 xor ecx,ecx
.PrU_hash_byte:
 cmp ecx,4096
 jae .PrU_config_bad
 movzx eax,byte ptr [r12+rcx]
 test al,al
 jz .PrU_hash_name
 xor rbx,rax
 imul rbx,r13
 inc ecx
 jmp .PrU_hash_byte
.PrU_hash_name:
 lea rdi,[rip+.PrU_pname]
 lea rsi,[rip+.PrU_phprefix]
 mov ecx,14
 rep movsb
 mov ecx,16
 lea rsi,[rip+.PrU_phhex]
.PrU_hash_hex:
 rol rbx,4
 mov rax,rbx
 and eax,15
 mov al,[rsi+rax]
 stosb
 loop .PrU_hash_hex
 mov dword ptr [rdi],0x6f736a2e
 mov word ptr [rdi+4],110
 mov qword ptr [rip+.PrU_pconfigured],1
 call .PrU_clear
 call .PrU_load
 jmp .PrU_config_return
.PrU_config_bad:
 mov rax,-22
 jmp .PrU_config_return
.PrU_config_disabled:
 xor eax,eax
.PrU_config_return:
 pop r13
 pop r12
 pop rbx
 ret
.local .PrU_last_error
.PrU_last_error:
 mov rax,[rip+.PrU_perror]
 ret
# Open each private state directory without following symlinks. May create
# missing components only when allowSave was explicitly enabled by root.
.PrU_popen_dir:
 mov qword ptr [rip+.PrU_pdir],-1
 mov qword ptr [rip+.PrU_pfd],-1
 mov qword ptr [rip+.PrU_pcreated],0
 mov eax,2
 lea rdi,[rip+.PrU_phome]
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .PrU_popen_return
 mov [rip+.PrU_pdir],rax
 push rbx
 push r12
 sub rsp,8
 xor ebx,ebx
.PrU_popen_component:
 lea rax,[rip+.PrU_phcomponents]
 movsxd r12,dword ptr [rax+rbx*4]
 add r12,rax
.PrU_popen_again:
 mov eax,257
 mov rdi,[rip+.PrU_pdir]
 mov rsi,r12
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 jns .PrU_popen_success
 cmp rax,-2
 jne .PrU_popen_component_error
 cmp qword ptr [rip+.PrU_penabled],0
 je .PrU_popen_component_error
 mov eax,258
 mov rdi,[rip+.PrU_pdir]
 mov rsi,r12
 mov edx,0700
 syscall
 test rax,rax
 jns .PrU_popen_again
 cmp rax,-17
 je .PrU_popen_again
 jmp .PrU_popen_component_error
.PrU_popen_success:
 push rax
 mov eax,3
 mov rdi,[rip+.PrU_pdir]
 syscall
 pop rax
 mov [rip+.PrU_pdir],rax
 inc ebx
 cmp ebx,3
 jb .PrU_popen_component
 xor eax,eax
.PrU_popen_component_error:
 add rsp,8
 pop r12
 pop rbx
.PrU_popen_return:
 ret
.PrU_pclose:
 mov rdi,[rip+.PrU_pfd]
 test rdi,rdi
 js .PrU_pclose_dir
 mov eax,3
 syscall
 mov qword ptr [rip+.PrU_pfd],-1
.PrU_pclose_dir:
 mov rdi,[rip+.PrU_pdir]
 test rdi,rdi
 js .PrU_pclose_return
 mov eax,3
 syscall
 mov qword ptr [rip+.PrU_pdir],-1
.PrU_pclose_return:
 ret
.local .PrU_load
.PrU_load:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 cmp qword ptr [rip+.PrU_pconfigured],0
 je .PrU_load_return
 call .PrU_popen_dir
 test rax,rax
 js .PrU_load_open_error
 mov eax,257
 mov rdi,[rip+.PrU_pdir]
 lea rsi,[rip+.PrU_pname]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .PrU_load_open_error
 mov [rip+.PrU_pfd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.PrU_pstat]
 syscall
 test rax,rax
 js .PrU_load_error
 mov eax,[rip+.PrU_pstat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .PrU_load_invalid
 mov eax,107
 syscall
 cmp eax,[rip+.PrU_pstat+28]
 jne .PrU_load_invalid
 cmp qword ptr [rip+.PrU_pstat+48],1048576
 ja .PrU_load_full
 xor r12d,r12d
.PrU_load_read:
 mov eax,0
 mov rdi,[rip+.PrU_pfd]
 lea rsi,[rip+.PrU_pjson]
 add rsi,r12
 mov edx,1048577
 sub rdx,r12
 jz .PrU_load_full
 syscall
 cmp rax,-4
 je .PrU_load_read
 test rax,rax
 js .PrU_load_error
 jz .PrU_load_parse
 add r12,rax
 jmp .PrU_load_read
.PrU_load_parse:
 cmp r12,1048576
 ja .PrU_load_full
 lea rdi,[rip+.PrU_pjson]
 mov rsi,r12
 lea rdx,[rip+.PrU_ptokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .PrU_load_invalid
 cmp qword ptr [rip+.PrU_ptokens],JT_ARRAY
 jne .PrU_load_invalid
 mov ebx,1
 xor r13d,r13d
.PrU_load_validate:
 cmp rbx,[rip+.PrU_ptokens+T_END]
 jae .PrU_load_valid
 lea r12,[rip+.PrU_ptokens]
 mov rax,rbx
 shl rax,5
 add r12,rax
 cmp qword ptr [r12+T_TYPE],JT_STRING
 jne .PrU_load_invalid
 call .PrU_load_decode
 test rax,rax
 js .PrU_load_invalid
 cmp rax,65535
 ja .PrU_load_full
 mov rbx,[r12+T_END]
 inc r13
 jmp .PrU_load_validate
.PrU_load_valid:
 call .PrU_clear
 mov qword ptr [rip+.PrU_ploading],1
 mov ebx,1
.PrU_load_commit:
 cmp rbx,[rip+.PrU_ptokens+T_END]
 jae .PrU_load_committed
 lea r12,[rip+.PrU_ptokens]
 mov rax,rbx
 shl rax,5
 add r12,rax
 call .PrU_load_decode
 mov rsi,rax
 lea rdi,[rip+.PrU_pdecoded]
 call .PrU_add
 mov rbx,[r12+T_END]
 jmp .PrU_load_commit
.PrU_load_committed:
 mov qword ptr [rip+.PrU_ploading],0
 mov r15,[rip+.PrU_hcount]
 jmp .PrU_load_cleanup
.PrU_load_decode:
 lea rdi,[rip+.PrU_pdecoded]
 lea rsi,[rip+.PrU_pjson]
 add rsi,[r12+T_START]
 mov rdx,[r12+T_LEN]
 mov ecx,65536
 jmp json_decode
.PrU_load_open_error:
 cmp rax,-2
 je .PrU_load_cleanup
.PrU_load_error:
 mov r15,rax
 jmp .PrU_load_cleanup
.PrU_load_invalid:
 mov r15,-22
 jmp .PrU_load_cleanup
.PrU_load_full:
 mov r15,-28
.PrU_load_cleanup:
 call .PrU_pclose
 xor eax,eax
 test r15,r15
 cmovs rax,r15
 mov [rip+.PrU_perror],rax
.PrU_load_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.local .PrU_save
.PrU_save:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 cmp qword ptr [rip+.PrU_penabled],0
 je .PrU_save_return
 cmp qword ptr [rip+.PrU_pconfigured],0
 je .PrU_save_return
 cmp qword ptr [rip+.PrU_ploading],0
 jne .PrU_save_return
 # Serialize complete JSON before touching the previous history file.
 lea r14,[rip+.PrU_pjson]
 mov byte ptr [r14],91
 mov r12d,1
 mov rbx,[rip+.PrU_hcount]
.PrU_save_entry:
 test rbx,rbx
 jz .PrU_save_json_done
 dec rbx
 mov rax,[rip+.PrU_hcount]
 dec rax
 cmp rbx,rax
 je .PrU_save_no_comma
 mov byte ptr [r14+r12],44
 inc r12
.PrU_save_no_comma:
 lea rax,[rip+.PrU_horder]
 mov rbp,[rax+rbx*8]
 lea rdi,[r14+r12]
 lea rax,[rip+.PrU_hlens]
 mov rdx,[rax+rbp*8]
 mov rsi,rbp
 shl rsi,16
 lea rax,[rip+.PrU_htext]
 add rsi,rax
 mov ecx,1048574
 sub rcx,r12
 jbe .PrU_save_full
 call json_quote
 test rax,rax
 js .PrU_save_full
 add r12,rax
 jmp .PrU_save_entry
.PrU_save_json_done:
 mov word ptr [r14+r12],0x0a5d
 add r12,2
 mov [rip+.PrU_plen],r12
 call .PrU_popen_dir
 test rax,rax
 js .PrU_save_error
 # Random O_EXCL temporary file inside the already-bound private directory.
.PrU_save_random:
 mov eax,318
 lea rdi,[rip+.PrU_prandom]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,-4
 je .PrU_save_random
 cmp rax,16
 jne .PrU_save_io
 lea rdi,[rip+.PrU_ptemp]
 lea rsi,[rip+.PrU_pname]
 mov ecx,36
 rep movsb
 mov dword ptr [rdi-1],0x706d742e
 add rdi,3
 mov byte ptr [rdi],45
 inc rdi
 lea rsi,[rip+.PrU_prandom]
 lea r8,[rip+.PrU_phhex]
 mov ecx,16
.PrU_save_hex:
 movzx eax,byte ptr [rsi]
 inc rsi
 mov edx,eax
 shr eax,4
 and edx,15
 mov al,[r8+rax]
 stosb
 mov al,[r8+rdx]
 stosb
 loop .PrU_save_hex
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,[rip+.PrU_pdir]
 lea rsi,[rip+.PrU_ptemp]
 mov edx,0xa00c1
 mov r10d,0600
 syscall
 test rax,rax
 js .PrU_save_error
 mov [rip+.PrU_pfd],rax
 mov qword ptr [rip+.PrU_pcreated],1
 mov rdi,rax
 mov eax,91
 mov esi,0600
 syscall
 test rax,rax
 js .PrU_save_error
 xor ebx,ebx
.PrU_save_write:
 cmp rbx,[rip+.PrU_plen]
 jae .PrU_save_fsync
 mov eax,1
 mov rdi,[rip+.PrU_pfd]
 lea rsi,[rip+.PrU_pjson]
 add rsi,rbx
 mov rdx,[rip+.PrU_plen]
 sub rdx,rbx
 syscall
 cmp rax,-4
 je .PrU_save_write
 test rax,rax
 jle .PrU_save_io
 add rbx,rax
 jmp .PrU_save_write
.PrU_save_fsync:
 mov eax,74
 mov rdi,[rip+.PrU_pfd]
 syscall
 cmp rax,-4
 je .PrU_save_fsync
 test rax,rax
 js .PrU_save_error
 mov eax,3
 mov rdi,[rip+.PrU_pfd]
 syscall
 mov qword ptr [rip+.PrU_pfd],-1
 mov eax,264
 mov rdi,[rip+.PrU_pdir]
 lea rsi,[rip+.PrU_ptemp]
 mov rdx,rdi
 lea r10,[rip+.PrU_pname]
 syscall
 test rax,rax
 js .PrU_save_error
 mov qword ptr [rip+.PrU_pcreated],0
 jmp .PrU_save_cleanup
.PrU_save_full:
 mov r15,-28
 jmp .PrU_save_return
.PrU_save_io:
 mov rax,-5
.PrU_save_error:
 mov r15,rax
.PrU_save_cleanup:
 cmp qword ptr [rip+.PrU_pcreated],0
 je .PrU_save_close
 mov eax,263
 mov rdi,[rip+.PrU_pdir]
 lea rsi,[rip+.PrU_ptemp]
 xor edx,edx
 syscall
.PrU_save_close:
 call .PrU_pclose
 mov [rip+.PrU_perror],r15
.PrU_save_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

.section .bss
.balign 16
.PrW_hcount: .skip 8
.PrW_hpos: .skip 8
.PrW_hinitialized: .skip 8
.PrW_hlens: .skip 800
.PrW_horder: .skip 800
.PrW_htext: .skip 6553600
.section .text
.local .PrW_add
.PrW_add:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 test rdi,rdi
 jz .PrW_history_add_done
 test rsi,rsi
 jz .PrW_history_add_done
 cmp rsi,65535
 ja .PrW_history_add_done
 xor ecx,ecx
.PrW_history_nonempty:
 cmp rcx,r13
 jae .PrW_history_add_done
 mov al,[r12+rcx]
 inc rcx
 cmp al,32
 je .PrW_history_nonempty
 cmp al,9
 jb .PrW_history_nonempty_found
 cmp al,13
 jbe .PrW_history_nonempty
.PrW_history_nonempty_found:
 call .PrW_reset_nav
 xor ebx,ebx
 lea r14,[rip+.PrW_horder]
.PrW_history_find:
 cmp rbx,[rip+.PrW_hcount]
 jae .PrW_history_new
 mov rbp,[r14+rbx*8]
 lea rax,[rip+.PrW_hlens]
 cmp r13,[rax+rbp*8]
 jne .PrW_history_find_next
 mov rsi,rbp
 shl rsi,16
 lea rax,[rip+.PrW_htext]
 add rsi,rax
 mov rdi,r12
 mov rcx,r13
 repe cmpsb
 je .PrW_history_reorder
.PrW_history_find_next:
 inc ebx
 jmp .PrW_history_find
.PrW_history_new:
 mov rbp,[rip+.PrW_hcount]
 cmp rbp,100
 jb .PrW_history_grow
 mov ebx,99
 mov rbp,[r14+rbx*8]
 jmp .PrW_history_store
.PrW_history_grow:
 mov rbx,rbp
 xor ebp,ebp
.PrW_free_slot:
 xor ecx,ecx
.PrW_slot_used:
 cmp rcx,[rip+.PrW_hcount]
 jae .PrW_slot_free
 cmp rbp,[r14+rcx*8]
 je .PrW_slot_advance
 inc rcx
 jmp .PrW_slot_used
.PrW_slot_advance:
 inc rbp
 jmp .PrW_free_slot
.PrW_slot_free:
 inc qword ptr [rip+.PrW_hcount]
.PrW_history_store:
 lea rax,[rip+.PrW_hlens]
 mov [rax+rbp*8],r13
 mov rdi,rbp
 shl rdi,16
 lea rax,[rip+.PrW_htext]
 add rdi,rax
 mov rsi,r12
 mov rcx,r13
 rep movsb
 mov byte ptr [rdi],0
.PrW_history_reorder:
 test rbx,rbx
 jz .PrW_history_at_front
 mov rax,[r14+rbx*8-8]
 mov [r14+rbx*8],rax
 dec ebx
 jmp .PrW_history_reorder
.PrW_history_at_front:
 mov [r14],rbp
 call .PrW_save
.PrW_history_add_done:
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.local .PrW_reset_nav
.PrW_reset_nav:
 mov qword ptr [rip+.PrW_hpos],-1
 mov qword ptr [rip+.PrW_hinitialized],1
 ret
.local .PrW_prev
.PrW_prev:
 cmp qword ptr [rip+.PrW_hinitialized],0
 jne .PrW_prev_initialized
 call .PrW_reset_nav
.PrW_prev_initialized:
 cmp qword ptr [rip+.PrW_hcount],0
 je .PrW_history_none
 mov rax,[rip+.PrW_hpos]
 inc rax
 cmp rax,[rip+.PrW_hcount]
 jb .PrW_history_select
 dec rax
 jmp .PrW_history_select
.local .PrW_next
.PrW_next:
 cmp qword ptr [rip+.PrW_hinitialized],0
 jne .PrW_next_initialized
 call .PrW_reset_nav
.PrW_next_initialized:
 mov rax,[rip+.PrW_hpos]
 test rax,rax
 js .PrW_history_none
 dec rax
 js .PrW_history_empty
.PrW_history_select:
 mov [rip+.PrW_hpos],rax
 lea rdx,[rip+.PrW_horder]
 mov rax,[rdx+rax*8]
 lea rdx,[rip+.PrW_hlens]
 mov rdx,[rdx+rax*8]
 shl rax,16
 lea rcx,[rip+.PrW_htext]
 add rax,rcx
 ret
.PrW_history_empty:
 mov qword ptr [rip+.PrW_hpos],-1
 lea rax,[rip+.PrW_empty+28]
 xor edx,edx
 ret
.PrW_history_none:
 xor eax,eax
 xor edx,edx
 ret
.section .note.GNU-stack,"",@progbits
.text
.local .PrW_clear
.PrW_clear:
 mov qword ptr [rip+.PrW_hcount],0
 jmp .PrW_reset_nav
# Private per-workspace MRU persistence. JSON order remains oldest-to-newest,
# matching original useShellHistory. Disabled config never creates/writes files.
.section .rodata
.PrW_phlocal: .asciz ".local"
.PrW_phstate: .asciz "state"
.PrW_phapp: .asciz "qwen-x86"
.PrW_phcomponents: .long .PrW_phlocal-.PrW_phcomponents,.PrW_phstate-.PrW_phcomponents,.PrW_phapp-.PrW_phcomponents
.PrW_phprefix: .ascii "shell-allow---"
.PrW_phhex: .ascii "0123456789abcdef"
.section .bss
.balign 16
.PrW_penabled: .skip 8
.PrW_pconfigured: .skip 8
.PrW_ploading: .skip 8
.PrW_perror: .skip 8
.PrW_pdir: .skip 8
.PrW_pfd: .skip 8
.PrW_pcreated: .skip 8
.PrW_plen: .skip 8
.PrW_phome: .skip 4096
.PrW_pname: .skip 80
.PrW_ptemp: .skip 112
.PrW_prandom: .skip 16
.PrW_pstat: .skip 144
.PrW_pjson: .skip 1048577
.PrW_ptokens: .skip 8192*32
.PrW_pdecoded: .skip 65536
.text
.local .PrW_config
# homeZ,cwdZ,allowSave; NULL disables persistence without changing memory MRU.
.PrW_config:
 push rbx
 push r12
 push r13
 mov [rip+.PrW_penabled],rdx
 mov qword ptr [rip+.PrW_pconfigured],0
 mov qword ptr [rip+.PrW_perror],0
 test rdi,rdi
 jz .PrW_config_disabled
 test rsi,rsi
 jz .PrW_config_disabled
 cmp byte ptr [rdi],47
 jne .PrW_config_bad
 mov r12,rsi
 mov rsi,rdi
 lea rdi,[rip+.PrW_phome]
 xor ecx,ecx
.PrW_homecopy:
 cmp ecx,3500
 jae .PrW_config_bad
 lodsb
 stosb
 test al,al
 jz .PrW_hash_start
 inc ecx
 jmp .PrW_homecopy
.PrW_hash_start:
 movabs rbx,0xcbf29ce484222325
 movabs r13,0x100000001b3
 xor ecx,ecx
.PrW_hash_byte:
 cmp ecx,4096
 jae .PrW_config_bad
 movzx eax,byte ptr [r12+rcx]
 test al,al
 jz .PrW_hash_name
 xor rbx,rax
 imul rbx,r13
 inc ecx
 jmp .PrW_hash_byte
.PrW_hash_name:
 lea rdi,[rip+.PrW_pname]
 lea rsi,[rip+.PrW_phprefix]
 mov ecx,14
 rep movsb
 mov ecx,16
 lea rsi,[rip+.PrW_phhex]
.PrW_hash_hex:
 rol rbx,4
 mov rax,rbx
 and eax,15
 mov al,[rsi+rax]
 stosb
 loop .PrW_hash_hex
 mov dword ptr [rdi],0x6f736a2e
 mov word ptr [rdi+4],110
 mov qword ptr [rip+.PrW_pconfigured],1
 call .PrW_clear
 call .PrW_load
 jmp .PrW_config_return
.PrW_config_bad:
 mov rax,-22
 jmp .PrW_config_return
.PrW_config_disabled:
 xor eax,eax
.PrW_config_return:
 pop r13
 pop r12
 pop rbx
 ret
.local .PrW_last_error
.PrW_last_error:
 mov rax,[rip+.PrW_perror]
 ret
# Open each private state directory without following symlinks. May create
# missing components only when allowSave was explicitly enabled by root.
.PrW_popen_dir:
 mov qword ptr [rip+.PrW_pdir],-1
 mov qword ptr [rip+.PrW_pfd],-1
 mov qword ptr [rip+.PrW_pcreated],0
 mov eax,2
 lea rdi,[rip+.PrW_phome]
 mov esi,0xb0000
 xor edx,edx
 syscall
 test rax,rax
 js .PrW_popen_return
 mov [rip+.PrW_pdir],rax
 push rbx
 push r12
 sub rsp,8
 xor ebx,ebx
.PrW_popen_component:
 lea rax,[rip+.PrW_phcomponents]
 movsxd r12,dword ptr [rax+rbx*4]
 add r12,rax
.PrW_popen_again:
 mov eax,257
 mov rdi,[rip+.PrW_pdir]
 mov rsi,r12
 mov edx,0xb0000
 xor r10d,r10d
 syscall
 test rax,rax
 jns .PrW_popen_success
 cmp rax,-2
 jne .PrW_popen_component_error
 cmp qword ptr [rip+.PrW_penabled],0
 je .PrW_popen_component_error
 mov eax,258
 mov rdi,[rip+.PrW_pdir]
 mov rsi,r12
 mov edx,0700
 syscall
 test rax,rax
 jns .PrW_popen_again
 cmp rax,-17
 je .PrW_popen_again
 jmp .PrW_popen_component_error
.PrW_popen_success:
 push rax
 mov eax,3
 mov rdi,[rip+.PrW_pdir]
 syscall
 pop rax
 mov [rip+.PrW_pdir],rax
 inc ebx
 cmp ebx,3
 jb .PrW_popen_component
 xor eax,eax
.PrW_popen_component_error:
 add rsp,8
 pop r12
 pop rbx
.PrW_popen_return:
 ret
.PrW_pclose:
 mov rdi,[rip+.PrW_pfd]
 test rdi,rdi
 js .PrW_pclose_dir
 mov eax,3
 syscall
 mov qword ptr [rip+.PrW_pfd],-1
.PrW_pclose_dir:
 mov rdi,[rip+.PrW_pdir]
 test rdi,rdi
 js .PrW_pclose_return
 mov eax,3
 syscall
 mov qword ptr [rip+.PrW_pdir],-1
.PrW_pclose_return:
 ret
.local .PrW_load
.PrW_load:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 cmp qword ptr [rip+.PrW_pconfigured],0
 je .PrW_load_return
 call .PrW_popen_dir
 test rax,rax
 js .PrW_load_open_error
 mov eax,257
 mov rdi,[rip+.PrW_pdir]
 lea rsi,[rip+.PrW_pname]
 mov edx,0xa0800
 xor r10d,r10d
 syscall
 test rax,rax
 js .PrW_load_open_error
 mov [rip+.PrW_pfd],rax
 mov rdi,rax
 mov eax,5
 lea rsi,[rip+.PrW_pstat]
 syscall
 test rax,rax
 js .PrW_load_error
 mov eax,[rip+.PrW_pstat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .PrW_load_invalid
 mov eax,107
 syscall
 cmp eax,[rip+.PrW_pstat+28]
 jne .PrW_load_invalid
 cmp qword ptr [rip+.PrW_pstat+48],1048576
 ja .PrW_load_full
 xor r12d,r12d
.PrW_load_read:
 mov eax,0
 mov rdi,[rip+.PrW_pfd]
 lea rsi,[rip+.PrW_pjson]
 add rsi,r12
 mov edx,1048577
 sub rdx,r12
 jz .PrW_load_full
 syscall
 cmp rax,-4
 je .PrW_load_read
 test rax,rax
 js .PrW_load_error
 jz .PrW_load_parse
 add r12,rax
 jmp .PrW_load_read
.PrW_load_parse:
 cmp r12,1048576
 ja .PrW_load_full
 lea rdi,[rip+.PrW_pjson]
 mov rsi,r12
 lea rdx,[rip+.PrW_ptokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .PrW_load_invalid
 cmp qword ptr [rip+.PrW_ptokens],JT_ARRAY
 jne .PrW_load_invalid
 mov ebx,1
 xor r13d,r13d
.PrW_load_validate:
 cmp rbx,[rip+.PrW_ptokens+T_END]
 jae .PrW_load_valid
 lea r12,[rip+.PrW_ptokens]
 mov rax,rbx
 shl rax,5
 add r12,rax
 cmp qword ptr [r12+T_TYPE],JT_STRING
 jne .PrW_load_invalid
 call .PrW_load_decode
 test rax,rax
 js .PrW_load_invalid
 cmp rax,65535
 ja .PrW_load_full
 mov rbx,[r12+T_END]
 inc r13
 jmp .PrW_load_validate
.PrW_load_valid:
 call .PrW_clear
 mov qword ptr [rip+.PrW_ploading],1
 mov ebx,1
.PrW_load_commit:
 cmp rbx,[rip+.PrW_ptokens+T_END]
 jae .PrW_load_committed
 lea r12,[rip+.PrW_ptokens]
 mov rax,rbx
 shl rax,5
 add r12,rax
 call .PrW_load_decode
 mov rsi,rax
 lea rdi,[rip+.PrW_pdecoded]
 call .PrW_add
 mov rbx,[r12+T_END]
 jmp .PrW_load_commit
.PrW_load_committed:
 mov qword ptr [rip+.PrW_ploading],0
 mov r15,[rip+.PrW_hcount]
 jmp .PrW_load_cleanup
.PrW_load_decode:
 lea rdi,[rip+.PrW_pdecoded]
 lea rsi,[rip+.PrW_pjson]
 add rsi,[r12+T_START]
 mov rdx,[r12+T_LEN]
 mov ecx,65536
 jmp json_decode
.PrW_load_open_error:
 cmp rax,-2
 je .PrW_load_cleanup
.PrW_load_error:
 mov r15,rax
 jmp .PrW_load_cleanup
.PrW_load_invalid:
 mov r15,-22
 jmp .PrW_load_cleanup
.PrW_load_full:
 mov r15,-28
.PrW_load_cleanup:
 call .PrW_pclose
 xor eax,eax
 test r15,r15
 cmovs rax,r15
 mov [rip+.PrW_perror],rax
.PrW_load_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.local .PrW_save
.PrW_save:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 xor r15d,r15d
 cmp qword ptr [rip+.PrW_penabled],0
 je .PrW_save_return
 cmp qword ptr [rip+.PrW_pconfigured],0
 je .PrW_save_return
 cmp qword ptr [rip+.PrW_ploading],0
 jne .PrW_save_return
 # Serialize complete JSON before touching the previous history file.
 lea r14,[rip+.PrW_pjson]
 mov byte ptr [r14],91
 mov r12d,1
 mov rbx,[rip+.PrW_hcount]
.PrW_save_entry:
 test rbx,rbx
 jz .PrW_save_json_done
 dec rbx
 mov rax,[rip+.PrW_hcount]
 dec rax
 cmp rbx,rax
 je .PrW_save_no_comma
 mov byte ptr [r14+r12],44
 inc r12
.PrW_save_no_comma:
 lea rax,[rip+.PrW_horder]
 mov rbp,[rax+rbx*8]
 lea rdi,[r14+r12]
 lea rax,[rip+.PrW_hlens]
 mov rdx,[rax+rbp*8]
 mov rsi,rbp
 shl rsi,16
 lea rax,[rip+.PrW_htext]
 add rsi,rax
 mov ecx,1048574
 sub rcx,r12
 jbe .PrW_save_full
 call json_quote
 test rax,rax
 js .PrW_save_full
 add r12,rax
 jmp .PrW_save_entry
.PrW_save_json_done:
 mov word ptr [r14+r12],0x0a5d
 add r12,2
 mov [rip+.PrW_plen],r12
 call .PrW_popen_dir
 test rax,rax
 js .PrW_save_error
 # Random O_EXCL temporary file inside the already-bound private directory.
.PrW_save_random:
 mov eax,318
 lea rdi,[rip+.PrW_prandom]
 mov esi,16
 xor edx,edx
 syscall
 cmp rax,-4
 je .PrW_save_random
 cmp rax,16
 jne .PrW_save_io
 lea rdi,[rip+.PrW_ptemp]
 lea rsi,[rip+.PrW_pname]
 mov ecx,36
 rep movsb
 mov dword ptr [rdi-1],0x706d742e
 add rdi,3
 mov byte ptr [rdi],45
 inc rdi
 lea rsi,[rip+.PrW_prandom]
 lea r8,[rip+.PrW_phhex]
 mov ecx,16
.PrW_save_hex:
 movzx eax,byte ptr [rsi]
 inc rsi
 mov edx,eax
 shr eax,4
 and edx,15
 mov al,[r8+rax]
 stosb
 mov al,[r8+rdx]
 stosb
 loop .PrW_save_hex
 mov byte ptr [rdi],0
 mov eax,257
 mov rdi,[rip+.PrW_pdir]
 lea rsi,[rip+.PrW_ptemp]
 mov edx,0xa00c1
 mov r10d,0600
 syscall
 test rax,rax
 js .PrW_save_error
 mov [rip+.PrW_pfd],rax
 mov qword ptr [rip+.PrW_pcreated],1
 mov rdi,rax
 mov eax,91
 mov esi,0600
 syscall
 test rax,rax
 js .PrW_save_error
 xor ebx,ebx
.PrW_save_write:
 cmp rbx,[rip+.PrW_plen]
 jae .PrW_save_fsync
 mov eax,1
 mov rdi,[rip+.PrW_pfd]
 lea rsi,[rip+.PrW_pjson]
 add rsi,rbx
 mov rdx,[rip+.PrW_plen]
 sub rdx,rbx
 syscall
 cmp rax,-4
 je .PrW_save_write
 test rax,rax
 jle .PrW_save_io
 add rbx,rax
 jmp .PrW_save_write
.PrW_save_fsync:
 mov eax,74
 mov rdi,[rip+.PrW_pfd]
 syscall
 cmp rax,-4
 je .PrW_save_fsync
 test rax,rax
 js .PrW_save_error
 mov eax,3
 mov rdi,[rip+.PrW_pfd]
 syscall
 mov qword ptr [rip+.PrW_pfd],-1
 mov eax,264
 mov rdi,[rip+.PrW_pdir]
 lea rsi,[rip+.PrW_ptemp]
 mov rdx,rdi
 lea r10,[rip+.PrW_pname]
 syscall
 test rax,rax
 js .PrW_save_error
 mov qword ptr [rip+.PrW_pcreated],0
 jmp .PrW_save_cleanup
.PrW_save_full:
 mov r15,-28
 jmp .PrW_save_return
.PrW_save_io:
 mov rax,-5
.PrW_save_error:
 mov r15,rax
.PrW_save_cleanup:
 cmp qword ptr [rip+.PrW_pcreated],0
 je .PrW_save_close
 mov eax,263
 mov rdi,[rip+.PrW_pdir]
 lea rsi,[rip+.PrW_ptemp]
 xor edx,edx
 syscall
.PrW_save_close:
 call .PrW_pclose
 mov [rip+.PrW_perror],r15
.PrW_save_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.section .rodata
.Pr_global: .asciz "@global-shell-permissions"
.Pr_user: .asciz "User · exact command"
.Pr_project: .asciz "Project · exact command"
.section .bss
.Pr_enabled: .skip 8
.Pr_quote: .skip 393218
.Pr_tokens: .skip 128
.section .text
.global ui_shell_permission_config
ui_shell_permission_config:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 mov rbx,rdx
 mov [rip+.Pr_enabled],rdx
 lea rsi,[rip+.Pr_global]
 call .PrU_config
 mov rdi,r12
 mov rsi,r13
 mov rdx,rbx
 call .PrW_config
 cmp rax,-2
 jne .Pr_config_result
 xor eax,eax
.Pr_config_result:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_shell_permission_add
# exact command bytes,len,scope0user1project. Never interprets/splits command.
ui_shell_permission_add:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 mov rbx,rdx
 cmp qword ptr [rip+.Pr_enabled],0
 je .Pr_add_denied
 test rdi,rdi
 jz .Pr_add_bad
 test rsi,rsi
 jz .Pr_add_bad
 cmp rsi,65535
 ja .Pr_add_bad
 cmp rdx,1
 ja .Pr_add_bad
 xor ecx,ecx
.Pr_add_nul:
 cmp rcx,r13
 jae .Pr_add_utf8
 cmp byte ptr [r12+rcx],0
 je .Pr_add_bad
 inc rcx
 jmp .Pr_add_nul
.Pr_add_utf8:
 lea rdi,[rip+.Pr_quote]
 mov rsi,r12
 mov rdx,r13
 mov ecx,393218
 call json_quote
 test rax,rax
 js .Pr_add_bad
 lea rdi,[rip+.Pr_quote]
 mov rsi,rax
 lea rdx,[rip+.Pr_tokens]
 mov ecx,4
 call json_parse
 cmp rax,1
 jne .Pr_add_bad
 mov rdi,r12
 mov rsi,r13
 test rbx,rbx
 jnz .Pr_add_workspace
 call .PrU_add
 mov rax,[rip+.PrU_perror]
 jmp .Pr_add_return
.Pr_add_workspace:
 call .PrW_add
 mov rax,[rip+.PrW_perror]
 jmp .Pr_add_return
.Pr_add_bad:
 mov rax,-22
 jmp .Pr_add_return
.Pr_add_denied:
 mov rax,-13
.Pr_add_return:
 pop r13
 pop r12
 pop rbx
 ret
.global ui_shell_permission_match
ui_shell_permission_match:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 lea r8,[rip+.PrW_hcount]
 lea r9,[rip+.PrW_horder]
 lea r10,[rip+.PrW_hlens]
 lea r11,[rip+.PrW_htext]
 call .Pr_match_store
 test eax,eax
 jnz .Pr_match_return
 lea r8,[rip+.PrU_hcount]
 lea r9,[rip+.PrU_horder]
 lea r10,[rip+.PrU_hlens]
 lea r11,[rip+.PrU_htext]
 call .Pr_match_store
.Pr_match_return:
 pop r13
 pop r12
 pop rbx
 ret
.Pr_match_store:
 xor ebx,ebx
 test r12,r12
 jz .Pr_match_no
 test r13,r13
 jz .Pr_match_no
.Pr_match_next:
 cmp rbx,[r8]
 jae .Pr_match_no
 mov rax,[r9+rbx*8]
 cmp r13,[r10+rax*8]
 jne .Pr_match_advance
 shl rax,16
 lea rsi,[r11+rax]
 mov rdi,r12
 mov rcx,r13
 repe cmpsb
 je .Pr_match_yes
.Pr_match_advance:
 inc ebx
 jmp .Pr_match_next
.Pr_match_yes:
 mov eax,1
 ret
.Pr_match_no:
 xor eax,eax
 ret
.global ui_shell_permission_catalog
# out24Bitems,capItems ->count (max200), values exact borrowed command strings.
ui_shell_permission_catalog:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 xor ebx,ebx
 test rdi,rdi
 jz .Pr_catalog_done
 lea r8,[rip+.PrW_hcount]
 lea r9,[rip+.PrW_horder]
 lea r10,[rip+.PrW_htext]
 lea r11,[rip+.Pr_project]
 call .Pr_catalog_store
 lea r8,[rip+.PrU_hcount]
 lea r9,[rip+.PrU_horder]
 lea r10,[rip+.PrU_htext]
 lea r11,[rip+.Pr_user]
 call .Pr_catalog_store
.Pr_catalog_done:
 mov rax,rbx
 pop r13
 pop r12
 pop rbx
 ret
.Pr_catalog_store:
 xor edx,edx
.Pr_catalog_next:
 cmp rdx,[r8]
 jae .Pr_catalog_ret
 cmp rbx,r13
 jae .Pr_catalog_ret
 mov rax,[r9+rdx*8]
 shl rax,16
 add rax,r10
 imul rcx,rbx,24
 mov [r12+rcx],rax
 mov [r12+rcx+8],r11
 mov [r12+rcx+16],rax
 inc rbx
 inc rdx
 jmp .Pr_catalog_next
.Pr_catalog_ret:
 ret
.global ui_shell_permission_remove
# command,len,scope; exact match only. Successful removal persists immediately.
ui_shell_permission_remove:
 push rbx
 push r12
 push r13
 push r14
 push r15
 cmp qword ptr [rip+.Pr_enabled],0
 je .Pr_remove_denied
 cmp rdx,1
 ja .Pr_remove_bad
 mov r12,rdi
 mov r13,rsi
 mov r15,rdx
 lea r8,[rip+.PrU_hcount]
 lea r9,[rip+.PrU_horder]
 lea r10,[rip+.PrU_hlens]
 lea r11,[rip+.PrU_htext]
 test rdx,rdx
 jz .Pr_remove_find
 lea r8,[rip+.PrW_hcount]
 lea r9,[rip+.PrW_horder]
 lea r10,[rip+.PrW_hlens]
 lea r11,[rip+.PrW_htext]
.Pr_remove_find:
 call .Pr_match_store
 test eax,eax
 jz .Pr_remove_missing
 dec qword ptr [r8]
.Pr_remove_shift:
 cmp rbx,[r8]
 jae .Pr_remove_save
 mov rax,[r9+rbx*8+8]
 mov [r9+rbx*8],rax
 inc rbx
 jmp .Pr_remove_shift
.Pr_remove_save:
 test r15,r15
 jnz .Pr_remove_project
 call .PrU_save
 jmp .Pr_remove_return
.Pr_remove_project:
 call .PrW_save
 jmp .Pr_remove_return
.Pr_remove_missing:
 mov rax,-2
 jmp .Pr_remove_return
.Pr_remove_bad:
 mov rax,-22
 jmp .Pr_remove_return
.Pr_remove_denied:
 mov rax,-13
.Pr_remove_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .note.GNU-stack,"",@progbits
.section .rodata
.PrU_empty: .byte 0
.PrW_empty: .byte 0
