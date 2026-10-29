# Application JSON byte routing with fixed ABI data and byte classification.
# Each invocation owns its cursors and bounded stack. No writable globals.
.include "abi.inc"
.intel_syntax noprefix
.text

# Private parser context offsets. At most 64 open containers / 40 bytes per
# recursive value frame; source and token capacities are checked before access.
.equ J_SRC,0
.equ J_SIZE,8
.equ J_TOK,16
.equ J_CAP,24
.equ J_POS,32
.equ J_COUNT,40
.equ J_DEPTH,48

.globl json_parse
.type json_parse,@function
json_parse:
    push r12
    sub rsp,64
    mov r12,rsp
    test rdi,rdi
    jz .Ljp_bad_root
    test rdx,rdx
    jz .Ljp_bad_root
    test rsi,rsi
    jz .Ljp_bad_root
    cmp rsi,MAX_JSON
    ja .Ljp_limit_root
    test rcx,rcx
    jz .Ljp_limit_root
    mov rax,MAX_TOKENS
    cmp rcx,rax
    cmova rcx,rax
    mov [r12+J_SRC],rdi
    mov [r12+J_SIZE],rsi
    mov [r12+J_TOK],rdx
    mov [r12+J_CAP],rcx
    mov qword ptr [r12+J_POS],0
    mov qword ptr [r12+J_COUNT],0
    mov qword ptr [r12+J_DEPTH],0
    call .Ljp_value
    test rax,rax
    js .Ljp_return_root
    call .Ljp_ws
    mov rax,[r12+J_POS]
    cmp rax,[r12+J_SIZE]
    jne .Ljp_bad_root
    mov rax,[r12+J_COUNT]
    jmp .Ljp_return_root
.Ljp_bad_root:
    mov rax,-1
    jmp .Ljp_return_root
.Ljp_limit_root:
    mov rax,-2
.Ljp_return_root:
    add rsp,64
    pop r12
    ret
.size json_parse,.-json_parse

# Whitespace class is immutable. Reads only within the acquired byte extent.
.Ljp_ws:
    mov rax,[r12+J_POS]
    mov rcx,[r12+J_SIZE]
    mov rdx,[r12+J_SRC]
    lea r9,[rip+.Ljson_classes]
.Ljp_ws_loop:
    cmp rax,rcx
    jae .Ljp_ws_done
    movzx r8d,byte ptr [rdx+rax]
    cmp byte ptr [r9+r8],8
    jne .Ljp_ws_done
    inc rax
    jmp .Ljp_ws_loop
.Ljp_ws_done:
    mov [r12+J_POS],rax
    ret

# Value frame: token index, source start, type, closing byte, spare (40 bytes).
.Ljp_value:
    sub rsp,40
    call .Ljp_ws
    mov rax,[r12+J_POS]
    cmp rax,[r12+J_SIZE]
    jae .Ljp_value_bad
    mov [rsp+8],rax
    mov rdx,[r12+J_SRC]
    movzx edx,byte ptr [rdx+rax]
    lea rcx,[rip+.Ljson_classes]
    movzx eax,byte ptr [rcx+rdx]
    test eax,eax
    jz .Ljp_value_bad
    cmp eax,7
    ja .Ljp_value_bad
    mov [rsp+16],rax
    mov rcx,[r12+J_COUNT]
    cmp rcx,[r12+J_CAP]
    jae .Ljp_value_limit
    mov [rsp],rcx
    mov rdx,rcx
    shl rdx,5
    add rdx,[r12+J_TOK]
    mov [rdx+T_TYPE],rax
    mov r8,[rsp+8]
    mov [rdx+T_START],r8
    mov qword ptr [rdx+T_LEN],0
    inc rcx
    mov [r12+J_COUNT],rcx
    mov [rdx+T_END],rcx
    lea rcx,[rip+.Ljp_routes]
    movsxd rdx,dword ptr [rcx+rax*4]
    add rdx,rcx
    jmp rdx
.Ljp_object:
    mov qword ptr [rsp+24],'}'
    jmp .Ljp_container
.Ljp_array:
    mov qword ptr [rsp+24],']'
