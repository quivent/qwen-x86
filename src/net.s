.include "abi.inc"
.ifndef DNS_PORT
.equ DNS_PORT,53
.endif
.data
.p2align 3
net_ui_hook: .quad 0
.text
.global net_set_ui_hook
net_set_ui_hook:
    mov [rip+net_ui_hook],rdi
    xor eax,eax
    ret
.global net_connect,net_read,net_write,net_close,net_set_interactive,net_cancelled
# Native Linux socket membrane. DNS data and per-process buffers are not shared.
net_set_interactive:
    mov [rip+net_interactive],rdi
    ret
# Nonblocking cancellation probe for bounded retry loops outside socket polling.
# Only the application's single native event loop consumes stdin. Match net_wait:
# consume at most one ready byte; ordinary bytes are ignored, byte3 is sticky.
.global net_check_cancel
net_check_cancel:
    sub rsp,24
    cmp qword ptr [rip+net_cancelled],0
    jne .L_check_cancelled
    cmp qword ptr [rip+net_interactive],0
    je .L_check_cancel_ok
    mov rax,[rip+net_ui_hook]
    test rax,rax
    jz .L_check_legacy_input
    call rax
    test rax,rax
    jns .L_check_cancel_ok
    mov qword ptr [rip+net_cancelled],1
    jmp .L_check_cancelled
.L_check_legacy_input:
    mov qword ptr [rsp],0
    mov word ptr [rsp+4],1
    mov eax,7
    mov rdi,rsp
    mov esi,1
    xor edx,edx
    syscall
    test rax,rax
    jle .L_check_cancel_ok
    test word ptr [rsp+6],1
    jz .L_check_cancel_ok
    xor eax,eax
    xor edi,edi
    lea rsi,[rsp+8]
    mov edx,1
    syscall
    cmp rax,1
    jne .L_check_cancel_ok
    cmp byte ptr [rsp+8],3
    jne .L_check_cancel_ok
    mov qword ptr [rip+net_cancelled],1
.L_check_cancelled:
    mov rax,-125
    jmp .L_check_cancel_return
.L_check_cancel_ok:
    xor eax,eax
.L_check_cancel_return:
    add rsp,24
    ret
net_close:
    mov eax,3
    syscall
    ret
# net_wait(fd,eventmask) ->0 ready /negative errno; stdin Ctrl+C cancels.
net_wait:
    push rbx
    push r12
    push r13
    push r14
    sub rsp,72
    mov ebx,edi
    mov r12d,esi
    call .L_net_clock_ms
    test rax,rax
    js .L_wait_done
    lea r14,[rax+30000]
.L_wait_again:
    cmp qword ptr [rip+net_cancelled],0
    jne .L_wait_cancel
    cmp qword ptr [rip+net_interactive],0
    je .L_wait_prepare
    mov rax,[rip+net_ui_hook]
    test rax,rax
    jz .L_wait_prepare
    call rax
    test rax,rax
    js .L_wait_mark_cancel
.L_wait_prepare:
    call .L_net_clock_ms
    test rax,rax
    js .L_wait_done
    mov r13,r14
    sub r13,rax
    jle .L_wait_timeout
    cmp qword ptr [rip+net_interactive],0
    je .L_wait_timeout_ready
    cmp qword ptr [rip+net_ui_hook],0
    je .L_wait_timeout_ready
    cmp r13,50
    jbe .L_wait_timeout_ready
    mov r13d,50
.L_wait_timeout_ready:
    mov [rsp],ebx
    mov [rsp+4],r12w
    mov word ptr [rsp+6],0
    mov eax,-1
    cmp qword ptr [rip+net_interactive],0
    je .L_wait_no_stdin
    xor eax,eax
