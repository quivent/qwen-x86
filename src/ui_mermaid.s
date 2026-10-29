# Native Mermaid terminal preview. Supported subset follows Qwen0.24.5's
# mermaidVisualRenderer; unsupported constructs remain explicit source fallback.
.intel_syntax noprefix
.equ R_MAX,131072
.equ R_NODES,160
.equ R_EDGES,160
.equ R_EDGE_SIZE,512
.equ R_LINES_MAX,160
.equ R_WIDTH_MAX,512
.equ R_HEIGHT_MAX,80
.equ R_NODE_SIZE,768
.equ N_LINES,112
.equ N_LABEL_LINES,640
.equ N_ID,0
.equ N_IDLEN,8
.equ N_LLEN,16
.equ N_SHAPE,24
.equ N_RANK,32
.equ N_X,40
.equ N_Y,48
.equ N_W,56
.equ N_H,64
.equ N_CX,72
.equ N_CY,80
.equ N_INCOMING,88
.equ N_EXPLICIT,96
.equ N_PREF,104
.equ N_LABEL,128
.equ R_OUT,0
.equ R_CAP,8
.equ R_LEN,16
.equ R_ERR,24
.equ R_SRC,32
.equ R_SIZE,40
.equ R_COLS,48
.equ R_THEME,56
.equ R_INDEX,64
.equ R_NLINES,72
.equ R_NCOUNT,80
.equ R_ECOUNT,88
.equ R_KIND,96
.equ R_DIR,104
.equ R_MSGCOUNT,112
.equ R_RELCOUNT,120
.equ R_MEMBERCOUNT,128
.equ R_CURRENT_CLASS,136
.equ R_WARNING,144
.equ R_LINEPTR,152
.equ R_LINELEN,160
.equ R_SCAN,168
.equ R_FROM,176
.equ R_TO,184
.equ R_OP,192
.equ R_AFTER,200
.equ R_LABELPTR,208
.equ R_LABELLEN,216
.equ R_NEXTOP,224
.equ R_CWIDTH,232
.equ R_CHEIGHT,240
.equ R_HORIZONTAL,248
.equ R_RANKS,256
.equ R_MAXRANK,264
.equ R_NUMBER,288
.equ R_TEMP,320
.equ R_PARTS,512
.equ R_SOURCE,R_PARTS+R_LINES_MAX*16
.equ R_NODEBUF,R_SOURCE+R_MAX*4
.equ R_EDGEBUF,R_NODEBUF+R_NODES*R_NODE_SIZE
.equ R_MSGBUF,R_EDGEBUF+R_EDGES*R_EDGE_SIZE
.equ R_RELBUF,R_MSGBUF+80*2048
.equ R_MEMBERBUF,R_RELBUF+80*64
.equ R_QUEUE,R_MEMBERBUF+80*32
.equ R_LAYER,R_QUEUE+R_NODES*8
.equ R_TEXTBUF,R_LAYER+R_NODES*8
.equ R_TLEN,352
.equ R_CANVAS,R_TEXTBUF+65536
.equ R_FRAME,((R_CANVAS+R_WIDTH_MAX*R_HEIGHT_MAX*16+15)/16)*16+8
.macro RE
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,R_FRAME
 mov rbx,rsp
.endm
.macro RL
 add rsp,R_FRAME
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.endm
.macro RC label
 lea rdi,[rip+\label]
 mov esi,OFFSET FLAT:\label\()_len
 call .R_put
.endm
.macro RLINE label
 lea rdi,[rip+\label]
 mov esi,OFFSET FLAT:\label\()_len
 call .R_line
.endm
.text
.globl ui_render_mermaid
# raw,len,out,cap,cols,theme,index7 ->length/-err. No runtime/parser allocation.
ui_render_mermaid:
 mov r10,[rsp+8]
 RE
 mov [rbx+R_OUT],rdx
 mov [rbx+R_CAP],rcx
 mov [rbx+R_INDEX],r10
 cmp r9,OFFSET FLAT:UI_THEME_PALETTE_COUNT
 jb .R_theme_valid
 xor r9d,r9d
.R_theme_valid:
 imul r9,r9,48
 lea rax,[rip+.r_palettes]
 add rax,r9
 mov [rbx+R_THEME],rax
 mov qword ptr [rbx+R_LEN],0
 mov qword ptr [rbx+R_ERR],0
 mov qword ptr [rbx+R_NLINES],0
 mov qword ptr [rbx+R_NCOUNT],0
 mov qword ptr [rbx+R_ECOUNT],0
 mov qword ptr [rbx+R_MSGCOUNT],0
 mov qword ptr [rbx+R_RELCOUNT],0
 mov qword ptr [rbx+R_MEMBERCOUNT],0
 mov qword ptr [rbx+R_CURRENT_CLASS],-1
 mov qword ptr [rbx+R_WARNING],0
 cmp rsi,R_MAX
 ja .R_invalid
 cmp r8,8
 jb .R_invalid
 cmp r8,R_WIDTH_MAX
 jbe .R_column_ok
 mov r8d,R_WIDTH_MAX
.R_column_ok:
 dec r8
 mov [rbx+R_COLS],r8
 lea rdx,[rbx+R_SOURCE]
 mov ecx,R_MAX*4
 call ui_sanitize
 test rax,rax
 js .R_return
 mov [rbx+R_SIZE],rax
 lea rdx,[rbx+R_SOURCE]
 mov [rbx+R_SRC],rdx
 call .R_collect_lines
 mov qword ptr [rbx+R_KIND],0
 cmp qword ptr [rbx+R_NLINES],0
 je .R_fallback
 mov rdi,[rbx+R_PARTS]
 mov rsi,[rbx+R_PARTS+8]
 lea rdx,[rip+.r_flowchart_key]
 call .R_prefix
 test rax,rax
 jnz .R_flow_header
 mov rdi,[rbx+R_PARTS]
 mov rsi,[rbx+R_PARTS+8]
 lea rdx,[rip+.r_graph_key]
 call .R_prefix
 test rax,rax
 jnz .R_flow_header
 mov rdi,[rbx+R_PARTS]
 mov rsi,[rbx+R_PARTS+8]
 lea rdx,[rip+.r_sequence_key]
 call .R_prefix
 test rax,rax
 jnz .R_sequence_start
 mov rdi,[rbx+R_PARTS]
 mov rsi,[rbx+R_PARTS+8]
 lea rdx,[rip+.r_class_key]
 call .R_prefix
 test rax,rax
 jnz .R_class_start
 jmp .R_fallback
.R_flow_header:
 mov qword ptr [rbx+R_KIND],1
 mov rdi,[rbx+R_PARTS]
 add rdi,rax
 mov rsi,[rbx+R_PARTS+8]
 sub rsi,rax
 call .R_trim
 cmp rsi,2
 jb .R_fallback
 mov ax,[rdi]
 and eax,0xdfdf
 mov [rbx+R_DIR],rax
 call .R_flow_parse
 test rax,rax
 js .R_fallback
 cmp qword ptr [rbx+R_ECOUNT],0
 je .R_fallback
 call .R_flow_layout
 test rax,rax
 js .R_fallback
 call .R_flow_title
 call .R_flow_draw
 jmp .R_finish
.R_sequence_start:
 mov qword ptr [rbx+R_KIND],2
 call .R_sequence_parse
 test rax,rax
 js .R_fallback
 cmp qword ptr [rbx+R_MSGCOUNT],0
 je .R_fallback
 lea rdi,[rip+.r_sequence_title]
 mov esi,OFFSET FLAT:.r_sequence_title_len
 call .R_title
 call .R_sequence_output
 jmp .R_finish
.R_class_start:
 mov qword ptr [rbx+R_KIND],3
 call .R_class_parse
 test rax,rax
 js .R_fallback
 cmp qword ptr [rbx+R_NCOUNT],0
 je .R_fallback
 lea rdi,[rip+.r_class_title]
 mov esi,OFFSET FLAT:.r_class_title_len
 call .R_title
 call .R_class_output
 jmp .R_finish
.R_fallback:
 call .R_source_fallback
.R_finish:
 RC .r_reset
 mov rax,[rbx+R_ERR]
 test rax,rax
 jnz .R_return
 mov rax,[rbx+R_LEN]
 jmp .R_return
.R_invalid:
 mov rax,-22
.R_return:
 RL
.R_put:
 cmp qword ptr [rbx+R_ERR],0
 jne .R_put_done
 mov rax,[rbx+R_LEN]
 add rax,rsi
 jc .R_cap
 cmp rax,[rbx+R_CAP]
 ja .R_cap
 mov rdx,rdi
 mov rdi,[rbx+R_OUT]
 add rdi,[rbx+R_LEN]
 mov rcx,rsi
 mov rsi,rdx
 rep movsb
 mov [rbx+R_LEN],rax
.R_put_done:
 ret
.R_cap:
 mov qword ptr [rbx+R_ERR],-28
 ret
# palette role0accentbold/1primary/2secondary. Offsets are PIC relative values.
.R_color:
 mov rax,[rbx+R_THEME]
 shl rdi,4
 add rax,rdi
 mov rsi,[rax+8]
 mov rdi,[rax]
 lea rdx,[rip+.r_palettes]
 add rdi,rdx
 jmp .R_put
.R_trim:
 test rsi,rsi
 jz .R_trim_done
 cmp byte ptr [rdi],' '
 jne .R_trim_tail
 inc rdi
 dec rsi
 jmp .R_trim
.R_trim_tail:
 test rsi,rsi
 jz .R_trim_done
 mov al,[rdi+rsi-1]
 cmp al,' '
 je .R_trim_dec
 cmp al,';'
 je .R_trim_dec
 cmp al,','
 jne .R_trim_done
.R_trim_dec:
 dec rsi
 jmp .R_trim_tail
.R_trim_done:
 ret
# Case-insensitive key prefix, returns matched length or0.
.R_prefix:
 xor eax,eax
 xor ecx,ecx
.R_prefix_byte:
 mov r8b,[rdx+rcx]
 test r8b,r8b
 jz .R_prefix_yes
 cmp rcx,rsi
 jae .R_prefix_no
 mov r9b,[rdi+rcx]
 or r8b,32
 or r9b,32
 cmp r8b,r9b
 jne .R_prefix_no
 inc rcx
 jmp .R_prefix_byte
.R_prefix_yes:
 mov rax,rcx
 ret
.R_prefix_no:
 xor eax,eax
 ret
.R_equal:
 cmp rsi,rcx
 jne .R_equal_no
 xor eax,eax
.R_equal_loop:
 cmp rax,rsi
 jae .R_equal_yes
 mov r8b,[rdi+rax]
 cmp r8b,[rdx+rax]
 jne .R_equal_no
 inc rax
 jmp .R_equal_loop
.R_equal_yes:
 mov eax,1
 ret
.R_equal_no:
 xor eax,eax
 ret
# Collect trimmed, noncomment lines. Empty lines remain in source for fallback.
.R_collect_lines:
 push r12
 push r13
 push r14
 mov r12,[rbx+R_SRC]
 mov r13,[rbx+R_SIZE]
 xor r14d,r14d
.R_collect_next:
 cmp r14,r13
 jae .R_collect_done
 mov rcx,r14
.R_collect_scan:
 cmp rcx,r13
 jae .R_collect_line
 cmp byte ptr [r12+rcx],10
 je .R_collect_line
 inc rcx
 jmp .R_collect_scan
.R_collect_line:
 lea rdi,[r12+r14]
 mov rsi,rcx
 sub rsi,r14
 lea r14,[rcx+1]
 call .R_trim
 test rsi,rsi
 jz .R_collect_next
 cmp rsi,2
 jb .R_collect_store
 cmp word ptr [rdi],0x2525
 je .R_collect_next
.R_collect_store:
 mov rax,[rbx+R_NLINES]
 cmp rax,R_LINES_MAX
 jae .R_collect_limit
 shl rax,4
 mov [rbx+rax+R_PARTS],rdi
 mov [rbx+rax+R_PARTS+8],rsi
 inc qword ptr [rbx+R_NLINES]
 jmp .R_collect_next
.R_collect_limit:
 mov qword ptr [rbx+R_WARNING],1
.R_collect_done:
 pop r14
 pop r13
 pop r12
 ret
# Clip body line by complete graphemes, reserve ellipsis if needed.
.R_line:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12,rdi
 mov r13,rsi
 mov edi,1
 call .R_color
 RC .r_space
 mov rdi,r12
 mov rsi,r13
 call ui_text_width
 mov r15,[rbx+R_COLS]
 xor ebp,ebp
 cmp rax,r15
 jbe .R_line_start
 dec r15
 mov ebp,1
.R_line_start:
 xor r14d,r14d
 mov qword ptr [rbx+R_TEMP],0
