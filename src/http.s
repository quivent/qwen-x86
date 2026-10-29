# HTTP/1.x streaming membrane. Immutable byte classes/layouts are bound here;
# connection state belongs to one process. No libc/network/HTTP helper runtime.
.intel_syntax noprefix
.equ H_INPUT,8192
.equ H_LINE,65536
.equ H_BODY_MAX,67108864

.section .data
h_ca: .quad h_default_ca
h_content_type: .quad h_default_type
h_fd: .quad -1

.section .rodata
h_default_ca: .asciz "/etc/ssl/certs/ca-certificates.crt"
h_default_type: .asciz "application/json"
h_https: .ascii "https://"
h_http: .ascii "http://"
h_localhost: .asciz "localhost"
h_loopback: .asciz "127.0.0.1"
h_post: .asciz "POST "
h_get: .asciz "GET "
h_empty: .asciz ""
h_request_head: .asciz " HTTP/1.1\r\nHost: "
h_type_head: .asciz "\r\nContent-Type: "
h_accept: .asciz "\r\nAccept: text/event-stream\r\nConnection: keep-alive\r\nContent-Length: "
h_auth: .asciz "\r\nAuthorization: Bearer "
h_anthropic_auth: .asciz "\r\nx-api-key: "
h_anthropic_version: .asciz "\r\nanthropic-version: 2023-06-01"
h_gemini_auth: .asciz "\r\nx-goog-api-key: "
h_end: .asciz "\r\n\r\n"
h_key_cl: .asciz "content-length"
h_key_te: .asciz "transfer-encoding"
h_key_connection: .asciz "connection"
h_keepalive: .asciz "keep-alive"
h_chunked: .asciz "chunked"
h_hex:
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 0,1,2,3,4,5,6,7,8,9,255,255,255,255,255,255
 .byte 255,10,11,12,13,14,15,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,10,11,12,13,14,15,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
h_tchar:
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,1,0,1,1,1,1,1,0,0,1,1,0,1,1,0
 .byte 1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
 .byte 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
 .byte 1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1
 .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
 .byte 1,1,1,1,1,1,1,1,1,1,1,0,1,0,1,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

.section .bss
.align 16
h_url: .skip 2049
h_host: .skip 256
h_authority: .skip 512
h_path: .skip 2050
h_ca_buffer: .skip 4096
h_type_buffer: .skip 128
h_key: .skip 8193
h_request: .skip 131072
h_req_len: .skip 8
h_body_ptr: .skip 8
h_body_len: .skip 8
h_callback: .skip 8
h_want_tls: .skip 8
h_using_tls: .skip 8
h_cached: .skip 8
h_cache_host: .skip 256
h_cache_port: .skip 8
h_cache_scheme: .skip 8
h_http11: .skip 8
h_response_close: .skip 8
h_delimited: .skip 8
h_port: .skip 8
h_explicit_port: .skip 8
h_status_code: .skip 8
h_have_cl: .skip 8
h_have_te: .skip 8
h_content_length: .skip 8
h_remaining: .skip 8
h_total: .skip 8
h_header_total: .skip 8
h_in_pos: .skip 8
h_in_end: .skip 8
h_input: .skip H_INPUT
h_line: .skip H_LINE+1
h_decimal: .skip 32
h_trailer: .skip 8
h_auth_mode: .skip 8
h_method_get: .skip 8
h_interim: .skip 8

.section .text
.global http_request,http_set_ca,http_set_content_type,http_status,http_close,http_after_fork
.extern net_connect,net_read,net_write,net_close
.extern tls_connect,tls_read,tls_write,tls_close,tls_pending,tls_after_fork

http_status:
 mov rax,QWORD PTR [rip+h_status_code]
 ret
.global http_set_auth_mode
# 0 OpenAI bearer/OAuth,1 Anthropic,2 Gemini. Credentials remain private.
http_set_auth_mode:
 cmp rdi,2
 ja .Lauth_mode_bad
 mov [rip+h_auth_mode],rdi
 xor eax,eax
 ret
.Lauth_mode_bad:
 mov rax,-22
 ret
.global http_get
# URLZ,bodyCallback(ptr,len)->HTTPstatus/error. Public GET never borrows a key.
http_get:
 push rbx
 mov rbx,[rip+h_auth_mode]
 mov qword ptr [rip+h_auth_mode],0
 mov qword ptr [rip+h_method_get],1
 mov r8,rsi
 lea rsi,[rip+h_empty]
 mov rdx,rsi
 xor ecx,ecx
 call http_request
 mov qword ptr [rip+h_method_get],0
 mov [rip+h_auth_mode],rbx
 pop rbx
 ret

# CA policy changes always invalidate an idle authenticated connection.
http_set_ca:
 push rbx
 mov rbx,rdi
 call http_close
 test rbx,rbx
 jz .Lsetca_default
 mov rdi,rbx
 mov esi,4095
 call h_bounded_length
 test rax,rax
 jle .Lsetca_bad
 mov rcx,rax
 inc rcx
 lea rdi,[rip+h_ca_buffer]
 mov rsi,rbx
 rep movsb
 lea rax,[rip+h_ca_buffer]
 mov QWORD PTR [rip+h_ca],rax
 xor eax,eax
 pop rbx
 ret
