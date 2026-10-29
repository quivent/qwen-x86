# Strict TLS 1.3 client profile, native x86-64 application membrane.
# AES_128_GCM_SHA256 / X25519 / RSA_PSS_RSAE_SHA256 only. No fallback,
# external executable, library, plaintext HTTP, certificate pin or insecure mode.
# Single connection context per process; forked workers own private BSS pages.
.include "abi.inc"
.intel_syntax noprefix
.equ TLS_RECORD_MAX,16640
.equ TLS_CERT_MAX,65536
.equ TLS_HS_MAX,131072
.equ TLS_TRANSCRIPT_MAX,131072
.macro TLS_ENTER frame=8
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,\frame
.endm
.macro TLS_LEAVE frame=8
 add rsp,\frame
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.endm
.macro TL_ADDR reg,label
 lea \reg,[rip+\label]
.endm
.macro TL_LABEL secret,label,context,contextlen,out,outlen
 TL_ADDR rdi,\secret
 TL_ADDR rsi,\label
 TL_ADDR rdx,\context
 mov ecx,\contextlen
 TL_ADDR r8,\out
 mov r9d,\outlen
 call tls_hkdf_label
 test rax,rax
 jns .Ltls_label_ok\@
 call .Ltls_kdf_fail
 TLS_LEAVE
.Ltls_label_ok\@:
.endm

.globl tls_error
.type tls_error,@function
tls_error:
 mov rax,[rip+.Ltls_error_ptr]
 TL_ADDR rdx,.Lerr_none
 test rax,rax
 cmovz rax,rdx
 ret
.size tls_error,.-tls_error
.Ltls_set_error:
 mov [rip+.Ltls_error_ptr],rdi
 mov rax,-1
 ret
.Ltls_bad_record:
 TL_ADDR rdi,.Lerr_record
 jmp .Ltls_set_error
.Ltls_io_fail:
 TL_ADDR rdi,.Lerr_io
 jmp .Ltls_set_error
.Ltls_bad_handshake:
 TL_ADDR rdi,.Lerr_handshake
 jmp .Ltls_set_error
.Ltls_kdf_fail:
 TL_ADDR rdi,.Lerr_kdf
 jmp .Ltls_set_error
.Ltls_erase:
 TL_ADDR rdi,.Ltls_state_begin
 mov ecx,.Ltls_state_end-.Ltls_state_begin
 xor eax,eax
 rep stosb
 mov qword ptr [rip+.Ltls_fd],-1
 ret

# Exact byte acquisition keeps partial I/O and late EOF separate from parsing.
.Ltls_read_exact:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
.Ltls_exact_loop:
 test r13,r13
 jz .Ltls_exact_done
 mov rdi,[rip+.Ltls_fd]
 mov rsi,r12
 mov rdx,r13
 call net_read
 test rax,rax
 jle .Ltls_exact_bad
 cmp rax,r13
 ja .Ltls_exact_bad
 add r12,rax
 sub r13,rax
 jmp .Ltls_exact_loop
.Ltls_exact_bad:
 call .Ltls_io_fail
 jmp .Ltls_exact_return
.Ltls_exact_done:
 xor eax,eax
.Ltls_exact_return:
 pop r13
 pop r12
 pop rbx
 ret

# Constant-time byte comparison: length and addresses are public extents.
.Ltls_equal:
 xor eax,eax
 xor ecx,ecx
.Ltls_equal_loop:
 cmp rcx,rdx
 jae .Ltls_equal_done
 mov r8b,[rdi+rcx]
 xor r8b,[rsi+rcx]
 or al,r8b
 inc rcx
 jmp .Ltls_equal_loop
.Ltls_equal_done:
 test al,al
 sete al
 movzx eax,al
 ret

.Ltls_hash_transcript:
 TL_ADDR rdi,.Ltls_transcript
 mov rsi,[rip+.Ltls_transcript_len]
 TL_ADDR rdx,.Ltls_hash
 jmp sha256_hash

# Append already-validated handshake message bytes (including the 4-byte header).
.Ltls_append:
 mov rax,[rip+.Ltls_transcript_len]
 mov rdx,rax
 add rdx,rsi
 jc .Ltls_bad_handshake
 cmp rdx,TLS_TRANSCRIPT_MAX
 ja .Ltls_bad_handshake
 mov [rip+.Ltls_transcript_len],rdx
 mov rcx,rsi
 mov rsi,rdi
 TL_ADDR rdi,.Ltls_transcript
 add rdi,rax
 rep movsb
 xor eax,eax
 ret

.Ltls_random_fill:
 push rbx
 push r12
 sub rsp,8
 TL_ADDR r12,.Ltls_random
 mov ebx,64
.Ltls_random_loop:
 mov eax,318
 mov rdi,r12
 mov rsi,rbx
 xor edx,edx
 syscall
 cmp rax,-4
 je .Ltls_random_loop
 test rax,rax
 jle .Ltls_random_bad
 add r12,rax
 sub rbx,rax
 jnz .Ltls_random_loop
 xor eax,eax
 jmp .Ltls_random_return
.Ltls_random_bad:
 TL_ADDR rdi,.Lerr_random
 call .Ltls_set_error
.Ltls_random_return:
 add rsp,8
 pop r12
 pop rbx
 ret

