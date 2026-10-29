# Native terminal Markdown. Parser state is private per call; only generated SGR
# may reach output. This is a bounded visual subset, not a CommonMark engine.
.intel_syntax noprefix
.equ MD_MAX,1048576
.equ C_OUT,0
.equ C_CAP,8
.equ C_LEN,16
.equ C_ERR,24
.equ C_SRC,32
.equ C_SIZE,40
.equ C_COLS,48
.equ C_LINE,56
.equ C_LLEN,64
.equ C_OFFSET,72
.equ C_COL,80
.equ C_FENCE,88
.equ C_FCOUNT,96
.equ C_CODELINE,104
.equ C_STYLE,112
.equ C_NEWLINE,120
.equ C_START,128
.equ C_END,136
.equ C_ROWS,144
.equ C_NCOLS,152
.equ C_TABLE_END,160
.equ C_CELL_MAX,168
.equ C_CELL_START,176
.equ C_CELL_END,184
.equ C_ROW_INDEX,192
.equ C_CELL_INDEX,200
.equ C_NUMBER,224
.equ C_THEME,272
.equ C_CODEPAD,280
.equ C_MATH,288
.equ C_MEASURE,296
.equ C_BODY_START,304
.equ C_TABLE_CURSOR,312
.equ C_TVERT,320
.equ C_BASE_STYLE,328
.equ C_WORD,336
.equ C_LINE_CONT,344
.equ C_INDENT,352
.equ C_IMAGE,360
.equ C_MATH_INDEX,368
.equ C_MATH_BUDGET,376
.equ C_TABLE_HEADER,384
.equ C_TABLE_ROW_INDEX,392
.equ C_MERMAID_INDEX,400
.equ C_FENCE_END,408
.equ C_FENCE_NEXT,416
.equ C_SCAN_LINE,424
.equ C_THEME_ID,432
.equ C_FENCE_CLOSED,440
.equ C_INFOPTR,448
.equ C_INFOLEN,456
.equ C_INPUT,512
.equ MD_CLEAN_MAX,MD_MAX*4
.equ C_CELLS,C_INPUT+MD_CLEAN_MAX
.equ MD_TABLE_COLUMNS,128
.equ MD_TABLE_STRIDE,MD_TABLE_COLUMNS*16
.equ C_WIDTHS,C_CELLS+MD_TABLE_STRIDE*2
.equ C_ALIGNS,C_WIDTHS+MD_TABLE_COLUMNS*8
.equ MD_FRAME,C_ALIGNS+MD_TABLE_COLUMNS*8+8
.macro ENTER
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
.endm
.macro LEAVE
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.endm
.macro PUT label
 .ifc \label,.m_heading
 mov edi,0
 call .M_color
 .else
 .ifc \label,.m_dim
 mov edi,1
 call .M_color
 .else
 .ifc \label,.m_code
 mov edi,2
 call .M_color
 .else
 .ifc \label,.m_link
 mov edi,3
 call .M_color
 .else
 .ifc \label,.m_keyword_color
 mov edi,4
 call .M_color
 .else
 .ifc \label,.m_string_color
 mov edi,5
 call .M_color
 .else
 .ifc \label,.m_number_color
 mov edi,6
 call .M_color
 .else
 .ifc \label,.m_foreground
 mov edi,7
 call .M_color
 .else
 .ifc \label,.m_math_color
 mov edi,8
 call .M_color
 .else
 .ifc \label,.m_code_foreground
 mov edi,9
 call .M_color
 .else
 .ifc \label,.m_gutter
 mov edi,10
 call .M_color
 .else
 .ifc \label,.m_comment_color
 mov edi,11
 call .M_color
 .else
 .ifc \label,.m_literal_color
 mov edi,12
 call .M_color
 .else
 lea rdi,[rip+\label]
 mov esi,OFFSET FLAT:\label\()_len
 call .M_put
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
 .endif
.endm
.macro TEXT label
 lea rdi,[rip+\label]
 mov esi,OFFSET FLAT:\label\()_len
 call .M_text
.endm
.text
.globl ui_sanitize,ui_format_markdown
# ui_sanitize(raw,len,out,cap) ->written/-28. Removes escape protocols, C0/C1
# controls and bidi steering; validates UTF8, replacing invalid bytes with U+FFFD.
# Stateless over a complete body, including a currently incomplete streamed body.
ui_sanitize:
 ENTER
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 xor ebx,ebx
 xor ebp,ebp
 test r13,r13
 jz .S_done
 test r12,r12
 jz .S_bad
.S_loop:
 cmp rbp,r13
 jae .S_done
 movzx eax,byte ptr [r12+rbp]
 cmp al,27
 je .S_escape
 cmp al,10
 je .S_ascii
 cmp al,9
 je .S_tab
 cmp al,32
 jb .S_skip
 cmp al,127
 je .S_skip
 cmp al,128
 jb .S_ascii
 # Decode and validate one scalar, while preserving its original UTF8 bytes.
 mov ecx,1
 cmp al,0xc2
 jb .S_replacement
 cmp al,0xe0
 jb .S_two
 cmp al,0xf0
 jb .S_three
 cmp al,0xf5
 jb .S_four
 jmp .S_replacement
.S_two:
 mov ecx,2
 and eax,31
 jmp .S_utf8
.S_three:
 mov ecx,3
 and eax,15
 jmp .S_utf8
.S_four:
 mov ecx,4
 and eax,7
.S_utf8:
 lea rdx,[rbp+rcx]
 cmp rdx,r13
 ja .S_replacement
 mov r8d,1
.S_continuation:
 lea r9,[r12+rbp]
 movzx edx,byte ptr [r9+r8]
 and edx,0xc0
 cmp edx,0x80
 jne .S_replacement
 lea r9,[r12+rbp]
 movzx edx,byte ptr [r9+r8]
 and edx,63
 shl eax,6
 or eax,edx
 inc r8
 cmp r8,rcx
 jb .S_continuation
 cmp ecx,2
 jne .S_not_two
 cmp eax,128
 jb .S_replacement
 jmp .S_scalar
.S_not_two:
 cmp ecx,3
 jne .S_not_three
 cmp eax,2048
 jb .S_replacement
 jmp .S_scalar
.S_not_three:
 cmp eax,65536
 jb .S_replacement
.S_scalar:
 cmp eax,0x10ffff
 ja .S_replacement
 cmp eax,0xd800
 jb .S_not_surrogate
 cmp eax,0xdfff
 jbe .S_replacement
.S_not_surrogate:
 cmp eax,0x80
 jb .S_valid
 cmp eax,0x9f
 jbe .S_skip_scalar
 cmp eax,0x202a
 jb .S_not_bidi
 cmp eax,0x202e
 jbe .S_skip_scalar
.S_not_bidi:
 cmp eax,0x2066
 jb .S_valid
 cmp eax,0x2069
 jbe .S_skip_scalar
.S_valid:
 lea rax,[rbx+rcx]
 cmp rax,r15
 ja .S_cap
 lea rsi,[r12+rbp]
 lea rdi,[r14+rbx]
 add rbp,rcx
 mov rbx,rax
 rep movsb
 jmp .S_loop
.S_skip_scalar:
 add rbp,rcx
 jmp .S_loop
.S_replacement:
 lea rax,[rbx+3]
 cmp rax,r15
 ja .S_cap
 mov word ptr [r14+rbx],0xbfef
 mov byte ptr [r14+rbx+2],0xbd
 add rbx,3
 inc rbp
 jmp .S_loop
.S_ascii:
 cmp rbx,r15
 jae .S_cap
 mov [r14+rbx],al
 inc rbx
.S_skip:
 inc rbp
 jmp .S_loop
.S_tab:
 lea rax,[rbx+4]
 cmp rax,r15
 ja .S_cap
 mov dword ptr [r14+rbx],0x20202020
 add rbx,4
 inc rbp
 jmp .S_loop
.S_escape:
 inc rbp
 cmp rbp,r13
 jae .S_done
 mov al,[r12+rbp]
 inc rbp
 cmp al,'['
 je .S_csi
 cmp al,']'
 je .S_string
 cmp al,'P'
 je .S_string
 cmp al,'_'
 je .S_string
 cmp al,'^'
 je .S_string
 cmp al,'X'
 je .S_string
 jmp .S_loop
.S_csi:
 cmp rbp,r13
 jae .S_done
 mov al,[r12+rbp]
 inc rbp
 cmp al,0x40
 jb .S_csi
 cmp al,0x7e
 ja .S_csi
 jmp .S_loop
.S_string:
 cmp rbp,r13
 jae .S_done
 mov al,[r12+rbp]
 inc rbp
 cmp al,7
 je .S_loop
 cmp al,27
 jne .S_string
 cmp rbp,r13
 jae .S_done
 cmp byte ptr [r12+rbp],'\\'
 jne .S_string
 inc rbp
 jmp .S_loop
.S_cap:
 mov rax,-28
 jmp .S_return
.S_bad:
 mov rax,-22
 jmp .S_return
.S_done:
 mov rax,rbx
.S_return:
 add rsp,8
 LEAVE

# RBX is this call's immutable context address. Output builder is sticky-bounded.
.M_put:
 cmp qword ptr [rbx+C_MEASURE],0
 jne .M_put_done
 cmp qword ptr [rbx+C_ERR],0
 jne .M_put_done
 mov rax,[rbx+C_LEN]
 add rax,rsi
 jc .M_put_bad
 cmp rax,[rbx+C_CAP]
 ja .M_put_bad
 mov rdx,rdi
 mov rdi,[rbx+C_OUT]
 add rdi,[rbx+C_LEN]
 mov rcx,rsi
 mov rsi,rdx
 rep movsb
 mov [rbx+C_LEN],rax
.M_put_done:
 ret
.M_put_bad:
 mov qword ptr [rbx+C_ERR],-28
 ret
.M_color:
 mov rax,[rbx+C_THEME]
 shl rdi,4
 add rax,rdi
 mov rsi,[rax+8]
 mov rdi,[rax]
 lea rdx,[rip+.m_palettes]
 add rdi,rdx
 jmp .M_put
.M_lf:
 sub rsp,8
 PUT .m_lf
 mov qword ptr [rbx+C_COL],0
 add rsp,8
 ret
.M_wrap:
 push r12
 call .M_lf
 mov r12,[rbx+C_INDENT]
 mov rax,[rbx+C_COLS]
 dec rax
 cmp r12,rax
 cmova r12,rax
.M_wrap_indent:
 test r12,r12
 jz .M_wrap_done
 PUT .m_space
 inc qword ptr [rbx+C_COL]
 dec r12
 jmp .M_wrap_indent
.M_wrap_done:
 pop r12
 ret
# Grapheme-aware cell wrapping, never splitting UTF8, combining marks or emoji.
.M_text:
 push r12
 push r13
 push r14
 push r15
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
.M_text_loop:
 cmp r14,r13
 jae .M_text_done
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov r15,rax
 cmp r15,r14
 jbe .M_text_bad
 cmp r15,r13
 ja .M_text_bad
 lea rdi,[r12+r14]
 mov rsi,r15
 sub rsi,r14
 call ui_text_width
 test rax,rax
 js .M_text_bad
 mov rdx,[rbx+C_COL]
 add rdx,rax
 cmp rdx,[rbx+C_COLS]
 jbe .M_text_fits
 cmp qword ptr [rbx+C_COL],0
 je .M_text_fits
 push rax
 sub rsp,8
 call .M_wrap
 add rsp,8
 pop rax
 mov rdx,[rbx+C_COL]
 add rdx,rax
.M_text_fits:
 mov [rbx+C_COL],rdx
 lea rdi,[r12+r14]
 mov rsi,r15
 sub rsi,r14
 call .M_put
 mov r14,r15
 cmp qword ptr [rbx+C_ERR],0
 je .M_text_loop
 jmp .M_text_done
.M_text_bad:
 mov qword ptr [rbx+C_ERR],-22
.M_text_done:
 add rsp,8
 pop r15
 pop r14
 pop r13
 pop r12
 ret

# Locate line at source offset: store pointer/length and next source offset.
.M_line:
 mov rax,[rbx+C_OFFSET]
 mov rcx,rax
 mov rdx,[rbx+C_SRC]
.M_line_scan:
 cmp rcx,[rbx+C_SIZE]
 jae .M_line_end
 cmp byte ptr [rdx+rcx],10
 je .M_line_lf
 inc rcx
 jmp .M_line_scan
.M_line_lf:
 mov qword ptr [rbx+C_NEWLINE],1
 lea rsi,[rcx+1]
 jmp .M_line_store
.M_line_end:
 mov qword ptr [rbx+C_NEWLINE],0
 mov rsi,rcx
.M_line_store:
 mov [rbx+C_OFFSET],rsi
 add rdx,rax
 sub rcx,rax
 mov [rbx+C_LINE],rdx
 mov [rbx+C_LLEN],rcx
 ret