.Ljp_container:
    inc qword ptr [r12+J_DEPTH]
    cmp qword ptr [r12+J_DEPTH],64
    ja .Ljp_value_limit
    inc qword ptr [r12+J_POS]
    call .Ljp_ws
    mov rax,[r12+J_POS]
    cmp rax,[r12+J_SIZE]
    jae .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    movzx eax,byte ptr [rdx+rax]
    cmp rax,[rsp+24]
    je .Ljp_close
.Ljp_element:
    cmp qword ptr [rsp+16],JT_OBJECT
    jne .Ljp_element_value
    mov rax,[r12+J_POS]
    cmp rax,[r12+J_SIZE]
    jae .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    cmp byte ptr [rdx+rax],'"'
    jne .Ljp_value_bad
    call .Ljp_value
    test rax,rax
    js .Ljp_value_return
    call .Ljp_ws
    mov rax,[r12+J_POS]
    cmp rax,[r12+J_SIZE]
    jae .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    cmp byte ptr [rdx+rax],':'
    jne .Ljp_value_bad
    inc qword ptr [r12+J_POS]
.Ljp_element_value:
    call .Ljp_value
    test rax,rax
    js .Ljp_value_return
    call .Ljp_ws
    mov rax,[r12+J_POS]
    cmp rax,[r12+J_SIZE]
    jae .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    movzx eax,byte ptr [rdx+rax]
    cmp rax,[rsp+24]
    je .Ljp_close
    cmp al,','
    jne .Ljp_value_bad
    inc qword ptr [r12+J_POS]
    call .Ljp_ws
    jmp .Ljp_element
.Ljp_close:
    inc qword ptr [r12+J_POS]
    dec qword ptr [r12+J_DEPTH]
    mov rdx,[rsp]
    shl rdx,5
    add rdx,[r12+J_TOK]
    mov rax,[r12+J_POS]
    sub rax,[rsp+8]
    mov [rdx+T_LEN],rax
    mov rax,[r12+J_COUNT]
    mov [rdx+T_END],rax
    xor eax,eax
    jmp .Ljp_value_return
.Ljp_string:
    call .Ljp_scan_string
    test rax,rax
    js .Ljp_value_return
    mov rcx,[rsp]
    shl rcx,5
    add rcx,[r12+J_TOK]
    mov [rcx+T_START],rdx
    mov [rcx+T_LEN],rax
    xor eax,eax
    jmp .Ljp_value_return
.Ljp_number:
    call .Ljp_scan_number
    test rax,rax
    js .Ljp_value_return
    jmp .Ljp_leaf_finish
.Ljp_true:
    mov rax,[r12+J_POS]
    lea rcx,[rax+4]
    cmp rcx,[r12+J_SIZE]
    ja .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    cmp dword ptr [rdx+rax],0x65757274
    jne .Ljp_value_bad
    mov [r12+J_POS],rcx
    jmp .Ljp_leaf_finish
.Ljp_false:
    mov rax,[r12+J_POS]
    lea rcx,[rax+5]
    cmp rcx,[r12+J_SIZE]
    ja .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    cmp dword ptr [rdx+rax],0x736c6166
    jne .Ljp_value_bad
    cmp byte ptr [rdx+rax+4],'e'
    jne .Ljp_value_bad
    mov [r12+J_POS],rcx
    jmp .Ljp_leaf_finish
.Ljp_null:
    mov rax,[r12+J_POS]
    lea rcx,[rax+4]
    cmp rcx,[r12+J_SIZE]
    ja .Ljp_value_bad
    mov rdx,[r12+J_SRC]
    cmp dword ptr [rdx+rax],0x6c6c756e
    jne .Ljp_value_bad
    mov [r12+J_POS],rcx
.Ljp_leaf_finish:
    mov rcx,[rsp]
    shl rcx,5
    add rcx,[r12+J_TOK]
    mov rax,[r12+J_POS]
    sub rax,[rsp+8]
    mov [rcx+T_LEN],rax
    xor eax,eax
    jmp .Ljp_value_return
.Ljp_value_bad:
    mov rax,-1
    jmp .Ljp_value_return
.Ljp_value_limit:
    mov rax,-2
.Ljp_value_return:
    add rsp,40
    ret

# Locate the unescaped closing quote, then validate its bounded contents with
# the same decoder exported to callers (NULL destination selects measure mode).
.Ljp_scan_string:
    sub rsp,24
    mov rax,[r12+J_POS]
    inc rax
    mov [rsp],rax
    mov rdx,[r12+J_SRC]
    mov rcx,[r12+J_SIZE]