.R_line_cluster:
 cmp r14,r13
 jae .R_line_end
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov [rbx+R_TEMP+8],rax
 lea rdi,[r12+r14]
 mov rsi,rax
 sub rsi,r14
 call ui_text_width
 add rax,[rbx+R_TEMP]
 cmp rax,r15
 ja .R_line_end
 mov [rbx+R_TEMP],rax
 lea rdi,[r12+r14]
 mov rsi,[rbx+R_TEMP+8]
 sub rsi,r14
 call .R_put
 mov r14,[rbx+R_TEMP+8]
 jmp .R_line_cluster
.R_line_end:
 test rbp,rbp
 jz .R_line_newline
 RC .r_ellipsis
.R_line_newline:
 RC .r_lf
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_number:
 sub rsp,8
 mov rsi,rdi
 lea rdi,[rbx+R_NUMBER]
 call qx_uint
 mov rsi,rax
 lea rdi,[rbx+R_NUMBER]
 call .R_put
 add rsp,8
 ret
.R_title:
 push r12
 push r13
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 xor edi,edi
 call .R_color
 RC .r_space
 mov rdi,r12
 mov rsi,r13
 call .R_put
 cmp qword ptr [rbx+R_INDEX],0
 je .R_title_end
 RC .r_source_hint
 mov rdi,[rbx+R_INDEX]
 call .R_number
.R_title_end:
 RC .r_reset
 RC .r_lf
 add rsp,8
 pop r13
 pop r12
 ret
.R_warning_line:
 push r12
 push r13
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 mov edi,2
 call .R_color
 RC .r_space
 mov rdi,r12
 mov rsi,r13
 call .R_put
 RC .r_lf
 add rsp,8
 pop r13
 pop r12
 ret
.R_source_fallback:
 push r12
 push r13
 push r14
 xor edi,edi
 call .R_color
 RC .r_space
 RC .r_source_title
 cmp qword ptr [rbx+R_NLINES],0
 je .R_fallback_unknown
 mov r12,[rbx+R_PARTS]
 mov r13,[rbx+R_PARTS+8]
 xor r14d,r14d
.R_fallback_type:
 cmp r14,r13
 jae .R_fallback_type_done
 cmp byte ptr [r12+r14],' '
 je .R_fallback_type_done
 inc r14
 jmp .R_fallback_type
.R_fallback_type_done:
 mov rdi,r12
 mov rsi,r14
 call .R_put
 jmp .R_fallback_title_end
.R_fallback_unknown:
 RC .r_unknown
.R_fallback_title_end:
 RC .r_paren
 cmp qword ptr [rbx+R_INDEX],0
 je .R_fallback_no_hint
 RC .r_source_hint
 mov rdi,[rbx+R_INDEX]
 call .R_number
.R_fallback_no_hint:
 RC .r_reset
 RC .r_lf
 RLINE .r_fence
 mov r12,[rbx+R_SRC]
 mov r13,[rbx+R_SIZE]
 xor r14d,r14d
 xor ebp,ebp
.R_fallback_line:
 cmp r14,r13
 jae .R_fallback_end
 cmp rbp,80
 jae .R_fallback_truncated
 mov rcx,r14
.R_fallback_scan:
 cmp rcx,r13
 jae .R_fallback_emit
 cmp byte ptr [r12+rcx],10
 je .R_fallback_emit
 inc rcx
 jmp .R_fallback_scan
.R_fallback_emit:
 lea rdi,[r12+r14]
 mov rsi,rcx
 sub rsi,r14
 lea r14,[rcx+1]
 call .R_line
 inc rbp
 jmp .R_fallback_line
.R_fallback_truncated:
 mov qword ptr [rbx+R_WARNING],1
.R_fallback_end:
 RLINE .r_fence_end
 lea rdi,[rip+.r_fallback_warning]
 mov esi,OFFSET FLAT:.r_fallback_warning_len
 call .R_warning_line
 cmp qword ptr [rbx+R_WARNING],0
 je .R_fallback_done
 RLINE .r_limit_warning
.R_fallback_done:
 pop r14
 pop r13
 pop r12
 ret
.R_treset:
 mov qword ptr [rbx+R_TLEN],0
 ret
.R_tput:
 mov rax,[rbx+R_TLEN]
 add rax,rsi
 cmp rax,65536
 ja .R_parse_error
 mov rdx,rdi
 lea rdi,[rbx+R_TEXTBUF]
 add rdi,[rbx+R_TLEN]
 mov rcx,rsi
 mov rsi,rdx
 rep movsb
 mov [rbx+R_TLEN],rax
 ret
.R_parse_error:
 mov qword ptr [rbx+R_WARNING],2
 mov rax,-90
 ret
# ID span,label span,shape ->stable insertion index. Label0 retains existing alias.
.R_get_node:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 mov rbp,r8
 call .R_trim
 mov r12,rdi
 mov r13,rsi
 test r13,r13
 jz .R_node_bad
 cmp r13,128
 ja .R_node_bad
 xor r10d,r10d
.R_node_search:
 cmp r10,[rbx+R_NCOUNT]
 jae .R_node_create
 imul rax,r10,R_NODE_SIZE
 lea r11,[rbx+R_NODEBUF]
 add r11,rax
 cmp r13,[r11+N_IDLEN]
 jne .R_node_next
 mov rdi,r12
 mov rsi,r13
 mov rdx,[r11+N_ID]
 mov rcx,r13
 call .R_equal
 test eax,eax
 jnz .R_node_found
.R_node_next:
 inc r10
 jmp .R_node_search
.R_node_create:
 cmp r10,R_NODES
 jae .R_node_bad
 inc qword ptr [rbx+R_NCOUNT]
 imul rax,r10,R_NODE_SIZE
 lea r11,[rbx+R_NODEBUF]
 add r11,rax
 mov [r11+N_ID],r12
 mov [r11+N_IDLEN],r13
 mov qword ptr [r11+N_RANK],-1
 mov qword ptr [r11+N_INCOMING],0
 mov qword ptr [r11+N_EXPLICIT],0
 mov qword ptr [r11+N_PREF],0
 mov [r11+N_SHAPE],rbp
 test r14,r14
 jnz .R_node_set_label
 mov r14,r12
 mov r15,r13
 jmp .R_node_set_label
.R_node_found:
 test r14,r14
 jz .R_node_index
 cmp qword ptr [rbx+R_KIND],1
 jne .R_node_set_label
 cmp qword ptr [r11+N_EXPLICIT],0
 jne .R_node_shape
.R_node_set_label:
 cmp r15,255
 ja .R_node_bad
 mov rdi,r14
 mov rsi,r15
 call .R_trim
 mov r14,rdi
 mov r15,rsi
 cmp qword ptr [rbx+R_KIND],1
 jne .R_node_copy
 cmp r15,2
 jb .R_node_copy
 mov al,[r14]
 cmp al,'"'
 je .R_node_quote
 cmp al,39
 jne .R_node_copy
.R_node_quote:
 cmp al,[r14+r15-1]
 jne .R_node_copy
 inc r14
 sub r15,2
.R_node_copy:
 lea rdi,[r11+N_LABEL]
 mov rsi,r14
 mov rcx,r15
 rep movsb
 mov [r11+N_LLEN],r15
 mov qword ptr [r11+N_EXPLICIT],1
 cmp r14,r12
 jne .R_node_shape
 mov qword ptr [r11+N_EXPLICIT],0
.R_node_shape:
 test rbp,rbp
 jz .R_node_index
 cmp qword ptr [r11+N_SHAPE],0
 jne .R_node_index
 mov [r11+N_SHAPE],rbp
.R_node_index:
 mov rax,r10
 jmp .R_node_return
.R_node_bad:
 mov rax,-90
.R_node_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_node_address:
 imul rax,rdi,R_NODE_SIZE
 lea rdi,[rbx+R_NODEBUF]
 add rdi,rax
 ret
.R_tnode:
 sub rsp,8
 call .R_node_address
 mov rsi,[rdi+N_LLEN]
 add rdi,N_LABEL
 call .R_tput
 add rsp,8
 ret
.R_header:
 push r12
 call .R_treset
 call .R_tput
 xor r12d,r12d
.R_header_node:
 cmp r12,[rbx+R_NCOUNT]
 jae .R_header_done
 test r12,r12
 jz .R_header_label
 lea rdi,[rip+.r_header_separator]
 mov esi,OFFSET FLAT:.r_header_separator_len
 call .R_tput
.R_header_label:
 mov rdi,r12
 call .R_tnode
 inc r12
 jmp .R_header_node
.R_header_done:
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call .R_line
 pop r12
 ret
.R_sequence_parse:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12d,1
.R_seq_line:
 cmp r12,[rbx+R_NLINES]
 jae .R_seq_done
 mov rax,r12
 shl rax,4
 mov r13,[rbx+rax+R_PARTS]
 mov r14,[rbx+rax+R_PARTS+8]
 mov rdi,r13
 mov rsi,r14
 lea rdx,[rip+.r_participant_key]
 call .R_prefix
 test rax,rax
 jnz .R_seq_participant
 mov rdi,r13
 mov rsi,r14
 lea rdx,[rip+.r_actor_key]
 call .R_prefix
 test rax,rax
 jnz .R_seq_participant
 jmp .R_seq_message
.R_seq_participant:
 cmp rax,r14
 jae .R_seq_next
 cmp byte ptr [r13+rax],' '
 jne .R_seq_next
 add r13,rax
 sub r14,rax
 mov rdi,r13
 mov rsi,r14
 call .R_trim
 mov r13,rdi
 mov r14,rsi
 xor ebp,ebp
.R_seq_alias_scan:
 lea rax,[rbp+4]
 cmp rax,r14
 ja .R_seq_no_alias
 cmp byte ptr [r13+rbp],' '
 jne .R_seq_alias_next
 mov ax,[r13+rbp+1]
 or eax,0x2020
 cmp ax,0x7361
 jne .R_seq_alias_next
 cmp byte ptr [r13+rbp+3],' '
 je .R_seq_alias_found
.R_seq_alias_next:
 inc rbp
 jmp .R_seq_alias_scan
.R_seq_alias_found:
 mov rdi,r13
 mov rsi,rbp
 lea rdx,[r13+rbp+4]
 mov rcx,r14
 sub rcx,rbp
 sub rcx,4
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_seq_return
 jmp .R_seq_next
.R_seq_no_alias:
 mov rdi,r13
 mov rsi,r14
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_seq_return
 jmp .R_seq_next
.R_seq_message:
 xor ebp,ebp
.R_seq_operator:
 cmp rbp,r14
 jae .R_seq_next
 cmp byte ptr [r13+rbp],'-'
 je .R_seq_operator_found
 inc rbp
 jmp .R_seq_operator
.R_seq_operator_found:
 mov [rbx+R_OP],rbp
 mov rax,rbp
 inc rax
 mov qword ptr [rbx+R_HORIZONTAL],0
 cmp rax,r14
 jae .R_seq_next
 cmp byte ptr [r13+rax],'-'
 jne .R_seq_arrow_end
 mov qword ptr [rbx+R_HORIZONTAL],1
 inc rax
.R_seq_arrow_end:
 cmp rax,r14
 jae .R_seq_next
 cmp byte ptr [r13+rax],'>'
 je .R_seq_greater
 cmp byte ptr [r13+rax],'x'
 jne .R_seq_next
 inc rax
 jmp .R_seq_after_operator
.R_seq_greater:
 inc rax
 cmp rax,r14
 jae .R_seq_next
 cmp byte ptr [r13+rax],'>'
 jne .R_seq_after_operator
 inc rax
.R_seq_after_operator:
 mov [rbx+R_AFTER],rax
 mov rbp,rax
.R_seq_colon:
 cmp rbp,r14
 jae .R_seq_next
 cmp byte ptr [r13+rbp],':'
 je .R_seq_nodes
 inc rbp
 jmp .R_seq_colon
.R_seq_nodes:
 mov [rbx+R_NEXTOP],rbp
 mov rdi,r13
 mov rsi,[rbx+R_OP]
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_seq_return
 mov [rbx+R_FROM],rax
 mov rax,[rbx+R_AFTER]
 lea rdi,[r13+rax]
 mov rsi,[rbx+R_NEXTOP]
 sub rsi,rax
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_seq_return
 mov [rbx+R_TO],rax
 call .R_treset
 mov rdi,[rbx+R_FROM]
 call .R_tnode
 lea rdi,[rip+.r_arrow]
 mov esi,OFFSET FLAT:.r_arrow_len
 cmp qword ptr [rbx+R_HORIZONTAL],0
 je .R_seq_arrow_put
 lea rdi,[rip+.r_dash_arrow]
 mov esi,OFFSET FLAT:.r_dash_arrow_len
