# [open integration] Bounded RSA/SHA256 X.509 validation profile.
# Not a general PKIX implementation: exact DER DN matching, SAN-only identity,
# 2048..4096-bit RSA/65537,96-bit TLSGCM unrelated. Unsupported critical
# extensions and unsupported signed-link algorithms fail closed.
.intel_syntax noprefix
.equ XR_SIZE,224
.equ CA_CAP,0x400000
.equ CA_MAP,0x411000
.section .rodata
.Lxo_sha256rsa: .byte 0x2a,0x86,0x48,0x86,0xf7,0x0d,1,1,11
.Lxo_rsa: .byte 0x2a,0x86,0x48,0x86,0xf7,0x0d,1,1,1
.Lxo_serverauth: .byte 0x2b,6,1,5,5,7,3,1
.Lxo_anyeku: .byte 0x55,0x1d,0x25,0
.Lx_ca_default: .asciz "/etc/ssl/certs/ca-certificates.crt"
.Lx_pem_begin: .ascii "-----BEGIN CERTIFICATE-----"
.Lx_pem_end: .ascii "-----END CERTIFICATE-----"
.balign 4
.Lx_month_days: .byte 31,28,31,30,31,30,31,31,30,31,30,31
.Lx_month_before: .long 0,31,59,90,120,151,181,212,243,273,304,334
.Lx_base64:
.set xc,0
.rept 256
 .if xc>=65 && xc<=90
  .byte xc-65
 .elseif xc>=97 && xc<=122
  .byte xc-97+26
 .elseif xc>=48 && xc<=57
  .byte xc-48+52
 .elseif xc==43
  .byte 62
 .elseif xc==47
  .byte 63
 .elseif xc==9 || xc==10 || xc==13 || xc==32
  .byte 64
 .elseif xc==61
  .byte 65
 .else
  .byte 255
 .endif
 .set xc,xc+1
.endr
.section .text
# DER cursor/end -> next or0; edx tag,rcx value,r8 len,r9 fullptr,r10 fulllen.
.Lxd_next:
 mov r9,rdi
 mov rax,rsi
 sub rax,rdi
 jc .Lxd_bad
 cmp rax,2
 jb .Lxd_bad
 movzx edx,byte ptr [rdi]
 mov eax,edx
 and eax,31
 cmp eax,31
 je .Lxd_bad
 movzx eax,byte ptr [rdi+1]
 lea rcx,[rdi+2]
 mov r8,rax
 cmp eax,128
 jb .Lxd_bound
 and eax,127
 jz .Lxd_bad
 cmp eax,4
 ja .Lxd_bad
 mov r11d,eax
 mov rax,rsi
 sub rax,rcx
 cmp rax,r11
 jb .Lxd_bad
 cmp byte ptr [rcx],0
 je .Lxd_bad
 xor r8d,r8d
.Lxd_length:
 movzx eax,byte ptr [rcx]
 shl r8,8
 add r8,rax
 inc rcx
 dec r11d
 jnz .Lxd_length
 cmp r8,128
 jb .Lxd_bad
.Lxd_bound:
 mov rax,rcx
 add rax,r8
 jc .Lxd_bad
 cmp rax,rsi
 ja .Lxd_bad
 mov r10,rax
 sub r10,r9
 ret
.Lxd_bad:
 xor eax,eax
 ret
.Lx_equal:
 xor eax,eax
 test rdx,rdx
 jz .Lxe_yes
.Lxe_loop:
 mov cl,byte ptr [rdi+rax]
 cmp cl,byte ptr [rsi+rax]
 jne .Lxe_no
 inc rax
 cmp rax,rdx
 jb .Lxe_loop
.Lxe_yes:
 mov eax,1
 ret
.Lxe_no:
 xor eax,eax
 ret
# AlgorithmIdentifier content/len, expectedOID/len ->1 match,0 other,-1 bad.
.Lx_algorithm:
 push rbx
 push r12
 push r13
 sub rsp,16
 mov r12,rdx
 mov r13,rcx
 lea rbx,[rdi+rsi]
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxa_bad
 cmp edx,6
 jne .Lxa_bad
 test r8,r8
 jz .Lxa_bad
 cmp r8,32
 ja .Lxa_bad
 mov qword ptr [rsp],rax
 mov qword ptr [rsp+8],0
 cmp r8,r13
 jne .Lxa_params
 mov rdi,rcx
 mov rsi,r12
 mov rdx,r13
 call .Lx_equal
 mov qword ptr [rsp+8],rax
.Lxa_params:
 mov rdi,qword ptr [rsp]
 cmp rdi,rbx
 je .Lxa_done
 mov rsi,rbx
 call .Lxd_next
 cmp rax,rbx
 jne .Lxa_bad
 cmp edx,5
 jne .Lxa_bad
 test r8,r8
 jnz .Lxa_bad
.Lxa_done:
 mov rax,qword ptr [rsp+8]
 jmp .Lxa_return
.Lxa_bad:
 mov rax,-1
.Lxa_return:
 add rsp,16
 pop r13
 pop r12
 pop rbx
 ret

# Parse two ASCII digits at rdi; eax value,CF error.
.Lx_dec2:
 movzx eax,byte ptr [rdi]
 sub eax,48
 cmp eax,9
 ja .Lxdec_bad
 movzx edx,byte ptr [rdi+1]
 sub edx,48
 cmp edx,9
 ja .Lxdec_bad
 imul eax,eax,10
 add eax,edx
 clc
 ret
.Lxdec_bad:
 stc
 ret
# Fixed UTC time: rdi value,rsi len,edx tag23/24 -> epochrax,CF error.
.Lx_time:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,32
 mov r12,rdi
 cmp edx,23
 je .Lxt_utc
 cmp edx,24
 jne .Lxt_bad
 cmp rsi,15
 jne .Lxt_bad
 cmp byte ptr [rdi+14],90
 jne .Lxt_bad
 call .Lx_dec2
 jc .Lxt_bad
 imul r13d,eax,100
 lea rdi,[r12+2]
 call .Lx_dec2
 jc .Lxt_bad
 add r13d,eax
 add r12,4
 jmp .Lxt_year