.Ljp_string_loop:
    cmp rax,rcx
    jae .Ljp_string_bad
    movzx r8d,byte ptr [rdx+rax]
    cmp r8b,'"'
    je .Ljp_string_end
    cmp r8b,0x20
    jb .Ljp_string_bad
    cmp r8b,'\\'
    jne .Ljp_string_advance
    inc rax
    cmp rax,rcx
    jae .Ljp_string_bad
.Ljp_string_advance:
    inc rax
    jmp .Ljp_string_loop
.Ljp_string_end:
    mov rsi,[rsp]
    sub rax,rsi
    mov [rsp+8],rax
    add rsi,rdx
    mov rdx,rax
    xor edi,edi
    mov ecx,MAX_JSON
    mov rax,[rsp]
    add rax,[rsp+8]
    inc rax
    mov [r12+J_POS],rax
    call .Ljson_decode_entry
    test rax,rax
    js .Ljp_string_return
    mov rax,[rsp+8]
    mov rdx,[rsp]
    jmp .Ljp_string_return
.Ljp_string_bad:
    mov rax,-1
.Ljp_string_return:
    add rsp,24
    ret

# Number grammar is exact JSON, not strtod: -?(0|[1-9][0-9]*)(.[0-9]+)?
# ([eE][+-]?[0-9]+)? . No conversion, floating-point, or global locale is used.
.Ljp_scan_number:
    mov r8,[r12+J_POS]
    mov r9,[r12+J_SIZE]
    mov r10,[r12+J_SRC]
    cmp byte ptr [r10+r8],'-'
    jne .Ljp_num_integer
    inc r8
    cmp r8,r9
    jae .Ljp_num_bad
.Ljp_num_integer:
    movzx eax,byte ptr [r10+r8]
    cmp al,'0'
    je .Ljp_num_zero
    sub eax,'1'
    cmp eax,8
    ja .Ljp_num_bad
.Ljp_num_digits:
    inc r8
    cmp r8,r9
    jae .Ljp_num_done
    movzx eax,byte ptr [r10+r8]
    sub eax,'0'
    cmp eax,9
    jbe .Ljp_num_digits
    jmp .Ljp_num_fraction
.Ljp_num_zero:
    inc r8
.Ljp_num_fraction:
    cmp r8,r9
    jae .Ljp_num_done
    cmp byte ptr [r10+r8],'.'
    jne .Ljp_num_exponent
    inc r8
    cmp r8,r9
    jae .Ljp_num_bad
    movzx eax,byte ptr [r10+r8]
    sub eax,'0'
    cmp eax,9
    ja .Ljp_num_bad
.Ljp_num_fraction_digits:
    inc r8
    cmp r8,r9
    jae .Ljp_num_done
    movzx eax,byte ptr [r10+r8]
    sub eax,'0'
    cmp eax,9
    jbe .Ljp_num_fraction_digits
.Ljp_num_exponent:
    cmp r8,r9
    jae .Ljp_num_done
    movzx eax,byte ptr [r10+r8]
    or eax,0x20
    cmp al,'e'
    jne .Ljp_num_done
    inc r8
    cmp r8,r9
    jae .Ljp_num_bad
    movzx eax,byte ptr [r10+r8]
    cmp al,'+'
    je .Ljp_num_exp_sign
    cmp al,'-'
    jne .Ljp_num_exp_first
.Ljp_num_exp_sign:
    inc r8
    cmp r8,r9
    jae .Ljp_num_bad
.Ljp_num_exp_first:
    movzx eax,byte ptr [r10+r8]
    sub eax,'0'
    cmp eax,9
    ja .Ljp_num_bad
.Ljp_num_exp_digits:
    inc r8
    cmp r8,r9
    jae .Ljp_num_done
    movzx eax,byte ptr [r10+r8]
    sub eax,'0'
    cmp eax,9
    jbe .Ljp_num_exp_digits
.Ljp_num_done:
    mov [r12+J_POS],r8
    xor eax,eax
    ret
.Ljp_num_bad:
    mov rax,-1
    ret

# Public decoding/quoting register contract is shared by private byte chains:
# r12 output (NULL=measure), r13 input, r14 size, r15 capacity,
# rbx input cursor, rbp output cursor. Calls preserve all public callee-saved.
.macro JSON_TEXT_ENTER
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,24
    mov r12,rdi
    mov r13,rsi
    mov r14,rdx
    mov r15,rcx
    xor ebx,ebx
    xor ebp,ebp
