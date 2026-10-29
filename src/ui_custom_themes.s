# Native Qwen0.24.5 customThemes semantic/legacy color parser.
# Adapted schema/color-name data: theme.ts/color-utils.ts, Apache2 QwenCode.
.include "abi.inc"
.equ CT_MAX,16
.equ CT_RECORD,8192
.equ CT_UI,64
.equ CT_MD,128
.equ CT_MER,336
.equ CT_COLORS,384
.equ CT_STYLES,1152
.equ CT_EXT,1280
.equ CT_SYNTAX,1536
.equ CT_GRAD_COUNT,1760
.equ CT_GRAD_STOPS,1768
.equ CT_GRAD36,1840
.equ CT_GRAD37,2128
.equ CT_GRAD_STRINGS,2432
.section .bss
.ct_count: .skip 8
.ct_records: .skip CT_MAX*CT_RECORD
.ct_temp: .skip CT_RECORD
.ct_src: .skip 8
.ct_tokens: .skip 8192*32
.ct_key: .skip 64
.ct_value: .skip 64
.ct_object: .skip 8
.ct_role: .skip 8
.ct_index: .skip 8
.ct_next: .skip 8
.ct_map: .skip 8
.text
.globl ui_custom_themes_reset,ui_custom_themes_load
.globl ui_custom_theme_catalog,ui_custom_theme_name,ui_custom_theme_find,ui_custom_theme_palette
ui_custom_themes_reset:
 mov qword ptr [rip+.ct_count],0
 xor eax,eax
 ret
# Full settings JSON ->number accepted/replaced, negative malformed/bounds.
# Missing customThemes is an empty merge. Caller resets before layered loading.
ui_custom_themes_load:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov rbx,rdi
 mov r12,rsi
 xor r15d,r15d
 cmp rsi,65536
 ja .CT_invalid
 mov [rip+.ct_src],rdi
 lea rdx,[rip+.ct_tokens]
 mov ecx,8192
 call json_parse
 test rax,rax
 js .CT_invalid
 cmp qword ptr [rip+.ct_tokens],JT_OBJECT
 jne .CT_invalid
 xor edx,edx
 lea rcx,[rip+.ct_custom_key]
 call .CT_find
 test rax,rax
 js .CT_done
 shl rax,5
 lea rdx,[rip+.ct_tokens]
 add rdx,rax
 cmp qword ptr [rdx],JT_OBJECT
 jne .CT_invalid
 mov r13,[rdx+T_END]
 shr rax,5
 lea r14,[rax+1]
.CT_theme:
 cmp r14,r13
 jae .CT_done
 mov rax,r14
 shl rax,5
 lea rdx,[rip+.ct_tokens]
 add rdx,rax
 cmp qword ptr [rdx],JT_STRING
 jne .CT_invalid
 lea rdi,[rip+.ct_temp]
 mov rsi,[rip+.ct_src]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 mov ecx,50
 call json_decode
 test rax,rax
 jle .CT_invalid
 lea rdi,[rip+.ct_temp]
 mov byte ptr [rdi+rax],0
 mov rcx,rax
 call .CT_name_valid
 test eax,eax
 jz .CT_invalid
 inc r14
 mov [rip+.ct_object],r14
 mov rax,r14
 shl rax,5
 lea rdx,[rip+.ct_tokens]
 add rdx,rax
 mov r14,[rdx+T_END]
 cmp qword ptr [rdx],JT_OBJECT
 jne .CT_theme
 # Optional config.name is the display/selection name, per original fallback.
 mov rdx,[rip+.ct_object]
 lea rcx,[rip+.ct_name_key]
 call .CT_find
 test rax,rax
 js .CT_defaults
 lea rdi,[rip+.ct_key]
 call .CT_decode
 test rax,rax
 jle .CT_defaults
 cmp rax,50
 ja .CT_theme
 lea rdi,[rip+.ct_key]
 mov rcx,rax
 call .CT_name_valid
 test eax,eax
 jz .CT_theme
 lea rsi,[rip+.ct_key]
 lea rdi,[rip+.ct_temp]
 call .CT_copyz
.CT_defaults:
 lea rbp,[rip+.ct_temp]
 xor r12d,r12d
.CT_default_color:
 lea rax,[rip+.ct_defaults]
 mov rsi,[rax+r12*8]
 add rsi,rax
 imul rdi,r12,40
 lea rdi,[rbp+rdi+CT_COLORS]
 call .CT_copyz
 inc r12
 cmp r12,18
 jb .CT_default_color
 xor r12d,r12d
.CT_role:
 mov [rip+.ct_role],r12
 cmp r12,15
 jb .CT_role_override
 mov eax,14
 cmp r12,16
 jne .CT_role_fallback
 mov eax,3
.CT_role_fallback:
 imul rsi,rax,40
 lea rsi,[rbp+rsi+CT_COLORS]
 imul rdi,r12,40
 lea rdi,[rbp+rdi+CT_COLORS]
 call .CT_copyz
.CT_role_override:
 imul rax,r12,32
 lea rbx,[rip+.ct_role_keys]
 add rbx,rax
 mov rax,[rbx]
 test rax,rax
 jz .CT_nested
 lea rcx,[rip+.ct_role_keys]
 add rcx,rax
 mov rdx,[rip+.ct_object]
 call .CT_find
 test rax,rax
 js .CT_nested
 call .CT_set_color
.CT_nested:
 mov rax,[rbx+8]
 test rax,rax
 jz .CT_role_next
 lea rcx,[rip+.ct_role_keys]
 add rcx,rax
 mov rdx,[rip+.ct_object]
 call .CT_find
 test rax,rax
 js .CT_role_next
 mov rdx,rax
 mov rax,[rbx+16]
 lea rcx,[rip+.ct_role_keys]
 add rcx,rax
 call .CT_find
 test rax,rax
 js .CT_role_next
 cmp qword ptr [rbx+24],0
 je .CT_nested_value
 mov rdx,rax
 lea rcx,[rip+.ct_role_keys]
 add rcx,[rbx+24]
 call .CT_find
 test rax,rax
 js .CT_role_next
.CT_nested_value:
 call .CT_set_color
.CT_role_next:
 inc r12
 cmp r12,18
 jb .CT_role
 call .CT_build_rows
 lea rdi,[rip+.ct_temp]
 call ui_custom_theme_find
 test rax,rax
 js .CT_new_theme
 sub rax,17
 jmp .CT_store_theme
.CT_new_theme:
 mov rax,[rip+.ct_count]
 cmp rax,CT_MAX
 jae .CT_full
 inc qword ptr [rip+.ct_count]
.CT_store_theme:
 imul rax,rax,CT_RECORD
 lea rdi,[rip+.ct_records]
 add rdi,rax
 mov rbx,rdi
 lea rsi,[rip+.ct_temp]
 mov ecx,CT_RECORD
 rep movsb
 # Relocate absolute palette pointers from scratch into the copied record.
 lea rax,[rip+.ct_temp]
 mov rdx,rbx
 sub rdx,rax
 lea rdi,[rbx+CT_UI]
 mov ecx,7