.Lxt_utc:
 cmp rsi,13
 jne .Lxt_bad
 cmp byte ptr [rdi+12],90
 jne .Lxt_bad
 call .Lx_dec2
 jc .Lxt_bad
 mov r13d,1900
 mov edx,2000
 cmp eax,50
 cmovb r13d,edx
 add r13d,eax
 add r12,2
.Lxt_year:
 cmp r13d,1950
 jb .Lxt_bad
 cmp r13d,9999
 ja .Lxt_bad
 xor ebx,ebx
.Lxt_parts:
 lea rdi,[r12+rbx*2]
 call .Lx_dec2
 jc .Lxt_bad
 mov dword ptr [rsp+rbx*4],eax
 inc ebx
 cmp ebx,5
 jb .Lxt_parts
 mov r14d,dword ptr [rsp]
 dec r14d
 cmp r14d,11
 ja .Lxt_bad
 mov eax,dword ptr [rsp+8]
 cmp eax,23
 ja .Lxt_bad
 cmp dword ptr [rsp+12],59
 ja .Lxt_bad
 cmp dword ptr [rsp+16],59
 ja .Lxt_bad
 # Leap year is a public calendar value, independent of certificate secrets.
 xor r15d,r15d
 mov eax,r13d
 xor edx,edx
 mov ecx,4
 div ecx
 test edx,edx
 jnz .Lxt_leap_known
 mov r15d,1
 mov eax,r13d
 xor edx,edx
 mov ecx,100
 div ecx
 test edx,edx
 jnz .Lxt_leap_known
 xor r15d,r15d
 mov eax,r13d
 xor edx,edx
 mov ecx,400
 div ecx
 test edx,edx
 sete r15b
.Lxt_leap_known:
 lea rdx,[rip+.Lx_month_days]
 movzx eax,byte ptr [rdx+r14]
 xor edx,edx
 cmp r14d,1
 cmove edx,r15d
 add eax,edx
 mov ebx,dword ptr [rsp+4]
 test ebx,ebx
 jz .Lxt_bad
 cmp ebx,eax
 ja .Lxt_bad
 mov eax,r13d
 sub eax,1970
 imul eax,eax,365
 movsxd rbx,eax
 lea eax,[r13-1]
 xor edx,edx
 mov ecx,4
 div ecx
 add rbx,rax
 lea eax,[r13-1]
 xor edx,edx
 mov ecx,100
 div ecx
 sub rbx,rax
 lea eax,[r13-1]
 xor edx,edx
 mov ecx,400
 div ecx
 add rbx,rax
 sub rbx,477
 lea rdx,[rip+.Lx_month_before]
 mov eax,dword ptr [rdx+r14*4]
 add rbx,rax
 xor eax,eax
 cmp r14d,1
 cmova eax,r15d
 add rbx,rax
 mov eax,dword ptr [rsp+4]
 dec eax
 add rbx,rax
 imul rax,rbx,86400
 mov edx,dword ptr [rsp+8]
 imul rdx,rdx,3600
 add rax,rdx
 mov edx,dword ptr [rsp+12]
 imul rdx,rdx,60
 add rax,rdx
 mov edx,dword ptr [rsp+16]
 add rax,rdx
 add rsp,32
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 clc
 ret
.Lxt_bad:
 add rsp,32
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 stc
 ret

# SPKI sequence content,len,record ->0/-1.
.Lx_spki:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdx
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxs_bad
 cmp edx,48
 jne .Lxs_bad
 mov r14,rax
 mov rdi,rcx
 mov rsi,r8
 lea rdx,[rip+.Lxo_rsa]
 mov ecx,9
 call .Lx_algorithm
 cmp rax,1
 jne .Lxs_bad
 mov rdi,r14
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxs_bad
 cmp edx,3
 jne .Lxs_bad
 cmp r8,2
 jb .Lxs_bad
 cmp byte ptr [rcx],0
 jne .Lxs_bad
 lea rdi,[rcx+1]
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxs_bad
 cmp edx,48
 jne .Lxs_bad
 mov rdi,rcx
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxs_bad
 cmp edx,2
 jne .Lxs_bad
 mov r14,rax
 cmp r8,257
 jb .Lxs_bad
 cmp r8,513
 ja .Lxs_bad
 cmp byte ptr [rcx],0
 jne .Lxs_bad
 inc rcx
 dec r8
 test r8,3
 jnz .Lxs_bad
 test byte ptr [rcx],128
 jz .Lxs_bad
 test byte ptr [rcx+r8-1],1
 jz .Lxs_bad
 mov qword ptr [r12+64],rcx
 mov qword ptr [r12+72],r8
 mov qword ptr [r12+80],65537
 mov rdi,r14
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxs_bad
 cmp edx,2
 jne .Lxs_bad
 cmp r8,3
 jne .Lxs_bad
 cmp byte ptr [rcx],1
 jne .Lxs_bad
 cmp byte ptr [rcx+1],0
 jne .Lxs_bad
 cmp byte ptr [rcx+2],1
 jne .Lxs_bad
 xor eax,eax
 jmp .Lxs_return
.Lxs_bad:
 mov rax,-1
