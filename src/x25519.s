# RFC 7748 X25519, native x86-64 application implementation.
# Field arithmetic uses sixteen signed 16-bit radix limbs in 64-bit slots.
# Every scalar follows the same 255-step ladder and fixed field-operation loops.
# Scalar bits select swap masks, never instruction routes or memory addresses.
# No imported routines, allocations, shared writable state, or CPU extensions.
.include "abi.inc"
.intel_syntax noprefix
.text
.equ X_SCALAR,0
.equ X_X,32
.equ X_A,160
.equ X_B,288
.equ X_C,416
.equ X_D,544
.equ X_E,672
.equ X_F,800
.equ X_BIT,928
.equ X_INDEX,936
.equ X_OUT,944
.equ X_FRAME,952

.macro X_ADD out,a,b
    lea rdi,[r12+\out]
    lea rsi,[r12+\a]
    lea rdx,[r12+\b]
    call .Lx_add
.endm
.macro X_SUB out,a,b
    lea rdi,[r12+\out]
    lea rsi,[r12+\a]
    lea rdx,[r12+\b]
    call .Lx_sub
.endm
.macro X_MUL out,a,b
    lea rdi,[r12+\out]
    lea rsi,[r12+\a]
    lea rdx,[r12+\b]
    call .Lx_mul
.endm
.macro X_SQUARE out,a
    lea rdi,[r12+\out]
    lea rsi,[r12+\a]
    call .Lx_square
.endm
.macro X_SWAP a,b
    lea rdi,[r12+\a]
    lea rsi,[r12+\b]
    mov rdx,[r12+X_BIT]
    call .Lx_swap
.endm

.globl x25519
.type x25519,@function
# x25519(scalar32, peer_u32, output32) -> 0, or -1 for all-zero shared output.
# Exact output alias with either input is supported; inputs otherwise unchanged.
x25519:
    test rdi,rdi
    jz .Lx_bad_pointer
    test rsi,rsi
    jz .Lx_bad_pointer
    test rdx,rdx
    jz .Lx_bad_pointer
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,X_FRAME
    mov r12,rsp
    mov [r12+X_OUT],rdx
    .set .Lsc,0
    .rept 4
    mov rax,[rdi+.Lsc]
    mov [r12+X_SCALAR+.Lsc],rax
    .set .Lsc,.Lsc+8
    .endr
    and byte ptr [r12+X_SCALAR],248
    and byte ptr [r12+X_SCALAR+31],127
    or byte ptr [r12+X_SCALAR+31],64
    lea rdi,[r12+X_X]
    call .Lx_unpack
    lea rdi,[r12+X_A]
    xor eax,eax
    mov ecx,96
    rep stosq
    mov qword ptr [r12+X_A],1
    mov qword ptr [r12+X_D],1
    lea rdi,[r12+X_B]
    lea rsi,[r12+X_X]
    mov ecx,16
    rep movsq
    mov qword ptr [r12+X_INDEX],254
.Lx_ladder:
    mov rax,[r12+X_INDEX]
    mov ecx,eax
    and ecx,7
    shr rax,3
    movzx edx,byte ptr [r12+rax]
    shr edx,cl
    and edx,1
    mov [r12+X_BIT],rdx
    X_SWAP X_A,X_B
    X_SWAP X_C,X_D
    X_ADD X_E,X_A,X_C
    X_SUB X_A,X_A,X_C
    X_ADD X_C,X_B,X_D
    X_SUB X_B,X_B,X_D
    X_SQUARE X_D,X_E
    X_SQUARE X_F,X_A
    X_MUL X_A,X_C,X_A
    X_MUL X_C,X_B,X_E
    X_ADD X_E,X_A,X_C
    X_SUB X_A,X_A,X_C
    X_SQUARE X_B,X_A
    X_SUB X_C,X_D,X_F
    lea rdi,[r12+X_A]
    lea rsi,[r12+X_C]
    lea rdx,[rip+.Lx_121665]
    call .Lx_mul
    X_ADD X_A,X_A,X_D
    X_MUL X_C,X_C,X_A
    X_MUL X_A,X_D,X_F
    X_MUL X_D,X_B,X_X
    X_SQUARE X_B,X_E
    X_SWAP X_A,X_B
    X_SWAP X_C,X_D
    dec qword ptr [r12+X_INDEX]
    jns .Lx_ladder
    lea rdi,[r12+X_C]
    mov rsi,rdi
    call .Lx_inverse
    X_MUL X_A,X_A,X_C
    mov rdi,[r12+X_OUT]
    lea rsi,[r12+X_A]
    call .Lx_pack
    mov rdi,[r12+X_OUT]
    mov rax,[rdi]
    or rax,[rdi+8]
    or rax,[rdi+16]
    or rax,[rdi+24]
    test rax,rax
    sete r11b
    movzx r11d,r11b
    neg r11
    # The caller's output survives; private scalar and field scratch do not.
    mov rdi,r12
    mov ecx,X_FRAME/8
    xor eax,eax
    rep stosq
    mov rax,r11
    add rsp,X_FRAME
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
.Lx_bad_pointer:
    mov rax,-1
    ret
