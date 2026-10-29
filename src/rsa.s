# Public RSA verification. Fixed32-bit Montgomery lanes; no private-key operations.
# Scope: normalized odd1024..4096-bit modulus, exponent65537, SHA256 signatures.
.intel_syntax noprefix

.section .rodata
r_der_sha256: .byte 0x30,0x31,0x30,0x0d,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,0x04,0x02,0x01,0x05,0x00,0x04,0x20

.section .bss
.align 16
r_limbs: .skip 8
r_bytes: .skip 8
r_n0: .skip 8
r_out: .skip 8
r_mod: .skip 512
r_base: .skip 512
r_rr: .skip 512
r_one: .skip 512
r_acc: .skip 512
r_t: .skip 520
r_encoded: .skip 512
r_db: .skip 512
r_hash: .skip 32
r_seed: .skip 36
r_prime: .skip 72
r_msg_hash: .skip 32

.section .text
.global rsa_public,rsa_pss_sha256_verify,rsa_pkcs1_sha256_verify
.extern sha256_hash

# rsa_public(sigBE,siglen,nBE,nlen,e,outBE)->0/-1.
rsa_public:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 mov r13,rdx
 mov r14,rcx
 mov QWORD PTR [rip+r_out],r9
 test r12,r12
 jz .Lrp_bad
 test r13,r13
 jz .Lrp_bad
 test r9,r9
 jz .Lrp_bad
 cmp r8,65537
 jne .Lrp_bad
 cmp rsi,r14
 jne .Lrp_bad
 cmp r14,128
 jb .Lrp_bad
 cmp r14,512
 ja .Lrp_bad
 test r14,3
 jnz .Lrp_bad
 test BYTE PTR [r13],0x80
 jz .Lrp_bad
 test BYTE PTR [r13+r14-1],1
 jz .Lrp_bad
 xor ecx,ecx
.Lrp_compare:
 cmp rcx,r14
 jae .Lrp_bad
 mov al,BYTE PTR [r12+rcx]
 cmp al,BYTE PTR [r13+rcx]
 jb .Lrp_less
 ja .Lrp_bad
 inc rcx
 jmp .Lrp_compare
.Lrp_less:
 mov QWORD PTR [rip+r_bytes],r14
 mov r15,r14
 shr r15,2
 mov QWORD PTR [rip+r_limbs],r15
 lea rdi,[rip+r_rr]
 xor eax,eax
 mov ecx,512
 rep stosb
 lea rdi,[rip+r_one]
 mov ecx,512
 rep stosb
 mov DWORD PTR [rip+r_rr],1
 mov DWORD PTR [rip+r_one],1
 xor ebx,ebx
.Lrp_convert:
 cmp rbx,r15
 jae .Lrp_inverse
 mov rcx,r14
 lea rax,[rbx*4+4]
 sub rcx,rax
 mov eax,DWORD PTR [r13+rcx]
 bswap eax
 lea rdx,[rip+r_mod]
 mov DWORD PTR [rdx+rbx*4],eax
 mov eax,DWORD PTR [r12+rcx]
 bswap eax
 lea rdx,[rip+r_base]
 mov DWORD PTR [rdx+rbx*4],eax
 inc rbx
 jmp .Lrp_convert
.Lrp_inverse:
 mov r8d,DWORD PTR [rip+r_mod]
 mov eax,1
 mov ecx,5
.Lrp_newton:
 mov edx,r8d
 imul edx,eax
 neg edx
 add edx,2
 imul eax,edx
 dec ecx
 jnz .Lrp_newton
 neg eax
 mov DWORD PTR [rip+r_n0],eax
 mov rbx,r14
 shl rbx,4
.Lrp_r2:
 lea rdi,[rip+r_rr]
 call r_double
 dec rbx
 jnz .Lrp_r2
 lea rdi,[rip+r_base]
 lea rsi,[rip+r_rr]
 lea rdx,[rip+r_base]
 call r_mont
 lea rsi,[rip+r_base]
 lea rdi,[rip+r_acc]
 mov rcx,r15
 rep movsd
 mov ebx,16
.Lrp_square:
 lea rdi,[rip+r_acc]
 mov rsi,rdi
 mov rdx,rdi
 call r_mont
 dec ebx
 jnz .Lrp_square
 lea rdi,[rip+r_acc]
 lea rsi,[rip+r_base]
 lea rdx,[rip+r_acc]
 call r_mont
 lea rdi,[rip+r_acc]
 lea rsi,[rip+r_one]
 lea rdx,[rip+r_acc]
 call r_mont
 xor ebx,ebx
.Lrp_output:
 cmp rbx,r15
 jae .Lrp_good
 lea rdx,[rip+r_acc]
 mov eax,DWORD PTR [rdx+rbx*4]
 bswap eax
 mov rcx,r14
 lea rdx,[rbx*4+4]
 sub rcx,rdx
 mov rdx,QWORD PTR [rip+r_out]
 mov DWORD PTR [rdx+rcx],eax
 inc rbx
 jmp .Lrp_output
.Lrp_good:
 xor eax,eax
 jmp .Lrp_done