.Lxs_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.globl x509_parse
.type x509_parse,@function
# DER,len,out224. All referenced DER remains owned by the caller.
x509_parse:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,104
 mov r12,rdx
 test r12,r12
 jz .Lxp_bad_nozero
 mov r13,rdi
 mov rbx,rsi
 mov rdi,r12
 xor eax,eax
 mov ecx,28
 rep stosq
 mov qword ptr [r12+152],-1
 test r13,r13
 jz .Lxp_bad
 test rbx,rbx
 jz .Lxp_bad
 cmp rbx,65536
 ja .Lxp_bad
 mov r14,r13
 add r14,rbx
 jc .Lxp_bad
 mov qword ptr [r12],r13
 mov qword ptr [r12+8],rbx
 mov rdi,r13
 mov rsi,r14
 xor edx,edx
 call .Lx_der_valid
 test rax,rax
 jz .Lxp_bad
 mov rdi,r13
 mov rsi,r14
 call .Lxd_next
 cmp rax,r14
 jne .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rcx
 mov rdi,r15
 mov rsi,r14
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov qword ptr [r12+16],r9
 mov qword ptr [r12+24],r10
 mov qword ptr [rsp],rcx
 mov rbx,rax
 mov r15,rax
 mov rdi,r15
 mov rsi,r14
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rax
 mov qword ptr [rsp+8],r9
 mov qword ptr [rsp+16],r10
 mov rdi,rcx
 mov rsi,r8
 lea rdx,[rip+.Lxo_sha256rsa]
 mov ecx,9
 call .Lx_algorithm
 test rax,rax
 js .Lxp_bad
 mov qword ptr [r12+104],rax
 mov rdi,r15
 mov rsi,r14
 call .Lxd_next
 cmp rax,r14
 jne .Lxp_bad
 cmp edx,3
 jne .Lxp_bad
 cmp r8,129
 jb .Lxp_bad
 cmp r8,513
 ja .Lxp_bad
 cmp byte ptr [rcx],0
 jne .Lxp_bad
 inc rcx
 dec r8
 mov qword ptr [r12+88],rcx
 mov qword ptr [r12+96],r8
 mov r15,qword ptr [rsp]
 mov qword ptr [rsp+48],0
 cmp byte ptr [r15],160
 jne .Lxp_serial
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 mov r15,rax
 mov rdi,rcx
 mov rsi,rax
 call .Lxd_next
 cmp rax,r15
 jne .Lxp_bad
 cmp edx,2
 jne .Lxp_bad
 cmp r8,1
 jne .Lxp_bad
 cmp byte ptr [rcx],2
 jne .Lxp_bad
 mov qword ptr [rsp+48],2
.Lxp_serial:
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,2
 jne .Lxp_bad
 test r8,r8
 jz .Lxp_bad
 cmp r8,21
 ja .Lxp_bad
 test byte ptr [rcx],128
 jnz .Lxp_bad
 cmp byte ptr [rcx],0
 jne .Lxp_serial_good
 cmp r8,1
 je .Lxp_bad
 test byte ptr [rcx+1],128
 jz .Lxp_bad
.Lxp_serial_good:
 mov r15,rax
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rax
 cmp r10,qword ptr [rsp+16]
 jne .Lxp_bad
 mov rdi,r9
 mov rsi,qword ptr [rsp+8]
 mov rdx,r10
 call .Lx_equal
 test rax,rax
 jz .Lxp_bad
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rax
 mov qword ptr [r12+32],r9
 mov qword ptr [r12+40],r10
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rax
 mov qword ptr [rsp+24],rax
 mov rdi,rcx
 mov rsi,rax
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 mov qword ptr [rsp+32],rax
 mov rdi,rcx
 mov rsi,r8
 call .Lx_time
 jc .Lxp_bad
 mov qword ptr [r12+112],rax
 mov rdi,qword ptr [rsp+32]
 mov rsi,qword ptr [rsp+24]
 call .Lxd_next
 cmp rax,qword ptr [rsp+24]
 jne .Lxp_bad
 mov rdi,rcx
 mov rsi,r8
 call .Lx_time
 jc .Lxp_bad
 mov qword ptr [r12+120],rax
 cmp rax,qword ptr [r12+112]
 jl .Lxp_bad
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rax
 mov qword ptr [r12+48],r9
 mov qword ptr [r12+56],r10
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 test rax,rax
 jz .Lxp_bad
 cmp edx,48
 jne .Lxp_bad
 mov r15,rax
 mov qword ptr [r12+176],r9
 mov qword ptr [r12+184],r10
 mov rdi,rcx
 mov rsi,r8
 mov rdx,r12
 call .Lx_spki
 test rax,rax
 jnz .Lxp_bad
 cmp r15,rbx
 je .Lxp_ok
 cmp qword ptr [rsp+48],2
 jne .Lxp_bad
 mov rdi,r15
 mov rsi,rbx
 call .Lxd_next
 cmp rax,rbx
 jne .Lxp_bad
 cmp edx,163
 jne .Lxp_bad
 mov rdi,rcx
 mov rsi,r8
 mov rdx,r12
 call .Lx_extensions
 test rax,rax
 jnz .Lxp_bad
.Lxp_ok:
 xor eax,eax
 jmp .Lxp_return
.Lxp_bad:
 mov rdi,r12
 xor eax,eax
 mov ecx,28
 rep stosq
.Lxp_bad_nozero:
 mov rax,-22
.Lxp_return:
 add rsp,104
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.size x509_parse,.-x509_parse

# BasicConstraints OCTET contents,len,record ->0/-1.
.Lx_basic:
 push rbx
 push r12
 push r13
 mov r12,rdx
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxb_bad
 cmp edx,48
 jne .Lxb_bad
 mov rbx,rcx
 cmp rbx,r13
 je .Lxb_ok
 cmp byte ptr [rbx],1
 jne .Lxb_path
 mov rdi,rbx
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxb_bad
 cmp r8,1
 jne .Lxb_bad
 cmp byte ptr [rcx],255
 jne .Lxb_bad
 mov qword ptr [r12+144],1
 mov rbx,rax
.Lxb_path:
 cmp rbx,r13
 je .Lxb_ok
 cmp qword ptr [r12+144],1
 jne .Lxb_bad
 mov rdi,rbx
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxb_bad
 cmp edx,2
 jne .Lxb_bad
 cmp r8,1
 jne .Lxb_bad
 test byte ptr [rcx],128
 jnz .Lxb_bad
 movzx eax,byte ptr [rcx]
 mov qword ptr [r12+152],rax
.Lxb_ok:
 xor eax,eax
 jmp .Lxb_return
.Lxb_bad:
 mov rax,-1
.Lxb_return:
 pop r13
 pop r12
 pop rbx
 ret

.Lx_usage:
 push rbx
 push r12
 push r13
 mov r12,rdx
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxu_bad
 cmp edx,3
 jne .Lxu_bad
 cmp r8,2
 jb .Lxu_bad
 cmp r8,3
 ja .Lxu_bad
 movzx ebx,byte ptr [rcx]
 cmp ebx,7
 ja .Lxu_bad
 movzx eax,byte ptr [rcx+1]
 cmp r8,3
 je .Lxu_ninth
 test eax,eax
 jz .Lxu_bad
 bsf edx,eax
 cmp edx,ebx
 jne .Lxu_bad
 jmp .Lxu_save