.L_wait_no_stdin:
    mov [rsp+8],eax
    mov word ptr [rsp+12],1
    mov word ptr [rsp+14],0
    mov eax,7
    mov rdi,rsp
    mov esi,2
    mov edx,r13d
    syscall
    cmp rax,-4
    je .L_wait_again
    test rax,rax
    js .L_wait_done
    jz .L_wait_again
    test word ptr [rsp+14],1
    jz .L_wait_socket
    cmp qword ptr [rip+net_ui_hook],0
    jne .L_wait_again
    xor eax,eax
    xor edi,edi
    lea rsi,[rsp+16]
    mov edx,1
    syscall
    cmp rax,1
    jne .L_wait_socket
    cmp byte ptr [rsp+16],3
    jne .L_wait_socket
.L_wait_mark_cancel:
    mov qword ptr [rip+net_cancelled],1
    jmp .L_wait_cancel
.L_wait_socket:
    test word ptr [rsp+6],0x3d
    jz .L_wait_again
    xor eax,eax
    jmp .L_wait_done
.L_wait_timeout:
    mov rax,-110
    jmp .L_wait_done
.L_wait_cancel:
    mov rax,-125
.L_wait_done:
    add rsp,72
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# Monotonic milliseconds; private stack state preserves nested UI callbacks.
.L_net_clock_ms:
    sub rsp,24
    mov eax,228
    mov edi,1
    mov rsi,rsp
    syscall
    test rax,rax
    js .L_net_clock_return
    mov rax,[rsp]
    imul rax,rax,1000
    mov r8,rax
    mov rax,[rsp+8]
    xor edx,edx
    mov ecx,1000000
    div rcx
    add rax,r8
.L_net_clock_return:
    add rsp,24
    ret
# net_read(fd,dst,cap), nonblocking descriptors and partial receive.
net_read:
    push rbx
    push r12
    push r13
    mov ebx,edi
    mov r12,rsi
    mov r13,rdx
.L_read_again:
    xor eax,eax
    mov edi,ebx
    mov rsi,r12
    mov rdx,r13
    syscall
    cmp rax,-4
    je .L_read_again
    cmp rax,-11
    jne .L_read_done
    mov edi,ebx
    mov esi,1
    call net_wait
    test rax,rax
    jns .L_read_again
.L_read_done:
    pop r13
    pop r12
    pop rbx
    ret
# net_write(fd,src,len) -> original length or error, MSG_NOSIGNAL.
net_write:
    push rbx
    push r12
    push r13
    push r14
    sub rsp,8
    mov ebx,edi
    mov r12,rsi
    mov r13,rdx
    mov r14,rdx
.L_send_again:
    test r13,r13
    jz .L_send_done
    mov eax,44
    mov edi,ebx
    mov rsi,r12
    mov rdx,r13
    mov r10d,0x4000
    xor r8d,r8d
    xor r9d,r9d
    syscall
    cmp rax,-4
    je .L_send_again
    cmp rax,-11
    je .L_send_wait
    test rax,rax
    js .L_send_return
    jz .L_send_zero
    add r12,rax
    sub r13,rax
    jmp .L_send_again
.L_send_wait:
    mov edi,ebx
    mov esi,4
    call net_wait
    test rax,rax
    jns .L_send_again
    jmp .L_send_return
.L_send_zero:
    mov rax,-5
    jmp .L_send_return
.L_send_done:
    mov rax,r14
.L_send_return:
    add rsp,8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# parse IPv4(z) -> eax little-endian network bytes, edx0 /edx -1.
.L_ipv4:
    xor r8d,r8d
    xor r9d,r9d
.L_ip_octet:
    xor eax,eax
    xor ecx,ecx
.L_ip_digit:
    movzx edx,byte ptr [rdi]
    sub edx,'0'
    cmp edx,9
    ja .L_ip_end_digit
    imul eax,eax,10
    add eax,edx
    cmp eax,255
    ja .L_ip_bad
    inc ecx
    inc rdi
    cmp ecx,3
    jbe .L_ip_digit
    jmp .L_ip_bad