.R_seq_arrow_put:
 call .R_tput
 mov rdi,[rbx+R_TO]
 call .R_tnode
 lea rdi,[rip+.r_colon]
 mov esi,OFFSET FLAT:.r_colon_len
 call .R_tput
 mov rax,[rbx+R_NEXTOP]
 lea rdi,[r13+rax+1]
 mov rsi,r14
 sub rsi,rax
 dec rsi
 call .R_trim
 test rsi,rsi
 jz .R_seq_next
 call .R_tput
 mov rax,[rbx+R_MSGCOUNT]
 cmp rax,80
 jae .R_seq_limit
 shl rax,11
 lea rdi,[rbx+R_MSGBUF]
 add rdi,rax
 mov rcx,[rbx+R_TLEN]
 cmp rcx,2032
 ja .R_seq_limit
 mov [rdi],rcx
 add rdi,16
 lea rsi,[rbx+R_TEXTBUF]
 rep movsb
 inc qword ptr [rbx+R_MSGCOUNT]
 jmp .R_seq_next
.R_seq_limit:
 mov qword ptr [rbx+R_WARNING],1
.R_seq_next:
 inc r12
 jmp .R_seq_line
.R_seq_done:
 xor eax,eax
.R_seq_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_sequence_output:
 push r12
 lea rdi,[rip+.r_participants]
 mov esi,OFFSET FLAT:.r_participants_len
 call .R_header
 RLINE .r_empty
 xor r12d,r12d
.R_seq_output_line:
 cmp r12,[rbx+R_MSGCOUNT]
 jae .R_seq_output_done
 mov rax,r12
 shl rax,11
 lea rdi,[rbx+R_MSGBUF]
 add rdi,rax
 mov rsi,[rdi]
 add rdi,16
 call .R_line
 inc r12
 jmp .R_seq_output_line
.R_seq_output_done:
 cmp qword ptr [rbx+R_WARNING],0
 je .R_seq_output_return
 RLINE .r_limit_warning
.R_seq_output_return:
 pop r12
 ret
# Class declarations, block/inline members, and source-recognized relationships.
.R_class_parse:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12d,1
.R_class_line:
 cmp r12,[rbx+R_NLINES]
 jae .R_class_done
 cmp r12,81
 jae .R_class_limit
 mov rax,r12
 shl rax,4
 mov r13,[rbx+rax+R_PARTS]
 mov r14,[rbx+rax+R_PARTS+8]
 mov rdi,r13
 mov rsi,r14
 lea rdx,[rip+.r_class_declare]
 call .R_prefix
 test rax,rax
 jnz .R_class_declaration
 cmp r14,1
 jne .R_class_relationship
 cmp byte ptr [r13],'}'
 jne .R_class_relationship
 mov qword ptr [rbx+R_CURRENT_CLASS],-1
 jmp .R_class_next
.R_class_declaration:
 cmp rax,r14
 jae .R_class_next
 cmp byte ptr [r13+rax],' '
 jne .R_class_relationship
 add r13,rax
 sub r14,rax
 mov rdi,r13
 mov rsi,r14
 call .R_trim
 mov r13,rdi
 mov r14,rsi
 xor ebp,ebp
.R_class_name:
 cmp rbp,r14
 jae .R_class_name_ready
 mov al,[r13+rbp]
 cmp al,' '
 je .R_class_name_ready
 cmp al,'{'
 je .R_class_name_ready
 inc rbp
 jmp .R_class_name
.R_class_name_ready:
 mov rdi,r13
 mov rsi,rbp
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_class_return
 mov [rbx+R_CURRENT_CLASS],rax
 jmp .R_class_next
.R_class_relationship:
 # Whitespace-separated from/operator/to as in the original relation grammar.
 xor ebp,ebp
.R_class_first_word:
 cmp rbp,r14
 jae .R_class_inline
 cmp byte ptr [r13+rbp],' '
 je .R_class_first_end
 inc rbp
 jmp .R_class_first_word
.R_class_first_end:
 mov [rbx+R_OP],rbp
.R_class_skip_operator:
 cmp rbp,r14
 jae .R_class_inline
 cmp byte ptr [r13+rbp],' '
 jne .R_class_operator_start
 inc rbp
 jmp .R_class_skip_operator
.R_class_operator_start:
 mov [rbx+R_AFTER],rbp
.R_class_operator_end:
 cmp rbp,r14
 jae .R_class_inline
 cmp byte ptr [r13+rbp],' '
 je .R_class_operator_ready
 inc rbp
 jmp .R_class_operator_end
.R_class_operator_ready:
 mov [rbx+R_NEXTOP],rbp
 mov rax,[rbx+R_AFTER]
 lea rdi,[r13+rax]
 mov rsi,rbp
 sub rsi,rax
 call .R_relation_op
 test eax,eax
 jz .R_class_inline
.R_class_skip_to:
 cmp rbp,r14
 jae .R_class_inline
 cmp byte ptr [r13+rbp],' '
 jne .R_class_to_start
 inc rbp
 jmp .R_class_skip_to
.R_class_to_start:
 mov [rbx+R_LABELPTR],rbp
.R_class_to_end:
 cmp rbp,r14
 jae .R_class_to_ready
 mov al,[r13+rbp]
 cmp al,' '
 je .R_class_to_ready
 cmp al,':'
 je .R_class_to_ready
 inc rbp
 jmp .R_class_to_end
.R_class_to_ready:
 mov [rbx+R_LABELLEN],rbp
 mov rdi,r13
 mov rsi,[rbx+R_OP]
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_class_return
 mov [rbx+R_FROM],rax
 mov rax,[rbx+R_LABELPTR]
 lea rdi,[r13+rax]
 mov rsi,[rbx+R_LABELLEN]
 sub rsi,rax
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_class_return
 mov r15,rax
 mov rax,[rbx+R_RELCOUNT]
 cmp rax,80
 jae .R_class_limit
 shl rax,9
 lea rdi,[rbx+R_RELBUF]
 add rdi,rax
 mov rax,[rbx+R_FROM]
 mov [rdi],rax
 mov [rdi+8],r15
 mov rax,[rbx+R_AFTER]
 lea rdx,[r13+rax]
 mov [rdi+16],rdx
 mov rdx,[rbx+R_NEXTOP]
 sub rdx,rax
 mov [rdi+24],rdx
 mov rbp,[rbx+R_LABELLEN]
.R_class_relation_label:
 cmp rbp,r14
 jae .R_class_relation_no_label
 mov al,[r13+rbp]
 cmp al,' '
 je .R_class_relation_label_next
 cmp al,':'
 jne .R_class_relation_no_label
 inc rbp
 jmp .R_class_relation_label_found
.R_class_relation_label_next:
 inc rbp
 jmp .R_class_relation_label
.R_class_relation_label_found:
 lea rax,[r13+rbp]
 mov [rdi+32],rax
 mov rax,r14
 sub rax,rbp
 mov [rdi+40],rax
 jmp .R_class_relation_store
.R_class_relation_no_label:
 mov qword ptr [rdi+32],0
 mov qword ptr [rdi+40],0
.R_class_relation_store:
 inc qword ptr [rbx+R_RELCOUNT]
 jmp .R_class_next
.R_class_inline:
 xor ebp,ebp
.R_class_inline_colon:
 cmp rbp,r14
 jae .R_class_block_member
 cmp byte ptr [r13+rbp],':'
 je .R_class_inline_member
 inc rbp
 jmp .R_class_inline_colon
.R_class_inline_member:
 mov rdi,r13
 mov rsi,rbp
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 test rax,rax
 js .R_class_return
 mov r15,rax
 lea rdi,[r13+rbp+1]
 mov rsi,r14
 sub rsi,rbp
 dec rsi
 call .R_trim
 mov r13,rdi
 mov r14,rsi
 jmp .R_class_member_store
.R_class_block_member:
 mov r15,[rbx+R_CURRENT_CLASS]
 test r15,r15
 js .R_class_next
.R_class_member_store:
 mov rax,[rbx+R_MEMBERCOUNT]
 cmp rax,80
 jae .R_class_limit
 shl rax,5
 mov [rbx+rax+R_MEMBERBUF],r15
 mov [rbx+rax+R_MEMBERBUF+8],r13
 mov [rbx+rax+R_MEMBERBUF+16],r14
 inc qword ptr [rbx+R_MEMBERCOUNT]
.R_class_next:
 inc r12
 jmp .R_class_line
.R_class_limit:
 mov qword ptr [rbx+R_WARNING],1
.R_class_done:
 xor eax,eax
.R_class_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_relation_op:
 # Only the documented ASCII relation vocabulary; anything else stays source.
 xor ecx,ecx
 xor r8d,r8d
.R_relation_char:
 cmp rcx,rsi
 jae .R_relation_done
 mov al,[rdi+rcx]
 cmp al,'-'
 je .R_relation_dash
 cmp al,'<'
 je .R_relation_next
 cmp al,'>'
 je .R_relation_next
 cmp al,'|'
 je .R_relation_next
 cmp al,'*'
 je .R_relation_next
 cmp al,'o'
 je .R_relation_next
 cmp al,'.'
 jne .R_relation_no
 jmp .R_relation_next
.R_relation_dash:
 inc r8
.R_relation_next:
 inc rcx
 jmp .R_relation_char
.R_relation_done:
 xor eax,eax
 test r8,r8
 setne al
 ret
.R_relation_no:
 xor eax,eax
 ret
.R_class_output:
 push r12
 push r13
 push r14
 lea rdi,[rip+.r_classes]
 mov esi,OFFSET FLAT:.r_classes_len
 call .R_header
 RLINE .r_empty
 cmp qword ptr [rbx+R_RELCOUNT],0
 je .R_class_no_relations
 RLINE .r_relationships
 xor r12d,r12d
.R_class_output_relation:
 cmp r12,[rbx+R_RELCOUNT]
 jae .R_class_output_members
 mov rax,r12
 shl rax,9
 lea r13,[rbx+R_RELBUF]
 add r13,rax
 call .R_treset
 mov rdi,[r13]
 call .R_tnode
 lea rdi,[rip+.r_space]
 mov esi,1
 call .R_tput
 mov rdi,[r13+16]
 mov rsi,[r13+24]
 call .R_tput
 lea rdi,[rip+.r_space]
 mov esi,1
 call .R_tput
 mov rdi,[r13+8]
 call .R_tnode
 cmp qword ptr [r13+40],0
 je .R_class_relation_output_done
 lea rdi,[rip+.r_colon]
 mov esi,2
 call .R_tput
 mov rdi,[r13+32]
 mov rsi,[r13+40]
 call .R_trim
 call .R_tput
.R_class_relation_output_done:
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call .R_line
 inc r12
 jmp .R_class_output_relation
.R_class_no_relations:
 RLINE .r_relationships_none
.R_class_output_members:
 cmp qword ptr [rbx+R_MEMBERCOUNT],0
 je .R_class_output_done
 RLINE .r_empty
 RLINE .r_members
 xor r12d,r12d
.R_class_output_member:
 cmp r12,[rbx+R_MEMBERCOUNT]
 jae .R_class_output_done
 cmp r12,24
 jae .R_class_output_done
 mov rax,r12
 shl rax,5
 lea r13,[rbx+R_MEMBERBUF]
 add r13,rax
 call .R_treset
 mov rdi,[r13]
 call .R_tnode
 lea rdi,[rip+.r_colon]
 mov esi,2
 call .R_tput
 mov rdi,[r13+8]
 mov rsi,[r13+16]
 call .R_tput
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call .R_line
 inc r12
 jmp .R_class_output_member
.R_class_output_done:
 cmp qword ptr [rbx+R_WARNING],0
 je .R_class_output_return
 RLINE .r_limit_warning
.R_class_output_return:
 pop r14
 pop r13
 pop r12
 ret
# Recognized flow operators outside quoted/bracketed node labels.
# ptr,end ->opstart RAX/0, after RDX,labelptr RCX,labellen R8.
.R_find_flow_op:
 mov r9,rdi
 xor r10d,r10d
 xor r11d,r11d
.R_find_flow_scan:
 cmp r9,rsi
 jae .R_find_flow_none
 mov al,[r9]
 test r11d,r11d
 jz .R_find_flow_quote
 cmp al,'\\'
 je .R_find_flow_escape
 cmp al,r11b
 jne .R_find_flow_advance
 xor r11d,r11d
 jmp .R_find_flow_advance
