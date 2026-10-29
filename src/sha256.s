.include "abi.inc"
.text
.global sha256_init,sha256_update,sha256_final,sha256_hash,hmac_sha256,hkdf_extract,hkdf_expand,tls_hkdf_label
# SHA-256 context112: state32,total8,used8,buffer64. Private caller state.
sha256_init:
    lea rsi,[rip+sha256_iv]
    mov ecx,4
    rep movsq
    mov qword ptr [rdi],0
    mov qword ptr [rdi+8],0
    xor eax,eax
    ret
# sha256_compress(state,block), fixed64 rounds, immutable K and stack schedule.
sha256_compress:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,264
    mov rbp,rdi
    xor ecx,ecx
.L_sha_load:
    mov eax,[rsi+rcx*4]
    bswap eax
    mov [rsp+rcx*4],eax
    inc ecx
    cmp ecx,16
    jb .L_sha_load
.L_sha_schedule:
    mov eax,[rsp+rcx*4-60]
    mov edx,eax
    ror edx,7
    mov esi,eax
    ror esi,18
    xor edx,esi
    shr eax,3
    xor edx,eax
    mov eax,[rsp+rcx*4-8]
    mov esi,eax
    ror esi,17
    mov edi,eax
    ror edi,19
    xor esi,edi
    shr eax,10
    xor esi,eax
    add edx,esi
    add edx,[rsp+rcx*4-64]
    add edx,[rsp+rcx*4-28]
    mov [rsp+rcx*4],edx
    inc ecx
    cmp ecx,64
    jb .L_sha_schedule
    mov r8d,[rbp]
    mov r9d,[rbp+4]
    mov r10d,[rbp+8]
    mov r11d,[rbp+12]
    mov r12d,[rbp+16]
    mov r13d,[rbp+20]
    mov r14d,[rbp+24]
    mov r15d,[rbp+28]
    lea rdi,[rip+sha256_k]
    xor ecx,ecx
.L_sha_round:
    mov eax,r12d
    ror eax,6
    mov edx,r12d
    ror edx,11
    xor eax,edx
    mov edx,r12d
    ror edx,25
    xor eax,edx
    mov edx,r12d
    and edx,r13d
    mov esi,r12d
    not esi
    and esi,r14d
    xor edx,esi
    add eax,edx
    add eax,r15d
    add eax,[rdi+rcx*4]
    add eax,[rsp+rcx*4]
    mov ebx,r8d
    ror ebx,2
    mov edx,r8d
    ror edx,13
    xor ebx,edx
    mov edx,r8d
    ror edx,22
    xor ebx,edx
    mov edx,r8d
    and edx,r9d
    mov esi,r8d
    and esi,r10d
    xor edx,esi
    mov esi,r9d
    and esi,r10d
    xor edx,esi
    add ebx,edx
    mov r15d,r14d
    mov r14d,r13d
    mov r13d,r12d
    mov r12d,r11d
    add r12d,eax
    mov r11d,r10d
    mov r10d,r9d
    mov r9d,r8d
    mov r8d,eax
    add r8d,ebx
    inc ecx
    cmp ecx,64
    jb .L_sha_round
    add [rbp],r8d
    add [rbp+4],r9d
    add [rbp+8],r10d
    add [rbp+12],r11d
    add [rbp+16],r12d
    add [rbp+20],r13d
    add [rbp+24],r14d
    add [rbp+28],r15d
    add rsp,264
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
# update(ctx,data,len)
sha256_update:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12,rdi
    mov r13,rsi
    mov r14,rdx
    add [r12+32],rdx
.L_sha_update_loop:
    test r14,r14
    jz .L_sha_update_done
    mov rbx,[r12+40]
    test rbx,rbx
    jnz .L_sha_partial
    cmp r14,64
    jb .L_sha_partial
    mov rdi,r12
    mov rsi,r13
    call sha256_compress
    add r13,64
    sub r14,64
    jmp .L_sha_update_loop