.L_ip_end_digit:
    test ecx,ecx
    jz .L_ip_bad
    mov ecx,r9d
    shl ecx,3
    shl eax,cl
    or r8d,eax
    inc r9d
    cmp r9d,4
    je .L_ip_final
    cmp byte ptr [rdi],'.'
    jne .L_ip_bad
    inc rdi
    jmp .L_ip_octet
.L_ip_final:
    cmp byte ptr [rdi],0
    jne .L_ip_bad
    mov eax,r8d
    xor edx,edx
    ret
.L_ip_bad:
    mov edx,-1
    ret
# net_connect(hostz,port) ->nonblocking TCP fd /negative.
net_connect:
    push rbx
    push r12
    push r13
    push r14
    sub rsp,24
    mov r12,rdi
    mov r13d,esi
    call .L_ipv4
    test edx,edx
    jz .L_connect_address
    mov rdi,r12
    call .L_hosts
    test edx,edx
    jz .L_connect_address
    mov rdi,r12
    call .L_dns
    test rax,rax
    js .L_connect_return
.L_connect_address:
    mov dword ptr [rsp+4],eax
    mov word ptr [rsp],2
    mov eax,r13d
    rol ax,8
    mov [rsp+2],ax
    mov qword ptr [rsp+8],0
    mov eax,41
    mov edi,2
    mov esi,0x80801
    xor edx,edx
    syscall
    test rax,rax
    js .L_connect_return
    mov ebx,eax
    mov eax,42
    mov edi,ebx
    mov rsi,rsp
    mov edx,16
    syscall
    test rax,rax
    jz .L_connect_ok
    cmp rax,-115
    jne .L_connect_close
    mov edi,ebx
    mov esi,4
    call net_wait
    test rax,rax
    js .L_connect_close
    mov dword ptr [rsp+16],4
    mov eax,55
    mov edi,ebx
    mov esi,1
    mov edx,4
    lea r10,[rsp+20]
    lea r8,[rsp+16]
    syscall
    test rax,rax
    js .L_connect_close
    mov eax,[rsp+20]
    test eax,eax
    jz .L_connect_ok
    neg rax
    jmp .L_connect_close
 .L_connect_ok:
    # Interactive request fragments must not wait on Nagle/delayed-ACK coupling.
    mov dword ptr [rsp+16],1
    mov eax,54
    mov edi,ebx
    mov esi,6
    mov edx,1
    lea r10,[rsp+16]
    mov r8d,4
    syscall
    test rax,rax
    js .L_connect_close
    mov eax,ebx
    jmp .L_connect_return
.L_connect_close:
    mov r14,rax
    mov eax,3
    mov edi,ebx
    syscall
    mov rax,r14
.L_connect_return:
    add rsp,24
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
# /etc/hosts is an acquired, bounded local routing source. IPv6 lines are
# skipped because this transport profile is IPv4; aliases match ASCII DNS case.
.L_hosts:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp,32
    mov r12,rdi
    xor ecx,ecx
.L_hosts_query_len:
    cmp ecx,253
    ja .L_hosts_missing
    cmp byte ptr [r12+rcx],0
    je .L_hosts_query_ready
    inc ecx
    jmp .L_hosts_query_len
.L_hosts_query_ready:
    test ecx,ecx
    jz .L_hosts_missing
    mov [rsp+24],rcx
    mov eax,2
    lea rdi,[rip+hosts_path]
    xor esi,esi
    xor edx,edx
    syscall
    test rax,rax
    js .L_hosts_missing
    mov ebx,eax
    xor eax,eax
    mov edi,ebx
    lea rsi,[rip+dns_buffer]
    mov edx,4095
    syscall
    mov r14,rax
    mov eax,3
    mov edi,ebx
    syscall
    test r14,r14
    jle .L_hosts_missing
    lea rdi,[rip+dns_buffer]
    lea r13,[rdi+r14]
    mov byte ptr [r13],0