.Lrp_bad:
 mov rax,-1
.Lrp_done:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# Double one N-limb value modulo the bound modulus. N and width are early data.
r_double:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,QWORD PTR [rip+r_limbs]
 xor r8d,r8d
 xor ebx,ebx
.Lrd_double:
 mov eax,DWORD PTR [r12+r8*4]
 lea rax,[rax*2+rbx]
 mov DWORD PTR [r12+r8*4],eax
 shr rax,32
 mov rbx,rax
 inc r8
 cmp r8,r13
 jb .Lrd_double
 test rbx,rbx
 jnz .Lrd_subtract
 mov r8,r13
 lea r9,[rip+r_mod]
.Lrd_compare:
 dec r8
 mov eax,DWORD PTR [r12+r8*4]
 cmp eax,DWORD PTR [r9+r8*4]
 ja .Lrd_subtract
 jb .Lrd_done
 test r8,r8
 jnz .Lrd_compare
.Lrd_subtract:
 xor ebx,ebx
 xor r8d,r8d
 lea r9,[rip+r_mod]
.Lrd_subtract_loop:
 mov eax,DWORD PTR [r12+r8*4]
 mov edx,DWORD PTR [r9+r8*4]
 sub rax,rdx
 sub rax,rbx
 mov DWORD PTR [r12+r8*4],eax
 shr rax,63
 mov rbx,rax
 inc r8
 cmp r8,r13
 jb .Lrd_subtract_loop
.Lrd_done:
 pop r13
 pop r12
 pop rbx
 ret

# CIOS Montgomery(aLE,bLE,outLE), N32-bit limbs, supports aliases.
r_mont:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov rbx,rdi
 mov rbp,rsi
 mov r12,rdx
 lea rdi,[rip+r_t]
 xor eax,eax
 mov ecx,130
 rep stosd
 xor r13d,r13d
.Lrm_outer:
 mov r14d,DWORD PTR [rbp+r13*4]
 xor r15d,r15d
 xor r8d,r8d
 lea r9,[rip+r_t]
.Lrm_product:
 mov eax,DWORD PTR [rbx+r8*4]
 imul rax,r14
 mov edx,DWORD PTR [r9+r8*4]
 add rax,rdx
 add rax,r15
 mov DWORD PTR [r9+r8*4],eax
 shr rax,32
 mov r15,rax
 inc r8
 cmp r8,QWORD PTR [rip+r_limbs]
 jb .Lrm_product
 mov eax,DWORD PTR [r9+r8*4]
 add rax,r15
 mov DWORD PTR [r9+r8*4],eax
 shr rax,32
 mov DWORD PTR [r9+r8*4+4],eax
 mov r14d,DWORD PTR [r9]
 imul r14d,DWORD PTR [rip+r_n0]
 lea r10,[rip+r_mod]
 mov eax,DWORD PTR [r10]
 imul rax,r14
 mov edx,DWORD PTR [r9]
 add rax,rdx
 shr rax,32
 mov r15,rax
 mov r8d,1
.Lrm_reduce:
 mov eax,DWORD PTR [r10+r8*4]
 imul rax,r14
 mov edx,DWORD PTR [r9+r8*4]
 add rax,rdx
 add rax,r15
 mov DWORD PTR [r9+r8*4-4],eax
 shr rax,32
 mov r15,rax
 inc r8
 cmp r8,QWORD PTR [rip+r_limbs]
 jb .Lrm_reduce
 mov eax,DWORD PTR [r9+r8*4]
 add rax,r15
 mov DWORD PTR [r9+r8*4-4],eax
 shr rax,32
 mov edx,DWORD PTR [r9+r8*4+4]
 add rax,rdx
 mov DWORD PTR [r9+r8*4],eax
 mov DWORD PTR [r9+r8*4+4],0
 inc r13
 cmp r13,QWORD PTR [rip+r_limbs]
 jb .Lrm_outer
 mov r8,QWORD PTR [rip+r_limbs]
 cmp DWORD PTR [r9+r8*4],0
 jne .Lrm_subtract
.Lrm_compare:
 dec r8
 mov eax,DWORD PTR [r9+r8*4]
 cmp eax,DWORD PTR [r10+r8*4]
 ja .Lrm_subtract
 jb .Lrm_copy
 test r8,r8
 jnz .Lrm_compare
.Lrm_subtract:
 xor r14d,r14d
 xor r8d,r8d
.Lrm_sub_loop:
 mov eax,DWORD PTR [r9+r8*4]
 mov edx,DWORD PTR [r10+r8*4]
 sub rax,rdx
 sub rax,r14
 mov DWORD PTR [r9+r8*4],eax
 shr rax,63
 mov r14,rax
 inc r8
 cmp r8,QWORD PTR [rip+r_limbs]
 jb .Lrm_sub_loop