.L_sha_partial:
    mov r15d,64
    sub r15,rbx
    cmp r15,r14
    cmova r15,r14
    lea rdi,[r12+rbx+48]
    mov rsi,r13
    mov rcx,r15
    rep movsb
    add r13,r15
    sub r14,r15
    add rbx,r15
    mov [r12+40],rbx
    cmp rbx,64
    jne .L_sha_update_loop
    mov rdi,r12
    lea rsi,[r12+48]
    call sha256_compress
    mov qword ptr [r12+40],0
    jmp .L_sha_update_loop
.L_sha_update_done:
    xor eax,eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# final(ctx,out32)
sha256_final:
    push rbx
    push r12
    push r13
    mov r12,rdi
    mov r13,rsi
    mov rbx,[r12+40]
    mov byte ptr [r12+rbx+48],0x80
    inc rbx
    cmp rbx,56
    jbe .L_sha_final_pad
    lea rdi,[r12+rbx+48]
    mov ecx,64
    sub rcx,rbx
    xor eax,eax
    rep stosb
    mov rdi,r12
    lea rsi,[r12+48]
    call sha256_compress
    xor ebx,ebx
.L_sha_final_pad:
    lea rdi,[r12+rbx+48]
    mov ecx,56
    sub rcx,rbx
    xor eax,eax
    rep stosb
    mov rax,[r12+32]
    shl rax,3
    bswap rax
    mov [r12+104],rax
    mov rdi,r12
    lea rsi,[r12+48]
    call sha256_compress
    xor ecx,ecx
.L_sha_final_output:
    mov eax,[r12+rcx*4]
    bswap eax
    mov [r13+rcx*4],eax
    inc ecx
    cmp ecx,8
    jb .L_sha_final_output
    xor eax,eax
    pop r13
    pop r12
    pop rbx
    ret
# hash(data,len,out32)
sha256_hash:
    push r12
    push r13
    push r14
    sub rsp,112
    mov r12,rdi
    mov r13,rsi
    mov r14,rdx
    mov rdi,rsp
    call sha256_init
    mov rdi,rsp
    mov rsi,r12
    mov rdx,r13
    call sha256_update
    mov rdi,rsp
    mov rsi,r14
    call sha256_final
    mov rdi,rsp
    mov ecx,14
    xor eax,eax
    rep stosq
    add rsp,112
    pop r14
    pop r13
    pop r12
    ret
# HMAC(key,keylen,data,datalen,out32)
hkdf_extract:
hmac_sha256:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp,224
    mov r12,rdi
    mov r13,rsi
    mov r14,rdx
    mov r15,rcx
    mov rbx,r8
    lea rdi,[rsp+112]
    mov ecx,8
    xor eax,eax
    rep stosq
    cmp r13,64
    jbe .L_hmac_copy_key
    mov rdi,r12
    mov rsi,r13
    lea rdx,[rsp+112]
    call sha256_hash
    jmp .L_hmac_ipad
.L_hmac_copy_key:
    lea rdi,[rsp+112]
    mov rsi,r12
    mov rcx,r13
    rep movsb
.L_hmac_ipad:
    mov rax,0x3636363636363636
    xor ecx,ecx
.L_hmac_ipad_loop:
    xor [rsp+rcx*8+112],rax
    inc ecx
    cmp ecx,8
    jb .L_hmac_ipad_loop
    mov rdi,rsp
    call sha256_init
    mov rdi,rsp
    lea rsi,[rsp+112]
    mov edx,64
    call sha256_update
    mov rdi,rsp
    mov rsi,r14
    mov rdx,r15
    call sha256_update
    mov rdi,rsp
    lea rsi,[rsp+176]
    call sha256_final
    mov rax,0x6a6a6a6a6a6a6a6a
    xor ecx,ecx