.Lsetca_bad:
 mov rax,-22
 pop rbx
 ret
.Lsetca_default:
 lea rax,[rip+h_default_ca]
 mov QWORD PTR [rip+h_ca],rax
 xor eax,eax
 pop rbx
 ret

# Graceful owner shutdown; TLS clears its state and sends close_notify only.
http_close:
 push rbx
 cmp QWORD PTR [rip+h_using_tls],0
 je .Lhttp_close_fd
 call tls_close@PLT
.Lhttp_close_fd:
 mov rdi,QWORD PTR [rip+h_fd]
 cmp rdi,0
 jl .Lhttp_close_reset
 call net_close@PLT
.Lhttp_close_reset:
 mov QWORD PTR [rip+h_fd],-1
 mov QWORD PTR [rip+h_using_tls],0
 mov QWORD PTR [rip+h_cached],0
 mov QWORD PTR [rip+h_in_pos],0
 mov QWORD PTR [rip+h_in_end],0
 xor eax,eax
 pop rbx
 ret

# A forked worker owns only its descriptor reference, never the parent's TLS
# connection. Drop that reference with no alert/shutdown on the shared socket.
http_after_fork:
 push rbx
 mov rdi,QWORD PTR [rip+h_fd]
 cmp rdi,0
 jl .Lafter_fork_reset
 call net_close@PLT
.Lafter_fork_reset:
 cmp QWORD PTR [rip+h_using_tls],0
 je .Lafter_fork_http_reset
 call tls_after_fork@PLT
.Lafter_fork_http_reset:
 mov QWORD PTR [rip+h_fd],-1
 mov QWORD PTR [rip+h_using_tls],0
 mov QWORD PTR [rip+h_cached],0
 mov QWORD PTR [rip+h_in_pos],0
 mov QWORD PTR [rip+h_in_end],0
 mov QWORD PTR [rip+h_status_code],0
 xor eax,eax
 pop rbx
 ret

http_set_content_type:
 test rdi,rdi
 jz .Lsettype_default
 push rbx
 mov rbx,rdi
 mov esi,127
 call h_bounded_length
 test rax,rax
 jle .Lsettype_bad
 xor ecx,ecx
.Lsettype_check:
 cmp rcx,rax
 jae .Lsettype_copy
 mov dl,BYTE PTR [rbx+rcx]
 cmp dl,32
 jb .Lsettype_bad
 cmp dl,126
 ja .Lsettype_bad
 inc rcx
 jmp .Lsettype_check
.Lsettype_copy:
 mov rcx,rax
 inc rcx
 lea rdi,[rip+h_type_buffer]
 mov rsi,rbx
 rep movsb
 lea rax,[rip+h_type_buffer]
 mov QWORD PTR [rip+h_content_type],rax
 xor eax,eax
 pop rbx
 ret
.Lsettype_bad:
 mov rax,-22
 pop rbx
 ret
.Lsettype_default:
 lea rax,[rip+h_default_type]
 mov QWORD PTR [rip+h_content_type],rax
 xor eax,eax
 ret

# http_request(URLz,keyz,body,len,callback)->HTTP status or negative.
http_request:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov QWORD PTR [rip+h_status_code],0
 mov QWORD PTR [rip+h_delimited],0
 mov QWORD PTR [rip+h_http11],0
 mov QWORD PTR [rip+h_response_close],0
 mov QWORD PTR [rip+h_body_ptr],rdx
 mov QWORD PTR [rip+h_body_len],rcx
 mov QWORD PTR [rip+h_callback],r8
 mov r12,rdi
 mov r13,rsi
 test r12,r12
 jz .Lrequest_invalid
 cmp rcx,H_BODY_MAX
 ja .Lrequest_limit
 test rcx,rcx
 jz .Lrequest_parse
 test rdx,rdx
 jz .Lrequest_invalid
.Lrequest_parse:
 mov rdi,r12
 call h_parse_url
 test rax,rax
 js .Lrequest_finish
 lea rdi,[rip+h_key]
 mov BYTE PTR [rdi],0
 test r13,r13
 jz .Lrequest_build
 mov rdi,r13
 mov esi,8192
 call h_bounded_length
 test rax,rax
 js .Lrequest_invalid
 mov r14,rax
 xor ecx,ecx
.Lrequest_key_check:
 cmp rcx,r14
 jae .Lrequest_key_copy
 mov dl,BYTE PTR [r13+rcx]
 cmp dl,33
 jb .Lrequest_invalid
 cmp dl,126
 ja .Lrequest_invalid
 inc rcx
 jmp .Lrequest_key_check
.Lrequest_key_copy:
 lea rdi,[rip+h_key]
 mov rsi,r13
 mov rcx,r14
 inc rcx
 rep movsb