ui_format_markdown:
 xor r9d,r9d
 jmp ui_format_markdown_ex
.globl ui_format_markdown_ex
ui_format_markdown_ex:
 xor r11d,r11d
 xor r10d,r10d
 jmp .M_format_entry
.globl ui_format_markdown_source
ui_format_markdown_source:
 mov r10,[rsp+8]
 xor r11d,r11d
 jmp .M_format_entry
.globl ui_format_markdown_full
ui_format_markdown_full:
 mov r10,[rsp+8]
 mov r11,[rsp+16]
.M_format_entry:
 ENTER
 sub rsp,MD_FRAME
 mov rbx,rsp
 mov [rbx+C_OUT],rdx
 mov [rbx+C_CAP],rcx
 cmp r9,OFFSET FLAT:UI_THEME_PALETTE_COUNT
 jb .M_theme_valid
 xor r9d,r9d
.M_theme_valid:
 mov [rbx+C_THEME_ID],r9
 imul r9,r9,208
 lea rax,[rip+.m_palettes]
 add rax,r9
 mov [rbx+C_THEME],rax
 mov qword ptr [rbx+C_MEASURE],0
 mov qword ptr [rbx+C_MATH],0
 mov [rbx+C_MATH_INDEX],r10
 mov [rbx+C_MERMAID_INDEX],r11
 mov qword ptr [rbx+C_BASE_STYLE],0
 mov qword ptr [rbx+C_INDENT],0
 mov qword ptr [rbx+C_LEN],0
 mov qword ptr [rbx+C_ERR],0
 mov qword ptr [rbx+C_OFFSET],0
 mov qword ptr [rbx+C_COL],0
 mov qword ptr [rbx+C_FENCE],0
 mov qword ptr [rbx+C_STYLE],0
 cmp rsi,MD_MAX
 ja .M_format_invalid
 test r8,r8
 jnz .M_columns
 mov r8d,80
.M_columns:
 cmp r8,4
 jb .M_format_invalid
 cmp r8,4096
 ja .M_format_invalid
 mov [rbx+C_COLS],r8
 lea rdx,[rbx+C_INPUT]
 mov ecx,MD_CLEAN_MAX
 call ui_sanitize
 test rax,rax
 js .M_format_return
 mov [rbx+C_SIZE],rax
 mov rcx,rax
 shl rcx,4
 mov [rbx+C_MATH_BUDGET],rcx
 lea rdx,[rbx+C_INPUT]
 mov [rbx+C_SRC],rdx
 .M_format_line:
 mov qword ptr [rbx+C_INDENT],0
 mov qword ptr [rbx+C_BASE_STYLE],0
 mov rax,[rbx+C_OFFSET]
 cmp rax,[rbx+C_SIZE]
 jae .M_format_done
 call .M_line
 mov r12,[rbx+C_LINE]
 mov r13,[rbx+C_LLEN]
 xor r14d,r14d
 # Fence indentation follows the original Qwen CODE_FENCE_RE (leading spaces).
.M_fence_indent:
 cmp r14,r13
 jae .M_fence_probe
 cmp byte ptr [r12+r14],' '
 jne .M_fence_probe
 inc r14
 jmp .M_fence_indent
.M_fence_probe:
 mov r15,r14
 cmp r14,r13
 jae .M_regular
 movzx eax,byte ptr [r12+r14]
 cmp al,'`'
 je .M_count_fence
 cmp al,'~'
 jne .M_regular
.M_count_fence:
 mov ebp,eax
.M_fence_run:
 cmp r14,r13
 jae .M_fence_counted
 cmp byte ptr [r12+r14],bpl
 jne .M_fence_counted
 inc r14
 jmp .M_fence_run
.M_fence_counted:
 mov rax,r14
 sub rax,r15
 cmp rax,3
 jb .M_regular
 cmp qword ptr [rbx+C_FENCE],0
 je .M_open_fence
 cmp [rbx+C_FENCE],rbp
 jne .M_regular
 cmp rax,[rbx+C_FCOUNT]
 jb .M_regular
 # Closing fences may have trailing whitespace only.
 mov rcx,r14
.M_close_spaces:
 cmp rcx,r13
 jae .M_close_fence
 cmp byte ptr [r12+rcx],' '
 jne .M_regular
 inc rcx
 jmp .M_close_spaces
.M_close_fence:
 mov qword ptr [rbx+C_FENCE],0
 jmp .M_format_next
.M_open_fence:
 mov [rbx+C_FENCE],rbp
 mov [rbx+C_FCOUNT],rax
 mov qword ptr [rbx+C_CODELINE],1
 lea rax,[r12+r14]
 mov [rbx+C_INFOPTR],rax
 mov rax,r13
 sub rax,r14
 mov [rbx+C_INFOLEN],rax
 call .M_code_count
 call .M_mermaid_fence
 jmp .M_format_next
.M_regular:
 cmp qword ptr [rbx+C_FENCE],0
 je .M_prose
 call .M_code
 jmp .M_line_finish
.M_prose:
 call .M_math_block
 test eax,eax
 jnz .M_format_next
 call .M_table_probe
 test eax,eax
 jnz .M_format_next
 xor r14d,r14d
 # Preserve list indentation; classify quote, heading, list and horizontal rule.
.M_indent:
 cmp r14,r13
 jae .M_inline_setup
 cmp byte ptr [r12+r14],' '
 jne .M_block
 inc r14
 jmp .M_indent
.M_block:
 mov rdi,r12
 mov rsi,r14
 call .M_text
 mov r15,r14
 mov al,[r12+r14]
 cmp al,'#'
 je .M_heading
 cmp al,'>'
 je .M_quote_block
 cmp al,'-'
 je .M_rule_probe
 cmp al,'*'
 je .M_rule_probe
 cmp al,'_'
 je .M_rule_probe
 cmp al,'+'
 je .M_bullet_probe
 cmp al,'0'
 jb .M_inline_setup
 cmp al,'9'
 jbe .M_ordered
 jmp .M_inline_setup
.M_heading:
 xor ebp,ebp
.M_heading_count:
 cmp r14,r13
 jae .M_inline_restore
 cmp byte ptr [r12+r14],'#'
 jne .M_heading_space
 inc r14
 inc ebp
 cmp ebp,4
 jbe .M_heading_count
 jmp .M_inline_restore
.M_heading_space:
 cmp byte ptr [r12+r14],' '
 jne .M_inline_restore
 inc r14
 cmp ebp,4
 je .M_heading_italic
 PUT .m_foreground
 PUT .m_bold
 mov qword ptr [rbx+C_BASE_STYLE],1
 jmp .M_inline_setup
.M_heading_italic:
 PUT .m_foreground
 PUT .m_italic
 mov qword ptr [rbx+C_BASE_STYLE],2
 jmp .M_inline_setup
.M_quote_block:
 inc r14
 TEXT .m_space
 PUT .m_dim
 TEXT .m_quote
 PUT .m_foreground
 PUT .m_italic
 mov qword ptr [rbx+C_BASE_STYLE],2
 cmp r14,r13
 jae .M_inline_setup
 cmp byte ptr [r12+r14],' '
 jne .M_inline_setup
 inc r14
 jmp .M_inline_setup
.M_rule_probe:
 mov dl,al
 mov rcx,r14
 xor ebp,ebp
.M_rule_count:
 cmp rcx,r13
 jae .M_rule_end
 mov al,[r12+rcx]
 inc rcx
 cmp al,' '
 je .M_rule_count
 cmp al,dl
 jne .M_bullet_probe
 inc ebp
 jmp .M_rule_count
.M_rule_end:
 cmp ebp,3
 jb .M_bullet_probe
 PUT .m_dim
 TEXT .m_hr
 jmp .M_line_finish
.M_bullet_probe:
 mov al,[r12+r14]
 cmp al,'-'
 je .M_bullet_valid
 cmp al,'*'
 je .M_bullet_valid
 cmp al,'+'
 jne .M_inline_setup
.M_bullet_valid:
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_setup
 cmp byte ptr [r12+r14+1],' '
 jne .M_inline_setup
 add r14,2
 TEXT .m_space
 # Actual Qwen task presentation: checked tick or empty circle, not brackets.
 lea rax,[r14+3]
 cmp rax,r13
 jae .M_list_marker
 cmp byte ptr [r12+r14],'['
 jne .M_list_marker
 cmp byte ptr [r12+r14+2],']'
 jne .M_list_marker
 cmp byte ptr [r12+r14+3],' '
 jne .M_list_marker
 mov al,[r12+r14+1]
 cmp al,' '
 je .M_list_unchecked
 or al,32
 cmp al,'x'
 jne .M_list_marker
 TEXT .m_checked
 add r14,4
 jmp .M_inline_setup
.M_list_unchecked:
 TEXT .m_unchecked
 add r14,4
 jmp .M_inline_setup
.M_list_marker:
 lea rdi,[r12+r15]
 mov esi,2
 call .M_text
 jmp .M_inline_setup
.M_ordered:
 mov rcx,r14
.M_ordered_digits:
 cmp rcx,r13
 jae .M_inline_setup
 mov al,[r12+rcx]
 cmp al,'0'
 jb .M_ordered_dot
 cmp al,'9'
 ja .M_ordered_dot
 inc rcx
 jmp .M_ordered_digits
.M_ordered_dot:
 cmp al,'.'
 je .M_ordered_space
 cmp al,')'
 jne .M_inline_setup
.M_ordered_space:
 lea rax,[rcx+1]
 cmp rax,r13
 jae .M_inline_setup
 cmp byte ptr [r12+rcx+1],' '
 jne .M_inline_setup
 lea r14,[rcx+2]
 TEXT .m_space
 lea rdi,[r12+r15]
 mov rsi,r14
 sub rsi,r15
 call .M_text
 PUT .m_reset
 jmp .M_inline_setup
.M_inline_restore:
 mov r14,r15
.M_inline_setup:
 mov rax,[rbx+C_COL]
 mov [rbx+C_INDENT],rax
 mov qword ptr [rbx+C_STYLE],0
 call .M_inline
.M_line_finish:
 PUT .m_reset
 cmp qword ptr [rbx+C_NEWLINE],0
 je .M_format_next
 call .M_lf
.M_format_next:
 cmp qword ptr [rbx+C_ERR],0
 je .M_format_line
.M_format_done:
 cmp qword ptr [rbx+C_MATH],0
 je .M_format_state_done
 PUT .m_reset
.M_format_state_done:
 mov rax,[rbx+C_ERR]
 test rax,rax
 jnz .M_format_return
 mov rax,[rbx+C_LEN]
 jmp .M_format_return
.M_format_invalid:
 mov rax,-22
.M_format_return:
 add rsp,MD_FRAME
 LEAVE

# Inline parser. Style commands are generated constants and reset at every
# logical line. Incomplete streaming markers are never terminal escape bytes.
.M_inline:
 push rbp
 mov qword ptr [rbx+C_WORD],1
 mov rax,r13
 shl rax,2
 mov [rbx+208],rax
.M_inline_loop:
 mov qword ptr [rbx+C_IMAGE],0
 cmp r14,r13
 jae .M_inline_done
 mov al,[r12+r14]
 test qword ptr [rbx+C_STYLE],8
 jz .M_inline_not_code
 cmp al,'`'
 je .M_inline_code_close
 jmp .M_inline_character
.M_inline_not_code:
 cmp al,'$'
 je .M_inline_math
 cmp al,'!'
 je .M_inline_image
 cmp al,'\\'
 je .M_inline_escape
 cmp al,'`'
 je .M_inline_code_open
 cmp al,'['
 je .M_inline_link
 cmp al,'*'
 je .M_inline_star
 cmp al,'_'
 je .M_inline_italic
 cmp al,'~'
 je .M_inline_strike
 jmp .M_inline_character
.M_inline_escape:
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_character
 mov al,[r12+r14+1]
 cmp al,33
 jb .M_inline_character
 cmp al,47
 jbe .M_inline_escape_valid
 cmp al,58
 jb .M_inline_character
 cmp al,64
 jbe .M_inline_escape_valid
 cmp al,91
 jb .M_inline_character
 cmp al,96
 jbe .M_inline_escape_valid
 cmp al,123
 jb .M_inline_character
 cmp al,126
 ja .M_inline_character
.M_inline_escape_valid:
 inc r14
 jmp .M_inline_character
.M_inline_star:
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_italic
 cmp byte ptr [r12+r14+1],'*'
 jne .M_inline_italic
 test qword ptr [rbx+C_STYLE],1
 jnz .M_inline_bold_toggle
 lea rax,[r14+2]
 cmp rax,r13
 jae .M_inline_character
 cmp byte ptr [r12+r14+2],' '
 je .M_inline_character