.L_hmac_opad_loop:
    xor [rsp+rcx*8+112],rax
    inc ecx
    cmp ecx,8
    jb .L_hmac_opad_loop
    mov rdi,rsp
    call sha256_init
    mov rdi,rsp
    lea rsi,[rsp+112]
    mov edx,64
    call sha256_update
    mov rdi,rsp
    lea rsi,[rsp+176]
    mov edx,32
    call sha256_update
    mov rdi,rsp
    mov rsi,rbx
    call sha256_final
    mov rdi,rsp
    mov ecx,28
    xor eax,eax
    rep stosq
    add rsp,224
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# HKDF expand(prk32,info,infolen,out,outlen), max8160 output and256 info.
hkdf_expand:
    cmp rdx,256
    ja .L_hkdf_bad
    cmp r8,8160
    ja .L_hkdf_bad
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp,384
    mov r12,rdi
    mov r13,rsi
    mov r14,rdx
    mov r15,rcx
    mov rbx,r8
    mov qword ptr [rsp+336],0
    mov qword ptr [rsp+344],1
.L_hkdf_loop:
    test rbx,rbx
    jz .L_hkdf_done
    mov rdi,rsp
    lea rsi,[rsp+304]
    mov rcx,[rsp+336]
    rep movsb
    mov rsi,r13
    mov rcx,r14
    rep movsb
    mov rax,[rsp+344]
    mov [rdi],al
    mov rcx,[rsp+336]
    add rcx,r14
    inc rcx
    mov rdi,r12
    mov esi,32
    mov rdx,rsp
    lea r8,[rsp+304]
    call hmac_sha256
    mov rcx,32
    cmp rcx,rbx
    cmova rcx,rbx
    sub rbx,rcx
    mov rdi,r15
    lea rsi,[rsp+304]
    rep movsb
    mov r15,rdi
    mov qword ptr [rsp+336],32
    inc qword ptr [rsp+344]
    jmp .L_hkdf_loop
.L_hkdf_done:
    mov rdi,rsp
    mov ecx,48
    xor eax,eax
    rep stosq
    add rsp,384
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.L_hkdf_bad:
    mov rax,-1
    ret
# TLS Expand-Label(secret,labelz,context,contextlen,out,outlen).
# RFC8446 HkdfLabel is bounded by the generic HKDF info cap here.
tls_hkdf_label:
    cmp rcx,200
    ja .L_label_bad
    cmp r9,8160
    ja .L_label_bad
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp,320
    mov r12,rdi
    mov r13,rsi
    mov r14,rdx
    mov r15,rcx
    mov rbx,r8
    mov [rsp+304],r9
    xor ecx,ecx
.L_label_strlen:
    cmp byte ptr [r13+rcx],0
    je .L_label_len
    inc ecx
    cmp ecx,49
    ja .L_label_bad_pop
    jmp .L_label_strlen
.L_label_len:
    mov rdx,rcx
    mov rax,r9
    rol ax,8
    mov [rsp],ax
    add ecx,6
    mov [rsp+2],cl
    lea rdi,[rsp+3]
    lea rsi,[rip+tls13_prefix]
    mov ecx,6
    rep movsb
    mov rsi,r13
    mov rcx,rdx
    rep movsb
    mov [rdi],r15b
    inc rdi
    mov rsi,r14
    mov rcx,r15
    rep movsb
    mov rdx,rdi
    sub rdx,rsp
    cmp rdx,256
    ja .L_label_bad_pop
    mov rdi,r12
    mov rsi,rsp
    mov rcx,rbx
    mov r8,[rsp+304]
    call hkdf_expand
    jmp .L_label_pop
.L_label_bad_pop:
    mov rax,-1
.L_label_pop:
    add rsp,320
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.L_label_bad:
    mov rax,-1
    ret
.section .rodata
.p2align 4
sha256_iv: .long 0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
sha256_k:
.long 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5
.long 0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174
.long 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da
.long 0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967
.long 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85
.long 0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070
.long 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3
.long 0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
tls13_prefix: .ascii "tls13 "
.section .note.GNU-stack,"",@progbits