.Lxu_ninth:
 cmp ebx,7
 jne .Lxu_bad
 cmp byte ptr [rcx+2],128
 jne .Lxu_bad
 test eax,8
 jz .Lxu_bad
 add eax,32768
.Lxu_save:
 mov qword ptr [r12+160],rax
 xor eax,eax
 jmp .Lxu_return
.Lxu_bad:
 mov rax,-1
.Lxu_return:
 pop r13
 pop r12
 pop rbx
 ret

.Lx_san:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdx
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxsan_bad
 cmp edx,48
 jne .Lxsan_bad
 test r8,r8
 jz .Lxsan_bad
 mov qword ptr [r12+128],rcx
 mov qword ptr [r12+136],r8
 mov r14,rcx
.Lxsan_entry:
 cmp r14,r13
 je .Lxsan_ok
 mov rdi,r14
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxsan_bad
 mov r14,rax
 cmp edx,130
 je .Lxsan_dns
 cmp edx,135
 je .Lxsan_ip
 cmp edx,129
 je .Lxsan_ascii
 cmp edx,134
 je .Lxsan_ascii
 cmp edx,160
 je .Lxsan_entry
 cmp edx,163
 je .Lxsan_entry
 cmp edx,164
 je .Lxsan_entry
 cmp edx,165
 je .Lxsan_entry
 cmp edx,136
 je .Lxsan_entry
 jmp .Lxsan_bad
.Lxsan_ip:
 cmp r8,4
 je .Lxsan_entry
 cmp r8,16
 je .Lxsan_entry
 jmp .Lxsan_bad
.Lxsan_dns:
 cmp r8,253
 ja .Lxsan_bad
.Lxsan_ascii:
 test r8,r8
 jz .Lxsan_bad
 xor eax,eax
.Lxsan_char:
 movzx edx,byte ptr [rcx+rax]
 cmp edx,33
 jb .Lxsan_bad
 cmp edx,126
 ja .Lxsan_bad
 inc rax
 cmp rax,r8
 jb .Lxsan_char
 jmp .Lxsan_entry
.Lxsan_ok:
 xor eax,eax
 jmp .Lxsan_return
.Lxsan_bad:
 mov rax,-1
.Lxsan_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.Lx_eku:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdx
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxeku_bad
 cmp edx,48
 jne .Lxeku_bad
 test r8,r8
 jz .Lxeku_bad
 mov r14,rcx
.Lxeku_entry:
 cmp r14,r13
 je .Lxeku_ok
 mov rdi,r14
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxeku_bad
 cmp edx,6
 jne .Lxeku_bad
 test r8,r8
 jz .Lxeku_bad
 mov r14,rax
 cmp r8,8
 je .Lxeku_server
 cmp r8,4
 jne .Lxeku_entry
 mov rdi,rcx
 lea rsi,[rip+.Lxo_anyeku]
 mov edx,4
 call .Lx_equal
 test rax,rax
 jz .Lxeku_entry
 or qword ptr [r12+168],2
 jmp .Lxeku_entry
.Lxeku_server:
 mov rdi,rcx
 lea rsi,[rip+.Lxo_serverauth]
 mov edx,8
 call .Lx_equal
 test rax,rax
 jz .Lxeku_entry
 or qword ptr [r12+168],1
 jmp .Lxeku_entry
.Lxeku_ok:
 xor eax,eax
 jmp .Lxeku_return
.Lxeku_bad:
 mov rax,-1
.Lxeku_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Explicit extensions [3] content,len,record. All OID duplicates are rejected.
.Lx_extensions:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,1128
 mov r12,rdx
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .Lxd_next
 cmp rax,r13
 jne .Lxx_bad
 cmp edx,48
 jne .Lxx_bad
 test r8,r8
 jz .Lxx_bad
 mov r14,rcx
 mov qword ptr [rsp],0
.Lxx_entry:
 cmp r14,r13
 je .Lxx_ok
 cmp qword ptr [rsp],64
 jae .Lxx_bad
 mov rdi,r14
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxx_bad
 cmp edx,48
 jne .Lxx_bad
 mov qword ptr [rsp+40],rax
 mov qword ptr [rsp+48],rax
 mov rdi,rcx
 mov rsi,rax
 call .Lxd_next
 test rax,rax
 jz .Lxx_bad
 cmp edx,6
 jne .Lxx_bad
 test r8,r8
 jz .Lxx_bad
 cmp r8,32
 ja .Lxx_bad
 mov qword ptr [rsp+8],rcx
 mov qword ptr [rsp+16],r8
 mov qword ptr [rsp+56],rax
 xor ebp,ebp
.Lxx_duplicate:
 cmp rbp,qword ptr [rsp]
 jae .Lxx_remember
 mov rax,rbp
 shl rax,4
 mov rdx,qword ptr [rsp+16]
 cmp rdx,qword ptr [rsp+rax+72]
 jne .Lxx_duplicate_next
 mov rdi,qword ptr [rsp+8]
 mov rsi,qword ptr [rsp+rax+64]
 call .Lx_equal
 test rax,rax
 jnz .Lxx_bad
.Lxx_duplicate_next:
 inc rbp
 jmp .Lxx_duplicate
.Lxx_remember:
 mov rax,qword ptr [rsp]
 shl rax,4
 mov rcx,qword ptr [rsp+8]
 mov rdx,qword ptr [rsp+16]
 mov qword ptr [rsp+rax+64],rcx
 mov qword ptr [rsp+rax+72],rdx
 inc qword ptr [rsp]
 xor r15d,r15d
 cmp rdx,3
 jne .Lxx_oid_known
 cmp byte ptr [rcx],0x55
 jne .Lxx_oid_known
 cmp byte ptr [rcx+1],0x1d
 jne .Lxx_oid_known
 movzx r15d,byte ptr [rcx+2]
.Lxx_oid_known:
 xor ebx,ebx
 mov rdi,qword ptr [rsp+56]
 cmp rdi,qword ptr [rsp+48]
 jae .Lxx_bad
 cmp byte ptr [rdi],1
 jne .Lxx_octet
 mov rsi,qword ptr [rsp+48]
 call .Lxd_next
 test rax,rax
 jz .Lxx_bad
 cmp r8,1
 jne .Lxx_bad
 cmp byte ptr [rcx],255
 jne .Lxx_bad
 mov ebx,1
 mov rdi,rax
