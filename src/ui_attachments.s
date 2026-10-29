# Explicit @file input expansion. Production code uses syscalls only.
# Returns an OpenAI content array, keeping the user's prompt as its first part.
# Unresolved mentions remain literal, as in the reference. Regular files only;
# nonblocking open prevents a pasted FIFO path from hanging the composer.
.include "abi.inc"
.equ AT_FILE_LIMIT,262144
.section .rodata
.At_open: .ascii "[{\"type\":\"text\",\"text\":"
.equ At_open_len,.-.At_open
.At_text: .ascii ",{\"type\":\"text\",\"text\":"
.equ At_text_len,.-.At_text
.At_image: .ascii ",{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:"
.equ At_image_len,.-.At_image
.At_png: .asciz "image/png"
.At_jpeg: .asciz "image/jpeg"
.At_gif: .asciz "image/gif"
.At_webp: .asciz "image/webp"
.At_base64: .ascii ";base64,"
.At_image_end: .ascii "\",\"detail\":\"auto\"}}"
.equ At_image_end_len,.-.At_image_end
.At_header: .ascii "--- Content from "
.equ At_header_len,.-.At_header
.At_header_end: .ascii " ---\n"
.At_footer: .ascii "\n--- End of content ---"
.equ At_footer_len,.-.At_footer
.At_alphabet: .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
.At_error: .asciz "Attachment exceeds the input limit or contains invalid text. No request was sent."
.section .bss
.balign 16
.At_builder: .skip 24
.At_prompt: .skip 8
.At_length: .skip 8
.At_position: .skip 8
.At_count: .skip 8
.At_size: .skip 8
.At_fd: .skip 8
.At_mime: .skip 8
.At_path: .skip 4096
.At_stat: .skip 144
.At_file: .skip AT_FILE_LIMIT+1
.At_textbuf: .skip AT_FILE_LIMIT+8192
.At_encoded: .skip 4*((AT_FILE_LIMIT+2)/3)
.section .text
.global ui_attachment_content,ui_attachment_count,ui_attachment_error
ui_attachment_count:
 mov rax,[rip+.At_count]
 ret
ui_attachment_error:
 lea rax,[rip+.At_error]
 ret
# (prompt,len,out,capacity) -> array length,0 without attachment,negative failure.
ui_attachment_content:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov [rip+.At_prompt],rdi
 mov [rip+.At_length],rsi
 mov [rip+.At_builder],rdx
 mov [rip+.At_builder+8],rcx
 mov qword ptr [rip+.At_builder+16],0
 mov qword ptr [rip+.At_count],0
 mov qword ptr [rip+.At_position],0
 lea rdi,[rip+.At_builder]
 lea rsi,[rip+.At_open]
 mov edx,At_open_len
 call qx_cat@PLT
 test rax,rax
 js .At_bad
 lea rdi,[rip+.At_builder]
 mov rsi,[rip+.At_prompt]
 mov rdx,[rip+.At_length]
 call qx_quote_cat@PLT
 test rax,rax
 js .At_bad
 call .At_close_part
 test rax,rax
 js .At_bad
.At_scan:
 mov r12,[rip+.At_position]
 cmp r12,[rip+.At_length]
 jae .At_finish
 mov r13,[rip+.At_prompt]
 movzx eax,byte ptr [r13+r12]
 inc r12
 mov [rip+.At_position],r12
 cmp al,'@'
 jne .At_scan
 cmp r12,1
 je .At_parse
 cmp byte ptr [r13+r12-2],92
 je .At_scan
.At_parse:
 xor ebx,ebx
 xor r14d,r14d
 cmp r12,[rip+.At_length]
 jae .At_finish
 movzx eax,byte ptr [r13+r12]
 cmp al,34
 je .At_quoted
 cmp al,39
 jne .At_path_loop
.At_quoted:
 mov r14b,al
 inc r12
.At_path_loop:
 cmp r12,[rip+.At_length]
 jae .At_path_done
 movzx eax,byte ptr [r13+r12]
 inc r12
 test r14b,r14b
 jz .At_unquoted
 cmp al,r14b
 je .At_path_done
 jmp .At_escape
.At_unquoted:
 cmp al,32
 jbe .At_path_done
 cmp al,','
 je .At_path_done
 cmp al,';'
 je .At_path_done
 cmp al,'!'
 je .At_path_done
 cmp al,'?'
 je .At_path_done
 cmp al,')'
 je .At_path_done