.CT_reloc_ui:
 add [rdi],rdx
 add rdi,8
 loop .CT_reloc_ui
 lea rdi,[rbx+CT_MD]
 mov ecx,13
.CT_reloc_md:
 add [rdi],rdx
 add rdi,16
 loop .CT_reloc_md
 lea rdi,[rbx+CT_MER]
 mov ecx,3
.CT_reloc_mer:
 add [rdi],rdx
 add rdi,16
 loop .CT_reloc_mer
 lea rdi,[rbx+CT_EXT]
 mov ecx,18
.CT_reloc_ext:
 add [rdi],rdx
 add rdi,8
 loop .CT_reloc_ext
 lea rdi,[rbx+CT_SYNTAX]
 mov ecx,12
.CT_reloc_syntax:
 add [rdi],rdx
 add rdi,16
 loop .CT_reloc_syntax
 lea rdi,[rbx+CT_GRAD36]
 mov ecx,73
.CT_reloc_gradients:
 add [rdi],rdx
 add rdi,8
 loop .CT_reloc_gradients
 inc r15
 jmp .CT_theme
.CT_full:
 mov r15,-28
 jmp .CT_done
.CT_invalid:
 mov r15,-22
.CT_done:
 mov rax,r15
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.CT_find:
 mov rdi,[rip+.ct_src]
 lea rsi,[rip+.ct_tokens]
 jmp json_find
# Token index rax, destination rdi ->decoded NUL string length/-1.
.CT_decode:
 shl rax,5
 lea rdx,[rip+.ct_tokens]
 add rdx,rax
 cmp qword ptr [rdx],JT_STRING
 jne .CT_decode_bad
 mov rsi,[rip+.ct_src]
 add rsi,[rdx+T_START]
 mov rdx,[rdx+T_LEN]
 push rdi
 mov ecx,63
 call json_decode
 pop rdi
 test rax,rax
 js .CT_decode_bad
 mov byte ptr [rdi+rax],0
 ret
.CT_decode_bad:
 mov rax,-1
 ret
.CT_set_color:
 sub rsp,8
 lea rdi,[rip+.ct_value]
 call .CT_decode
 test rax,rax
 js .CT_set_done
 lea rdi,[rip+.ct_value]
 mov rsi,[rip+.ct_role]
 imul rsi,rsi,40
 lea rsi,[rbp+rsi+CT_COLORS]
 call .CT_color
.CT_set_done:
 add rsp,8
 ret
.CT_copyz:
 lodsb
 stosb
 test al,al
 jnz .CT_copyz
 ret
.CT_strlen:
 xor eax,eax
.CT_strlen_loop:
 cmp byte ptr [rdi+rax],0
 je .CT_strlen_done
 inc rax
 jmp .CT_strlen_loop
.CT_strlen_done:
 ret
.CT_name_valid:
 xor eax,eax
 xor edx,edx
.CT_name_char:
 test rcx,rcx
 jz .CT_name_done
 mov al,[rdi]
 cmp al,32
 jb .CT_name_bad
 cmp al,127
 je .CT_name_bad
 cmp al,32
 je .CT_name_space
 mov edx,1
.CT_name_space:
 inc rdi
 dec rcx
 jmp .CT_name_char
.CT_name_done:
 mov eax,edx
 ret
.CT_name_bad:
 xor eax,eax
 ret
ui_custom_theme_name:
 sub rdi,17
 cmp rdi,[rip+.ct_count]
 jae .CT_name_missing
 imul rax,rdi,CT_RECORD
 lea rdx,[rip+.ct_records]
 add rax,rdx
 ret
.CT_name_missing:
 xor eax,eax
 ret
ui_custom_theme_find:
 xor r8d,r8d
 lea r9,[rip+.ct_records]
.CT_find_name:
 cmp r8,[rip+.ct_count]
 jae .CT_find_missing
 xor ecx,ecx
.CT_find_name_char:
 mov al,[rdi+rcx]
 cmp al,[r9+rcx]
 jne .CT_find_name_next
 inc rcx
 test al,al
 jnz .CT_find_name_char
 lea rax,[r8+17]
 ret
.CT_find_name_next:
 inc r8
 add r9,CT_RECORD
 jmp .CT_find_name
.CT_find_missing:
 mov rax,-1
 ret
ui_custom_theme_catalog:
 mov rax,[rip+.ct_count]
 test rsi,rsi
 jz .CT_catalog_done
 test rdi,rdi
 jz .CT_catalog_bad
 cmp rsi,rax
 cmova rsi,rax
 mov rax,rsi
 lea rdx,[rip+.ct_records]
 xor ecx,ecx
.CT_catalog_loop:
 cmp rcx,rax
 jae .CT_catalog_done
 mov [rdi],rdx
 lea r8,[rip+.ct_custom_label]
 mov [rdi+8],r8
 lea r8,[rcx+17]
 mov [rdi+16],r8
 add rdi,24
 add rdx,CT_RECORD
 inc rcx
 jmp .CT_catalog_loop
.CT_catalog_bad:
 mov rax,-22
.CT_catalog_done:
 ret
ui_custom_theme_palette:
 sub rdi,17
 cmp rdi,[rip+.ct_count]
 jae .CT_palette_missing
 imul rax,rdi,CT_RECORD
 lea rdx,[rip+.ct_records]
 add rax,rdx
 cmp rsi,0
 je .CT_palette_ui
 cmp rsi,1
 je .CT_palette_md
 cmp rsi,2
 je .CT_palette_mer
 cmp rsi,3
 je .CT_palette_syntax
 cmp rsi,5
 je .CT_palette_ext
.CT_palette_missing:
 xor eax,eax
 ret
.CT_palette_ui:
 add rax,CT_UI
 ret
.CT_palette_md:
 add rax,CT_MD
 ret
.CT_palette_mer:
 add rax,CT_MER
 ret
.CT_palette_syntax:
 add rax,CT_SYNTAX
 ret
.CT_palette_ext:
 add rax,CT_EXT
 ret
# Build renderer semantic pointers and formatter styled sequences.
.CT_build_rows:
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 lea r12,[rip+.ct_ui_role_map]
 lea r13,[rbp+CT_UI]
 mov r14d,7
.CT_build_ui:
 movzx eax,byte ptr [r12]
 inc r12
 imul rax,rax,40
 lea rax,[rbp+rax+CT_COLORS]
 mov [r13],rax
 add r13,8
 dec r14
 jnz .CT_build_ui
 lea r12,[rip+.ct_md_role_map]
 lea r13,[rbp+CT_MD]
 xor r14d,r14d