# Build a bounded ClientHello. Immutable extension records are bound data; only
# random, hostname and X25519 share arrive at runtime.
.Ltls_client_hello:
 TLS_ENTER
 call .Ltls_random_fill
 test rax,rax
 js .Ltls_ch_return
 TL_ADDR rdi,.Ltls_scalar
 TL_ADDR rsi,.Ltls_basepoint
 TL_ADDR rdx,.Ltls_public
 call x25519
 test rax,rax
 jne .Ltls_ch_bad
 TL_ADDR r12,.Ltls_hs_out
 mov byte ptr [r12],1
 mov word ptr [r12+4],0x0303
 lea rdi,[r12+6]
 TL_ADDR rsi,.Ltls_random
 mov ecx,32
 rep movsb
 mov byte ptr [rdi],0
 mov word ptr [rdi+1],0x0200
 mov word ptr [rdi+3],0x0113
 mov byte ptr [rdi+5],1
 mov byte ptr [rdi+6],0
 add rdi,9
 mov r13,rdi
 # SNI extension, list and host lengths are network-order 16-bit values.
 mov word ptr [rdi],0
 mov rax,[rip+.Ltls_hostname_len]
 add eax,5
 rol ax,8
 mov [rdi+2],ax
 mov rax,[rip+.Ltls_hostname_len]
 add eax,3
 rol ax,8
 mov [rdi+4],ax
 mov byte ptr [rdi+6],0
 mov rax,[rip+.Ltls_hostname_len]
 rol ax,8
 mov [rdi+7],ax
 add rdi,9
 TL_ADDR rsi,.Ltls_hostname
 mov rcx,[rip+.Ltls_hostname_len]
 rep movsb
 TL_ADDR rsi,.Ltls_ch_extensions
 mov ecx,.Ltls_ch_extensions_end-.Ltls_ch_extensions
 rep movsb
 # key_share extension: one X25519 entry.
 mov dword ptr [rdi],0x26003300
 mov dword ptr [rdi+4],0x1d002400
 mov word ptr [rdi+8],0x2000
 add rdi,10
 TL_ADDR rsi,.Ltls_public
 mov ecx,32
 rep movsb
 TL_ADDR rsi,.Ltls_alpn_extension
 mov ecx,.Ltls_alpn_extension_end-.Ltls_alpn_extension
 rep movsb
 mov rax,rdi
 sub rax,r13
 rol ax,8
 mov [r13-2],ax
 mov rbx,rdi
 sub rbx,r12
 mov rax,rbx
 sub eax,4
 bswap eax
 shr eax,8
 mov byte ptr [r12+1],al
 shr eax,8
 mov byte ptr [r12+2],al
 shr eax,8
 mov byte ptr [r12+3],al
 mov rdi,r12
 mov rsi,rbx
 call .Ltls_append
 test rax,rax
 js .Ltls_ch_return
 TL_ADDR rdi,.Ltls_wire
 mov byte ptr [rdi],22
 mov word ptr [rdi+1],0x0103
 mov rax,rbx
 rol ax,8
 mov [rdi+3],ax
 add rdi,5
 mov rsi,r12
 mov rcx,rbx
 rep movsb
 mov rdi,[rip+.Ltls_fd]
 TL_ADDR rsi,.Ltls_wire
 lea rdx,[rbx+5]
 call net_write
 test rax,rax
 js .Ltls_ch_bad
 xor eax,eax
 jmp .Ltls_ch_return
.Ltls_ch_bad:
 TL_ADDR rdi,.Lerr_handshake
 call .Ltls_set_error
.Ltls_ch_return:
 TLS_LEAVE

# Make nonce = static_iv XOR padded big-endian sequence number.
# rdi IV12, rsi sequence, rdx nonce12. No sequence wrap is admitted.
.Ltls_nonce:
 mov eax,[rdi]
 mov [rdx],eax
 mov rax,[rdi+4]
 bswap rsi
 xor rax,rsi
 mov [rdx+4],rax
 ret

# Read one authenticated record into .Ltls_plain. rax=content bytes, edx=type.
# Authentication completes before any plaintext is handed to the state machine.
.Ltls_record:
 TLS_ENTER
.Ltls_record_again:
 TL_ADDR rdi,.Ltls_wire
 mov esi,5
 call .Ltls_read_exact
 test rax,rax
 js .Ltls_record_return
 TL_ADDR r12,.Ltls_wire
 cmp word ptr [r12+1],0x0303
 jne .Ltls_record_bad
 movzx ebx,word ptr [r12+3]
 rol bx,8
 cmp ebx,TLS_RECORD_MAX
 ja .Ltls_record_bad
 test ebx,ebx
 jz .Ltls_record_bad
 lea rdi,[r12+5]
 mov rsi,rbx
 call .Ltls_read_exact
 test rax,rax
 js .Ltls_record_return
 movzx r13d,byte ptr [r12]
 cmp r13d,20
 je .Ltls_record_ccs
 cmp qword ptr [rip+.Ltls_phase],0
 je .Ltls_record_clear
 cmp r13d,23
 jne .Ltls_record_bad
 cmp ebx,17
 jb .Ltls_record_bad
 mov rsi,[rip+.Ltls_read_seq]
 cmp rsi,-1
 je .Ltls_record_bad
 TL_ADDR rdi,.Ltls_server_iv
 TL_ADDR rdx,.Ltls_nonce_buf
 call .Ltls_nonce
 TL_ADDR rdi,.Ltls_gcm_request
 TL_ADDR rax,.Ltls_server_roundkeys
 mov [rdi],rax
 TL_ADDR rax,.Ltls_nonce_buf
 mov [rdi+8],rax
 mov [rdi+16],r12
 mov qword ptr [rdi+24],5
 lea rax,[r12+5]
 mov [rdi+32],rax
 lea rax,[rbx-16]
 mov [rdi+40],rax
 TL_ADDR rdx,.Ltls_plain
 mov [rdi+48],rdx
 lea rdx,[r12+rax+5]
 mov [rdi+56],rdx
 call gcm_decrypt
 test rax,rax
 jne .Ltls_record_auth_fail
 inc qword ptr [rip+.Ltls_read_seq]
 sub ebx,16
 TL_ADDR r12,.Ltls_plain
.Ltls_record_strip:
 test ebx,ebx
 jz .Ltls_record_bad
 dec ebx
 movzx edx,byte ptr [r12+rbx]
 test edx,edx
 jz .Ltls_record_strip
 cmp ebx,16384
 ja .Ltls_record_bad
 cmp edx,21
 je .Ltls_record_done
 cmp edx,22
 je .Ltls_record_done
 cmp edx,23
 jne .Ltls_record_bad
.Ltls_record_done:
 mov rax,rbx
 jmp .Ltls_record_return
.Ltls_record_ccs:
 cmp qword ptr [rip+.Ltls_ready],0
 jne .Ltls_record_bad
 cmp ebx,1
 jne .Ltls_record_bad
 cmp byte ptr [r12+5],1
 jne .Ltls_record_bad
 inc qword ptr [rip+.Ltls_ccs_count]
 cmp qword ptr [rip+.Ltls_ccs_count],8
 ja .Ltls_record_bad
 jmp .Ltls_record_again
.Ltls_record_clear:
 cmp r13d,22
 je .Ltls_record_clear_copy
 cmp r13d,21
 jne .Ltls_record_bad
.Ltls_record_clear_copy:
 cmp ebx,16384
 ja .Ltls_record_bad
 TL_ADDR rdi,.Ltls_plain
 lea rsi,[r12+5]
 mov rcx,rbx
 rep movsb
 mov edx,r13d
 mov rax,rbx
 jmp .Ltls_record_return