.M_inline_bold_toggle:
 add r14,2
 xor qword ptr [rbx+C_STYLE],1
 test qword ptr [rbx+C_STYLE],1
 jz .M_inline_bold_off
 PUT .m_bold
 jmp .M_inline_loop
.M_inline_bold_off:
 test qword ptr [rbx+C_BASE_STYLE],1
 jz .M_inline_bold_clear
 PUT .m_bold
 jmp .M_inline_loop
.M_inline_bold_clear:
 PUT .m_bold_off
 jmp .M_inline_loop
.M_inline_italic:
 # Do not consume word-internal underscores in identifiers/paths.
 cmp al,'_'
 jne .M_inline_italic_toggle
 test qword ptr [rbx+C_STYLE],2
 jnz .M_inline_italic_toggle
 test r14,r14
 jz .M_inline_italic_toggle
 mov al,[r12+r14-1]
 cmp al,' '
 jne .M_inline_character
.M_inline_italic_toggle:
 test qword ptr [rbx+C_STYLE],2
 jnz .M_inline_italic_ready
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_character
 cmp byte ptr [r12+r14+1],' '
 je .M_inline_character
.M_inline_italic_ready:
 inc r14
 xor qword ptr [rbx+C_STYLE],2
 test qword ptr [rbx+C_STYLE],2
 jz .M_inline_italic_off
 PUT .m_italic
 jmp .M_inline_loop
.M_inline_italic_off:
 test qword ptr [rbx+C_BASE_STYLE],2
 jz .M_inline_italic_clear
 PUT .m_italic
 jmp .M_inline_loop
.M_inline_italic_clear:
 PUT .m_italic_off
 jmp .M_inline_loop
.M_inline_strike:
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_character
 cmp byte ptr [r12+r14+1],'~'
 jne .M_inline_character
 test qword ptr [rbx+C_STYLE],4
 jnz .M_inline_strike_ready
 lea rax,[r14+2]
 cmp rax,r13
 jae .M_inline_character
 cmp byte ptr [r12+r14+2],' '
 je .M_inline_character
.M_inline_strike_ready:
 add r14,2
 xor qword ptr [rbx+C_STYLE],4
 test qword ptr [rbx+C_STYLE],4
 jz .M_inline_strike_off
 PUT .m_strike
 jmp .M_inline_loop
.M_inline_strike_off:
 PUT .m_strike_off
 jmp .M_inline_loop
.M_inline_code_open:
 or qword ptr [rbx+C_STYLE],8
 inc r14
 PUT .m_code
 jmp .M_inline_loop
.M_inline_code_close:
 and qword ptr [rbx+C_STYLE],-9
 inc r14
 PUT .m_foreground
 jmp .M_inline_loop
.M_inline_math:
 # Original delimiter rules exclude currency, word-internal dollars and spaces.
 test r14,r14
 jz .M_math_open_next
 mov al,[r12+r14-1]
 cmp al,'$'
 je .M_inline_character
 call .M_ascii_word
 test eax,eax
 jnz .M_inline_character
.M_math_open_next:
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_character
 mov al,[r12+r14+1]
 cmp al,' '
 je .M_inline_character
 cmp al,'$'
 je .M_inline_character
 cmp al,'0'
 jb .M_math_open_ok
 cmp al,'9'
 jbe .M_inline_character
.M_math_open_ok:
 lea rbp,[r14+1]
.M_math_find_close:
 cmp rbp,r13
 jae .M_inline_character
 mov rax,rbp
 sub rax,r14
 cmp rax,1025
 ja .M_inline_character
 cmp byte ptr [r12+rbp],'$'
 je .M_math_close_probe
 cmp byte ptr [r12+rbp],'\\'
 jne .M_math_find_next
 inc rbp
.M_math_find_next:
 inc rbp
 jmp .M_math_find_close
.M_math_close_probe:
 cmp byte ptr [r12+rbp-1],' '
 je .M_inline_character
 lea rax,[rbp+1]
 cmp rax,r13
 jae .M_math_inline_found
 mov al,[r12+rbp+1]
 cmp al,'$'
 je .M_inline_character
 call .M_ascii_word
 test eax,eax
 jnz .M_inline_character
.M_math_inline_found:
 mov [rbx+C_END],rbp
 PUT .m_math_color
 lea rdi,[r12+r14+1]
 mov rsi,rbp
 sub rsi,r14
 dec rsi
 xor edx,edx
 call .M_math
 PUT .m_foreground
 mov r14,[rbx+C_END]
 inc r14
 jmp .M_inline_loop
# AL ->ASCII word predicate, preserving every callee saved register.
.M_ascii_word:
 cmp al,'_'
 je .M_ascii_yes
 cmp al,'0'
 jb .M_ascii_alpha
 cmp al,'9'
 jbe .M_ascii_yes
.M_ascii_alpha:
 or al,32
 cmp al,'a'
 jb .M_ascii_no
 cmp al,'z'
 jbe .M_ascii_yes
.M_ascii_no:
 xor eax,eax
 ret
.M_ascii_yes:
 mov eax,1
 ret
.M_inline_image:
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_inline_character
 cmp byte ptr [r12+r14+1],'['
 jne .M_inline_character
 mov qword ptr [rbx+C_IMAGE],1
 inc r14
.M_inline_link:
 cmp qword ptr [rbx+208],0
 je .M_link_failure
 # A link is rendered only after its bounded complete syntax is present.
 mov rcx,r14
 inc rcx
.M_link_label:
 cmp qword ptr [rbx+208],0
 je .M_link_failure
 dec qword ptr [rbx+208]
 cmp rcx,r13
 jae .M_link_failure
 cmp byte ptr [r12+rcx],']'
 je .M_link_bracket
 inc rcx
 jmp .M_link_label
.M_link_bracket:
 lea rax,[rcx+1]
 cmp rax,r13
 jae .M_link_failure
 cmp byte ptr [r12+rcx+1],'('
 jne .M_link_failure
 mov rbp,rcx
 lea rcx,[rcx+2]
.M_link_url:
 cmp qword ptr [rbx+208],0
 je .M_link_failure
 dec qword ptr [rbx+208]
 cmp rcx,r13
 jae .M_link_failure
 cmp byte ptr [r12+rcx],')'
 je .M_link_found
 inc rcx
 jmp .M_link_url
.M_link_failure:
 cmp qword ptr [rbx+C_IMAGE],0
 je .M_inline_character
 dec r14
 mov qword ptr [rbx+C_IMAGE],0
 jmp .M_inline_character
.M_link_found:
 # Save spans in the small private context, not volatile argument registers.
 mov [rbx+C_START],rbp
 mov [rbx+C_END],rcx
 cmp qword ptr [rbx+C_IMAGE],0
 je .M_link_color
 TEXT .m_image_open
.M_link_color:
 PUT .m_link
 lea rdi,[r12+r14+1]
 mov rsi,[rbx+C_START]
 sub rsi,r14
 dec rsi
 call .M_text
 PUT .m_link_off
 cmp qword ptr [rbx+C_IMAGE],0
 je .M_link_url_color
 TEXT .m_image_close
.M_link_url_color:
 PUT .m_dim
 TEXT .m_url_open
 mov rax,[rbx+C_START]
 lea rdi,[r12+rax+2]
 mov rsi,[rbx+C_END]
 sub rsi,rax
 sub rsi,2
 call .M_text
 TEXT .m_url_close
 PUT .m_foreground
 mov r14,[rbx+C_END]
 inc r14
 jmp .M_inline_loop
.M_inline_character:
 cmp byte ptr [r12+r14],' '
 jne .M_inline_word
 mov qword ptr [rbx+C_WORD],1
 mov rax,[rbx+C_COL]
 cmp rax,[rbx+C_COLS]
 jb .M_inline_grapheme
 call .M_wrap
 inc r14
 jmp .M_inline_loop
.M_inline_word:
 cmp qword ptr [rbx+C_WORD],0
 je .M_inline_grapheme
 mov qword ptr [rbx+C_WORD],0
 test qword ptr [rbx+C_STYLE],8
 jnz .M_inline_grapheme
 mov rbp,r14
.M_inline_word_scan:
 cmp rbp,r13
 jae .M_inline_word_width
 mov al,[r12+rbp]
 cmp al,' '
 je .M_inline_word_width
 cmp al,'*'
 je .M_inline_word_width
 cmp al,'_'
 je .M_inline_word_width
 cmp al,'~'
 je .M_inline_word_width
 cmp al,'['
 je .M_inline_word_width
 cmp al,'`'
 je .M_inline_word_width
 cmp al,'$'
 je .M_inline_word_width
 inc rbp
 jmp .M_inline_word_scan
.M_inline_word_width:
 cmp rbp,r14
 je .M_inline_grapheme
 lea rdi,[r12+r14]
 mov rsi,rbp
 sub rsi,r14
 call ui_text_width
 mov rdx,[rbx+C_COLS]
 sub rdx,[rbx+C_INDENT]
 cmp rax,rdx
 ja .M_inline_grapheme
 add rax,[rbx+C_COL]
 cmp rax,[rbx+C_COLS]
 jbe .M_inline_grapheme
 mov rax,[rbx+C_COL]
 cmp rax,[rbx+C_INDENT]
 jbe .M_inline_grapheme
 call .M_wrap
.M_inline_grapheme:
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov rbp,rax
 cmp rbp,r14
 jbe .M_inline_done
 lea rdi,[r12+r14]
 mov rsi,rbp
 sub rsi,r14
 call .M_text
 mov r14,rbp
 jmp .M_inline_loop
.M_inline_done:
 pop rbp
 ret

# Count a complete/current code body for the original padded line-number gutter.
.M_code_count:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r15,[rbx+C_OFFSET]
 xor r12d,r12d
.M_code_count_line:
 mov rax,r15
 cmp rax,[rbx+C_SIZE]
 jae .M_code_count_eof
 mov [rbx+C_SCAN_LINE],r15
 call .M_peek
 mov r15,rdx
 xor ecx,ecx
.M_code_count_indent:
 cmp rcx,rsi
 jae .M_code_count_body
 cmp byte ptr [rdi+rcx],' '
 jne .M_code_count_marker
 inc rcx
 jmp .M_code_count_indent
.M_code_count_marker:
 mov r8,rcx
 mov r9,[rbx+C_FENCE]
.M_code_count_run:
 cmp rcx,rsi
 jae .M_code_count_run_end
 cmp byte ptr [rdi+rcx],r9b
 jne .M_code_count_run_end
 inc rcx
 jmp .M_code_count_run
.M_code_count_run_end:
 mov rax,rcx
 sub rax,r8
 cmp rax,[rbx+C_FCOUNT]
 jb .M_code_count_body
.M_code_count_tail:
 cmp rcx,rsi
 jae .M_code_count_closed
 cmp byte ptr [rdi+rcx],' '
 jne .M_code_count_body
 inc rcx
 jmp .M_code_count_tail
.M_code_count_body:
 inc r12
 jmp .M_code_count_line
.M_code_count_closed:
 mov rax,[rbx+C_SCAN_LINE]
 mov [rbx+C_FENCE_END],rax
 mov [rbx+C_FENCE_NEXT],r15
 mov qword ptr [rbx+C_FENCE_CLOSED],1
 jmp .M_code_count_end
.M_code_count_eof:
 mov rax,[rbx+C_SIZE]
 mov [rbx+C_FENCE_END],rax
 mov [rbx+C_FENCE_NEXT],rax
 mov qword ptr [rbx+C_FENCE_CLOSED],0
.M_code_count_end:
 mov rax,r12
 mov ecx,1
 mov r8d,10
.M_code_pad_digits:
 xor edx,edx
 div r8
 test rax,rax
 jz .M_code_pad_done
 inc ecx
 jmp .M_code_pad_digits
.M_code_pad_done:
 mov [rbx+C_CODEPAD],rcx
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

.M_mermaid_fence:
 push r12
 push r13
 sub rsp,8
 mov rdi,[rbx+C_INFOPTR]
 mov rsi,[rbx+C_INFOLEN]
.M_mermaid_info_space:
 test rsi,rsi
 jz .M_mermaid_return
 cmp byte ptr [rdi],' '
 jne .M_mermaid_info
 inc rdi
 dec rsi
 jmp .M_mermaid_info_space
.M_mermaid_info:
 cmp rsi,7
 jb .M_mermaid_return
 xor ecx,ecx
 lea rdx,[rip+.m_mermaid_lang]
.M_mermaid_lang_byte:
 cmp ecx,7
 jae .M_mermaid_lang_end
 mov al,[rdi+rcx]
 or al,32
 cmp al,[rdx+rcx]
 jne .M_mermaid_return
 inc ecx
 jmp .M_mermaid_lang_byte
.M_mermaid_lang_end:
 cmp rsi,7
 je .M_mermaid_detected
 cmp byte ptr [rdi+7],' '
 jne .M_mermaid_return