.CT_build_md:
 movzx eax,byte ptr [r12+r14]
 imul rax,rax,40
 lea rdi,[rbp+rax+CT_COLORS]
 cmp r14,0
 jne .CT_md_not_heading
 lea rdi,[rbp+CT_STYLES]
 mov dword ptr [rdi],0x6d315b1b
 mov byte ptr [rdi+4],0
 jmp .CT_md_pointer
.CT_md_not_heading:
 cmp r14,3
 jne .CT_md_pointer
 mov rsi,rdi
 lea rdi,[rbp+CT_STYLES+40]
 mov r15,rdi
 call .CT_copyz
 dec rdi
 mov dword ptr [rdi],0x6d345b1b
 mov byte ptr [rdi+4],0
 mov rdi,r15
.CT_md_pointer:
 mov [r13],rdi
 call .CT_strlen
 mov [r13+8],rax
 add r13,16
 inc r14
 cmp r14,13
 jb .CT_build_md
 lea rsi,[rbp+CT_COLORS+4*40]
 lea rdi,[rbp+CT_STYLES+80]
 mov r15,rdi
 call .CT_copyz
 dec rdi
 mov dword ptr [rdi],0x6d315b1b
 mov byte ptr [rdi+4],0
 mov [rbp+CT_MER],r15
 mov rdi,r15
 call .CT_strlen
 mov [rbp+CT_MER+8],rax
 lea rdi,[rbp+CT_COLORS+40]
 mov [rbp+CT_MER+16],rdi
 call .CT_strlen
 mov [rbp+CT_MER+24],rax
 lea rdi,[rbp+CT_COLORS+14*40]
 mov [rbp+CT_MER+32],rdi
 call .CT_strlen
 mov [rbp+CT_MER+40],rax
 xor r12d,r12d
.CT_build_ext:
 imul rax,r12,40
 lea rax,[rbp+rax+CT_COLORS]
 mov [rbp+r12*8+CT_EXT],rax
 inc r12
 cmp r12,18
 jb .CT_build_ext
 lea r12,[rip+.ct_syntax_role_map]
 lea r13,[rbp+CT_SYNTAX]
 xor r14d,r14d
.CT_build_syntax:
 movzx eax,byte ptr [r12+r14]
 imul rax,rax,40
 lea rdi,[rbp+rax+CT_COLORS]
 mov [r13],rdi
 call .CT_strlen
 mov [r13+8],rax
 add r13,16
 inc r14
 cmp r14,12
 jb .CT_build_syntax
 call .CT_build_gradients
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 ret
# colorZ,out40 ->length. Invalid color strings resolve to terminal default,
# matching original resolveColor's undefined fallback; controls never copied.
.CT_color:
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov qword ptr [rip+.ct_rgb_value],-1
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
.CT_color_lower:
 mov al,[r12+r14]
 test al,al
 jz .CT_color_lower_done
 cmp al,'A'
 jb .CT_color_lower_next
 cmp al,'Z'
 ja .CT_color_lower_next
 or al,32
 mov [r12+r14],al
.CT_color_lower_next:
 inc r14
 jmp .CT_color_lower
.CT_color_lower_done:
 test r14,r14
 jz .CT_color_default
 cmp byte ptr [r12],'#'
 je .CT_color_hex
 lea r15,[rip+.ct_color_names]
 xor r8d,r8d
.CT_color_lookup:
 cmp r8,OFFSET FLAT:CT_COLOR_NAMES
 jae .CT_color_default
 mov r10,r8
 shl r10,4
 mov rdi,[r15+r10]
 add rdi,r15
 xor ecx,ecx
.CT_color_compare:
 mov al,[r12+rcx]
 cmp al,[rdi+rcx]
 jne .CT_color_next_name
 inc rcx
 test al,al
 jnz .CT_color_compare
 mov r14,[r15+r10+8]
 test r14d,0x1000000
 jnz .CT_color_ansi
 jmp .CT_color_rgb
.CT_color_next_name:
 inc r8
 jmp .CT_color_lookup
.CT_color_hex:
 cmp r14,4
 je .CT_color_hex_short
 cmp r14,7
 jne .CT_color_default
 mov r15d,6
 jmp .CT_color_hex_start
.CT_color_hex_short:
 mov r15d,3
.CT_color_hex_start:
 xor r14d,r14d
 mov ecx,1
.CT_color_hex_digit:
 movzx eax,byte ptr [r12+rcx]
 sub eax,'0'
 cmp eax,9
 jbe .CT_color_hex_nibble
 sub eax,39
 cmp eax,10
 jb .CT_color_default
 cmp eax,15
 ja .CT_color_default
.CT_color_hex_nibble:
 cmp r15,3
 jne .CT_color_hex_six
 mov edx,eax
 shl eax,4
 or eax,edx
 shl r14d,8
 or r14d,eax
 jmp .CT_color_hex_next
.CT_color_hex_six:
 shl r14d,4
 or r14d,eax
.CT_color_hex_next:
 inc rcx
 cmp rcx,r15
 jbe .CT_color_hex_digit
.CT_color_rgb:
 mov [rip+.ct_rgb_value],r14
 mov rdi,r13
 lea rsi,[rip+.ct_sgr_rgb]
 mov ecx,7
 rep movsb
 mov r12,rdi
 mov rsi,r14
 shr rsi,16
 and esi,255
 call .CT_decimal
 mov byte ptr [rdi],';'
 inc rdi
 mov rsi,r14
 shr rsi,8
 and esi,255
 call .CT_decimal
 mov byte ptr [rdi],';'
 inc rdi
 mov rsi,r14
 and esi,255
 call .CT_decimal
 mov byte ptr [rdi],'m'
 mov byte ptr [rdi+1],0
 lea rax,[rdi+1]
 sub rax,r13
 jmp .CT_color_return
.CT_color_ansi:
 mov eax,r14d
 and eax,255
 cmp eax,90
 jb .CT_ansi_normal
 sub eax,82
 jmp .CT_ansi_index
.CT_ansi_normal:
 sub eax,30
.CT_ansi_index:
 lea rdx,[rip+.ct_ansi_rgb]
 mov eax,[rdx+rax*4]
 mov [rip+.ct_rgb_value],rax
 mov rdi,r13
 mov word ptr [rdi],0x5b1b
 add rdi,2
 mov esi,r14d
 and esi,255
 call .CT_decimal
 mov byte ptr [rdi],'m'
 mov byte ptr [rdi+1],0
 lea rax,[rdi+1]
 sub rax,r13
 jmp .CT_color_return
.CT_color_default:
 mov dword ptr [r13],0x39335b1b
 mov word ptr [r13+4],0x006d
 mov eax,5
.CT_color_return:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 ret
# destination,value0..255 ->destination advanced, no external helper.
.CT_decimal:
 mov rax,rsi
 xor ecx,ecx
 mov r9d,10
.CT_dec_digits:
 xor edx,edx
 div r9
 add dl,'0'
 mov [rsp-8+rcx],dl
 inc rcx
 test rax,rax
 jnz .CT_dec_digits