.R_find_flow_quote:
 cmp al,'"'
 je .R_find_flow_quote_open
 cmp al,39
 je .R_find_flow_quote_open
 cmp al,'['
 je .R_find_flow_open
 cmp al,'('
 je .R_find_flow_open
 cmp al,'{'
 je .R_find_flow_open
 cmp al,']'
 je .R_find_flow_close
 cmp al,')'
 je .R_find_flow_close
 cmp al,'}'
 je .R_find_flow_close
 test r10,r10
 jnz .R_find_flow_advance
 lea rax,[r9+3]
 cmp rax,rsi
 ja .R_find_flow_advance
 cmp word ptr [r9],0x2d2d
 je .R_find_flow_dash
 cmp word ptr [r9],0x3d3d
 jne .R_find_flow_dotted
 cmp byte ptr [r9+2],'>'
 je .R_find_flow_three
 jmp .R_find_flow_advance
.R_find_flow_dotted:
 lea rax,[r9+4]
 cmp rax,rsi
 ja .R_find_flow_advance
 cmp dword ptr [r9],0x3e2d2e2d
 je .R_find_flow_four
 jmp .R_find_flow_advance
.R_find_flow_dash:
 mov al,[r9+2]
 cmp al,'>'
 je .R_find_flow_three
 cmp al,'-'
 je .R_find_flow_three
 cmp al,'x'
 je .R_find_flow_three
 cmp al,'o'
 je .R_find_flow_three
 cmp al,' '
 jne .R_find_flow_advance
 lea rcx,[r9+3]
.R_find_flow_label_start:
 cmp rcx,rsi
 jae .R_find_flow_none
 cmp byte ptr [rcx],' '
 jne .R_find_flow_label_search
 inc rcx
 jmp .R_find_flow_label_start
.R_find_flow_label_search:
 mov rdx,rcx
.R_find_flow_label_end:
 lea rax,[rdx+3]
 cmp rax,rsi
 ja .R_find_flow_none
 cmp word ptr [rdx],0x2d2d
 jne .R_find_flow_label_next
 cmp byte ptr [rdx+2],'>'
 je .R_find_flow_text_label
.R_find_flow_label_next:
 inc rdx
 jmp .R_find_flow_label_end
.R_find_flow_text_label:
 mov r8,rdx
.R_find_flow_label_trim:
 cmp r8,rcx
 jbe .R_find_flow_label_empty
 cmp byte ptr [r8-1],' '
 jne .R_find_flow_label_ready
 dec r8
 jmp .R_find_flow_label_trim
.R_find_flow_label_ready:
 sub r8,rcx
 add rdx,3
 mov rax,r9
 ret
.R_find_flow_label_empty:
 xor r8d,r8d
 add rdx,3
 mov rax,r9
 ret
.R_find_flow_three:
 lea rdx,[r9+3]
 jmp .R_find_flow_operator_end
.R_find_flow_four:
 lea rdx,[r9+4]
.R_find_flow_operator_end:
 mov rax,r9
 xor ecx,ecx
 xor r8d,r8d
.R_find_flow_skip_spaces:
 cmp rdx,rsi
 jae .R_find_flow_return
 cmp byte ptr [rdx],' '
 jne .R_find_flow_pipe
 inc rdx
 jmp .R_find_flow_skip_spaces
.R_find_flow_pipe:
 cmp byte ptr [rdx],'|'
 jne .R_find_flow_return
 lea rcx,[rdx+1]
 mov rdx,rcx
.R_find_flow_pipe_end:
 cmp rdx,rsi
 jae .R_find_flow_none
 cmp byte ptr [rdx],'|'
 je .R_find_flow_pipe_ready
 inc rdx
 jmp .R_find_flow_pipe_end
.R_find_flow_pipe_ready:
 mov r8,rdx
 sub r8,rcx
 inc rdx
.R_find_flow_return:
 ret
.R_find_flow_quote_open:
 mov r11b,al
 jmp .R_find_flow_advance
.R_find_flow_open:
 inc r10
 jmp .R_find_flow_advance
.R_find_flow_close:
 test r10,r10
 jz .R_find_flow_advance
 dec r10
 jmp .R_find_flow_advance
.R_find_flow_escape:
 inc r9
.R_find_flow_advance:
 inc r9
 jmp .R_find_flow_scan
.R_find_flow_none:
 xor eax,eax
 ret
.R_node_token:
 push r12
 push r13
 push r14
 push r15
 push rbp
 call .R_trim
 mov r12,rdi
 mov r13,rsi
 test r13,r13
 jz .R_token_bad
 xor r14d,r14d
.R_token_id:
 cmp r14,r13
 jae .R_token_bare
 mov al,[r12+r14]
 cmp al,'_'
 je .R_token_id_next
 cmp al,'.'
 je .R_token_id_next
 cmp al,'$'
 je .R_token_id_next
 cmp al,':'
 je .R_token_id_next
 cmp al,'-'
 je .R_token_id_next
 cmp al,'0'
 jb .R_token_alpha
 cmp al,'9'
 jbe .R_token_id_next
.R_token_alpha:
 or al,32
 cmp al,'a'
 jb .R_token_id_end
 cmp al,'z'
 ja .R_token_id_end
.R_token_id_next:
 inc r14
 jmp .R_token_id
.R_token_id_end:
 test r14,r14
 jz .R_token_bare
 lea rdi,[r12+r14]
 mov rsi,r13
 sub rsi,r14
 call .R_trim
 mov r15,rdi
 mov rbp,rsi
 cmp rbp,2
 jb .R_token_id_only
 xor r8d,r8d
 mov al,[r15]
 cmp al,'['
 je .R_token_rect
 cmp al,'('
 je .R_token_round
 cmp al,'{'
 je .R_token_diamond
 cmp al,'>'
 jne .R_token_id_only
 cmp byte ptr [r15+rbp-1],']'
 jne .R_token_id_only
 jmp .R_token_label_one
.R_token_rect:
 cmp byte ptr [r15+rbp-1],']'
 jne .R_token_id_only
 cmp rbp,4
 jb .R_token_label_one
 cmp byte ptr [r15+1],'['
 jne .R_token_label_one
 cmp byte ptr [r15+rbp-2],']'
 jne .R_token_label_one
 inc r15
 sub rbp,2
 jmp .R_token_label_one
.R_token_round:
 mov r8d,1
 cmp byte ptr [r15+rbp-1],')'
 jne .R_token_id_only
 cmp rbp,4
 jb .R_token_label_one
 cmp byte ptr [r15+1],'('
 jne .R_token_label_one
 cmp byte ptr [r15+rbp-2],')'
 jne .R_token_label_one
 inc r15
 sub rbp,2
 jmp .R_token_label_one
.R_token_diamond:
 mov r8d,2
 cmp byte ptr [r15+rbp-1],'}'
 jne .R_token_id_only
.R_token_label_one:
 mov rdi,r12
 mov rsi,r14
 lea rdx,[r15+1]
 lea rcx,[rbp-2]
 call .R_get_node
 jmp .R_token_return
.R_token_id_only:
 mov r13,r14
.R_token_bare:
 mov rdi,r12
 mov rsi,r13
 xor edx,edx
 xor ecx,ecx
 xor r8d,r8d
 call .R_get_node
 jmp .R_token_return
.R_token_bad:
 mov rax,-90
.R_token_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_branch_pref:
 push r12
 push r13
 sub rsp,8
 mov r12,rdi
 mov r13,rsi
 lea rdx,[rip+.r_no]
 call .R_prefix
 cmp rax,r13
 je .R_branch_no
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.r_false]
 call .R_prefix
 cmp rax,r13
 je .R_branch_no
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.r_yes]
 call .R_prefix
 cmp rax,r13
 je .R_branch_yes
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.r_true]
 call .R_prefix
 cmp rax,r13
 je .R_branch_yes
 xor eax,eax
 jmp .R_branch_return
.R_branch_no:
 mov rax,-1
 jmp .R_branch_return
.R_branch_yes:
 mov eax,1
.R_branch_return:
 add rsp,8
 pop r13
 pop r12
 ret
.R_flow_statement:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 lea r13,[rdi+rsi]
 mov rsi,r13
 call .R_find_flow_op
 test rax,rax
 jz .R_statement_done
 mov [rbx+R_AFTER],rdx
 mov [rbx+R_LABELPTR],rcx
 mov [rbx+R_LABELLEN],r8
 mov rdi,r12
 mov rsi,rax
 sub rsi,r12
 call .R_node_token
 test rax,rax
 js .R_statement_return
 mov r14,rax
.R_statement_edge:
 mov rdi,[rbx+R_AFTER]
 mov rsi,r13
 call .R_find_flow_op
 mov [rsp],rax
 mov [rsp+8],rdx
 mov [rsp+16],rcx
 mov [rsp+24],r8
 test rax,rax
 jnz .R_statement_right_end
 mov rax,r13
.R_statement_right_end:
 mov rdi,[rbx+R_AFTER]
 mov rsi,rax
 sub rsi,rdi
 call .R_node_token
 test rax,rax
 js .R_statement_return
 mov r15,rax
 mov rbp,[rbx+R_ECOUNT]
 cmp rbp,R_EDGES
 jae .R_statement_limit
 imul rbp,rbp,R_EDGE_SIZE
 lea r12,[rbx+R_EDGEBUF]
 add r12,rbp
 mov [r12],r14
 mov [r12+8],r15
 mov rdi,[rbx+R_LABELPTR]
 mov rsi,[rbx+R_LABELLEN]
 mov [r12+16],rdi
 mov [r12+24],rsi
 inc qword ptr [rbx+R_ECOUNT]
 mov rdi,r15
 call .R_node_address
 inc qword ptr [rdi+N_INCOMING]
 mov rbp,rdi
 mov rdi,[r12+16]
 mov rsi,[r12+24]
 test rsi,rsi
 jz .R_statement_next
 call .R_branch_pref
 cmp qword ptr [rbp+N_PREF],0
 jne .R_statement_next
 mov [rbp+N_PREF],rax
.R_statement_next:
 cmp qword ptr [rsp],0
 je .R_statement_done
 mov r14,r15
 mov rax,[rsp+8]
 mov [rbx+R_AFTER],rax
 mov rax,[rsp+16]
 mov [rbx+R_LABELPTR],rax
 mov rax,[rsp+24]
 mov [rbx+R_LABELLEN],rax
 jmp .R_statement_edge
.R_statement_limit:
 mov rax,-90
 jmp .R_statement_return
.R_statement_done:
 xor eax,eax
.R_statement_return:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_flow_parse:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12d,1
.R_flow_source_line:
 cmp r12,[rbx+R_NLINES]
 jae .R_flow_parse_done
 cmp r12,121
 jae .R_flow_source_limit
 mov rax,r12
 shl rax,4
 mov r13,[rbx+rax+R_PARTS]
 mov r14,[rbx+rax+R_PARTS+8]
 add r14,r13
 mov r15,r13
.R_flow_semicolon:
 mov rbp,r15
.R_flow_statement_end:
 cmp rbp,r14
 jae .R_flow_statement_ready
 cmp byte ptr [rbp],';'
 je .R_flow_statement_ready
 inc rbp
 jmp .R_flow_statement_end
.R_flow_statement_ready:
 mov rdi,r15
 mov rsi,rbp
 sub rsi,r15
 call .R_flow_statement
 test rax,rax
 js .R_flow_parse_return
 lea r15,[rbp+1]
 cmp r15,r14
 jb .R_flow_semicolon
 inc r12
 jmp .R_flow_source_line
.R_flow_source_limit:
 mov qword ptr [rbx+R_WARNING],1
.R_flow_parse_done:
 xor eax,eax
.R_flow_parse_return:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
# Whitespace-only label trim (commas inside node labels remain visible).
.R_ws:
 test rsi,rsi
 jz .R_ws_done
 cmp byte ptr [rdi],' '
 jne .R_ws_tail
 inc rdi
 dec rsi
 jmp .R_ws
.R_ws_tail:
 test rsi,rsi
 jz .R_ws_done
 cmp byte ptr [rdi+rsi-1],' '
 jne .R_ws_done
 dec rsi
 jmp .R_ws_tail
.R_ws_done:
 ret
# Label normalization has no terminal effects. Convert literal\n and simple<br>.
.R_normalize_label:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,[r12+N_LLEN]
 xor r14d,r14d
 xor ecx,ecx
.R_normalize_byte:
 cmp r14,r13
 jae .R_normalize_done
 mov al,[r12+r14+N_LABEL]
 cmp al,'\\'
 jne .R_normalize_br
 lea rdx,[r14+1]
 cmp rdx,r13
 jae .R_normalize_store
 cmp byte ptr [r12+r14+N_LABEL+1],'n'
 jne .R_normalize_store
 mov al,10
 inc r14
 jmp .R_normalize_store
.R_normalize_br:
 cmp al,'<'
 jne .R_normalize_store
 lea rdx,[r14+4]
 cmp rdx,r13
 ja .R_normalize_store
 mov edx,dword ptr [r12+r14+N_LABEL]
 or edx,0x202000
 cmp edx,0x3e72623c
 jne .R_normalize_store
 mov al,10
 add r14,3