.Ltls_record_auth_fail:
 TL_ADDR rdi,.Lerr_auth_tag
 call .Ltls_set_error
 jmp .Ltls_record_return
.Ltls_record_bad:
 call .Ltls_bad_record
.Ltls_record_return:
 TLS_LEAVE

# Emit one encrypted inner record, using current write traffic keys.
# rdi plaintext pointer, rsi length<=16384, edx inner content type.
.Ltls_send_record:
 TLS_ENTER
 mov r12,rdi
 mov r13,rsi
 mov r14d,edx
 cmp r13,16384
 ja .Ltls_send_bad
 cmp qword ptr [rip+.Ltls_phase],0
 je .Ltls_send_bad
 mov rsi,[rip+.Ltls_write_seq]
 cmp rsi,-1
 je .Ltls_send_bad
 TL_ADDR rdi,.Ltls_client_iv
 TL_ADDR rdx,.Ltls_nonce_buf
 call .Ltls_nonce
 TL_ADDR rdi,.Ltls_send_plain
 mov rsi,r12
 mov rcx,r13
 rep movsb
 mov [rdi],r14b
 TL_ADDR r12,.Ltls_wire
 mov byte ptr [r12],23
 mov word ptr [r12+1],0x0303
 lea rax,[r13+17]
 rol ax,8
 mov [r12+3],ax
 TL_ADDR rdi,.Ltls_gcm_request
 TL_ADDR rax,.Ltls_client_roundkeys
 mov [rdi],rax
 TL_ADDR rax,.Ltls_nonce_buf
 mov [rdi+8],rax
 mov [rdi+16],r12
 mov qword ptr [rdi+24],5
 TL_ADDR rax,.Ltls_send_plain
 mov [rdi+32],rax
 lea rax,[r13+1]
 mov [rdi+40],rax
 lea rdx,[r12+5]
 mov [rdi+48],rdx
 lea rdx,[r12+rax+5]
 mov [rdi+56],rdx
 call gcm_encrypt
 test rax,rax
 jne .Ltls_send_bad
 mov rdi,[rip+.Ltls_fd]
 mov rsi,r12
 lea rdx,[r13+22]
 call net_write
 test rax,rax
 js .Ltls_send_io
 inc qword ptr [rip+.Ltls_write_seq]
 xor eax,eax
 jmp .Ltls_send_return
.Ltls_send_io:
 call .Ltls_io_fail
 jmp .Ltls_send_return
.Ltls_send_bad:
 call .Ltls_bad_record
.Ltls_send_return:
 TLS_LEAVE

# Fragment acquisition is separate from handshake routing. A complete header's
# extent is known before the next message is parsed or copied into transcript.
.Ltls_get_handshake:
 TLS_ENTER
.Ltls_hs_again:
 mov rbx,[rip+.Ltls_hs_len]
 cmp rbx,4
 jb .Ltls_hs_more
 TL_ADDR r12,.Ltls_hs_buffer
 movzx eax,byte ptr [r12+1]
 shl eax,16
 movzx ecx,byte ptr [r12+2]
 shl ecx,8
 add eax,ecx
 movzx ecx,byte ptr [r12+3]
 add eax,ecx
 add eax,4
 cmp eax,TLS_CERT_MAX+8
 ja .Ltls_hs_bad
 cmp rbx,rax
 jae .Ltls_hs_return
.Ltls_hs_more:
 call .Ltls_record
 test rax,rax
 js .Ltls_hs_return
 cmp edx,22
 jne .Ltls_hs_bad
 test rax,rax
 jz .Ltls_hs_bad
 mov rcx,[rip+.Ltls_hs_len]
 mov rdx,rcx
 add rdx,rax
 jc .Ltls_hs_bad
 cmp rdx,TLS_HS_MAX
 ja .Ltls_hs_bad
 mov [rip+.Ltls_hs_len],rdx
 TL_ADDR rdi,.Ltls_hs_buffer
 add rdi,rcx
 TL_ADDR rsi,.Ltls_plain
 mov rcx,rax
 rep movsb
 jmp .Ltls_hs_again
.Ltls_hs_bad:
 call .Ltls_bad_handshake
.Ltls_hs_return:
 TLS_LEAVE
.Ltls_consume_hs:
 mov rcx,[rip+.Ltls_hs_len]
 cmp rdi,rcx
 ja .Ltls_bad_handshake
 sub rcx,rdi
 mov [rip+.Ltls_hs_len],rcx
 TL_ADDR rsi,.Ltls_hs_buffer
 add rsi,rdi
 TL_ADDR rdi,.Ltls_hs_buffer
 rep movsb
 xor eax,eax
 ret

# ServerHello admits exactly our offered cipher/version/group/key share.
.Ltls_server_hello:
 TLS_ENTER
 mov rbx,rdi
 TL_ADDR r12,.Ltls_hs_buffer
 cmp byte ptr [r12],2
 jne .Ltls_sh_bad
 cmp rbx,44
 jb .Ltls_sh_bad
 cmp word ptr [r12+4],0x0303
 jne .Ltls_sh_bad
 lea rdi,[r12+6]
 TL_ADDR rsi,.Ltls_hrr_random
 mov edx,32
 call .Ltls_equal
 test eax,eax
 jnz .Ltls_sh_bad
 cmp byte ptr [r12+38],0
 jne .Ltls_sh_bad
 cmp word ptr [r12+39],0x0113
 jne .Ltls_sh_bad
 cmp byte ptr [r12+41],0
 jne .Ltls_sh_bad
 movzx eax,word ptr [r12+42]
 rol ax,8
 add rax,44
 cmp rax,rbx
 jne .Ltls_sh_bad
 lea r13,[r12+44]
 add r12,rbx
 xor r14d,r14d
.Ltls_sh_extensions:
 cmp r13,r12
 je .Ltls_sh_extensions_done
 lea rax,[r13+4]
 cmp rax,r12
 ja .Ltls_sh_bad
 movzx ebx,word ptr [r13]
 rol bx,8
 movzx ebp,word ptr [r13+2]
 rol bp,8
 add r13,4
 lea rax,[r13+rbp]
 cmp rax,r12
 ja .Ltls_sh_bad
 cmp ebx,43
 je .Ltls_sh_version
 cmp ebx,51
 jne .Ltls_sh_bad
 test r14d,2
 jnz .Ltls_sh_bad
 cmp ebp,36
 jne .Ltls_sh_bad
 cmp word ptr [r13],0x1d00
 jne .Ltls_sh_bad
 cmp word ptr [r13+2],0x2000
 jne .Ltls_sh_bad
 TL_ADDR rdi,.Ltls_server_public
 lea rsi,[r13+4]
 mov ecx,32
 rep movsb
 or r14d,2
 jmp .Ltls_sh_next_extension