.CT_dec_copy:
 dec rcx
 mov al,[rsp-8+rcx]
 stosb
 test rcx,rcx
 jnz .CT_dec_copy
 ret
.section .rodata
.ct_custom_key: .asciz "customThemes"
.ct_name_key: .asciz "name"
.ct_custom_label: .asciz "Custom"
.ct_sgr_rgb: .ascii "\033[38;2;"
.ct_ui_role_map: .byte 1,14,4,6,8,7,16
.ct_syntax_role_map: .byte 1,5,5,2,14,3,14,8,3,4,4,1
.ct_md_role_map: .byte 1,14,2,3,3,7,6,1,4,1,14,13,3
.balign 8
.ct_defaults:
 .quad .ct_default_0-.ct_defaults
 .quad .ct_default_1-.ct_defaults
 .quad .ct_default_2-.ct_defaults
 .quad .ct_default_3-.ct_defaults
 .quad .ct_default_4-.ct_defaults
 .quad .ct_default_5-.ct_defaults
 .quad .ct_default_6-.ct_defaults
 .quad .ct_default_7-.ct_defaults
 .quad .ct_default_8-.ct_defaults
 .quad .ct_default_9-.ct_defaults
 .quad .ct_default_10-.ct_defaults
 .quad .ct_default_11-.ct_defaults
 .quad .ct_default_12-.ct_defaults
 .quad .ct_default_13-.ct_defaults
 .quad .ct_default_14-.ct_defaults
 .quad .ct_default_15-.ct_defaults
 .quad .ct_default_16-.ct_defaults
 .quad .ct_default_17-.ct_defaults
.ct_default_0: .byte 27,91,51,56,59,50,59,49,49,59,49,52,59,50,48,109,0
.ct_default_1: .byte 27,91,51,56,59,50,59,49,57,49,59,49,56,57,59,49,56,50,109,0
.ct_default_2: .byte 27,91,51,56,59,50,59,56,57,59,49,57,52,59,50,53,53,109,0
.ct_default_3: .byte 27,91,51,56,59,50,59,53,55,59,49,56,54,59,50,51,48,109,0
.ct_default_4: .byte 27,91,51,56,59,50,59,50,49,48,59,49,54,54,59,50,53,53,109,0
.ct_default_5: .byte 27,91,51,56,59,50,59,49,52,57,59,50,51,48,59,50,48,51,109,0
.ct_default_6: .byte 27,91,51,56,59,50,59,49,55,48,59,50,49,55,59,55,54,109,0
.ct_default_7: .byte 27,91,51,56,59,50,59,50,53,53,59,50,49,53,59,48,109,0
.ct_default_8: .byte 27,91,51,56,59,50,59,50,52,50,59,49,48,57,59,49,50,48,109,0
.ct_default_9: .byte 27,91,51,56,59,50,59,49,51,57,59,49,49,55,59,52,56,109,0
.ct_default_10: .byte 27,91,51,56,59,50,59,49,51,57,59,53,56,59,55,52,109,0
.ct_default_11: .byte 27,91,51,56,59,50,59,49,55,48,59,50,49,55,59,55,54,109,0
.ct_default_12: .byte 27,91,51,56,59,50,59,50,52,50,59,49,48,57,59,49,50,48,109,0
.ct_default_13: .byte 27,91,51,56,59,50,59,49,48,48,59,49,48,54,59,49,49,51,109,0
.ct_default_14: .byte 27,91,51,56,59,50,59,54,49,59,54,53,59,55,51,109,0
.ct_default_15: .byte 27,91,51,56,59,50,59,54,49,59,54,53,59,55,51,109,0
.ct_default_16: .byte 27,91,51,56,59,50,59,53,55,59,49,56,54,59,50,51,48,109,0
.ct_default_17: .byte 27,91,51,56,59,50,59,54,49,59,54,53,59,55,51,109,0
.balign 8
.ct_role_keys:
 .quad .ct_schema_8-.ct_role_keys,.ct_schema_17-.ct_role_keys,.ct_schema_27-.ct_role_keys,0
 .quad .ct_schema_12-.ct_role_keys,.ct_schema_33-.ct_role_keys,.ct_schema_27-.ct_role_keys,0
 .quad .ct_schema_14-.ct_role_keys,.ct_schema_33-.ct_role_keys,.ct_schema_19-.ct_role_keys,0
 .quad .ct_schema_0-.ct_role_keys,.ct_schema_33-.ct_role_keys,.ct_schema_26-.ct_role_keys,0
 .quad .ct_schema_3-.ct_role_keys,.ct_schema_33-.ct_role_keys,.ct_schema_15-.ct_role_keys,0
 .quad .ct_schema_1-.ct_role_keys,.ct_schema_33-.ct_role_keys,.ct_schema_26-.ct_role_keys,0
 .quad .ct_schema_2-.ct_role_keys,.ct_schema_30-.ct_role_keys,.ct_schema_31-.ct_role_keys,0
 .quad .ct_schema_6-.ct_role_keys,.ct_schema_30-.ct_role_keys,.ct_schema_35-.ct_role_keys,0
 .quad .ct_schema_4-.ct_role_keys,.ct_schema_30-.ct_role_keys,.ct_schema_23-.ct_role_keys,0
 .quad .ct_schema_7-.ct_role_keys,.ct_schema_30-.ct_role_keys,.ct_schema_36-.ct_role_keys,0
 .quad .ct_schema_5-.ct_role_keys,.ct_schema_30-.ct_role_keys,.ct_schema_24-.ct_role_keys,0
 .quad .ct_schema_10-.ct_role_keys,.ct_schema_17-.ct_role_keys,.ct_schema_22-.ct_role_keys,.ct_schema_16-.ct_role_keys
 .quad .ct_schema_11-.ct_role_keys,.ct_schema_17-.ct_role_keys,.ct_schema_22-.ct_role_keys,.ct_schema_28-.ct_role_keys
 .quad .ct_schema_9-.ct_role_keys,.ct_schema_34-.ct_role_keys,.ct_schema_20-.ct_role_keys,0
 .quad .ct_schema_13-.ct_role_keys,.ct_schema_33-.ct_role_keys,.ct_schema_29-.ct_role_keys,0
 .quad 0,.ct_schema_18-.ct_role_keys,.ct_schema_21-.ct_role_keys,0
 .quad 0,.ct_schema_18-.ct_role_keys,.ct_schema_25-.ct_role_keys,0
 .quad 0,.ct_schema_34-.ct_role_keys,.ct_schema_32-.ct_role_keys,0