.R_normalize_store:
 mov [r12+rcx+N_LABEL],al
 inc rcx
 inc r14
 jmp .R_normalize_byte
.R_normalize_done:
 mov [r12+N_LLEN],rcx
 pop r14
 pop r13
 pop r12
 ret
# Append one label line to temporary text, clipping by grapheme to maxcells.
.R_fit_label:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov r12,rdi
 mov r13,rsi
 mov r15,rdx
 call ui_text_width
 xor ebp,ebp
 cmp rax,r15
 jbe .R_fit_start
 dec r15
 mov ebp,1
.R_fit_start:
 xor r14d,r14d
 mov qword ptr [rbx+R_TEMP+16],0
.R_fit_cluster:
 cmp r14,r13
 jae .R_fit_end
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov [rbx+R_TEMP+24],rax
 lea rdi,[r12+r14]
 mov rsi,rax
 sub rsi,r14
 call ui_text_width
 add rax,[rbx+R_TEMP+16]
 cmp rax,r15
 ja .R_fit_end
 mov [rbx+R_TEMP+16],rax
 lea rdi,[r12+r14]
 mov rsi,[rbx+R_TEMP+24]
 sub rsi,r14
 call .R_tput
 mov r14,[rbx+R_TEMP+24]
 jmp .R_fit_cluster
.R_fit_end:
 test rbp,rbp
 jz .R_fit_done
 lea rdi,[rip+.r_ellipsis]
 mov esi,3
 call .R_tput
 inc qword ptr [rbx+R_TEMP+16]
.R_fit_done:
 mov rax,[rbx+R_TEMP+16]
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
# Compute source-backed box dimensions and centered multiline label spans.
.R_measure_node:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 mov r13,rsi
 cmp r13,8
 jae .R_measure_width
 mov r13d,8
.R_measure_width:
 sub r13,4
 call .R_normalize_label
 mov r15,[r12+N_LLEN]
 xor r14d,r14d
 xor ebp,ebp
 mov qword ptr [rsp],4
 call .R_treset
.R_measure_label_line:
 cmp r14,r15
 jae .R_measure_node_copy
 mov rcx,r14
.R_measure_line_end:
 cmp rcx,r15
 jae .R_measure_line_span
 cmp byte ptr [r12+rcx+N_LABEL],10
 je .R_measure_line_span
 inc rcx
 jmp .R_measure_line_end
.R_measure_line_span:
 lea rdi,[r12+r14+N_LABEL]
 mov rsi,rcx
 sub rsi,r14
 lea r14,[rcx+1]
 call .R_ws
 test rsi,rsi
 jz .R_measure_label_line
 cmp rbp,8
 jae .R_measure_bad
 mov [rsp+8],rdi
 mov [rsp+16],rsi
 test rbp,rbp
 jz .R_measure_label_first
 lea rdi,[rip+.r_space]
 mov esi,1
 call .R_tput
.R_measure_label_first:
 mov rax,[rbx+R_TLEN]
 mov [rsp+24],rax
 mov rdi,[rsp+8]
 mov rsi,[rsp+16]
 mov rdx,r13
 call .R_fit_label
 cmp rax,[rsp]
 jbe .R_measure_label_store
 mov [rsp],rax
.R_measure_label_store:
 mov rax,rbp
 shl rax,4
 mov rdx,[rsp+24]
 mov [r12+rax+N_LABEL_LINES],rdx
 mov rcx,[rbx+R_TLEN]
 sub rcx,rdx
 mov [r12+rax+N_LABEL_LINES+8],rcx
 inc rbp
 jmp .R_measure_label_line
.R_measure_node_copy:
 mov rcx,[rbx+R_TLEN]
 cmp rcx,512
 ja .R_measure_bad
 mov [r12+N_LLEN],rcx
 lea rdi,[r12+N_LABEL]
 lea rsi,[rbx+R_TEXTBUF]
 rep movsb
 xor ecx,ecx
.R_measure_pointers:
 cmp rcx,rbp
 jae .R_measure_node_size
 mov rax,rcx
 shl rax,4
 lea rdx,[r12+N_LABEL]
 add [r12+rax+N_LABEL_LINES],rdx
 inc rcx
 jmp .R_measure_pointers
.R_measure_node_size:
 mov [r12+N_LINES],rbp
 lea rax,[rbp+2]
 mov [r12+N_H],rax
 mov rax,[rsp]
 add rax,4
 cmp qword ptr [r12+N_SHAPE],2
 jne .R_measure_size_set
 add rax,2
.R_measure_size_set:
 mov [r12+N_W],rax
 xor eax,eax
 jmp .R_measure_return
.R_measure_bad:
 mov rax,-90
.R_measure_return:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

# BFS ranks + insertion order, with original no/yes branch ordering per layer.
.R_flow_layout:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 xor r12d,r12d
 xor r13d,r13d
.R_layout_roots:
 cmp r12,[rbx+R_NCOUNT]
 jae .R_layout_roots_done
 mov rdi,r12
 call .R_node_address
 cmp qword ptr [rdi+N_INCOMING],0
 jne .R_layout_root_next
 mov qword ptr [rdi+N_RANK],0
 mov [rbx+r13*8+R_QUEUE],r12
 inc r13
.R_layout_root_next:
 inc r12
 jmp .R_layout_roots
.R_layout_roots_done:
 test r13,r13
 jnz .R_layout_bfs_start
 mov rax,[rbx+R_EDGEBUF]
 mov [rbx+R_QUEUE],rax
 mov rdi,rax
 call .R_node_address
 mov qword ptr [rdi+N_RANK],0
 mov r13d,1
.R_layout_bfs_start:
 xor r12d,r12d
.R_layout_bfs:
 cmp r12,r13
 jae .R_layout_rank_max
 mov r14,[rbx+r12*8+R_QUEUE]
 mov rdi,r14
 call .R_node_address
 mov r15,[rdi+N_RANK]
 xor ebp,ebp
.R_layout_bfs_edge:
 cmp rbp,[rbx+R_ECOUNT]
 jae .R_layout_bfs_next
 mov rax,rbp
 shl rax,9
 lea rdx,[rbx+R_EDGEBUF]
 add rdx,rax
 cmp [rdx],r14
 jne .R_layout_bfs_edge_next
 mov rax,[rdx+8]
 mov [rsp],rax
 mov rdi,rax
 call .R_node_address
 cmp qword ptr [rdi+N_RANK],-1
 jne .R_layout_bfs_edge_next
 lea rax,[r15+1]
 mov [rdi+N_RANK],rax
 mov rax,[rsp]
 mov [rbx+r13*8+R_QUEUE],rax
 inc r13
.R_layout_bfs_edge_next:
 inc rbp
 jmp .R_layout_bfs_edge
.R_layout_bfs_next:
 inc r12
 jmp .R_layout_bfs
.R_layout_rank_max:
 xor r12d,r12d
 xor r13d,r13d
.R_layout_rank_node:
 cmp r12,[rbx+R_NCOUNT]
 jae .R_layout_mode
 mov rdi,r12
 call .R_node_address
 mov rax,[rdi+N_RANK]
 test rax,rax
 jns .R_layout_max_update
 xor eax,eax
 mov [rdi+N_RANK],rax
.R_layout_max_update:
 cmp rax,r13
 cmova r13,rax
 inc r12
 jmp .R_layout_rank_node
.R_layout_mode:
 mov [rbx+R_MAXRANK],r13
 inc r13
 mov [rbx+R_RANKS],r13
 mov qword ptr [rbx+R_HORIZONTAL],0
 cmp qword ptr [rbx+R_NCOUNT],8
 ja .R_layout_vertical
 mov ax,[rbx+R_DIR]
 cmp ax,0x524c
 je .R_layout_try_horizontal
 cmp ax,0x4c52
 jne .R_layout_vertical
.R_layout_try_horizontal:
 mov rax,[rbx+R_COLS]
 lea rcx,[r13-1]
 shl rcx,2
 sub rax,rcx
 jbe .R_layout_vertical
 xor edx,edx
 div r13
 cmp rax,24
 jbe .R_layout_column_min
 mov eax,24
.R_layout_column_min:
 cmp rax,10
 jae .R_layout_column_width
 mov eax,10
.R_layout_column_width:
 mov [rbx+R_CWIDTH],rax
 imul rax,r13
 lea rcx,[r13-1]
 shl rcx,2
 add rax,rcx
 cmp rax,[rbx+R_COLS]
 ja .R_layout_vertical
 mov rcx,[rbx+R_COLS]
 sub rcx,rax
 shr rcx,1
 mov [rsp+8],rcx
 mov qword ptr [rbx+R_HORIZONTAL],1
 jmp .R_layout_layers
.R_layout_vertical:
 mov qword ptr [rsp+8],0
.R_layout_layers:
 mov qword ptr [rsp+16],0
 xor r12d,r12d
 mov qword ptr [rbx+R_CHEIGHT],0
.R_layout_layer:
 cmp r12,[rbx+R_RANKS]
 jae .R_layout_done
 xor r13d,r13d
 xor r14d,r14d
.R_layout_collect_layer:
 cmp r14,[rbx+R_NCOUNT]
 jae .R_layout_sort_layer
 mov rdi,r14
 call .R_node_address
 cmp [rdi+N_RANK],r12
 jne .R_layout_collect_next
 mov [rbx+r13*8+R_LAYER],r14
 inc r13
.R_layout_collect_next:
 inc r14
 jmp .R_layout_collect_layer
.R_layout_sort_layer:
 # Stable insertion sort by branch preference; stable node insertion is tiebreak.
 mov r14d,1
.R_layer_sort_outer:
 cmp r14,r13
 jae .R_layout_measure_layer
 mov r15,r14
.R_layer_sort_inner:
 test r15,r15
 jz .R_layer_sort_next
 mov rdi,[rbx+r15*8+R_LAYER]
 call .R_node_address
 mov rbp,[rdi+N_PREF]
 mov rdi,[rbx+r15*8+R_LAYER-8]
 call .R_node_address
 cmp rbp,[rdi+N_PREF]
 jge .R_layer_sort_next
 mov rax,[rbx+r15*8+R_LAYER]
 mov rcx,[rbx+r15*8+R_LAYER-8]
 mov [rbx+r15*8+R_LAYER],rcx
 mov [rbx+r15*8+R_LAYER-8],rax
 dec r15
 jmp .R_layer_sort_inner
.R_layer_sort_next:
 inc r14
 jmp .R_layer_sort_outer
.R_layout_measure_layer:
 mov rax,[rbx+R_COLS]
 cmp qword ptr [rbx+R_HORIZONTAL],0
 jne .R_layout_measure_horizontal
 lea rcx,[r13-1]
 shl rcx,2
 sub rax,rcx
 jbe .R_layout_impossible
 xor edx,edx
 div r13
 cmp rax,8
 jae .R_layout_vertical_max
 mov eax,8
.R_layout_vertical_max:
 cmp rax,28
 jbe .R_layout_measure_limit
 mov eax,28
 jmp .R_layout_measure_limit
.R_layout_measure_horizontal:
 mov rax,[rbx+R_CWIDTH]
.R_layout_measure_limit:
 mov [rsp+24],rax
 xor r14d,r14d
 xor r15d,r15d
 xor ebp,ebp
.R_layout_measure_each:
 cmp r14,r13
 jae .R_layout_place_start
 mov rdi,[rbx+r14*8+R_LAYER]
 call .R_node_address
 mov rsi,[rsp+24]
 call .R_measure_node
 test rax,rax
 js .R_layout_return
 mov rdi,[rbx+r14*8+R_LAYER]
 call .R_node_address
 add r15,[rdi+N_W]
 mov rax,[rdi+N_H]
 cmp rax,rbp
 cmova rbp,rax
 inc r14
 jmp .R_layout_measure_each
.R_layout_place_start:
 cmp qword ptr [rbx+R_HORIZONTAL],0
 jne .R_layout_place_horizontal
 lea rax,[r13-1]
 shl rax,2
 add r15,rax
 mov rax,[rbx+R_COLS]
 sub rax,r15
 jns .R_layout_x_nonnegative
 xor eax,eax
.R_layout_x_nonnegative:
 shr rax,1
 mov r15,rax
 jmp .R_layout_place_vertical
.R_layout_place_horizontal:
 mov r15,[rsp+8]
 mov qword ptr [rsp+16],0
.R_layout_place_vertical:
 xor r14d,r14d
.R_layout_place_node:
 cmp r14,r13
 jae .R_layout_layer_next
 mov rdi,[rbx+r14*8+R_LAYER]
 call .R_node_address
 mov rax,r15
 cmp qword ptr [rbx+R_HORIZONTAL],0
 je .R_layout_set_x
 mov rcx,[rbx+R_CWIDTH]
 sub rcx,[rdi+N_W]
 sar rcx,1
 add rax,rcx