.size x25519,.-x25519

# Fixed-width field input. RFC 7748 requires ignoring bit 255, including on
# noncanonical peer encodings; subsequent field operations reduce modulo p.
.Lx_unpack:
    xor ecx,ecx
.Lx_unpack_loop:
    movzx eax,word ptr [rsi+rcx*2]
    mov [rdi+rcx*8],rax
    inc ecx
    cmp ecx,16
    jb .Lx_unpack_loop
    and qword ptr [rdi+120],0x7fff
    ret
.Lx_add:
    xor ecx,ecx
.Lx_add_loop:
    mov rax,[rsi+rcx*8]
    add rax,[rdx+rcx*8]
    mov [rdi+rcx*8],rax
    inc ecx
    cmp ecx,16
    jb .Lx_add_loop
    ret
.Lx_sub:
    xor ecx,ecx
.Lx_sub_loop:
    mov rax,[rsi+rcx*8]
    sub rax,[rdx+rcx*8]
    mov [rdi+rcx*8],rax
    inc ecx
    cmp ecx,16
    jb .Lx_sub_loop
    ret

# Masked swap has no secret-dependent routes or addresses.
.Lx_swap:
    neg rdx
    xor ecx,ecx
.Lx_swap_loop:
    mov rax,[rdi+rcx*8]
    mov r8,[rsi+rcx*8]
    xor rax,r8
    and rax,rdx
    xor [rdi+rcx*8],rax
    xor [rsi+rcx*8],rax
    inc ecx
    cmp ecx,16
    jb .Lx_swap_loop
    ret

# One carry pass. The fifteenth carry folds into limb zero with 2^256 == 38.
# Bias preserves the radix carry for negative subtraction intermediates.
.Lx_carry:
    xor ecx,ecx
.Lx_carry_loop:
    mov rax,[rdi+rcx*8]
    add rax,65536
    mov rdx,rax
    sar rdx,16
    mov r8,rdx
    shl r8,16
    sub rax,r8
    mov [rdi+rcx*8],rax
    dec rdx
    add [rdi+rcx*8+8],rdx
    inc ecx
    cmp ecx,15
    jb .Lx_carry_loop
    mov rax,[rdi+120]
    add rax,65536
    mov rdx,rax
    sar rdx,16
    mov r8,rdx
    shl r8,16
    sub rax,r8
    mov [rdi+120],rax
    dec rdx
    imul rdx,rdx,38
    add [rdi],rdx
    ret

.Lx_square:
    mov rdx,rsi
    jmp .Lx_mul

# Schoolbook field multiplication: 16x16 products, 32 fixed accumulator limbs.
# Inputs are bounded radix limbs from the ladder; signed 64-bit accumulators
# have ample headroom. Exact output/input alias is safe: stores follow all reads.
.Lx_mul:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,264
    mov r12,rsi
    mov r13,rdx
    mov r14,rdi
    mov r15,rsp
    mov rdi,rsp
    xor eax,eax
    mov ecx,32
    rep stosq
    xor r8d,r8d