.Lrequest_build:
 call h_build_request
 test rax,rax
 js .Lrequest_finish
 cmp QWORD PTR [rip+h_cached],0
 je .Lrequest_new_connection
 cmp QWORD PTR [rip+h_fd],0
 jl .Lrequest_new_connection
 mov rax,QWORD PTR [rip+h_port]
 cmp rax,QWORD PTR [rip+h_cache_port]
 jne .Lrequest_new_connection
 mov rax,QWORD PTR [rip+h_want_tls]
 cmp rax,QWORD PTR [rip+h_cache_scheme]
 jne .Lrequest_new_connection
 lea rdi,[rip+h_host]
 lea rsi,[rip+h_cache_host]
 call h_equal
 test eax,eax
 jz .Lrequest_new_connection
 mov QWORD PTR [rip+h_cached],0
 jmp .Lrequest_send
.Lrequest_new_connection:
 call http_close
 lea rdi,[rip+h_host]
 lea rsi,[rip+h_localhost]
 call h_equal
 lea rdi,[rip+h_host]
 lea rdx,[rip+h_loopback]
 test eax,eax
 cmovnz rdi,rdx
 mov rsi,QWORD PTR [rip+h_port]
 call net_connect@PLT
 test rax,rax
 js .Lrequest_finish
 mov QWORD PTR [rip+h_fd],rax
 cmp QWORD PTR [rip+h_want_tls],0
 je .Lrequest_send
 mov rdi,rax
 lea rsi,[rip+h_host]
 mov rdx,QWORD PTR [rip+h_ca]
 call tls_connect@PLT
 test rax,rax
 js .Lrequest_finish
 mov QWORD PTR [rip+h_using_tls],1
.Lrequest_send:
 lea rdi,[rip+h_request]
 mov rsi,QWORD PTR [rip+h_req_len]
 call h_send
 test rax,rax
 js .Lrequest_finish
 mov rdi,QWORD PTR [rip+h_body_ptr]
 mov rsi,QWORD PTR [rip+h_body_len]
 call h_send
 test rax,rax
 js .Lrequest_finish
 mov QWORD PTR [rip+h_in_pos],0
 mov QWORD PTR [rip+h_in_end],0
 mov QWORD PTR [rip+h_total],0
 mov QWORD PTR [rip+h_interim],0
.Lrequest_response:
 mov QWORD PTR [rip+h_header_total],0
 mov QWORD PTR [rip+h_have_cl],0
 mov QWORD PTR [rip+h_have_te],0
 mov QWORD PTR [rip+h_content_length],0
 mov QWORD PTR [rip+h_trailer],0
 lea rdi,[rip+h_line]
 mov esi,H_LINE
 call h_getline
 test rax,rax
 js .Lrequest_finish
 call h_status_line
 test rax,rax
 js .Lrequest_finish
.Lrequest_headers:
 lea rdi,[rip+h_line]
 mov esi,H_LINE
 call h_getline
 test rax,rax
 js .Lrequest_finish
 test rax,rax
 jz .Lrequest_headers_done
 call h_parse_header
 test rax,rax
 js .Lrequest_finish
 jmp .Lrequest_headers
.Lrequest_headers_done:
 cmp QWORD PTR [rip+h_have_cl],0
 je .Lrequest_framing_ok
 cmp QWORD PTR [rip+h_have_te],0
 jne .Lrequest_bad
.Lrequest_framing_ok:
 mov rax,QWORD PTR [rip+h_status_code]
 cmp rax,200
 jae .Lrequest_body_status
 cmp rax,101
 je .Lrequest_bad
 inc QWORD PTR [rip+h_interim]
 cmp QWORD PTR [rip+h_interim],5
 ja .Lrequest_bad
 cmp QWORD PTR [rip+h_have_cl],0
 jne .Lrequest_bad
 cmp QWORD PTR [rip+h_have_te],0
 jne .Lrequest_bad
 jmp .Lrequest_response
.Lrequest_body_status:
 cmp rax,204
 je .Lrequest_no_body
 cmp rax,304
 je .Lrequest_no_body
 cmp QWORD PTR [rip+h_have_te],0
 jne .Lrequest_chunks
 cmp QWORD PTR [rip+h_have_cl],0
 je .Lrequest_close_body
 mov QWORD PTR [rip+h_delimited],1
 mov rax,QWORD PTR [rip+h_content_length]
 mov QWORD PTR [rip+h_remaining],rax
 call h_copy_length
 test rax,rax
 js .Lrequest_finish
 jmp .Lrequest_success
.Lrequest_chunks:
 mov QWORD PTR [rip+h_delimited],1
 mov QWORD PTR [rip+h_header_total],0
 lea rdi,[rip+h_line]
 mov esi,H_LINE
 call h_getline
 test rax,rax
 js .Lrequest_finish
 call h_chunk_size
 test rax,rax
 js .Lrequest_finish
 test rax,rax
 jz .Lrequest_trailers
 mov QWORD PTR [rip+h_remaining],rax
 call h_copy_length
 test rax,rax
 js .Lrequest_finish
 call h_getbyte
 test rax,rax
 js .Lrequest_finish
 cmp rax,13
 jne .Lrequest_bad
 call h_getbyte
 test rax,rax
 js .Lrequest_finish
 cmp rax,10
 jne .Lrequest_bad
 jmp .Lrequest_chunks
.Lrequest_trailers:
 mov QWORD PTR [rip+h_trailer],1
 mov QWORD PTR [rip+h_header_total],0