.R_layout_set_x:
 mov [rdi+N_X],rax
 mov rdx,[rdi+N_W]
 shr rdx,1
 add rdx,rax
 mov [rdi+N_CX],rdx
 mov rax,[rsp+16]
 mov [rdi+N_Y],rax
 mov rdx,[rdi+N_H]
 shr rdx,1
 add rdx,rax
 mov [rdi+N_CY],rdx
 add rax,[rdi+N_H]
 cmp rax,[rbx+R_CHEIGHT]
 jbe .R_layout_height_set
 mov [rbx+R_CHEIGHT],rax
.R_layout_height_set:
 cmp qword ptr [rbx+R_HORIZONTAL],0
 jne .R_layout_stack_node
 add r15,[rdi+N_W]
 add r15,4
 jmp .R_layout_place_next
.R_layout_stack_node:
 mov rax,[rdi+N_H]
 add rax,4
 add [rsp+16],rax
.R_layout_place_next:
 inc r14
 jmp .R_layout_place_node
.R_layout_layer_next:
 cmp qword ptr [rbx+R_HORIZONTAL],0
 jne .R_layout_next_column
 add rbp,4
 add [rsp+16],rbp
 jmp .R_layout_layer_increment
.R_layout_next_column:
 mov rax,[rbx+R_CWIDTH]
 add rax,4
 add [rsp+8],rax
.R_layout_layer_increment:
 inc r12
 jmp .R_layout_layer
.R_layout_done:
 mov rax,[rbx+R_CHEIGHT]
 inc rax
 cmp rax,R_HEIGHT_MAX
 jbe .R_layout_height_final
 mov eax,R_HEIGHT_MAX
 mov qword ptr [rbx+R_WARNING],1
.R_layout_height_final:
 mov [rbx+R_CHEIGHT],rax
 xor eax,eax
 jmp .R_layout_return
.R_layout_impossible:
 mov rax,-90
.R_layout_return:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
# Canvas cells{UTF8span pointer,length32,continuation32}; wide clusters never split.
.R_glyph:
 test rdi,rdi
 js .R_glyph_done
 test rsi,rsi
 js .R_glyph_done
 cmp rdi,[rbx+R_COLS]
 jae .R_glyph_done
 cmp rsi,[rbx+R_CHEIGHT]
 jae .R_glyph_done
 mov rax,rsi
 imul rax,[rbx+R_COLS]
 add rax,rdi
 shl rax,4
 lea r9,[rbx+R_CANVAS]
 add r9,rax
 test r8,r8
 jnz .R_glyph_store
 cmp dword ptr [r9+12],1
 je .R_glyph_done
 mov r10,[r9]
 lea r11,[rip+.r_down]
 cmp rdx,r11
 je .R_glyph_store
 cmp r10,r11
 je .R_glyph_done
 lea r11,[rip+.r_right_arrow]
 cmp rdx,r11
 je .R_glyph_store
 cmp r10,r11
 je .R_glyph_done
 lea r11,[rip+.r_left_arrow]
 cmp rdx,r11
 je .R_glyph_store
 cmp r10,r11
 je .R_glyph_done
 lea r11,[rip+.r_cross]
 cmp r10,r11
 je .R_glyph_done
 lea rax,[rip+.r_vertical]
 cmp r10,rax
 jne .R_glyph_horizontal_existing
 lea rax,[rip+.r_horizontal]
 cmp rdx,rax
 jne .R_glyph_store
 mov rdx,r11
 jmp .R_glyph_store
.R_glyph_horizontal_existing:
 lea rax,[rip+.r_horizontal]
 cmp r10,rax
 jne .R_glyph_store
 lea rax,[rip+.r_vertical]
 cmp rdx,rax
 jne .R_glyph_store
 mov rdx,r11
.R_glyph_store:
 mov [r9],rdx
 mov [r9+8],ecx
 mov dword ptr [r9+12],0
.R_glyph_done:
 ret
.R_canvas_text:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,rcx
 mov [rsp],r8
 xor ebp,ebp
.R_canvas_cluster:
 cmp rbp,r15
 jae .R_canvas_text_done
 mov rdi,r14
 mov rsi,r15
 mov rdx,rbp
 call ui_next_grapheme
 mov [rsp+8],rax
 lea rdi,[r14+rbp]
 mov rsi,rax
 sub rsi,rbp
 call ui_text_width
 cmp rax,1
 jae .R_canvas_width
 mov eax,1
.R_canvas_width:
 mov [rsp+16],rax
 mov rdi,r12
 mov rsi,r13
 lea rdx,[r14+rbp]
 mov rcx,[rsp+8]
 sub rcx,rbp
 mov r8,[rsp]
 call .R_glyph
 mov rax,[rsp+16]
 cmp rax,1
 jbe .R_canvas_advance
 mov ecx,1
.R_canvas_continuation:
 cmp rcx,rax
 jae .R_canvas_advance
 lea rdx,[r12+rcx]
 cmp rdx,[rbx+R_COLS]
 jae .R_canvas_cont_next
 cmp r13,[rbx+R_CHEIGHT]
 jae .R_canvas_cont_next
 mov rsi,r13
 imul rsi,[rbx+R_COLS]
 add rsi,rdx
 shl rsi,4
 mov qword ptr [rbx+rsi+R_CANVAS],0
 mov dword ptr [rbx+rsi+R_CANVAS+8],0
 mov dword ptr [rbx+rsi+R_CANVAS+12],1
.R_canvas_cont_next:
 inc rcx
 jmp .R_canvas_continuation
.R_canvas_advance:
 add r12,[rsp+16]
 mov rbp,[rsp+8]
 jmp .R_canvas_cluster
.R_canvas_text_done:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_hline:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 cmp r12,r14
 jle .R_hline_loop
 xchg r12,r14
.R_hline_loop:
 cmp r12,r14
 jg .R_hline_done
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.r_horizontal]
 mov ecx,3
 xor r8d,r8d
 call .R_glyph
 inc r12
 jmp .R_hline_loop
.R_hline_done:
 pop r14
 pop r13
 pop r12
 ret
.R_vline:
 push r12
 push r13
 push r14
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 cmp r13,r14
 jle .R_vline_loop
 xchg r13,r14
.R_vline_loop:
 cmp r13,r14
 jg .R_vline_done
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.r_vertical]
 mov ecx,3
 xor r8d,r8d
 call .R_glyph
 inc r13
 jmp .R_vline_loop
.R_vline_done:
 pop r14
 pop r13
 pop r12
 ret
.R_draw_node:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 xor r13d,r13d
.R_draw_node_row:
 cmp r13,[r12+N_H]
 jae .R_draw_node_done
 xor r14d,r14d
.R_draw_node_clear:
 cmp r14,[r12+N_W]
 jae .R_draw_node_borders
 mov rdi,[r12+N_X]
 add rdi,r14
 mov rsi,[r12+N_Y]
 add rsi,r13
 lea rdx,[rip+.r_space]
 mov ecx,1
 mov r8d,1
 call .R_glyph
 inc r14
 jmp .R_draw_node_clear
.R_draw_node_borders:
 mov r14,[r12+N_X]
 mov r15,[r12+N_Y]
 add r15,r13
 mov rbp,[r12+N_W]
 cmp qword ptr [r12+N_SHAPE],2
 jne .R_draw_node_normal_positions
 inc r14
 sub rbp,2
.R_draw_node_normal_positions:
 test r13,r13
 jz .R_draw_node_top
 mov rax,[r12+N_H]
 dec rax
 cmp r13,rax
 je .R_draw_node_bottom
 lea rdx,[rip+.r_vertical]
 cmp qword ptr [r12+N_SHAPE],2
 jne .R_draw_node_middle_border
 lea rdx,[rip+.r_diamond]
.R_draw_node_middle_border:
 mov [rsp],rdx
 mov rdi,r14
 mov rsi,r15
 mov ecx,3
 mov r8d,1
 call .R_glyph
 lea rdi,[r14+rbp-1]
 mov rsi,r15
 mov rdx,[rsp]
 mov ecx,3
 mov r8d,1
 call .R_glyph
 mov rax,r13
 dec rax
 shl rax,4
 mov rdi,[r12+rax+N_LABEL_LINES]
 mov rsi,[r12+rax+N_LABEL_LINES+8]
 mov [rsp+8],rdi
 mov [rsp+16],rsi
 call ui_text_width
 mov rdx,rbp
 sub rdx,4
 sub rdx,rax
 sar rdx,1
 lea rdi,[r14+rdx+2]
 mov rsi,r15
 mov rdx,[rsp+8]
 mov rcx,[rsp+16]
 mov r8d,1
 call .R_canvas_text
 jmp .R_draw_node_next
.R_draw_node_top:
 lea rdx,[rip+.r_top_left]
 lea rax,[rip+.r_top_right]
 cmp qword ptr [r12+N_SHAPE],1
 jne .R_draw_node_top_diamond
 lea rdx,[rip+.r_round_top_left]
 lea rax,[rip+.r_round_top_right]
.R_draw_node_top_diamond:
 cmp qword ptr [r12+N_SHAPE],2
 jne .R_draw_node_box
 lea rdx,[rip+.r_diag_up]
 lea rax,[rip+.r_diag_down]
 jmp .R_draw_node_box
.R_draw_node_bottom:
 lea rdx,[rip+.r_bottom_left]
 lea rax,[rip+.r_bottom_right]
 cmp qword ptr [r12+N_SHAPE],1
 jne .R_draw_node_bottom_diamond
 lea rdx,[rip+.r_round_bottom_left]
 lea rax,[rip+.r_round_bottom_right]
.R_draw_node_bottom_diamond:
 cmp qword ptr [r12+N_SHAPE],2
 jne .R_draw_node_box
 lea rdx,[rip+.r_diag_down]
 lea rax,[rip+.r_diag_up]
.R_draw_node_box:
 mov [rsp],rax
 mov rdi,r14
 mov rsi,r15
 mov ecx,3
 mov r8d,1
 call .R_glyph
 lea rdi,[r14+1]
 mov rsi,r15
 lea rdx,[r14+rbp-2]
 call .R_hline
 lea rdi,[r14+rbp-1]
 mov rsi,r15
 mov rdx,[rsp]
 mov ecx,3
 mov r8d,1
 call .R_glyph
.R_draw_node_next:
 inc r13
 jmp .R_draw_node_row
.R_draw_node_done:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
# Temporary label rendering used by edge labels; no escape data is introduced.
.R_stable_label:
 mov rcx,[rbx+R_TLEN]
 cmp rcx,448
 ja .R_stable_too_large
 mov [rdi+32],rcx
 add rdi,64
 lea rsi,[rbx+R_TEXTBUF]
 rep movsb
 ret
.R_stable_too_large:
 mov qword ptr [rdi+32],0
 mov qword ptr [rbx+R_WARNING],1
 ret
.R_edge_label:
 sub rsp,8
 call .R_treset
 call .R_fit_label
 add rsp,8
 ret
# fromnode,toNode,edge ->standard forward vertical connection.
.R_vertical_edge:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov r15,[r12+N_Y]
 add r15,[r12+N_H]
 mov rbp,[r13+N_Y]
 dec rbp
 mov [rsp],rbp
 lea rax,[r15+rbp]
 sar rax,1
 cmp rax,r15
 cmovl rax,r15
 mov [rsp+8],rax
 mov rax,[r12+N_CX]
 sub rax,[r13+N_CX]
 mov rcx,rax
 sar rcx,63
 xor rax,rcx
 sub rax,rcx
 cmp rax,1
 ja .R_vertical_bend
 mov rdi,[r12+N_CX]
 mov rsi,r15
 mov rdx,rbp
 call .R_vline
 mov rdi,[r12+N_CX]
 mov rsi,rbp
 lea rdx,[rip+.r_down]
 mov ecx,3
 xor r8d,r8d
 call .R_glyph
 cmp qword ptr [r14+24],0
 je .R_vertical_edge_done
 mov rdi,[r14+16]
 mov rsi,[r14+24]
 mov edx,14
 call .R_edge_label
 mov rdi,r14
 call .R_stable_label
 mov rdi,[r12+N_CX]
 add rdi,2
 mov rax,[rbx+R_COLS]
 dec rax
 cmp rdi,rax
 cmovg rdi,rax
 mov rsi,[rsp+8]
 lea rdx,[r14+64]
 mov rcx,[r14+32]
 mov r8d,1
 call .R_canvas_text
 jmp .R_vertical_edge_done