.L_hosts_line:
    cmp rdi,r13
    jae .L_hosts_missing
    mov al,[rdi]
    cmp al,' '
    je .L_hosts_advance
    cmp al,9
    je .L_hosts_advance
    cmp al,10
    je .L_hosts_advance
    cmp al,13
    je .L_hosts_advance
    cmp al,'#'
    je .L_hosts_skip_line
    mov r15,rdi
.L_hosts_address:
    cmp rdi,r13
    jae .L_hosts_missing
    mov al,[rdi]
    cmp al,' '
    je .L_hosts_address_end
    cmp al,9
    je .L_hosts_address_end
    cmp al,10
    je .L_hosts_skip_line
    cmp al,13
    je .L_hosts_skip_line
    cmp al,'#'
    je .L_hosts_skip_line
    inc rdi
    jmp .L_hosts_address
.L_hosts_address_end:
    mov [rsp+8],rdi
    mov [rsp+16],al
    mov byte ptr [rdi],0
    mov rdi,r15
    call .L_ipv4
    mov rdi,[rsp+8]
    mov cl,[rsp+16]
    mov [rdi],cl
    test edx,edx
    jnz .L_hosts_skip_line
    mov [rsp],eax
.L_hosts_alias_space:
    cmp rdi,r13
    jae .L_hosts_missing
    mov al,[rdi]
    cmp al,' '
    je .L_hosts_alias_advance
    cmp al,9
    je .L_hosts_alias_advance
    cmp al,'#'
    je .L_hosts_skip_line
    cmp al,10
    je .L_hosts_advance
    cmp al,13
    je .L_hosts_advance
    mov r15,rdi
.L_hosts_alias_end:
    cmp rdi,r13
    jae .L_hosts_alias_compare
    mov al,[rdi]
    cmp al,' '
    je .L_hosts_alias_compare
    cmp al,9
    je .L_hosts_alias_compare
    cmp al,10
    je .L_hosts_alias_compare
    cmp al,13
    je .L_hosts_alias_compare
    cmp al,'#'
    je .L_hosts_alias_compare
    inc rdi
    jmp .L_hosts_alias_end
.L_hosts_alias_compare:
    mov r14,rdi
    sub rdi,r15
    cmp rdi,[rsp+24]
    jne .L_hosts_alias_mismatch
    xor ebx,ebx
.L_hosts_name_byte:
    cmp rbx,[rsp+24]
    jae .L_hosts_found
    movzx eax,byte ptr [r15+rbx]
    lea ecx,[rax-'A']
    cmp ecx,25
    setbe cl
    movzx ecx,cl
    shl ecx,5
    add eax,ecx
    movzx edx,byte ptr [r12+rbx]
    lea ecx,[rdx-'A']
    cmp ecx,25
    setbe cl
    movzx ecx,cl
    shl ecx,5
    add edx,ecx
    cmp eax,edx
    jne .L_hosts_alias_mismatch
    inc ebx
    jmp .L_hosts_name_byte
.L_hosts_alias_mismatch:
    mov rdi,r14
    jmp .L_hosts_alias_space
.L_hosts_alias_advance:
    inc rdi
    jmp .L_hosts_alias_space
.L_hosts_skip_line:
    cmp rdi,r13
    jae .L_hosts_missing
    cmp byte ptr [rdi],10
    je .L_hosts_advance
    inc rdi
    jmp .L_hosts_skip_line
.L_hosts_advance:
    inc rdi
    jmp .L_hosts_line
.L_hosts_found:
    mov eax,[rsp]
    xor edx,edx
    jmp .L_hosts_return
.L_hosts_missing:
    xor eax,eax
    mov edx,-1
.L_hosts_return:
    add rsp,32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# DNS A resolver: IPv4 nameserver from resolv.conf, bounded names and packets.