.endm
.macro JSON_TEXT_LEAVE
    add rsp,24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
.endm
.globl json_decode
.type json_decode,@function
json_decode:
.Ljson_decode_entry:
    JSON_TEXT_ENTER
    cmp r14,MAX_JSON
    ja .Ljd_capacity
    test r14,r14
    jz .Ljd_done
    test r13,r13
    jz .Ljd_invalid
.Ljd_loop:
    cmp rbx,r14
    jae .Ljd_done
    call .Ljd_next
    test rax,rax
    js .Ljd_return
    call .Ljd_emit
    test rax,rax
    js .Ljd_return
    jmp .Ljd_loop
.Ljd_done:
    mov rax,rbp
    jmp .Ljd_return
.Ljd_invalid:
    mov rax,-1
    jmp .Ljd_return
.Ljd_capacity:
    mov rax,-2
.Ljd_return:
    JSON_TEXT_LEAVE
.size json_decode,.-json_decode

# Decode one escaped JSON character into a Unicode scalar. Scalar bytes have a
# separate bounded chain below; the cursor's acquired extent owns every load.
.Ljd_next:
    sub rsp,24
    cmp rbx,r14
    jae .Ljd_next_bad
    movzx eax,byte ptr [r13+rbx]
    cmp al,0x20
    jb .Ljd_next_bad
    cmp al,'"'
    je .Ljd_next_bad
    cmp al,'\\'
    je .Ljd_escape
    call .Ljd_utf8
    jmp .Ljd_next_return
.Ljd_escape:
    inc rbx
    cmp rbx,r14
    jae .Ljd_next_bad
    movzx eax,byte ptr [r13+rbx]
    inc rbx
    cmp al,'u'
    je .Ljd_unicode
    lea rdx,[rip+.Lescape_decode]
    movzx eax,byte ptr [rdx+rax]
    test eax,eax
    jz .Ljd_next_bad
    jmp .Ljd_next_return
.Ljd_unicode:
    call .Ljd_hex4
    test rax,rax
    js .Ljd_next_return
    cmp eax,0xd800
    jb .Ljd_next_return
    cmp eax,0xdfff
    ja .Ljd_next_return
    cmp eax,0xdbff
    ja .Ljd_next_bad
    mov [rsp],rax
    mov rdx,r14
    sub rdx,rbx
    cmp rdx,6
    jb .Ljd_next_bad
    cmp word ptr [r13+rbx],0x755c
    jne .Ljd_next_bad
    add rbx,2
    call .Ljd_hex4
    cmp eax,0xdc00
    jb .Ljd_next_bad
    cmp eax,0xdfff
    ja .Ljd_next_bad
    sub eax,0xdc00
    mov rdx,[rsp]
    sub edx,0xd800
    shl edx,10
    add eax,edx
    add eax,0x10000
    jmp .Ljd_next_return
.Ljd_next_bad:
    mov rax,-1
.Ljd_next_return:
    add rsp,24
    ret

# Four hex nibbles are a fixed bound; they are materialized, not reparsed as
# four independent decisions. 255 marks invalid byte classes in bound data.
.Ljd_hex4:
    mov rax,r14
    sub rax,rbx
    cmp rax,4
    jb .Ljd_hex_bad
    lea rdx,[rip+.Lhex_values]
    xor eax,eax
    .rept 4
    movzx ecx,byte ptr [r13+rbx]
    movzx ecx,byte ptr [rdx+rcx]
    cmp ecx,255
    je .Ljd_hex_bad
    shl eax,4
    add eax,ecx
    inc rbx
    .endr
    ret
.Ljd_hex_bad:
    mov rax,-1
    ret

# One UTF-8 scalar: byte count is table-selected; shortest-form, surrogate and
# 0x10ffff boundaries are checked. Invalid input never gets replaced silently.
.Ljd_utf8:
    cmp rbx,r14
    jae .Ljd_utf8_bad
    movzx eax,byte ptr [r13+rbx]
    cmp eax,128
    jb .Ljd_utf8_ascii
    lea rdx,[rip+.Lutf8_lengths]
    movzx r8d,byte ptr [rdx+rax]
    cmp r8d,2
    jb .Ljd_utf8_bad
    mov rdx,r14
    sub rdx,rbx
    cmp rdx,r8
    jb .Ljd_utf8_bad
    lea rdx,[rip+.Lutf8_masks]
    and al,byte ptr [rdx+r8]
    mov ecx,1