.Lrequest_trailer_line:
 lea rdi,[rip+h_line]
 mov esi,H_LINE
 call h_getline
 test rax,rax
 js .Lrequest_finish
 test rax,rax
 jz .Lrequest_success
 call h_parse_header
 test rax,rax
 js .Lrequest_finish
 jmp .Lrequest_trailer_line
.Lrequest_close_body:
 call h_fill
 test rax,rax
 js .Lrequest_finish
 jz .Lrequest_success
 mov rsi,QWORD PTR [rip+h_in_end]
 sub rsi,QWORD PTR [rip+h_in_pos]
 lea rdi,[rip+h_input]
 add rdi,QWORD PTR [rip+h_in_pos]
 call h_emit
 test rax,rax
 js .Lrequest_finish
 mov rax,QWORD PTR [rip+h_in_end]
 mov QWORD PTR [rip+h_in_pos],rax
 jmp .Lrequest_close_body
.Lrequest_no_body:
 mov QWORD PTR [rip+h_delimited],1
.Lrequest_success:
 cmp QWORD PTR [rip+h_delimited],0
 je .Lrequest_success_close
 cmp QWORD PTR [rip+h_http11],1
 jne .Lrequest_success_close
 cmp QWORD PTR [rip+h_response_close],0
 jne .Lrequest_success_close
 mov rax,QWORD PTR [rip+h_in_pos]
 cmp rax,QWORD PTR [rip+h_in_end]
 jne .Lrequest_success_close
 cmp QWORD PTR [rip+h_using_tls],0
 je .Lrequest_cache_ready
 call tls_pending@PLT
 test rax,rax
 jnz .Lrequest_success_close
.Lrequest_cache_ready:
 lea rdi,[rip+h_cache_host]
 lea rsi,[rip+h_host]
.Lrequest_cache_host:
 lodsb
 stosb
 test al,al
 jnz .Lrequest_cache_host
 mov rax,QWORD PTR [rip+h_port]
 mov QWORD PTR [rip+h_cache_port],rax
 mov rax,QWORD PTR [rip+h_want_tls]
 mov QWORD PTR [rip+h_cache_scheme],rax
 mov QWORD PTR [rip+h_cached],1
 mov r15,QWORD PTR [rip+h_status_code]
 jmp .Lrequest_return
.Lrequest_success_close:
 mov rax,QWORD PTR [rip+h_status_code]
 jmp .Lrequest_finish
.Lrequest_invalid:
 mov rax,-22
 jmp .Lrequest_finish
.Lrequest_bad:
 mov rax,-74
 jmp .Lrequest_finish
.Lrequest_limit:
 mov rax,-75
.Lrequest_finish:
 mov r15,rax
 call http_close
.Lrequest_return:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret

# Bounded NUL string length, with caller-owned maximum. Returns-22 on overflow.
h_bounded_length:
 xor eax,eax
.Lbounded_loop:
 cmp rax,rsi
 ja .Lbounded_bad
 cmp BYTE PTR [rdi+rax],0
 je .Lbounded_done
 inc rax
 jmp .Lbounded_loop
.Lbounded_bad:
 mov rax,-22
.Lbounded_done:
 ret

# Exact NUL-string comparison. No locale/library state.
h_equal:
 xor eax,eax
.Lequal_loop:
 mov dl,BYTE PTR [rdi+rax]
 cmp dl,BYTE PTR [rsi+rax]
 jne .Lequal_no
 test dl,dl
 jz .Lequal_yes
 inc rax
 jmp .Lequal_loop
.Lequal_yes:
 mov eax,1
 ret
.Lequal_no:
 xor eax,eax
 ret

h_parse_url:
 push rbx
 push r12
 push r13
 push r14
 sub rsp,8
 mov r12,rdi
 mov esi,2048
 call h_bounded_length
 test rax,rax
 js .Lurl_bad
 cmp rax,8
 jb .Lurl_bad
 mov r13,rax
 xor ecx,ecx
.Lurl_ascii:
 cmp rcx,r13
 jae .Lurl_copy
 mov dl,BYTE PTR [r12+rcx]
 cmp dl,33
 jb .Lurl_bad
 cmp dl,126
 ja .Lurl_bad
 cmp dl,35
 je .Lurl_bad
 inc rcx
 jmp .Lurl_ascii
.Lurl_copy:
 lea rdi,[rip+h_url]
 mov rsi,r12
 lea rcx,[r13+1]
 rep movsb
 lea r12,[rip+h_url]
 mov QWORD PTR [rip+h_want_tls],0
 mov QWORD PTR [rip+h_port],80
 mov QWORD PTR [rip+h_explicit_port],0
 mov rdi,r12
 lea rsi,[rip+h_https]
 mov ecx,8
 repe cmpsb
 jne .Lurl_http
 mov QWORD PTR [rip+h_want_tls],1
 mov QWORD PTR [rip+h_port],443
 lea r14,[r12+8]
 jmp .Lurl_host
.Lurl_http:
 mov rdi,r12
 lea rsi,[rip+h_http]
 mov ecx,7
 repe cmpsb
 jne .Lurl_bad
 lea r14,[r12+7]