.M_mermaid_detected:
 inc qword ptr [rbx+C_MERMAID_INDEX]
 cmp qword ptr [rbx+C_FENCE_CLOSED],0
 je .M_mermaid_pending
 mov rdi,[rbx+C_SRC]
 add rdi,[rbx+C_OFFSET]
 mov rsi,[rbx+C_FENCE_END]
 sub rsi,[rbx+C_OFFSET]
 mov rdx,[rbx+C_OUT]
 add rdx,[rbx+C_LEN]
 mov rcx,[rbx+C_CAP]
 sub rcx,[rbx+C_LEN]
 # Markdown body reserves a two-cell right inset before diagram padding.
 mov r8,[rbx+C_COLS]
 sub r8,2
 mov r9,[rbx+C_THEME_ID]
 sub rsp,16
 mov rax,[rbx+C_MERMAID_INDEX]
 mov [rsp],rax
 call ui_render_mermaid
 add rsp,16
 test rax,rax
 js .M_mermaid_error
 add [rbx+C_LEN],rax
 mov rax,[rbx+C_FENCE_NEXT]
 mov [rbx+C_OFFSET],rax
 mov qword ptr [rbx+C_FENCE],0
 mov qword ptr [rbx+C_COL],0
 jmp .M_mermaid_return
.M_mermaid_error:
 cmp rax,-28
 jne .M_mermaid_source_limit
 mov [rbx+C_ERR],rax
 jmp .M_mermaid_return
.M_mermaid_source_limit:
 PUT .m_math_color
 TEXT .m_mermaid_limit
 mov rdi,[rbx+C_MERMAID_INDEX]
 call .M_number
 PUT .m_reset
 call .M_lf
 jmp .M_mermaid_return
.M_mermaid_pending:
 PUT .m_math_color
 TEXT .m_space
 TEXT .m_mermaid_pending
 PUT .m_reset
 call .M_lf
 mov r12,[rbx+C_OFFSET]
 xor r13d,r13d
.M_mermaid_pending_line:
 cmp r12,[rbx+C_SIZE]
 jae .M_mermaid_pending_done
 cmp r13,6
 jae .M_mermaid_pending_done
 mov rax,r12
 call .M_peek
 mov r12,rdx
 mov [rsp],rsi
 PUT .m_dim
 TEXT .m_space
 mov rdi,[rbx+C_SRC]
 add rdi,[rbx+C_OFFSET]
 mov rsi,[rsp]
 call .M_text
 mov [rbx+C_OFFSET],r12
 PUT .m_reset
 call .M_lf
 inc r13
 jmp .M_mermaid_pending_line
.M_mermaid_pending_done:
 mov rax,[rbx+C_SIZE]
 mov [rbx+C_OFFSET],rax
 mov qword ptr [rbx+C_FENCE],0
.M_mermaid_return:
 add rsp,8
 pop r13
 pop r12
 ret

# Small unsigned formatter used by code-line gutter.
.M_number:
 sub rsp,40
 mov rax,rdi
 lea rdi,[rsp+32]
 xor ecx,ecx
 mov r8d,10
.M_number_digit:
 xor edx,edx
 div r8
 add dl,'0'
 dec rdi
 mov [rdi],dl
 inc ecx
 test rax,rax
 jnz .M_number_digit
 mov esi,ecx
 call .M_text
 add rsp,40
 ret

# Code highlighting is deliberately a bounded common-language lexer, not a
# second language parser. Keywords, strings, comments and numbers have theme
# colors. Language labels are visible; unsupported languages remain readable.
.M_code:
 push rbp
 PUT .m_gutter
 TEXT .m_space
 mov rax,[rbx+C_CODELINE]
 mov ecx,1
 mov r8d,10
.M_code_number_width:
 xor edx,edx
 div r8
 test rax,rax
 jz .M_code_number_pad
 inc ecx
 jmp .M_code_number_width
.M_code_number_pad:
 mov rbp,[rbx+C_CODEPAD]
 sub rbp,rcx
.M_code_number_spaces:
 test rbp,rbp
 jz .M_code_number_emit
 TEXT .m_space
 dec rbp
 jmp .M_code_number_spaces
.M_code_number_emit:
 mov rdi,[rbx+C_CODELINE]
 call .M_number
 inc qword ptr [rbx+C_CODELINE]
 TEXT .m_space
 mov rax,[rbx+C_COL]
 mov [rbx+C_INDENT],rax
 PUT .m_code_foreground
 xor r14d,r14d
.M_code_loop:
 cmp r14,r13
 jae .M_code_done
 mov qword ptr [rbx+216],0
 mov al,[r12+r14]
 cmp al,'"'
 je .M_code_string
 cmp al,39
 je .M_code_string
 cmp al,'#'
 je .M_code_comment
 cmp al,'/'
 jne .M_code_number_probe
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_code_plain
 cmp byte ptr [r12+r14+1],'/'
 je .M_code_comment
.M_code_number_probe:
 mov al,[r12+r14]
 cmp al,'0'
 jb .M_code_word_probe
 cmp al,'9'
 ja .M_code_word_probe
 PUT .m_number_color
 mov qword ptr [rbx+216],1
 mov rbp,r14
.M_code_number_more:
 inc rbp
 cmp rbp,r13
 jae .M_code_span
 mov al,[r12+rbp]
 cmp al,'.'
 je .M_code_number_more
 cmp al,'_'
 je .M_code_number_more
 cmp al,'0'
 jb .M_code_span
 cmp al,'9'
 jbe .M_code_number_more
 jmp .M_code_span
.M_code_word_probe:
 cmp al,'_'
 je .M_code_word
 or al,32
 cmp al,'a'
 jb .M_code_plain
 cmp al,'z'
 ja .M_code_plain
.M_code_word:
 mov rbp,r14
.M_code_word_more:
 inc rbp
 cmp rbp,r13
 jae .M_code_word_end
 mov al,[r12+rbp]
 cmp al,'_'
 je .M_code_word_more
 cmp al,'0'
 jb .M_code_word_alpha
 cmp al,'9'
 jbe .M_code_word_more
.M_code_word_alpha:
 or al,32
 cmp al,'a'
 jb .M_code_word_end
 cmp al,'z'
 jbe .M_code_word_more
.M_code_word_end:
 lea rdi,[r12+r14]
 mov rsi,rbp
 sub rsi,r14
 call .M_literal_keyword
 test eax,eax
 jz .M_code_regular_keyword
 PUT .m_literal_color
 mov qword ptr [rbx+216],1
 jmp .M_code_span
.M_code_regular_keyword:
 lea rdi,[r12+r14]
 mov rsi,rbp
 sub rsi,r14
 call .M_keyword
 test eax,eax
 jz .M_code_span
 PUT .m_keyword_color
 mov qword ptr [rbx+216],1
 jmp .M_code_span
.M_code_string:
 mov dl,al
 lea rbp,[r14+1]
.M_code_string_more:
 cmp rbp,r13
 jae .M_code_string_end
 mov al,[r12+rbp]
 inc rbp
 cmp al,'\\'
 jne .M_code_string_quote
 cmp rbp,r13
 jae .M_code_string_end
 inc rbp
 jmp .M_code_string_more
.M_code_string_quote:
 cmp al,dl
 jne .M_code_string_more
.M_code_string_end:
 mov qword ptr [rbx+216],1
 PUT .m_string_color
 jmp .M_code_span
.M_code_comment:
 mov qword ptr [rbx+216],1
 PUT .m_comment_color
 mov rbp,r13
 jmp .M_code_span
.M_code_plain:
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov rbp,rax
.M_code_span:
 lea rdi,[r12+r14]
 mov rsi,rbp
 sub rsi,r14
 call .M_text
 cmp qword ptr [rbx+216],0
 je .M_code_span_next
 PUT .m_bold_off
 PUT .m_code_foreground
.M_code_span_next:
 mov r14,rbp
 jmp .M_code_loop
.M_code_done:
 pop rbp
 ret
# keyword(ptr,len)->1/0, exact case-sensitive comparisons over a fixed table.
.M_literal_keyword:
 lea r8,[rip+.m_literals]
 jmp .M_keyword_next
.M_keyword:
 lea r8,[rip+.m_keywords]
.M_keyword_next:
 cmp byte ptr [r8],0
 je .M_keyword_no
 xor ecx,ecx
.M_keyword_byte:
 cmp rcx,rsi
 jae .M_keyword_end
 mov al,[r8+rcx]
 test al,al
 jz .M_keyword_skip
 cmp al,[rdi+rcx]
 jne .M_keyword_skip
 inc rcx
 jmp .M_keyword_byte
.M_keyword_end:
 cmp byte ptr [r8+rcx],0
 je .M_keyword_yes
.M_keyword_skip:
 cmp byte ptr [r8],0
 je .M_keyword_advance
 inc r8
 jmp .M_keyword_skip
.M_keyword_advance:
 inc r8
 jmp .M_keyword_next
.M_keyword_yes:
 mov eax,1
 ret
.M_keyword_no:
 xor eax,eax
 ret

# Peek offset -> pointer,length,next-offset. Does not alter current line state.
.M_peek:
 mov rdi,[rbx+C_SRC]
 add rdi,rax
 mov rcx,rax
 mov rdx,[rbx+C_SRC]
.M_peek_scan:
 cmp rcx,[rbx+C_SIZE]
 jae .M_peek_end
 cmp byte ptr [rdx+rcx],10
 je .M_peek_lf
 inc rcx
 jmp .M_peek_scan
.M_peek_lf:
 lea rdx,[rcx+1]
 jmp .M_peek_result
.M_peek_end:
 mov rdx,rcx
.M_peek_result:
 mov rsi,rcx
 sub rsi,rax
 ret

# Parse bounded raw cells into fixed row slots. Leading/trailing bars optional.
.M_parse_cells:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12,rdi
 lea r13,[rdi+rsi]
 mov r14,rdi
 xor r15d,r15d
 shl rdx,11
 lea rbp,[rbx+C_CELLS]
 add rbp,rdx
.M_cells_indent:
 cmp r14,r13
 jae .M_cells_done
 cmp byte ptr [r14],' '
 jne .M_cells_first
 inc r14
 jmp .M_cells_indent
.M_cells_first:
 cmp byte ptr [r14],'|'
 jne .M_cells_begin
 inc r14
.M_cells_begin:
 cmp r14,r13
 jae .M_cells_done
 cmp r15,MD_TABLE_COLUMNS
 jae .M_cells_bad
 mov r12,r14
 xor r8d,r8d
.M_cell_find:
 cmp r14,r13
 jae .M_cell_trim
 mov al,[r14]
 cmp al,'\\'
 jne .M_cell_fence_check
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_cell_advance
 cmp byte ptr [r14+1],'|'
 jne .M_cell_advance
 add r14,2
 jmp .M_cell_find
.M_cell_fence_check:
 cmp al,'`'
 jne .M_cell_pipe_check
 xor r8d,1
 jmp .M_cell_advance
.M_cell_pipe_check:
 cmp al,'|'
 jne .M_cell_advance
 test r8d,r8d
 jz .M_cell_trim
.M_cell_advance:
 inc r14
 jmp .M_cell_find
.M_cell_trim:
 mov rcx,r14
.M_cell_trim_right:
 cmp rcx,r12
 jbe .M_cell_trim_left
 cmp byte ptr [rcx-1],' '
 jne .M_cell_trim_left
 dec rcx
 jmp .M_cell_trim_right
.M_cell_trim_left:
 cmp r12,rcx
 jae .M_cell_store
 cmp byte ptr [r12],' '
 jne .M_cell_store
 inc r12
 jmp .M_cell_trim_left
.M_cell_store:
 mov rax,r15
 shl rax,4
 mov [rbp+rax],r12
 sub rcx,r12
 mov [rbp+rax+8],rcx
 inc r15
 cmp r14,r13
 jae .M_cells_done
 inc r14
 # A final delimiter followed only by spaces does not add a phantom cell.
 mov rcx,r14
.M_cell_tail_spaces:
 cmp rcx,r13
 jae .M_cells_done
 cmp byte ptr [rcx],' '
 jne .M_cells_begin
 inc rcx
 jmp .M_cell_tail_spaces
.M_cells_done:
 mov rax,r15
 jmp .M_cells_return
.M_cells_bad:
 mov rax,-1
.M_cells_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

.M_has_pipe:
 xor eax,eax
 xor ecx,ecx
.M_pipe_scan:
 cmp rcx,rsi
 jae .M_pipe_done
 cmp byte ptr [rdi+rcx],'|'
 je .M_pipe_yes
 inc rcx
 jmp .M_pipe_scan
.M_pipe_yes:
 mov eax,1
.M_pipe_done:
 ret