.Lrm_copy:
 mov rdi,r12
 mov rsi,r9
 mov rcx,QWORD PTR [rip+r_limbs]
 rep movsd
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# rsa_*_verify(modBE,nlen,sigBE,siglen,digest32)->1/0.
# Public exponent is fixed by the negotiated TLS signature algorithm.
rsa_pkcs1_sha256_verify:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 mov r14,r8
 test r14,r14
 jz .Lpk_bad
 mov rdi,rdx
 mov rsi,rcx
 mov rdx,r12
 mov rcx,r13
 mov r8d,65537
 lea r9,[rip+r_encoded]
 call rsa_public
 test rax,rax
 jne .Lpk_bad
 lea r8,[rip+r_encoded]
 xor ebx,ebx
 movzx eax,BYTE PTR [r8]
 or ebx,eax
 movzx eax,BYTE PTR [r8+1]
 xor eax,1
 or ebx,eax
 mov r9,r13
 sub r9,52
 mov ecx,2
.Lpk_padding:
 cmp rcx,r9
 jae .Lpk_separator
 movzx eax,BYTE PTR [r8+rcx]
 xor eax,255
 or ebx,eax
 inc rcx
 jmp .Lpk_padding
.Lpk_separator:
 movzx eax,BYTE PTR [r8+r9]
 or ebx,eax
 lea r8,[r8+r9+1]
 lea r9,[rip+r_der_sha256]
 xor ecx,ecx
.Lpk_der:
 movzx eax,BYTE PTR [r8+rcx]
 xor al,BYTE PTR [r9+rcx]
 or ebx,eax
 inc rcx
 cmp rcx,19
 jb .Lpk_der
 add r8,19
 xor ecx,ecx
.Lpk_digest:
 movzx eax,BYTE PTR [r8+rcx]
 xor al,BYTE PTR [r14+rcx]
 or ebx,eax
 inc rcx
 cmp rcx,32
 jb .Lpk_digest
 xor eax,eax
 test ebx,ebx
 sete al
 jmp .Lpk_done
.Lpk_bad:
 xor eax,eax
.Lpk_done:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

rsa_pss_sha256_verify:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 mov r14,r8
 test r14,r14
 jz .Lps_bad
 mov rdi,rdx
 mov rsi,rcx
 mov rdx,r12
 mov rcx,r13
 mov r8d,65537
 lea r9,[rip+r_encoded]
 call rsa_public
 test rax,rax
 jne .Lps_bad
 lea rbx,[rip+r_encoded]
 cmp BYTE PTR [rbx+r13-1],0xbc
 jne .Lps_bad
 test BYTE PTR [rbx],0x80
 jnz .Lps_bad
 mov r15,r13
 sub r15,33
 lea rsi,[rbx+r15]
 lea rdi,[rip+r_seed]
 mov ecx,32
 rep movsb
 lea rsi,[rip+r_encoded]
 lea rdi,[rip+r_db]
 mov rcx,r15
 rep movsb
 xor ebp,ebp
 xor r12d,r12d
.Lps_mgf:
 mov eax,r12d
 bswap eax
 mov DWORD PTR [rip+r_seed+32],eax
 lea rdi,[rip+r_seed]
 mov esi,36
 lea rdx,[rip+r_hash]
 call sha256_hash@PLT
 mov r9,r15
 sub r9,rbp
 mov eax,32
 cmp r9,32
 cmova r9,rax
 xor ecx,ecx
 lea r8,[rip+r_db]
 add r8,rbp
 lea r10,[rip+r_hash]
.Lps_xor:
 mov al,BYTE PTR [r10+rcx]
 xor BYTE PTR [r8+rcx],al
 inc rcx
 cmp rcx,r9
 jb .Lps_xor
 add rbp,r9
 inc r12d
 cmp rbp,r15
 jb .Lps_mgf
 and BYTE PTR [rip+r_db],0x7f
 xor ebx,ebx
 mov r9,r15
 sub r9,33
 xor ecx,ecx
 lea r8,[rip+r_db]
.Lps_zeros:
 cmp rcx,r9
 jae .Lps_separator
 movzx eax,BYTE PTR [r8+rcx]
 or ebx,eax
 inc rcx
 jmp .Lps_zeros
.Lps_separator:
 movzx eax,BYTE PTR [r8+r9]
 xor eax,1
 or ebx,eax
 lea rdi,[rip+r_prime]
 xor eax,eax
 mov ecx,8
 rep stosb
 mov rsi,r14
 mov ecx,32
 rep movsb
 lea rsi,[r8+r9+1]
 mov ecx,32
 rep movsb
 lea rdi,[rip+r_prime]
 mov esi,72
 lea rdx,[rip+r_msg_hash]
 call sha256_hash@PLT
 lea r8,[rip+r_msg_hash]
 lea r9,[rip+r_seed]
 xor ecx,ecx
.Lps_hash_compare:
 movzx eax,BYTE PTR [r8+rcx]
 xor al,BYTE PTR [r9+rcx]
 or ebx,eax
 inc rcx
 cmp rcx,32
 jb .Lps_hash_compare
 xor eax,eax
 test ebx,ebx
 sete al
 jmp .Lps_done
.Lps_bad:
 xor eax,eax
.Lps_done:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

.section .note.GNU-stack,"",@progbits
