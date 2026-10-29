# [open integration] Native Qwen OAuth device grant/cache/refresh membrane.
# Public protocol/constants match local qwen-go/provider/oauth.go and QwenCode.
# Only this application's private credential file is ever refreshed/written.
# Exported ABI: oauth_load(homez),oauth_ensure(),oauth_login(homez) ->0/-negative.
# oauth_token/resource/error return owned NUL strings. Process-local bounded state;
# serialize within a process; fork workers coordinate refresh via stable flock.
# Native cache expiry_date is Unix milliseconds (expires_at integer seconds alias).
# External cache use requires known future expiry and never changes external files.
# Native endpoint literals are fixed; no token-bearing endpoint override exists.
.intel_syntax noprefix
.equ O_DIR_FLAGS,0xb0000
.equ O_READ_FLAGS,0xa0800
.equ O_TOKEN_CAP,8193
.equ O_RESPONSE_CAP,65536
.section .rodata
o_device_endpoint: .asciz "https://chat.qwen.ai/api/v1/oauth2/device/code"
o_token_endpoint: .asciz "https://chat.qwen.ai/api/v1/oauth2/token"
.Lo_client_id: .asciz "f0304373b74a44d2b584a3fb70ca9e56"
.Lo_scope: .asciz "openid profile email model.completion"
.Lo_form_type: .asciz "application/x-www-form-urlencoded"
.Lo_config: .asciz ".config"
.Lo_native: .asciz "qwen-x86"
.Lo_go: .asciz "qwen-go"
.Lo_qwen: .asciz ".qwen"
.Lo_file: .asciz "oauth.json"
.Lo_qwen_file: .asciz "oauth_creds.json"
.Lo_lock: .asciz "oauth.lock"
.Lo_temp_prefix: .ascii ".oauth-tmp-"
.Lo_empty: .asciz ""
.Lo_bearer: .asciz "Bearer"
.Lo_access: .asciz "access_token"
.Lo_refresh: .asciz "refresh_token"
.Lo_type: .asciz "token_type"
.Lo_resource: .asciz "resource_url"
.Lo_expiry: .asciz "expiry_date"
.Lo_expires_at: .asciz "expires_at"
.Lo_expires_in: .asciz "expires_in"
.Lo_interval: .asciz "interval"
.Lo_device: .asciz "device_code"
.Lo_user: .asciz "user_code"
.Lo_uri_complete: .asciz "verification_uri_complete"
.Lo_uri: .asciz "verification_uri"
.Lo_error_key: .asciz "error"
.Lo_client_key: .asciz "client_id"
.Lo_scope_key: .asciz "scope"
.Lo_challenge_key: .asciz "code_challenge"
.Lo_method_key: .asciz "code_challenge_method"
.Lo_method: .asciz "S256"
.Lo_grant_key: .asciz "grant_type"
.Lo_device_grant: .asciz "urn:ietf:params:oauth:grant-type:device_code"
.Lo_refresh_grant: .asciz "refresh_token"
.Lo_verifier_key: .asciz "code_verifier"
.Lo_pending: .asciz "authorization_pending"
.Lo_slow: .asciz "slow_down"
.Lo_denied: .asciz "access_denied"
.Lo_expired: .asciz "expired_token"
.Lo_hex: .ascii "0123456789ABCDEF"
.Lo_b64url: .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
.Lo_open_msg: .asciz "Open "
.Lo_code_msg: .asciz "\nCode: "
.Lo_wait_msg: .asciz "\nWaiting for browser approval (Ctrl+C cancels)…\n"
.Lo_saved_msg: .asciz "Qwen login saved securely. Run qwen-x86 to start.\n"
.Lo_need_login: .asciz "Qwen login required; run qwen-x86 login."
.Lo_external_expired: .asciz "External Qwen credentials expired; run qwen-x86 login. External caches were not changed."
.Lo_invalid_cache: .asciz "Invalid or unsafe OAuth credential cache."
.Lo_network_error: .asciz "Native OAuth HTTPS request failed."
.Lo_response_error: .asciz "OAuth response was invalid or exceeded the bounded limit."
.Lo_denied_error: .asciz "Qwen authorization was denied."
.Lo_expired_error: .asciz "Qwen authorization expired; run qwen-x86 login again."
.Lo_refresh_error: .asciz "Qwen token refresh failed; run qwen-x86 login."
.Lo_save_error: .asciz "Could not safely save OAuth credentials."
.Lo_cancel_error: .asciz "Qwen login was canceled."
.Lo_json_access: .asciz "{\"access_token\":"
.Lo_json_refresh: .asciz ",\"refresh_token\":"
.Lo_json_resource: .asciz ",\"resource_url\":"
.Lo_json_expiry: .asciz ",\"token_type\":\"Bearer\",\"expiry_date\":"
.Lo_json_end: .asciz "}\n"
.section .bss
.balign 16
.Lo_home: .skip 4096
.Lo_token: .skip O_TOKEN_CAP
.Lo_refresh_token: .skip O_TOKEN_CAP
.Lo_resource_url: .skip 2049
.Lo_expiry_ms: .skip 8
.Lo_source: .skip 8
.Lo_error: .skip 8
.Lo_response: .skip O_RESPONSE_CAP
.Lo_response_len: .skip 8
.Lo_tokens: .skip 32768
.Lo_form: .skip 65536
.Lo_form_len: .skip 8
.Lo_save: .skip 65536
.Lo_save_len: .skip 8
.Lo_new_token: .skip O_TOKEN_CAP
.Lo_new_refresh: .skip O_TOKEN_CAP
.Lo_new_resource: .skip 2049
.Lo_type_text: .skip 64
.Lo_error_text: .skip 128
.Lo_device_code: .skip 8193
.Lo_user_code: .skip 129
.Lo_verification: .skip 2049
.Lo_verifier: .skip 44
.Lo_challenge: .skip 44
.Lo_random: .skip 32
.Lo_digest: .skip 32
.Lo_temp: .skip 64
.Lo_poll_interval: .skip 8
.Lo_deadline: .skip 8
.Lo_http_code: .skip 8
.Lo_stat: .skip 144
.section .text
.globl oauth_token,oauth_resource,oauth_error,oauth_load,oauth_ensure,oauth_login
oauth_token:
 lea rax,[rip+.Lo_token]
 ret
oauth_resource:
 lea rax,[rip+.Lo_resource_url]
 ret
oauth_error:
 mov rax,qword ptr [rip+.Lo_error]
 test rax,rax
 jne .Lo_error_done
 lea rax,[rip+.Lo_need_login]
.Lo_error_done:
 ret
.Lo_zlen:
 xor eax,eax
.Lo_zlen_loop:
 cmp byte ptr [rdi+rax],0
 je .Lo_zlen_done
 inc rax
 cmp rax,65536
 jb .Lo_zlen_loop
 mov rax,-1
.Lo_zlen_done:
 ret
.Lo_equal:
 xor eax,eax
.Lo_eq_loop:
 mov dl,byte ptr [rdi+rax]
 cmp dl,byte ptr [rsi+rax]
 jne .Lo_eq_no
 test dl,dl
 jz .Lo_eq_yes
 inc rax
 jmp .Lo_eq_loop
.Lo_eq_yes:
 mov eax,1
 ret
.Lo_eq_no:
 xor eax,eax
 ret