.At_escape:
 cmp al,92
 jne .At_store
 cmp r12,[rip+.At_length]
 jae .At_path_done
 movzx eax,byte ptr [r13+r12]
 inc r12
.At_store:
 cmp ebx,4095
 jae .At_skip_long
 cmp al,32
 jb .At_skip_long
 lea rdx,[rip+.At_path]
 mov [rdx+rbx],al
 inc ebx
 jmp .At_path_loop
.At_skip_long:
 mov [rip+.At_position],r12
 jmp .At_scan
.At_path_done:
 mov [rip+.At_position],r12
 test ebx,ebx
 jz .At_scan
 lea rdi,[rip+.At_path]
 mov byte ptr [rdi+rbx],0
 # @foo. at sentence end refers to foo, not foo.
 test r14b,r14b
 jnz .At_open_file
 cmp byte ptr [rdi+rbx-1],'.'
 jne .At_open_file
 dec ebx
 mov byte ptr [rdi+rbx],0
 test ebx,ebx
 jz .At_scan
.At_open_file:
 mov eax,2
 mov esi,0x80800
 xor edx,edx
 syscall
 test rax,rax
 js .At_scan
 mov [rip+.At_fd],rax
 mov rdi,rax
 lea rsi,[rip+.At_stat]
 mov eax,5
 syscall
 test rax,rax
 js .At_skip_file
 mov eax,[rip+.At_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .At_skip_file
 cmp qword ptr [rip+.At_stat+48],AT_FILE_LIMIT
 ja .At_close_bad
 xor r15d,r15d
.At_read:
 mov eax,0
 mov rdi,[rip+.At_fd]
 lea rsi,[rip+.At_file]
 add rsi,r15
 mov edx,AT_FILE_LIMIT+1
 sub rdx,r15
 syscall
 cmp rax,-4
 je .At_read
 test rax,rax
 js .At_skip_file
 jz .At_read_done
 add r15,rax
 cmp r15,AT_FILE_LIMIT
 ja .At_close_bad
 jmp .At_read
.At_skip_file:
 mov eax,3
 mov rdi,[rip+.At_fd]
 syscall
 jmp .At_scan
.At_close_bad:
 mov eax,3
 mov rdi,[rip+.At_fd]
 syscall
 jmp .At_bad
.At_read_done:
 mov eax,3
 mov rdi,[rip+.At_fd]
 syscall
 mov [rip+.At_size],r15
 mov qword ptr [rip+.At_mime],0
 lea rdi,[rip+.At_file]
 cmp r15,8
 jb .At_text_file
 mov rax,0x0a1a0a0d474e5089
 cmp [rdi],rax
 jne .At_jpeg_test
 lea rax,[rip+.At_png]
 jmp .At_image_file
.At_jpeg_test:
 cmp word ptr [rdi],0xd8ff
 jne .At_gif_test
 cmp byte ptr [rdi+2],0xff
 jne .At_gif_test
 lea rax,[rip+.At_jpeg]
 jmp .At_image_file
.At_gif_test:
 cmp dword ptr [rdi],0x38464947
 jne .At_webp_test
 cmp word ptr [rdi+4],0x6137
 je .At_gif_yes
 cmp word ptr [rdi+4],0x6139
 jne .At_webp_test
.At_gif_yes:
 lea rax,[rip+.At_gif]
 jmp .At_image_file
.At_webp_test:
 cmp r15,12
 jb .At_text_file
 cmp dword ptr [rdi],0x46464952
 jne .At_text_file
 cmp dword ptr [rdi+8],0x50424557
 jne .At_text_file
 lea rax,[rip+.At_webp]
 jmp .At_image_file
.At_text_file:
 # Binary NUL data is never silently passed as text.
 mov rcx,r15
 test rcx,rcx
 jz .At_text_copy
 xor eax,eax
 repne scasb
 je .At_bad
.At_text_copy:
 lea rdi,[rip+.At_textbuf]
 lea rsi,[rip+.At_header]
 mov ecx,At_header_len
 rep movsb
 lea rsi,[rip+.At_path]
 mov ecx,ebx
 rep movsb
 lea rsi,[rip+.At_header_end]
 mov ecx,5
 rep movsb
 lea rsi,[rip+.At_file]
 mov rcx,r15
 rep movsb
 lea rsi,[rip+.At_footer]
 mov ecx,At_footer_len
 rep movsb
 lea rdx,[rip+.At_textbuf]
 sub rdi,rdx
 mov r15,rdi
 lea rdi,[rip+.At_builder]
 lea rsi,[rip+.At_text]
 mov edx,At_text_len
 call qx_cat@PLT
 test rax,rax
 js .At_bad
 lea rdi,[rip+.At_builder]
 lea rsi,[rip+.At_textbuf]
 mov rdx,r15
 call qx_quote_cat@PLT
 test rax,rax
 js .At_bad
 call .At_close_part
 test rax,rax
 js .At_bad
 jmp .At_added
.At_image_file:
 mov [rip+.At_mime],rax
 lea rdi,[rip+.At_builder]
 lea rsi,[rip+.At_image]
 mov edx,At_image_len
 call qx_cat@PLT
 test rax,rax
 js .At_bad
 mov rdi,[rip+.At_mime]
 call qx_strlen@PLT
 mov rdx,rax
 mov rsi,[rip+.At_mime]
 lea rdi,[rip+.At_builder]
 call qx_cat@PLT
 test rax,rax
 js .At_bad
 lea rdi,[rip+.At_builder]
 lea rsi,[rip+.At_base64]
 mov edx,8
 call qx_cat@PLT
 test rax,rax
 js .At_bad
 lea r12,[rip+.At_file]
 lea r13,[rip+.At_encoded]
 lea r14,[rip+.At_alphabet]
 mov r15,[rip+.At_size]
 xor ebx,ebx
 xor ebp,ebp
.At_encode:
 cmp rbx,r15
 jae .At_encoded_done
 movzx eax,byte ptr [r12+rbx]
 shl eax,16
 lea rcx,[rbx+1]
 cmp rcx,r15
 jae .At_encode_bits
 movzx edx,byte ptr [r12+rbx+1]
 shl edx,8
 or eax,edx
 lea rcx,[rbx+2]
 cmp rcx,r15
 jae .At_encode_bits
 movzx edx,byte ptr [r12+rbx+2]
 or eax,edx
.At_encode_bits:
 mov edx,eax
 shr edx,18
 mov dl,[r14+rdx]
 mov [r13+rbp],dl
 mov edx,eax
 shr edx,12
 and edx,63
 mov dl,[r14+rdx]
 mov [r13+rbp+1],dl
 mov byte ptr [r13+rbp+2],'='
 mov byte ptr [r13+rbp+3],'='
 lea rcx,[rbx+1]
 cmp rcx,r15
 jae .At_encoded_next
 mov edx,eax
 shr edx,6
 and edx,63
 mov dl,[r14+rdx]
 mov [r13+rbp+2],dl
 lea rcx,[rbx+2]
 cmp rcx,r15
 jae .At_encoded_next
 and eax,63
 mov al,[r14+rax]
 mov [r13+rbp+3],al
.At_encoded_next:
 add rbx,3
 add rbp,4
 jmp .At_encode
.At_encoded_done:
 lea rdi,[rip+.At_builder]
 mov rsi,r13
 mov rdx,rbp
 call qx_cat@PLT
 test rax,rax
 js .At_bad
 lea rdi,[rip+.At_builder]
 lea rsi,[rip+.At_image_end]
 mov edx,At_image_end_len
 call qx_cat@PLT
 test rax,rax
 js .At_bad
.At_added:
 inc qword ptr [rip+.At_count]
 jmp .At_scan
.At_finish:
 xor eax,eax
 cmp qword ptr [rip+.At_count],0
 je .At_return
 mov rax,[rip+.At_builder+16]
 cmp rax,[rip+.At_builder+8]
 jae .At_bad
 mov rdx,[rip+.At_builder]
 mov byte ptr [rdx+rax],']'
 inc rax
 jmp .At_return
.At_bad:
 mov rax,-1
.At_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.At_close_part:
 mov rax,[rip+.At_builder+16]
 cmp rax,[rip+.At_builder+8]
 jae .At_part_bad
 mov rdx,[rip+.At_builder]
 mov byte ptr [rdx+rax],'}'
 inc qword ptr [rip+.At_builder+16]
 xor eax,eax
 ret
.At_part_bad:
 mov rax,-1
 ret
.section .note.GNU-stack,"",@progbits