.Ltls_sh_version:
 test r14d,1
 jnz .Ltls_sh_bad
 cmp ebp,2
 jne .Ltls_sh_bad
 cmp word ptr [r13],0x0403
 jne .Ltls_sh_bad
 or r14d,1
.Ltls_sh_next_extension:
 add r13,rbp
 jmp .Ltls_sh_extensions
.Ltls_sh_extensions_done:
 cmp r14d,3
 jne .Ltls_sh_bad
 xor eax,eax
 jmp .Ltls_sh_return
.Ltls_sh_bad:
 call .Ltls_bad_handshake
.Ltls_sh_return:
 TLS_LEAVE

.Ltls_handshake_keys:
 TLS_ENTER
 TL_ADDR rdi,.Ltls_scalar
 TL_ADDR rsi,.Ltls_server_public
 TL_ADDR rdx,.Ltls_shared
 call x25519
 test rax,rax
 jne .Ltls_hk_bad
 TL_ADDR rdi,.Ltls_zeros
 mov esi,32
 TL_ADDR rdx,.Ltls_zeros
 mov ecx,32
 TL_ADDR r8,.Ltls_early_secret
 call hkdf_extract
 TL_LABEL .Ltls_early_secret,.Llabel_derived,.Ltls_empty_hash,32,.Ltls_derived,32
 TL_ADDR rdi,.Ltls_derived
 mov esi,32
 TL_ADDR rdx,.Ltls_shared
 mov ecx,32
 TL_ADDR r8,.Ltls_handshake_secret
 call hkdf_extract
 call .Ltls_hash_transcript
 TL_LABEL .Ltls_handshake_secret,.Llabel_client_hs,.Ltls_hash,32,.Ltls_client_hs,32
 TL_LABEL .Ltls_handshake_secret,.Llabel_server_hs,.Ltls_hash,32,.Ltls_server_hs,32
 TL_LABEL .Ltls_handshake_secret,.Llabel_derived,.Ltls_empty_hash,32,.Ltls_derived,32
 TL_ADDR rdi,.Ltls_derived
 mov esi,32
 TL_ADDR rdx,.Ltls_zeros
 mov ecx,32
 TL_ADDR r8,.Ltls_master_secret
 call hkdf_extract
 TL_ADDR rdi,.Ltls_client_hs
 TL_ADDR rsi,.Ltls_server_hs
 call .Ltls_traffic_keys
 test rax,rax
 js .Ltls_hk_return
 mov qword ptr [rip+.Ltls_phase],1
 xor eax,eax
 jmp .Ltls_hk_return
.Ltls_hk_bad:
 call .Ltls_kdf_fail
.Ltls_hk_return:
 TLS_LEAVE

# rdi client traffic secret32, rsi server traffic secret32.
.Ltls_traffic_keys:
 TLS_ENTER
 mov r12,rdi
 mov r13,rsi
 mov rdi,r12
 TL_ADDR rsi,.Llabel_key
 xor edx,edx
 xor ecx,ecx
 TL_ADDR r8,.Ltls_client_key
 mov r9d,16
 call tls_hkdf_label
 test rax,rax
 js .Ltls_tk_bad
 mov rdi,r13
 TL_ADDR rsi,.Llabel_key
 xor edx,edx
 xor ecx,ecx
 TL_ADDR r8,.Ltls_server_key
 mov r9d,16
 call tls_hkdf_label
 test rax,rax
 js .Ltls_tk_bad
 mov rdi,r12
 TL_ADDR rsi,.Llabel_iv
 xor edx,edx
 xor ecx,ecx
 TL_ADDR r8,.Ltls_client_iv
 mov r9d,12
 call tls_hkdf_label
 test rax,rax
 js .Ltls_tk_bad
 mov rdi,r13
 TL_ADDR rsi,.Llabel_iv
 xor edx,edx
 xor ecx,ecx
 TL_ADDR r8,.Ltls_server_iv
 mov r9d,12
 call tls_hkdf_label
 test rax,rax
 js .Ltls_tk_bad
 TL_ADDR rdi,.Ltls_client_key
 TL_ADDR rsi,.Ltls_client_roundkeys
 call aes128_expand
 test rax,rax
 jne .Ltls_tk_bad
 TL_ADDR rdi,.Ltls_server_key
 TL_ADDR rsi,.Ltls_server_roundkeys
 call aes128_expand
 test rax,rax
 jne .Ltls_tk_bad
 mov qword ptr [rip+.Ltls_read_seq],0
 mov qword ptr [rip+.Ltls_write_seq],0
 xor eax,eax
 jmp .Ltls_tk_return
.Ltls_tk_bad:
 call .Ltls_kdf_fail
.Ltls_tk_return:
 TLS_LEAVE

# EncryptedExtensions: SNI acknowledgment, supported_groups and optional ALPN.
# Unoffered extension types, duplicates and alternate ALPN are rejected.
.Ltls_encrypted_extensions:
 TLS_ENTER
 TL_ADDR r12,.Ltls_hs_buffer
 cmp byte ptr [r12],8
 jne .Ltls_ee_bad
 cmp rdi,6
 jb .Ltls_ee_bad
 movzx eax,word ptr [r12+4]
 rol ax,8
 add rax,6
 cmp rax,rdi
 jne .Ltls_ee_bad
 lea r13,[r12+rdi]
 add r12,6
 xor r14d,r14d
.Ltls_ee_loop:
 cmp r12,r13
 je .Ltls_ee_done
 lea rax,[r12+4]
 cmp rax,r13
 ja .Ltls_ee_bad
 movzx ebx,word ptr [r12]
 rol bx,8
 movzx ebp,word ptr [r12+2]
 rol bp,8
 add r12,4
 lea rax,[r12+rbp]
 cmp rax,r13
 ja .Ltls_ee_bad
 cmp ebx,0
 je .Ltls_ee_sni
 cmp ebx,16
 je .Ltls_ee_alpn
 cmp ebx,10
 jne .Ltls_ee_bad
 test r14d,4
 jnz .Ltls_ee_bad
 or r14d,4
 cmp ebp,4
 jb .Ltls_ee_bad
 movzx eax,word ptr [r12]
 rol ax,8
 add eax,2
 cmp eax,ebp
 jne .Ltls_ee_bad
 test ebp,1
 jnz .Ltls_ee_bad
 jmp .Ltls_ee_next