# Copyz(dst,src,cap) ->len/-2.
.Lo_copyz:
 sub rsp,8
 test rsi,rsi
 jz .Lo_copy_bad
 mov r8,rdi
 mov r9,rdx
 mov rdi,rsi
 call .Lo_zlen
 test rax,rax
 js .Lo_copy_bad
 cmp rax,r9
 jae .Lo_copy_bad
 mov rdi,r8
 mov rcx,rax
 inc rcx
 rep movsb
 add rsp,8
 ret
.Lo_copy_bad:
 mov rax,-2
 add rsp,8
 ret
# Printable ASCII token/URL; control/space bytes rejected, optional empty allowed.
.Lo_printable:
 xor eax,eax
.Lo_printable_loop:
 movzx edx,byte ptr [rdi+rax]
 test edx,edx
 jz .Lo_printable_good
 cmp edx,33
 jb .Lo_printable_bad
 cmp edx,126
 ja .Lo_printable_bad
 inc rax
 cmp rax,rsi
 jb .Lo_printable_loop
.Lo_printable_bad:
 mov rax,-2
 ret
.Lo_printable_good:
 ret
# Current Unix milliseconds; negative on system error.
.Lo_now_ms:
 sub rsp,24
 mov eax,228
 xor edi,edi
 mov rsi,rsp
 syscall
 test rax,rax
 js .Lo_now_return
 mov r8,qword ptr [rsp]
 imul r8,r8,1000
 mov rax,qword ptr [rsp+8]
 xor edx,edx
 mov ecx,1000000
 div rcx
 add rax,r8
.Lo_now_return:
 add rsp,24
 ret
# Canonical JSON field parser over bounded private response/tokens.
.Lo_parse_response:
 sub rsp,8
 lea rdi,[rip+.Lo_response]
 mov rsi,qword ptr [rip+.Lo_response_len]
 lea rdx,[rip+.Lo_tokens]
 mov ecx,1024
 call json_parse
 test rax,rax
 js .Lo_parse_bad
 cmp qword ptr [rip+.Lo_tokens],1
 jne .Lo_parse_bad
 xor eax,eax
 add rsp,8
 ret
.Lo_parse_bad:
 mov rax,-2
 add rsp,8
 ret
# fieldString(key,dst,cap) ->len,-1missing,-2invalid; decodedNUL rejected.
.Lo_field_string:
 push rbx
 push r12
 push r13
 mov rbx,rdi
 mov r12,rsi
 mov r13,rdx
 mov byte ptr [r12],0
 lea rdi,[rip+.Lo_response]
 lea rsi,[rip+.Lo_tokens]
 xor edx,edx
 mov rcx,rbx
 call json_find
 test rax,rax
 js .Lo_fs_missing
 shl rax,5
 lea rdx,[rip+.Lo_tokens]
 add rdx,rax
 cmp qword ptr [rdx],3
 jne .Lo_fs_bad
 lea rsi,[rip+.Lo_response]
 add rsi,qword ptr [rdx+8]
 mov rdx,qword ptr [rdx+16]
 mov rdi,r12
 lea rcx,[r13-1]
 call json_decode
 test rax,rax
 js .Lo_fs_bad
 mov byte ptr [r12+rax],0
 xor ecx,ecx
.Lo_fs_nul:
 cmp rcx,rax
 jae .Lo_fs_done
 cmp byte ptr [r12+rcx],0
 je .Lo_fs_bad
 inc rcx
 jmp .Lo_fs_nul
.Lo_fs_missing:
 mov rax,-1
 jmp .Lo_fs_done
.Lo_fs_bad:
 mov byte ptr [r12],0
 mov rax,-2
.Lo_fs_done:
 pop r13
 pop r12
 pop rbx
 ret
# fieldNumber(key) ->unsignedinteger or-1missing/-2invalid. No floats/exponents.
.Lo_field_number:
 push rbx
 mov rcx,rdi
 lea rdi,[rip+.Lo_response]
 lea rsi,[rip+.Lo_tokens]
 xor edx,edx
 call json_find
 test rax,rax
 js .Lo_fn_missing
 shl rax,5
 lea rdx,[rip+.Lo_tokens]
 add rdx,rax
 cmp qword ptr [rdx],4
 jne .Lo_fn_bad
 mov r8,qword ptr [rdx+16]
 lea rsi,[rip+.Lo_response]
 add rsi,qword ptr [rdx+8]
 test r8,r8
 jz .Lo_fn_bad
 cmp r8,19
 ja .Lo_fn_bad
 xor eax,eax
 xor ecx,ecx
.Lo_fn_digit:
 movzx edx,byte ptr [rsi+rcx]
 sub edx,48
 cmp edx,9
 ja .Lo_fn_bad
 imul rax,rax,10
 jo .Lo_fn_bad
 add rax,rdx
 jo .Lo_fn_bad
 inc rcx
 cmp rcx,r8
 jb .Lo_fn_digit
 pop rbx
 ret
.Lo_fn_missing:
 mov rax,-1
 pop rbx
 ret
.Lo_fn_bad:
 mov rax,-2
 pop rbx
 ret
# Validatecache/commit fields; buffer is already a parsed JSON object.
.Lo_cache_fields:
 push rbx
 lea rdi,[rip+.Lo_access]
 lea rsi,[rip+.Lo_new_token]
 mov edx,O_TOKEN_CAP
 call .Lo_field_string
 test rax,rax
 jle .Lo_cache_bad
 lea rdi,[rip+.Lo_new_token]
 mov esi,O_TOKEN_CAP
 call .Lo_printable
 test rax,rax
 js .Lo_cache_bad
 lea rdi,[rip+.Lo_refresh]
 lea rsi,[rip+.Lo_new_refresh]
 mov edx,O_TOKEN_CAP
 call .Lo_field_string
 cmp rax,-2
 je .Lo_cache_bad
 lea rdi,[rip+.Lo_new_refresh]
 mov esi,O_TOKEN_CAP
 call .Lo_printable
 test rax,rax
 js .Lo_cache_bad
 lea rdi,[rip+.Lo_resource]
 lea rsi,[rip+.Lo_new_resource]
 mov edx,2049
 call .Lo_field_string
 cmp rax,-2
 je .Lo_cache_bad
 lea rdi,[rip+.Lo_new_resource]
 mov esi,2049
 call .Lo_printable
 test rax,rax
 js .Lo_cache_bad
 lea rdi,[rip+.Lo_type]
 lea rsi,[rip+.Lo_type_text]
 mov edx,64
 call .Lo_field_string
 cmp rax,-2
 je .Lo_cache_bad
 test rax,rax
 jle .Lo_cache_expiry
 lea rdi,[rip+.Lo_type_text]
 lea rsi,[rip+.Lo_bearer]
 call .Lo_equal
 test rax,rax
 jz .Lo_cache_bad
.Lo_cache_expiry:
 lea rdi,[rip+.Lo_expiry]
 call .Lo_field_number
 cmp rax,-2
 je .Lo_cache_bad
 cmp rax,-1
 jne .Lo_cache_have_expiry
 lea rdi,[rip+.Lo_expires_at]
 call .Lo_field_number
 cmp rax,-2
 je .Lo_cache_bad
 cmp rax,-1
 jne .Lo_cache_seconds
 xor eax,eax
 jmp .Lo_cache_have_expiry
.Lo_cache_seconds:
 imul rax,rax,1000
 jo .Lo_cache_bad