.Lurl_host:
 xor ebx,ebx
 lea rdi,[rip+h_host]
.Lurl_host_char:
 movzx eax,BYTE PTR [r14]
 test al,al
 jz .Lurl_host_done
 cmp al,47
 je .Lurl_host_done
 cmp al,63
 je .Lurl_host_done
 cmp al,58
 je .Lurl_host_done
 cmp ebx,253
 jae .Lurl_bad
 cmp al,65
 jb .Lurl_host_digit
 cmp al,90
 ja .Lurl_host_digit
 add al,32
 jmp .Lurl_host_store
.Lurl_host_digit:
 cmp al,97
 jb .Lurl_host_number
 cmp al,122
 jbe .Lurl_host_store
.Lurl_host_number:
 cmp al,48
 jb .Lurl_host_dot
 cmp al,57
 jbe .Lurl_host_store
.Lurl_host_dot:
 cmp al,46
 je .Lurl_host_store
 cmp al,45
 jne .Lurl_bad
.Lurl_host_store:
 mov BYTE PTR [rdi+rbx],al
 inc ebx
 inc r14
 jmp .Lurl_host_char
.Lurl_host_done:
 test ebx,ebx
 jz .Lurl_bad
 mov BYTE PTR [rdi+rbx],0
 mov r12d,ebx
 cmp BYTE PTR [r14],58
 jne .Lurl_authority
 inc r14
 mov QWORD PTR [rip+h_explicit_port],1
 xor eax,eax
 xor ecx,ecx
.Lurl_port_digits:
 movzx edx,BYTE PTR [r14]
 cmp edx,48
 jb .Lurl_port_done
 cmp edx,57
 ja .Lurl_port_done
 imul eax,eax,10
 sub edx,48
 add eax,edx
 cmp eax,65535
 ja .Lurl_bad
 inc ecx
 inc r14
 jmp .Lurl_port_digits
.Lurl_port_done:
 test ecx,ecx
 jz .Lurl_bad
 test eax,eax
 jz .Lurl_bad
 cmp BYTE PTR [r14],0
 je .Lurl_port_store
 cmp BYTE PTR [r14],47
 je .Lurl_port_store
 cmp BYTE PTR [r14],63
 jne .Lurl_bad
.Lurl_port_store:
 mov QWORD PTR [rip+h_port],rax
.Lurl_authority:
 lea rdi,[rip+h_authority]
 lea rsi,[rip+h_host]
 mov rcx,r12
 rep movsb
 cmp QWORD PTR [rip+h_explicit_port],0
 je .Lurl_authority_end
 mov BYTE PTR [rdi],58
 inc rdi
 mov rsi,rdi
 mov rdi,QWORD PTR [rip+h_port]
 call h_decimal_value
 # Decimal helper leaves destination advanced to its terminating NUL.
.Lurl_authority_end:
 mov BYTE PTR [rdi],0
 lea rdi,[rip+h_path]
 cmp BYTE PTR [r14],47
 je .Lurl_path_copy
 mov BYTE PTR [rdi],47
 inc rdi
.Lurl_path_copy:
 mov al,BYTE PTR [r14]
 mov BYTE PTR [rdi],al
 inc rdi
 inc r14
 test al,al
 jnz .Lurl_path_copy
 cmp QWORD PTR [rip+h_want_tls],0
 jne .Lurl_good
 lea rdi,[rip+h_host]
 lea rsi,[rip+h_localhost]
 call h_equal
 test eax,eax
 jnz .Lurl_good
 lea rdi,[rip+h_host]
 lea rsi,[rip+h_loopback]
 call h_equal
 test eax,eax
 jz .Lurl_bad
.Lurl_good:
 xor eax,eax
 jmp .Lurl_done
.Lurl_bad:
 mov rax,-22
.Lurl_done:
 add rsp,8
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# rdi unsignedinteger,rsi destination; rdi returns at terminatingNUL.
h_decimal_value:
 sub rsp,32
 lea r8,[rsp+31]
 mov BYTE PTR [r8],0
 mov r9,r8
 mov rax,rdi
 mov r10d,10
.Ldecimal_digit:
 xor edx,edx
 div r10
 add dl,48
 dec r8
 mov BYTE PTR [r8],dl
 test rax,rax
 jnz .Ldecimal_digit
 mov rcx,r9
 sub rcx,r8
 mov rdi,rsi
 mov rsi,r8
 rep movsb
 mov BYTE PTR [rdi],0
 add rsp,32
 ret

# Append NUL-terminated source to the bound requestheaderbuffer.
h_append:
 mov rax,QWORD PTR [rip+h_req_len]
 lea rdx,[rip+h_request]
.Lappend_byte:
 mov cl,BYTE PTR [rdi]
 test cl,cl
 jz .Lappend_done
 cmp rax,131071
 jae .Lappend_bad
 mov BYTE PTR [rdx+rax],cl
 inc rax
 inc rdi
 jmp .Lappend_byte
.Lappend_done:
 mov QWORD PTR [rip+h_req_len],rax
 xor eax,eax
 ret
.Lappend_bad:
 mov rax,-75
 ret