.Ljd_utf8_continuation:
    lea rdx,[rbx+rcx]
    movzx edx,byte ptr [r13+rdx]
    sub edx,0x80
    cmp edx,0x3f
    ja .Ljd_utf8_bad
    shl eax,6
    add eax,edx
    inc ecx
    cmp ecx,r8d
    jb .Ljd_utf8_continuation
    lea rdx,[rip+.Lutf8_minimum]
    cmp eax,dword ptr [rdx+r8*4]
    jb .Ljd_utf8_bad
    cmp eax,0x10ffff
    ja .Ljd_utf8_bad
    lea edx,[rax-0xd800]
    cmp edx,0x7ff
    jbe .Ljd_utf8_bad
    add rbx,r8
    ret
.Ljd_utf8_ascii:
    inc rbx
    ret
.Ljd_utf8_bad:
    mov rax,-1
    ret

# Emit a scalar as canonical UTF-8. Output span is selected before touching
# memory; NULL measure mode routes the store into an eight-byte red-zone sink.
.Ljd_emit:
    xor ecx,ecx
    cmp eax,0x7f
    seta cl
    xor edx,edx
    cmp eax,0x7ff
    seta dl
    add ecx,edx
    xor edx,edx
    cmp eax,0xffff
    seta dl
    lea ecx,[rcx+rdx+1]
    lea r8,[rbp+rcx]
    cmp r8,rbp
    jb .Ljd_emit_limit
    cmp r8,r15
    ja .Ljd_emit_limit
    lea rdi,[r12+rbp]
    lea rdx,[rsp-8]
    test r12,r12
    cmovz rdi,rdx
    cmp ecx,1
    je .Ljd_emit_one
    cmp ecx,2
    je .Ljd_emit_two
    cmp ecx,3
    je .Ljd_emit_three
    mov edx,eax
    and edx,0x3f
    add edx,0x80
    mov byte ptr [rdi+3],dl
    shr eax,6
    mov edx,eax
    and edx,0x3f
    add edx,0x80
    mov byte ptr [rdi+2],dl
    shr eax,6
    mov edx,eax
    and edx,0x3f
    add edx,0x80
    mov byte ptr [rdi+1],dl
    shr eax,6
    add eax,0xf0
    mov byte ptr [rdi],al
    jmp .Ljd_emit_done
.Ljd_emit_three:
    mov edx,eax
    and edx,0x3f
    add edx,0x80
    mov byte ptr [rdi+2],dl
    shr eax,6
    mov edx,eax
    and edx,0x3f
    add edx,0x80
    mov byte ptr [rdi+1],dl
    shr eax,6
    add eax,0xe0
    mov byte ptr [rdi],al
    jmp .Ljd_emit_done
.Ljd_emit_two:
    mov edx,eax
    and edx,0x3f
    add edx,0x80
    mov byte ptr [rdi+1],dl
    shr eax,6
    add eax,0xc0
.Ljd_emit_one:
    mov byte ptr [rdi],al
.Ljd_emit_done:
    mov rbp,r8
    xor eax,eax
    ret
.Ljd_emit_limit:
    mov rax,-2
    ret

.globl json_quote
.type json_quote,@function
json_quote:
    JSON_TEXT_ENTER
    cmp r14,MAX_JSON
    ja .Ljq_limit
    test r14,r14
    jz .Ljq_begin
    test r13,r13
    jz .Ljq_bad
.Ljq_begin:
    mov eax,'"'
    call .Ljd_emit
    test rax,rax
    js .Ljq_return
.Ljq_loop:
    cmp rbx,r14
    jae .Ljq_end
    call .Ljd_utf8
    test rax,rax
    js .Ljq_return
    cmp eax,'"'
    je .Ljq_short_escape
    cmp eax,'\\'
    je .Ljq_short_escape
    cmp eax,0x20
    jb .Ljq_control
    call .Ljd_emit
    test rax,rax
    js .Ljq_return
    jmp .Ljq_loop
.Ljq_control:
    lea rdx,[rip+.Lescape_encode]
    movzx edx,byte ptr [rdx+rax]
    test edx,edx
    jz .Ljq_unicode_escape
    mov eax,edx