.Ltls_ee_sni:
 test r14d,1
 jnz .Ltls_ee_bad
 or r14d,1
 test ebp,ebp
 jnz .Ltls_ee_bad
 jmp .Ltls_ee_next
.Ltls_ee_alpn:
 test r14d,2
 jnz .Ltls_ee_bad
 or r14d,2
 cmp ebp,11
 jne .Ltls_ee_bad
 mov rdi,r12
 TL_ADDR rsi,.Ltls_alpn_value
 mov edx,11
 call .Ltls_equal
 test eax,eax
 jz .Ltls_ee_bad
.Ltls_ee_next:
 add r12,rbp
 jmp .Ltls_ee_loop
.Ltls_ee_done:
 xor eax,eax
 jmp .Ltls_ee_return
.Ltls_ee_bad:
 call .Ltls_bad_handshake
.Ltls_ee_return:
 TLS_LEAVE

# Certificate bytes are copied before parsing: token pointers stay stable even
# when later fragmented handshake messages shift in the acquisition buffer.
.Ltls_certificate:
 TLS_ENTER
 mov rbx,rdi
 TL_ADDR rsi,.Ltls_hs_buffer
 cmp byte ptr [rsi],11
 jne .Ltls_cert_bad
 cmp rbx,8
 jb .Ltls_cert_bad
 cmp rbx,TLS_CERT_MAX+8
 ja .Ltls_cert_bad
 TL_ADDR rdi,.Ltls_certificate_buffer
 mov rcx,rbx
 rep movsb
 TL_ADDR r12,.Ltls_certificate_buffer
 cmp byte ptr [r12+4],0
 jne .Ltls_cert_bad
 movzx eax,byte ptr [r12+5]
 shl eax,16
 movzx ecx,byte ptr [r12+6]
 shl ecx,8
 add eax,ecx
 movzx ecx,byte ptr [r12+7]
 add eax,ecx
 add eax,8
 cmp rax,rbx
 jne .Ltls_cert_bad
 lea r13,[r12+rbx]
 add r12,8
 xor r14d,r14d
.Ltls_cert_loop:
 cmp r12,r13
 je .Ltls_cert_chain
 cmp r14d,8
 jae .Ltls_cert_bad
 lea rax,[r12+3]
 cmp rax,r13
 ja .Ltls_cert_bad
 movzx ebp,byte ptr [r12]
 shl ebp,16
 movzx ecx,byte ptr [r12+1]
 shl ecx,8
 add ebp,ecx
 movzx ecx,byte ptr [r12+2]
 add ebp,ecx
 test ebp,ebp
 jz .Ltls_cert_bad
 add r12,3
 lea rax,[r12+rbp+2]
 cmp rax,r13
 ja .Ltls_cert_bad
 imul edx,r14d,224
 TL_ADDR r15,.Ltls_certificates
 add rdx,r15
 mov rdi,r12
 mov rsi,rbp
 call x509_parse
 test rax,rax
 js .Ltls_cert_chain_bad
 add r12,rbp
 movzx eax,word ptr [r12]
 rol ax,8
 add r12,2
 add r12,rax
 cmp r12,r13
 ja .Ltls_cert_bad
 inc r14d
 jmp .Ltls_cert_loop
.Ltls_cert_chain:
 test r14d,r14d
 jz .Ltls_cert_bad
 TL_ADDR rdi,.Ltls_certificates
 mov rsi,r14
 TL_ADDR rdx,.Ltls_hostname
 mov rcx,[rip+.Ltls_ca_path]
 call x509_verify_chain
 test rax,rax
 jne .Ltls_cert_chain_bad
 xor eax,eax
 jmp .Ltls_cert_return
.Ltls_cert_chain_bad:
 TL_ADDR rdi,.Lerr_certificate
 call .Ltls_set_error
 jmp .Ltls_cert_return
.Ltls_cert_bad:
 call .Ltls_bad_handshake
.Ltls_cert_return:
 TLS_LEAVE

.Ltls_certificate_verify:
 TLS_ENTER
 mov rbx,rdi
 TL_ADDR r12,.Ltls_hs_buffer
 cmp byte ptr [r12],15
 jne .Ltls_cv_bad
 cmp rbx,8
 jb .Ltls_cv_bad
 cmp word ptr [r12+4],0x0408
 jne .Ltls_cv_bad
 movzx r13d,word ptr [r12+6]
 rol r13w,8
 lea rax,[r13+8]
 cmp rax,rbx
 jne .Ltls_cv_bad
 cmp qword ptr [rip+.Ltls_certificates+80],65537
 jne .Ltls_cv_bad
 cmp r13,[rip+.Ltls_certificates+72]
 jne .Ltls_cv_bad
 call .Ltls_hash_transcript
 TL_ADDR rdi,.Ltls_verify_context
 mov al,32
 mov ecx,64
 rep stosb
 TL_ADDR rsi,.Ltls_server_context
 mov ecx,.Ltls_server_context_end-.Ltls_server_context
 rep movsb
 TL_ADDR rsi,.Ltls_hash
 mov ecx,32
 rep movsb
 TL_ADDR rdi,.Ltls_verify_context
 mov esi,130
 TL_ADDR rdx,.Ltls_verify_hash
 call sha256_hash
 mov rdi,[rip+.Ltls_certificates+64]
 mov rsi,[rip+.Ltls_certificates+72]
 lea rdx,[r12+8]
 mov rcx,r13
 TL_ADDR r8,.Ltls_verify_hash
 call rsa_pss_sha256_verify
 cmp eax,1
 jne .Ltls_cv_bad
 xor eax,eax
 jmp .Ltls_cv_return
.Ltls_cv_bad:
 TL_ADDR rdi,.Lerr_certificate_verify
 call .Ltls_set_error
.Ltls_cv_return:
 TLS_LEAVE

.Ltls_server_finished:
 TLS_ENTER
 cmp rdi,36
 jne .Ltls_sf_bad
 TL_ADDR r12,.Ltls_hs_buffer
 cmp byte ptr [r12],20
 jne .Ltls_sf_bad
 call .Ltls_hash_transcript
 TL_LABEL .Ltls_server_hs,.Llabel_finished,.Ltls_zeros,0,.Ltls_finished_key,32
 TL_ADDR rdi,.Ltls_finished_key
 mov esi,32
 TL_ADDR rdx,.Ltls_hash
 mov ecx,32
 TL_ADDR r8,.Ltls_finished_mac
 call hmac_sha256
 lea rdi,[r12+4]
 TL_ADDR rsi,.Ltls_finished_mac
 mov edx,32
 call .Ltls_equal
 test eax,eax
 jz .Ltls_sf_bad
 xor eax,eax
 jmp .Ltls_sf_return