h_build_request:
 push rbx
 mov QWORD PTR [rip+h_req_len],0
 lea rdi,[rip+h_post]
 cmp qword ptr [rip+h_method_get],0
 je .Lbuild_method_ready
 lea rdi,[rip+h_get]
.Lbuild_method_ready:
 call h_append
 test rax,rax
 js .Lbuild_done
 lea rdi,[rip+h_path]
 call h_append
 test rax,rax
 js .Lbuild_done
 lea rdi,[rip+h_request_head]
 call h_append
 test rax,rax
 js .Lbuild_done
 lea rdi,[rip+h_authority]
 call h_append
 test rax,rax
 js .Lbuild_done
 lea rdi,[rip+h_type_head]
 call h_append
 test rax,rax
 js .Lbuild_done
 mov rdi,QWORD PTR [rip+h_content_type]
 call h_append
 test rax,rax
 js .Lbuild_done
 lea rdi,[rip+h_accept]
 call h_append
 test rax,rax
 js .Lbuild_done
 mov rdi,QWORD PTR [rip+h_body_len]
 lea rsi,[rip+h_decimal]
 call h_decimal_value
 lea rdi,[rip+h_decimal]
 call h_append
 test rax,rax
 js .Lbuild_done
 cmp BYTE PTR [rip+h_key],0
 je .Lbuild_finish
 lea rdi,[rip+h_auth]
 cmp qword ptr [rip+h_auth_mode],1
 jne .Lbuild_not_anthropic_auth
 lea rdi,[rip+h_anthropic_auth]
.Lbuild_not_anthropic_auth:
 cmp qword ptr [rip+h_auth_mode],2
 jne .Lbuild_auth_ready
 lea rdi,[rip+h_gemini_auth]
.Lbuild_auth_ready:
 call h_append
 test rax,rax
 js .Lbuild_done
 lea rdi,[rip+h_key]
 call h_append
 test rax,rax
 js .Lbuild_done
.Lbuild_finish:
 cmp qword ptr [rip+h_auth_mode],1
 jne .Lbuild_version_ready
 lea rdi,[rip+h_anthropic_version]
 call h_append
 test rax,rax
 js .Lbuild_done
.Lbuild_version_ready:
 lea rdi,[rip+h_end]
 call h_append
.Lbuild_done:
 pop rbx
 ret

# Internal I/O signatures use(ptr,len), with a bound connection descriptor.
h_write:
 cmp QWORD PTR [rip+h_using_tls],0
 jne .Lwrite_tls
 mov rdx,rsi
 mov rsi,rdi
 mov rdi,QWORD PTR [rip+h_fd]
 jmp net_write@PLT
.Lwrite_tls:
 jmp tls_write@PLT

h_read:
 cmp QWORD PTR [rip+h_using_tls],0
 jne .Lread_tls
 mov rdx,rsi
 mov rsi,rdi
 mov rdi,QWORD PTR [rip+h_fd]
 jmp net_read@PLT
.Lread_tls:
 jmp tls_read@PLT

h_send:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 xor ebx,ebx
.Lsend_loop:
 cmp rbx,r13
 jae .Lsend_good
 lea rdi,[r12+rbx]
 mov rsi,r13
 sub rsi,rbx
 call h_write
 test rax,rax
 js .Lsend_done
 jz .Lsend_bad
 mov rdx,r13
 sub rdx,rbx
 cmp rax,rdx
 ja .Lsend_bad
 add rbx,rax
 jmp .Lsend_loop
.Lsend_good:
 xor eax,eax
 jmp .Lsend_done
.Lsend_bad:
 mov rax,-74
.Lsend_done:
 pop r13
 pop r12
 pop rbx
 ret

# Ensure unread input exists;0 is authenticatedEOF at the active I/O layer.
h_fill:
 mov rax,QWORD PTR [rip+h_in_end]
 sub rax,QWORD PTR [rip+h_in_pos]
 jnz .Lfill_done
 sub rsp,8
 lea rdi,[rip+h_input]
 mov esi,H_INPUT
 call h_read
 test rax,rax
 js .Lfill_return
 cmp rax,H_INPUT
 ja .Lfill_bad
 mov QWORD PTR [rip+h_in_pos],0
 mov QWORD PTR [rip+h_in_end],rax
.Lfill_return:
 add rsp,8
.Lfill_done:
 ret
.Lfill_bad:
 mov rax,-74
 jmp .Lfill_return

h_getbyte:
 sub rsp,8
 call h_fill
 test rax,rax
 js .Lbyte_done
 jz .Lbyte_eof
 mov rdx,QWORD PTR [rip+h_in_pos]
 lea rdi,[rip+h_input]
 movzx eax,BYTE PTR [rdi+rdx]
 inc rdx
 mov QWORD PTR [rip+h_in_pos],rdx
 jmp .Lbyte_done
.Lbyte_eof:
 mov rax,-74
.Lbyte_done:
 add rsp,8
 ret

# Strict CRLF line, bounded both per-line and per-headersection.
h_getline:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 xor ebx,ebx
.Lline_byte:
 call h_getbyte
 test rax,rax
 js .Lline_done
 cmp al,13
 je .Lline_cr
 cmp al,10
 je .Lline_bad
 cmp al,9
 je .Lline_store
 cmp al,32
 jb .Lline_bad
 cmp al,127
 je .Lline_bad