.R_vertical_bend:
 mov rbp,[rsp+8]
 mov rax,[rsp]
 dec rax
 cmp rbp,rax
 cmovg rbp,rax
 cmp rbp,r15
 cmovl rbp,r15
 mov [rsp+8],rbp
 mov rdi,[r12+N_CX]
 mov rsi,r15
 mov rdx,rbp
 call .R_vline
 mov rdi,[r12+N_CX]
 mov rsi,rbp
 mov rdx,[r13+N_CX]
 call .R_hline
 mov rdi,[r13+N_CX]
 lea rsi,[rbp+1]
 mov rdx,[rsp]
 cmp rsi,rdx
 jg .R_vertical_bend_corners
 call .R_vline
.R_vertical_bend_corners:
 lea rdx,[rip+.r_bottom_right]
 lea rax,[rip+.r_top_left]
 mov rcx,[r13+N_CX]
 cmp rcx,[r12+N_CX]
 jle .R_vertical_bend_left
 lea rdx,[rip+.r_bottom_left]
 lea rax,[rip+.r_top_right]
.R_vertical_bend_left:
 mov [rsp+16],rax
 mov rdi,[r12+N_CX]
 mov rsi,rbp
 mov ecx,3
 mov r8d,1
 call .R_glyph
 mov rdi,[r13+N_CX]
 mov rsi,rbp
 mov rdx,[rsp+16]
 mov ecx,3
 mov r8d,1
 call .R_glyph
 mov rdi,[r13+N_CX]
 mov rsi,[rsp]
 lea rdx,[rip+.r_down]
 mov ecx,3
 xor r8d,r8d
 call .R_glyph
 cmp qword ptr [r14+24],0
 je .R_vertical_edge_done
 mov rdi,[r14+16]
 mov rsi,[r14+24]
 mov edx,14
 call .R_edge_label
 mov rdi,r14
 call .R_stable_label
 mov rdi,[r12+N_CX]
 add rdi,2
 mov rax,[rbx+R_COLS]
 sub rax,[rbx+R_TLEN]
 cmp rdi,rax
 cmovg rdi,rax
 mov rsi,[rsp+8]
 lea rdx,[r14+64]
 mov rcx,[r14+32]
 mov r8d,1
 call .R_canvas_text
.R_vertical_edge_done:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_horizontal_edge:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,32
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov rax,[r13+N_RANK]
 cmp rax,[r12+N_RANK]
 jle .R_horizontal_back
 mov r15,[r12+N_X]
 add r15,[r12+N_W]
 mov rbp,[r13+N_X]
 dec rbp
 lea rax,[rip+.r_right_arrow]
 jmp .R_horizontal_points
.R_horizontal_back:
 mov r15,[r12+N_X]
 dec r15
 mov rbp,[r13+N_X]
 add rbp,[r13+N_W]
 lea rax,[rip+.r_left_arrow]
.R_horizontal_points:
 mov [rsp],rax
 lea rax,[r15+rbp]
 sar rax,1
 mov [rsp+8],rax
 mov rdi,r15
 mov rsi,[r12+N_CY]
 mov rdx,rbp
 mov rax,[r13+N_CY]
 cmp rax,rsi
 je .R_horizontal_straight
 mov rdx,[rsp+8]
 call .R_hline
 mov rdi,[rsp+8]
 mov rsi,[r12+N_CY]
 mov rdx,[r13+N_CY]
 call .R_vline
 mov rdi,[rsp+8]
 mov rsi,[r13+N_CY]
 mov rdx,rbp
.R_horizontal_straight:
 call .R_hline
 mov rdi,rbp
 mov rsi,[r13+N_CY]
 mov rdx,[rsp]
 mov ecx,3
 xor r8d,r8d
 call .R_glyph
 cmp qword ptr [r14+24],0
 je .R_horizontal_done
 mov rdi,[r14+16]
 mov rsi,[r14+24]
 mov edx,12
 call .R_edge_label
 mov rdi,r14
 call .R_stable_label
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call ui_text_width
 shr rax,1
 mov rdi,[rsp+8]
 sub rdi,rax
 test rdi,rdi
 jns .R_horizontal_label_x
 xor edi,edi
.R_horizontal_label_x:
 mov rsi,[r12+N_CY]
 mov rax,[r13+N_CY]
 cmp rax,rsi
 cmovl rsi,rax
 lea rdx,[r14+64]
 mov rcx,[r14+32]
 mov r8d,1
 call .R_canvas_text
.R_horizontal_done:
 add rsp,32
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_outdegree:
 xor eax,eax
 xor ecx,ecx
.R_outdegree_loop:
 cmp rcx,[rbx+R_ECOUNT]
 jae .R_outdegree_done
 mov r8,rcx
 shl r8,9
 cmp [rbx+r8+R_EDGEBUF],rdi
 jne .R_outdegree_next
 inc rax
.R_outdegree_next:
 inc rcx
 jmp .R_outdegree_loop
.R_outdegree_done:
 ret
.R_vertical_fork:
 push r12
 push r13
 push r14
 push r15
 push rbp
 sub rsp,64
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 xor r15d,r15d
.R_fork_collect:
 cmp r15,[rbx+R_ECOUNT]
 jae .R_fork_collected
 mov rax,r15
 shl rax,9
 lea rbp,[rbx+R_EDGEBUF]
 add rbp,rax
 cmp [rbp],r13
 jne .R_fork_collect_next
 mov rdi,[rbp+8]
 call .R_node_address
 mov rax,[rdi+N_RANK]
 cmp rax,[r12+N_RANK]
 jle .R_fork_collect_next
 mov [rbx+r14*8+R_LAYER],r15
 inc r14
.R_fork_collect_next:
 inc r15
 jmp .R_fork_collect
.R_fork_collected:
 test r14,r14
 jz .R_fork_done
 cmp r14,1
 jne .R_fork_sort_start
 mov rax,[rbx+R_LAYER]
 shl rax,9
 lea rdx,[rbx+R_EDGEBUF]
 add rdx,rax
 mov [rsp],rdx
 mov rdi,[rdx+8]
 call .R_node_address
 mov rsi,rdi
 mov rdi,r12
 mov rdx,[rsp]
 call .R_vertical_edge
 jmp .R_fork_done
.R_fork_sort_start:
 mov [rsp],r14
 mov r14d,1
.R_fork_sort_outer:
 cmp r14,[rsp]
 jae .R_fork_dimensions
 mov r15,r14
.R_fork_sort_inner:
 test r15,r15
 jz .R_fork_sort_next
 mov rax,[rbx+r15*8+R_LAYER]
 shl rax,9
 mov rdi,[rbx+rax+R_EDGEBUF+8]
 call .R_node_address
 mov rbp,[rdi+N_CX]
 mov rax,[rbx+r15*8+R_LAYER-8]
 shl rax,9
 mov rdi,[rbx+rax+R_EDGEBUF+8]
 call .R_node_address
 cmp rbp,[rdi+N_CX]
 jge .R_fork_sort_next
 mov rax,[rbx+r15*8+R_LAYER]
 mov rcx,[rbx+r15*8+R_LAYER-8]
 mov [rbx+r15*8+R_LAYER],rcx
 mov [rbx+r15*8+R_LAYER-8],rax
 dec r15
 jmp .R_fork_sort_inner
.R_fork_sort_next:
 inc r14
 jmp .R_fork_sort_outer
.R_fork_dimensions:
 mov rax,[r12+N_Y]
 add rax,[r12+N_H]
 mov [rsp+8],rax
 mov r15,0x7fffffff
 xor r14d,r14d
.R_fork_top_min:
 cmp r14,[rsp]
 jae .R_fork_points
 mov rax,[rbx+r14*8+R_LAYER]
 shl rax,9
 mov rdi,[rbx+rax+R_EDGEBUF+8]
 call .R_node_address
 mov rax,[rdi+N_Y]
 cmp rax,r15
 cmovl r15,rax
 inc r14
 jmp .R_fork_top_min
.R_fork_points:
 lea rax,[r15-3]
 cmp rax,[rsp+8]
 cmovl rax,[rsp+8]
 mov [rsp+16],rax
 inc rax
 sub r15,2
 cmp rax,r15
 cmovg rax,r15
 mov [rsp+24],rax
 mov rax,[rbx+R_LAYER]
 shl rax,9
 mov rdi,[rbx+rax+R_EDGEBUF+8]
 call .R_node_address
 mov rax,[rdi+N_CX]
 mov [rsp+48],rax
 mov rcx,[rsp]
 dec rcx
 mov rax,[rbx+rcx*8+R_LAYER]
 shl rax,9
 mov rdi,[rbx+rax+R_EDGEBUF+8]
 call .R_node_address
 mov rax,[rdi+N_CX]
 mov [rsp+56],rax
 mov rdi,[r12+N_CX]
 mov rsi,[rsp+8]
 mov rdx,[rsp+16]
 call .R_vline
 mov rdi,[rsp+48]
 mov rsi,[rsp+16]
 mov rdx,[rsp+56]
 call .R_hline
 mov rdi,[r12+N_CX]
 mov rsi,[rsp+16]
 lea rdx,[rip+.r_bottom_junction]
 mov ecx,3
 mov r8d,1
 call .R_glyph
 xor r14d,r14d
.R_fork_target:
 cmp r14,[rsp]
 jae .R_fork_done
 mov rax,[rbx+r14*8+R_LAYER]
 shl rax,9
 lea r15,[rbx+R_EDGEBUF]
 add r15,rax
 mov rdi,[r15+8]
 call .R_node_address
 mov rbp,rdi
 mov rax,[rbp+N_Y]
 dec rax
 mov [rsp+32],rax
 mov rdi,[rbp+N_CX]
 mov rsi,[rsp+16]
 lea rdx,[rip+.r_top_junction]
 test r14,r14
 jnz .R_fork_corner_last
 lea rdx,[rip+.r_top_left]
 jmp .R_fork_corner
.R_fork_corner_last:
 lea rax,[r14+1]
 cmp rax,[rsp]
 jne .R_fork_corner
 lea rdx,[rip+.r_top_right]
.R_fork_corner:
 mov ecx,3
 mov r8d,1
 call .R_glyph
 mov rdi,[rbp+N_CX]
 mov rsi,[rsp+32]
 lea rdx,[rip+.r_down]
 mov ecx,3
 xor r8d,r8d
 call .R_glyph
 cmp qword ptr [r15+24],0
 je .R_fork_target_stems
 call .R_treset
 lea rdi,[rip+.r_bracket_open]
 mov esi,1
 call .R_tput
 mov rdi,[r15+16]
 mov rsi,[r15+24]
 mov edx,10
 call .R_fit_label
 lea rdi,[rip+.r_bracket_close]
 mov esi,1
 call .R_tput
 mov rdi,r15
 call .R_stable_label
 lea rdi,[r15+64]
 mov rsi,[r15+32]
 call ui_text_width
 mov rdi,[rbp+N_CX]
 mov rdx,rax
 shr rdx,1
 sub rdi,rdx
 mov rdx,[rbx+R_COLS]
 sub rdx,rax
 cmp rdi,rdx
 cmovg rdi,rdx
 test rdi,rdi
 jns .R_fork_label_x
 xor edi,edi
.R_fork_label_x:
 mov rsi,[rsp+24]
 lea rdx,[r15+64]
 mov rcx,[r15+32]
 mov r8d,1
 call .R_canvas_text
.R_fork_target_stems:
 mov rdi,[rbp+N_CX]
 mov rsi,[rsp+16]
 inc rsi
 mov rdx,[rsp+24]
 dec rdx
 cmp rsi,rdx
 jg .R_fork_target_lower
 call .R_vline
.R_fork_target_lower:
 mov rdi,[rbp+N_CX]
 mov rsi,[rsp+24]
 inc rsi
 mov rdx,[rsp+32]
 cmp rsi,rdx
 jg .R_fork_target_next
 call .R_vline
.R_fork_target_next:
 inc r14
 jmp .R_fork_target
.R_fork_done:
 add rsp,64
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret
.R_flow_title:
 sub rsp,8
 call .R_treset
 lea rdi,[rip+.r_flow_title]
 mov esi,OFFSET FLAT:.r_flow_title_len
 call .R_tput
 lea rdi,[rbx+R_DIR]
 mov esi,2
 call .R_tput
 lea rdi,[rip+.r_paren]
 mov esi,1
 call .R_tput
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call .R_title
 add rsp,8
 ret
.R_flow_draw:
 push r12
 push r13
 push r14
 push r15
 push rbp
 mov rax,[rbx+R_COLS]
 imul rax,[rbx+R_CHEIGHT]
 lea rdi,[rbx+R_CANVAS]
 mov rcx,rax
 shl rcx,1
 xor eax,eax
 rep stosq
 xor r12d,r12d