# Inline measurement uses the same parser in a private counting mode; no SGR or
# marker bytes count as terminal cells. This keeps alignment and display equal.
.M_measure_inline:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 mov r13,rsi
 mov rax,[rbx+C_COL]
 mov [rsp],rax
 mov rax,[rbx+C_COLS]
 mov [rsp+8],rax
 mov rax,[rbx+C_MEASURE]
 mov [rsp+16],rax
 mov rax,[rbx+C_STYLE]
 mov [rsp+24],rax
 mov qword ptr [rbx+C_COL],0
 mov qword ptr [rbx+C_COLS],0x7fffffff
 mov qword ptr [rbx+C_MEASURE],1
 mov qword ptr [rbx+C_STYLE],0
 xor r14d,r14d
 call .M_inline
 mov r15,[rbx+C_COL]
 mov rax,[rsp]
 mov [rbx+C_COL],rax
 mov rax,[rsp+8]
 mov [rbx+C_COLS],rax
 mov rax,[rsp+16]
 mov [rbx+C_MEASURE],rax
 mov rax,[rsp+24]
 mov [rbx+C_STYLE],rax
 mov rax,r15
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.M_render_inline:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 mov qword ptr [rbx+C_STYLE],0
 call .M_inline
 pop r14
 pop r13
 pop r12
 ret
.M_measure_row:
 push r12
 push r13
 push r14
 mov r12,rdi
 imul r12,r12,MD_TABLE_STRIDE
 lea r13,[rbx+C_CELLS]
 add r12,r13
 xor r14d,r14d
.M_measure_row_loop:
 cmp r14,[rbx+C_NCOLS]
 jae .M_measure_row_done
 mov rdi,[r12]
 mov rsi,[r12+8]
 call .M_measure_inline
 cmp rax,3
 jae .M_measure_min
 mov eax,3
.M_measure_min:
 cmp rax,[rbx+r14*8+C_WIDTHS]
 jbe .M_measure_row_next
 mov [rbx+r14*8+C_WIDTHS],rax
.M_measure_row_next:
 add r12,16
 inc r14
 jmp .M_measure_row_loop
.M_measure_row_done:
 pop r14
 pop r13
 pop r12
 ret

.M_table_probe:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,16
 mov rdi,[rbx+C_LINE]
 mov rsi,[rbx+C_LLEN]
 call .M_has_pipe
 test eax,eax
 jz .M_table_no
 cmp qword ptr [rbx+C_NEWLINE],0
 je .M_table_no
 mov rax,[rbx+C_OFFSET]
 cmp rax,[rbx+C_SIZE]
 jae .M_table_no
 call .M_peek
 mov [rbx+C_BODY_START],rdx
 xor ecx,ecx
 xor r8d,r8d
.M_separator_scan:
 cmp rcx,rsi
 jae .M_separator_done
 mov al,[rdi+rcx]
 inc rcx
 cmp al,'-'
 je .M_separator_dash
 cmp al,'|'
 je .M_separator_scan
 cmp al,':'
 je .M_separator_scan
 cmp al,' '
 je .M_separator_scan
 jmp .M_table_no
.M_separator_dash:
 inc r8
 jmp .M_separator_scan
.M_separator_done:
 cmp r8,3
 jb .M_table_no
 mov edx,1
 call .M_parse_cells
 test rax,rax
 jle .M_table_no
 mov [rsp+8],rax
 mov rdi,[rbx+C_LINE]
 mov rsi,[rbx+C_LLEN]
 xor edx,edx
 call .M_parse_cells
 cmp rax,[rsp+8]
 jne .M_table_no
 mov [rbx+C_NCOLS],rax
 xor r12d,r12d
.M_table_alignment:
 cmp r12,[rbx+C_NCOLS]
 jae .M_table_alignment_done
 mov rax,r12
 shl rax,4
 lea rdi,[rbx+C_CELLS+MD_TABLE_STRIDE]
 add rdi,rax
 mov rsi,[rdi+8]
 mov rdi,[rdi]
 xor r8d,r8d
 test rsi,rsi
 jz .M_table_no
 cmp byte ptr [rdi],':'
 jne .M_table_alignment_right
 mov r8d,2
 inc rdi
 dec rsi
.M_table_alignment_right:
 test rsi,rsi
 jz .M_table_no
 cmp byte ptr [rdi+rsi-1],':'
 jne .M_table_alignment_left
 dec rsi
 test r8d,r8d
 jnz .M_table_alignment_dash
 mov r8d,1
 jmp .M_table_alignment_dash
.M_table_alignment_left:
 xor r8d,r8d
.M_table_alignment_dash:
 test rsi,rsi
 jz .M_table_no
 xor ecx,ecx
.M_table_alignment_each:
 cmp rcx,rsi
 jae .M_table_alignment_save
 cmp byte ptr [rdi+rcx],'-'
 jne .M_table_no
 inc rcx
 jmp .M_table_alignment_each
.M_table_alignment_save:
 mov [rbx+r12*8+C_ALIGNS],r8
 inc r12
 jmp .M_table_alignment
.M_table_alignment_done:
 lea rdi,[rbx+C_WIDTHS]
 xor eax,eax
 mov ecx,MD_TABLE_COLUMNS
 rep stosq
 xor edi,edi
 call .M_measure_row
 mov rax,[rbx+C_BODY_START]
 mov [rbx+C_TABLE_END],rax
 mov qword ptr [rbx+C_ROWS],1
.M_table_gather:
 mov rax,[rbx+C_TABLE_END]
 cmp rax,[rbx+C_SIZE]
 jae .M_table_select_layout
 call .M_peek
 mov [rsp],rdx
 mov r12,rdi
 mov r13,rsi
 call .M_has_pipe
 test eax,eax
 jz .M_table_select_layout
 mov rdi,r12
 mov rsi,r13
 mov edx,1
 call .M_parse_cells
 cmp rax,[rbx+C_NCOLS]
 jne .M_table_select_layout
 mov edi,1
 call .M_measure_row
 inc qword ptr [rbx+C_ROWS]
 mov rax,[rsp]
 mov [rbx+C_TABLE_END],rax
 jmp .M_table_gather
.M_table_select_layout:
 mov qword ptr [rbx+C_TVERT],0
 mov rax,[rbx+C_NCOLS]
 imul rax,rax,6
 add rax,5
 cmp rax,24
 jae .M_table_minimum
 mov eax,24
.M_table_minimum:
 cmp rax,[rbx+C_COLS]
 ja .M_table_vertical
 mov rax,[rbx+C_NCOLS]
 lea rax,[rax+rax*2+1]
 xor ecx,ecx
.M_table_total_width:
 cmp rcx,[rbx+C_NCOLS]
 jae .M_table_width_done
 add rax,[rbx+rcx*8+C_WIDTHS]
 inc rcx
 jmp .M_table_total_width
.M_table_width_done:
 cmp rax,[rbx+C_COLS]
 jbe .M_table_horizontal
.M_table_vertical:
 mov qword ptr [rbx+C_TVERT],1
 jmp .M_table_body_render
.M_table_horizontal:
 call .M_lf
 xor edi,edi
 call .M_table_border
 xor edi,edi
 call .M_table_render_row
 cmp qword ptr [rbx+C_ROWS],1
 jbe .M_table_body_render
 mov edi,1
 call .M_table_border
.M_table_body_render:
 mov qword ptr [rbx+C_TABLE_ROW_INDEX],0
 cmp qword ptr [rbx+C_TVERT],0
 je .M_table_body_start
 call .M_lf
.M_table_body_start:
 mov rax,[rbx+C_BODY_START]
 mov [rbx+C_TABLE_CURSOR],rax
.M_table_body_loop:
 mov rax,[rbx+C_TABLE_CURSOR]
 cmp rax,[rbx+C_TABLE_END]
 jae .M_table_yes
 call .M_peek
 mov [rbx+C_TABLE_CURSOR],rdx
 mov edx,1
 call .M_parse_cells
 cmp qword ptr [rbx+C_TVERT],0
 jne .M_table_render_fields
 mov edi,1
 call .M_table_render_row
 mov rax,[rbx+C_TABLE_CURSOR]
 cmp rax,[rbx+C_TABLE_END]
 jae .M_table_body_loop
 mov edi,1
 call .M_table_border
 jmp .M_table_body_loop
.M_table_render_fields:
 cmp qword ptr [rbx+C_TABLE_ROW_INDEX],0
 je .M_table_fields_ready
 PUT .m_dim
 mov r14,[rbx+C_COLS]
 dec r14
 cmp r14,40
 jbe .M_table_field_rule
 mov r14d,40
.M_table_field_rule:
 TEXT .m_rule
 dec r14
 jnz .M_table_field_rule
 PUT .m_reset
 call .M_lf
.M_table_fields_ready:
 inc qword ptr [rbx+C_TABLE_ROW_INDEX]
 xor r13d,r13d
.M_table_field:
 cmp r13,[rbx+C_NCOLS]
 jae .M_table_field_done
 mov rax,r13
 shl rax,4
 lea r14,[rbx+C_CELLS]
 add r14,rax
 PUT .m_bold
 PUT .m_link
 PUT .m_link_off
 mov rdi,[r14]
 mov rsi,[r14+8]
 call .M_render_inline
 TEXT .m_colon
 PUT .m_reset
 TEXT .m_space
 mov rdi,[r14+MD_TABLE_STRIDE]
 mov rsi,[r14+MD_TABLE_STRIDE+8]
 call .M_render_inline
 PUT .m_reset
 call .M_lf
 inc r13
 jmp .M_table_field
.M_table_field_done:
 jmp .M_table_body_loop
.M_table_yes:
 cmp qword ptr [rbx+C_TVERT],0
 jne .M_table_margin_end
 mov edi,2
 call .M_table_border
.M_table_margin_end:
 # The original marginY1 and a following Markdown blank form one blank row.
 # Preserve the input blank instead of adding a second identical margin.
 mov rax,[rbx+C_TABLE_END]
 cmp rax,[rbx+C_SIZE]
 jae .M_table_margin_emit
 call .M_peek
 test rsi,rsi
 jz .M_table_margin_supplied
.M_table_margin_emit:
 call .M_lf
.M_table_margin_supplied:
 mov rax,[rbx+C_TABLE_END]
 mov [rbx+C_OFFSET],rax
 mov eax,1
 jmp .M_table_return
.M_table_no:
 xor eax,eax
.M_table_return:
 add rsp,16
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

.M_table_border:
 push r12
 push r13
 push r14
 mov r12,rdi
 PUT .m_dim
 test r12,r12
 jz .M_border_top_left
 cmp r12,1
 je .M_border_mid_left
 TEXT .m_table_bottom_left
 jmp .M_border_columns
.M_border_top_left:
 TEXT .m_table_top_left
 jmp .M_border_columns
.M_border_mid_left:
 TEXT .m_table_border_left
.M_border_columns:
 xor r13d,r13d
.M_border_column:
 mov r14,[rbx+r13*8+C_WIDTHS]
 add r14,2
.M_border_dash:
 TEXT .m_rule
 dec r14
 jnz .M_border_dash
 inc r13
 cmp r13,[rbx+C_NCOLS]
 jae .M_border_right
 test r12,r12
 jz .M_border_top_mid
 cmp r12,1
 je .M_border_mid_mid
 TEXT .m_table_bottom_middle
 jmp .M_border_column
.M_border_top_mid:
 TEXT .m_table_top_middle
 jmp .M_border_column
.M_border_mid_mid:
 TEXT .m_table_border_middle
 jmp .M_border_column
.M_border_right:
 test r12,r12
 jz .M_border_top_right
 cmp r12,1
 je .M_border_mid_right
 TEXT .m_table_bottom_right
 jmp .M_border_done
.M_border_top_right:
 TEXT .m_table_top_right
 jmp .M_border_done
.M_border_mid_right:
 TEXT .m_table_border_right
.M_border_done:
 PUT .m_reset
 call .M_lf
 pop r14
 pop r13
 pop r12
 ret

.M_table_render_row:
 push r12
 push r13
 push r14
 mov qword ptr [rbx+C_TABLE_HEADER],0
 test rdi,rdi
 jnz .M_table_render_body_index
 mov qword ptr [rbx+C_TABLE_HEADER],1
.M_table_render_body_index:
 mov r12,rdi
 imul r12,r12,MD_TABLE_STRIDE
 lea rax,[rbx+C_CELLS]
 add r12,rax
 PUT .m_dim
 TEXT .m_table_left
 xor r13d,r13d
.M_table_render_cell:
 mov qword ptr [rbx+C_BASE_STYLE],0
 PUT .m_foreground
 cmp qword ptr [rbx+C_TABLE_HEADER],0
 je .M_table_render_cell_data
 mov qword ptr [rbx+C_BASE_STYLE],1
 PUT .m_bold
 PUT .m_link
 PUT .m_link_off