.Lxx_octet:
 mov rsi,qword ptr [rsp+48]
 call .Lxd_next
 cmp rax,qword ptr [rsp+48]
 jne .Lxx_bad
 cmp edx,4
 jne .Lxx_bad
 mov rdi,rcx
 mov rsi,r8
 mov rdx,r12
 cmp r15d,19
 je .Lxx_bc
 cmp r15d,15
 je .Lxx_ku
 cmp r15d,17
 je .Lxx_san
 cmp r15d,37
 je .Lxx_eku
 test ebx,ebx
 jnz .Lxx_bad
 jmp .Lxx_next
.Lxx_bc:
 or qword ptr [r12+192],2
 call .Lx_basic
 jmp .Lxx_check
.Lxx_ku:
 or qword ptr [r12+192],1
 call .Lx_usage
 jmp .Lxx_check
.Lxx_san:
 or qword ptr [r12+192],8
 call .Lx_san
 jmp .Lxx_check
.Lxx_eku:
 or qword ptr [r12+192],4
 call .Lx_eku
.Lxx_check:
 test rax,rax
 jnz .Lxx_bad
.Lxx_next:
 mov r14,qword ptr [rsp+40]
 jmp .Lxx_entry
.Lxx_ok:
 xor eax,eax
 jmp .Lxx_return
.Lxx_bad:
 mov rax,-1
.Lxx_return:
 add rsp,1128
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# Parse canonical dotted IPv4 at rdi,lenrsi ->eax native-byte-order address,CFbad.
.Lx_ipv4:
 xor r8d,r8d
 xor r9d,r9d
 xor r10d,r10d
 xor r11d,r11d
 xor ecx,ecx
.Lxip_char:
 cmp rcx,rsi
 je .Lxip_end
 movzx edx,byte ptr [rdi+rcx]
 cmp edx,46
 je .Lxip_octet
 sub edx,48
 cmp edx,9
 ja .Lxip_bad
 cmp r11d,1
 jne .Lxip_digit
 test r9d,r9d
 jz .Lxip_bad
.Lxip_digit:
 imul r9d,r9d,10
 add r9d,edx
 cmp r9d,255
 ja .Lxip_bad
 inc r11d
 inc rcx
 jmp .Lxip_char
.Lxip_octet:
 cmp r10d,3
 jae .Lxip_bad
 test r11d,r11d
 jz .Lxip_bad
 push rcx
 mov ecx,r10d
 imul ecx,ecx,8
 shl r9d,cl
 or r8d,r9d
 pop rcx
 inc r10d
 xor r9d,r9d
 xor r11d,r11d
 inc rcx
 jmp .Lxip_char
.Lxip_end:
 cmp r10d,3
 jne .Lxip_bad
 test r11d,r11d
 jz .Lxip_bad
 shl r9d,24
 or r8d,r9d
 mov eax,r8d
 clc
 ret
.Lxip_bad:
 stc
 ret

# SAN DNS bytes,len,hostname bytes,len ->1 match/0bad. Only full leftmost wildcard.
.Lx_dns_match:
 cmp rsi,3
 jb .Lxdns_exact
 cmp byte ptr [rdi],42
 jne .Lxdns_exact
 cmp byte ptr [rdi+1],46
 jne .Lxdns_no
 xor eax,eax
.Lxdns_first_dot:
 cmp rax,rcx
 jae .Lxdns_no
 cmp byte ptr [rdx+rax],46
 je .Lxdns_suffix
 inc rax
 jmp .Lxdns_first_dot
.Lxdns_suffix:
 test rax,rax
 jz .Lxdns_no
 add rdx,rax
 sub rcx,rax
 inc rdi
 dec rsi
.Lxdns_exact:
 cmp rsi,rcx
 jne .Lxdns_no
 xor eax,eax
.Lxdns_compare:
 cmp rax,rsi
 jae .Lxdns_yes
 movzx r8d,byte ptr [rdi+rax]
 movzx r9d,byte ptr [rdx+rax]
 or r8d,32
 or r9d,32
 cmp r8d,r9d
 jne .Lxdns_no
 inc rax
 jmp .Lxdns_compare
.Lxdns_yes:
 mov eax,1
 ret
.Lxdns_no:
 xor eax,eax
 ret

# record,reference hostnamez ->0 match/-1. No CN fallback or IP-as-DNS matching.
.Lx_hostname:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,16
 mov rbx,rdi
 mov r12,rsi
 test r12,r12
 jz .Lxh_bad
 xor r13d,r13d
 xor r8d,r8d
 mov r9d,1
.Lxh_validate:
 movzx eax,byte ptr [r12+r13]
 test eax,eax
 jz .Lxh_validated
 cmp r13,253
 jae .Lxh_bad
 cmp eax,46
 je .Lxh_dot
 cmp eax,45
 je .Lxh_hyphen
 mov edx,eax
 sub edx,48
 cmp edx,9
 jbe .Lxh_label_char
 or eax,32
 sub eax,97
 cmp eax,25
 ja .Lxh_bad
 xor r9d,r9d
 jmp .Lxh_label_char
.Lxh_hyphen:
 test r8d,r8d
 jz .Lxh_bad
 xor r9d,r9d
.Lxh_label_char:
 inc r8d
 cmp r8d,63
 ja .Lxh_bad
 inc r13
 jmp .Lxh_validate
.Lxh_dot:
 test r8d,r8d
 jz .Lxh_bad
 cmp byte ptr [r12+r13-1],45
 je .Lxh_bad
 xor r8d,r8d
 inc r13
 jmp .Lxh_validate
.Lxh_validated:
 test r13,r13
 jz .Lxh_bad
 test r8d,r8d
 jz .Lxh_bad
 cmp byte ptr [r12+r13-1],45
 je .Lxh_bad
 mov qword ptr [rsp+8],r9
 test r9,r9
 jz .Lxh_sans
 mov rdi,r12
 mov rsi,r13
 call .Lx_ipv4
 jc .Lxh_bad
 mov dword ptr [rsp],eax