.L_dns:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp,320
    mov r12,rdi
    mov eax,2
    lea rdi,[rip+resolv_path]
    xor esi,esi
    syscall
    test rax,rax
    js .L_dns_bad
    mov ebx,eax
    xor eax,eax
    mov edi,ebx
    lea rsi,[rip+dns_buffer]
    mov edx,4095
    syscall
    mov r14,rax
    mov eax,3
    mov edi,ebx
    syscall
    test r14,r14
    jle .L_dns_bad
    lea rdi,[rip+dns_buffer]
    mov byte ptr [rdi+r14],0
    lea r15,[rdi+r14]
.L_dns_config:
    cmp rdi,r15
    jae .L_dns_bad
    cmp byte ptr [rdi],10
    je .L_dns_config_next
    cmp byte ptr [rdi],13
    je .L_dns_config_next
    # Compare literal nameserver only at a line start.
    mov rsi,rdi
    lea rdx,[rip+nameserver_word]
    xor ecx,ecx
.L_dns_word:
    mov al,[rdx+rcx]
    test al,al
    jz .L_dns_space
    lea r8,[rsi+rcx]
    cmp r8,r15
    jae .L_dns_bad
    cmp al,[r8]
    jne .L_dns_skip_line
    inc rcx
    jmp .L_dns_word
.L_dns_space:
    lea rdi,[rsi+rcx]
.L_dns_skip_space:
    cmp rdi,r15
    jae .L_dns_bad
    mov al,[rdi]
    cmp al,' '
    je .L_dns_advance_space
    cmp al,9
    jne .L_dns_ip_start
.L_dns_advance_space:
    inc rdi
    jmp .L_dns_skip_space
.L_dns_ip_start:
    mov rsi,rdi
.L_dns_ip_end:
    cmp rdi,r15
    jae .L_dns_ip_terminate
    mov al,[rdi]
    cmp al,'.'
    je .L_dns_ip_more
    cmp al,'0'
    jb .L_dns_ip_terminate
    cmp al,'9'
    ja .L_dns_ip_terminate
.L_dns_ip_more:
    inc rdi
    jmp .L_dns_ip_end
.L_dns_ip_terminate:
    mov byte ptr [rdi],0
    mov rdi,rsi
    call .L_ipv4
    test edx,edx
    jnz .L_dns_bad
    mov [rsp+4],eax
    jmp .L_dns_make
.L_dns_skip_line:
    cmp rdi,r15
    jae .L_dns_bad
    cmp byte ptr [rdi],10
    je .L_dns_config_next
    inc rdi
    jmp .L_dns_skip_line
.L_dns_config_next:
    inc rdi
    jmp .L_dns_config
.L_dns_make:
    lea r14,[rip+dns_buffer]
    mov eax,318
    mov rdi,r14
    mov esi,2
    xor edx,edx
    syscall
    cmp rax,2
    jne .L_dns_bad
    movzx eax,word ptr [r14]
    mov [rsp+16],ax
    mov word ptr [r14+2],0x0001
    mov word ptr [r14+4],0x0100
    mov dword ptr [r14+6],0
    mov word ptr [r14+10],0
    lea rdi,[r14+12]
    mov rsi,r12
    xor r13d,r13d
.L_dns_label:
    mov rbx,rdi
    inc rdi
    xor ecx,ecx
.L_dns_label_char:
    mov al,[rsi]
    test al,al
    jz .L_dns_label_end
    cmp al,'.'
    je .L_dns_label_end
    cmp al,33
    jb .L_dns_bad
    cmp al,127
    jae .L_dns_bad
    mov [rdi],al
    inc rdi
    inc rsi
    inc ecx
    inc r13d
    cmp ecx,63
    ja .L_dns_bad
    cmp r13d,253
    ja .L_dns_bad
    jmp .L_dns_label_char
.L_dns_label_end:
    test ecx,ecx
    jz .L_dns_bad
    mov [rbx],cl
    test al,al
    jz .L_dns_q_end
    inc rsi
    jmp .L_dns_label