.Ljq_short_escape:
    mov byte ptr [rsp],'\\'
    mov byte ptr [rsp+1],al
    mov edx,2
    jmp .Ljq_emit_escape
.Ljq_unicode_escape:
    mov dword ptr [rsp],0x3030755c
    mov edx,eax
    shr edx,4
    lea rcx,[rip+.Lhex_digits]
    mov dl,byte ptr [rcx+rdx]
    mov byte ptr [rsp+4],dl
    and eax,15
    mov al,byte ptr [rcx+rax]
    mov byte ptr [rsp+5],al
    mov edx,6
.Ljq_emit_escape:
    lea r8,[rbp+rdx]
    cmp r8,rbp
    jb .Ljq_limit
    cmp r8,r15
    ja .Ljq_limit
    lea rdi,[r12+rbp]
    lea rsi,[rsp+8]
    test r12,r12
    cmovz rdi,rsi
    mov rsi,rsp
    mov rcx,rdx
    rep movsb
    mov rbp,r8
    jmp .Ljq_loop
.Ljq_end:
    mov eax,'"'
    call .Ljd_emit
    test rax,rax
    js .Ljq_return
    mov rax,rbp
    jmp .Ljq_return
.Ljq_bad:
    mov rax,-1
    jmp .Ljq_return
.Ljq_limit:
    mov rax,-2
.Ljq_return:
    JSON_TEXT_LEAVE
.size json_quote,.-json_quote

# json_find compares decoded key scalars, so "role" and "r\\u006fle" agree.
# No key-sized allocation is needed. Caller supplies a valid parser token array.
.globl json_find
.type json_find,@function
json_find:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp,88
    test rdi,rdi
    jz .Ljf_missing
    test rsi,rsi
    jz .Ljf_missing
    test rcx,rcx
    jz .Ljf_missing
    mov [rsp+16],rdi
    mov [rsp+24],rsi
    mov [rsp+32],rcx
    mov rax,[rsi+T_START]
    add rax,[rsi+T_LEN]
    jc .Ljf_missing
    cmp rax,MAX_JSON
    ja .Ljf_missing
    mov r12,rax
    mov rax,[rsi+T_END]
    mov rbp,rax
    cmp rax,MAX_TOKENS
    ja .Ljf_missing
    cmp rdx,rax
    jae .Ljf_missing
    mov rax,rdx
    shl rax,5
    add rax,rsi
    cmp qword ptr [rax+T_TYPE],JT_OBJECT
    jne .Ljf_missing
    mov rax,[rax+T_END]
    cmp rax,rbp
    ja .Ljf_missing
    cmp rax,rdx
    jbe .Ljf_missing
    mov [rsp+8],rax
    inc rdx
    mov [rsp],rdx
    xor eax,eax
.Ljf_key_length:
    cmp rax,MAX_JSON
    jae .Ljf_missing
    cmp byte ptr [rcx+rax],0
    je .Ljf_key_length_done
    inc rax
    jmp .Ljf_key_length
.Ljf_key_length_done:
    mov [rsp+40],rax
.Ljf_next_key:
    mov rax,[rsp]
    cmp rax,[rsp+8]
    jae .Ljf_missing
    mov rdx,rax
    shl rdx,5
    add rdx,[rsp+24]
    cmp qword ptr [rdx+T_TYPE],JT_STRING
    jne .Ljf_missing
    mov r13,[rdx+T_START]
    mov r14,[rdx+T_LEN]
    mov rcx,r13
    add rcx,r14
    jc .Ljf_missing
    cmp rcx,r12
    ja .Ljf_missing
    add r13,[rsp+16]
    xor ebx,ebx
    mov qword ptr [rsp+56],0
.Ljf_compare:
    cmp rbx,r14
    jae .Ljf_compare_end
    call .Ljd_next
    test rax,rax
    js .Ljf_skip_value
    mov [rsp+48],rax
    mov [rsp+64],r13
    mov [rsp+72],r14
    mov [rsp+80],rbx
    mov r13,[rsp+32]
    mov r14,[rsp+40]
    mov rbx,[rsp+56]
    call .Ljd_utf8
    mov [rsp+56],rbx
    mov r13,[rsp+64]
    mov r14,[rsp+72]
    mov rbx,[rsp+80]
    cmp rax,[rsp+48]
    jne .Ljf_skip_value
    jmp .Ljf_compare