.Lo_cache_have_expiry:
 mov rbx,rax
 lea rdi,[rip+.Lo_token]
 lea rsi,[rip+.Lo_new_token]
 mov edx,O_TOKEN_CAP
 call .Lo_copyz
 lea rdi,[rip+.Lo_refresh_token]
 lea rsi,[rip+.Lo_new_refresh]
 mov edx,O_TOKEN_CAP
 call .Lo_copyz
 lea rdi,[rip+.Lo_resource_url]
 lea rsi,[rip+.Lo_new_resource]
 mov edx,2049
 call .Lo_copyz
 mov qword ptr [rip+.Lo_expiry_ms],rbx
 xor eax,eax
 pop rbx
 ret
.Lo_cache_bad:
 mov rax,-2
 pop rbx
 ret
# Validity window matches Qwen/Go's30s eager-refresh threshold; expiry0 is unknown.
.Lo_credentials_ready:
 cmp byte ptr [rip+.Lo_token],0
 je .Lo_ready_no
 cmp qword ptr [rip+.Lo_expiry_ms],0
 je .Lo_ready_yes
 sub rsp,8
 call .Lo_now_ms
 add rsp,8
 test rax,rax
 js .Lo_ready_no
 add rax,30000
 cmp qword ptr [rip+.Lo_expiry_ms],rax
 jle .Lo_ready_no
.Lo_ready_yes:
 xor eax,eax
 ret
.Lo_ready_no:
 mov rax,-1
 ret

# Open one named child directory; optional creation, no symlink traversal.
.Lo_child:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov eax,257
 mov edx,O_DIR_FLAGS
 xor r10d,r10d
 syscall
 cmp rax,-2
 jne .Lo_child_return
 test r14,r14
 jz .Lo_child_return
 mov eax,258
 mov rdi,r12
 mov rsi,r13
 mov edx,448
 syscall
 test rax,rax
 jz .Lo_child_reopen
 cmp rax,-17
 jne .Lo_child_return
.Lo_child_reopen:
 mov eax,257
 mov rdi,r12
 mov rsi,r13
 mov edx,O_DIR_FLAGS
 xor r10d,r10d
 syscall
.Lo_child_return:
 pop r14
 pop r13
 pop r12
 ret
# Own dir(createflag) ->fd/-1missing/-2unsafe. Only own directory becomes0700.
.Lo_open_native:
 push rbx
 push r12
 push r13
 mov r13,rdi
 mov eax,257
 mov rdi,-100
 lea rsi,[rip+.Lo_home]
 mov edx,O_DIR_FLAGS
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lo_dir_error
 mov r12,rax
 mov rdi,r12
 lea rsi,[rip+.Lo_config]
 mov rdx,r13
 call .Lo_child
 mov rbx,rax
 mov eax,3
 mov rdi,r12
 syscall
 test rbx,rbx
 js .Lo_dir_child_error
 mov r12,rbx
 mov rdi,r12
 lea rsi,[rip+.Lo_native]
 mov rdx,r13
 call .Lo_child
 mov rbx,rax
 mov eax,3
 mov rdi,r12
 syscall
 test rbx,rbx
 js .Lo_dir_child_error
 mov eax,5
 mov rdi,rbx
 lea rsi,[rip+.Lo_stat]
 syscall
 test rax,rax
 js .Lo_dir_close_bad
 mov eax,107
 syscall
 cmp eax,dword ptr [rip+.Lo_stat+28]
 jne .Lo_dir_close_bad
 mov eax,dword ptr [rip+.Lo_stat+24]
 and eax,0xf000
 cmp eax,0x4000
 jne .Lo_dir_close_bad
 mov eax,91
 mov rdi,rbx
 mov esi,448
 syscall
 test rax,rax
 js .Lo_dir_close_bad
 mov rax,rbx
 jmp .Lo_dir_return
.Lo_dir_close_bad:
 mov eax,3
 mov rdi,rbx
 syscall
 mov rax,-2
 jmp .Lo_dir_return
.Lo_dir_child_error:
 mov rax,rbx
.Lo_dir_error:
 cmp rax,-2
 mov rax,-2
 jne .Lo_dir_return
 mov rax,-1
.Lo_dir_return:
 pop r13
 pop r12
 pop rbx
 ret