.ct_schema_0: .asciz "AccentBlue"
.ct_schema_1: .asciz "AccentCyan"
.ct_schema_2: .asciz "AccentGreen"
.ct_schema_3: .asciz "AccentPurple"
.ct_schema_4: .asciz "AccentRed"
.ct_schema_5: .asciz "AccentRedDim"
.ct_schema_6: .asciz "AccentYellow"
.ct_schema_7: .asciz "AccentYellowDim"
.ct_schema_8: .asciz "Background"
.ct_schema_9: .asciz "Comment"
.ct_schema_10: .asciz "DiffAdded"
.ct_schema_11: .asciz "DiffRemoved"
.ct_schema_12: .asciz "Foreground"
.ct_schema_13: .asciz "Gray"
.ct_schema_14: .asciz "LightBlue"
.ct_schema_15: .asciz "accent"
.ct_schema_16: .asciz "added"
.ct_schema_17: .asciz "background"
.ct_schema_18: .asciz "border"
.ct_schema_19: .asciz "code"
.ct_schema_20: .asciz "comment"
.ct_schema_21: .asciz "default"
.ct_schema_22: .asciz "diff"
.ct_schema_23: .asciz "error"
.ct_schema_24: .asciz "errorDim"
.ct_schema_25: .asciz "focused"
.ct_schema_26: .asciz "link"
.ct_schema_27: .asciz "primary"
.ct_schema_28: .asciz "removed"
.ct_schema_29: .asciz "secondary"
.ct_schema_30: .asciz "status"
.ct_schema_31: .asciz "success"
.ct_schema_32: .asciz "symbol"
.ct_schema_33: .asciz "text"
.ct_schema_34: .asciz "ui"
.ct_schema_35: .asciz "warning"
.ct_schema_36: .asciz "warningDim"
.balign 8
.ct_color_names:
 .quad .ct_color_name_0-.ct_color_names,15792383
 .quad .ct_color_name_1-.ct_color_names,16444375
 .quad .ct_color_name_2-.ct_color_names,65535
 .quad .ct_color_name_3-.ct_color_names,8388564
 .quad .ct_color_name_4-.ct_color_names,15794175
 .quad .ct_color_name_5-.ct_color_names,16119260
 .quad .ct_color_name_6-.ct_color_names,16770244
 .quad .ct_color_name_7-.ct_color_names,16772045
 .quad .ct_color_name_8-.ct_color_names,9055202
 .quad .ct_color_name_9-.ct_color_names,10824234
 .quad .ct_color_name_10-.ct_color_names,14596231
 .quad .ct_color_name_11-.ct_color_names,6266528
 .quad .ct_color_name_12-.ct_color_names,8388352
 .quad .ct_color_name_13-.ct_color_names,13789470
 .quad .ct_color_name_14-.ct_color_names,16744272
 .quad .ct_color_name_15-.ct_color_names,6591981
 .quad .ct_color_name_16-.ct_color_names,16775388
 .quad .ct_color_name_17-.ct_color_names,14423100
 .quad .ct_color_name_18-.ct_color_names,139
 .quad .ct_color_name_19-.ct_color_names,35723
 .quad .ct_color_name_20-.ct_color_names,12092939
 .quad .ct_color_name_21-.ct_color_names,11119017
 .quad .ct_color_name_22-.ct_color_names,11119017
 .quad .ct_color_name_23-.ct_color_names,25600
 .quad .ct_color_name_24-.ct_color_names,12433259
 .quad .ct_color_name_25-.ct_color_names,9109643
 .quad .ct_color_name_26-.ct_color_names,5597999
 .quad .ct_color_name_27-.ct_color_names,16747520
 .quad .ct_color_name_28-.ct_color_names,10040012
 .quad .ct_color_name_29-.ct_color_names,9109504
 .quad .ct_color_name_30-.ct_color_names,15308410
 .quad .ct_color_name_31-.ct_color_names,9419919
 .quad .ct_color_name_32-.ct_color_names,4734347
 .quad .ct_color_name_33-.ct_color_names,3100495
 .quad .ct_color_name_34-.ct_color_names,3100495
 .quad .ct_color_name_35-.ct_color_names,52945
 .quad .ct_color_name_36-.ct_color_names,9699539
 .quad .ct_color_name_37-.ct_color_names,16716947
 .quad .ct_color_name_38-.ct_color_names,49151
 .quad .ct_color_name_39-.ct_color_names,6908265
 .quad .ct_color_name_40-.ct_color_names,6908265
 .quad .ct_color_name_41-.ct_color_names,2003199
 .quad .ct_color_name_42-.ct_color_names,11674146
 .quad .ct_color_name_43-.ct_color_names,16775920
 .quad .ct_color_name_44-.ct_color_names,2263842
 .quad .ct_color_name_45-.ct_color_names,16711935
 .quad .ct_color_name_46-.ct_color_names,14474460
 .quad .ct_color_name_47-.ct_color_names,16316671
 .quad .ct_color_name_48-.ct_color_names,16766720
 .quad .ct_color_name_49-.ct_color_names,14329120
 .quad .ct_color_name_50-.ct_color_names,11403055
 .quad .ct_color_name_51-.ct_color_names,15794160
 .quad .ct_color_name_52-.ct_color_names,16738740
 .quad .ct_color_name_53-.ct_color_names,13458524
 .quad .ct_color_name_54-.ct_color_names,4915330
 .quad .ct_color_name_55-.ct_color_names,16777200
 .quad .ct_color_name_56-.ct_color_names,15787660
 .quad .ct_color_name_57-.ct_color_names,15132410
 .quad .ct_color_name_58-.ct_color_names,16773365
 .quad .ct_color_name_59-.ct_color_names,8190976
 .quad .ct_color_name_60-.ct_color_names,16775885
 .quad .ct_color_name_61-.ct_color_names,11393254
 .quad .ct_color_name_62-.ct_color_names,15761536
 .quad .ct_color_name_63-.ct_color_names,14745599
 .quad .ct_color_name_64-.ct_color_names,16448210
 .quad .ct_color_name_65-.ct_color_names,13882323
 .quad .ct_color_name_66-.ct_color_names,13882323
 .quad .ct_color_name_67-.ct_color_names,9498256
 .quad .ct_color_name_68-.ct_color_names,16758465
 .quad .ct_color_name_69-.ct_color_names,16752762
 .quad .ct_color_name_70-.ct_color_names,2142890
 .quad .ct_color_name_71-.ct_color_names,8900346
 .quad .ct_color_name_72-.ct_color_names,7833753
 .quad .ct_color_name_73-.ct_color_names,7833753
 .quad .ct_color_name_74-.ct_color_names,11584734
 .quad .ct_color_name_75-.ct_color_names,16777184
 .quad .ct_color_name_76-.ct_color_names,65280
 .quad .ct_color_name_77-.ct_color_names,3329330
 .quad .ct_color_name_78-.ct_color_names,16445670
 .quad .ct_color_name_79-.ct_color_names,8388608
 .quad .ct_color_name_80-.ct_color_names,6737322
 .quad .ct_color_name_81-.ct_color_names,205
 .quad .ct_color_name_82-.ct_color_names,12211667
 .quad .ct_color_name_83-.ct_color_names,9662683
 .quad .ct_color_name_84-.ct_color_names,3978097
 .quad .ct_color_name_85-.ct_color_names,8087790
 .quad .ct_color_name_86-.ct_color_names,64154
 .quad .ct_color_name_87-.ct_color_names,4772300
 .quad .ct_color_name_88-.ct_color_names,13047173
 .quad .ct_color_name_89-.ct_color_names,1644912
 .quad .ct_color_name_90-.ct_color_names,16121850
 .quad .ct_color_name_91-.ct_color_names,16770273
 .quad .ct_color_name_92-.ct_color_names,16770229
 .quad .ct_color_name_93-.ct_color_names,16768685
 .quad .ct_color_name_94-.ct_color_names,128
 .quad .ct_color_name_95-.ct_color_names,16643558
 .quad .ct_color_name_96-.ct_color_names,8421376
 .quad .ct_color_name_97-.ct_color_names,7048739
 .quad .ct_color_name_98-.ct_color_names,16753920
 .quad .ct_color_name_99-.ct_color_names,16729344
 .quad .ct_color_name_100-.ct_color_names,14315734
 .quad .ct_color_name_101-.ct_color_names,15657130
 .quad .ct_color_name_102-.ct_color_names,10025880
 .quad .ct_color_name_103-.ct_color_names,11529966
 .quad .ct_color_name_104-.ct_color_names,14381203
 .quad .ct_color_name_105-.ct_color_names,16773077
 .quad .ct_color_name_106-.ct_color_names,16767673
 .quad .ct_color_name_107-.ct_color_names,13468991
 .quad .ct_color_name_108-.ct_color_names,16761035
 .quad .ct_color_name_109-.ct_color_names,14524637
 .quad .ct_color_name_110-.ct_color_names,11591910
 .quad .ct_color_name_111-.ct_color_names,8388736
 .quad .ct_color_name_112-.ct_color_names,6697881
 .quad .ct_color_name_113-.ct_color_names,12357519
 .quad .ct_color_name_114-.ct_color_names,4286945
 .quad .ct_color_name_115-.ct_color_names,9127187
 .quad .ct_color_name_116-.ct_color_names,16416882
 .quad .ct_color_name_117-.ct_color_names,16032864
 .quad .ct_color_name_118-.ct_color_names,3050327
 .quad .ct_color_name_119-.ct_color_names,16774638
 .quad .ct_color_name_120-.ct_color_names,10506797
 .quad .ct_color_name_121-.ct_color_names,12632256
 .quad .ct_color_name_122-.ct_color_names,8900331
 .quad .ct_color_name_123-.ct_color_names,6970061
 .quad .ct_color_name_124-.ct_color_names,7372944
 .quad .ct_color_name_125-.ct_color_names,7372944
 .quad .ct_color_name_126-.ct_color_names,16775930
 .quad .ct_color_name_127-.ct_color_names,65407
 .quad .ct_color_name_128-.ct_color_names,4620980
 .quad .ct_color_name_129-.ct_color_names,13808780
 .quad .ct_color_name_130-.ct_color_names,32896
 .quad .ct_color_name_131-.ct_color_names,14204888
 .quad .ct_color_name_132-.ct_color_names,16737095
 .quad .ct_color_name_133-.ct_color_names,4251856
 .quad .ct_color_name_134-.ct_color_names,15631086
 .quad .ct_color_name_135-.ct_color_names,16113331
 .quad .ct_color_name_136-.ct_color_names,16119285
 .quad .ct_color_name_137-.ct_color_names,10145074
 .quad .ct_color_name_138-.ct_color_names,16777246
 .quad .ct_color_name_139-.ct_color_names,16777247
 .quad .ct_color_name_140-.ct_color_names,16777248
 .quad .ct_color_name_141-.ct_color_names,16777249
 .quad .ct_color_name_142-.ct_color_names,16777250
 .quad .ct_color_name_143-.ct_color_names,16777251
 .quad .ct_color_name_144-.ct_color_names,16777252
 .quad .ct_color_name_145-.ct_color_names,16777253
 .quad .ct_color_name_146-.ct_color_names,16777306
 .quad .ct_color_name_147-.ct_color_names,16777306
 .quad .ct_color_name_148-.ct_color_names,16777306
 .quad .ct_color_name_149-.ct_color_names,16777307
 .quad .ct_color_name_150-.ct_color_names,16777308
 .quad .ct_color_name_151-.ct_color_names,16777309
 .quad .ct_color_name_152-.ct_color_names,16777310
 .quad .ct_color_name_153-.ct_color_names,16777311
 .quad .ct_color_name_154-.ct_color_names,16777312
 .quad .ct_color_name_155-.ct_color_names,16777313