.Lxh_sans:
 mov r14,qword ptr [rbx+128]
 mov r15,qword ptr [rbx+136]
 test r14,r14
 jz .Lxh_bad
 test r15,r15
 jz .Lxh_bad
 add r15,r14
 jc .Lxh_bad
.Lxh_entry:
 cmp r14,r15
 jae .Lxh_bad
 mov rdi,r14
 mov rsi,r15
 call .Lxd_next
 test rax,rax
 jz .Lxh_bad
 mov r14,rax
 cmp qword ptr [rsp+8],0
 jne .Lxh_ip
 cmp edx,130
 jne .Lxh_entry
 mov rdi,rcx
 mov rsi,r8
 mov rdx,r12
 mov rcx,r13
 call .Lx_dns_match
 test rax,rax
 jz .Lxh_entry
 jmp .Lxh_ok
.Lxh_ip:
 cmp edx,135
 jne .Lxh_entry
 cmp r8,4
 jne .Lxh_entry
 mov eax,dword ptr [rcx]
 cmp eax,dword ptr [rsp]
 jne .Lxh_entry
.Lxh_ok:
 xor eax,eax
 jmp .Lxh_return
.Lxh_bad:
 mov rax,-1
.Lxh_return:
 add rsp,16
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# record,epoch,isCA,pathBelow ->0/-1. CA EKU restrictions are also enforced.
.Lx_policy:
 cmp rsi,qword ptr [rdi+112]
 jl .Lxpol_bad
 cmp rsi,qword ptr [rdi+120]
 jg .Lxpol_bad
 test qword ptr [rdi+192],4
 jz .Lxpol_usage
 test qword ptr [rdi+168],3
 jz .Lxpol_bad
.Lxpol_usage:
 test rdx,rdx
 jnz .Lxpol_ca
 test qword ptr [rdi+192],1
 jz .Lxpol_ok
 test qword ptr [rdi+160],128
 jz .Lxpol_bad
 jmp .Lxpol_ok
.Lxpol_ca:
 test qword ptr [rdi+192],2
 jz .Lxpol_bad
 cmp qword ptr [rdi+144],1
 jne .Lxpol_bad
 test qword ptr [rdi+192],1
 jz .Lxpol_path
 test qword ptr [rdi+160],4
 jz .Lxpol_bad
.Lxpol_path:
 mov rax,qword ptr [rdi+152]
 cmp rax,-1
 je .Lxpol_ok
 cmp rcx,rax
 ja .Lxpol_bad
.Lxpol_ok:
 xor eax,eax
 ret
.Lxpol_bad:
 mov rax,-1
 ret

# certificate record,issuer record,digest32scratch ->0/-1.
.Lx_signature:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 cmp qword ptr [r12+104],1
 jne .Lxsig_bad
 mov rdx,qword ptr [r12+40]
 cmp rdx,qword ptr [r13+56]
 jne .Lxsig_bad
 mov rdi,qword ptr [r12+32]
 mov rsi,qword ptr [r13+48]
 call .Lx_equal
 test rax,rax
 jz .Lxsig_bad
 mov rdi,qword ptr [r12+16]
 mov rsi,qword ptr [r12+24]
 mov rdx,r14
 call sha256_hash
 mov rdi,qword ptr [r13+64]
 mov rsi,qword ptr [r13+72]
 mov rdx,qword ptr [r12+88]
 mov rcx,qword ptr [r12+96]
 mov r8,r14
 call rsa_pkcs1_sha256_verify
 cmp rax,1
 jne .Lxsig_bad
 xor eax,eax
 jmp .Lxsig_return
.Lxsig_bad:
 mov rax,-1
.Lxsig_return:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Bounded marker search(ptr,end,marker,len) -> found/0.
.Lx_find:
 mov r8,rdi
.Lxf_position:
 mov rax,rsi
 sub rax,r8
 cmp rax,rcx
 jb .Lxf_missing
 xor r9d,r9d
.Lxf_compare:
 mov al,byte ptr [r8+r9]
 cmp al,byte ptr [rdx+r9]
 jne .Lxf_advance
 inc r9
 cmp r9,rcx
 jb .Lxf_compare
 mov rax,r8
 ret
.Lxf_advance:
 inc r8
 jmp .Lxf_position
.Lxf_missing:
 xor eax,eax
 ret

# PEM(cursor,end,DERout,capacity) -> next cursor, r8 DERlen;0 EOF;-22 malformed.
.Lx_pem:
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
 lea rdx,[rip+.Lx_pem_begin]
 mov ecx,27
 call .Lx_find
 test rax,rax
 jz .Lxpem_return
 lea r12,[rax+27]
 xor ebx,ebx
 xor ebp,ebp
 mov qword ptr [rsp],0
 mov qword ptr [rsp+8],0
.Lxpem_char:
 cmp r12,r13
 jae .Lxpem_bad
 movzx eax,byte ptr [r12]
 cmp eax,45
 je .Lxpem_end
 inc r12
 lea rdx,[rip+.Lx_base64]
 movzx eax,byte ptr [rdx+rax]
 cmp eax,64
 je .Lxpem_char
 cmp eax,65
 je .Lxpem_pad
 cmp eax,63
 ja .Lxpem_bad
 cmp qword ptr [rsp+8],0
 jne .Lxpem_bad
 shl ebx,6
 or ebx,eax
 inc ebp
 cmp ebp,4
 jb .Lxpem_char
 mov rax,qword ptr [rsp]
 lea rdx,[rax+3]
 cmp rdx,r15
 ja .Lxpem_bad
 mov ecx,ebx
 shr ecx,16
 mov byte ptr [r14+rax],cl
 mov ecx,ebx
 shr ecx,8
 mov byte ptr [r14+rax+1],cl
 mov byte ptr [r14+rax+2],bl
 mov qword ptr [rsp],rdx
 xor ebx,ebx
 xor ebp,ebp
 jmp .Lxpem_char