# Read cache(dirfd,name,privateflag) into private bounded response buffer.
.Lo_read_cache:
 push rbx
 push r12
 push r13
 mov r13,rdx
 mov qword ptr [rip+.Lo_response_len],0
 mov eax,257
 mov edx,O_READ_FLAGS
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lo_cache_open_error
 mov r12,rax
 mov eax,5
 mov rdi,r12
 lea rsi,[rip+.Lo_stat]
 syscall
 test rax,rax
 js .Lo_read_bad_close
 mov eax,dword ptr [rip+.Lo_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lo_read_bad_close
 mov eax,107
 syscall
 cmp eax,dword ptr [rip+.Lo_stat+28]
 jne .Lo_read_bad_close
 mov eax,dword ptr [rip+.Lo_stat+24]
 test eax,18
 jnz .Lo_read_bad_close
 test r13,r13
 jz .Lo_read_start
 mov eax,dword ptr [rip+.Lo_stat+24]
 and eax,511
 cmp eax,384
 jne .Lo_read_bad_close
 cmp qword ptr [rip+.Lo_stat+16],1
 jne .Lo_read_bad_close
.Lo_read_start:
 xor ebx,ebx
.Lo_read_more:
 mov eax,0
 mov rdi,r12
 lea rsi,[rip+.Lo_response]
 add rsi,rbx
 mov edx,O_RESPONSE_CAP
 sub rdx,rbx
 jz .Lo_read_bad_close
 syscall
 cmp rax,-4
 je .Lo_read_more
 test rax,rax
 js .Lo_read_bad_close
 jz .Lo_read_ok
 add rbx,rax
 jmp .Lo_read_more
.Lo_read_ok:
 lea rax,[rip+.Lo_response]
 mov byte ptr [rax+rbx],0
 mov qword ptr [rip+.Lo_response_len],rbx
 mov eax,3
 mov rdi,r12
 syscall
 mov rax,rbx
 jmp .Lo_read_return
.Lo_read_bad_close:
 mov eax,3
 mov rdi,r12
 syscall
 mov rax,-2
 jmp .Lo_read_return
.Lo_cache_open_error:
 cmp rax,-2
 mov rax,-2
 jne .Lo_read_return
 mov rax,-1
.Lo_read_return:
 pop r13
 pop r12
 pop rbx
 ret

# Read external source2Go/source3Qwen,never modify itsdirectory/file/refreshlock.
.Lo_external:
 push rbx
 push r12
 push r13
 mov r13,rdi
 mov eax,257
 mov rdi,-100
 lea rsi,[rip+.Lo_home]
 mov edx,O_DIR_FLAGS
 xor r10d,r10d
 syscall
 test rax,rax
 js .Lo_external_missing
 mov r12,rax
 mov rdi,r12
 lea rsi,[rip+.Lo_config]
 cmp r13,3
 jne .Lo_external_first
 lea rsi,[rip+.Lo_qwen]
.Lo_external_first:
 xor edx,edx
 call .Lo_child
 mov rbx,rax
 mov eax,3
 mov rdi,r12
 syscall
 test rbx,rbx
 js .Lo_external_missing
 mov r12,rbx
 cmp r13,3
 je .Lo_external_read
 mov rdi,r12
 lea rsi,[rip+.Lo_go]
 xor edx,edx
 call .Lo_child
 mov rbx,rax
 mov eax,3
 mov rdi,r12
 syscall
 test rbx,rbx
 js .Lo_external_missing
 mov r12,rbx
.Lo_external_read:
 mov rdi,r12
 lea rsi,[rip+.Lo_file]
 cmp r13,3
 jne .Lo_external_filename
 lea rsi,[rip+.Lo_qwen_file]
.Lo_external_filename:
 xor edx,edx
 call .Lo_read_cache
 mov rbx,rax
 mov eax,3
 mov rdi,r12
 syscall
 test rbx,rbx
 js .Lo_external_missing
 call .Lo_parse_response
 test rax,rax
 jnz .Lo_external_invalid
 call .Lo_cache_fields
 test rax,rax
 jnz .Lo_external_invalid
 cmp qword ptr [rip+.Lo_expiry_ms],0
 jle .Lo_external_expired_code
 call .Lo_credentials_ready
 test rax,rax
 jnz .Lo_external_expired_code
 mov qword ptr [rip+.Lo_source],r13
 xor eax,eax
 jmp .Lo_external_return
.Lo_external_expired_code:
 lea rax,[rip+.Lo_external_expired]
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
 jmp .Lo_external_return
.Lo_external_invalid:
 lea rax,[rip+.Lo_invalid_cache]
 mov qword ptr [rip+.Lo_error],rax
.Lo_external_missing:
 mov rax,-1
.Lo_external_return:
 pop r13
 pop r12
 pop rbx
 ret

# Load credentials from native then unexpired external caches. No network calls.
oauth_load:
 push rbx
 push r12
 sub rsp,8
 mov rsi,rdi
 lea rdi,[rip+.Lo_home]
 mov edx,4096
 call .Lo_copyz
 test rax,rax
 js .Lo_load_invalid
 mov byte ptr [rip+.Lo_token],0
 mov byte ptr [rip+.Lo_refresh_token],0
 mov byte ptr [rip+.Lo_resource_url],0
 mov qword ptr [rip+.Lo_expiry_ms],0
 mov qword ptr [rip+.Lo_source],0
 lea rax,[rip+.Lo_need_login]
 mov qword ptr [rip+.Lo_error],rax
 xor edi,edi
 call .Lo_open_native
 cmp rax,-1
 je .Lo_load_external
 test rax,rax
 js .Lo_load_invalid
 mov rbx,rax
 mov rdi,rax
 lea rsi,[rip+.Lo_file]
 mov edx,1
 call .Lo_read_cache
 mov r12,rax
 mov eax,3
 mov rdi,rbx
 syscall
 cmp r12,-1
 je .Lo_load_external
 test r12,r12
 js .Lo_load_invalid
 call .Lo_parse_response
 test rax,rax
 jnz .Lo_load_invalid
 call .Lo_cache_fields
 test rax,rax
 jnz .Lo_load_invalid
 mov qword ptr [rip+.Lo_source],1
 xor eax,eax
 jmp .Lo_load_return
.Lo_load_external:
 mov edi,2
 call .Lo_external
 test rax,rax
 jz .Lo_load_return
 mov ebx,eax
 mov edi,3
 call .Lo_external
 test rax,rax
 jz .Lo_load_return
 cmp eax,-2
 je .Lo_load_clear
 cmp ebx,-2
 jne .Lo_load_missing
 mov rax,-2
 jmp .Lo_load_clear
.Lo_load_missing:
 mov rax,-1
 jmp .Lo_load_clear
.Lo_load_invalid:
 lea rax,[rip+.Lo_invalid_cache]
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
.Lo_load_clear:
 mov byte ptr [rip+.Lo_token],0
 mov byte ptr [rip+.Lo_refresh_token],0
 mov byte ptr [rip+.Lo_resource_url],0
 mov qword ptr [rip+.Lo_source],0
.Lo_load_return:
 add rsp,8
 pop r12
 pop rbx
 ret

.Lo_form_reset:
 mov qword ptr [rip+.Lo_form_len],0
 mov byte ptr [rip+.Lo_form],0
 xor eax,eax
 ret
.Lo_form_put:
 mov rax,qword ptr [rip+.Lo_form_len]
 cmp rax,65535
 jae .Lo_form_bad
 lea rdx,[rip+.Lo_form]
 mov byte ptr [rdx+rax],dil
 inc rax
 mov byte ptr [rdx+rax],0
 mov qword ptr [rip+.Lo_form_len],rax
 xor eax,eax
 ret
.Lo_form_bad:
 mov rax,-2
 ret
# PercentencodeoneNULstring; formspacesuse'+'; no shell or JSON interpolation.
.Lo_form_encode:
 push rbx
 push r12
 push r13
 mov r12,rdi
 xor r13d,r13d
.Lo_form_char:
 movzx ebx,byte ptr [r12+r13]
 test ebx,ebx
 jz .Lo_form_encode_good
 cmp r13,8192
 jae .Lo_form_encode_bad
 mov edi,ebx
 mov eax,ebx
 sub eax,48
 cmp eax,9
 jbe .Lo_form_raw
 mov eax,ebx
 or eax,32
 sub eax,97
 cmp eax,25
 jbe .Lo_form_raw
 cmp ebx,45
 je .Lo_form_raw
 cmp ebx,46
 je .Lo_form_raw
 cmp ebx,95
 je .Lo_form_raw
 cmp ebx,126
 je .Lo_form_raw
 cmp ebx,32
 jne .Lo_form_percent
 mov edi,43
 jmp .Lo_form_raw
.Lo_form_percent:
 mov edi,37
 call .Lo_form_put
 test rax,rax
 js .Lo_form_encode_bad
 mov eax,ebx
 shr eax,4
 lea rdx,[rip+.Lo_hex]
 movzx edi,byte ptr [rdx+rax]
 call .Lo_form_put
 test rax,rax
 js .Lo_form_encode_bad
 mov eax,ebx
 and eax,15
 lea rdx,[rip+.Lo_hex]
 movzx edi,byte ptr [rdx+rax]
.Lo_form_raw:
 call .Lo_form_put
 test rax,rax
 js .Lo_form_encode_bad
 inc r13
 jmp .Lo_form_char
.Lo_form_encode_good:
 xor eax,eax
 jmp .Lo_form_encode_return
.Lo_form_encode_bad:
 mov rax,-2
.Lo_form_encode_return:
 pop r13
 pop r12
 pop rbx
 ret
.Lo_form_add:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 cmp qword ptr [rip+.Lo_form_len],0
 je .Lo_form_key
 mov edi,38
 call .Lo_form_put
 test rax,rax
 js .Lo_form_add_done
.Lo_form_key:
 mov rdi,r12
 call .Lo_form_encode
 test rax,rax
 js .Lo_form_add_done
 mov edi,61
 call .Lo_form_put
 test rax,rax
 js .Lo_form_add_done
 mov rdi,r13
 call .Lo_form_encode
.Lo_form_add_done:
 pop r14
 pop r13
 pop r12
 ret
# Bounded nativeHTTPresponse collector. Never display endpoint error bodies.
.Lo_collect:
 mov r8,rdi
 mov r9,rsi
 mov rdx,qword ptr [rip+.Lo_response_len]
 mov rax,rdx
 add rax,r9
 jc .Lo_collect_bad
 cmp rax,O_RESPONSE_CAP
 jae .Lo_collect_bad
 mov qword ptr [rip+.Lo_response_len],rax
 lea rdi,[rip+.Lo_response]
 add rdi,rdx
 mov rsi,r8
 mov rcx,r9
 rep movsb
 mov byte ptr [rdi],0
 xor eax,eax
 ret
.Lo_collect_bad:
 mov qword ptr [rip+.Lo_overflow],1
 mov eax,1
 ret
.Lo_auth_post:
 push rbx
 mov rbx,rdi
 mov qword ptr [rip+.Lo_response_len],0
 mov qword ptr [rip+.Lo_overflow],0
 mov byte ptr [rip+.Lo_response],0
 lea rdi,[rip+.Lo_form_type]
 call http_set_content_type
 test rax,rax
 js .Lo_post_restore_bad
 mov rdi,rbx
 xor esi,esi
 lea rdx,[rip+.Lo_form]
 mov rcx,qword ptr [rip+.Lo_form_len]
 lea r8,[rip+.Lo_collect]
 call http_request
 mov rbx,rax
 xor edi,edi
 call http_set_content_type
 mov qword ptr [rip+.Lo_http_code],rbx
 test rbx,rbx
 js .Lo_post_network
 call .Lo_parse_response
 test rax,rax
 jnz .Lo_post_invalid
 lea rdi,[rip+.Lo_error_key]
 lea rsi,[rip+.Lo_error_text]
 mov edx,128
 call .Lo_field_string
 cmp rax,-2
 je .Lo_post_invalid
 mov rax,rbx
 pop rbx
 ret
.Lo_post_restore_bad:
 xor edi,edi
 call http_set_content_type
.Lo_post_network:
 lea rax,[rip+.Lo_network_error]
 cmp qword ptr [rip+net_cancelled],0
 je .Lo_post_check_overflow
 lea rax,[rip+.Lo_cancel_error]
.Lo_post_check_overflow:
 cmp qword ptr [rip+.Lo_overflow],0
 je .Lo_post_set_error
.Lo_post_invalid:
 lea rax,[rip+.Lo_response_error]
.Lo_post_set_error:
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
 pop rbx
 ret

# Valid token response ->commit; preservepreviousrefresh/resource whenflag1.
.Lo_response_credentials:
 push rbx
 push r12
 push r13
 mov r12,rdi
 lea rdi,[rip+.Lo_access]
 lea rsi,[rip+.Lo_new_token]
 mov edx,O_TOKEN_CAP
 call .Lo_field_string
 test rax,rax
 jle .Lo_new_bad
 lea rdi,[rip+.Lo_new_token]
 mov esi,O_TOKEN_CAP
 call .Lo_printable
 test rax,rax
 js .Lo_new_bad
 lea rdi,[rip+.Lo_refresh]
 lea rsi,[rip+.Lo_new_refresh]
 mov edx,O_TOKEN_CAP
 call .Lo_field_string
 cmp rax,-2
 je .Lo_new_bad
 lea rdi,[rip+.Lo_new_refresh]
 mov esi,O_TOKEN_CAP
 call .Lo_printable
 test rax,rax
 js .Lo_new_bad
 lea rdi,[rip+.Lo_resource]
 lea rsi,[rip+.Lo_new_resource]
 mov edx,2049
 call .Lo_field_string
 cmp rax,-2
 je .Lo_new_bad
 lea rdi,[rip+.Lo_new_resource]
 mov esi,2049
 call .Lo_printable
 test rax,rax
 js .Lo_new_bad
 lea rdi,[rip+.Lo_type]
 lea rsi,[rip+.Lo_type_text]
 mov edx,64
 call .Lo_field_string
 cmp rax,-2
 je .Lo_new_bad
 test rax,rax
 jle .Lo_new_expiry
 lea rdi,[rip+.Lo_type_text]
 lea rsi,[rip+.Lo_bearer]
 call .Lo_equal
 test rax,rax
 jz .Lo_new_bad
.Lo_new_expiry:
 lea rdi,[rip+.Lo_expires_in]
 call .Lo_field_number
 test rax,rax
 jle .Lo_new_bad
 cmp rax,2678400
 ja .Lo_new_bad
 imul r13,rax,1000
 call .Lo_now_ms
 test rax,rax
 js .Lo_new_bad
 add r13,rax
 jo .Lo_new_bad
 lea rdi,[rip+.Lo_token]
 lea rsi,[rip+.Lo_new_token]
 mov edx,O_TOKEN_CAP
 call .Lo_copyz
 cmp byte ptr [rip+.Lo_new_refresh],0
 jne .Lo_new_copy_refresh
 test r12,r12
 jnz .Lo_new_resource_commit
.Lo_new_copy_refresh:
 lea rdi,[rip+.Lo_refresh_token]
 lea rsi,[rip+.Lo_new_refresh]
 mov edx,O_TOKEN_CAP
 call .Lo_copyz
.Lo_new_resource_commit:
 cmp byte ptr [rip+.Lo_new_resource],0
 jne .Lo_new_copy_resource
 test r12,r12
 jnz .Lo_new_done
.Lo_new_copy_resource:
 lea rdi,[rip+.Lo_resource_url]
 lea rsi,[rip+.Lo_new_resource]
 mov edx,2049
 call .Lo_copyz
.Lo_new_done:
 mov qword ptr [rip+.Lo_expiry_ms],r13
 xor eax,eax
 jmp .Lo_new_return
.Lo_new_bad:
 lea rax,[rip+.Lo_response_error]
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
.Lo_new_return:
 pop r13
 pop r12
 pop rbx
 ret

# Lock private directory's stable0600lockfile; no unlink races across forkworkers.
# Nonblocking retries bound contention to30s and observe native cancellation.
.Lo_lock_dir:
 push rbx
 push r12
 sub rsp,24
 mov eax,257
 lea rsi,[rip+.Lo_lock]
 mov edx,0xa0842
 mov r10d,384
 syscall
 test rax,rax
 js .Lo_lock_bad
 mov rbx,rax
 mov eax,5
 mov rdi,rbx
 lea rsi,[rip+.Lo_stat]
 syscall
 test rax,rax
 js .Lo_lock_close_bad
 mov eax,dword ptr [rip+.Lo_stat+24]
 and eax,0xf000
 cmp eax,0x8000
 jne .Lo_lock_close_bad
 cmp qword ptr [rip+.Lo_stat+16],1
 jne .Lo_lock_close_bad
 mov eax,107
 syscall
 cmp eax,dword ptr [rip+.Lo_stat+28]
 jne .Lo_lock_close_bad
 mov eax,91
 mov rdi,rbx
 mov esi,384
 syscall
 test rax,rax
 js .Lo_lock_close_bad
 call .Lo_now_ms
 test rax,rax
 js .Lo_lock_close_bad
 lea r12,[rax+30000]
.Lo_lock_retry:
 call net_check_cancel
 test rax,rax
 js .Lo_lock_close_bad
 mov eax,73
 mov rdi,rbx
 mov esi,6
 syscall
 test rax,rax
 jz .Lo_lock_acquired
 cmp rax,-11
 jne .Lo_lock_close_bad
 call .Lo_now_ms
 cmp rax,r12
 jae .Lo_lock_close_bad
 mov qword ptr [rsp],0
 mov qword ptr [rsp+8],100000000
 mov eax,35
 mov rdi,rsp
 xor esi,esi
 syscall
 test rax,rax
 js .Lo_lock_close_bad
 jmp .Lo_lock_retry
.Lo_lock_acquired:
 mov rax,rbx
 add rsp,24
 pop r12
 pop rbx
 ret
.Lo_lock_close_bad:
 mov eax,3
 mov rdi,rbx
 syscall
.Lo_lock_bad:
 mov rax,-2
 add rsp,24
 pop r12
 pop rbx
 ret
.Lo_unlock_close:
 push rbx
 mov rbx,rdi
 mov eax,73
 mov esi,8
 syscall
 mov eax,3
 mov rdi,rbx
 syscall
 pop rbx
 ret

# Build compact credential JSON using the shared nativeboundedbuilder.
.Lo_save_json:
 push rbx
 mov qword ptr [rip+.Lo_save_builder+16],0
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_json_access]
 mov edx,16
 call qx_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_token]
 call .Lo_zlen
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_token]
 mov rdx,rax
 call qx_quote_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_json_refresh]
 mov edx,17
 call qx_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_refresh_token]
 call .Lo_zlen
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_refresh_token]
 mov rdx,rax
 call qx_quote_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_json_resource]
 mov edx,16
 call qx_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_resource_url]
 call .Lo_zlen
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_resource_url]
 mov rdx,rax
 call qx_quote_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_json_expiry]
 mov edx,37
 call qx_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_number]
 mov rsi,qword ptr [rip+.Lo_expiry_ms]
 call qx_uint
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_number]
 mov rdx,rax
 call qx_cat
 test rax,rax
 js .Lo_save_json_bad
 lea rdi,[rip+.Lo_save_builder]
 lea rsi,[rip+.Lo_json_end]
 mov edx,2
 call qx_cat
 test rax,rax
 js .Lo_save_json_bad
 mov rax,qword ptr [rip+.Lo_save_builder+16]
 mov qword ptr [rip+.Lo_save_len],rax
 xor eax,eax
 pop rbx
 ret