.M_table_render_cell_data:
 mov rdi,[r12]
 mov rsi,[r12+8]
 mov rdx,[rbx+r13*8+C_WIDTHS]
 mov r8,[rbx+r13*8+C_ALIGNS]
 call .M_table_cell
 PUT .m_reset
 PUT .m_dim
 inc r13
 add r12,16
 cmp r13,[rbx+C_NCOLS]
 jae .M_table_row_end
 TEXT .m_table_middle
 jmp .M_table_render_cell
.M_table_row_end:
 mov qword ptr [rbx+C_BASE_STYLE],0
 TEXT .m_table_right
 PUT .m_reset
 call .M_lf
 pop r14
 pop r13
 pop r12
 ret

.M_table_cell:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,16
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov [rsp],r8
 call .M_measure_inline
 mov rbp,r14
 sub rbp,rax
 mov r15,rbp
 cmp qword ptr [rsp],0
 jne .M_cell_align_nonleft
 xor r15d,r15d
 jmp .M_cell_align_ready
.M_cell_align_nonleft:
 cmp qword ptr [rsp],2
 jne .M_cell_align_ready
 shr r15,1
.M_cell_align_ready:
 sub rbp,r15
.M_cell_left_pad:
 test r15,r15
 jz .M_cell_content
 TEXT .m_space
 dec r15
 jmp .M_cell_left_pad
.M_cell_content:
 mov rdi,r12
 mov rsi,r13
 call .M_render_inline
.M_cell_right_pad:
 test rbp,rbp
 jz .M_cell_render_done
 TEXT .m_space
 dec rbp
 jmp .M_cell_right_pad
.M_cell_render_done:
 add rsp,16
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

.section .rodata
.m_lf: .ascii "\012"
.equ .m_lf_len,.-.m_lf
.m_reset: .ascii "\033[0m"
.equ .m_reset_len,.-.m_reset
.m_bold: .ascii "\033[1m"
.equ .m_bold_len,.-.m_bold
.m_bold_off: .ascii "\033[22m"
.equ .m_bold_off_len,.-.m_bold_off
.m_italic: .ascii "\033[3m"
.equ .m_italic_len,.-.m_italic
.m_italic_off: .ascii "\033[23m"
.equ .m_italic_off_len,.-.m_italic_off
.m_strike: .ascii "\033[9m"
.equ .m_strike_len,.-.m_strike
.m_strike_off: .ascii "\033[29m"
.equ .m_strike_off_len,.-.m_strike_off
.m_heading: .ascii "\033[1;38;2;137;180;250m"
.equ .m_heading_len,.-.m_heading
.m_dim: .ascii "\033[38;2;108;112;134m"
.equ .m_dim_len,.-.m_dim
.m_code: .ascii "\033[38;2;249;226;175m"
.equ .m_code_len,.-.m_code
.m_foreground: .ascii "\033[39m"
.equ .m_foreground_len,.-.m_foreground
.m_link: .ascii "\033[4;38;2;137;180;250m"
.equ .m_link_len,.-.m_link
.m_link_off: .ascii "\033[24m"
.equ .m_link_off_len,.-.m_link_off
.m_keyword_color: .ascii "\033[38;2;137;180;250m"
.equ .m_keyword_color_len,.-.m_keyword_color
.m_string_color: .ascii "\033[38;2;249;226;175m"
.equ .m_string_color_len,.-.m_string_color
.m_number_color: .ascii "\033[38;2;166;227;161m"
.equ .m_number_color_len,.-.m_number_color
.m_quote: .ascii "\342\224\202 "
.equ .m_quote_len,.-.m_quote
.m_bullet: .ascii "\342\200\242 "
.equ .m_bullet_len,.-.m_bullet
.m_rule: .ascii "\342\224\200"
.equ .m_rule_len,.-.m_rule
.m_code_open: .ascii ""
.equ .m_code_open_len,.-.m_code_open
.m_code_gutter: .ascii " \342\224\202 "
.equ .m_code_gutter_len,.-.m_code_gutter
.m_url_open: .ascii " ("
.equ .m_url_open_len,.-.m_url_open
.m_url_close: .ascii ")"
.equ .m_url_close_len,.-.m_url_close
.m_table_left: .ascii "\342\224\202 "
.equ .m_table_left_len,.-.m_table_left
.m_table_middle: .ascii " \342\224\202 "
.equ .m_table_middle_len,.-.m_table_middle
.m_table_right: .ascii " \342\224\202"
.equ .m_table_right_len,.-.m_table_right
.m_table_border_left: .ascii "\342\224\234"
.equ .m_table_border_left_len,.-.m_table_border_left
.m_table_border_middle: .ascii "\342\224\274"
.equ .m_table_border_middle_len,.-.m_table_border_middle
.m_table_border_right: .ascii "\342\224\244"
.equ .m_table_border_right_len,.-.m_table_border_right
.m_ellipsis: .ascii "\342\200\246"
.equ .m_ellipsis_len,.-.m_ellipsis
.m_space: .ascii " "
.equ .m_space_len,.-.m_space
.m_keywords:
 .asciz "if"
 .asciz "else"
 .asciz "elif"
 .asciz "for"
 .asciz "while"
 .asciz "do"
 .asciz "done"
 .asciz "switch"
 .asciz "case"
 .asciz "default"
 .asciz "break"
 .asciz "continue"
 .asciz "return"
 .asciz "yield"
 .asciz "def"
 .asciz "class"
 .asciz "function"
 .asciz "const"
 .asciz "let"
 .asciz "var"
 .asciz "import"
 .asciz "from"
 .asciz "as"
 .asciz "export"
 .asciz "async"
 .asciz "await"
 .asciz "try"
 .asciz "catch"
 .asciz "except"
 .asciz "finally"
 .asciz "raise"
 .asciz "throw"
 .asciz "new"
 .asciz "delete"
 .asciz "typeof"
 .asciz "instanceof"
 .asciz "in"
 .asciz "of"
 .asciz "is"
 .asciz "not"
 .asciz "and"
 .asciz "or"
 .asciz "pass"
 .asciz "with"
 .asciz "lambda"
 .asciz "func"
 .asciz "package"
 .asciz "struct"
 .asciz "interface"
 .asciz "type"
 .asciz "range"
 .asciz "go"
 .asciz "defer"
 .asciz "select"
 .asciz "map"
 .asciz "chan"
 .asciz "int"
 .asciz "string"
 .asciz "bool"
 .asciz "void"
 .asciz "static"
 .asciz "public"
 .asciz "private"
 .asciz "protected"
 .asciz "final"
 .asciz "this"
 .asciz "self"
 .asciz "super"
 .asciz "extends"
 .asciz "implements"
 .asciz "enum"
 .asciz "match"
 .asciz "fn"
 .asciz "pub"
 .asciz "impl"
 .asciz "use"
 .asciz "mod"
 .asciz "mut"
 .asciz "ref"
 .asciz "move"
 .asciz "unsafe"
 .asciz "where"
 .asciz "then"
 .asciz "fi"
 .asciz "esac"
 .asciz "local"
 .asciz "readonly"
 .byte 0
.section .note.GNU-stack,"",@progbits

.section .rodata
.balign 8
.include "ui_formatter_palettes.inc"
.m_field_separator: .ascii ": "
.equ .m_field_separator_len,.-.m_field_separator
.m_hr: .ascii "---"
.equ .m_hr_len,.-.m_hr
.m_checked: .byte 0xe2,0x9c,0x93,32
.equ .m_checked_len,.-.m_checked
.m_unchecked: .byte 0xe2,0x97,0x8b,32
.equ .m_unchecked_len,.-.m_unchecked

.text
# Display-math is the same textual LaTeX presentation as Qwen's RenderMathBlock:
# source-copy label, then joined/simplified inline expression; no invented CAS.
.M_math_block:
 push r12
 push r13
 push r14
 mov r12,[rbx+C_LINE]
 mov r13,[rbx+C_LLEN]
 xor r14d,r14d
.M_math_block_trim:
 cmp r14,r13
 jae .M_math_block_body
 cmp byte ptr [r12+r14],' '
 jne .M_math_block_tail
 inc r14
 jmp .M_math_block_trim
.M_math_block_tail:
 cmp r13,r14
 jbe .M_math_block_body
 cmp byte ptr [r12+r13-1],' '
 jne .M_math_block_fence
 dec r13
 jmp .M_math_block_tail
.M_math_block_fence:
 mov rax,r13
 sub rax,r14
 cmp rax,2
 jne .M_math_block_body
 cmp word ptr [r12+r14],0x2424
 jne .M_math_block_body
 cmp qword ptr [rbx+C_MATH],0
 jne .M_math_block_close
 mov qword ptr [rbx+C_MATH],1
 inc qword ptr [rbx+C_MATH_INDEX]
 TEXT .m_space
 PUT .m_bold
 PUT .m_math_color
 TEXT .m_math_label
 mov rdi,[rbx+C_MATH_INDEX]
 call .M_number
 PUT .m_reset
 call .M_lf
 mov eax,1
 jmp .M_math_block_return
.M_math_block_close:
 PUT .m_reset
 cmp qword ptr [rbx+C_COL],0
 je .M_math_block_closed
 call .M_lf
.M_math_block_closed:
 mov qword ptr [rbx+C_MATH],0
 mov eax,1
 jmp .M_math_block_return
.M_math_block_body:
 cmp qword ptr [rbx+C_MATH],0
 je .M_math_block_no
 mov qword ptr [rbx+C_INDENT],1
 cmp qword ptr [rbx+C_COL],0
 jne .M_math_block_join
 TEXT .m_space
 jmp .M_math_block_expr
.M_math_block_join:
 TEXT .m_space
.M_math_block_expr:
 PUT .m_math_color
 mov rdi,[rbx+C_LINE]
 mov rsi,[rbx+C_LLEN]
 xor edx,edx
 call .M_math
 mov eax,1
 jmp .M_math_block_return
.M_math_block_no:
 xor eax,eax
.M_math_block_return:
 pop r14
 pop r13
 pop r12
 ret

# ptr,end ->group content pointer RAX,length RDX,next pointer RCX; RAX0 missing.
.M_math_group:
 xor eax,eax
 cmp rdi,rsi
 jae .M_math_group_done
 cmp byte ptr [rdi],'{'
 jne .M_math_group_done
 lea r8,[rdi+1]
 mov rcx,r8
 mov r9d,1
.M_math_group_scan:
 cmp qword ptr [rbx+C_MATH_BUDGET],0
 je .M_math_group_fail
 dec qword ptr [rbx+C_MATH_BUDGET]
 cmp rcx,rsi
 jae .M_math_group_fail
 mov dl,[rcx]
 inc rcx
 cmp dl,'\\'
 jne .M_math_group_brace
 cmp rcx,rsi
 jae .M_math_group_fail
 inc rcx
 jmp .M_math_group_scan
.M_math_group_brace:
 cmp dl,'{'
 jne .M_math_group_close
 inc r9
 jmp .M_math_group_scan
.M_math_group_close:
 cmp dl,'}'
 jne .M_math_group_scan
 dec r9
 jnz .M_math_group_scan
 mov rax,r8
 mov rdx,rcx
 sub rdx,r8
 dec rdx
 ret
.M_math_group_fail:
 xor eax,eax
.M_math_group_done:
 ret

# Exact source-backed command map, longest first, bounded at45 records.
.M_math_command:
 lea r8,[rip+.m_math_commands]
 lea r9,[rip+.m_math_data]
.M_math_cmd_next:
 mov r10d,[r8+4]
 test r10d,r10d
 jz .M_math_cmd_missing
 cmp r10,rsi
 ja .M_math_cmd_advance
 movsxd r11,dword ptr [r8]
 add r11,r9
 xor ecx,ecx
.M_math_cmd_compare:
 cmp rcx,r10
 jae .M_math_cmd_found
 mov al,[r11+rcx]
 cmp al,[rdi+rcx]
 jne .M_math_cmd_advance
 inc rcx
 jmp .M_math_cmd_compare
.M_math_cmd_advance:
 add r8,16
 jmp .M_math_cmd_next
.M_math_cmd_found:
 movsxd rax,dword ptr [r8+8]
 add rax,r9
 mov edx,[r8+12]
 mov rcx,r10
 ret
.M_math_cmd_missing:
 xor eax,eax
 ret

# ptr,len,depth ->emit. The depth10 bound matches the original latexRenderer.
.M_math:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,64
 mov r12,rdi
 mov r13,rsi
 mov r15,rdx
 xor r14d,r14d
 xor ebp,ebp
 mov qword ptr [rsp+40],0
 cmp r15,10
 jbe .M_math_loop
 call .M_text
 jmp .M_math_return
.M_math_loop:
 cmp r14,r13
 jae .M_math_return
 mov al,[r12+r14]
 cmp al,32
 jbe .M_math_space
 cmp qword ptr [rsp+40],0
 je .M_math_dispatch
 test rbp,rbp
 jz .M_math_dispatch
 TEXT .m_space