.Ltls_sf_bad:
 TL_ADDR rdi,.Lerr_finished
 call .Ltls_set_error
.Ltls_sf_return:
 TLS_LEAVE

.Ltls_client_finished:
 TLS_ENTER
 call .Ltls_hash_transcript
 TL_LABEL .Ltls_master_secret,.Llabel_client_app,.Ltls_hash,32,.Ltls_client_app,32
 TL_LABEL .Ltls_master_secret,.Llabel_server_app,.Ltls_hash,32,.Ltls_server_app,32
 TL_LABEL .Ltls_client_hs,.Llabel_finished,.Ltls_zeros,0,.Ltls_finished_key,32
 TL_ADDR rdi,.Ltls_finished_key
 mov esi,32
 TL_ADDR rdx,.Ltls_hash
 mov ecx,32
 TL_ADDR r8,.Ltls_finished_mac
 call hmac_sha256
 TL_ADDR rdi,.Ltls_hs_out
 mov dword ptr [rdi],0x20000014
 add rdi,4
 TL_ADDR rsi,.Ltls_finished_mac
 mov ecx,32
 rep movsb
 TL_ADDR rdi,.Ltls_hs_out
 mov esi,36
 mov edx,22
 call .Ltls_send_record
 test rax,rax
 js .Ltls_cf_return
 TL_ADDR rdi,.Ltls_hs_out
 mov esi,36
 call .Ltls_append
 test rax,rax
 js .Ltls_cf_return
 TL_ADDR rdi,.Ltls_client_app
 TL_ADDR rsi,.Ltls_server_app
 call .Ltls_traffic_keys
 test rax,rax
 js .Ltls_cf_return
 mov qword ptr [rip+.Ltls_phase],2
 mov qword ptr [rip+.Ltls_ready],1
 xor eax,eax
.Ltls_cf_return:
 TLS_LEAVE

.globl tls_connect
.type tls_connect,@function
# HTTP caller owns fd. Failure never sends application bytes and never closes it.
tls_connect:
 TLS_ENTER 40
 cmp qword ptr [rip+.Ltls_ready],0
 jne .Ltc_busy
 test rdi,rdi
 js .Ltc_invalid
 test rsi,rsi
 jz .Ltc_invalid
 test rdx,rdx
 jz .Ltc_invalid
 mov [rsp+16],rdi
 mov [rsp+24],rsi
 mov [rsp+32],rdx
 mov eax,1
 cpuid
 bt ecx,25
 jnc .Ltc_no_aes
 call .Ltls_erase
 mov rdi,[rsp+16]
 mov [rip+.Ltls_fd],rdi
 mov rsi,[rsp+24]
 mov rdx,[rsp+32]
 mov [rip+.Ltls_ca_path],rdx
 xor ecx,ecx
.Ltc_host_length:
 cmp ecx,253
 jae .Ltc_invalid
 mov al,[rsi+rcx]
 test al,al
 jz .Ltc_host_done
 cmp al,0x21
 jb .Ltc_invalid
 cmp al,0x7e
 ja .Ltc_invalid
 inc ecx
 jmp .Ltc_host_length
.Ltc_host_done:
 test ecx,ecx
 jz .Ltc_invalid
 mov [rip+.Ltls_hostname_len],rcx
 TL_ADDR rdi,.Ltls_hostname
 rep movsb
 mov byte ptr [rdi],0
 call .Ltls_client_hello
 test rax,rax
 js .Ltc_failed
 call .Ltls_get_handshake
 test rax,rax
 js .Ltc_failed
 mov [rsp],rax
 mov rdi,rax
 call .Ltls_server_hello
 test rax,rax
 js .Ltc_failed
 TL_ADDR rdi,.Ltls_hs_buffer
 mov rsi,[rsp]
 call .Ltls_append
 test rax,rax
 js .Ltc_failed
 mov rdi,[rsp]
 call .Ltls_consume_hs
 # ServerHello must finish its plaintext record; mixing clear/encrypted
 # handshake bytes in a single outer record is not admitted.
 cmp qword ptr [rip+.Ltls_hs_len],0
 jne .Ltc_profile
 call .Ltls_handshake_keys
 test rax,rax
 js .Ltc_failed
 # EncryptedExtensions, Certificate, CertificateVerify, Finished, in order.
 xor ebx,ebx
.Ltc_message_loop:
 call .Ltls_get_handshake
 test rax,rax
 js .Ltc_failed
 mov [rsp],rax
 mov rdi,rax
 cmp ebx,0
 je .Ltc_message_ee
 cmp ebx,1
 je .Ltc_message_cert
 cmp ebx,2
 je .Ltc_message_cv
 call .Ltls_server_finished
 jmp .Ltc_message_checked
.Ltc_message_ee:
 call .Ltls_encrypted_extensions
 jmp .Ltc_message_checked
.Ltc_message_cert:
 call .Ltls_certificate
 jmp .Ltc_message_checked
.Ltc_message_cv:
 call .Ltls_certificate_verify
.Ltc_message_checked:
 test rax,rax
 js .Ltc_failed
 TL_ADDR rdi,.Ltls_hs_buffer
 mov rsi,[rsp]
 call .Ltls_append
 test rax,rax
 js .Ltc_failed
 mov rdi,[rsp]
 call .Ltls_consume_hs
 inc ebx
 cmp ebx,4
 jb .Ltc_message_loop
 cmp qword ptr [rip+.Ltls_hs_len],0
 jne .Ltc_profile
 call .Ltls_client_finished
 test rax,rax
 js .Ltc_failed
 TL_ADDR rax,.Lerr_none
 mov [rip+.Ltls_error_ptr],rax
 xor eax,eax
 jmp .Ltc_return
.Ltc_profile:
 call .Ltls_bad_handshake
 jmp .Ltc_failed
.Ltc_no_aes:
 TL_ADDR rdi,.Lerr_aes
 call .Ltls_set_error
 jmp .Ltc_return
.Ltc_busy:
 TL_ADDR rdi,.Lerr_busy
 call .Ltls_set_error
 jmp .Ltc_return