.equ CT_COLOR_NAMES,156
.ct_color_name_0: .asciz "aliceblue"
.ct_color_name_1: .asciz "antiquewhite"
.ct_color_name_2: .asciz "aqua"
.ct_color_name_3: .asciz "aquamarine"
.ct_color_name_4: .asciz "azure"
.ct_color_name_5: .asciz "beige"
.ct_color_name_6: .asciz "bisque"
.ct_color_name_7: .asciz "blanchedalmond"
.ct_color_name_8: .asciz "blueviolet"
.ct_color_name_9: .asciz "brown"
.ct_color_name_10: .asciz "burlywood"
.ct_color_name_11: .asciz "cadetblue"
.ct_color_name_12: .asciz "chartreuse"
.ct_color_name_13: .asciz "chocolate"
.ct_color_name_14: .asciz "coral"
.ct_color_name_15: .asciz "cornflowerblue"
.ct_color_name_16: .asciz "cornsilk"
.ct_color_name_17: .asciz "crimson"
.ct_color_name_18: .asciz "darkblue"
.ct_color_name_19: .asciz "darkcyan"
.ct_color_name_20: .asciz "darkgoldenrod"
.ct_color_name_21: .asciz "darkgray"
.ct_color_name_22: .asciz "darkgrey"
.ct_color_name_23: .asciz "darkgreen"
.ct_color_name_24: .asciz "darkkhaki"
.ct_color_name_25: .asciz "darkmagenta"
.ct_color_name_26: .asciz "darkolivegreen"
.ct_color_name_27: .asciz "darkorange"
.ct_color_name_28: .asciz "darkorchid"
.ct_color_name_29: .asciz "darkred"
.ct_color_name_30: .asciz "darksalmon"
.ct_color_name_31: .asciz "darkseagreen"
.ct_color_name_32: .asciz "darkslateblue"
.ct_color_name_33: .asciz "darkslategray"
.ct_color_name_34: .asciz "darkslategrey"
.ct_color_name_35: .asciz "darkturquoise"
.ct_color_name_36: .asciz "darkviolet"
.ct_color_name_37: .asciz "deeppink"
.ct_color_name_38: .asciz "deepskyblue"
.ct_color_name_39: .asciz "dimgray"
.ct_color_name_40: .asciz "dimgrey"
.ct_color_name_41: .asciz "dodgerblue"
.ct_color_name_42: .asciz "firebrick"
.ct_color_name_43: .asciz "floralwhite"
.ct_color_name_44: .asciz "forestgreen"
.ct_color_name_45: .asciz "fuchsia"
.ct_color_name_46: .asciz "gainsboro"
.ct_color_name_47: .asciz "ghostwhite"
.ct_color_name_48: .asciz "gold"
.ct_color_name_49: .asciz "goldenrod"
.ct_color_name_50: .asciz "greenyellow"
.ct_color_name_51: .asciz "honeydew"
.ct_color_name_52: .asciz "hotpink"
.ct_color_name_53: .asciz "indianred"
.ct_color_name_54: .asciz "indigo"
.ct_color_name_55: .asciz "ivory"
.ct_color_name_56: .asciz "khaki"
.ct_color_name_57: .asciz "lavender"
.ct_color_name_58: .asciz "lavenderblush"
.ct_color_name_59: .asciz "lawngreen"
.ct_color_name_60: .asciz "lemonchiffon"
.ct_color_name_61: .asciz "lightblue"
.ct_color_name_62: .asciz "lightcoral"
.ct_color_name_63: .asciz "lightcyan"
.ct_color_name_64: .asciz "lightgoldenrodyellow"
.ct_color_name_65: .asciz "lightgray"
.ct_color_name_66: .asciz "lightgrey"
.ct_color_name_67: .asciz "lightgreen"
.ct_color_name_68: .asciz "lightpink"
.ct_color_name_69: .asciz "lightsalmon"
.ct_color_name_70: .asciz "lightseagreen"
.ct_color_name_71: .asciz "lightskyblue"
.ct_color_name_72: .asciz "lightslategray"
.ct_color_name_73: .asciz "lightslategrey"
.ct_color_name_74: .asciz "lightsteelblue"
.ct_color_name_75: .asciz "lightyellow"
.ct_color_name_76: .asciz "lime"
.ct_color_name_77: .asciz "limegreen"
.ct_color_name_78: .asciz "linen"
.ct_color_name_79: .asciz "maroon"
.ct_color_name_80: .asciz "mediumaquamarine"
.ct_color_name_81: .asciz "mediumblue"
.ct_color_name_82: .asciz "mediumorchid"
.ct_color_name_83: .asciz "mediumpurple"
.ct_color_name_84: .asciz "mediumseagreen"
.ct_color_name_85: .asciz "mediumslateblue"
.ct_color_name_86: .asciz "mediumspringgreen"
.ct_color_name_87: .asciz "mediumturquoise"
.ct_color_name_88: .asciz "mediumvioletred"
.ct_color_name_89: .asciz "midnightblue"
.ct_color_name_90: .asciz "mintcream"
.ct_color_name_91: .asciz "mistyrose"
.ct_color_name_92: .asciz "moccasin"
.ct_color_name_93: .asciz "navajowhite"
.ct_color_name_94: .asciz "navy"
.ct_color_name_95: .asciz "oldlace"
.ct_color_name_96: .asciz "olive"
.ct_color_name_97: .asciz "olivedrab"
.ct_color_name_98: .asciz "orange"
.ct_color_name_99: .asciz "orangered"
.ct_color_name_100: .asciz "orchid"
.ct_color_name_101: .asciz "palegoldenrod"
.ct_color_name_102: .asciz "palegreen"
.ct_color_name_103: .asciz "paleturquoise"
.ct_color_name_104: .asciz "palevioletred"
.ct_color_name_105: .asciz "papayawhip"
.ct_color_name_106: .asciz "peachpuff"
.ct_color_name_107: .asciz "peru"
.ct_color_name_108: .asciz "pink"
.ct_color_name_109: .asciz "plum"
.ct_color_name_110: .asciz "powderblue"
.ct_color_name_111: .asciz "purple"
.ct_color_name_112: .asciz "rebeccapurple"
.ct_color_name_113: .asciz "rosybrown"
.ct_color_name_114: .asciz "royalblue"
.ct_color_name_115: .asciz "saddlebrown"
.ct_color_name_116: .asciz "salmon"
.ct_color_name_117: .asciz "sandybrown"
.ct_color_name_118: .asciz "seagreen"
.ct_color_name_119: .asciz "seashell"
.ct_color_name_120: .asciz "sienna"
.ct_color_name_121: .asciz "silver"
.ct_color_name_122: .asciz "skyblue"
.ct_color_name_123: .asciz "slateblue"
.ct_color_name_124: .asciz "slategray"
.ct_color_name_125: .asciz "slategrey"
.ct_color_name_126: .asciz "snow"
.ct_color_name_127: .asciz "springgreen"
.ct_color_name_128: .asciz "steelblue"
.ct_color_name_129: .asciz "tan"
.ct_color_name_130: .asciz "teal"
.ct_color_name_131: .asciz "thistle"
.ct_color_name_132: .asciz "tomato"
.ct_color_name_133: .asciz "turquoise"
.ct_color_name_134: .asciz "violet"
.ct_color_name_135: .asciz "wheat"
.ct_color_name_136: .asciz "whitesmoke"
.ct_color_name_137: .asciz "yellowgreen"
.ct_color_name_138: .asciz "black"
.ct_color_name_139: .asciz "red"
.ct_color_name_140: .asciz "green"
.ct_color_name_141: .asciz "yellow"
.ct_color_name_142: .asciz "blue"
.ct_color_name_143: .asciz "magenta"
.ct_color_name_144: .asciz "cyan"
.ct_color_name_145: .asciz "white"
.ct_color_name_146: .asciz "gray"
.ct_color_name_147: .asciz "grey"
.ct_color_name_148: .asciz "blackbright"
.ct_color_name_149: .asciz "redbright"
.ct_color_name_150: .asciz "greenbright"
.ct_color_name_151: .asciz "yellowbright"
.ct_color_name_152: .asciz "bluebright"
.ct_color_name_153: .asciz "magentabright"
.ct_color_name_154: .asciz "cyanbright"
.ct_color_name_155: .asciz "whitebright"
.section .note.GNU-stack,"",@progbits
.section .bss
.ct_rgb_value: .skip 8
.ct_gradient_sgr: .skip 40
.ct_grad_token: .skip 8
.ct_grad_width: .skip 8
.ct_grad_x: .skip 8
.ct_grad_start: .skip 8
.ct_grad_end: .skip 8
.ct_grad_span: .skip 8
.ct_grad_pos: .skip 8
.ct_grad_low: .skip 8
.ct_grad_high: .skip 8
.text
.globl ui_custom_theme_gradient
# id,visibleLogoCells36or37 ->array of absolute trustedSGRz pointers/NULL.
ui_custom_theme_gradient:
 sub rdi,17
 cmp rdi,[rip+.ct_count]
 jae .CT_gradient_missing
 imul rax,rdi,CT_RECORD
 lea rdx,[rip+.ct_records]
 add rax,rdx
 cmp rsi,36
 je .CT_gradient36
 cmp rsi,37
 jne .CT_gradient_missing
 add rax,CT_GRAD37
 ret