.Lx_mul_outer:
    xor r9d,r9d
.Lx_mul_inner:
    mov rax,[r12+r8*8]
    imul rax,[r13+r9*8]
    lea r10,[r8+r9]
    add [r15+r10*8],rax
    inc r9d
    cmp r9d,16
    jb .Lx_mul_inner
    inc r8d
    cmp r8d,16
    jb .Lx_mul_outer
    xor ecx,ecx
.Lx_mul_fold:
    mov rax,[r15+rcx*8+128]
    imul rax,rax,38
    add [r15+rcx*8],rax
    inc ecx
    cmp ecx,16
    jb .Lx_mul_fold
    mov rdi,r14
    mov rsi,r15
    mov ecx,16
    rep movsq
    mov rdi,r14
    call .Lx_carry
    mov rdi,r14
    call .Lx_carry
    mov rdi,rsp
    mov ecx,33
    xor eax,eax
    rep stosq
    add rsp,264
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

# Inversion exponent p-2 = 2^255-21. The two skipped multiply positions are
# public exponent bits; every input follows exactly these same 254 rounds.
.Lx_inverse:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,280
    mov r12,rsp
    lea r13,[rsp+128]
    mov r14,rdi
    xor ecx,ecx
.Lx_inverse_copy:
    mov rax,[rsi+rcx*8]
    mov [r12+rcx*8],rax
    mov [r13+rcx*8],rax
    inc ecx
    cmp ecx,16
    jb .Lx_inverse_copy
    mov r15d,253
.Lx_inverse_loop:
    mov rdi,r12
    mov rsi,r12
    call .Lx_square
    cmp r15d,2
    je .Lx_inverse_skip
    cmp r15d,4
    je .Lx_inverse_skip
    mov rdi,r12
    mov rsi,r12
    mov rdx,r13
    call .Lx_mul
.Lx_inverse_skip:
    dec r15d
    jns .Lx_inverse_loop
    mov rdi,r14
    mov rsi,r12
    mov ecx,16
    rep movsq
    mov rdi,rsp
    mov ecx,35
    xor eax,eax
    rep stosq
    add rsp,280
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

# Canonical packing: three carries then two masked trial subtractions of p.
.Lx_pack:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,280
    mov r12,rsp
    lea r13,[rsp+128]
    mov r14,rdi
    mov rdi,r12
    mov ecx,16
    rep movsq
    mov rdi,r12
    call .Lx_carry
    mov rdi,r12
    call .Lx_carry
    mov rdi,r12
    call .Lx_carry
    mov r15d,2
.Lx_pack_reduce:
    mov rax,[r12]
    sub rax,0xffed
    mov [r13],rax
    mov ecx,1
.Lx_pack_borrow:
    mov rax,[r13+rcx*8-8]
    sar rax,16
    and eax,1
    mov rdx,[r12+rcx*8]
    sub rdx,0xffff
    sub rdx,rax
    mov [r13+rcx*8],rdx
    and qword ptr [r13+rcx*8-8],0xffff
    inc ecx
    cmp ecx,15
    jb .Lx_pack_borrow
    mov rax,[r13+112]
    sar rax,16
    and eax,1
    mov rdx,[r12+120]
    sub rdx,0x7fff
    sub rdx,rax
    mov [r13+120],rdx
    and qword ptr [r13+112],0xffff
    sar rdx,16
    and edx,1
    xor edx,1
    mov rdi,r12
    mov rsi,r13
    call .Lx_swap
    dec r15d
    jnz .Lx_pack_reduce
    xor ecx,ecx
.Lx_pack_bytes:
    mov rax,[r12+rcx*8]
    mov word ptr [r14+rcx*2],ax
    inc ecx
    cmp ecx,16
    jb .Lx_pack_bytes
    mov rdi,rsp
    mov ecx,35
    xor eax,eax
    rep stosq
    add rsp,280
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

.section .rodata
.Lx_121665:
    .quad 0xdb41,1
    .zero 112
.section .note.GNU-stack,"",@progbits