.Ljf_compare_end:
    mov rax,[rsp+56]
    cmp rax,[rsp+40]
    jne .Ljf_skip_value
    mov rax,[rsp]
    inc rax
    cmp rax,[rsp+8]
    jae .Ljf_missing
    jmp .Ljf_return
.Ljf_skip_value:
    mov rax,[rsp]
    inc rax
    cmp rax,[rsp+8]
    jae .Ljf_missing
    mov rdx,rax
    shl rdx,5
    add rdx,[rsp+24]
    mov rdx,[rdx+T_END]
    cmp rdx,rax
    jbe .Ljf_missing
    cmp rdx,[rsp+8]
    ja .Ljf_missing
    mov [rsp],rdx
    jmp .Ljf_next_key
.Ljf_missing:
    mov rax,-1
.Ljf_return:
    add rsp,88
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
.size json_find,.-json_find

.section .rodata
.Ljp_routes:
    .long .Ljp_value_bad-.Ljp_routes
    .long .Ljp_object-.Ljp_routes
    .long .Ljp_array-.Ljp_routes
    .long .Ljp_string-.Ljp_routes
    .long .Ljp_number-.Ljp_routes
    .long .Ljp_true-.Ljp_routes
    .long .Ljp_false-.Ljp_routes
    .long .Ljp_null-.Ljp_routes
.Ljson_classes:
    .set .Lbyte,0
    .rept 256
    .if .Lbyte==0x7b
    .byte JT_OBJECT
    .elseif .Lbyte==0x5b
    .byte JT_ARRAY
    .elseif .Lbyte==0x22
    .byte JT_STRING
    .elseif .Lbyte==0x2d || (.Lbyte>=0x30 && .Lbyte<=0x39)
    .byte JT_NUMBER
    .elseif .Lbyte==0x74
    .byte JT_TRUE
    .elseif .Lbyte==0x66
    .byte JT_FALSE
    .elseif .Lbyte==0x6e
    .byte JT_NULL
    .elseif .Lbyte==9 || .Lbyte==10 || .Lbyte==13 || .Lbyte==32
    .byte 8
    .else
    .byte 0
    .endif
    .set .Lbyte,.Lbyte+1
    .endr
.Lhex_values:
    .set .Lbyte,0
    .rept 256
    .if .Lbyte>=0x30 && .Lbyte<=0x39
    .byte .Lbyte-0x30
    .elseif .Lbyte>=0x41 && .Lbyte<=0x46
    .byte .Lbyte-0x41+10
    .elseif .Lbyte>=0x61 && .Lbyte<=0x66
    .byte .Lbyte-0x61+10
    .else
    .byte 255
    .endif
    .set .Lbyte,.Lbyte+1
    .endr
.Lescape_decode:
    .set .Lbyte,0
    .rept 256
    .if .Lbyte==0x22 || .Lbyte==0x2f || .Lbyte==0x5c
    .byte .Lbyte
    .elseif .Lbyte==0x62
    .byte 8
    .elseif .Lbyte==0x66
    .byte 12
    .elseif .Lbyte==0x6e
    .byte 10
    .elseif .Lbyte==0x72
    .byte 13
    .elseif .Lbyte==0x74
    .byte 9
    .else
    .byte 0
    .endif
    .set .Lbyte,.Lbyte+1
    .endr
.Lescape_encode:
    .byte 0,0,0,0,0,0,0,0,'b','t','n',0,'f','r',0,0
    .zero 16
.Lutf8_lengths:
    .set .Lbyte,0
    .rept 256
    .if .Lbyte<128
    .byte 1
    .elseif .Lbyte>=0xc2 && .Lbyte<=0xdf
    .byte 2
    .elseif .Lbyte>=0xe0 && .Lbyte<=0xef
    .byte 3
    .elseif .Lbyte>=0xf0 && .Lbyte<=0xf4
    .byte 4
    .else
    .byte 0
    .endif
    .set .Lbyte,.Lbyte+1
    .endr
.Lutf8_masks:
    .byte 0,0x7f,0x1f,0x0f,0x07
.Lutf8_minimum:
    .long 0,0,0x80,0x800,0x10000
.Lhex_digits:
    .ascii "0123456789abcdef"
.section .note.GNU-stack,"",@progbits