.Lline_store:
 cmp rbx,r13
 jae .Lline_limit
 mov BYTE PTR [r12+rbx],al
 inc rbx
 jmp .Lline_byte
.Lline_cr:
 call h_getbyte
 test rax,rax
 js .Lline_done
 cmp rax,10
 jne .Lline_bad
 mov BYTE PTR [r12+rbx],0
 mov rax,QWORD PTR [rip+h_header_total]
 lea rax,[rax+rbx+2]
 cmp rax,H_LINE
 ja .Lline_limit
 mov QWORD PTR [rip+h_header_total],rax
 mov rax,rbx
 jmp .Lline_done
.Lline_bad:
 mov rax,-74
 jmp .Lline_done
.Lline_limit:
 mov rax,-75
.Lline_done:
 pop r13
 pop r12
 pop rbx
 ret

h_status_line:
 cmp rax,12
 jb .Lstatus_bad
 lea r8,[rip+h_line]
 # Compare HTTP/1. prefix separately, permitting HTTP/1.0 and HTTP/1.1.
 movabs rdx,0x002e312f50545448
 mov rcx,QWORD PTR [r8]
 movabs r9,0x00ffffffffffffff
 and rcx,r9
 cmp rcx,rdx
 jne .Lstatus_bad
 mov dl,BYTE PTR [r8+7]
 cmp dl,48
 je .Lstatus_version
 cmp dl,49
 jne .Lstatus_bad
.Lstatus_version:
 xor edx,edx
 cmp BYTE PTR [r8+7],49
 sete dl
 mov QWORD PTR [rip+h_http11],rdx
 cmp BYTE PTR [r8+8],32
 jne .Lstatus_bad
 cmp rax,12
 je .Lstatus_digits
 cmp BYTE PTR [r8+12],32
 jne .Lstatus_bad
.Lstatus_digits:
 xor eax,eax
 mov ecx,9
.Lstatus_digit:
 movzx edx,BYTE PTR [r8+rcx]
 sub edx,48
 cmp edx,9
 ja .Lstatus_bad
 imul eax,eax,10
 add eax,edx
 inc ecx
 cmp ecx,12
 jb .Lstatus_digit
 cmp eax,100
 jb .Lstatus_bad
 cmp eax,599
 ja .Lstatus_bad
 mov QWORD PTR [rip+h_status_code],rax
 xor eax,eax
 ret
.Lstatus_bad:
 mov rax,-74
 ret

h_parse_header:
 push rbx
 push r12
 push r13
 lea r12,[rip+h_line]
 xor ebx,ebx
 lea r9,[rip+h_tchar]
.Lheader_name:
 movzx eax,BYTE PTR [r12+rbx]
 cmp al,58
 je .Lheader_colon
 cmp BYTE PTR [r9+rax],1
 jne .Lheader_bad
 cmp al,65
 jb .Lheader_next
 cmp al,90
 ja .Lheader_next
 add al,32
 mov BYTE PTR [r12+rbx],al
.Lheader_next:
 inc rbx
 jmp .Lheader_name
.Lheader_colon:
 test rbx,rbx
 jz .Lheader_bad
 mov BYTE PTR [r12+rbx],0
 lea r13,[r12+rbx+1]
.Lheader_ltrim:
 mov al,BYTE PTR [r13]
 cmp al,32
 je .Lheader_trim_next
 cmp al,9
 jne .Lheader_value_end
.Lheader_trim_next:
 inc r13
 jmp .Lheader_ltrim
.Lheader_value_end:
 mov rbx,r13
.Lheader_value_scan:
 cmp BYTE PTR [rbx],0
 je .Lheader_rtrim
 inc rbx
 jmp .Lheader_value_scan
.Lheader_rtrim:
 cmp rbx,r13
 jbe .Lheader_identify
 mov al,BYTE PTR [rbx-1]
 cmp al,32
 je .Lheader_trim_back
 cmp al,9
 jne .Lheader_identify
.Lheader_trim_back:
 dec rbx
 mov BYTE PTR [rbx],0
 jmp .Lheader_rtrim
.Lheader_identify:
 mov rdi,r12
 lea rsi,[rip+h_key_cl]
 call h_equal
 test eax,eax
 jnz .Lheader_length
 mov rdi,r12
 lea rsi,[rip+h_key_te]
 call h_equal
 test eax,eax
 jnz .Lheader_encoding
 mov rdi,r12
 lea rsi,[rip+h_key_connection]
 call h_equal
 test eax,eax
 jnz .Lheader_connection
 xor eax,eax
 jmp .Lheader_done
.Lheader_length:
 cmp QWORD PTR [rip+h_trailer],0
 jne .Lheader_bad
 cmp QWORD PTR [rip+h_have_cl],0
 jne .Lheader_bad
 cmp r13,rbx
 je .Lheader_bad
 xor eax,eax
 mov r8,r13
.Lheader_decimal:
 cmp r8,rbx
 jae .Lheader_length_store
 movzx edx,BYTE PTR [r8]
 sub edx,48
 cmp edx,9
 ja .Lheader_bad
 imul rax,rax,10
 add rax,rdx
 cmp rax,H_BODY_MAX
 ja .Lheader_limit
 inc r8
 jmp .Lheader_decimal