.Lo_save_json_bad:
 mov rax,-2
 pop rbx
 ret

# Atomic private cache replace in dirfd. Caller owns refresh/loginfilelock.
.Lo_save_cache:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 call .Lo_save_json
 test rax,rax
 jnz .Lo_save_bad
 mov eax,318
 lea rdi,[rip+.Lo_random]
 mov esi,8
 xor edx,edx
 syscall
 cmp rax,8
 jne .Lo_save_bad
 lea rdi,[rip+.Lo_temp]
 lea rsi,[rip+.Lo_temp_prefix]
 mov ecx,11
 rep movsb
 lea rsi,[rip+.Lo_random]
 lea r8,[rip+.Lo_hex]
 xor ecx,ecx
.Lo_temp_hex:
 movzx eax,byte ptr [rsi+rcx]
 mov edx,eax
 shr eax,4
 and edx,15
 mov al,byte ptr [r8+rax]
 mov dl,byte ptr [r8+rdx]
 mov byte ptr [rdi+rcx*2],al
 mov byte ptr [rdi+rcx*2+1],dl
 inc rcx
 cmp rcx,8
 jb .Lo_temp_hex
 mov byte ptr [rdi+16],0
 mov eax,257
 mov rdi,r12
 lea rsi,[rip+.Lo_temp]
 mov edx,0xa00c1
 mov r10d,384
 syscall
 test rax,rax
 js .Lo_save_bad
 mov r13,rax
 mov eax,91
 mov rdi,r13
 mov esi,384
 syscall
 test rax,rax
 js .Lo_save_close_bad
 mov rdi,r13
 lea rsi,[rip+.Lo_save]
 mov rdx,qword ptr [rip+.Lo_save_len]
 call qx_write_all
 cmp rax,qword ptr [rip+.Lo_save_len]
 jne .Lo_save_close_bad
 mov eax,74
 mov rdi,r13
 syscall
 test rax,rax
 js .Lo_save_close_bad
 mov eax,3
 mov rdi,r13
 syscall
 test rax,rax
 js .Lo_save_unlink_bad
 mov eax,264
 mov rdi,r12
 lea rsi,[rip+.Lo_temp]
 mov rdx,r12
 lea r10,[rip+.Lo_file]
 syscall
 test rax,rax
 js .Lo_save_unlink_bad
 mov eax,74
 mov rdi,r12
 syscall
 test rax,rax
 js .Lo_save_bad
 xor eax,eax
 jmp .Lo_save_return