.M_math_dispatch:
 mov qword ptr [rsp+40],0
 mov al,[r12+r14]
 cmp al,'\\'
 je .M_math_slash
 cmp al,'^'
 je .M_math_script
 cmp al,'_'
 je .M_math_script
 jmp .M_math_plain
.M_math_space:
 mov qword ptr [rsp+40],1
 inc r14
 jmp .M_math_loop
.M_math_slash:
 mov rax,r13
 sub rax,r14
 cmp rax,2
 jb .M_math_plain
 cmp byte ptr [r12+r14+1],','
 jne .M_math_fraction_probe
 add r14,2
 mov qword ptr [rsp+40],1
 jmp .M_math_loop
.M_math_fraction_probe:
 cmp rax,6
 jb .M_math_map
 cmp dword ptr [r12+r14+1],0x63617266
 je .M_math_fraction
 cmp dword ptr [r12+r14+1],0x74727173
 je .M_math_sqrt
 jmp .M_math_map
.M_math_fraction:
 lea rdi,[r12+r14+5]
 lea rsi,[r12+r13]
 call .M_math_group
 test rax,rax
 jz .M_math_map
 mov [rsp],rax
 mov [rsp+8],rdx
 mov rdi,rcx
 lea rsi,[r12+r13]
 call .M_math_group
 test rax,rax
 jz .M_math_map
 mov [rsp+16],rax
 mov [rsp+24],rdx
 mov [rsp+32],rcx
 mov rdi,[rsp]
 mov rsi,[rsp+8]
 lea rdx,[r15+1]
 call .M_math
 TEXT .m_divide
 mov rdi,[rsp+16]
 mov rsi,[rsp+24]
 lea rdx,[r15+1]
 call .M_math
 mov r14,[rsp+32]
 sub r14,r12
 mov ebp,1
 jmp .M_math_loop
.M_math_sqrt:
 lea rdi,[r12+r14+5]
 lea rsi,[r12+r13]
 call .M_math_group
 test rax,rax
 jz .M_math_map
 mov [rsp],rax
 mov [rsp+8],rdx
 mov [rsp+32],rcx
 TEXT .m_sqrt_open
 mov rdi,[rsp]
 mov rsi,[rsp+8]
 lea rdx,[r15+1]
 call .M_math
 TEXT .m_url_close
 mov r14,[rsp+32]
 sub r14,r12
 mov ebp,1
 jmp .M_math_loop
.M_math_map:
 lea rdi,[r12+r14]
 mov rsi,r13
 sub rsi,r14
 call .M_math_command
 test rax,rax
 jz .M_math_plain
 mov [rsp+48],rcx
 test rdx,rdx
 jz .M_math_map_empty
 mov rdi,rax
 mov rsi,rdx
 call .M_text
 mov ebp,1
.M_math_map_empty:
 add r14,[rsp+48]
 jmp .M_math_loop
.M_math_script:
 mov [rsp+56],al
 lea rax,[r14+1]
 cmp rax,r13
 jae .M_math_plain
 cmp byte ptr [r12+r14+1],'{'
 jne .M_math_script_single
 lea rdi,[r12+r14+1]
 lea rsi,[r12+r13]
 call .M_math_group
 test rax,rax
 jz .M_math_plain
 mov [rsp+32],rcx
 mov [rsp],rax
 mov [rsp+8],rdx
 xor ecx,ecx
.M_math_script_nested:
 cmp rcx,rdx
 jae .M_math_script_begin
 cmp byte ptr [rax+rcx],'{'
 je .M_math_plain
 cmp byte ptr [rax+rcx],'}'
 je .M_math_plain
 inc rcx
 jmp .M_math_script_nested
.M_math_script_single:
 lea rax,[r12+r14+1]
 movzx edx,byte ptr [rax]
 mov [rsp],rax
 mov qword ptr [rsp+8],1
 lea rcx,[rax+1]
 mov [rsp+32],rcx
 # The original single form only accepts ASCII alphanumeric,+,-,=,(,).
 mov eax,edx
 call .M_ascii_word
 test eax,eax
 jnz .M_math_script_begin
 cmp dl,'+'
 je .M_math_script_begin
 cmp dl,'-'
 je .M_math_script_begin
 cmp dl,'='
 je .M_math_script_begin
 cmp dl,'('
 je .M_math_script_begin
 cmp dl,')'
 jne .M_math_plain
.M_math_script_begin:
 mov qword ptr [rsp+48],0
.M_math_script_each:
 mov rcx,[rsp+48]
 cmp rcx,[rsp+8]
 jae .M_math_script_done
 mov rax,[rsp]
 movzx edx,byte ptr [rax+rcx]
 cmp edx,128
 jae .M_math_script_unicode
 lea r8,[rip+.m_superscripts]
 cmp byte ptr [rsp+56],'^'
 je .M_math_script_table
 lea r8,[rip+.m_subscripts]
.M_math_script_table:
 lea r8,[r8+rdx*8]
 cmp dword ptr [r8+4],0
 je .M_math_script_literal
 mov rdi,r8
 mov esi,[r8+4]
 call .M_text
 jmp .M_math_script_advance
.M_math_script_literal:
 lea rdi,[rax+rcx]
 mov esi,1
 call .M_text
 jmp .M_math_script_advance
.M_math_script_unicode:
 mov rdi,[rsp]
 mov rsi,[rsp+8]
 mov rdx,rcx
 call ui_next_grapheme
 mov rdx,rax
 sub rdx,[rsp+48]
 mov rdi,[rsp]
 add rdi,[rsp+48]
 mov rsi,rdx
 mov [rsp+48],rax
 call .M_text
 jmp .M_math_script_each
.M_math_script_advance:
 inc qword ptr [rsp+48]
 jmp .M_math_script_each
.M_math_script_done:
 mov r14,[rsp+32]
 sub r14,r12
 mov ebp,1
 jmp .M_math_loop
.M_math_plain:
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov [rsp+48],rax
 lea rdi,[r12+r14]
 mov rsi,rax
 sub rsi,r14
 call .M_text
 mov r14,[rsp+48]
 mov ebp,1
 jmp .M_math_loop
.M_math_return:
 add rsp,64
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

.section .rodata
.m_image_open: .ascii "[Image: "
.equ .m_image_open_len,.-.m_image_open
.m_image_close: .ascii "]"
.equ .m_image_close_len,.-.m_image_close
.m_math_label: .byte 76,97,84,101,88,32,98,108,111,99,107,32,194,183,32,115,111,117,114,99,101,58,32,47,99,111,112,121,32,108,97,116,101,120,32
.equ .m_math_label_len,.-.m_math_label
.m_divide: .byte 47
.equ .m_divide_len,.-.m_divide
.m_sqrt_open: .byte 226,136,154,40
.equ .m_sqrt_open_len,.-.m_sqrt_open
.balign 8
.m_math_commands:
 .long .m_math_key0-.m_math_data,11,.m_math_val0-.m_math_data,2
 .long .m_math_key1-.m_math_data,11,.m_math_val1-.m_math_data,3
 .long .m_math_key2-.m_math_data,11,.m_math_val2-.m_math_data,3
 .long .m_math_key3-.m_math_data,10,.m_math_val3-.m_math_data,3
 .long .m_math_key4-.m_math_data,10,.m_math_val4-.m_math_data,3
 .long .m_math_key5-.m_math_data,8,.m_math_val5-.m_math_data,2
 .long .m_math_key6-.m_math_data,8,.m_math_val6-.m_math_data,3
 .long .m_math_key7-.m_math_data,7,.m_math_val7-.m_math_data,2
 .long .m_math_key8-.m_math_data,7,.m_math_val8-.m_math_data,2
 .long .m_math_key9-.m_math_data,7,.m_math_val9-.m_math_data,2
 .long .m_math_key10-.m_math_data,7,.m_math_val10-.m_math_data,3
 .long .m_math_key11-.m_math_data,7,.m_math_val11-.m_math_data,0
 .long .m_math_key12-.m_math_data,6,.m_math_val12-.m_math_data,2
 .long .m_math_key13-.m_math_data,6,.m_math_val13-.m_math_data,2
 .long .m_math_key14-.m_math_data,6,.m_math_val14-.m_math_data,2
 .long .m_math_key15-.m_math_data,6,.m_math_val15-.m_math_data,2
 .long .m_math_key16-.m_math_data,6,.m_math_val16-.m_math_data,2
 .long .m_math_key17-.m_math_data,6,.m_math_val17-.m_math_data,2
 .long .m_math_key18-.m_math_data,6,.m_math_val18-.m_math_data,2
 .long .m_math_key19-.m_math_data,6,.m_math_val19-.m_math_data,2
 .long .m_math_key20-.m_math_data,6,.m_math_val20-.m_math_data,2
 .long .m_math_key21-.m_math_data,6,.m_math_val21-.m_math_data,2
 .long .m_math_key22-.m_math_data,6,.m_math_val22-.m_math_data,2
 .long .m_math_key23-.m_math_data,6,.m_math_val23-.m_math_data,3
 .long .m_math_key24-.m_math_data,6,.m_math_val24-.m_math_data,2
 .long .m_math_key25-.m_math_data,6,.m_math_val25-.m_math_data,0
 .long .m_math_key26-.m_math_data,6,.m_math_val26-.m_math_data,0
 .long .m_math_key27-.m_math_data,5,.m_math_val27-.m_math_data,2
 .long .m_math_key28-.m_math_data,5,.m_math_val28-.m_math_data,3
 .long .m_math_key29-.m_math_data,5,.m_math_val29-.m_math_data,3
 .long .m_math_key30-.m_math_data,5,.m_math_val30-.m_math_data,2
 .long .m_math_key31-.m_math_data,5,.m_math_val31-.m_math_data,0
 .long .m_math_key32-.m_math_data,4,.m_math_val32-.m_math_data,2
 .long .m_math_key33-.m_math_data,4,.m_math_val33-.m_math_data,2
 .long .m_math_key34-.m_math_data,4,.m_math_val34-.m_math_data,2
 .long .m_math_key35-.m_math_data,4,.m_math_val35-.m_math_data,2
 .long .m_math_key36-.m_math_data,4,.m_math_val36-.m_math_data,2
 .long .m_math_key37-.m_math_data,4,.m_math_val37-.m_math_data,3
 .long .m_math_key38-.m_math_data,4,.m_math_val38-.m_math_data,3
 .long .m_math_key39-.m_math_data,4,.m_math_val39-.m_math_data,3
 .long .m_math_key40-.m_math_data,4,.m_math_val40-.m_math_data,3
 .long .m_math_key41-.m_math_data,3,.m_math_val41-.m_math_data,2
 .long .m_math_key42-.m_math_data,3,.m_math_val42-.m_math_data,2
 .long .m_math_key43-.m_math_data,3,.m_math_val43-.m_math_data,2
 .long .m_math_key44-.m_math_data,3,.m_math_val44-.m_math_data,2
 .long .m_math_key45-.m_math_data,3,.m_math_val45-.m_math_data,3
 .long 0,0,0,0
