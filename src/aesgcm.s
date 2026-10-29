# [open integration] AES-128/AES-GCM for Linux x86-64 with AES-NI.
# GCM contract: 96-bit nonce, 128-bit tag; exact in-place supported; partial
# input/output overlap rejected. Caller owns nonce uniqueness for each key.
# No writable global state, secret-indexed tables, external calls or runtimes.
.intel_syntax noprefix

.section .text
.macro EXPAND_ROUND rcon, offset
 aeskeygenassist xmm1, xmm0, \rcon
 pshufd xmm1, xmm1, 255
 movdqa xmm2, xmm0
 pslldq xmm2, 4
 pxor xmm0, xmm2
 pslldq xmm2, 4
 pxor xmm0, xmm2
 pslldq xmm2, 4
 pxor xmm0, xmm2
 pxor xmm0, xmm1
 movdqu xmmword ptr [rsi+\offset], xmm0
.endm

.globl aes128_expand
.type aes128_expand,@function
# rdi key16, rsi roundkeys176; supports unaligned buffers.
aes128_expand:
 movdqu xmm0, xmmword ptr [rdi]
 movdqu xmmword ptr [rsi], xmm0
 EXPAND_ROUND 1,16
 EXPAND_ROUND 2,32
 EXPAND_ROUND 4,48
 EXPAND_ROUND 8,64
 EXPAND_ROUND 16,80
 EXPAND_ROUND 32,96
 EXPAND_ROUND 64,112
 EXPAND_ROUND 128,128
 EXPAND_ROUND 27,144
 EXPAND_ROUND 54,160
 pxor xmm0,xmm0
 pxor xmm1,xmm1
 pxor xmm2,xmm2
 xor eax,eax
 ret
.size aes128_expand,.-aes128_expand

.macro AES_ROUND offset
 movdqu xmm1,xmmword ptr [rdi+\offset]
 aesenc xmm0,xmm1
.endm
.globl aes128_block
.type aes128_block,@function
# rdi roundkeys176, rsi input16, rdx output16; exact in-place supported.
aes128_block:
 movdqu xmm0,xmmword ptr [rsi]
 movdqu xmm1,xmmword ptr [rdi]
 pxor xmm0,xmm1
 AES_ROUND 16
 AES_ROUND 32
 AES_ROUND 48
 AES_ROUND 64
 AES_ROUND 80
 AES_ROUND 96
 AES_ROUND 112
 AES_ROUND 128
 AES_ROUND 144
 movdqu xmm1,xmmword ptr [rdi+160]
 aesenclast xmm0,xmm1
 movdqu xmmword ptr [rdx],xmm0
 pxor xmm0,xmm0
 pxor xmm1,xmm1
 xor eax,eax
 ret
.size aes128_block,.-aes128_block

# GHASH multiply X <- X*H, big-endian polynomial representation.
# NIST SP800-38D Algorithm1: exactly128 bit steps. Every selection is a mask;
# the loop counter is a fixed public bound. No branch or address depends on a bit.
.Lghash_multiply:
 push rbx
 push r12
 mov r12,rdi
 mov r8,qword ptr [rdi]
 mov r9,qword ptr [rdi+8]
 mov r10,qword ptr [rsi]
 mov r11,qword ptr [rsi+8]
 bswap r8
 bswap r9
 bswap r10
 bswap r11
 xor eax,eax
 xor edx,edx
 mov rsi,0xe100000000000000
 mov ebx,128
.Lghash_bit:
 mov rcx,r8
 sar rcx,63
 mov rdi,r10
 and rdi,rcx
 xor rax,rdi
 mov rdi,r11
 and rdi,rcx
 xor rdx,rdi
 shld r8,r9,1
 shl r9,1
 mov rcx,r11
 and ecx,1
 neg rcx
 shrd r11,r10,1
 shr r10,1
 and rcx,rsi
 xor r10,rcx
 dec ebx
 jnz .Lghash_bit
 bswap rax
 bswap rdx
 mov qword ptr [r12],rax
 mov qword ptr [r12+8],rdx
 xor eax,eax
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 xor edi,edi
 xor r8d,r8d
 xor r9d,r9d
 xor r10d,r10d
 xor r11d,r11d
 pop r12
 pop rbx
 ret

# rdi Y16, rsi H16, rdx bytes, rcx length. A final partial block is zero-padded
# independently, so AAD and ciphertext boundaries never merge.
.Lghash_bytes:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,16
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
.Lghash_full:
 cmp r15,16
 jb .Lghash_tail
 movdqu xmm0,xmmword ptr [r12]
 movdqu xmm1,xmmword ptr [r14]
 pxor xmm0,xmm1
 movdqu xmmword ptr [r12],xmm0
 mov rdi,r12
 mov rsi,r13
 call .Lghash_multiply
 add r14,16
 sub r15,16
 jmp .Lghash_full