.Lheader_length_store:
 mov QWORD PTR [rip+h_content_length],rax
 mov QWORD PTR [rip+h_have_cl],1
 xor eax,eax
 jmp .Lheader_done
.Lheader_encoding:
 cmp QWORD PTR [rip+h_trailer],0
 jne .Lheader_bad
 cmp QWORD PTR [rip+h_have_te],0
 jne .Lheader_bad
 mov rax,rbx
 sub rax,r13
 cmp rax,7
 jne .Lheader_bad
 xor ecx,ecx
 lea r8,[rip+h_chunked]
.Lheader_encoding_check:
 mov al,BYTE PTR [r13+rcx]
 cmp al,65
 jb .Lheader_encoding_lower
 cmp al,90
 ja .Lheader_encoding_lower
 add al,32
.Lheader_encoding_lower:
 cmp al,BYTE PTR [r8+rcx]
 jne .Lheader_bad
 inc rcx
 cmp rcx,7
 jb .Lheader_encoding_check
 mov QWORD PTR [rip+h_have_te],1
 xor eax,eax
 jmp .Lheader_done
.Lheader_connection:
 # Unknown/comma-list hop options conservatively disable reuse; no option can
 # override a close already observed in another header/interim response.
 mov rax,rbx
 sub rax,r13
 cmp rax,10
 jne .Lheader_connection_close
 lea r8,[rip+h_keepalive]
 xor ecx,ecx
.Lheader_connection_check:
 mov al,BYTE PTR [r13+rcx]
 cmp al,65
 jb .Lheader_connection_lower
 cmp al,90
 ja .Lheader_connection_lower
 add al,32
.Lheader_connection_lower:
 cmp al,BYTE PTR [r8+rcx]
 jne .Lheader_connection_close
 inc ecx
 cmp ecx,10
 jb .Lheader_connection_check
 xor eax,eax
 jmp .Lheader_done
.Lheader_connection_close:
 mov QWORD PTR [rip+h_response_close],1
 xor eax,eax
 jmp .Lheader_done
.Lheader_bad:
 mov rax,-74
 jmp .Lheader_done
.Lheader_limit:
 mov rax,-75
.Lheader_done:
 pop r13
 pop r12
 pop rbx
 ret

h_chunk_size:
 lea r8,[rip+h_line]
 lea r9,[rip+h_hex]
 xor eax,eax
 xor ecx,ecx
.Lchunk_digit:
 movzx edx,BYTE PTR [r8+rcx]
 movzx edx,BYTE PTR [r9+rdx]
 cmp edx,255
 je .Lchunk_end
 shl rax,4
 add rax,rdx
 cmp rax,H_BODY_MAX
 ja .Lchunk_limit
 inc rcx
 jmp .Lchunk_digit
.Lchunk_end:
 test rcx,rcx
 jz .Lchunk_bad
 cmp BYTE PTR [r8+rcx],0
 je .Lchunk_good
 cmp BYTE PTR [r8+rcx],59
 jne .Lchunk_bad
.Lchunk_good:
 ret
.Lchunk_bad:
 mov rax,-74
 ret
.Lchunk_limit:
 mov rax,-75
 ret

# Copy exactly the current framing length. EOF before completion is an error.
h_copy_length:
 push rbx
 push r12
 sub rsp,8
.Lcopy_length_loop:
 cmp QWORD PTR [rip+h_remaining],0
 je .Lcopy_length_good
 call h_fill
 test rax,rax
 js .Lcopy_length_done
 jz .Lcopy_length_bad
 mov r12,rax
 mov rax,QWORD PTR [rip+h_remaining]
 cmp r12,rax
 cmova r12,rax
 lea rdi,[rip+h_input]
 add rdi,QWORD PTR [rip+h_in_pos]
 mov rsi,r12
 call h_emit
 test rax,rax
 js .Lcopy_length_done
 add QWORD PTR [rip+h_in_pos],r12
 sub QWORD PTR [rip+h_remaining],r12
 jmp .Lcopy_length_loop
.Lcopy_length_good:
 xor eax,eax
 jmp .Lcopy_length_done
.Lcopy_length_bad:
 mov rax,-74
.Lcopy_length_done:
 add rsp,8
 pop r12
 pop rbx
 ret

h_emit:
 push rbx
 test rsi,rsi
 jz .Lemit_good
 mov rax,QWORD PTR [rip+h_total]
 add rax,rsi
 cmp rax,H_BODY_MAX
 ja .Lemit_limit
 mov QWORD PTR [rip+h_total],rax
 mov rbx,QWORD PTR [rip+h_callback]
 test rbx,rbx
 jz .Lemit_good
 call rbx
 test rax,rax
 jnz .Lemit_abort
.Lemit_good:
 xor eax,eax
 jmp .Lemit_done
.Lemit_abort:
 mov rax,-125
 jmp .Lemit_done
.Lemit_limit:
 mov rax,-75
.Lemit_done:
 pop rbx
 ret

.section .note.GNU-stack,"",@progbits