.L_dns_q_end:
    mov byte ptr [rdi],0
    mov dword ptr [rdi+1],0x01000100
    lea r13,[rdi+5]
    sub r13,r14
    cmp r13,271
    ja .L_dns_bad
    lea rdi,[rsp+32]
    mov rsi,r14
    mov rcx,r13
    rep movsb
    mov word ptr [rsp],2
    mov eax,DNS_PORT
    rol ax,8
    mov word ptr [rsp+2],ax
    mov qword ptr [rsp+8],0
    mov eax,41
    mov edi,2
    mov esi,0x80802
    xor edx,edx
    syscall
    test rax,rax
    js .L_dns_return
    mov ebx,eax
    mov eax,42
    mov edi,ebx
    mov rsi,rsp
    mov edx,16
    syscall
    test rax,rax
    js .L_dns_close
    mov edi,ebx
    mov rsi,r14
    mov rdx,r13
    call net_write
    test rax,rax
    js .L_dns_close
    mov edi,ebx
    mov rsi,r14
    mov edx,4096
    call net_read
    test rax,rax
    js .L_dns_close
    cmp rax,r13
    jb .L_dns_fail_close
    movzx edx,word ptr [rsp+16]
    cmp dx,[r14]
    jne .L_dns_fail_close
    test byte ptr [r14+2],0x80
    jz .L_dns_fail_close
    test byte ptr [r14+2],2
    jnz .L_dns_fail_close
    test byte ptr [r14+3],15
    jnz .L_dns_fail_close
    cmp word ptr [r14+4],0x0100
    jne .L_dns_fail_close
    lea rdi,[r14+12]
    lea rsi,[rsp+44]
    mov rcx,r13
    sub rcx,12
    repe cmpsb
    jne .L_dns_fail_close
    lea r15,[r14+rax]
    movzx r12d,word ptr [r14+6]
    rol r12w,8
    add r14,r13
.L_dns_answer:
    test r12d,r12d
    jz .L_dns_fail_close
    cmp r14,r15
    jae .L_dns_fail_close
.L_dns_name:
    movzx eax,byte ptr [r14]
    inc r14
    test eax,eax
    jz .L_dns_rr
    cmp eax,0xc0
    jae .L_dns_pointer
    cmp eax,63
    ja .L_dns_fail_close
    add r14,rax
    cmp r14,r15
    jae .L_dns_fail_close
    jmp .L_dns_name
.L_dns_pointer:
    inc r14
.L_dns_rr:
    lea rax,[r14+10]
    cmp rax,r15
    ja .L_dns_fail_close
    movzx edx,word ptr [r14+8]
    rol dx,8
    lea rax,[r14+rdx+10]
    cmp rax,r15
    ja .L_dns_fail_close
    cmp word ptr [r14],0x0100
    jne .L_dns_next_rr
    cmp word ptr [r14+2],0x0100
    jne .L_dns_next_rr
    cmp edx,4
    jne .L_dns_next_rr
    mov r13d,[r14+10]
    mov eax,3
    mov edi,ebx
    syscall
    mov eax,r13d
    jmp .L_dns_return
.L_dns_next_rr:
    mov r14,rax
    dec r12d
    jmp .L_dns_answer
.L_dns_fail_close:
    mov rax,-113
.L_dns_close:
    mov r13,rax
    mov eax,3
    mov edi,ebx
    syscall
    mov rax,r13
    jmp .L_dns_return
.L_dns_bad:
    mov rax,-113
.L_dns_return:
    add rsp,320
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.section .rodata
resolv_path: .asciz "/etc/resolv.conf"
hosts_path: .asciz "/etc/hosts"
nameserver_word: .asciz "nameserver"
.bss
.p2align 3
net_interactive: .zero 8
net_cancelled: .zero 8
.p2align 4
dns_buffer: .zero 4096
.section .note.GNU-stack,"",@progbits