.Lxpem_pad:
 cmp qword ptr [rsp+8],1
 je .Lxpem_second_pad
 cmp qword ptr [rsp+8],0
 jne .Lxpem_bad
 cmp ebp,2
 je .Lxpem_pad_one
 cmp ebp,3
 jne .Lxpem_bad
 test ebx,3
 jnz .Lxpem_bad
 mov rax,qword ptr [rsp]
 lea rdx,[rax+2]
 cmp rdx,r15
 ja .Lxpem_bad
 mov ecx,ebx
 shr ecx,10
 mov byte ptr [r14+rax],cl
 shr ebx,2
 mov byte ptr [r14+rax+1],bl
 mov qword ptr [rsp],rdx
 mov qword ptr [rsp+8],2
 xor ebp,ebp
 jmp .Lxpem_char
.Lxpem_pad_one:
 test ebx,15
 jnz .Lxpem_bad
 mov rax,qword ptr [rsp]
 cmp rax,r15
 jae .Lxpem_bad
 shr ebx,4
 mov byte ptr [r14+rax],bl
 inc qword ptr [rsp]
 mov qword ptr [rsp+8],1
 xor ebp,ebp
 jmp .Lxpem_char
.Lxpem_second_pad:
 mov qword ptr [rsp+8],2
 jmp .Lxpem_char
.Lxpem_end:
 test ebp,ebp
 jnz .Lxpem_bad
 cmp qword ptr [rsp+8],1
 je .Lxpem_bad
 mov rax,r13
 sub rax,r12
 cmp rax,25
 jb .Lxpem_bad
 mov rdi,r12
 lea rsi,[rip+.Lx_pem_end]
 mov edx,25
 call .Lx_equal
 test rax,rax
 jz .Lxpem_bad
 mov r8,qword ptr [rsp]
 test r8,r8
 jz .Lxpem_bad
 lea rax,[r12+25]
 jmp .Lxpem_return
.Lxpem_bad:
 mov rax,-22
.Lxpem_return:
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

.globl x509_verify_chain
.type x509_verify_chain,@function
# records leaf-to-root,count1..8,hostnamez,CAfilez(defaultsystemfile ifnull).
x509_verify_chain:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,184
 mov r12,rdi
 mov r13,rsi
 mov qword ptr [rsp+64],rdx
 mov qword ptr [rsp+80],rsi
 mov qword ptr [rsp+16],-1
 mov qword ptr [rsp],0
 test r12,r12
 jz .Lxv_bad
 test r13,r13
 jz .Lxv_bad
 cmp r13,8
 ja .Lxv_bad
 test rdx,rdx
 jz .Lxv_bad
 lea rax,[rip+.Lx_ca_default]
 test rcx,rcx
 cmovz rcx,rax
 mov qword ptr [rsp+144],rcx
 mov eax,201
 xor edi,edi
 syscall
 test rax,rax
 js .Lxv_bad
 mov qword ptr [rsp+72],rax
 xor ebx,ebx
 mov r14,r12
.Lxv_policy:
 mov rdi,r14
 mov rsi,qword ptr [rsp+72]
 mov rdx,rbx
 lea rcx,[rbx-1]
 xor eax,eax
 test rbx,rbx
 cmovz rcx,rax
 call .Lx_policy
 test rax,rax
 jnz .Lxv_bad
 inc rbx
 add r14,XR_SIZE
 cmp rbx,r13
 jb .Lxv_policy
 lea r14,[r14-XR_SIZE]
 mov qword ptr [rsp+88],r14
 mov rdi,r12
 mov rsi,qword ptr [rsp+64]
 call .Lx_hostname
 test rax,rax
 jnz .Lxv_bad
 mov r14,r12
 mov ebx,1
.Lxv_links:
 cmp rbx,r13
 jae .Lxv_read_ca
 mov rdi,r14
 lea rsi,[r14+XR_SIZE]
 lea rdx,[rsp+104]
 call .Lx_signature
 test rax,rax
 jnz .Lxv_bad
 add r14,XR_SIZE
 inc rbx
 jmp .Lxv_links
.Lxv_read_ca:
 mov eax,9
 xor edi,edi
 mov esi,CA_MAP
 mov edx,3
 mov r10d,34
 mov r8,-1
 xor r9d,r9d
 syscall
 test rax,rax
 js .Lxv_bad
 mov qword ptr [rsp],rax
 mov r15,rax
 lea rax,[r15+CA_CAP]
 mov qword ptr [rsp+48],rax
 lea rax,[r15+CA_CAP+65536]
 mov qword ptr [rsp+56],rax
 mov eax,257
 mov rdi,-100
 mov rsi,qword ptr [rsp+144]
 mov edx,0x80000
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lxv_bad
 mov qword ptr [rsp+16],rax
 xor ebx,ebx
.Lxv_read:
 mov eax,0
 mov rdi,qword ptr [rsp+16]
 lea rsi,[r15+rbx]
 mov edx,CA_CAP
 sub rdx,rbx
 jz .Lxv_ca_too_big
 syscall
 cmp rax,-4
 je .Lxv_read
 test rax,rax
 js .Lxv_bad
 jz .Lxv_ca_loaded
 add rbx,rax
 jmp .Lxv_read
.Lxv_ca_too_big:
 mov eax,0
 mov rdi,qword ptr [rsp+16]
 lea rsi,[rsp+152]
 mov edx,1
 syscall
 cmp rax,-4
 je .Lxv_ca_too_big
 test rax,rax
 jne .Lxv_bad
.Lxv_ca_loaded:
 mov eax,3
 mov rdi,qword ptr [rsp+16]
 syscall
 mov qword ptr [rsp+16],-1
 test rbx,rbx
 jz .Lxv_bad
 lea rax,[r15+rbx]
 mov qword ptr [rsp+32],rax
 mov qword ptr [rsp+40],r15