.Lghash_tail:
 test r15,r15
 jz .Lghash_bytes_done
 pxor xmm0,xmm0
 movdqu xmmword ptr [rsp],xmm0
 xor eax,eax
.Lghash_copy_tail:
 movzx edx,byte ptr [r14+rax]
 mov byte ptr [rsp+rax],dl
 inc rax
 cmp rax,r15
 jb .Lghash_copy_tail
 movdqu xmm0,xmmword ptr [r12]
 movdqu xmm1,xmmword ptr [rsp]
 pxor xmm0,xmm1
 movdqu xmmword ptr [r12],xmm0
 mov rdi,r12
 mov rsi,r13
 call .Lghash_multiply
.Lghash_bytes_done:
 pxor xmm0,xmm0
 pxor xmm1,xmm1
 movdqu xmmword ptr [rsp],xmm0
 add rsp,16
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# CTR transform: rdi rk176, rsi mutableJ016, rdx in, rcx out, r8 length.
# Caller has already checked ceil(length/16) <= 2^32-2. J0 low word starts1.
.Lgcm_ctr:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 mov rbx,r8
 mov ebp,2
.Lctr_block:
 test rbx,rbx
 jz .Lctr_done
 mov eax,ebp
 bswap eax
 mov dword ptr [r13+12],eax
 mov rdi,r12
 mov rsi,r13
 mov rdx,rsp
 call aes128_block
 mov r8,rbx
 mov eax,16
 cmp r8,16
 cmova r8,rax
 xor ecx,ecx
.Lctr_bytes:
 movzx eax,byte ptr [r14+rcx]
 xor al,byte ptr [rsp+rcx]
 mov byte ptr [r15+rcx],al
 inc rcx
 cmp rcx,r8
 jb .Lctr_bytes
 add r14,r8
 add r15,r8
 sub rbx,r8
 inc ebp
 jmp .Lctr_block
.Lctr_done:
 pxor xmm0,xmm0
 movdqu xmmword ptr [rsp],xmm0
 mov qword ptr [rsp+16],0
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

.globl gcm_encrypt
.type gcm_encrypt,@function
gcm_encrypt:
 xor esi,esi
 jmp .Lgcm_common
.size gcm_encrypt,.-gcm_encrypt
.globl gcm_decrypt
.type gcm_decrypt,@function
gcm_decrypt:
 mov esi,1
 jmp .Lgcm_common
.size gcm_decrypt,.-gcm_decrypt

# Request layout (64 bytes):
# 0 rk176ptr,8 nonce12ptr,16 AADptr,24 AADlen,32 inputptr,40 inputlen,
# 48 outputptr,56 tag16ptr. Decryption authenticates before writing output.
.Lgcm_common:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,120
 mov qword ptr [rsp+96],rsi
 mov r12,rdi
 test r12,r12
 jz .Lgcm_invalid
 mov r13,qword ptr [r12]
 test r13,r13
 jz .Lgcm_invalid
 cmp qword ptr [r12+8],0
 je .Lgcm_invalid
 cmp qword ptr [r12+56],0
 je .Lgcm_invalid
 mov rax,qword ptr [r12+24]
 mov rcx,0x1fffffffffffffff
 cmp rax,rcx
 ja .Lgcm_invalid
 test rax,rax
 jz .Lgcm_aad_valid
 cmp qword ptr [r12+16],0
 je .Lgcm_invalid
 mov rdx,qword ptr [r12+16]
 add rdx,rax
 jc .Lgcm_invalid
.Lgcm_aad_valid:
 mov rbx,qword ptr [r12+40]
 mov rax,0xfffffffe0
 cmp rbx,rax
 ja .Lgcm_invalid
 mov r14,qword ptr [r12+32]
 mov r15,qword ptr [r12+48]
 test rbx,rbx
 jz .Lgcm_buffers_valid
 test r14,r14
 jz .Lgcm_invalid
 test r15,r15
 jz .Lgcm_invalid
 mov rax,r14
 add rax,rbx
 jc .Lgcm_invalid
 mov rdx,r15
 add rdx,rbx
 jc .Lgcm_invalid
 cmp r14,r15
 je .Lgcm_overlap_valid
 cmp r14,rdx
 jae .Lgcm_overlap_valid
 cmp r15,rax
 jb .Lgcm_invalid