.Lo_save_close_bad:
 mov eax,3
 mov rdi,r13
 syscall
.Lo_save_unlink_bad:
 mov eax,263
 mov rdi,r12
 lea rsi,[rip+.Lo_temp]
 xor edx,edx
 syscall
.Lo_save_bad:
 lea rax,[rip+.Lo_save_error]
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
.Lo_save_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .data
.Lo_save_builder: .quad .Lo_save,65536,0
.section .bss
.Lo_overflow: .skip 8
.Lo_number: .skip 32

.section .text
# Readycache or native refresh. External source never reaches refresh path.
oauth_ensure:
 push rbx
 push r12
 push r13
 push r14
 push r15
 call .Lo_credentials_ready
 test rax,rax
 jz .Lo_ensure_ok
 cmp qword ptr [rip+.Lo_source],1
 jne .Lo_ensure_external
 cmp byte ptr [rip+.Lo_refresh_token],0
 je .Lo_ensure_need_login
 xor edi,edi
 call .Lo_open_native
 test rax,rax
 js .Lo_ensure_invalid
 mov r12,rax
 mov rdi,rax
 call .Lo_lock_dir
 test rax,rax
 js .Lo_ensure_close_dir_bad
 mov r13,rax
 # Re-read afterflock: another process may already have rotated the token.
 mov rdi,r12
 lea rsi,[rip+.Lo_file]
 mov edx,1
 call .Lo_read_cache
 test rax,rax
 js .Lo_ensure_unlock_invalid
 call .Lo_parse_response
 test rax,rax
 jnz .Lo_ensure_unlock_invalid
 call .Lo_cache_fields
 test rax,rax
 jnz .Lo_ensure_unlock_invalid
 call .Lo_credentials_ready
 test rax,rax
 jz .Lo_ensure_unlock_ok
 cmp byte ptr [rip+.Lo_refresh_token],0
 je .Lo_ensure_unlock_needlogin
 call .Lo_form_reset
 lea rdi,[rip+.Lo_grant_key]
 lea rsi,[rip+.Lo_refresh_grant]
 call .Lo_form_add
 test rax,rax
 js .Lo_ensure_unlock_bad
 lea rdi,[rip+.Lo_refresh]
 lea rsi,[rip+.Lo_refresh_token]
 call .Lo_form_add
 test rax,rax
 js .Lo_ensure_unlock_bad
 lea rdi,[rip+.Lo_client_key]
 lea rsi,[rip+.Lo_client_id]
 call .Lo_form_add
 test rax,rax
 js .Lo_ensure_unlock_bad
 lea rdi,[rip+o_token_endpoint]
 call .Lo_auth_post
 test rax,rax
 js .Lo_ensure_unlock_bad
 cmp rax,200
 jb .Lo_ensure_refresh_error
 cmp rax,300
 jae .Lo_ensure_refresh_error
 cmp byte ptr [rip+.Lo_error_text],0
 jne .Lo_ensure_refresh_error
 mov edi,1
 call .Lo_response_credentials
 test rax,rax
 jnz .Lo_ensure_unlock_bad
 mov rdi,r12
 call .Lo_save_cache
 test rax,rax
 jnz .Lo_ensure_unsaved