.Ltc_invalid:
 TL_ADDR rdi,.Lerr_arguments
 call .Ltls_set_error
.Ltc_failed:
 mov [rsp+8],rax
 call .Ltls_erase
 mov rax,[rsp+8]
.Ltc_return:
 TLS_LEAVE 40
.size tls_connect,.-tls_connect

.globl tls_write
.type tls_write,@function
tls_write:
 TLS_ENTER
 mov r12,rdi
 mov r13,rsi
 mov r14,rsi
 cmp qword ptr [rip+.Ltls_ready],1
 jne .Ltw_closed
 test r13,r13
 jz .Ltw_done
 test r12,r12
 jz .Ltw_closed
.Ltw_loop:
 test r13,r13
 jz .Ltw_done
 mov ebx,16384
 cmp r13,rbx
 cmovb rbx,r13
 mov rdi,r12
 mov rsi,rbx
 mov edx,23
 call .Ltls_send_record
 test rax,rax
 js .Ltw_return
 add r12,rbx
 sub r13,rbx
 jmp .Ltw_loop
.Ltw_done:
 mov rax,r14
 jmp .Ltw_return
.Ltw_closed:
 TL_ADDR rdi,.Lerr_closed
 call .Ltls_set_error
.Ltw_return:
 test rax,rax
 jns .Ltw_return_ok
 mov qword ptr [rip+.Ltls_ready],0
.Ltw_return_ok:
 TLS_LEAVE
.size tls_write,.-tls_write

# Authenticated post-handshake messages are framed independently of records.
# Tickets need no action because this profile never offers PSK/resumption.
.Ltls_post_handshake:
 TLS_ENTER
 mov rbx,rdi
 mov rax,[rip+.Ltls_hs_len]
 lea rdx,[rax+rbx]
 cmp rdx,TLS_HS_MAX
 ja .Ltls_post_bad
 TL_ADDR rdi,.Ltls_hs_buffer
 add rdi,rax
 TL_ADDR rsi,.Ltls_plain
 mov rcx,rbx
 rep movsb
 mov [rip+.Ltls_hs_len],rdx
.Ltls_post_loop:
 mov rbx,[rip+.Ltls_hs_len]
 cmp rbx,4
 jb .Ltls_post_done
 TL_ADDR r12,.Ltls_hs_buffer
 movzx eax,byte ptr [r12+1]
 shl eax,16
 movzx ecx,byte ptr [r12+2]
 shl ecx,8
 add eax,ecx
 movzx ecx,byte ptr [r12+3]
 add eax,ecx
 add eax,4
 cmp eax,TLS_CERT_MAX
 ja .Ltls_post_bad
 cmp rax,rbx
 ja .Ltls_post_done
 cmp byte ptr [r12],4
 jne .Ltls_post_unsupported
 mov rdi,rax
 call .Ltls_consume_hs
 jmp .Ltls_post_loop
.Ltls_post_done:
 xor eax,eax
 jmp .Ltls_post_return
.Ltls_post_unsupported:
 TL_ADDR rdi,.Lerr_post_handshake
 call .Ltls_set_error
 jmp .Ltls_post_return
.Ltls_post_bad:
 call .Ltls_bad_handshake
.Ltls_post_return:
 TLS_LEAVE

.globl tls_read
.type tls_read,@function
tls_read:
 TLS_ENTER
 mov r12,rdi
 mov r13,rsi
 cmp qword ptr [rip+.Ltls_ready],1
 jne .Ltr_closed
 test r13,r13
 jz .Ltr_eof
 test r12,r12
 jz .Ltr_closed
.Ltr_again:
 mov rbx,[rip+.Ltls_app_len]
 mov r14,[rip+.Ltls_app_pos]
 sub rbx,r14
 jnz .Ltr_copy
 cmp qword ptr [rip+.Ltls_read_closed],0
 jne .Ltr_eof
 call .Ltls_record
 test rax,rax
 js .Ltr_return
 cmp edx,23
 je .Ltr_application
 cmp edx,22
 je .Ltr_handshake
 cmp edx,21
 jne .Ltr_bad
 cmp rax,2
 jne .Ltr_bad
 cmp byte ptr [rip+.Ltls_plain+1],0
 jne .Ltr_alert
 cmp qword ptr [rip+.Ltls_hs_len],0
 jne .Ltr_bad
 mov qword ptr [rip+.Ltls_read_closed],1
 jmp .Ltr_eof
.Ltr_application:
 cmp qword ptr [rip+.Ltls_hs_len],0
 jne .Ltr_bad
 mov [rip+.Ltls_app_len],rax
 mov qword ptr [rip+.Ltls_app_pos],0
 test rax,rax
 jz .Ltr_again
 mov rbx,rax
 xor r14d,r14d
 jmp .Ltr_copy
.Ltr_handshake:
 mov rdi,rax
 call .Ltls_post_handshake
 test rax,rax
 js .Ltr_return
 jmp .Ltr_again
.Ltr_copy:
 cmp rbx,r13
 cmova rbx,r13
 mov rdi,r12
 TL_ADDR rsi,.Ltls_plain
 add rsi,r14
 mov rcx,rbx
 rep movsb
 add [rip+.Ltls_app_pos],rbx
 mov rax,rbx
 jmp .Ltr_return
.Ltr_eof:
 xor eax,eax
 jmp .Ltr_return
.Ltr_closed:
 TL_ADDR rdi,.Lerr_closed
 call .Ltls_set_error
 jmp .Ltr_return
.Ltr_alert:
 TL_ADDR rdi,.Lerr_alert
 call .Ltls_set_error
 jmp .Ltr_return
.Ltr_bad:
 call .Ltls_bad_record
.Ltr_return:
 test rax,rax
 jns .Ltr_return_ok
 mov qword ptr [rip+.Ltls_ready],0
.Ltr_return_ok:
 TLS_LEAVE
.size tls_read,.-tls_read

# Bytes already authenticated/decrypted but not returned by tls_read. Socket
# readiness alone cannot reveal these bytes; HTTP reuse must check both layers.
.globl tls_pending
.type tls_pending,@function
tls_pending:
 xor eax,eax
 cmp qword ptr [rip+.Ltls_ready],1
 jne .Ltp_done
 mov rax,[rip+.Ltls_app_len]
 sub rax,[rip+.Ltls_app_pos]
 jnc .Ltp_done
 xor eax,eax
.Ltp_done:
 ret
.size tls_pending,.-tls_pending