.m_math_data:
.m_math_key0: .byte 92,118,97,114,101,112,115,105,108,111,110
.m_math_val0: .byte 206,181
.m_math_key1: .byte 92,114,105,103,104,116,97,114,114,111,119
.m_math_val1: .byte 226,134,146
.m_math_key2: .byte 92,82,105,103,104,116,97,114,114,111,119
.m_math_val2: .byte 226,135,146
.m_math_key3: .byte 92,108,101,102,116,97,114,114,111,119
.m_math_val3: .byte 226,134,144
.m_math_key4: .byte 92,76,101,102,116,97,114,114,111,119
.m_math_val4: .byte 226,135,144
.m_math_key5: .byte 92,101,112,115,105,108,111,110
.m_math_val5: .byte 206,181
.m_math_key6: .byte 92,112,97,114,116,105,97,108
.m_math_val6: .byte 226,136,130
.m_math_key7: .byte 92,108,97,109,98,100,97
.m_math_val7: .byte 206,187
.m_math_key8: .byte 92,118,97,114,112,104,105
.m_math_val8: .byte 207,134
.m_math_key9: .byte 92,76,97,109,98,100,97
.m_math_val9: .byte 206,155
.m_math_key10: .byte 92,97,112,112,114,111,120
.m_math_val10: .byte 226,137,136
.m_math_key11: .byte 92,114,105,103,104,116,46
.m_math_val11: .byte 0
.m_math_key12: .byte 92,97,108,112,104,97
.m_math_val12: .byte 206,177
.m_math_key13: .byte 92,103,97,109,109,97
.m_math_val13: .byte 206,179
.m_math_key14: .byte 92,100,101,108,116,97
.m_math_val14: .byte 206,180
.m_math_key15: .byte 92,116,104,101,116,97
.m_math_val15: .byte 206,184
.m_math_key16: .byte 92,115,105,103,109,97
.m_math_val16: .byte 207,131
.m_math_key17: .byte 92,111,109,101,103,97
.m_math_val17: .byte 207,137
.m_math_key18: .byte 92,71,97,109,109,97
.m_math_val18: .byte 206,147
.m_math_key19: .byte 92,68,101,108,116,97
.m_math_val19: .byte 206,148
.m_math_key20: .byte 92,84,104,101,116,97
.m_math_val20: .byte 206,152
.m_math_key21: .byte 92,83,105,103,109,97
.m_math_val21: .byte 206,163
.m_math_key22: .byte 92,79,109,101,103,97
.m_math_val22: .byte 206,169
.m_math_key23: .byte 92,105,110,102,116,121
.m_math_val23: .byte 226,136,158
.m_math_key24: .byte 92,116,105,109,101,115
.m_math_val24: .byte 195,151
.m_math_key25: .byte 92,108,101,102,116,46
.m_math_val25: .byte 0
.m_math_key26: .byte 92,114,105,103,104,116
.m_math_val26: .byte 0
.m_math_key27: .byte 92,98,101,116,97
.m_math_val27: .byte 206,178
.m_math_key28: .byte 92,112,114,111,100
.m_math_val28: .byte 226,136,143
.m_math_key29: .byte 92,115,113,114,116
.m_math_val29: .byte 226,136,154
.m_math_key30: .byte 92,99,100,111,116
.m_math_val30: .byte 194,183
.m_math_key31: .byte 92,108,101,102,116
.m_math_val31: .byte 0
.m_math_key32: .byte 92,114,104,111
.m_math_val32: .byte 207,129
.m_math_key33: .byte 92,116,97,117
.m_math_val33: .byte 207,132
.m_math_key34: .byte 92,112,104,105
.m_math_val34: .byte 207,134
.m_math_key35: .byte 92,80,104,105
.m_math_val35: .byte 206,166
.m_math_key36: .byte 92,115,117,109
.m_math_val36: .byte 206,163
.m_math_key37: .byte 92,105,110,116
.m_math_val37: .byte 226,136,171
.m_math_key38: .byte 92,108,101,113
.m_math_val38: .byte 226,137,164
.m_math_key39: .byte 92,103,101,113
.m_math_val39: .byte 226,137,165
.m_math_key40: .byte 92,110,101,113
.m_math_val40: .byte 226,137,160
.m_math_key41: .byte 92,109,117
.m_math_val41: .byte 206,188
.m_math_key42: .byte 92,112,105
.m_math_val42: .byte 207,128
.m_math_key43: .byte 92,80,105
.m_math_val43: .byte 206,160
.m_math_key44: .byte 92,112,109
.m_math_val44: .byte 194,177
.m_math_key45: .byte 92,116,111
.m_math_val45: .byte 226,134,146
.balign 8
.m_superscripts:
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 12419554,3
 .long 12485090,3
 .long 0,0
 .long 12222946,3
 .long 0,0
 .long 12288482,3
 .long 0,0
 .long 0,0
 .long 11567586,3
 .long 47554,2
 .long 45762,2
 .long 46018,2
 .long 11829730,3
 .long 11895266,3
 .long 11960802,3
 .long 12026338,3
 .long 12091874,3
 .long 12157410,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 12354018,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 11633122,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 12550626,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
.balign 8
.m_subscripts:
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 9274082,3
 .long 9339618,3
 .long 0,0
 .long 9077474,3
 .long 0,0
 .long 9143010,3
 .long 0,0
 .long 0,0
 .long 8422114,3
 .long 8487650,3
 .long 8553186,3
 .long 8618722,3
 .long 8684258,3
 .long 8749794,3
 .long 8815330,3
 .long 8880866,3
 .long 8946402,3
 .long 9011938,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 9208546,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 9470690,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 9536226,3
 .long 0,0
 .long 0,0
 .long 9798370,3
 .long 10663393,3
 .long 12366306,3
 .long 9863906,3
 .long 9929442,3
 .long 9994978,3
 .long 10060514,3
 .long 9601762,3
 .long 10126050,3
 .long 0,0
 .long 10728929,3
 .long 10191586,3
 .long 10257122,3
 .long 10794465,3
 .long 10860001,3
 .long 0,0
 .long 9667298,3
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0
 .long 0,0

.section .rodata
.m_literals:
 .asciz "None"
 .asciz "True"
 .asciz "False"
 .asciz "null"
 .asciz "true"
 .asciz "false"
 .asciz "nil"
 .byte 0

.section .rodata
.m_table_top_left: .byte 226,148,140
.equ .m_table_top_left_len,.-.m_table_top_left
.m_table_top_middle: .byte 226,148,172
.equ .m_table_top_middle_len,.-.m_table_top_middle
.m_table_top_right: .byte 226,148,144
.equ .m_table_top_right_len,.-.m_table_top_right
.m_table_bottom_left: .byte 226,148,148
.equ .m_table_bottom_left_len,.-.m_table_bottom_left
.m_table_bottom_middle: .byte 226,148,180
.equ .m_table_bottom_middle_len,.-.m_table_bottom_middle
.m_table_bottom_right: .byte 226,148,152
.equ .m_table_bottom_right_len,.-.m_table_bottom_right
.m_colon: .byte 58
.equ .m_colon_len,.-.m_colon

.text
.globl ui_math_count,ui_extract_math
# Count display-math blocks exactly once on opening. A partially streamed block
# counts too, matching the displayed /copy label. Fenced code is excluded.
ui_math_count:
 xor r9d,r9d
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 jmp .X_entry
# source,length,index1,out,capacity ->source byte length or -1/-22/-28.
# Only line-delimited $$ blocks are numbered; inline dollars are not blocks.
ui_extract_math:
 xor r9d,r9d
 test rdx,rdx
 jz .X_invalid_leaf
 jmp .X_entry
.globl ui_mermaid_count,ui_extract_mermaid
ui_mermaid_count:
 mov r9d,1
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 jmp .X_entry
ui_extract_mermaid:
 mov r9d,1
 test rdx,rdx
 jz .X_invalid_leaf
.X_entry:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,72
 mov rbx,rsp
 mov [rbx],rcx
 mov [rbx+8],r8
 mov [rbx+16],rdx
 mov [rbx+56],r9
 mov qword ptr [rbx+24],0
 mov qword ptr [rbx+32],0
 mov qword ptr [rbx+64],0
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 xor r15d,r15d
 xor ebp,ebp
 cmp r13,1048576
 ja .X_invalid
 test r13,r13
 jz .X_eof
 test r12,r12
 jz .X_invalid
.X_line:
 cmp r14,r13
 jae .X_eof
 mov [rbx+40],r14
 mov rcx,r14
.X_scan:
 cmp rcx,r13
 jae .X_endline
 cmp byte ptr [r12+rcx],10
 je .X_has_lf
 inc rcx
 jmp .X_scan
.X_has_lf:
 lea r14,[rcx+1]
 jmp .X_line_bounds
.X_endline:
 mov r14,rcx
.X_line_bounds:
 mov [rbx+48],rcx
 mov rdi,[rbx+40]
 mov rsi,rcx
.X_trim_left:
 cmp rdi,rsi
 jae .X_line
 mov al,[r12+rdi]
 cmp al,' '
 je .X_left_advance
 cmp al,9
 jne .X_trim_right
.X_left_advance:
 inc rdi
 jmp .X_trim_left
.X_trim_right:
 cmp rsi,rdi
 jbe .X_line
 mov al,[r12+rsi-1]
 cmp al,' '
 je .X_right_advance
 cmp al,9
 je .X_right_advance
 cmp al,13
 jne .X_classify
.X_right_advance:
 dec rsi
 jmp .X_trim_right
.X_classify:
 cmp qword ptr [rbx+64],2
 je .X_mermaid_inside
 cmp qword ptr [rbx+64],0
 jne .X_math_inside
 # A fenced literal body cannot open a math block.
 mov al,[r12+rdi]
 cmp al,'`'
 je .X_fence
 cmp al,'~'
 je .X_fence
 test rbp,rbp
 jnz .X_line
 cmp qword ptr [rbx+56],1
 je .X_line
 mov rax,rsi
 sub rax,rdi
 cmp rax,2
 jne .X_line
 cmp word ptr [r12+rdi],0x2424
 jne .X_line
 inc r15
 mov qword ptr [rbx+64],1
 mov [rbx+24],r14
 jmp .X_line
.X_fence:
 movzx r9d,al
 mov rcx,rdi
.X_fence_run:
 cmp rcx,rsi
 jae .X_fence_count
 cmp byte ptr [r12+rcx],r9b
 jne .X_fence_count
 inc rcx
 jmp .X_fence_run
.X_fence_count:
 sub rcx,rdi
 cmp rcx,3
 jb .X_line
 test rbp,rbp
 jnz .X_fence_close
 mov rbp,r9
 mov [rbx+32],rcx
 cmp qword ptr [rbx+56],1
 jne .X_line
 add rcx,rdi
.X_mermaid_lang_space:
 cmp rcx,rsi
 jae .X_line
 cmp byte ptr [r12+rcx],' '
 je .X_mermaid_space_advance
 cmp byte ptr [r12+rcx],9
 jne .X_mermaid_lang
.X_mermaid_space_advance:
 inc rcx
 jmp .X_mermaid_lang_space
.X_mermaid_lang:
 lea rax,[rcx+7]
 cmp rax,rsi
 ja .X_line
 mov r8,rcx
 lea r10,[rip+.m_mermaid_lang]
 xor r11d,r11d
.X_mermaid_lang_compare:
 cmp r11d,7
 jae .X_mermaid_lang_after
 mov al,[r12+r8]
 or al,32
 cmp al,[r10+r11]
 jne .X_line
 inc r8
 inc r11
 jmp .X_mermaid_lang_compare
.X_mermaid_lang_after:
 cmp r8,rsi
 jae .X_mermaid_open
 cmp byte ptr [r12+r8],' '
 je .X_mermaid_open
 cmp byte ptr [r12+r8],9
 jne .X_line
.X_mermaid_open:
 inc r15
 mov qword ptr [rbx+64],2
 mov [rbx+24],r14
 jmp .X_line
.X_fence_close:
 cmp rbp,r9
 jne .X_line
 cmp rcx,[rbx+32]
 jb .X_line
 add rcx,rdi
.X_fence_tail:
 cmp rcx,rsi
 jae .X_fence_closed
 cmp byte ptr [r12+rcx],' '
 jne .X_line
 inc rcx
 jmp .X_fence_tail
.X_fence_closed:
 xor ebp,ebp
 cmp qword ptr [rbx+64],2
 jne .X_line
 mov qword ptr [rbx+64],0
 mov rax,[rbx+16]
 test rax,rax
 jz .X_line
 cmp rax,r15
 jne .X_line
 mov rdx,[rbx+40]
 jmp .X_copy
.X_mermaid_inside:
 mov al,[r12+rdi]
 cmp al,bpl
 jne .X_line
 jmp .X_fence
.X_math_inside:
 mov rax,rsi
 sub rax,rdi
 cmp rax,2
 jne .X_line
 cmp word ptr [r12+rdi],0x2424
 jne .X_line
 mov qword ptr [rbx+64],0
 mov rax,[rbx+16]
 test rax,rax
 jz .X_line
 cmp rax,r15
 jne .X_line
 mov rdx,[rbx+40]
 jmp .X_copy
.X_eof:
 cmp qword ptr [rbx+16],0
 je .X_count_done
 cmp qword ptr [rbx+64],0
 je .X_missing
 cmp r15,[rbx+16]
 jne .X_missing
 mov rdx,r13
.X_copy:
 mov rsi,[rbx+24]
 sub rdx,rsi
 # Opening/closing marker lines are excluded; preserve exact intervening bytes.
 cmp rdx,[rbx+8]
 ja .X_capacity
 mov rdi,[rbx]
 test rdx,rdx
 jz .X_empty
 test rdi,rdi
 jz .X_invalid
 mov rax,rdx
 mov rcx,rdx
 add rsi,r12
 rep movsb
 jmp .X_return
.X_empty:
 xor eax,eax
 jmp .X_return
.X_count_done:
 mov rax,r15
 jmp .X_return
.X_missing:
 mov rax,-1
 jmp .X_return
.X_capacity:
 mov rax,-28
 jmp .X_return
.X_invalid:
 mov rax,-22
.X_return:
 add rsp,72
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.X_invalid_leaf:
 mov rax,-22
 ret

.section .rodata
.m_mermaid_lang: .ascii "mermaid"
.equ .m_mermaid_lang_len,.-.m_mermaid_lang
.m_mermaid_limit: .ascii "Mermaid source (preview limit) \302\267 source: /copy mermaid "
.equ .m_mermaid_limit_len,.-.m_mermaid_limit
.m_mermaid_pending: .ascii "Mermaid diagram is being written..."
.equ .m_mermaid_pending_len,.-.m_mermaid_pending