.Lo_ensure_unlock_ok:
 mov rdi,r13
 call .Lo_unlock_close
 mov eax,3
 mov rdi,r12
 syscall
.Lo_ensure_ok:
 xor eax,eax
 jmp .Lo_ensure_return
.Lo_ensure_unsaved:
 mov byte ptr [rip+.Lo_token],0
 mov qword ptr [rip+.Lo_source],0
 jmp .Lo_ensure_unlock_bad
.Lo_ensure_refresh_error:
 lea rax,[rip+.Lo_refresh_error]
 mov qword ptr [rip+.Lo_error],rax
 jmp .Lo_ensure_unlock_bad
.Lo_ensure_unlock_needlogin:
 lea rax,[rip+.Lo_need_login]
 mov qword ptr [rip+.Lo_error],rax
 jmp .Lo_ensure_unlock_bad
.Lo_ensure_unlock_invalid:
 lea rax,[rip+.Lo_invalid_cache]
 mov qword ptr [rip+.Lo_error],rax
.Lo_ensure_unlock_bad:
 mov rdi,r13
 call .Lo_unlock_close
 mov eax,3
 mov rdi,r12
 syscall
 mov rax,-2
 jmp .Lo_ensure_return
.Lo_ensure_close_dir_bad:
 mov eax,3
 mov rdi,r12
 syscall
.Lo_ensure_invalid:
 lea rax,[rip+.Lo_invalid_cache]
 cmp qword ptr [rip+net_cancelled],0
 je .Lo_ensure_error_selected
 lea rax,[rip+.Lo_cancel_error]
.Lo_ensure_error_selected:
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
 jmp .Lo_ensure_return
.Lo_ensure_external:
 cmp qword ptr [rip+.Lo_source],2
 jb .Lo_ensure_need_login
 lea rax,[rip+.Lo_external_expired]
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
 jmp .Lo_ensure_return
.Lo_ensure_need_login:
 lea rax,[rip+.Lo_need_login]
 mov qword ptr [rip+.Lo_error],rax
 mov rax,-2
.Lo_ensure_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Fixed32 randombytes ->43 base64urlbytes,withoutpadding. Private immutabletable.
.Lo_b64_32:
 push rbx
 mov r8,rdi
 mov r9,rsi
 lea r10,[rip+.Lo_b64url]
 mov ecx,10
.Lo_b64_group:
 movzx eax,byte ptr [r8]
 movzx edx,byte ptr [r8+1]
 shl eax,16
 shl edx,8
 or eax,edx
 movzx edx,byte ptr [r8+2]
 or eax,edx
 mov ebx,eax
 shr eax,18
 mov al,byte ptr [r10+rax]
 mov byte ptr [r9],al
 mov eax,ebx
 shr eax,12
 and eax,63
 mov al,byte ptr [r10+rax]
 mov byte ptr [r9+1],al
 mov eax,ebx
 shr eax,6
 and eax,63
 mov al,byte ptr [r10+rax]
 mov byte ptr [r9+2],al
 and ebx,63
 mov al,byte ptr [r10+rbx]
 mov byte ptr [r9+3],al
 add r8,3
 add r9,4
 dec ecx
 jnz .Lo_b64_group
 movzx eax,byte ptr [r8]
 movzx edx,byte ptr [r8+1]
 shl eax,8
 or eax,edx
 mov ebx,eax
 shr eax,10
 mov al,byte ptr [r10+rax]
 mov byte ptr [r9],al
 mov eax,ebx
 shr eax,4
 and eax,63
 mov al,byte ptr [r10+rax]
 mov byte ptr [r9+1],al
 and ebx,15
 shl ebx,2
 mov al,byte ptr [r10+rbx]
 mov byte ptr [r9+2],al
 mov byte ptr [r9+3],0
 xor eax,eax
 pop rbx
 ret
.Lo_random32:
 push rbx
 xor ebx,ebx
.Lo_random_more:
 mov eax,318
 lea rdi,[rip+.Lo_random]
 add rdi,rbx
 mov esi,32
 sub rsi,rbx
 xor edx,edx
 syscall
 cmp rax,-4
 je .Lo_random_more
 test rax,rax
 jle .Lo_random_bad
 add rbx,rax
 cmp rbx,32
 jb .Lo_random_more
 xor eax,eax
 pop rbx
 ret
.Lo_random_bad:
 mov rax,-2
 pop rbx
 ret
# Deliberately printonlyverificationURL+usercode,nevercredential/tokenresponses.
.Lo_print_login:
 push rbx
 mov edi,1
 lea rsi,[rip+.Lo_open_msg]
 mov edx,5
 call qx_write_all
 lea rdi,[rip+.Lo_verification]
 call .Lo_zlen
 mov edi,1
 lea rsi,[rip+.Lo_verification]
 mov rdx,rax
 call qx_write_all
 mov edi,1
 lea rsi,[rip+.Lo_code_msg]
 mov edx,7
 call qx_write_all
 lea rdi,[rip+.Lo_user_code]
 call .Lo_zlen
 mov edi,1
 lea rsi,[rip+.Lo_user_code]
 mov rdx,rax
 call qx_write_all
 mov edi,1
 lea rsi,[rip+.Lo_wait_msg]
 mov edx,50
 call qx_write_all
 xor eax,eax
 pop rbx
 ret
# Clearephemeralgrant/form/HTTPJSONcopies;persistedtokenbuffers remain usable.
.Lo_clear_ephemeral:
 lea rdi,[rip+.Lo_verifier]
 xor eax,eax
 mov ecx,44
 rep stosb
 lea rdi,[rip+.Lo_device_code]
 mov ecx,8193
 rep stosb
 lea rdi,[rip+.Lo_random]
 mov ecx,32
 rep stosb
 lea rdi,[rip+.Lo_form]
 mov ecx,65536/8
 rep stosq
 lea rdi,[rip+.Lo_response]
 mov ecx,65536/8
 rep stosq
 ret