# Fork detach: the child must not send close_notify on the parent's shared TCP
# stream. Erase only its private copied TLS context; HTTP owns raw FD cleanup.
.globl tls_after_fork
.type tls_after_fork,@function
tls_after_fork:
 jmp .Ltls_erase
.size tls_after_fork,.-tls_after_fork

.globl tls_close
.type tls_close,@function
# Send close_notify when possible, erase secrets; HTTP caller closes its fd.
tls_close:
 TLS_ENTER
 cmp qword ptr [rip+.Ltls_ready],1
 jne .Ltls_close_erase
 cmp qword ptr [rip+net_cancelled],0
 jne .Ltls_close_erase
 TL_ADDR rdi,.Ltls_close_alert
 mov esi,2
 mov edx,21
 call .Ltls_send_record
.Ltls_close_erase:
 call .Ltls_erase
 xor eax,eax
 TLS_LEAVE
.size tls_close,.-tls_close

.section .rodata
.Lerr_none: .asciz "no TLS error"
.Lerr_io: .asciz "TLS connection ended early, timed out or was cancelled"
.Lerr_record: .asciz "invalid TLS record or sequence"
.Lerr_auth_tag: .asciz "TLS record authentication failed"
.Lerr_handshake: .asciz "unsupported or malformed TLS 1.3 handshake"
.Lerr_kdf: .asciz "TLS key agreement or key schedule failed"
.Lerr_random: .asciz "kernel random source failed"
.Lerr_certificate: .asciz "TLS certificate chain, hostname or validity verification failed"
.Lerr_certificate_verify: .asciz "TLS server CertificateVerify signature failed"
.Lerr_finished: .asciz "TLS server Finished verification failed"
.Lerr_closed: .asciz "no active TLS session"
.Lerr_alert: .asciz "TLS peer sent an alert"
.Lerr_post_handshake: .asciz "unsupported TLS post-handshake message (KeyUpdate/client authentication)"
.Lerr_arguments: .asciz "invalid TLS connection arguments"
.Lerr_aes: .asciz "TLS requires the AES-NI CPU capability"
.Lerr_busy: .asciz "a TLS connection is already active"
.Llabel_derived: .asciz "derived"
.Llabel_client_hs: .asciz "c hs traffic"
.Llabel_server_hs: .asciz "s hs traffic"
.Llabel_client_app: .asciz "c ap traffic"
.Llabel_server_app: .asciz "s ap traffic"
.Llabel_key: .asciz "key"
.Llabel_iv: .asciz "iv"
.Llabel_finished: .asciz "finished"
.Ltls_server_context: .asciz "TLS 1.3, server CertificateVerify"
.Ltls_server_context_end:
.Ltls_close_alert: .byte 1,0
.Ltls_empty_hash:
 .byte 0xe3,0xb0,0xc4,0x42,0x98,0xfc,0x1c,0x14,0x9a,0xfb,0xf4,0xc8,0x99,0x6f,0xb9,0x24
 .byte 0x27,0xae,0x41,0xe4,0x64,0x9b,0x93,0x4c,0xa4,0x95,0x99,0x1b,0x78,0x52,0xb8,0x55
.Ltls_zeros: .zero 32
.Ltls_basepoint: .byte 9
 .zero 31
.Ltls_hrr_random:
 .byte 0xcf,0x21,0xad,0x74,0xe5,0x9a,0x61,0x11,0xbe,0x1d,0x8c,0x02,0x1e,0x65,0xb8,0x91
 .byte 0xc2,0xa2,0x11,0x16,0x7a,0xbb,0x8c,0x5e,0x07,0x9e,0x09,0xe2,0xc8,0xa8,0x33,0x9c
.Ltls_ch_extensions:
 .byte 0,43,0,3,2,3,4
 .byte 0,10,0,4,0,2,0,29
 .byte 0,13,0,4,0,2,8,4
 # Certificate chain signature profile is separate from CertificateVerify.
 .byte 0,50,0,4,0,2,4,1
.Ltls_ch_extensions_end:
.Ltls_alpn_extension:
 .byte 0,16,0,11
.Ltls_alpn_value:
 .byte 0,9,8
 .ascii "http/1.1"
.Ltls_alpn_extension_end:

.section .bss
.p2align 4
.Ltls_error_ptr: .skip 8
.Ltls_state_begin:
.Ltls_fd: .skip 8
.Ltls_ready: .skip 8
.Ltls_phase: .skip 8
.Ltls_ca_path: .skip 8
.Ltls_hostname_len: .skip 8
.Ltls_transcript_len: .skip 8
.Ltls_hs_len: .skip 8
.Ltls_read_seq: .skip 8
.Ltls_write_seq: .skip 8
.Ltls_ccs_count: .skip 8
.Ltls_app_len: .skip 8
.Ltls_app_pos: .skip 8
.Ltls_read_closed: .skip 8
.Ltls_hostname: .skip 256
.Ltls_random: .skip 32
.Ltls_scalar: .skip 32
.Ltls_public: .skip 32
.Ltls_server_public: .skip 32
.Ltls_shared: .skip 32
.Ltls_early_secret: .skip 32
.Ltls_derived: .skip 32
.Ltls_handshake_secret: .skip 32
.Ltls_master_secret: .skip 32
.Ltls_client_hs: .skip 32
.Ltls_server_hs: .skip 32
.Ltls_client_app: .skip 32
.Ltls_server_app: .skip 32
.Ltls_client_key: .skip 16
.Ltls_server_key: .skip 16
.Ltls_client_iv: .skip 12
.Ltls_server_iv: .skip 12
.Ltls_nonce_buf: .skip 12
.Ltls_client_roundkeys: .skip 176
.Ltls_server_roundkeys: .skip 176
.Ltls_hash: .skip 32
.Ltls_verify_context: .skip 130
.Ltls_verify_hash: .skip 32
.Ltls_finished_key: .skip 32
.Ltls_finished_mac: .skip 32
.Ltls_gcm_request: .skip 64
.Ltls_hs_out: .skip 1024
.Ltls_wire: .skip TLS_RECORD_MAX+5
.Ltls_plain: .skip TLS_RECORD_MAX
.Ltls_send_plain: .skip 16385
.Ltls_certificates: .skip 224*8
.Ltls_certificate_buffer: .skip TLS_CERT_MAX+8
.Ltls_hs_buffer: .skip TLS_HS_MAX
.Ltls_transcript: .skip TLS_TRANSCRIPT_MAX
.Ltls_state_end:
.section .note.GNU-stack,"",@progbits