.Lgcm_overlap_valid:
 # Tag may immediately follow ciphertext, but may not replace any ciphertext.
 mov rcx,qword ptr [r12+56]
 mov rsi,rcx
 add rsi,16
 jc .Lgcm_invalid
 cmp rcx,rdx
 jae .Lgcm_tag_valid
 cmp r15,rsi
 jb .Lgcm_invalid
.Lgcm_tag_valid:
 # Output must not overwrite a key schedule needed by later CTR blocks.
 mov rcx,r13
 add rcx,176
 jc .Lgcm_invalid
 cmp r15,rcx
 jae .Lgcm_buffers_valid
 cmp r13,rdx
 jb .Lgcm_invalid
.Lgcm_buffers_valid:
 pxor xmm0,xmm0
 movdqu xmmword ptr [rsp],xmm0
 movdqu xmmword ptr [rsp+48],xmm0
 mov rdi,r13
 mov rsi,rsp
 mov rdx,rsp
 call aes128_block                      # H = AES_K(0^128)
 mov rax,qword ptr [r12+8]
 mov rdx,qword ptr [rax]
 mov qword ptr [rsp+16],rdx
 mov edx,dword ptr [rax+8]
 mov dword ptr [rsp+24],edx
 mov dword ptr [rsp+28],0x01000000       # J0 = nonce || 0^31 || 1
 mov rdi,r13
 lea rsi,[rsp+16]
 lea rdx,[rsp+32]
 call aes128_block                      # E = AES_K(J0)
 lea rdi,[rsp+48]
 mov rsi,rsp
 mov rdx,qword ptr [r12+16]
 mov rcx,qword ptr [r12+24]
 call .Lghash_bytes                     # authenticate AAD before output mutation
 cmp qword ptr [rsp+96],0
 jne .Lgcm_ciphertext_hash
 mov rdi,r13
 lea rsi,[rsp+16]
 mov rdx,r14
 mov rcx,r15
 mov r8,rbx
 call .Lgcm_ctr
.Lgcm_ciphertext_hash:
 mov rdx,r15
 cmp qword ptr [rsp+96],0
 cmovne rdx,r14                        # encrypt hashes output; decrypt hashes input
 lea rdi,[rsp+48]
 mov rsi,rsp
 mov rcx,rbx
 call .Lghash_bytes
 mov rax,qword ptr [r12+24]
 shl rax,3
 bswap rax
 mov qword ptr [rsp+80],rax
 mov rax,rbx
 shl rax,3
 bswap rax
 mov qword ptr [rsp+88],rax
 lea rdi,[rsp+48]
 mov rsi,rsp
 lea rdx,[rsp+80]
 mov ecx,16
 call .Lghash_bytes
 movdqu xmm0,xmmword ptr [rsp+48]
 movdqu xmm1,xmmword ptr [rsp+32]
 pxor xmm0,xmm1
 movdqu xmmword ptr [rsp+48],xmm0
 mov rcx,qword ptr [r12+56]
 cmp qword ptr [rsp+96],0
 jne .Lgcm_verify
 movdqu xmmword ptr [rcx],xmm0
 xor eax,eax
 jmp .Lgcm_return
.Lgcm_verify:
 mov rax,qword ptr [rsp+48]
 xor rax,qword ptr [rcx]
 mov rdx,qword ptr [rsp+56]
 xor rdx,qword ptr [rcx+8]
 or rax,rdx                           # always compare all128 tag bits
 jnz .Lgcm_auth_failed
 mov rdi,r13
 lea rsi,[rsp+16]
 mov rdx,r14
 mov rcx,r15
 mov r8,rbx
 call .Lgcm_ctr                        # only authenticated ciphertext reaches output
 xor eax,eax
 jmp .Lgcm_return
.Lgcm_auth_failed:
 mov rax,-1
 jmp .Lgcm_return
.Lgcm_invalid:
 mov rax,-22
.Lgcm_return:
 # Erase stack-resident H, masks, counters, hashes and intermediate streams.
 pxor xmm0,xmm0
 pxor xmm1,xmm1
 movdqu xmmword ptr [rsp],xmm0
 movdqu xmmword ptr [rsp+16],xmm0
 movdqu xmmword ptr [rsp+32],xmm0
 movdqu xmmword ptr [rsp+48],xmm0
 movdqu xmmword ptr [rsp+64],xmm0
 movdqu xmmword ptr [rsp+80],xmm0
 movdqu xmmword ptr [rsp+96],xmm0
 mov qword ptr [rsp+112],0
 xor ecx,ecx
 xor edx,edx
 xor esi,esi
 xor edi,edi
 xor r8d,r8d
 xor r9d,r9d
 xor r10d,r10d
 xor r11d,r11d
 add rsp,120
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.section .note.GNU-stack,"",@progbits