.CT_gradient36:
 add rax,CT_GRAD36
 ret
.CT_gradient_missing:
 xor eax,eax
 ret
.CT_gradient_defaults:
 mov qword ptr [rbp+CT_GRAD_COUNT],3
 mov dword ptr [rbp+CT_GRAD_STOPS],0x4796e4
 mov dword ptr [rbp+CT_GRAD_STOPS+4],0x847ace
 mov dword ptr [rbp+CT_GRAD_STOPS+8],0xc3677f
 ret
.CT_build_gradients:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,16
 call .CT_gradient_defaults
 mov qword ptr [rip+.ct_grad_token],-1
 mov rdx,[rip+.ct_object]
 lea rcx,[rip+.ct_gradient_legacy_key]
 call .CT_find
 mov [rip+.ct_grad_token],rax
 mov rdx,[rip+.ct_object]
 lea rcx,[rip+.ct_gradient_ui_key]
 call .CT_find
 test rax,rax
 js .CT_gradient_array
 mov rdx,rax
 lea rcx,[rip+.ct_gradient_key]
 call .CT_find
 test rax,rax
 js .CT_gradient_array
 mov [rip+.ct_grad_token],rax
.CT_gradient_array:
 mov rax,[rip+.ct_grad_token]
 test rax,rax
 js .CT_gradient_render
 shl rax,5
 lea rdx,[rip+.ct_tokens]
 add rdx,rax
 cmp qword ptr [rdx],JT_ARRAY
 jne .CT_gradient_render
 mov r13,[rdx+T_END]
 shr rax,5
 lea r12,[rax+1]
 xor r14d,r14d