.R_flow_edge:
 cmp r12,[rbx+R_ECOUNT]
 jae .R_flow_forks
 mov rax,r12
 shl rax,9
 lea r13,[rbx+R_EDGEBUF]
 add r13,rax
 mov rdi,[r13]
 call .R_node_address
 mov r14,rdi
 mov rdi,[r13+8]
 call .R_node_address
 mov r15,rdi
 mov rax,[r15+N_RANK]
 cmp qword ptr [rbx+R_HORIZONTAL],0
 je .R_flow_vertical_choice
 cmp rax,[r14+N_RANK]
 je .R_flow_vertical_choice
 mov rdi,r14
 mov rsi,r15
 mov rdx,r13
 call .R_horizontal_edge
 jmp .R_flow_edge_next
.R_flow_vertical_choice:
 cmp rax,[r14+N_RANK]
 jle .R_flow_edge_next
 cmp qword ptr [rbx+R_HORIZONTAL],0
 jne .R_flow_single_vertical
 mov rdi,[r13]
 call .R_outdegree
 cmp rax,1
 ja .R_flow_edge_next
.R_flow_single_vertical:
 mov rdi,r14
 mov rsi,r15
 mov rdx,r13
 call .R_vertical_edge
.R_flow_edge_next:
 inc r12
 jmp .R_flow_edge
.R_flow_forks:
 cmp qword ptr [rbx+R_HORIZONTAL],0
 jne .R_flow_nodes
 xor r12d,r12d
.R_flow_fork_node:
 cmp r12,[rbx+R_NCOUNT]
 jae .R_flow_nodes
 mov rdi,r12
 call .R_outdegree
 cmp rax,1
 jbe .R_flow_fork_next
 mov rdi,r12
 call .R_node_address
 mov rsi,r12
 call .R_vertical_fork
.R_flow_fork_next:
 inc r12
 jmp .R_flow_fork_node
.R_flow_nodes:
 xor r12d,r12d
.R_flow_node:
 cmp r12,[rbx+R_NCOUNT]
 jae .R_flow_canvas
 mov rdi,r12
 call .R_node_address
 call .R_draw_node
 inc r12
 jmp .R_flow_node
.R_flow_canvas:
 xor r12d,r12d
.R_flow_canvas_row:
 cmp r12,[rbx+R_CHEIGHT]
 jae .R_flow_cycles
 mov rax,r12
 imul rax,[rbx+R_COLS]
 shl rax,4
 lea r13,[rbx+R_CANVAS]
 add r13,rax
 mov r14,[rbx+R_COLS]
.R_flow_trim_row:
 test r14,r14
 jz .R_flow_row_start
 mov rax,r14
 dec rax
 shl rax,4
 cmp dword ptr [r13+rax+12],1
 je .R_flow_trim_one
 cmp dword ptr [r13+rax+8],0
 je .R_flow_trim_one
 mov rdx,[r13+rax]
 cmp dword ptr [r13+rax+8],1
 jne .R_flow_row_start
 cmp byte ptr [rdx],' '
 jne .R_flow_row_start
.R_flow_trim_one:
 dec r14
 jmp .R_flow_trim_row
.R_flow_row_start:
 call .R_treset
 xor r15d,r15d
.R_flow_row_cell:
 cmp r15,r14
 jae .R_flow_row_output
 mov rax,r15
 shl rax,4
 mov rdi,[r13+rax]
 mov esi,[r13+rax+8]
 test rsi,rsi
 jnz .R_flow_row_append
 cmp dword ptr [r13+rax+12],1
 je .R_flow_row_next
 lea rdi,[rip+.r_space]
 mov esi,1
.R_flow_row_append:
 call .R_tput
.R_flow_row_next:
 inc r15
 jmp .R_flow_row_cell
.R_flow_row_output:
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call .R_line
 inc r12
 jmp .R_flow_canvas_row
.R_flow_cycles:
 xor r12d,r12d
 xor ebp,ebp
.R_flow_cycle_edge:
 cmp r12,[rbx+R_ECOUNT]
 jae .R_flow_warning
 mov rax,r12
 shl rax,9
 lea r13,[rbx+R_EDGEBUF]
 add r13,rax
 mov rdi,[r13]
 call .R_node_address
 mov r14,[rdi+N_RANK]
 mov rdi,[r13+8]
 call .R_node_address
 mov rax,[rdi+N_RANK]
 cmp rax,r14
 jg .R_flow_cycle_next
 cmp qword ptr [rbx+R_HORIZONTAL],0
 je .R_flow_cycle_note
 cmp rax,r14
 jne .R_flow_cycle_next
.R_flow_cycle_note:
 test rbp,rbp
 jnz .R_flow_cycle_text
 RLINE .r_empty
 RLINE .r_cycles
 mov ebp,1
.R_flow_cycle_text:
 call .R_treset
 lea rdi,[rip+.r_two_spaces]
 mov esi,2
 call .R_tput
 mov rdi,[r13]
 call .R_tnode
 cmp qword ptr [r13+24],0
 je .R_flow_cycle_arrow
 lea rdi,[rip+.r_space_bracket]
 mov esi,2
 call .R_tput
 mov rdi,[r13+16]
 mov rsi,[r13+24]
 call .R_tput
 lea rdi,[rip+.r_bracket_close]
 mov esi,1
 call .R_tput
.R_flow_cycle_arrow:
 lea rdi,[rip+.r_cycle_arrow]
 mov esi,OFFSET FLAT:.r_cycle_arrow_len
 call .R_tput
 mov rdi,[r13+8]
 call .R_tnode
 lea rdi,[rbx+R_TEXTBUF]
 mov rsi,[rbx+R_TLEN]
 call .R_line
.R_flow_cycle_next:
 inc r12
 jmp .R_flow_cycle_edge
.R_flow_warning:
 cmp qword ptr [rbx+R_WARNING],0
 je .R_flow_draw_done
 RLINE .r_limit_warning
.R_flow_draw_done:
 pop rbp
 pop r15
 pop r14
 pop r13
 pop r12
 ret

.section .rodata
.r_space: .asciz " "
.equ .r_space_len,.-.r_space-1
.r_two_spaces: .asciz "  "
.equ .r_two_spaces_len,.-.r_two_spaces-1
.r_lf: .asciz "\012"
.equ .r_lf_len,.-.r_lf-1
.r_empty: .asciz ""
.equ .r_empty_len,.-.r_empty-1
.r_ellipsis: .asciz "\342\200\246"
.equ .r_ellipsis_len,.-.r_ellipsis-1
.r_reset: .asciz "\033[0m"
.equ .r_reset_len,.-.r_reset-1
.r_flowchart_key: .asciz "flowchart"
.equ .r_flowchart_key_len,.-.r_flowchart_key-1
.r_graph_key: .asciz "graph"
.equ .r_graph_key_len,.-.r_graph_key-1
.r_sequence_key: .asciz "sequenceDiagram"
.equ .r_sequence_key_len,.-.r_sequence_key-1
.r_class_key: .asciz "classDiagram"
.equ .r_class_key_len,.-.r_class_key-1
.r_participant_key: .asciz "participant"
.equ .r_participant_key_len,.-.r_participant_key-1
.r_actor_key: .asciz "actor"
.equ .r_actor_key_len,.-.r_actor_key-1
.r_class_declare: .asciz "class"
.equ .r_class_declare_len,.-.r_class_declare-1
.r_sequence_title: .asciz "Mermaid sequence diagram"
.equ .r_sequence_title_len,.-.r_sequence_title-1
.r_class_title: .asciz "Mermaid class diagram"
.equ .r_class_title_len,.-.r_class_title-1
.r_source_title: .asciz "Mermaid source ("
.equ .r_source_title_len,.-.r_source_title-1
.r_flow_title: .asciz "Mermaid flowchart ("
.equ .r_flow_title_len,.-.r_flow_title-1
.r_paren: .asciz ")"
.equ .r_paren_len,.-.r_paren-1
.r_unknown: .asciz "unknown"
.equ .r_unknown_len,.-.r_unknown-1
.r_source_hint: .asciz " \302\267 source: /copy mermaid "
.equ .r_source_hint_len,.-.r_source_hint-1
.r_fence: .asciz "```mermaid"
.equ .r_fence_len,.-.r_fence-1
.r_fence_end: .asciz "```"
.equ .r_fence_end_len,.-.r_fence_end-1
.r_fallback_warning: .asciz "Visual preview is not available; showing source so it remains readable and copyable."
.equ .r_fallback_warning_len,.-.r_fallback_warning-1
.r_limit_warning: .asciz "Native preview limit reached; complete source remains available with /copy mermaid."
.equ .r_limit_warning_len,.-.r_limit_warning-1
.r_header_separator: .asciz " | "
.equ .r_header_separator_len,.-.r_header_separator-1
.r_participants: .asciz "Participants: "
.equ .r_participants_len,.-.r_participants-1
.r_classes: .asciz "Classes: "
.equ .r_classes_len,.-.r_classes-1
.r_relationships: .asciz "Relationships:"
.equ .r_relationships_len,.-.r_relationships-1
.r_relationships_none: .asciz "Relationships: none previewed"
.equ .r_relationships_none_len,.-.r_relationships_none-1
.r_members: .asciz "Members:"
.equ .r_members_len,.-.r_members-1
.r_colon: .asciz ": "
.equ .r_colon_len,.-.r_colon-1
.r_arrow: .asciz " \342\206\222 "
.equ .r_arrow_len,.-.r_arrow-1
.r_dash_arrow: .asciz " \342\207\242 "
.equ .r_dash_arrow_len,.-.r_dash_arrow-1
.r_no: .asciz "no"
.equ .r_no_len,.-.r_no-1
.r_false: .asciz "false"
.equ .r_false_len,.-.r_false-1
.r_yes: .asciz "yes"
.equ .r_yes_len,.-.r_yes-1
.r_true: .asciz "true"
.equ .r_true_len,.-.r_true-1
.r_horizontal: .asciz "\342\224\200"
.equ .r_horizontal_len,.-.r_horizontal-1
.r_vertical: .asciz "\342\224\202"
.equ .r_vertical_len,.-.r_vertical-1
.r_cross: .asciz "\342\224\274"
.equ .r_cross_len,.-.r_cross-1
.r_top_left: .asciz "\342\224\214"
.equ .r_top_left_len,.-.r_top_left-1
.r_top_right: .asciz "\342\224\220"
.equ .r_top_right_len,.-.r_top_right-1
.r_bottom_left: .asciz "\342\224\224"
.equ .r_bottom_left_len,.-.r_bottom_left-1
.r_bottom_right: .asciz "\342\224\230"
.equ .r_bottom_right_len,.-.r_bottom_right-1
.r_round_top_left: .asciz "\342\225\255"
.equ .r_round_top_left_len,.-.r_round_top_left-1
.r_round_top_right: .asciz "\342\225\256"
.equ .r_round_top_right_len,.-.r_round_top_right-1
.r_round_bottom_left: .asciz "\342\225\260"
.equ .r_round_bottom_left_len,.-.r_round_bottom_left-1
.r_round_bottom_right: .asciz "\342\225\257"
.equ .r_round_bottom_right_len,.-.r_round_bottom_right-1
.r_diag_up: .asciz "\342\225\261"
.equ .r_diag_up_len,.-.r_diag_up-1
.r_diag_down: .asciz "\342\225\262"
.equ .r_diag_down_len,.-.r_diag_down-1
.r_diamond: .asciz "\342\227\207"
.equ .r_diamond_len,.-.r_diamond-1
.r_down: .asciz "\342\226\274"
.equ .r_down_len,.-.r_down-1
.r_right_arrow: .asciz "\342\226\266"
.equ .r_right_arrow_len,.-.r_right_arrow-1
.r_left_arrow: .asciz "\342\227\200"
.equ .r_left_arrow_len,.-.r_left_arrow-1
.r_top_junction: .asciz "\342\224\254"
.equ .r_top_junction_len,.-.r_top_junction-1
.r_bottom_junction: .asciz "\342\224\264"
.equ .r_bottom_junction_len,.-.r_bottom_junction-1
.r_bracket_open: .asciz "["
.equ .r_bracket_open_len,.-.r_bracket_open-1
.r_bracket_close: .asciz "]"
.equ .r_bracket_close_len,.-.r_bracket_close-1
.r_space_bracket: .asciz " ["
.equ .r_space_bracket_len,.-.r_space_bracket-1
.r_cycle_arrow: .asciz " \342\206\251 to "
.equ .r_cycle_arrow_len,.-.r_cycle_arrow-1
.r_cycles: .asciz "Cycles:"
.equ .r_cycles_len,.-.r_cycles-1
.balign 8
.include "ui_mermaid_palettes.inc"
.section .note.GNU-stack,"",@progbits