oauth_login:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,16
 mov rsi,rdi
 lea rdi,[rip+.Lo_home]
 mov edx,4096
 call .Lo_copyz
 test rax,rax
 js .Lo_login_invalid
 mov qword ptr [rip+.Lo_source],0
 mov byte ptr [rip+.Lo_token],0
 mov byte ptr [rip+.Lo_refresh_token],0
 mov byte ptr [rip+.Lo_resource_url],0
 call .Lo_random32
 test rax,rax
 jnz .Lo_login_response_error
 lea rdi,[rip+.Lo_random]
 lea rsi,[rip+.Lo_verifier]
 call .Lo_b64_32
 lea rdi,[rip+.Lo_verifier]
 mov esi,43
 lea rdx,[rip+.Lo_digest]
 call sha256_hash
 lea rdi,[rip+.Lo_digest]
 lea rsi,[rip+.Lo_challenge]
 call .Lo_b64_32
 call .Lo_form_reset
 lea rdi,[rip+.Lo_client_key]
 lea rsi,[rip+.Lo_client_id]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_scope_key]
 lea rsi,[rip+.Lo_scope]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_challenge_key]
 lea rsi,[rip+.Lo_challenge]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_method_key]
 lea rsi,[rip+.Lo_method]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+o_device_endpoint]
 call .Lo_auth_post
 test rax,rax
 js .Lo_login_fail
 cmp rax,200
 jb .Lo_login_response_error
 cmp rax,300
 jae .Lo_login_response_error
 cmp byte ptr [rip+.Lo_error_text],0
 jne .Lo_login_response_error
 lea rdi,[rip+.Lo_device]
 lea rsi,[rip+.Lo_device_code]
 mov edx,8193
 call .Lo_field_string
 test rax,rax
 jle .Lo_login_response_error
 lea rdi,[rip+.Lo_user]
 lea rsi,[rip+.Lo_user_code]
 mov edx,129
 call .Lo_field_string
 test rax,rax
 jle .Lo_login_response_error
 lea rdi,[rip+.Lo_user_code]
 mov esi,129
 call .Lo_printable
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_uri_complete]
 lea rsi,[rip+.Lo_verification]
 mov edx,2049
 call .Lo_field_string
 cmp rax,-2
 je .Lo_login_response_error
 test rax,rax
 jg .Lo_login_have_uri
 lea rdi,[rip+.Lo_uri]
 lea rsi,[rip+.Lo_verification]
 mov edx,2049
 call .Lo_field_string
 test rax,rax
 jle .Lo_login_response_error
.Lo_login_have_uri:
 lea rdi,[rip+.Lo_verification]
 mov esi,2049
 call .Lo_printable
 test rax,rax
 js .Lo_login_response_error
 cmp rax,8
 jb .Lo_login_response_error
 cmp dword ptr [rip+.Lo_verification],0x70747468
 jne .Lo_login_response_error
 cmp dword ptr [rip+.Lo_verification+4],0x2f2f3a73
 jne .Lo_login_response_error
 lea rdi,[rip+.Lo_interval]
 call .Lo_field_number
 cmp rax,-2
 je .Lo_login_response_error
 cmp rax,1
 jge .Lo_login_interval
 mov eax,5
.Lo_login_interval:
 cmp rax,3600
 ja .Lo_login_response_error
 mov qword ptr [rip+.Lo_poll_interval],rax
 lea rdi,[rip+.Lo_expires_in]
 call .Lo_field_number
 cmp rax,-2
 je .Lo_login_response_error
 cmp rax,1
 jge .Lo_login_expiry
 mov eax,600
.Lo_login_expiry:
 cmp rax,86400
 ja .Lo_login_response_error
 mov rbx,rax
 call .Lo_now_ms
 test rax,rax
 js .Lo_login_response_error
 imul rbx,rbx,1000
 add rbx,rax
 mov qword ptr [rip+.Lo_deadline],rbx
 call .Lo_print_login
.Lo_login_poll:
 call .Lo_now_ms
 cmp rax,qword ptr [rip+.Lo_deadline]
 jae .Lo_login_expired
 mov rcx,qword ptr [rip+.Lo_deadline]
 sub rcx,rax
 add rcx,999
 xor edx,edx
 mov rax,rcx
 mov ecx,1000
 div rcx
 mov rcx,qword ptr [rip+.Lo_poll_interval]
 cmp rcx,rax
 cmova rcx,rax
 mov qword ptr [rsp],rcx
 mov qword ptr [rsp+8],0
 mov eax,35
 mov rdi,rsp
 xor esi,esi
 syscall
 test rax,rax
 js .Lo_login_cancel
 call .Lo_now_ms
 cmp rax,qword ptr [rip+.Lo_deadline]
 jae .Lo_login_expired
 call .Lo_form_reset
 lea rdi,[rip+.Lo_grant_key]
 lea rsi,[rip+.Lo_device_grant]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_client_key]
 lea rsi,[rip+.Lo_client_id]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_device]
 lea rsi,[rip+.Lo_device_code]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+.Lo_verifier_key]
 lea rsi,[rip+.Lo_verifier]
 call .Lo_form_add
 test rax,rax
 js .Lo_login_response_error
 lea rdi,[rip+o_token_endpoint]
 call .Lo_auth_post
 test rax,rax
 js .Lo_login_fail
 lea rdi,[rip+.Lo_error_text]
 lea rsi,[rip+.Lo_pending]
 call .Lo_equal
 test rax,rax
 jnz .Lo_login_poll
 lea rdi,[rip+.Lo_error_text]
 lea rsi,[rip+.Lo_slow]
 call .Lo_equal
 test rax,rax
 jz .Lo_login_not_slow
 add qword ptr [rip+.Lo_poll_interval],5
 cmp qword ptr [rip+.Lo_poll_interval],3600
 ja .Lo_login_expired
 jmp .Lo_login_poll
.Lo_login_not_slow:
 lea rdi,[rip+.Lo_error_text]
 lea rsi,[rip+.Lo_denied]
 call .Lo_equal
 test rax,rax
 jnz .Lo_login_denied
 lea rdi,[rip+.Lo_error_text]
 lea rsi,[rip+.Lo_expired]
 call .Lo_equal
 test rax,rax
 jnz .Lo_login_expired
 cmp byte ptr [rip+.Lo_error_text],0
 jne .Lo_login_response_error
 cmp qword ptr [rip+.Lo_http_code],200
 jb .Lo_login_response_error
 cmp qword ptr [rip+.Lo_http_code],300
 jae .Lo_login_response_error
 xor edi,edi
 call .Lo_response_credentials
 test rax,rax
 jnz .Lo_login_fail
 mov edi,1
 call .Lo_open_native
 test rax,rax
 js .Lo_login_save_error
 mov r12,rax
 mov rdi,rax
 call .Lo_lock_dir
 test rax,rax
 js .Lo_login_close_save_error
 mov r13,rax
 mov rdi,r12
 call .Lo_save_cache
 mov r14,rax
 mov rdi,r13
 call .Lo_unlock_close
 mov eax,3
 mov rdi,r12
 syscall
 test r14,r14
 jnz .Lo_login_save_error
 mov qword ptr [rip+.Lo_source],1
 mov edi,1
 lea rsi,[rip+.Lo_saved_msg]
 mov edx,50
 call qx_write_all
 call .Lo_clear_ephemeral
 xor eax,eax
 jmp .Lo_login_return
.Lo_login_close_save_error:
 mov eax,3
 mov rdi,r12
 syscall
.Lo_login_save_error:
 mov byte ptr [rip+.Lo_token],0
 lea rax,[rip+.Lo_save_error]
 cmp qword ptr [rip+net_cancelled],0
 je .Lo_login_set_error
 lea rax,[rip+.Lo_cancel_error]
 jmp .Lo_login_set_error
.Lo_login_invalid:
 lea rax,[rip+.Lo_invalid_cache]
 jmp .Lo_login_set_error
.Lo_login_response_error:
 lea rax,[rip+.Lo_response_error]
 jmp .Lo_login_set_error
.Lo_login_denied:
 lea rax,[rip+.Lo_denied_error]
 jmp .Lo_login_set_error
.Lo_login_expired:
 lea rax,[rip+.Lo_expired_error]
 jmp .Lo_login_set_error
.Lo_login_cancel:
 lea rax,[rip+.Lo_cancel_error]
.Lo_login_set_error:
 mov qword ptr [rip+.Lo_error],rax
.Lo_login_fail:
 call .Lo_clear_ephemeral
 mov rax,-2
.Lo_login_return:
 add rsp,16
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .note.GNU-stack,"",@progbits