.CT_gradient_parse_stop:
 cmp r12,r13
 jae .CT_gradient_parsed
 cmp r14,16
 jae .CT_gradient_reset
 mov rax,r12
 shl rax,5
 lea rdx,[rip+.ct_tokens]
 add rdx,rax
 mov r15,[rdx+T_END]
 mov rax,r12
 lea rdi,[rip+.ct_value]
 call .CT_decode
 test rax,rax
 jle .CT_gradient_reset
 lea rdi,[rip+.ct_value]
 lea rsi,[rip+.ct_gradient_sgr]
 call .CT_color
 mov rax,[rip+.ct_rgb_value]
 test rax,rax
 js .CT_gradient_reset
 mov [rbp+r14*4+CT_GRAD_STOPS],eax
 inc r14
 mov r12,r15
 jmp .CT_gradient_parse_stop
.CT_gradient_parsed:
 test r14,r14
 jz .CT_gradient_reset
 cmp r14,1
 jne .CT_gradient_count
 mov eax,[rbp+CT_GRAD_STOPS]
 mov [rbp+CT_GRAD_STOPS+4],eax
 mov r14d,2
.CT_gradient_count:
 mov [rbp+CT_GRAD_COUNT],r14
 jmp .CT_gradient_render
.CT_gradient_reset:
 call .CT_gradient_defaults
.CT_gradient_render:
 mov r15d,36
 lea r14,[rbp+CT_GRAD36]
 lea r13,[rbp+CT_GRAD_STRINGS]
.CT_gradient_width:
 mov [rip+.ct_grad_width],r15
 xor r12d,r12d
.CT_gradient_cell:
 mov [rip+.ct_grad_x],r12
 xor ebx,ebx
.CT_gradient_segment:
 lea rax,[r15-1]
 lea rcx,[rbx+1]
 imul rax,rcx
 mov rcx,[rbp+CT_GRAD_COUNT]
 dec rcx
 xor edx,edx
 div rcx
 cmp r12,rax
 jbe .CT_gradient_segment_ready
 inc rbx
 jmp .CT_gradient_segment
.CT_gradient_segment_ready:
 mov [rip+.ct_grad_end],rax
 lea rax,[r15-1]
 imul rax,rbx
 mov rcx,[rbp+CT_GRAD_COUNT]
 dec rcx
 xor edx,edx
 div rcx
 mov [rip+.ct_grad_start],rax
 mov rcx,[rip+.ct_grad_end]
 sub rcx,rax
 mov [rip+.ct_grad_span],rcx
 mov rcx,r12
 sub rcx,rax
 mov [rip+.ct_grad_pos],rcx
 mov eax,[rbp+rbx*4+CT_GRAD_STOPS]
 mov [rip+.ct_grad_low],rax
 mov eax,[rbp+rbx*4+CT_GRAD_STOPS+4]
 mov [rip+.ct_grad_high],rax
 mov rdi,[rip+.ct_grad_low]
 shr edi,16
 mov rsi,[rip+.ct_grad_high]
 shr esi,16
 call .CT_gradient_component
 shl eax,16
 mov [rsp],rax
 mov rdi,[rip+.ct_grad_low]
 shr edi,8
 and edi,255
 mov rsi,[rip+.ct_grad_high]
 shr esi,8
 and esi,255
 call .CT_gradient_component
 shl eax,8
 or [rsp],rax
 mov rdi,[rip+.ct_grad_low]
 and edi,255
 mov rsi,[rip+.ct_grad_high]
 and esi,255
 call .CT_gradient_component
 or rax,[rsp]
 lea rdi,[rip+.ct_value]
 mov byte ptr [rdi],'#'
 mov ecx,6
 lea r8,[rip+.ct_hex]
.CT_gradient_hex:
 mov rdx,rax
 and edx,15
 mov dl,[r8+rdx]
 mov [rdi+rcx],dl
 shr rax,4
 dec ecx
 jnz .CT_gradient_hex
 mov byte ptr [rdi+7],0
 mov rsi,r13
 call .CT_color
 mov [r14],r13
 add r14,8
 add r13,24
 inc r12
 cmp r12,r15
 jb .CT_gradient_cell
 cmp r15,37
 je .CT_gradient_done
 mov r15d,37
 lea r14,[rbp+CT_GRAD37]
 jmp .CT_gradient_width
.CT_gradient_done:
 add rsp,16
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.CT_gradient_component:
 mov rcx,[rip+.ct_grad_span]
 mov r8,[rip+.ct_grad_pos]
 mov rax,rcx
 sub rax,r8
 imul rax,rdi
 imul rsi,r8
 add rax,rsi
 mov rdx,rcx
 shr rdx,1
 add rax,rdx
 xor edx,edx
 div rcx
 ret
.section .rodata
.ct_gradient_legacy_key: .asciz "GradientColors"
.ct_gradient_ui_key: .asciz "ui"
.ct_gradient_key: .asciz "gradient"
.ct_hex: .ascii "0123456789abcdef"
.ct_ansi_rgb: .long 0,0xff0000,0x00ff00,0xffff00,0x0000ff,0xff00ff,0x00ffff,0xffffff,0x808080,0xff8080,0x80ff80,0xffff80,0x8080ff,0xff80ff,0x80ffff,0xffffff
.section .note.GNU-stack,"",@progbits
