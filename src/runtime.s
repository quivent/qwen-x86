.include "abi.inc"
.text
.global qx_strlen,qx_streq,qx_write_all,qx_printz,qx_env_get,qx_uint,qx_cat,qx_quote_cat
.type qx_strlen,@function
qx_strlen:
    xor eax,eax
.L_strlen:
    cmp byte ptr [rdi+rax],0
    je .L_strlen_done
    inc rax
    jmp .L_strlen
.L_strlen_done:
    ret
# Exact string equality, 1 equal / 0 unequal.
qx_streq:
    xor eax,eax
.L_streq:
    mov dl,[rdi+rax]
    cmp dl,[rsi+rax]
    jne .L_streq_no
    inc rax
    test dl,dl
    jne .L_streq
    mov eax,1
    ret
.L_streq_no:
    xor eax,eax
    ret
# qx_write_all(fd,bytes,length) -> original length / negative errno.
qx_write_all:
    push r12
    mov r12,rdx
.L_write:
    test rdx,rdx
    jz .L_write_done
    mov eax,1
    syscall
    cmp rax,-4
    je .L_write
    test rax,rax
    js .L_write_error
    jz .L_write_zero
    add rsi,rax
    sub rdx,rax
    jmp .L_write
.L_write_done:
    mov rax,r12
.L_write_error:
    pop r12
    ret
.L_write_zero:
    mov rax,-5
    jmp .L_write_error
# qx_printz(fd,z)
qx_printz:
    push rdi
    mov rdi,rsi
    push rsi
    sub rsp,8
    call qx_strlen
    add rsp,8
    pop rsi
    pop rdi
    mov rdx,rax
    jmp qx_write_all
# qx_env_get(envp,"KEY") -> value address or zero. No environment mutation.
qx_env_get:
    push rbx
    push r12
    mov r12,rdi
    mov rbx,rsi
.L_env_entry:
    mov rdi,[r12]
    test rdi,rdi
    jz .L_env_missing
    xor ecx,ecx
.L_env_char:
    mov al,[rbx+rcx]
    test al,al
    jz .L_env_equal
    cmp al,[rdi+rcx]
    jne .L_env_next
    inc rcx
    jmp .L_env_char
.L_env_equal:
    cmp byte ptr [rdi+rcx],'='
    jne .L_env_next
    lea rax,[rdi+rcx+1]
    jmp .L_env_done
.L_env_next:
    add r12,8
    jmp .L_env_entry
.L_env_missing:
    xor eax,eax
.L_env_done:
    pop r12
    pop rbx
    ret
# qx_uint(dst,value) -> bytes, caller supplies at least 20 bytes.
qx_uint:
    sub rsp,32
    mov rax,rsi
    xor ecx,ecx
    mov r8d,10
.L_uint_digits:
    xor edx,edx
    div r8
    add dl,'0'
    mov [rsp+rcx],dl
    inc ecx
    test rax,rax
    jnz .L_uint_digits
    mov eax,ecx
.L_uint_copy:
    dec ecx
    mov dl,[rsp+rcx]
    mov [rdi],dl
    inc rdi
    test ecx,ecx
    jnz .L_uint_copy
    add rsp,32
    ret
# Builder is {base,capacity,length}, all u64. Never grows or truncates.
qx_cat:
    mov rax,[rdi+16]
    mov r9,rax
    add r9,rdx
    jc .L_cat_bad
    cmp r9,[rdi+8]
    ja .L_cat_bad
    push rdi
    mov rdi,[rdi]
    add rdi,rax
    mov rcx,rdx
    rep movsb
    pop rdi
    mov [rdi+16],r9
    xor eax,eax
    ret
.L_cat_bad:
    mov rax,-1
    ret
# qx_quote_cat(builder,raw,length) ->0 /negative.
qx_quote_cat:
    push rbx
    mov rbx,rdi
    mov rax,[rdi+16]
    mov rcx,[rdi+8]
    sub rcx,rax
    mov rdi,[rdi]
    add rdi,rax
    call json_quote
    test rax,rax
    js .L_quote_done
    add [rbx+16],rax
    xor eax,eax
.L_quote_done:
    pop rbx
    ret
.section .note.GNU-stack,"",@progbits
.text
.global qx_parse_uint
qx_parse_uint:
    test rsi,rsi
    jz .L_parse_uint_bad
    xor eax,eax
    xor ecx,ecx
.L_parse_uint_loop:
    movzx edx,byte ptr [rdi+rcx]
    sub edx,'0'
    cmp edx,9
    ja .L_parse_uint_bad
    mov r8,0x1999999999999999
    cmp rax,r8
    ja .L_parse_uint_bad
    imul rax,rax,10
    add rax,rdx
    jc .L_parse_uint_bad
    inc rcx
    cmp rcx,rsi
    jb .L_parse_uint_loop
    ret
.L_parse_uint_bad:
    mov rax,-1
    ret