.Lxv_anchor_next:
 mov rdi,qword ptr [rsp+40]
 mov rsi,qword ptr [rsp+32]
 mov rdx,qword ptr [rsp+48]
 mov ecx,65536
 call .Lx_pem
 test rax,rax
 jle .Lxv_bad
 mov qword ptr [rsp+40],rax
 mov rdi,qword ptr [rsp+48]
 mov rsi,r8
 mov rdx,qword ptr [rsp+56]
 call x509_parse
 test rax,rax
 jnz .Lxv_anchor_next             # unsupported EC/other anchor profiles are skipped
 mov r14,qword ptr [rsp+88]
 mov r15,qword ptr [rsp+56]
 # A trust anchor is an explicitly trusted subject/key, not the wire
 # certificate wrapper. A cross-signed root can have a different issuer,
 # validity or self-signature algorithm while naming the identical trusted
 # CA public key. Match BOTH exact Subject DER and exact SPKI DER; matching
 # a name alone never establishes trust. All child signatures and wire
 # certificate policies were already checked above.
 mov rax,qword ptr [r14+56]
 cmp rax,qword ptr [r15+56]
 jne .Lxv_external_anchor
 mov rdi,qword ptr [r14+48]
 mov rsi,qword ptr [r15+48]
 mov rdx,rax
 call .Lx_equal
 test rax,rax
 jz .Lxv_external_anchor
 mov rax,qword ptr [r14+184]
 cmp rax,qword ptr [r15+184]
 jne .Lxv_external_anchor
 mov rdi,qword ptr [r14+176]
 mov rsi,qword ptr [r15+176]
 mov rdx,rax
 call .Lx_equal
 test rax,rax
 jz .Lxv_external_anchor
 mov rdi,r15
 mov rsi,qword ptr [rsp+72]
 mov edx,1
 mov rcx,qword ptr [rsp+80]
 sub rcx,2
 xor eax,eax
 cmp qword ptr [rsp+80],2
 cmovb rcx,rax
 call .Lx_policy
 test rax,rax
 jnz .Lxv_anchor_next
 jmp .Lxv_success
.Lxv_external_anchor:
 mov rdi,r15
 mov rsi,qword ptr [rsp+72]
 mov edx,1
 mov rcx,qword ptr [rsp+80]
 dec rcx
 call .Lx_policy
 test rax,rax
 jnz .Lxv_anchor_next
 mov rdi,r14
 mov rsi,r15
 lea rdx,[rsp+104]
 call .Lx_signature
 test rax,rax
 jnz .Lxv_anchor_next
.Lxv_success:
 xor ebp,ebp
 jmp .Lxv_cleanup
.Lxv_bad:
 mov rbp,-22
.Lxv_cleanup:
 cmp qword ptr [rsp+16],-1
 je .Lxv_unmap
 mov eax,3
 mov rdi,qword ptr [rsp+16]
 syscall
.Lxv_unmap:
 cmp qword ptr [rsp],0
 je .Lxv_return
 mov eax,11
 mov rdi,qword ptr [rsp]
 mov esi,CA_MAP
 syscall
.Lxv_return:
 mov rax,rbp
 pxor xmm0,xmm0
 movdqu xmmword ptr [rsp+104],xmm0
 movdqu xmmword ptr [rsp+120],xmm0
 add rsp,184
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.size x509_verify_chain,.-x509_verify_chain


# Recursive structural DER validation; constructed depth is bounded16. OCTET
# payloads remain opaque and known extension parsers validate their own syntax.
.Lx_der_valid:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 cmp r14,16
 ja .Lxdv_bad
.Lxdv_next:
 cmp r12,r13
 je .Lxdv_good
 mov rdi,r12
 mov rsi,r13
 call .Lxd_next
 test rax,rax
 jz .Lxdv_bad
 mov r15,rax
 mov ebx,edx
 test ebx,32
 jnz .Lxdv_constructed
 test ebx,192
 jnz .Lxdv_advance
 test ebx,ebx
 jz .Lxdv_bad
 cmp ebx,16
 je .Lxdv_bad
 cmp ebx,17
 je .Lxdv_bad
 cmp ebx,1
 je .Lxdv_boolean
 cmp ebx,2
 je .Lxdv_integer
 cmp ebx,3
 je .Lxdv_bits
 cmp ebx,5
 je .Lxdv_null
 cmp ebx,6
 je .Lxdv_oid
 jmp .Lxdv_advance
.Lxdv_constructed:
 mov eax,ebx
 and eax,192
 jnz .Lxdv_recurse
 cmp ebx,48
 je .Lxdv_recurse
 cmp ebx,49
 jne .Lxdv_bad
.Lxdv_recurse:
 mov rdi,rcx
 mov rsi,r15
 lea rdx,[r14+1]
 call .Lx_der_valid
 test rax,rax
 jz .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_boolean:
 cmp r8,1
 jne .Lxdv_bad
 movzx eax,byte ptr [rcx]
 test eax,eax
 jz .Lxdv_advance
 cmp eax,255
 jne .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_integer:
 test r8,r8
 jz .Lxdv_bad
 cmp r8,1
 je .Lxdv_advance
 movzx eax,byte ptr [rcx]
 test eax,eax
 jnz .Lxdv_negative
 test byte ptr [rcx+1],128
 jz .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_negative:
 cmp eax,255
 jne .Lxdv_advance
 test byte ptr [rcx+1],128
 jnz .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_bits:
 test r8,r8
 jz .Lxdv_bad
 movzx edx,byte ptr [rcx]
 cmp edx,7
 ja .Lxdv_bad
 cmp r8,1
 jne .Lxdv_bit_padding
 test edx,edx
 jnz .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_bit_padding:
 movzx eax,byte ptr [rcx+r8-1]
 mov ecx,edx
 mov edx,1
 shl edx,cl
 dec edx
 test eax,edx
 jnz .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_null:
 test r8,r8
 jnz .Lxdv_bad
 jmp .Lxdv_advance
.Lxdv_oid:
 test r8,r8
 jz .Lxdv_bad
 xor eax,eax
 mov r9d,1
.Lxdv_oid_byte:
 movzx edx,byte ptr [rcx+rax]
 test r9d,r9d
 jz .Lxdv_oid_continue
 cmp edx,128
 je .Lxdv_bad
.Lxdv_oid_continue:
 xor r9d,r9d
 test edx,128
 setz r9b
 inc rax
 cmp rax,r8
 jb .Lxdv_oid_byte
 test r9d,r9d
 jz .Lxdv_bad
.Lxdv_advance:
 mov r12,r15
 jmp .Lxdv_next
.Lxdv_good:
 mov eax,1
 jmp .Lxdv_return
.Lxdv_bad:
 xor eax,eax
.Lxdv_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .note.GNU-stack,"",@progbits
