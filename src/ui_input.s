# Stateful native input and Unicode layout. No I/O or application side effects.
.intel_syntax noprefix
.include "ui_abi.inc"
.equ C_BUF,0
.equ C_CAP,8
.equ C_LEN,16
.equ C_CUR,24
.equ C_ANCHOR,32
.equ C_MENU,40
.equ C_ESC,48
.equ C_ESCLEN,56
.equ C_ESCSTR,64
.equ C_UTF,136
.equ C_UTFN,144
.equ C_UTFNEED,152
.equ C_PASTE,160
.equ C_PEND,168
.equ C_PCR,176
.equ C_DIRTY,184
.equ C_UCOUNT,224
.equ C_UPOS,232
.equ C_USTART,240
.equ C_HCOUNT,272
.equ C_HINDEX,280
.equ C_HLENS,1024
.equ C_DRAFTLEN,352
.equ C_SEARCH,360
.equ C_SLEN,368
.equ C_SINDEX,376
.equ C_COLUMNS,384
.equ C_ROWS,392
.equ C_GOAL,400
.equ C_VCOUNT,408
.equ C_VROW,416
.equ C_VCOL,424
.equ C_IX,432
.equ C_VR,440
.equ C_VC,448
.equ C_END,456
.equ C_WIDTH,464
.equ C_TARGET,472
.equ C_HUP,520
.equ C_CONSUMED,528
.equ C_EXTERNAL_HISTORY,536
.equ C_MOUSE_BUTTON,544
.equ C_MOUSE_X,552
.equ C_MOUSE_Y,560
.equ C_MOUSE_RELEASE,568
.equ C_MOUSE_TEMP,584
.equ C_OSC_R,616
.equ C_OSC_G,624
.equ C_OSC_B,632
.equ C_OSC_VALID,640
.equ C_OSC_TEMP,648
.equ C_VSTART,1650000
.equ C_ULENS,2048
.equ C_UCURS,2184
.equ C_DRAFT,4096
.equ C_UNDO,131584
.equ C_HISTORY,1300000
.equ C_QUERY,1600000
.text
# Decode one UTF-8 scalar at index. Invalid encoding consumes one byte as U+FFFD.
# rdi ptr,rsi length,rdx index -> eax scalar,rdx next index.
.Ldecode:
 cmp rdx,rsi
 jae .Ldec_end
 movzx eax,byte ptr [rdi+rdx]
 inc rdx
 cmp eax,128
 jb .Ldec_ret
 mov r8d,eax
 mov ecx,1
 and eax,31
 cmp r8d,194
 jb .Ldec_bad
 cmp r8d,224
 jb .Ldec_more
 mov ecx,2
 and eax,15
 cmp r8d,240
 jb .Ldec_more
 mov ecx,3
 and eax,7
 cmp r8d,245
 jae .Ldec_bad
.Ldec_more:
 mov r9,rdx
.Ldec_loop:
 cmp rdx,rsi
 jae .Ldec_reset
 movzx r10d,byte ptr [rdi+rdx]
 mov r11d,r10d
 and r11d,192
 cmp r11d,128
 jne .Ldec_reset
 shl eax,6
 and r10d,63
 or eax,r10d
 inc rdx
 dec ecx
 jnz .Ldec_loop
 cmp r8d,224
 jb .Ldec_ret
 cmp r8d,240
 jb .Ldec_min3
 cmp eax,65536
 jb .Ldec_reset
 cmp eax,0x10ffff
 ja .Ldec_reset
 ret
.Ldec_min3:
 cmp eax,2048
 jb .Ldec_reset
 cmp eax,0xd800
 jb .Ldec_ret
 cmp eax,0xdfff
 ja .Ldec_ret
.Ldec_reset:
 mov rdx,r9
.Ldec_bad:
 mov eax,0xfffd
.Ldec_ret:
 ret
.Ldec_end:
 xor eax,eax
 ret
# eax scalar -> eax packed immutable properties.
.Lprops:
 xor ecx,ecx
 mov r8d,OFFSET FLAT:UNICODE_RANGE_COUNT
 lea r9,[rip+.Lunicode_ranges]
.Lprop_loop:
 cmp ecx,r8d
 jae .Lprop_zero
 lea edx,[rcx+r8]
 shr edx,1
 lea r10,[rdx+rdx*2]
 lea r10,[r9+r10*4]
 cmp eax,[r10]
 jb .Lprop_lower
 cmp eax,[r10+4]
 ja .Lprop_upper
 mov eax,[r10+8]
 ret
.Lprop_lower:
 mov r8d,edx
 jmp .Lprop_loop
.Lprop_upper:
 lea ecx,[rdx+1]
 jmp .Lprop_loop
.Lprop_zero:
 xor eax,eax
 ret
.global ui_next_grapheme
.type ui_next_grapheme,@function
ui_next_grapheme:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov r12,rdi
 mov r13,rsi
 cmp rdx,rsi
 jae .Lng_end
 call .Ldecode
 mov r14,rdx
 call .Lprops
 mov ebx,eax
 xor r15d,r15d
 mov eax,ebx
 and eax,15
 cmp eax,6
 sete r15b
 mov eax,ebx
 and eax,16
 mov [rsp],rax # EP Extend* state; ZWJ remembered as bit 32
 mov eax,ebx
 and eax,64
 mov [rsp+8],rax # InCB consonant chain 64 then linker bit128
.Lng_loop:
 cmp r14,r13
 jae .Lng_done
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call .Ldecode
 mov rbp,rdx
 call .Lprops
 mov [rsp+16],rax
 mov ecx,ebx
 and ecx,15
 mov edx,eax
 and edx,15
 # CR x LF; break around controls.
 cmp ecx,1
 jne .Lng_control
 cmp edx,2
 je .Lng_join
.Lng_control:
 cmp ecx,3
 jbe .Lng_prev_control
.Lng_next_control:
 test edx,edx
 jz .Lng_hangul
 cmp edx,3
 jbe .Lng_done
.Lng_hangul:
 cmp ecx,9
 jne .Lng_lv
 cmp edx,9
 je .Lng_join
 cmp edx,10
 je .Lng_join
 cmp edx,12
 je .Lng_join
 cmp edx,13
 je .Lng_join
.Lng_lv:
 cmp ecx,10
 je .Lng_v
 cmp ecx,12
 jne .Lng_lvt
.Lng_v:
 cmp edx,10
 je .Lng_join
 cmp edx,11
 je .Lng_join
.Lng_lvt:
 cmp ecx,11
 je .Lng_t
 cmp ecx,13
 jne .Lng_extend
.Lng_t:
 cmp edx,11
 je .Lng_join
.Lng_extend:
 cmp edx,4
 je .Lng_join
 cmp edx,5
 je .Lng_join
 cmp edx,8
 je .Lng_join
 cmp ecx,7
 je .Lng_join
 test eax,64
 jz .Lng_emoji
 cmp qword ptr [rsp+8],192
 je .Lng_join
.Lng_emoji:
 test eax,16
 jz .Lng_ri
 cmp qword ptr [rsp],32
 je .Lng_join
.Lng_ri:
 cmp ecx,6
 jne .Lng_done
 cmp edx,6
 jne .Lng_done
 test r15d,1
 jz .Lng_done
 jmp .Lng_join
.Lng_prev_control:
 test ecx,ecx
 jnz .Lng_done
 jmp .Lng_next_control
.Lng_join:
 mov eax,[rsp+16]
 mov edx,eax
 and edx,15
 cmp edx,6
 jne .Lng_ri_reset
 inc r15d
 jmp .Lng_ep
.Lng_ri_reset:
 xor r15d,r15d
.Lng_ep:
 test eax,16
 jz .Lng_ep_not
 mov qword ptr [rsp],16
 jmp .Lng_incb
.Lng_ep_not:
 cmp edx,4
 je .Lng_incb
 cmp edx,5
 jne .Lng_ep_zero
 cmp qword ptr [rsp],16
 jne .Lng_ep_zero
 mov qword ptr [rsp],32
 jmp .Lng_incb
.Lng_ep_zero:
 mov qword ptr [rsp],0
.Lng_incb:
 test eax,64
 jz .Lng_link
 mov qword ptr [rsp+8],64
 jmp .Lng_advance
.Lng_link:
 test eax,128
 jz .Lng_incb_extend
 cmp qword ptr [rsp+8],0
 je .Lng_advance
 or qword ptr [rsp+8],128
 jmp .Lng_advance
.Lng_incb_extend:
 test eax,256
 jnz .Lng_advance
 mov qword ptr [rsp+8],0
.Lng_advance:
 mov ebx,eax
 mov r14,rbp
 jmp .Lng_loop
.Lng_end:
 mov r14,r13
.Lng_done:
 mov rax,r14
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.global ui_text_width
.type ui_text_width,@function
ui_text_width:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov r12,rdi
 mov r13,rsi
 xor r14d,r14d
 xor r15d,r15d
.Lwidth_cluster:
 cmp r14,r13
 jae .Lwidth_done
 mov rdi,r12
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 mov [rsp],rax
 xor ebx,ebx
 mov qword ptr [rsp+8],0
.Lwidth_scalar:
 mov rdi,r12
 mov rsi,[rsp]
 mov rdx,r14
 call .Ldecode
 mov r14,rdx
 mov ebp,eax
 call .Lprops
 mov ecx,eax
 and ecx,15
 cmp ebp,0xfe0f
 je .Lwidth_emoji
 cmp ecx,6
 je .Lwidth_emoji
 cmp ebp,9
 je .Lwidth_tab
 cmp ebp,32
 jb .Lwidth_next
 cmp ebp,127
 je .Lwidth_next
 cmp ecx,3
 je .Lwidth_next
 cmp ecx,4
 je .Lwidth_next
 cmp ecx,5
 je .Lwidth_next
 mov edx,1
 test eax,32
 jz .Lwidth_max
 mov edx,2
 jmp .Lwidth_max
.Lwidth_emoji:
 mov edx,2
 jmp .Lwidth_max
.Lwidth_tab:
 mov edx,4
.Lwidth_max:
 cmp ebx,edx
 cmovb ebx,edx
.Lwidth_next:
 cmp r14,[rsp]
 jb .Lwidth_scalar
 add r15,rbx
 jmp .Lwidth_cluster
.Lwidth_done:
 mov rax,r15
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
# Context metadata initialized without touching history/payload pages.
.global input_init
input_init:
 test rdi,rdi
 jz .Linvalid
 test rsi,rsi
 jz .Linvalid
 cmp rdx,2
 jb .Linvalid
 cmp rdx,65536
 ja .Linvalid
 mov [rdi+C_BUF],rsi
 mov [rdi+C_CAP],rdx
 push rdi
 add rdi,16
 mov ecx,48
 xor eax,eax
 rep stosq
 pop rdi
 mov qword ptr [rdi+C_ANCHOR],-1
 mov qword ptr [rdi+C_HINDEX],-1
 mov byte ptr [rsi],0
 mov qword ptr [rdi+C_COLUMNS],80
 mov qword ptr [rdi+C_GOAL],-1
 mov qword ptr [rdi+C_HUP],0
 mov qword ptr [rdi+C_CONSUMED],0
 mov qword ptr [rdi+C_EXTERNAL_HISTORY],0
 mov qword ptr [rdi+C_MOUSE_BUTTON],0
 mov qword ptr [rdi+C_MOUSE_X],0
 mov qword ptr [rdi+C_MOUSE_Y],0
 mov qword ptr [rdi+C_MOUSE_RELEASE],0
 mov qword ptr [rdi+C_OSC_VALID],0
 xor eax,eax
 ret
.Linvalid:
 mov rax,-22
 ret
.global input_begin
.global input_set
input_set:
input_begin:
 push r12
 mov r12,rdi
 mov rcx,[rdi+C_CAP]
 dec rcx
 cmp rdx,rcx
 jbe .Lbegin_boundary_done
 mov rdx,rcx
 # Clamp only at UTF-8 boundaries when caller input exceeds capacity.
.Lbegin_boundary:
 test rdx,rdx
 jz .Lbegin_boundary_done
 movzx eax,byte ptr [rsi+rdx]
 and eax,192
 cmp eax,128
 jne .Lbegin_boundary_done
 dec rdx
 jmp .Lbegin_boundary
.Lbegin_boundary_done:
 mov [rdi+C_LEN],rdx
 mov [rdi+C_CUR],rdx
 mov rcx,rdx
 mov rdi,[rdi+C_BUF]
 rep movsb
 mov byte ptr [rdi],0
 mov qword ptr [r12+C_ANCHOR],-1
 mov qword ptr [r12+C_MENU],0
 mov qword ptr [r12+C_ESC],0
 mov qword ptr [r12+C_UTFN],0
 mov qword ptr [r12+C_PASTE],0
 mov qword ptr [r12+C_PEND],0
 mov qword ptr [r12+C_PCR],0
 mov qword ptr [r12+C_SEARCH],0
 mov qword ptr [r12+C_UCOUNT],0
 mov qword ptr [r12+C_UPOS],0
 mov qword ptr [r12+C_USTART],0
 mov qword ptr [r12+C_HINDEX],-1
 mov qword ptr [r12+C_HUP],0
 mov qword ptr [r12+C_DIRTY],1
 mov qword ptr [r12+C_GOAL],-1
 pop r12
 xor eax,eax
 ret
.global input_clear
input_clear:
 xor esi,esi
 xor edx,edx
 jmp input_begin
.global input_resize
input_resize:
 cmp rsi,1
 jb .Lresize_bad
 cmp rsi,4096
 ja .Lresize_bad
 mov [rdi+C_COLUMNS],rsi
 mov [rdi+C_ROWS],rdx
 mov qword ptr [rdi+C_DIRTY],1
 xor eax,eax
 ret
.Lresize_bad:
 mov rax,-22
 ret
.global input_set_completion
input_set_completion:
 mov [rdi+C_MENU],rsi
 ret
.global input_set_external_history
input_set_external_history:
 mov [rdi+C_EXTERNAL_HISTORY],rsi
 ret
.global input_mouse_snapshot
# out32 receives button,x,y,release for the last valid SGR packet.
input_mouse_snapshot:
 mov rax,[rdi+C_MOUSE_BUTTON]
 mov [rsi],rax
 mov rax,[rdi+C_MOUSE_X]
 mov [rsi+8],rax
 mov rax,[rdi+C_MOUSE_Y]
 mov [rsi+16],rax
 mov rax,[rdi+C_MOUSE_RELEASE]
 mov [rsi+24],rax
 ret
.global input_osc11_snapshot
# Snapshot consumes the pending valid bit; normalized channels retain last value.
input_osc11_snapshot:
 xor eax,eax
 cmp qword ptr [rdi+C_OSC_VALID],0
 je .Losc_snapshot_none
 mov rax,[rdi+C_OSC_R]
 mov [rsi],rax
 mov rax,[rdi+C_OSC_G]
 mov [rsi+8],rax
 mov rax,[rdi+C_OSC_B]
 mov [rsi+16],rax
 mov qword ptr [rsi+24],1
 mov qword ptr [rdi+C_OSC_VALID],0
 mov eax,1
 ret
.Losc_snapshot_none:
 mov qword ptr [rsi+24],0
 ret
.global input_snapshot
input_snapshot:
 mov rax,[rdi+C_BUF]
 mov [rsi+IS_TEXT],rax
 mov rax,[rdi+C_LEN]
 mov [rsi+IS_LENGTH],rax
 mov rax,[rdi+C_CUR]
 mov [rsi+IS_CURSOR],rax
 mov rax,[rdi+C_DIRTY]
 mov [rsi+IS_DIRTY],rax
 mov qword ptr [rdi+C_DIRTY],0
 xor eax,eax
 cmp qword ptr [rdi+C_SEARCH],0
 setne al
 cmp qword ptr [rdi+C_PASTE],0
 je .Lsnap_menu
 or eax,2
.Lsnap_menu:
 cmp qword ptr [rdi+C_MENU],0
 je .Lsnap_flags
 or eax,4
.Lsnap_flags:
 mov [rsi+IS_FLAGS],rax
 lea rax,[rdi+C_QUERY]
 mov [rsi+IS_HINT],rax
 mov rax,[rdi+C_SLEN]
 mov [rsi+IS_HINT_LENGTH],rax
 mov rax,[rdi+C_ANCHOR]
 mov [rsi+IS_SELECTION],rax
 ret
# A 17-state timeline retains 16 undo transitions and all corresponding redo
# states. Untouched pages stay lazy. A mutation after undo truncates its future.
.Lsave_undo:
 mov rax,[r12+C_UPOS]
 cmp rax,[r12+C_UCOUNT]
 jae .Lsave_append
 inc rax
 mov [r12+C_UCOUNT],rax
 mov [r12+C_UPOS],rax
 ret
.Lsave_append:
 call .Ltimeline_append
 mov rax,[r12+C_UCOUNT]
 mov [r12+C_UPOS],rax
 ret
.Ltimeline_append:
 mov r9,[r12+C_UCOUNT]
 mov r10,[r12+C_USTART]
 cmp r9,17
 jb .Ltimeline_room
 inc r10
 cmp r10,17
 jb .Ltimeline_start
 xor r10d,r10d
.Ltimeline_start:
 mov [r12+C_USTART],r10
 dec r9
.Ltimeline_room:
 lea r8,[r9+r10]
 cmp r8,17
 jb .Ltimeline_slot
 sub r8,17
.Ltimeline_slot:
 mov rcx,[r12+C_LEN]
 mov [r12+C_ULENS+r8*8],rcx
 mov rax,[r12+C_CUR]
 mov [r12+C_UCURS+r8*8],rax
 shl r8,16
 lea rdi,[r12+r8+C_UNDO]
 mov rsi,[r12+C_BUF]
 rep movsb
 inc r9
 mov [r12+C_UCOUNT],r9
 ret
# Replace exact byte interval. Internal no-undo entry. r12 ctx, rsi start,
# rdx end, rcx replacement pointer,r8 replacement length.->0/-ENOSPC.
.Lreplace:
 mov r9,[r12+C_LEN]
 cmp rsi,rdx
 ja .Lreplace_bad
 cmp rdx,r9
 ja .Lreplace_bad
 mov r10,r9
 sub r10,rdx
 add r10,rsi
 add r10,r8
 cmp r10,[r12+C_CAP]
 jae .Lreplace_full
 push rbx
 push rbp
 mov rbx,rcx
 mov rbp,r8
 mov r11,rsi
 mov rdi,[r12+C_BUF]
 # memmove tail including terminator, backwards if expansion
 mov rcx,r9
 sub rcx,rdx
 inc rcx
 mov rax,rsi
 add rax,r8
 cmp rax,rdx
 ja .Lreplace_back
 add rsi,rbp
 add rsi,rdi
 xchg rsi,rdi
 # rdi destination, source buf+end
 mov rsi,[r12+C_BUF]
 add rsi,rdx
 rep movsb
 jmp .Lreplace_copy
.Lreplace_back:
 lea rsi,[rdi+r9]
 lea rdi,[rdi+r10]
 std
 rep movsb
 cld
.Lreplace_copy:
 mov rdi,[r12+C_BUF]
 add rdi,r11
 mov rsi,rbx
 mov rcx,rbp
 rep movsb
 mov [r12+C_LEN],r10
 add r11,rbp
 mov [r12+C_CUR],r11
 mov qword ptr [r12+C_ANCHOR],-1
 mov qword ptr [r12+C_DIRTY],1
 pop rbp
 pop rbx
 xor eax,eax
 ret
.Lreplace_full:
 mov rax,-28
 ret
.Lreplace_bad:
 mov rax,-22
 ret
.global input_replace
input_replace:
 push r12
 mov r12,rdi
 push rsi
 push rdx
 push rcx
 push r8
 call .Lsave_undo
 pop r8
 pop rcx
 pop rdx
 pop rsi
 call .Lreplace
 pop r12
 ret
# Previous grapheme boundary, context in r12, index in rax.
.Lprev:
 push rbx
 push rbp
 mov rbp,rax
 xor ebx,ebx
.Lprev_loop:
 cmp rbx,rbp
 jae .Lprev_zero
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,rbx
 call ui_next_grapheme
 cmp rax,rbp
 jae .Lprev_found
 mov rbx,rax
 jmp .Lprev_loop
.Lprev_zero:
 xor ebx,ebx
.Lprev_found:
 mov rax,rbx
 pop rbp
 pop rbx
 ret
# Insert scalar bytes from rcx,len r8, replacing selection when present.
.Linsert:
 mov rsi,[r12+C_CUR]
 mov rdx,rsi
 mov rax,[r12+C_ANCHOR]
 cmp rax,-1
 je .Linsert_call
 cmp rax,rsi
 ja .Linsert_right
 mov rsi,rax
 jmp .Linsert_call
.Linsert_right:
 mov rdx,rax
.Linsert_call:
 jmp .Lreplace
.global input_feed
input_feed:
 push rbp
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24
 mov r12,rdi
 mov r13,rsi
 lea r14,[rsi+rdx]
 mov qword ptr [r12+C_CONSUMED],0
 xor r15d,r15d
.Lfeed_loop:
 cmp r13,r14
 jae .Lfeed_done
 movzx ebx,byte ptr [r13]
 inc r13
 inc qword ptr [r12+C_CONSUMED]
 call .Lbyte
 test r15d,~(INPUT_CHANGED|INPUT_FULL|INPUT_SEARCH)
 jnz .Lfeed_done
 jmp .Lfeed_loop
.Lfeed_done:
 mov rax,r15
 add rsp,24
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 pop rbp
 ret
.global input_consumed
input_consumed:
 mov rax,[rdi+C_CONSUMED]
 ret
# r12 ctx, bl byte, r15 event accumulation.
.Lbyte:
 cmp qword ptr [r12+C_PASTE],0
 je .Lbyte_escape
 mov rax,[r12+C_PEND]
 test rax,rax
 jnz .Lpaste_match
 cmp bl,27
 jne .Lpaste_text
 mov qword ptr [r12+C_PEND],1
 ret
.Lpaste_match:
 lea rdx,[rip+.Lpaste_end]
 cmp bl,[rdx+rax]
 jne .Lpaste_mismatch
 inc rax
 cmp rax,6
 je .Lpaste_finished
 mov [r12+C_PEND],rax
 ret
.Lpaste_finished:
 mov qword ptr [r12+C_PEND],0
 mov qword ptr [r12+C_PASTE],0
 mov qword ptr [r12+C_PCR],0
 or r15d,INPUT_CHANGED
 ret
.Lpaste_mismatch:
 # Preserve printable bytes of a false end marker, without executing escape.
 mov rbp,rax
 mov qword ptr [r12+C_PEND],0
 mov [rsp+8],rbx
 mov qword ptr [rsp+16],1
.Lpaste_flush:
 mov rax,[rsp+16]
 cmp rax,rbp
 jae .Lpaste_flush_done
 lea rdx,[rip+.Lpaste_end]
 movzx ebx,byte ptr [rdx+rax]
 inc qword ptr [rsp+16]
 call .Ltext_byte
 jmp .Lpaste_flush
.Lpaste_flush_done:
 mov rbx,[rsp+8]
 jmp .Lpaste_text
.Lpaste_text:
 cmp bl,10
 jne .Lpaste_cr
 cmp qword ptr [r12+C_PCR],0
 jne .Lpaste_skip_lf
.Lpaste_cr:
 mov qword ptr [r12+C_PCR],0
 cmp bl,13
 jne .Lpaste_control
 mov qword ptr [r12+C_PCR],1
 mov ebx,10
.Lpaste_control:
 cmp bl,10
 je .Ltext_byte
 cmp bl,9
 je .Ltext_byte
 cmp bl,32
 jb .Lbyte_ret
 cmp bl,127
 je .Lbyte_ret
 jmp .Ltext_byte
.Lpaste_skip_lf:
 mov qword ptr [r12+C_PCR],0
 ret
.Lbyte_escape:
 mov rax,[r12+C_ESC]
 test rax,rax
 jnz .Lesc_byte
 cmp bl,27
 jne .Lbyte_plain
 mov qword ptr [r12+C_ESC],1
 ret
.Lesc_byte:
 cmp rax,5
 je .Losc_byte
 cmp rax,6
 je .Losc_st
 cmp rax,7
 je .Losc_discard
 cmp rax,8
 je .Losc_discard_st
 cmp rax,4
 je .Lesc_discard
 cmp rax,1
 jne .Lesc_collect
 cmp bl,27
 je .Lesc_double
 cmp bl,93
 je .Losc_start
 cmp bl,91
 je .Lesc_csi
 cmp bl,79
 je .Lesc_ss3
 mov qword ptr [r12+C_ESC],0
 cmp bl,13
 je .Lnewline
 cmp bl,10
 je .Lnewline
 cmp bl,98
 je .Lword_left
 cmp bl,102
 je .Lword_right
 cmp bl,100
 je .Ldelete_word_right
 cmp bl,127
 je .Ldelete_word_left
 ret
.Lesc_double:
 mov rdi,r12
 call input_timeout
 or r15,rax
 mov qword ptr [r12+C_ESC],1
 ret
.Lesc_csi:
 mov qword ptr [r12+C_ESC],2
 mov qword ptr [r12+C_ESCLEN],0
 ret
.Lesc_ss3:
 mov qword ptr [r12+C_ESC],3
 mov qword ptr [r12+C_ESCLEN],0
 ret
.Lesc_collect:
 cmp bl,3
 jne .Lesc_collect_regular
 mov qword ptr [r12+C_ESC],0
 jmp .Lcancel
.Lesc_collect_regular:
 mov rax,[r12+C_ESCLEN]
 cmp rax,62
 jae .Lesc_overflow
 mov [r12+C_ESCSTR+rax],bl
 inc rax
 mov [r12+C_ESCLEN],rax
 cmp bl,64
 jb .Lbyte_ret
 cmp bl,126
 ja .Lesc_abort
 mov qword ptr [r12+C_ESC],0
 cmp byte ptr [r12+C_ESCSTR],60
 je .Lsgr_mouse
 # Parse first parameter and second modifier. Missing parameter -> 0.
 xor ecx,ecx
 xor edx,edx
 xor r8d,r8d
 xor r9d,r9d
.Lesc_number:
 cmp rcx,rax
 jae .Lesc_action
 movzx r10d,byte ptr [r12+C_ESCSTR+rcx]
 inc rcx
 cmp r10b,59
 je .Lesc_semicolon
 sub r10d,48
 cmp r10d,9
 ja .Lesc_action
 test r9d,r9d
 jnz .Lesc_num2
 imul edx,edx,10
 add edx,r10d
 jmp .Lesc_number
.Lesc_num2:
 imul r8d,r8d,10
 add r8d,r10d
 jmp .Lesc_number
.Lesc_semicolon:
 inc r9d
 jmp .Lesc_number
.Lesc_action:
 # Source viewport shortcuts precede editor selection/movement.
 cmp r8d,5
 jb .Lesc_shift_scroll
 cmp r8d,8
 ja .Lesc_shift_scroll
 cmp bl,72
 je .Lscroll_top
 cmp bl,70
 je .Lscroll_bottom
 cmp bl,126
 jne .Lesc_shift_scroll
 cmp edx,1
 je .Lscroll_top
 cmp edx,7
 je .Lscroll_top
 cmp edx,4
 je .Lscroll_bottom
 cmp edx,8
 je .Lscroll_bottom
.Lesc_shift_scroll:
 cmp r8d,2
 je .Lesc_shift_scroll_key
 cmp r8d,4
 je .Lesc_shift_scroll_key
 cmp r8d,6
 je .Lesc_shift_scroll_key
 cmp r8d,8
 jne .Lesc_selection
.Lesc_shift_scroll_key:
 cmp bl,65
 je .Lscroll_line_up
 cmp bl,66
 je .Lscroll_line_down
.Lesc_selection:
 # Shift modifier establishes selection before cursor movement.
 cmp r8d,2
 je .Lesc_select
 cmp r8d,4
 je .Lesc_select
 cmp r8d,6
 je .Lesc_select
 cmp r8d,8
 je .Lesc_select
 mov qword ptr [r12+C_ANCHOR],-1
 jmp .Lesc_dispatch
.Lesc_select:
 cmp qword ptr [r12+C_ANCHOR],-1
 jne .Lesc_dispatch
 mov rcx,[r12+C_CUR]
 mov [r12+C_ANCHOR],rcx
.Lesc_dispatch:
 cmp bl,65
 je .Lup
 cmp bl,66
 je .Ldown
 mov qword ptr [r12+C_GOAL],-1
 cmp bl,90
 je .Lmode
 cmp bl,65
 je .Lup
 cmp bl,66
 je .Ldown
 cmp bl,67
 je .Lesc_right
 cmp bl,68
 je .Lesc_left
 cmp bl,72
 je .Lhome
 cmp bl,70
 je .Lend
 cmp bl,117
 je .Lesc_u
 cmp bl,126
 jne .Lbyte_ret
 cmp edx,200
 je .Lpaste_start
 cmp edx,1
 je .Lhome
 cmp edx,7
 je .Lhome
 cmp edx,4
 je .Lend
 cmp edx,8
 je .Lend
 cmp edx,3
 je .Ldelete
 cmp edx,5
 je .Lpage_up
 cmp edx,6
 je .Lpage_down
 ret
.Lesc_u:
 cmp edx,13
 je .Lnewline
 cmp edx,90
 jne .Lesc_u_undo
 cmp r8d,6
 je .Lredo
 ret
.Lesc_u_undo:
 cmp edx,122
 jne .Lbyte_ret
 cmp r8d,5
 je .Lundo
 ret
.Lesc_right:
 cmp r8d,3
 jae .Lword_right
 jmp .Lright
.Lesc_left:
 cmp r8d,3
 jae .Lword_left
 jmp .Lleft
.Losc_start:
 mov qword ptr [r12+C_ESC],5
 mov qword ptr [r12+C_ESCLEN],0
 ret
.Losc_byte:
 cmp bl,7
 je .Losc_complete
 cmp bl,27
 je .Losc_wait_st
 cmp bl,32
 jb .Losc_discard_start
 cmp bl,127
 jae .Losc_discard_start
 mov rax,[r12+C_ESCLEN]
 cmp rax,62
 jae .Losc_discard_start
 mov [r12+C_ESCSTR+rax],bl
 inc qword ptr [r12+C_ESCLEN]
 ret
.Losc_wait_st:
 mov qword ptr [r12+C_ESC],6
 ret
.Losc_st:
 cmp bl,92
 je .Losc_complete
 cmp bl,7
 je .Losc_complete
 cmp bl,27
 je .Losc_discard_wait_st
 jmp .Losc_discard_start
.Losc_discard_start:
 mov qword ptr [r12+C_ESC],7
 ret
.Losc_discard_wait_st:
 mov qword ptr [r12+C_ESC],8
 ret
.Losc_discard:
 cmp bl,7
 je .Losc_discard_done
 cmp bl,27
 je .Losc_discard_wait_st
 ret
.Losc_discard_st:
 cmp bl,92
 je .Losc_discard_done
 cmp bl,7
 je .Losc_discard_done
 cmp bl,27
 je .Lbyte_ret
 mov qword ptr [r12+C_ESC],7
 ret
.Losc_discard_done:
 mov qword ptr [r12+C_ESC],0
 ret
.Losc_complete:
 mov qword ptr [r12+C_ESC],0
 mov r10,[r12+C_ESCLEN]
 cmp r10,7
 jb .Lbyte_ret
 cmp word ptr [r12+C_ESCSTR],0x3131
 jne .Lbyte_ret
 cmp byte ptr [r12+C_ESCSTR+2],59
 jne .Lbyte_ret
 mov ecx,3
 movzx eax,byte ptr [r12+C_ESCSTR+rcx]
 cmp al,35
 je .Losc_hash
 # rgb: and rgba: are accepted case-insensitively, as in source detector.
 mov eax,dword ptr [r12+C_ESCSTR+3]
 or eax,0x202020
 and eax,0x00ffffff
 cmp eax,0x00626772
 jne .Lbyte_ret
 mov ecx,6
 cmp byte ptr [r12+C_ESCSTR+rcx],58
 je .Losc_rgb_begin
 mov al,[r12+C_ESCSTR+rcx]
 or al,32
 cmp al,97
 jne .Lbyte_ret
 inc ecx
 cmp byte ptr [r12+C_ESCSTR+rcx],58
 jne .Lbyte_ret
.Losc_rgb_begin:
 inc ecx
 xor r8d,r8d
.Losc_rgb_component:
 xor edx,edx
 xor r9d,r9d
.Losc_rgb_digit:
 cmp rcx,r10
 jae .Losc_rgb_end
 movzx eax,byte ptr [r12+C_ESCSTR+rcx]
 cmp al,47
 je .Losc_rgb_separator
 call .Losc_hex
 test eax,eax
 js .Lbyte_ret
 inc r9d
 cmp r9d,4
 ja .Lbyte_ret
 shl edx,4
 or edx,eax
 inc ecx
 jmp .Losc_rgb_digit
.Losc_rgb_separator:
 cmp r8d,2
 jae .Lbyte_ret
 test r9d,r9d
 jz .Lbyte_ret
 call .Losc_normalize
 mov [r12+r8*8+C_OSC_TEMP],rax
 inc r8d
 inc ecx
 jmp .Losc_rgb_component
.Losc_rgb_end:
 cmp r8d,2
 jne .Lbyte_ret
 test r9d,r9d
 jz .Lbyte_ret
 call .Losc_normalize
 mov [r12+C_OSC_TEMP+16],rax
 jmp .Losc_accept
.Losc_hash:
 mov rax,r10
 sub eax,4
 xor edx,edx
 mov ecx,3
 div ecx
 test edx,edx
 jnz .Lbyte_ret
 test eax,eax
 jz .Lbyte_ret
 cmp eax,4
 ja .Lbyte_ret
 mov r11d,eax
 mov ecx,4
 xor r8d,r8d
.Losc_hash_component:
 xor edx,edx
 xor r9d,r9d
.Losc_hash_digit:
 movzx eax,byte ptr [r12+C_ESCSTR+rcx]
 call .Losc_hex
 test eax,eax
 js .Lbyte_ret
 shl edx,4
 or edx,eax
 inc ecx
 inc r9d
 cmp r9d,r11d
 jb .Losc_hash_digit
 call .Losc_normalize
 mov [r12+r8*8+C_OSC_TEMP],rax
 inc r8d
 cmp r8d,3
 jb .Losc_hash_component
.Losc_accept:
 mov rax,[r12+C_OSC_TEMP]
 mov [r12+C_OSC_R],rax
 mov rax,[r12+C_OSC_TEMP+8]
 mov [r12+C_OSC_G],rax
 mov rax,[r12+C_OSC_TEMP+16]
 mov [r12+C_OSC_B],rax
 mov qword ptr [r12+C_OSC_VALID],1
 or r15d,INPUT_THEME_RESPONSE
 ret
# Hex digit EAX ->EAX0..15 or-1; all parser cursors preserved.
.Losc_hex:
 cmp eax,48
 jb .Losc_hex_bad
 cmp eax,57
 jbe .Losc_hex_decimal
 or eax,32
 sub eax,97
 cmp eax,5
 ja .Losc_hex_bad
 add eax,10
 ret
.Losc_hex_decimal:
 sub eax,48
 ret
.Losc_hex_bad:
 mov eax,-1
 ret
# EDX component,R9D hex digits -> RAX normalized16; preserve all cursors.
.Losc_normalize:
 push rcx
 mov ecx,r9d
 shl ecx,2
 mov eax,1
 shl eax,cl
 dec eax
 mov r9d,eax
 mov eax,edx
 imul eax,eax,65535
 xor edx,edx
 div r9d
 pop rcx
 ret
.Lesc_overflow:
 mov qword ptr [r12+C_ESC],4
.Lesc_discard:
 cmp bl,3
 je .Lesc_discard_cancel
 cmp bl,64
 jb .Lbyte_ret
 cmp bl,126
 ja .Lbyte_ret
 mov qword ptr [r12+C_ESC],0
 ret
.Lesc_discard_cancel:
 mov qword ptr [r12+C_ESC],0
 jmp .Lcancel
# Strict SGR: ESC[<button;x;yM or m. Retained parser state handles all splits;
# non-wheel packets are consumed but never become editor text.
.Lsgr_mouse:
 cmp bl,77
 je .Lsgr_final_valid
 cmp bl,109
 jne .Lbyte_ret
.Lsgr_final_valid:
 mov r10,[r12+C_ESCLEN]
 dec r10
 mov ecx,1
 xor edx,edx
 xor r8d,r8d
 xor r9d,r9d
.Lsgr_digit:
 cmp rcx,r10
 jae .Lsgr_last
 movzx eax,byte ptr [r12+C_ESCSTR+rcx]
 inc rcx
 cmp al,59
 je .Lsgr_separator
 sub eax,48
 cmp eax,9
 ja .Lbyte_ret
 imul edx,edx,10
 add edx,eax
 cmp edx,65535
 ja .Lbyte_ret
 inc r9d
 jmp .Lsgr_digit
.Lsgr_separator:
 test r9d,r9d
 jz .Lbyte_ret
 cmp r8d,2
 jae .Lbyte_ret
 mov [r12+r8*8+C_MOUSE_TEMP],rdx
 inc r8d
 xor edx,edx
 xor r9d,r9d
 jmp .Lsgr_digit
.Lsgr_last:
 cmp r8d,2
 jne .Lbyte_ret
 test r9d,r9d
 jz .Lbyte_ret
 test edx,edx
 jz .Lbyte_ret
 mov [r12+C_MOUSE_TEMP+16],rdx
 mov rax,[r12+C_MOUSE_TEMP+8]
 test rax,rax
 jz .Lbyte_ret
 mov [r12+C_MOUSE_X],rax
 mov rax,[r12+C_MOUSE_TEMP+16]
 mov [r12+C_MOUSE_Y],rax
 mov rax,[r12+C_MOUSE_TEMP]
 mov [r12+C_MOUSE_BUTTON],rax
 xor edx,edx
 cmp bl,109
 sete dl
 mov [r12+C_MOUSE_RELEASE],rdx
 cmp eax,255
 ja .Lbyte_ret
 test eax,64
 jz .Lsgr_nonwheel
 test edx,edx
 jnz .Lbyte_ret
 and eax,3
 cmp eax,0
 je .Lsgr_wheel_up
 cmp eax,1
 je .Lsgr_wheel_down
.Lsgr_nonwheel:
 or r15d,INPUT_MOUSE_EVENT
 ret
.Lsgr_wheel_up:
 or r15d,INPUT_MOUSE_SCROLL_UP
 ret
.Lsgr_wheel_down:
 or r15d,INPUT_MOUSE_SCROLL_DOWN
 ret
.Lesc_abort:
 mov qword ptr [r12+C_ESC],0
 ret
.Lpaste_start:
 call .Lsave_undo
 mov qword ptr [r12+C_PASTE],1
 mov qword ptr [r12+C_PEND],0
 ret
.Lscroll_top:
 or r15d,INPUT_SCROLL_TOP
 ret
.Lscroll_bottom:
 or r15d,INPUT_SCROLL_BOTTOM
 ret
.Lscroll_line_up:
 or r15d,INPUT_SCROLL_LINE_UP
 ret
.Lscroll_line_down:
 or r15d,INPUT_SCROLL_LINE_DOWN
 ret
.Lmode:
 or r15d,131072
 ret
.Lpage_up:
 or r15d,INPUT_SCROLL_UP
 ret
.Lpage_down:
 or r15d,INPUT_SCROLL_DOWN
 ret
.Lbyte_plain:
 mov qword ptr [r12+C_GOAL],-1
 cmp qword ptr [r12+C_SEARCH],0
 jne .Lsearch_byte
 cmp bl,33
 jne .Lplain_not_shell_toggle
 cmp qword ptr [r12+C_LEN],0
 jne .Lplain_not_shell_toggle
 cmp qword ptr [r12+C_MENU],0
 jne .Lplain_not_shell_toggle
 or r15d,16777216
 ret
.Lplain_not_shell_toggle:
 cmp bl,13
 je .Lsubmit
 cmp bl,10
 je .Lnewline
 cmp bl,9
 je .Lcomplete
 cmp bl,3
 je .Lcancel
 cmp bl,4
 je .Lctrl_d
 cmp bl,1
 je .Lhome
 cmp bl,5
 je .Lend
 cmp bl,2
 je .Lleft
 cmp bl,6
 je .Lright
 cmp bl,8
 je .Lbackspace
 cmp bl,127
 je .Lbackspace
 cmp bl,11
 je .Lkill_right
 cmp bl,21
 je .Lkill_left
 cmp bl,23
 je .Ldelete_word_left
 cmp bl,31
 je .Ldelete_word_left
 cmp bl,16
 je .Lup
 cmp bl,14
 je .Ldown
 cmp bl,18
 je .Lsearch_start
 cmp bl,26
 je .Lundo
 cmp bl,25
 je .Lretry
 cmp bl,17
 je .Lqueue
 cmp bl,24
 je .Lexternal
 cmp bl,12
 je .Lclear_screen
 cmp bl,15
 je .Ldetails
 cmp bl,32
 jb .Lbyte_ret
.Ltext_byte:
 mov rax,[r12+C_UTFN]
 test rax,rax
 jnz .Lutf_more
 cmp bl,128
 jb .Linsert_ascii
 cmp bl,194
 jb .Lbyte_ret
 cmp bl,245
 jae .Lbyte_ret
 mov ecx,2
 cmp bl,224
 jb .Lutf_start
 inc ecx
 cmp bl,240
 jb .Lutf_start
 inc ecx
.Lutf_start:
 mov [r12+C_UTFNEED],rcx
 mov [r12+C_UTF],bl
 mov qword ptr [r12+C_UTFN],1
 ret
.Lutf_more:
 mov ecx,ebx
 and ecx,192
 cmp ecx,128
 jne .Lutf_reset_retry
 mov [r12+C_UTF+rax],bl
 inc rax
 mov [r12+C_UTFN],rax
 cmp rax,[r12+C_UTFNEED]
 jb .Lbyte_ret
 lea rdi,[r12+C_UTF]
 mov rsi,rax
 xor edx,edx
 call .Ldecode
 cmp rdx,[r12+C_UTFN]
 jne .Lutf_reset
 cmp qword ptr [r12+C_PASTE],0
 jne .Lutf_insert
 call .Lsave_undo
.Lutf_insert:
 lea rcx,[r12+C_UTF]
 mov r8,[r12+C_UTFN]
 mov qword ptr [r12+C_UTFN],0
 call .Linsert
 jmp .Linsert_result
.Lutf_reset_retry:
 mov qword ptr [r12+C_UTFN],0
 jmp .Ltext_byte
.Lutf_reset:
 mov qword ptr [r12+C_UTFN],0
 ret
.Linsert_ascii:
 mov [r12+C_UTF],bl
 cmp qword ptr [r12+C_PASTE],0
 jne .Linsert_ascii_saved
 call .Lsave_undo
.Linsert_ascii_saved:
 lea rcx,[r12+C_UTF]
 mov r8d,1
 call .Linsert
.Linsert_result:
 test rax,rax
 js .Lfull
 jmp .Lchanged
.Lfull:
 or r15d,INPUT_FULL
 ret
.Lchanged:
 mov qword ptr [r12+C_DIRTY],1
 or r15d,INPUT_CHANGED
.Lbyte_ret:
 ret
.Lsubmit:
 cmp qword ptr [r12+C_MENU],0
 je .Lsubmit_plain
 or r15d,INPUT_MENU_ACCEPT
 ret
.Lsubmit_plain:
 or r15d,INPUT_SUBMIT
 ret
.Lnewline:
 mov ebx,10
 jmp .Linsert_ascii
.Lcomplete:
 or r15d,INPUT_COMPLETE
 ret
.Lqueue:
 or r15d,INPUT_QUEUE
 ret
.Lclear_screen:
 or r15d,262144
 ret
.Ldetails:
 or r15d,524288
 ret
.Lretry:
 or r15d,1048576
 ret
.Lexternal:
 or r15d,INPUT_EXTERNAL_EDITOR
 ret
.Lcancel:
 mov qword ptr [r12+C_LEN],0
 mov qword ptr [r12+C_CUR],0
 mov rax,[r12+C_BUF]
 mov byte ptr [rax],0
 mov qword ptr [r12+C_ANCHOR],-1
 or r15d,INPUT_CANCEL
 jmp .Lchanged
.Lctrl_d:
 cmp qword ptr [r12+C_LEN],0
 jne .Ldelete
 or r15d,INPUT_EOF
 ret
.Lleft:
 mov rax,[r12+C_CUR]
 call .Lprev
 mov [r12+C_CUR],rax
 jmp .Lchanged
.Lright:
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,[r12+C_CUR]
 call ui_next_grapheme
 mov [r12+C_CUR],rax
 jmp .Lchanged
.Lhome:
 call .Lvisual_layout
 mov rax,[r12+C_VROW]
 mov eax,[r12+rax*4+C_VSTART]
 jmp .Lmove_done
.Lend:
 call .Lvisual_layout
 mov rax,[r12+C_VROW]
 inc rax
 cmp rax,[r12+C_VCOUNT]
 jae .Lend_final
 mov eax,[r12+rax*4+C_VSTART]
 mov rdx,[r12+C_BUF]
 test rax,rax
 jz .Lmove_done
 cmp byte ptr [rdx+rax-1],10
 jne .Lmove_done
 dec rax
 jmp .Lmove_done
.Lend_final:
 mov rax,[r12+C_LEN]
.Lmove_done:
 mov [r12+C_CUR],rax
 jmp .Lchanged
.Lbackspace:
 cmp qword ptr [r12+C_ANCHOR],-1
 jne .Ldelete_selection
 mov rax,[r12+C_CUR]
 test rax,rax
 jz .Lbyte_ret
 call .Lprev
 mov rbp,rax
 call .Lsave_undo
 mov rsi,rbp
 mov rdx,[r12+C_CUR]
 jmp .Ldelete_range
.Ldelete:
 cmp qword ptr [r12+C_ANCHOR],-1
 jne .Ldelete_selection
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,[r12+C_CUR]
 cmp rdx,rsi
 jae .Lbyte_ret
 call ui_next_grapheme
 mov rbp,rax
 call .Lsave_undo
 mov rsi,[r12+C_CUR]
 mov rdx,rbp
 jmp .Ldelete_range
.Ldelete_selection:
 call .Lsave_undo
 mov rsi,[r12+C_ANCHOR]
 mov rdx,[r12+C_CUR]
 cmp rsi,rdx
 jbe .Ldelete_range
 xchg rsi,rdx
.Ldelete_range:
 xor ecx,ecx
 xor r8d,r8d
 call .Lreplace
 jmp .Lchanged
.Lkill_left:
 mov rbp,[r12+C_CUR]
 call .Lhome
 mov rsi,[r12+C_CUR]
 mov [r12+C_CUR],rbp
 push rsi
 call .Lsave_undo
 pop rsi
 mov rdx,rbp
 jmp .Ldelete_range
.Lkill_right:
 mov rbp,[r12+C_CUR]
 call .Lend
 mov rdx,[r12+C_CUR]
 mov [r12+C_CUR],rbp
 push rdx
 call .Lsave_undo
 pop rdx
 mov rsi,rbp
 jmp .Ldelete_range
# Native word classification: Unicode letters/numbers/marks, punctuation,
# whitespace and script transitions. CJK clusters remain distinct words.
# rdx byte index -> eax class (0 whitespace,1 word,2 punctuation)+script bits.
.Lword_class:
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 call .Ldecode
 cmp eax,0xfeff
 je .Lwc_space
 call .Lprops
 test eax,1024
 jnz .Lwc_space
 test eax,512
 jz .Lwc_punct
 and eax,0xf800
 or eax,1
 ret
.Lwc_space:
 xor eax,eax
 ret
.Lwc_punct:
 mov eax,2
 ret
# Return previous UTF-8 scalar boundary from rax, no scanning from buffer start.
.Lprev_scalar:
 test rax,rax
 jz .Lps_done
 mov rdx,[r12+C_BUF]
 dec rax
.Lps_loop:
 test rax,rax
 jz .Lps_done
 movzx ecx,byte ptr [rdx+rax]
 and ecx,192
 cmp ecx,128
 jne .Lps_done
 dec rax
 jmp .Lps_loop
.Lps_done:
 ret
.Lword_left:
 push rbx
 sub rsp,16
 mov rdi,r12
 xor esi,esi
 call .D_navigation
 test rax,rax
 js .Lwl_native_fallback
 mov [rsp],rax
 jmp .Lwl_done
.Lwl_native_fallback:
 mov rax,[r12+C_CUR]
 mov [rsp],rax
 xor ebx,ebx
.Lwl_skip:
 mov rax,[rsp]
 test rax,rax
 jz .Lwl_done
 call .Lprev_scalar
 mov [rsp+8],rax
 mov rdx,rax
 call .Lword_class
 test eax,eax
 jnz .Lwl_first
 mov rax,[rsp+8]
 mov [rsp],rax
 jmp .Lwl_skip
.Lwl_first:
 mov ebx,eax
 mov rax,[rsp+8]
 mov [rsp],rax
 mov eax,ebx
 and eax,0xf800
 cmp eax,8<<11
 je .Lwl_done
 cmp eax,9<<11
 je .Lwl_done
 cmp eax,10<<11
 je .Lwl_done
.Lwl_body:
 mov rax,[rsp]
 test rax,rax
 jz .Lwl_done
 call .Lprev_scalar
 mov [rsp+8],rax
 mov rdx,rax
 call .Lword_class
 mov ecx,eax
 xor ecx,ebx
 test ecx,3
 jnz .Lwl_done
 mov ecx,eax
 and ecx,0xf800
 jz .Lwl_take
 mov edx,ebx
 and edx,0xf800
 jz .Lwl_take_class
 cmp ecx,edx
 jne .Lwl_done
.Lwl_take_class:
 mov ebx,eax
.Lwl_take:
 mov rax,[rsp+8]
 mov [rsp],rax
 jmp .Lwl_body
.Lwl_done:
 mov rax,[rsp]
 add rsp,16
 pop rbx
 jmp .Lmove_done
.Lword_right:
 push rbx
 sub rsp,16
 mov rdi,r12
 mov esi,1
 call .D_navigation
 test rax,rax
 js .Lwr_native_fallback
 mov [rsp],rax
 jmp .Lwr_done
.Lwr_native_fallback:
 mov rax,[r12+C_CUR]
 mov [rsp],rax
 cmp rax,[r12+C_LEN]
 jae .Lwr_done
 mov rdx,rax
 call .Lword_class
 mov ebx,eax
.Lwr_body:
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,[rsp]
 call ui_next_grapheme
 mov [rsp],rax
 cmp rax,[r12+C_LEN]
 jae .Lwr_done
 mov rdx,rax
 call .Lword_class
 test eax,eax
 jz .Lwr_spaces
 mov ecx,ebx
 and ecx,0xf800
 cmp ecx,8<<11
 je .Lwr_done
 cmp ecx,9<<11
 je .Lwr_done
 cmp ecx,10<<11
 je .Lwr_done
 mov ecx,eax
 xor ecx,ebx
 test ecx,3
 jnz .Lwr_done
 mov ecx,eax
 and ecx,0xf800
 jz .Lwr_body
 mov edx,ebx
 and edx,0xf800
 jz .Lwr_class
 cmp ecx,edx
 jne .Lwr_done
.Lwr_class:
 mov ebx,eax
 jmp .Lwr_body
.Lwr_spaces:
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,[rsp]
 call ui_next_grapheme
 mov [rsp],rax
 cmp rax,[r12+C_LEN]
 jae .Lwr_done
 mov rdx,rax
 call .Lword_class
 test eax,eax
 jz .Lwr_spaces
.Lwr_done:
 mov rax,[rsp]
 add rsp,16
 pop rbx
 jmp .Lmove_done
.Ldelete_word_left:
 mov rbp,[r12+C_CUR]
 call .Lword_left
 mov rsi,[r12+C_CUR]
 mov [r12+C_CUR],rbp
 push rsi
 call .Lsave_undo
 pop rsi
 mov rdx,rbp
 jmp .Ldelete_range
.Ldelete_word_right:
 mov rbp,[r12+C_CUR]
 call .Lword_right
 mov rdx,[r12+C_CUR]
 mov [r12+C_CUR],rbp
 push rdx
 call .Lsave_undo
 pop rdx
 mov rsi,rbp
 jmp .Ldelete_range
.Lup:
 cmp qword ptr [r12+C_MENU],0
 je .Lup_plain
 or r15d,INPUT_MENU_UP
 ret
.Lup_plain:
 cmp qword ptr [r12+C_EXTERNAL_HISTORY],0
 je .Lup_internal
 or r15d,4194304
 ret
.Lup_internal:
 call .Lvisual_layout
 mov rax,[r12+C_VROW]
 test rax,rax
 jnz .Lvisual_up_target
 # Original history policy: first move to start of the first visual row.
 cmp qword ptr [r12+C_CUR],0
 jne .Lvisual_first_home
 jmp .Lhistory_up
.Lvisual_first_home:
 xor eax,eax
 jmp .Lmove_done
.Lvisual_up_target:
 dec rax
 jmp .Lvisual_target
.Ldown:
 cmp qword ptr [r12+C_MENU],0
 je .Ldown_plain
 or r15d,INPUT_MENU_DOWN
 ret
.Ldown_plain:
 cmp qword ptr [r12+C_EXTERNAL_HISTORY],0
 je .Ldown_internal
 or r15d,8388608
 ret
.Ldown_internal:
 call .Lvisual_layout
 mov rax,[r12+C_VROW]
 inc rax
 cmp rax,[r12+C_VCOUNT]
 jb .Lvisual_target
 mov rax,[r12+C_LEN]
 cmp rax,[r12+C_CUR]
 jne .Lmove_done
 jmp .Lhistory_down
.Lvisual_target:
 mov [r12+C_TARGET],rax
 mov rcx,[r12+C_GOAL]
 cmp rcx,-1
 jne .Lvisual_have_goal
 mov rcx,[r12+C_VCOL]
 mov [r12+C_GOAL],rcx
.Lvisual_have_goal:
 mov eax,[r12+rax*4+C_VSTART]
 mov [r12+C_IX],rax
 mov qword ptr [r12+C_VC],0
 mov rdx,[r12+C_TARGET]
 inc rdx
 mov rcx,[r12+C_LEN]
 cmp rdx,[r12+C_VCOUNT]
 jae .Lvisual_target_end
 mov ecx,[r12+rdx*4+C_VSTART]
.Lvisual_target_end:
 mov [r12+C_END],rcx
.Lvisual_seek:
 mov rax,[r12+C_IX]
 cmp rax,[r12+C_END]
 jae .Lvisual_seek_done
 mov rdi,[r12+C_BUF]
 cmp byte ptr [rdi+rax],10
 je .Lvisual_seek_done
 mov rsi,[r12+C_LEN]
 mov rdx,rax
 call ui_next_grapheme
 mov [r12+C_WIDTH],rax # preserve next index temporarily
 mov rdi,[r12+C_BUF]
 add rdi,[r12+C_IX]
 mov rsi,rax
 sub rsi,[r12+C_IX]
 call ui_text_width
 add rax,[r12+C_VC]
 cmp rax,[r12+C_GOAL]
 ja .Lvisual_seek_done
 mov [r12+C_VC],rax
 mov rax,[r12+C_WIDTH]
 mov [r12+C_IX],rax
 jmp .Lvisual_seek
.Lvisual_seek_done:
 mov rax,[r12+C_IX]
 jmp .Lmove_done
# Build immutable-for-this-key visual row starts in private context. Width
# agrees with renderer: wrap before a cluster that would exceed content cols.
.Lvisual_layout:
 mov qword ptr [r12+C_IX],0
 mov qword ptr [r12+C_VR],0
 mov qword ptr [r12+C_VC],0
 mov dword ptr [r12+C_VSTART],0
.Llayout_loop:
 mov rax,[r12+C_IX]
 cmp rax,[r12+C_LEN]
 jae .Llayout_eof
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,rax
 call ui_next_grapheme
 mov [r12+C_END],rax
 mov rdi,[r12+C_BUF]
 add rdi,[r12+C_IX]
 mov rsi,rax
 sub rsi,[r12+C_IX]
 call ui_text_width
 mov [r12+C_WIDTH],rax
 mov rdx,[r12+C_VC]
 test rdx,rdx
 jz .Llayout_record
 add rdx,rax
 cmp rdx,[r12+C_COLUMNS]
 jbe .Llayout_record
 inc qword ptr [r12+C_VR]
 mov qword ptr [r12+C_VC],0
 mov rdx,[r12+C_VR]
 mov rax,[r12+C_IX]
 mov [r12+rdx*4+C_VSTART],eax
.Llayout_record:
 mov rax,[r12+C_IX]
 cmp rax,[r12+C_CUR]
 jne .Llayout_advance
 mov rax,[r12+C_VR]
 mov [r12+C_VROW],rax
 mov rax,[r12+C_VC]
 mov [r12+C_VCOL],rax
.Llayout_advance:
 mov rdi,[r12+C_BUF]
 mov rax,[r12+C_IX]
 cmp byte ptr [rdi+rax],10
 jne .Llayout_add_width
 inc qword ptr [r12+C_VR]
 mov qword ptr [r12+C_VC],0
 mov rdx,[r12+C_VR]
 mov rax,[r12+C_END]
 mov [r12+rdx*4+C_VSTART],eax
 jmp .Llayout_next
.Llayout_add_width:
 mov rax,[r12+C_WIDTH]
 add [r12+C_VC],rax
.Llayout_next:
 mov rax,[r12+C_END]
 mov [r12+C_IX],rax
 jmp .Llayout_loop
.Llayout_eof:
 cmp rax,[r12+C_CUR]
 jne .Llayout_count
 mov rax,[r12+C_VR]
 mov [r12+C_VROW],rax
 mov rax,[r12+C_VC]
 mov [r12+C_VCOL],rax
.Llayout_count:
 mov rax,[r12+C_VR]
 inc rax
 mov [r12+C_VCOUNT],rax
 ret
.Ldraft_save:
 mov rcx,[r12+C_LEN]
 mov [r12+C_DRAFTLEN],rcx
 mov rsi,[r12+C_BUF]
 lea rdi,[r12+C_DRAFT]
 rep movsb
 ret
.Lhistory_up:
 mov qword ptr [r12+C_HUP],1
 mov rax,[r12+C_HCOUNT]
 test rax,rax
 jz .Lbyte_ret
 mov rbx,[r12+C_HINDEX]
 cmp rbx,-1
 jne .Lhistory_older
 call .Ldraft_save
 mov rbx,[r12+C_HCOUNT]
 dec rbx
 jmp .Lhistory_load
.Lhistory_older:
 test rbx,rbx
 jz .Lbyte_ret
 dec rbx
 jmp .Lhistory_load
.Lhistory_down:
 mov qword ptr [r12+C_HUP],0
 mov rbx,[r12+C_HINDEX]
 cmp rbx,-1
 je .Lbyte_ret
 inc rbx
 cmp rbx,[r12+C_HCOUNT]
 jb .Lhistory_load
 mov qword ptr [r12+C_HINDEX],-1
 lea rsi,[r12+C_DRAFT]
 mov rcx,[r12+C_DRAFTLEN]
 jmp .Lhistory_copy
.Lhistory_load:
 mov [r12+C_HINDEX],rbx
 mov rcx,[r12+C_HLENS+rbx*8]
 mov rsi,rbx
 shl rsi,13
 lea rsi,[r12+rsi+C_HISTORY]
.Lhistory_copy:
 mov qword ptr [r12+C_GOAL],-1
 mov rax,[r12+C_CAP]
 dec rax
 cmp rcx,rax
 jbe .Lhistory_clamped
 mov rcx,rax
.Lhistory_clamp_boundary:
 test rcx,rcx
 jz .Lhistory_clamped
 movzx eax,byte ptr [rsi+rcx]
 and eax,192
 cmp eax,128
 jne .Lhistory_clamped
 dec rcx
 jmp .Lhistory_clamp_boundary
.Lhistory_clamped:
 mov [r12+C_LEN],rcx
 mov [r12+C_CUR],rcx
 cmp qword ptr [r12+C_HUP],1
 jne .Lhistory_cursor_ready
 mov qword ptr [r12+C_CUR],0
.Lhistory_cursor_ready:
 mov qword ptr [r12+C_HUP],0
 mov rdi,[r12+C_BUF]
 rep movsb
 mov byte ptr [rdi],0
 mov qword ptr [r12+C_ANCHOR],-1
 jmp .Lchanged
.global input_history_add
input_history_add:
 push rbx
 push rbp
 push r12
 mov r12,rdi
 mov rbp,rsi
 mov rbx,rdx
 test rdx,rdx
 jz .Lha_done
 cmp rbx,8191
 jbe .Lha_cap
 mov ebx,8191
.Lha_boundary:
 movzx eax,byte ptr [rbp+rbx]
 and eax,192
 cmp eax,128
 jne .Lha_cap
 dec rbx
 jmp .Lha_boundary
.Lha_cap:
 mov rax,[r12+C_HCOUNT]
 cmp rax,32
 jb .Lha_append
 lea rdi,[r12+C_HISTORY]
 lea rsi,[r12+C_HISTORY+8192]
 mov ecx,31*8192
 rep movsb
 lea rdi,[r12+C_HLENS]
 lea rsi,[r12+C_HLENS+8]
 mov ecx,31
 rep movsq
 mov eax,31
.Lha_append:
 mov [r12+C_HLENS+rax*8],rbx
 mov rdx,rax
 shl rdx,13
 lea rdi,[r12+rdx+C_HISTORY]
 mov rsi,rbp
 mov rcx,rbx
 rep movsb
 mov byte ptr [rdi],0
 inc rax
 mov [r12+C_HCOUNT],rax
 mov qword ptr [r12+C_HINDEX],-1
.Lha_done:
 pop r12
 pop rbp
 pop rbx
 xor eax,eax
 ret
.Lundo:
 mov rax,[r12+C_UPOS]
 test rax,rax
 jz .Lbyte_ret
 cmp rax,[r12+C_UCOUNT]
 jb .Lundo_have_current
 call .Ltimeline_append
 mov rax,[r12+C_UCOUNT]
 dec rax
.Lundo_have_current:
 test rax,rax
 jz .Lbyte_ret
 dec rax
 jmp .Ltimeline_restore
.Lredo:
 mov rax,[r12+C_UPOS]
 inc rax
 cmp rax,[r12+C_UCOUNT]
 jae .Lbyte_ret
.Ltimeline_restore:
 mov [r12+C_UPOS],rax
 add rax,[r12+C_USTART]
 cmp rax,17
 jb .Ltimeline_restore_slot
 sub rax,17
.Ltimeline_restore_slot:
 mov rcx,[r12+C_ULENS+rax*8]
 mov rdx,[r12+C_UCURS+rax*8]
 shl rax,16
 lea rsi,[r12+rax+C_UNDO]
 mov rax,rdx
.Lrestore_edit:
 mov [r12+C_LEN],rcx
 mov [r12+C_CUR],rax
 mov rdi,[r12+C_BUF]
 rep movsb
 mov byte ptr [rdi],0
 mov qword ptr [r12+C_ANCHOR],-1
 jmp .Lchanged
.Lsearch_start:
 mov qword ptr [r12+C_HUP],0
 call .Ldraft_save
 mov qword ptr [r12+C_SEARCH],1
 mov qword ptr [r12+C_SLEN],0
 mov byte ptr [r12+C_QUERY],0
 mov rax,[r12+C_HCOUNT]
 mov [r12+C_SINDEX],rax
 or r15d,INPUT_SEARCH
 jmp .Lsearch_again
.Lsearch_byte:
 cmp bl,18
 je .Lsearch_again
 cmp bl,13
 je .Lsearch_accept
 cmp bl,10
 je .Lsearch_accept
 cmp bl,3
 je .Lsearch_cancel
 cmp bl,127
 je .Lsearch_back
 cmp bl,8
 je .Lsearch_back
 cmp bl,32
 jb .Lbyte_ret
 mov rax,[r12+C_SLEN]
 cmp rax,255
 jae .Lfull
 mov [r12+C_QUERY+rax],bl
 inc rax
 mov [r12+C_SLEN],rax
 mov byte ptr [r12+C_QUERY+rax],0
 mov rax,[r12+C_HCOUNT]
 mov [r12+C_SINDEX],rax
 jmp .Lsearch_again
.Lsearch_back:
 mov rax,[r12+C_SLEN]
 test rax,rax
 jz .Lbyte_ret
 dec rax
.Lsearch_back_utf:
 movzx ecx,byte ptr [r12+C_QUERY+rax]
 and ecx,192
 cmp ecx,128
 jne .Lsearch_back_done
 test rax,rax
 jz .Lsearch_back_done
 dec rax
 jmp .Lsearch_back_utf
.Lsearch_back_done:
 mov [r12+C_SLEN],rax
 mov byte ptr [r12+C_QUERY+rax],0
 mov rax,[r12+C_HCOUNT]
 mov [r12+C_SINDEX],rax
.Lsearch_again:
 mov rbx,[r12+C_SINDEX]
.Lsearch_entry:
 test rbx,rbx
 jz .Lchanged
 dec rbx
 mov rdx,[r12+C_HLENS+rbx*8]
 mov rcx,[r12+C_SLEN]
 cmp rdx,rcx
 jb .Lsearch_entry
 mov r8,rbx
 shl r8,13
 lea r8,[r12+r8+C_HISTORY]
 xor r9d,r9d
 sub rdx,rcx
.Lsearch_offset:
 cmp r9,rdx
 ja .Lsearch_entry
 xor eax,eax
.Lsearch_compare:
 cmp rax,rcx
 jae .Lsearch_found
 mov r10b,[r8+r9]
 # indexed comparison uses offset + query index
 lea r11,[r8+r9]
 mov r10b,[r11+rax]
 cmp r10b,[r12+C_QUERY+rax]
 jne .Lsearch_next
 inc rax
 jmp .Lsearch_compare
.Lsearch_next:
 inc r9
 jmp .Lsearch_offset
.Lsearch_found:
 mov [r12+C_SINDEX],rbx
 mov rcx,[r12+C_HLENS+rbx*8]
 mov rsi,r8
 jmp .Lhistory_copy
.Lsearch_accept:
 mov qword ptr [r12+C_SEARCH],0
 mov qword ptr [r12+C_SLEN],0
 jmp .Lchanged
.Lsearch_cancel:
 mov qword ptr [r12+C_SEARCH],0
 mov qword ptr [r12+C_SLEN],0
 lea rsi,[r12+C_DRAFT]
 mov rcx,[r12+C_DRAFTLEN]
 jmp .Lhistory_copy
.global input_timeout
input_timeout:
 push r12
 mov r12,rdi
 cmp qword ptr [rdi+C_ESC],0
 je .Ltimeout_none
 mov rax,[rdi+C_ESC]
 cmp rax,1
 jne .Ltimeout_none
 mov qword ptr [rdi+C_ESC],0
 cmp qword ptr [rdi+C_MENU],0
 jne .Ltimeout_menu
 cmp qword ptr [rdi+C_SEARCH],0
 jne .Ltimeout_search
 mov eax,2097152
 pop r12
 ret
.Ltimeout_menu:
 mov qword ptr [rdi+C_MENU],0
 mov eax,INPUT_CHANGED
 pop r12
 ret
.Ltimeout_search:
 push r15
 xor r15d,r15d
 call .Lsearch_cancel
 mov rax,r15
 pop r15
 pop r12
 ret
.Ltimeout_none:
 xor eax,eax
 pop r12
 ret
.include "ui_unicode.inc"
.section .rodata
.Lpaste_end: .ascii "\033[201~"
.section .note.GNU-stack,"",@progbits

.text
.global ui_decode_mouse
# Complete SGR packet ptr,len,out32 ->0valid/-22. No editor side effects.
ui_decode_mouse:
 cmp rsi,9
 jb .Lmouse_decode_bad
 cmp rsi,32
 ja .Lmouse_decode_bad
 cmp word ptr [rdi],0x5b1b
 jne .Lmouse_decode_bad
 cmp byte ptr [rdi+2],60
 jne .Lmouse_decode_bad
 sub rsp,24
 mov r11,rdx
 mov ecx,3
 xor r8d,r8d
 xor r9d,r9d
 xor r10d,r10d
.Lmouse_decode_byte:
 cmp rcx,rsi
 jae .Lmouse_decode_invalid
 movzx eax,byte ptr [rdi+rcx]
 inc rcx
 cmp al,59
 je .Lmouse_decode_separator
 cmp al,77
 je .Lmouse_decode_final
 cmp al,109
 je .Lmouse_decode_final
 sub eax,48
 cmp eax,9
 ja .Lmouse_decode_invalid
 imul r9d,r9d,10
 add r9d,eax
 cmp r9d,65535
 ja .Lmouse_decode_invalid
 inc r10d
 jmp .Lmouse_decode_byte
.Lmouse_decode_separator:
 test r10d,r10d
 jz .Lmouse_decode_invalid
 cmp r8d,2
 jae .Lmouse_decode_invalid
 mov [rsp+r8*8],r9
 inc r8
 xor r9d,r9d
 xor r10d,r10d
 jmp .Lmouse_decode_byte
.Lmouse_decode_final:
 cmp rcx,rsi
 jne .Lmouse_decode_invalid
 cmp r8d,2
 jne .Lmouse_decode_invalid
 test r10d,r10d
 jz .Lmouse_decode_invalid
 test r9d,r9d
 jz .Lmouse_decode_invalid
 cmp qword ptr [rsp+8],0
 je .Lmouse_decode_invalid
 cmp qword ptr [rsp],255
 ja .Lmouse_decode_invalid
 mov [rsp+16],r9
 xor r10d,r10d
 cmp al,109
 sete r10b
 mov rax,[rsp]
 mov [r11],rax
 mov rax,[rsp+8]
 mov [r11+8],rax
 mov [r11+16],r9
 mov [r11+24],r10
 add rsp,24
 xor eax,eax
 ret
.Lmouse_decode_invalid:
 add rsp,24
.Lmouse_decode_bad:
 mov rax,-22
 ret

.text
.global input_pointer,input_selection,input_select_line,input_select_word
# Context, absolute visual row0, content column0, extend ->INPUT_CHANGED.
# Layout is exactly the editor's grapheme/wide-cell wrapping geometry.
input_pointer:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 mov rbx,rcx
 xor r15d,r15d
 call .Lvisual_layout
 mov rax,[r12+C_VCOUNT]
 dec rax
 cmp r13,rax
 cmova r13,rax
 test rbx,rbx
 jnz .Lpointer_extend
 mov qword ptr [r12+C_ANCHOR],-1
 jmp .Lpointer_seek
.Lpointer_extend:
 cmp qword ptr [r12+C_ANCHOR],-1
 jne .Lpointer_seek
 mov rax,[r12+C_CUR]
 mov [r12+C_ANCHOR],rax
.Lpointer_seek:
 mov [r12+C_GOAL],r14
 mov rax,r13
 call .Lvisual_target
 mov qword ptr [r12+C_GOAL],-1
 mov rax,r15
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Borrowed selected UTF8 bytes; empty selection returns0 and NULL/0.
input_selection:
 mov qword ptr [rsi],0
 mov qword ptr [rsi+8],0
 xor eax,eax
 mov r8,[rdi+C_ANCHOR]
 cmp r8,-1
 je .Lselection_return
 mov r9,[rdi+C_CUR]
 cmp r8,r9
 je .Lselection_return
 jb .Lselection_ordered
 xchg r8,r9
.Lselection_ordered:
 cmp r9,[rdi+C_LEN]
 ja .Lselection_return
 mov rdx,[rdi+C_BUF]
 add rdx,r8
 mov [rsi],rdx
 sub r9,r8
 mov [rsi+8],r9
 mov eax,1
.Lselection_return:
 ret
input_select_line:
 push r12
 push r13
 push r15
 mov r12,rdi
 xor r15d,r15d
 call .Lhome
 mov r13,[r12+C_CUR]
 call .Lend
 mov [r12+C_ANCHOR],r13
 mov qword ptr [r12+C_GOAL],-1
 mov rax,r15
 pop r15
 pop r13
 pop r12
 ret
input_select_word:
 push r12
 push r13
 push r15
 mov r12,rdi
 xor r15d,r15d
 mov rax,[r12+C_CUR]
 cmp rax,[r12+C_LEN]
 jae .Lselect_word_eof
 inc rax
 # Word-left accepts an index just after the clicked scalar.
 mov rdx,[r12+C_CUR]
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 call ui_next_grapheme
 jmp .Lselect_word_left
.Lselect_word_eof:
 test rax,rax
 jz .Lselect_word_empty
.Lselect_word_left:
 mov [r12+C_CUR],rax
 call .Lword_left
 mov r13,[r12+C_CUR]
 call .Lword_right
 mov rax,[r12+C_CUR]
.Lselect_word_trim:
 cmp rax,r13
 jbe .Lselect_word_commit
 call .Lprev_scalar
 mov [r12+C_CUR],rax
 mov rdx,rax
 call .Lword_class
 test eax,eax
 jz .Lselect_word_next_trim
 # C_CUR currently points before the last nonspace scalar; restore its end.
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,[r12+C_CUR]
 call ui_next_grapheme
 mov [r12+C_CUR],rax
 jmp .Lselect_word_commit
.Lselect_word_next_trim:
 mov rax,[r12+C_CUR]
 jmp .Lselect_word_trim
.Lselect_word_commit:
 mov [r12+C_ANCHOR],r13
 mov qword ptr [r12+C_DIRTY],1
 mov eax,INPUT_CHANGED
 jmp .Lselect_word_return
.Lselect_word_empty:
 mov qword ptr [r12+C_ANCHOR],-1
 mov eax,INPUT_CHANGED
.Lselect_word_return:
 pop r15
 pop r13
 pop r12
 ret

# ICU78.2 UCharsTrie dictionary machine. Immutable data are copied from the
# exact installed Qwen reference Node; no ICU/Node/shared library is used here.
# Source algorithm: unicode-org/icu release-78.2/common/ucharstrie.cpp.
.text
# state(pos*,remaining),UTF16 unit ->EAX no-match0/no-value1/value2/final3,EDXcost.
.D_step:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13d,esi
 mov rbx,[r12]
 test rbx,rbx
 jz .D_step_no
 mov rcx,[r12+8]
 test rcx,rcx
 js .D_step_node
 movzx eax,word ptr [rbx]
 cmp eax,r13d
 jne .D_step_no
 add rbx,2
 dec rcx
 mov [r12+8],rcx
 jmp .D_step_current
.D_step_node:
 movzx eax,word ptr [rbx]
 add rbx,2
.D_step_node_type:
 cmp eax,0x30
 jb .D_step_branch
 cmp eax,0x40
 jb .D_step_linear
 test eax,0x8000
 jnz .D_step_no
 cmp eax,0x4040
 jb .D_step_skip_node_ready
 cmp eax,0x7fc0
 jb .D_step_skip_node_two
 add rbx,2
.D_step_skip_node_two:
 add rbx,2
.D_step_skip_node_ready:
 and eax,0x3f
 jmp .D_step_node_type
.D_step_linear:
 sub eax,0x30
 dec eax
 movsxd rcx,eax
 mov [r12+8],rcx
 movzx eax,word ptr [rbx]
 cmp eax,r13d
 jne .D_step_no
 add rbx,2
 jmp .D_step_current
.D_step_branch:
 mov r10d,eax
 test r10d,r10d
 jnz .D_step_branch_length
 movzx r10d,word ptr [rbx]
 add rbx,2
.D_step_branch_length:
 inc r10d
.D_step_binary:
 cmp r10d,5
 jbe .D_step_branch_linear
 movzx eax,word ptr [rbx]
 add rbx,2
 xor r9d,r9d
 cmp r13d,eax
 setb r9b
 movzx eax,word ptr [rbx]
 add rbx,2
 cmp eax,0xfc00
 jb .D_step_binary_delta
 cmp eax,0xffff
 je .D_step_binary_three
 sub eax,0xfc00
 shl eax,16
 movzx edx,word ptr [rbx]
 or eax,edx
 add rbx,2
 jmp .D_step_binary_delta
.D_step_binary_three:
 movzx eax,word ptr [rbx]
 shl eax,16
 movzx edx,word ptr [rbx+2]
 or eax,edx
 add rbx,4
.D_step_binary_delta:
 mov ecx,r10d
 shr ecx,1
 test r9d,r9d
 jz .D_step_binary_right
 mov r10d,ecx
 lea rbx,[rbx+rax*2]
 jmp .D_step_binary
.D_step_binary_right:
 sub r10d,ecx
 jmp .D_step_binary
.D_step_branch_linear:
 cmp r10d,1
 je .D_step_branch_last
 movzx eax,word ptr [rbx]
 add rbx,2
 cmp eax,r13d
 je .D_step_branch_found
 movzx eax,word ptr [rbx]
 add rbx,2
 and eax,0x7fff
 cmp eax,0x4000
 jb .D_step_branch_skip_ready
 cmp eax,0x7fff
 jb .D_step_branch_skip_two
 add rbx,2
.D_step_branch_skip_two:
 add rbx,2
.D_step_branch_skip_ready:
 dec r10d
 jmp .D_step_branch_linear
.D_step_branch_found:
 movzx eax,word ptr [rbx]
 test eax,0x8000
 jnz .D_step_branch_at_value
 add rbx,2
 cmp eax,0x4000
 jb .D_step_branch_delta_ready
 cmp eax,0x7fff
 je .D_step_branch_delta_three
 sub eax,0x4000
 shl eax,16
 movzx edx,word ptr [rbx]
 or eax,edx
 add rbx,2
 jmp .D_step_branch_delta_ready
.D_step_branch_delta_three:
 movzx eax,word ptr [rbx]
 shl eax,16
 movzx edx,word ptr [rbx+2]
 or eax,edx
 add rbx,4
.D_step_branch_delta_ready:
 lea rbx,[rbx+rax*2]
.D_step_branch_at_value:
 mov qword ptr [r12+8],-1
 jmp .D_step_current
.D_step_branch_last:
 movzx eax,word ptr [rbx]
 add rbx,2
 cmp eax,r13d
 jne .D_step_no
 mov qword ptr [r12+8],-1
.D_step_current:
 mov [r12],rbx
 cmp qword ptr [r12+8],0
 jge .D_step_no_value
 movzx eax,word ptr [rbx]
 cmp eax,0x40
 jb .D_step_no_value
 test eax,0x8000
 jz .D_step_intermediate_value
 and eax,0x7fff
 cmp eax,0x4000
 jb .D_step_final_small
 cmp eax,0x7fff
 je .D_step_final_three
 sub eax,0x4000
 shl eax,16
 movzx edx,word ptr [rbx+2]
 or edx,eax
 jmp .D_step_final_result
.D_step_final_three:
 movzx edx,word ptr [rbx+2]
 shl edx,16
 movzx eax,word ptr [rbx+4]
 or edx,eax
 jmp .D_step_final_result
.D_step_final_small:
 mov edx,eax
.D_step_final_result:
 mov eax,3
 jmp .D_step_return
.D_step_intermediate_value:
 cmp eax,0x4040
 jb .D_step_intermediate_small
 cmp eax,0x7fc0
 jae .D_step_intermediate_three
 and eax,0x7fc0
 sub eax,0x4040
 shl eax,10
 movzx edx,word ptr [rbx+2]
 or edx,eax
 jmp .D_step_intermediate_result
.D_step_intermediate_three:
 movzx edx,word ptr [rbx+2]
 shl edx,16
 movzx eax,word ptr [rbx+4]
 or edx,eax
 jmp .D_step_intermediate_result
.D_step_intermediate_small:
 shr eax,6
 lea edx,[rax-1]
.D_step_intermediate_result:
 mov eax,2
 jmp .D_step_return
.D_step_no_value:
 mov eax,1
 xor edx,edx
 jmp .D_step_return
.D_step_no:
 mov qword ptr [r12],0
 xor eax,eax
 xor edx,edx
.D_step_return:
 pop r13
 pop r12
 pop rbx
 ret
.D_step_cp:
 cmp esi,0xffff
 jbe .D_step
 push rbx
 push r12
 sub rsp,8
 mov rbx,rdi
 mov r12d,esi
 sub esi,0x10000
 shr esi,10
 add esi,0xd800
 call .D_step
 cmp eax,1
 je .D_step_trail
 cmp eax,2
 jne .D_step_supplementary_no
.D_step_trail:
 mov rdi,rbx
 mov esi,r12d
 and esi,1023
 add esi,0xdc00
 call .D_step
 jmp .D_step_cp_return
.D_step_supplementary_no:
 xor eax,eax
.D_step_cp_return:
 add rsp,8
 pop r12
 pop rbx
 ret
# Code point array,count,costs20: -1 for no word; otherwise exact dictionary cost.
.D_matches:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,16
 mov r12,rdi
 mov r13,rsi
 cmp r13,20
 jbe .D_matches_count
 mov r13d,20
.D_matches_count:
 mov r14,rdx
 mov rdi,rdx
 mov ecx,20
 mov eax,-1
 rep stosd
 lea rax,[rip+.Ldictionary_trie]
 mov [rsp],rax
 mov qword ptr [rsp+8],-1
 xor r15d,r15d
.D_matches_next:
 cmp r15,r13
 jae .D_matches_done
 mov rdi,rsp
 mov esi,[r12+r15*4]
 call .D_step_cp
 test eax,eax
 jz .D_matches_done
 cmp eax,1
 je .D_matches_continue
 mov [r14+r15*4],edx
 cmp eax,3
 je .D_matches_done
.D_matches_continue:
 inc r15
 jmp .D_matches_next
.D_matches_done:
 add rsp,16
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.balign 2
.Ldictionary_trie:
.incbin "ui_cjk_icu78.bin"
.Ldictionary_trie_end:
.include "ui_dictionary.inc"

# Native CJK segmentation uses ICU's exact dictionary costs and dynamic program.
# UTF8 spans are mapped through Unicode17 NFKC compatibility/kana normalization.
.equ D_RAW,0
.equ D_RAWLEN,8
.equ D_OUT,16
.equ D_CAP,24
.equ D_NORM,32
.equ D_ORIGCOUNT,40
.equ D_ORIGPOS,48
.equ D_NEXT,56
.equ D_CODES,64
.equ D_MAP,D_CODES+4096*4
.equ D_COST,D_MAP+4097*8
.equ D_PREV,D_COST+4097*4
.equ D_BREAK,D_PREV+4097*4
.equ D_MATCH,((D_BREAK+4097+7)/8)*8
.equ D_LOCALS,D_MATCH+80
.equ D_FRAME,((D_LOCALS+64+15)/16)*16+8
.text
.D_is_cjk:
 cmp eax,0x30fc
 je .D_bool_yes
 cmp eax,0x3099
 je .D_bool_yes
 cmp eax,0x309a
 je .D_bool_yes
 cmp eax,0xff70
 je .D_bool_yes
 cmp eax,0xff9e
 je .D_bool_yes
 cmp eax,0xff9f
 je .D_bool_yes
 sub rsp,8
 call .Lprops
 add rsp,8
 and eax,0xf800
 cmp eax,8<<11
 jb .D_bool_no
 cmp eax,10<<11
 ja .D_bool_no
.D_bool_yes:
 mov eax,1
 ret
.D_bool_no:
 xor eax,eax
 ret
.D_is_katakana:
 cmp eax,0x30a1
 jb .D_kata_halfwidth
 cmp eax,0x30fe
 ja .D_kata_halfwidth
 cmp eax,0x30fb
 jne .D_bool_yes
.D_kata_halfwidth:
 cmp eax,0xff66
 jb .D_bool_no
 cmp eax,0xff9f
 jbe .D_bool_yes
 jmp .D_bool_no
# CP ->RDI normalized sequence pointer or0,ECX count. Sorted immutable table.
.D_nfkc_lookup:
 xor ecx,ecx
 mov r8d,DICT_NFKC_COUNT
 lea r9,[rip+.Ldict_nfkc]
.D_nfkc_search:
 cmp ecx,r8d
 jae .D_nfkc_none
 lea edx,[rcx+r8]
 shr edx,1
 lea r10,[rdx+rdx*2]
 lea r10,[r9+r10*4]
 cmp eax,[r10]
 jb .D_nfkc_lower
 ja .D_nfkc_upper
 mov ecx,[r10+8]
 mov edx,[r10+4]
 lea rdi,[rip+.Ldict_nfkc_pool]
 lea rdi,[rdi+rdx*4]
 ret
.D_nfkc_lower:
 mov r8d,edx
 jmp .D_nfkc_search
.D_nfkc_upper:
 lea ecx,[rdx+1]
 jmp .D_nfkc_search
.D_nfkc_none:
 xor edi,edi
 xor ecx,ecx
 ret
# Append CP EAX, compose Hiragana/Katakana combining voice marks in-place.
.D_append_normalized:
 mov rdx,[rbx+D_NORM]
 test rdx,rdx
 jz .D_append_plain
 cmp eax,0x3099
 je .D_append_compose
 cmp eax,0x309a
 jne .D_append_plain
.D_append_compose:
 mov r8d,[rbx+rdx*4+D_CODES-4]
 lea r9,[rip+.Ldict_kana_compose]
 mov ecx,DICT_KANA_COMPOSE_COUNT
.D_append_compose_next:
 cmp r8d,[r9]
 jne .D_append_compose_advance
 cmp eax,[r9+4]
 jne .D_append_compose_advance
 mov eax,[r9+8]
 mov [rbx+rdx*4+D_CODES-4],eax
 xor eax,eax
 ret
.D_append_compose_advance:
 add r9,12
 loop .D_append_compose_next
.D_append_plain:
 cmp rdx,4096
 jae .D_append_bad
 mov [rbx+rdx*4+D_CODES],eax
 mov rax,[rbx+D_ORIGPOS]
 mov [rbx+rdx*8+D_MAP],rax
 inc qword ptr [rbx+D_NORM]
 xor eax,eax
 ret
.D_append_bad:
 mov rax,-28
 ret

.global ui_cjk_boundaries
# UTF8 CJK range,len,out16B(start,end) spans,cap ->count/-1fallback/-28capacity.
# Cap0 measures count. Source uses dictionary only for <=1500 original scalars.
ui_cjk_boundaries:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,D_FRAME
 mov rbx,rsp
 mov [rbx+D_RAW],rdi
 mov [rbx+D_RAWLEN],rsi
 mov [rbx+D_OUT],rdx
 mov [rbx+D_CAP],rcx
 mov qword ptr [rbx+D_NORM],0
 mov qword ptr [rbx+D_ORIGCOUNT],0
 mov qword ptr [rbx+D_ORIGPOS],0
 mov qword ptr [rbx+D_NEXT],0
 cmp rsi,6000
 ja .D_bound_fallback
 test rsi,rsi
 jz .D_bound_empty
 test rdi,rdi
 jz .D_bound_fallback
 test rcx,rcx
 jz .D_normalize_next
 test rdx,rdx
 jz .D_bound_fallback
.D_normalize_next:
 mov rdx,[rbx+D_NEXT]
 cmp rdx,[rbx+D_RAWLEN]
 jae .D_normalize_done
 mov [rbx+D_ORIGPOS],rdx
 mov rdi,[rbx+D_RAW]
 mov rsi,[rbx+D_RAWLEN]
 call .Ldecode
 mov [rbx+D_NEXT],rdx
 mov r12d,eax
 call .D_is_cjk
 test eax,eax
 jz .D_bound_fallback
 inc qword ptr [rbx+D_ORIGCOUNT]
 cmp qword ptr [rbx+D_ORIGCOUNT],1500
 ja .D_bound_fallback
 mov eax,r12d
 call .D_nfkc_lookup
 test rdi,rdi
 jz .D_normalize_plain
 mov r13,rdi
 mov r14d,ecx
.D_normalize_expansion:
 mov eax,[r13]
 call .D_append_normalized
 test rax,rax
 js .D_bound_fallback
 add r13,4
 dec r14
 jnz .D_normalize_expansion
 jmp .D_normalize_next
.D_normalize_plain:
 mov eax,r12d
 call .D_append_normalized
 test rax,rax
 js .D_bound_fallback
 jmp .D_normalize_next
.D_normalize_done:
 mov r12,[rbx+D_NORM]
 mov rax,[rbx+D_RAWLEN]
 mov [rbx+r12*8+D_MAP],rax
 lea rdi,[rbx+D_COST]
 lea rcx,[r12+1]
 mov eax,-1
 rep stosd
 lea rdi,[rbx+D_PREV]
 lea rcx,[r12+1]
 rep stosd
 lea rdi,[rbx+D_BREAK]
 lea rcx,[r12+1]
 xor eax,eax
 rep stosb
 mov dword ptr [rbx+D_COST],0
 xor r13d,r13d
.D_dp_next:
 cmp r13,r12
 jae .D_dp_done
 cmp dword ptr [rbx+r13*4+D_COST],-1
 je .D_dp_advance
 lea rdi,[rbx+r13*4+D_CODES]
 mov rsi,r12
 sub rsi,r13
 lea rdx,[rbx+D_MATCH]
 call .D_matches
 cmp dword ptr [rbx+D_MATCH],-1
 jne .D_dp_candidates
 mov dword ptr [rbx+D_MATCH],255
.D_dp_candidates:
 xor r14d,r14d
.D_dp_candidate:
 cmp r14,20
 jae .D_dp_katakana
 lea r15,[r13+r14+1]
 cmp r15,r12
 ja .D_dp_katakana
 mov eax,[rbx+r14*4+D_MATCH]
 cmp eax,-1
 je .D_dp_candidate_next
 add eax,[rbx+r13*4+D_COST]
 cmp eax,[rbx+r15*4+D_COST]
 jae .D_dp_candidate_next
 mov [rbx+r15*4+D_COST],eax
 mov [rbx+r15*4+D_PREV],r13d
.D_dp_candidate_next:
 inc r14
 jmp .D_dp_candidate
.D_dp_katakana:
 mov eax,[rbx+r13*4+D_CODES]
 call .D_is_katakana
 test eax,eax
 jz .D_dp_advance
 test r13,r13
 jz .D_dp_kata_run
 mov eax,[rbx+r13*4+D_CODES-4]
 call .D_is_katakana
 test eax,eax
 jnz .D_dp_advance
.D_dp_kata_run:
 mov r14d,1
.D_dp_kata_next:
 cmp r14,20
 jae .D_dp_advance
 lea r15,[r13+r14]
 cmp r15,r12
 jae .D_dp_kata_cost
 mov eax,[rbx+r15*4+D_CODES]
 call .D_is_katakana
 test eax,eax
 jz .D_dp_kata_cost
 inc r14
 jmp .D_dp_kata_next
.D_dp_kata_cost:
 mov eax,8192
 cmp r14,8
 ja .D_dp_kata_relax
 lea rdx,[rip+.Ldict_katakana_cost]
 mov eax,[rdx+r14*4]
.D_dp_kata_relax:
 add eax,[rbx+r13*4+D_COST]
 lea r15,[r13+r14]
 cmp eax,[rbx+r15*4+D_COST]
 jae .D_dp_advance
 mov [rbx+r15*4+D_COST],eax
 mov [rbx+r15*4+D_PREV],r13d
.D_dp_advance:
 inc r13
 jmp .D_dp_next
.D_dp_done:
 mov r13,r12
.D_dp_trace:
 mov byte ptr [rbx+r13+D_BREAK],1
 test r13,r13
 jz .D_dp_spans
 mov eax,[rbx+r13*4+D_PREV]
 cmp eax,-1
 je .D_bound_fallback
 cmp rax,r13
 jae .D_bound_fallback
 mov r13,rax
 jmp .D_dp_trace
.D_dp_spans:
 mov r13d,1
 xor r14d,r14d
 xor r15d,r15d
.D_dp_span_next:
 cmp r13,r12
 ja .D_dp_spans_done
 cmp byte ptr [rbx+r13+D_BREAK],0
 je .D_dp_span_advance
 mov rbp,[rbx+r13*8+D_MAP]
 cmp rbp,r14
 jbe .D_dp_span_advance
 cmp qword ptr [rbx+D_CAP],0
 je .D_dp_span_count
 cmp r15,[rbx+D_CAP]
 jae .D_bound_cap
 mov rax,r15
 shl rax,4
 add rax,[rbx+D_OUT]
 mov [rax],r14
 mov [rax+8],rbp
.D_dp_span_count:
 inc r15
 mov r14,rbp
.D_dp_span_advance:
 inc r13
 jmp .D_dp_span_next
.D_dp_spans_done:
 mov rax,r15
 jmp .D_bound_return
.D_bound_empty:
 xor eax,eax
 jmp .D_bound_return
.D_bound_cap:
 mov rax,-28
 jmp .D_bound_return
.D_bound_fallback:
 mov rax,-1
.D_bound_return:
 add rsp,D_FRAME
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.section .rodata
.Ldict_katakana_cost: .long 8192,984,408,240,204,252,300,372,480

.text
# Context,direction0left1right ->byte boundary/-1 use ordinary Unicode fallback.
# The source disables dictionary segmentation above1500 scalars in this line.
.D_navigation:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,24064
 mov r12,rdi
 mov ebx,esi
 mov r13,[r12+C_CUR]
 mov [rsp+24008],r13
 mov r14,r13
 mov r15,r13
 mov rdi,[r12+C_BUF]
.D_nav_line_left:
 test r14,r14
 jz .D_nav_line_right
 cmp byte ptr [rdi+r14-1],10
 je .D_nav_line_right
 dec r14
 jmp .D_nav_line_left
.D_nav_line_right:
 cmp r15,[r12+C_LEN]
 jae .D_nav_line_ready
 cmp byte ptr [rdi+r15],10
 je .D_nav_line_ready
 inc r15
 jmp .D_nav_line_right
.D_nav_line_ready:
 mov [rsp+24032],r14
 mov [rsp+24040],r15
 test ebx,ebx
 jnz .D_nav_cross_right
 cmp r13,r14
 jne .D_nav_segment_line
 mov rax,r13
 test rax,rax
 jz .D_nav_return
 dec rax
 jmp .D_nav_return
.D_nav_cross_right:
 cmp r13,r15
 jne .D_nav_segment_line
 mov rax,r13
 cmp rax,[r12+C_LEN]
 jae .D_nav_return
 inc rax
 jmp .D_nav_return
.D_nav_segment_line:
 mov rdi,[r12+C_BUF]
 add rdi,r14
 mov rsi,r15
 sub rsi,r14
 mov rdx,rsp
 mov ecx,1500
 call ui_word_boundaries
 test rax,rax
 js .D_nav_fallback
 mov r15,rax
 sub r13,r14
 mov [rsp+24008],r13
 test ebx,ebx
 jnz .D_nav_find_right_start
 xor ecx,ecx
 xor r8d,r8d
 mov r9,-1
.D_nav_find_left:
 cmp rcx,r15
 jae .D_nav_left_gap
 mov rax,rcx
 shl rax,4
 mov rdx,[rsp+rax]
 cmp rdx,r13
 je .D_nav_left_found
 ja .D_nav_left_gap
 mov r8,rdx
 mov r9,[rsp+rax+8]
 cmp r13,r9
 jbe .D_nav_left_found
 inc rcx
 jmp .D_nav_find_left
.D_nav_left_gap:
 # Source fallback in whitespace skips punctuation, then a strict-script word.
 mov r13,[r12+C_CUR]
.D_nav_left_nonword:
 cmp r13,r14
 jbe .D_nav_left_absolute
 mov rax,r13
 call .Lprev_scalar
 mov [rsp+24016],rax
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,rax
 call .Ldecode
 call .W_strict_class
 test eax,eax
 jnz .D_nav_left_strict_first
 mov r13,[rsp+24016]
 jmp .D_nav_left_nonword
.D_nav_left_strict_first:
 mov ebx,eax
 mov r13,[rsp+24016]
.D_nav_left_strict:
 cmp r13,r14
 jbe .D_nav_left_absolute
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,r13
 call .Ldecode
 call .W_source_is_cjk
 mov [rsp+24056],rax
 mov rax,r13
 call .Lprev_scalar
 mov [rsp+24016],rax
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,rax
 call .Ldecode
 call .W_strict_class
 cmp eax,ebx
 jne .D_nav_left_absolute
 cmp qword ptr [rsp+24056],0
 je .D_nav_left_strict_take
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,[rsp+24016]
 call .Ldecode
 call .W_source_is_cjk
 test eax,eax
 jnz .D_nav_left_absolute
.D_nav_left_strict_take:
 mov r13,[rsp+24016]
 jmp .D_nav_left_strict
.D_nav_left_absolute:
 mov rax,r13
 jmp .D_nav_return
.D_nav_left_found:
 lea rax,[r14+r8]
 jmp .D_nav_return
.D_nav_find_right_start:
 xor r13d,r13d
.D_nav_find_right:
 cmp r13,r15
 jae .D_nav_right_line_end
 mov rax,r13
 shl rax,4
 mov rcx,[rsp+rax]
 mov rdx,[rsp+rax+8]
 mov [rsp+24016],rcx
 mov [rsp+24024],rdx
 mov r8,[rsp+24008]
 cmp r8,rdx
 jae .D_nav_find_right_next
 cmp r8,rcx
 jae .D_nav_right_containing
 # Starting in whitespace: the source skips nonword spans and consumes the
 # first next word, rather than stopping before that word.
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 lea rdx,[r14+rcx]
 call .Ldecode
 call .Lprops
 test eax,512
 jz .D_nav_find_right_next
 shr eax,16
 and eax,31
 cmp eax,4
 je .D_nav_find_right_next
.D_nav_right_found:
 add r14,[rsp+24024]
 jmp .D_nav_success
.D_nav_right_containing:
 add r14,[rsp+24024]
 jmp .D_nav_skip_whitespace
.D_nav_find_right_next:
 inc r13
 jmp .D_nav_find_right
.D_nav_right_line_end:
 mov rax,[rsp+24040]
 jmp .D_nav_return
.D_nav_skip_whitespace:
 cmp r14,[rsp+24040]
 jae .D_nav_success
 mov rdx,r14
 call .Lword_class
 test eax,eax
 jnz .D_nav_success
 mov rdi,[r12+C_BUF]
 mov rsi,[r12+C_LEN]
 mov rdx,r14
 call .Ldecode
 mov r14,rdx
 jmp .D_nav_skip_whitespace
.D_nav_success:
 mov rax,r14
 jmp .D_nav_return
.D_nav_fallback:
 mov rax,-1
.D_nav_return:
 add rsp,24064
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

# Unicode17 UAX29 word boundaries, then ICU CJK dictionary refinement.
# Source word navigation splits literal '.' and omits whitespace-only segments.
.equ W_RAW,0
.equ W_LEN,8
.equ W_OUT,16
.equ W_CAP,24
.equ W_N,32
.equ W_INDEX,40
.equ W_AA,48
.equ W_BB,56
.equ W_CJSTART,64
.equ W_CJEND,72
.equ W_CP,128
.equ W_PROPS,W_CP+1501*4
.equ W_MAP,W_PROPS+1501*4
.equ W_FLAGS,W_MAP+1502*8
.equ W_TEMP,((W_FLAGS+1502+15)/16)*16
.equ W_FRAME,W_TEMP+24000+8
.text
.W_previous_significant:
 test rax,rax
 js .W_significant_none
 mov rdx,rax
 mov eax,[rbx+rax*4+W_PROPS]
 shr eax,16
 and eax,31
 cmp eax,4
 je .W_previous_skip
 cmp eax,5
 je .W_previous_skip
 cmp eax,7
 jne .W_significant_return
.W_previous_skip:
 lea rax,[rdx-1]
 jmp .W_previous_significant
.W_next_significant:
 cmp rax,[rbx+W_N]
 jae .W_significant_none
 mov rdx,rax
 mov eax,[rbx+rax*4+W_PROPS]
 shr eax,16
 and eax,31
 cmp eax,4
 je .W_next_skip
 cmp eax,5
 je .W_next_skip
 cmp eax,7
 jne .W_significant_return
.W_next_skip:
 lea rax,[rdx+1]
 jmp .W_next_significant
.W_significant_none:
 xor eax,eax
 mov rdx,-1
.W_significant_return:
 ret
# W_INDEX is a boundary before a scalar. EAX1joins/EAX0breaks.
.W_join:
 push rbp
 push r12
 push r13
 push r14
 push r15
 mov r12,[rbx+W_INDEX]
 mov r14d,[rbx+r12*4+W_PROPS-4]
 shr r14d,16
 and r14d,31
 mov r15d,[rbx+r12*4+W_PROPS]
 shr r15d,16
 and r15d,31
 cmp r14d,1
 jne .W_join_newline
 cmp r15d,2
 je .W_join_yes
.W_join_newline:
 cmp r14d,1
 jb .W_join_right_newline
 cmp r14d,3
 jbe .W_join_no
.W_join_right_newline:
 cmp r15d,1
 jb .W_join_emoji
 cmp r15d,3
 jbe .W_join_no
.W_join_emoji:
 cmp r14d,5
 jne .W_join_spaces
 test dword ptr [rbx+r12*4+W_PROPS],16
 jnz .W_join_yes
.W_join_spaces:
 cmp r14d,18
 jne .W_join_ignored
 cmp r15d,18
 je .W_join_yes
.W_join_ignored:
 cmp r15d,4
 je .W_join_yes
 cmp r15d,5
 je .W_join_yes
 cmp r15d,7
 je .W_join_yes
 lea rax,[r12-1]
 call .W_previous_significant
 test rax,rax
 jz .W_join_no
 mov r14d,eax
 mov r13,rdx
 cmp dword ptr [rbx+r12*4+W_CP],46
 je .W_join_no
 cmp dword ptr [rbx+r13*4+W_CP],46
 je .W_join_no
 lea rax,[r13-1]
 call .W_previous_significant
 mov [rbx+W_AA],rax
 lea rax,[r12+1]
 call .W_next_significant
 mov [rbx+W_BB],rax
 cmp r14d,9
 jne .W_join_ah_test
 cmp r15d,11
 je .W_join_yes
 cmp r15d,12
 jne .W_join_ah_test
 cmp qword ptr [rbx+W_BB],9
 je .W_join_yes
.W_join_ah_test:
 cmp r14d,9
 je .W_join_after_ah
 cmp r14d,10
 je .W_join_after_ah
 cmp r14d,16
 je .W_join_after_numeric
 cmp r14d,8
 je .W_join_after_katakana
 cmp r14d,17
 je .W_join_after_extendnum
 cmp r14d,6
 je .W_join_regional
 jmp .W_join_mid_left
.W_join_after_ah:
 cmp r15d,9
 je .W_join_yes
 cmp r15d,10
 je .W_join_yes
 cmp r15d,16
 je .W_join_yes
 cmp r15d,17
 je .W_join_yes
 cmp r15d,11
 je .W_join_mid_right_ah
 cmp r15d,13
 je .W_join_mid_right_ah
 cmp r15d,14
 jne .W_join_no
.W_join_mid_right_ah:
 cmp qword ptr [rbx+W_BB],9
 je .W_join_yes
 cmp qword ptr [rbx+W_BB],10
 je .W_join_yes
 jmp .W_join_no
.W_join_after_numeric:
 cmp r15d,9
 je .W_join_yes
 cmp r15d,10
 je .W_join_yes
 cmp r15d,16
 je .W_join_yes
 cmp r15d,17
 je .W_join_yes
 cmp r15d,11
 je .W_join_mid_right_numeric
 cmp r15d,13
 je .W_join_mid_right_numeric
 cmp r15d,15
 jne .W_join_no
.W_join_mid_right_numeric:
 cmp qword ptr [rbx+W_BB],16
 je .W_join_yes
 jmp .W_join_no
.W_join_after_katakana:
 cmp r15d,8
 je .W_join_yes
 cmp r15d,17
 je .W_join_yes
 jmp .W_join_no
.W_join_after_extendnum:
 cmp r15d,9
 je .W_join_yes
 cmp r15d,10
 je .W_join_yes
 cmp r15d,16
 je .W_join_yes
 cmp r15d,8
 je .W_join_yes
 cmp r15d,17
 je .W_join_yes
 jmp .W_join_no
.W_join_mid_left:
 cmp r14d,12
 jne .W_join_mid_ah_left
 cmp r15d,9
 jne .W_join_no
 cmp qword ptr [rbx+W_AA],9
 je .W_join_yes
 jmp .W_join_no
.W_join_mid_ah_left:
 cmp r15d,9
 je .W_join_mid_left_ah_check
 cmp r15d,10
 jne .W_join_mid_numeric_left
.W_join_mid_left_ah_check:
 cmp r14d,11
 je .W_join_mid_left_ah_previous
 cmp r14d,13
 je .W_join_mid_left_ah_previous
 cmp r14d,14
 jne .W_join_no
.W_join_mid_left_ah_previous:
 cmp qword ptr [rbx+W_AA],9
 je .W_join_yes
 cmp qword ptr [rbx+W_AA],10
 je .W_join_yes
 jmp .W_join_no
.W_join_mid_numeric_left:
 cmp r15d,16
 jne .W_join_no
 cmp r14d,11
 je .W_join_mid_left_numeric_previous
 cmp r14d,13
 je .W_join_mid_left_numeric_previous
 cmp r14d,15
 jne .W_join_no
.W_join_mid_left_numeric_previous:
 cmp qword ptr [rbx+W_AA],16
 je .W_join_yes
 jmp .W_join_no
.W_join_regional:
 cmp r15d,6
 jne .W_join_no
 xor ebp,ebp
 mov rax,r13
.W_join_regional_count:
 call .W_previous_significant
 cmp eax,6
 jne .W_join_regional_ready
 inc rbp
 lea rax,[rdx-1]
 jmp .W_join_regional_count
.W_join_regional_ready:
 test ebp,1
 jnz .W_join_yes
.W_join_no:
 xor eax,eax
 jmp .W_join_return
.W_join_yes:
 mov eax,1
.W_join_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 ret

.global ui_word_boundaries
# UTF8 line,len,out16(start,end),cap ->nonwhite segment count/-1fallback/-28cap.
ui_word_boundaries:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,W_FRAME
 mov rbx,rsp
 mov [rbx+W_RAW],rdi
 mov [rbx+W_LEN],rsi
 mov [rbx+W_OUT],rdx
 mov [rbx+W_CAP],rcx
 mov qword ptr [rbx+W_N],0
 cmp rsi,6000
 ja .W_bound_fallback
 test rsi,rsi
 jz .W_bound_empty
 test rdi,rdi
 jz .W_bound_fallback
 xor r12d,r12d
.W_decode_next:
 cmp r12,[rbx+W_LEN]
 jae .W_decode_done
 mov r13,[rbx+W_N]
 cmp r13,1500
 jae .W_bound_fallback
 mov [rbx+r13*8+W_MAP],r12
 mov rdi,[rbx+W_RAW]
 mov rsi,[rbx+W_LEN]
 mov rdx,r12
 call .Ldecode
 mov r12,rdx
 mov [rbx+r13*4+W_CP],eax
 call .Lprops
 mov [rbx+r13*4+W_PROPS],eax
 inc qword ptr [rbx+W_N]
 jmp .W_decode_next
.W_decode_done:
 mov r12,[rbx+W_N]
 mov rax,[rbx+W_LEN]
 mov [rbx+r12*8+W_MAP],rax
 lea rdi,[rbx+W_FLAGS]
 lea rcx,[r12+1]
 mov al,1
 rep stosb
 mov qword ptr [rbx+W_INDEX],1
.W_rules_next:
 mov rax,[rbx+W_INDEX]
 cmp rax,r12
 jae .W_dictionary_start
 call .W_join
 test eax,eax
 jz .W_rules_break
 mov rax,[rbx+W_INDEX]
 mov byte ptr [rbx+rax+W_FLAGS],0
.W_rules_break:
 inc qword ptr [rbx+W_INDEX]
 jmp .W_rules_next
.W_dictionary_start:
 xor r13d,r13d
.W_dictionary_next:
 cmp r13,r12
 jae .W_output_start
 mov eax,[rbx+r13*4+W_PROPS]
 shr eax,21
 and eax,7
 test eax,eax
 jnz .W_complex_start
 mov eax,[rbx+r13*4+W_CP]
 call .D_is_cjk
 test eax,eax
 jz .W_dictionary_advance
 mov [rbx+W_CJSTART],r13
 mov r14,r13
.W_dictionary_run:
 inc r14
 cmp r14,r12
 jae .W_dictionary_range
 mov eax,[rbx+r14*4+W_CP]
 call .D_is_cjk
 test eax,eax
 jnz .W_dictionary_run
.W_dictionary_range:
 mov [rbx+W_CJEND],r14
 mov r15,[rbx+r13*8+W_MAP]
 mov rdi,[rbx+W_RAW]
 add rdi,r15
 mov rsi,[rbx+r14*8+W_MAP]
 sub rsi,r15
 lea rdx,[rbx+W_TEMP]
 mov ecx,1500
 call ui_cjk_boundaries
 jmp .W_dictionary_apply
.W_complex_start:
 mov [rbx+W_AA],rax
 mov [rbx+W_CJSTART],r13
 mov r14,r13
.W_complex_run:
 inc r14
 cmp r14,r12
 jae .W_complex_range
 mov eax,[rbx+r14*4+W_PROPS]
 shr eax,21
 and eax,7
 cmp rax,[rbx+W_AA]
 je .W_complex_run
.W_complex_range:
 mov [rbx+W_CJEND],r14
 mov r15,[rbx+r13*8+W_MAP]
 mov rdi,[rbx+W_RAW]
 add rdi,r15
 mov rsi,[rbx+r14*8+W_MAP]
 sub rsi,r15
 mov rdx,[rbx+W_AA]
 lea rcx,[rbx+W_TEMP]
 mov r8d,1500
 call ui_complex_boundaries
.W_dictionary_apply:
 test rax,rax
 jle .W_dictionary_range_done
 mov [rbx+W_INDEX],rax
 lea rdi,[rbx+r13+W_FLAGS+1]
 mov rcx,r14
 sub rcx,r13
 dec rcx
 xor eax,eax
 rep stosb
 xor ebp,ebp
.W_dictionary_break_next:
 cmp rbp,[rbx+W_INDEX]
 jae .W_dictionary_range_done
 mov rax,rbp
 shl rax,4
 mov r15,[rbx+rax+W_TEMP+8]
 mov rax,[rbx+W_CJSTART]
 add r15,[rbx+rax*8+W_MAP]
 xor ecx,ecx
 lea r8,[r12+1]
.W_dictionary_boundary_search:
 cmp rcx,r8
 jae .W_dictionary_break_advance
 lea rdx,[rcx+r8]
 shr rdx,1
 cmp r15,[rbx+rdx*8+W_MAP]
 jb .W_dictionary_boundary_lower
 ja .W_dictionary_boundary_upper
 cmp rdx,[rbx+W_CJEND]
 je .W_dictionary_break_advance
 mov byte ptr [rbx+rdx+W_FLAGS],1
 jmp .W_dictionary_break_advance
.W_dictionary_boundary_lower:
 mov r8,rdx
 jmp .W_dictionary_boundary_search
.W_dictionary_boundary_upper:
 lea rcx,[rdx+1]
 jmp .W_dictionary_boundary_search
.W_dictionary_break_advance:
 inc rbp
 jmp .W_dictionary_break_next
.W_dictionary_range_done:
 mov r13,[rbx+W_CJEND]
 jmp .W_dictionary_next
.W_dictionary_advance:
 inc r13
 jmp .W_dictionary_next
.W_output_start:
 xor r13d,r13d
 mov r14d,1
 xor r15d,r15d
.W_output_next:
 cmp r14,r12
 ja .W_output_done
 cmp byte ptr [rbx+r14+W_FLAGS],0
 je .W_output_advance
 mov rbp,r13
.W_output_whitespace:
 cmp rbp,r14
 jae .W_output_skip
 test dword ptr [rbx+rbp*4+W_PROPS],1024
 jnz .W_output_white_advance
 cmp dword ptr [rbx+rbp*4+W_CP],0xfeff
 jne .W_output_segment
.W_output_white_advance:
 inc rbp
 jmp .W_output_whitespace
.W_output_segment:
 cmp qword ptr [rbx+W_CAP],0
 je .W_output_count
 cmp r15,[rbx+W_CAP]
 jae .W_bound_cap
 mov rdx,[rbx+W_OUT]
 test rdx,rdx
 jz .W_bound_fallback
 mov rax,r15
 shl rax,4
 add rdx,rax
 mov rax,[rbx+r13*8+W_MAP]
 mov [rdx],rax
 mov rax,[rbx+r14*8+W_MAP]
 mov [rdx+8],rax
.W_output_count:
 inc r15
.W_output_skip:
 mov r13,r14
.W_output_advance:
 inc r14
 jmp .W_output_next
.W_output_done:
 mov rax,r15
 jmp .W_bound_return
.W_bound_cap:
 mov rax,-28
 jmp .W_bound_return
.W_bound_fallback:
 mov rax,-1
 jmp .W_bound_return
.W_bound_empty:
 xor eax,eax
.W_bound_return:
 add rsp,W_FRAME
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret

.text
# Source isWordCharStrict plus getCharScript's six explicit script categories.
.W_strict_class:
 sub rsp,8
 call .Lprops
 add rsp,8
 test eax,512
 jz .W_strict_no
 mov edx,eax
 shr edx,16
 and edx,31
 cmp edx,4
 je .W_strict_no
 and eax,0xf800
 cmp eax,1<<11
 je .W_strict_yes
 cmp eax,3<<11
 je .W_strict_yes
 cmp eax,5<<11
 je .W_strict_yes
 cmp eax,8<<11
 je .W_strict_yes
 cmp eax,9<<11
 je .W_strict_yes
 cmp eax,10<<11
 je .W_strict_yes
 xor eax,eax
.W_strict_yes:
 or eax,1
 ret
.W_strict_no:
 xor eax,eax
 ret

.text
.W_source_is_cjk:
 cmp eax,0x3400
 jb .W_source_cjk_kana
 cmp eax,0x4dbf
 jbe .D_bool_yes
 cmp eax,0x4e00
 jb .D_bool_no
 cmp eax,0x9fff
 jbe .D_bool_yes
 cmp eax,0xac00
 jb .D_bool_no
 cmp eax,0xd7af
 jbe .D_bool_yes
 cmp eax,0xf900
 jb .D_bool_no
 cmp eax,0xfaff
 jbe .D_bool_yes
 jmp .D_bool_no
.W_source_cjk_kana:
 cmp eax,0x3040
 jb .D_bool_no
 cmp eax,0x30ff
 jbe .D_bool_yes
 jmp .D_bool_no

# ICU BytesTrie for Thai/Lao/Myanmar/Khmer dictionaries. Values are only word
# terminals; the source PossibleWord algorithm also uses nonterminal prefixes.
.text
# rdi after lead,EAX shifted lead ->EAXvalue,RDI after encoded value.
.B_value:
 cmp eax,0x51
 jb .B_value_one
 cmp eax,0x6c
 jb .B_value_two
 cmp eax,0x7e
 jb .B_value_three
 cmp eax,0x7e
 je .B_value_four
 movzx eax,byte ptr [rdi]
 shl eax,24
 movzx edx,byte ptr [rdi+1]
 shl edx,16
 or eax,edx
 movzx edx,byte ptr [rdi+2]
 shl edx,8
 or eax,edx
 movzx edx,byte ptr [rdi+3]
 or eax,edx
 add rdi,4
 ret
.B_value_one:
 sub eax,0x10
 ret
.B_value_two:
 sub eax,0x51
 shl eax,8
 movzx edx,byte ptr [rdi]
 or eax,edx
 inc rdi
 ret
.B_value_three:
 sub eax,0x6c
 shl eax,16
 movzx edx,byte ptr [rdi]
 shl edx,8
 or eax,edx
 movzx edx,byte ptr [rdi+1]
 or eax,edx
 add rdi,2
 ret
.B_value_four:
 movzx eax,byte ptr [rdi]
 shl eax,16
 movzx edx,byte ptr [rdi+1]
 shl edx,8
 or eax,edx
 movzx edx,byte ptr [rdi+2]
 or eax,edx
 add rdi,3
 ret
# rdi delta lead ->EAXdelta,RDI after encoded delta.
.B_delta:
 movzx eax,byte ptr [rdi]
 inc rdi
 cmp eax,0xc0
 jb .B_delta_return
 cmp eax,0xf0
 jb .B_delta_two
 cmp eax,0xfe
 jb .B_delta_three
 cmp eax,0xfe
 je .B_value_four
 mov eax,0x7f
 jmp .B_value
.B_delta_two:
 sub eax,0xc0
 shl eax,8
 movzx edx,byte ptr [rdi]
 or eax,edx
 inc rdi
 ret
.B_delta_three:
 sub eax,0xf0
 shl eax,16
 movzx edx,byte ptr [rdi]
 shl edx,8
 or eax,edx
 movzx edx,byte ptr [rdi+1]
 or eax,edx
 add rdi,2
.B_delta_return:
 ret
# State(pos*,remaining),byte ->0none/1prefix/2terminal/3final terminal.
.B_step:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13d,esi
 mov rbx,[r12]
 test rbx,rbx
 jz .B_step_no
 mov rcx,[r12+8]
 test rcx,rcx
 js .B_step_node
 movzx eax,byte ptr [rbx]
 cmp eax,r13d
 jne .B_step_no
 inc rbx
 dec rcx
 mov [r12+8],rcx
 jmp .B_step_current
.B_step_node:
 movzx eax,byte ptr [rbx]
 inc rbx
 cmp eax,0x10
 jb .B_step_branch
 cmp eax,0x20
 jb .B_step_linear
 test eax,1
 jnz .B_step_no
 mov rdi,rbx
 shr eax,1
 call .B_value
 mov rbx,rdi
 jmp .B_step_node
.B_step_linear:
 sub eax,0x10
 dec eax
 movsxd rcx,eax
 mov [r12+8],rcx
 movzx eax,byte ptr [rbx]
 cmp eax,r13d
 jne .B_step_no
 inc rbx
 jmp .B_step_current
.B_step_branch:
 mov r10d,eax
 test r10d,r10d
 jnz .B_step_length_ready
 movzx r10d,byte ptr [rbx]
 inc rbx
.B_step_length_ready:
 inc r10d
.B_step_binary:
 cmp r10d,5
 jbe .B_step_branch_linear
 movzx eax,byte ptr [rbx]
 inc rbx
 xor r9d,r9d
 cmp r13d,eax
 setb r9b
 mov rdi,rbx
 call .B_delta
 mov rbx,rdi
 mov ecx,r10d
 shr ecx,1
 test r9d,r9d
 jz .B_step_binary_right
 mov r10d,ecx
 add rbx,rax
 jmp .B_step_binary
.B_step_binary_right:
 sub r10d,ecx
 jmp .B_step_binary
.B_step_branch_linear:
 cmp r10d,1
 je .B_step_branch_last
 movzx eax,byte ptr [rbx]
 inc rbx
 cmp eax,r13d
 je .B_step_branch_found
 movzx eax,byte ptr [rbx]
 inc rbx
 shr eax,1
 mov rdi,rbx
 call .B_value
 mov rbx,rdi
 dec r10d
 jmp .B_step_branch_linear
.B_step_branch_found:
 movzx eax,byte ptr [rbx]
 test eax,1
 jnz .B_step_branch_value
 inc rbx
 shr eax,1
 mov rdi,rbx
 call .B_value
 lea rbx,[rdi+rax]
.B_step_branch_value:
 mov qword ptr [r12+8],-1
 jmp .B_step_current
.B_step_branch_last:
 movzx eax,byte ptr [rbx]
 inc rbx
 cmp eax,r13d
 jne .B_step_no
 mov qword ptr [r12+8],-1
.B_step_current:
 mov [r12],rbx
 cmp qword ptr [r12+8],0
 jge .B_step_prefix
 movzx eax,byte ptr [rbx]
 cmp eax,0x20
 jb .B_step_prefix
 and eax,1
 add eax,2
 jmp .B_step_return
.B_step_prefix:
 mov eax,1
 jmp .B_step_return
.B_step_no:
 mov qword ptr [r12],0
 xor eax,eax
.B_step_return:
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Ldictionary_thai: .incbin "ui_thai_icu78.bin"
.Ldictionary_lao: .incbin "ui_lao_icu78.bin"
.Ldictionary_burmese: .incbin "ui_burmese_icu78.bin"
.Ldictionary_khmer: .incbin "ui_khmer_icu78.bin"

# Exact ICU PossibleWord three-word lookahead shared by four SA scripts.
.equ S_RAW,0
.equ S_RAWLEN,8
.equ S_TYPE,16
.equ S_OUT,24
.equ S_CAP,32
.equ S_N,40
.equ S_POS,48
.equ S_FOUND,56
.equ S_CURRENT,64
.equ S_WORDLEN,72
.equ S_CHARS,80
.equ S_TRIE,88
.equ S_OFFSET,96
.equ S_SEL0,104
.equ S_SEL1,112
.equ S_SEL2,120
.equ S_CP,256
.equ S_PROPS,S_CP+1501*4
.equ S_MAP,S_PROPS+1501*4
.equ S_BREAK,S_MAP+1502*8
.equ S_SLOTS,((S_BREAK+1502+15)/16)*16
.equ S_FRAME,S_SLOTS+3*256+8
.text
# Shared frameRBX; slotptr,startCP ->candidate count, sets S_POS to longest.
.B_candidates:
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,16
 mov r12,rdi
 mov r13,rsi
 cmp rsi,[r12]
 je .B_candidates_ready
 mov [r12],rsi
 mov qword ptr [r12+8],0
 mov qword ptr [r12+16],0
 mov rax,[rbx+S_TRIE]
 mov [rsp],rax
 mov qword ptr [rsp+8],-1
 mov r14,r13
.B_candidates_match:
 cmp r14,[rbx+S_N]
 jae .B_candidates_ready
 mov esi,[rbx+r14*4+S_CP]
 cmp esi,0x200d
 je .B_transform_zwj
 cmp esi,0x200c
 je .B_transform_zwnj
 sub esi,[rbx+S_OFFSET]
 cmp esi,0xfd
 ja .B_transform_zwj
 jmp .B_candidates_step
.B_transform_zwj:
 mov esi,255
 jmp .B_candidates_step
.B_transform_zwnj:
 mov esi,254
.B_candidates_step:
 mov rdi,rsp
 call .B_step
 lea rdx,[r14+1]
 sub rdx,r13
 mov [r12+16],rdx
 test eax,eax
 jz .B_candidates_ready
 cmp eax,1
 je .B_candidates_continue
 mov rcx,[r12+8]
 cmp rcx,20
 jae .B_candidates_terminal_ready
 mov [r12+rcx*8+40],rdx
 inc qword ptr [r12+8]
.B_candidates_terminal_ready:
 cmp eax,3
 je .B_candidates_ready
.B_candidates_continue:
 inc r14
 jmp .B_candidates_match
.B_candidates_prefix_fail:
 lea rdx,[r14+1]
 sub rdx,r13
 mov [r12+16],rdx
.B_candidates_ready:
 mov rax,[r12+8]
 mov rcx,rax
 dec rcx
 mov [r12+24],rcx
 mov [r12+32],rcx
 mov rdx,r13
 test rax,rax
 jz .B_candidates_cursor
 add rdx,[r12+rcx*8+40]
.B_candidates_cursor:
 mov [rbx+S_POS],rdx
 add rsp,16
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 ret
.B_backup:
 mov rcx,[rdi+24]
 test rcx,rcx
 jle .B_backup_none
 dec rcx
 mov [rdi+24],rcx
 mov rax,[rdi]
 add rax,[rdi+rcx*8+40]
 mov [rbx+S_POS],rax
 mov eax,1
 ret
.B_backup_none:
 xor eax,eax
 ret
.B_accept:
 mov rcx,[rdi+32]
 mov rax,[rdi+rcx*8+40]
 mov rdx,[rdi]
 add rdx,rax
 mov [rbx+S_POS],rdx
 ret
.B_mark:
 mov rax,[rdi+24]
 mov [rdi+32],rax
 ret
.B_slot_for_found:
 mov rax,[rbx+S_FOUND]
 xor edx,edx
 mov ecx,3
 div rcx
 shl rdx,8
 lea rdi,[rbx+rdx+S_SLOTS]
 ret
.B_select_slots:
 sub rsp,8
 call .B_slot_for_found
 mov [rbx+S_SEL0],rdi
 add rdi,256
 lea rax,[rbx+S_SLOTS+3*256]
 cmp rdi,rax
 jb .B_select_slot1
 lea rdi,[rbx+S_SLOTS]
.B_select_slot1:
 mov [rbx+S_SEL1],rdi
 add rdi,256
 cmp rdi,rax
 jb .B_select_slot2
 lea rdi,[rbx+S_SLOTS]
.B_select_slot2:
 mov [rbx+S_SEL2],rdi
 add rsp,8
 ret

.global ui_complex_boundaries
# UTF8 SA range,len,type1Thai2Lao3Myanmar4Khmer,out16pairs,cap ->count/-error.
ui_complex_boundaries:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,S_FRAME
 mov rbx,rsp
 mov [rbx+S_RAW],rdi
 mov [rbx+S_RAWLEN],rsi
 mov [rbx+S_TYPE],rdx
 mov [rbx+S_OUT],rcx
 mov [rbx+S_CAP],r8
 mov qword ptr [rbx+S_N],0
 mov qword ptr [rbx+S_POS],0
 mov qword ptr [rbx+S_FOUND],0
 cmp rsi,6000
 ja .S_fallback
 cmp edx,1
 jb .S_fallback
 cmp edx,4
 ja .S_fallback
 lea rax,[rip+.Lcomplex_dictionary_table]
 dec edx
 shl edx,4
 mov rcx,[rax+rdx]
 add rcx,rax
 mov [rbx+S_TRIE],rcx
 mov rcx,[rax+rdx+8]
 mov [rbx+S_OFFSET],rcx
 xor r12d,r12d
.S_decode_next:
 cmp r12,[rbx+S_RAWLEN]
 jae .S_decode_done
 mov r13,[rbx+S_N]
 cmp r13,1500
 jae .S_fallback
 mov [rbx+r13*8+S_MAP],r12
 mov rdi,[rbx+S_RAW]
 mov rsi,[rbx+S_RAWLEN]
 mov rdx,r12
 call .Ldecode
 mov r12,rdx
 mov [rbx+r13*4+S_CP],eax
 call .Lprops
 mov [rbx+r13*4+S_PROPS],eax
 shr eax,21
 and eax,7
 cmp rax,[rbx+S_TYPE]
 jne .S_fallback
 inc qword ptr [rbx+S_N]
 jmp .S_decode_next
.S_decode_done:
 mov r12,[rbx+S_N]
 mov rax,[rbx+S_RAWLEN]
 mov [rbx+r12*8+S_MAP],rax
 lea rdi,[rbx+S_BREAK]
 lea rcx,[r12+1]
 xor eax,eax
 rep stosb
 mov byte ptr [rbx+S_BREAK],1
 mov byte ptr [rbx+r12+S_BREAK],1
 lea rdi,[rbx+S_SLOTS]
 mov ecx,3*256/8
 rep stosq
 mov qword ptr [rbx+S_SLOTS],-1
 mov qword ptr [rbx+S_SLOTS+256],-1
 mov qword ptr [rbx+S_SLOTS+512],-1
 cmp r12,4
 jb .S_output_start
 jne .S_loop
 cmp qword ptr [rbx+S_TYPE],1
 je .S_output_start
.S_loop:
 mov rax,[rbx+S_POS]
 cmp rax,[rbx+S_N]
 jae .S_output_start
 mov [rbx+S_CURRENT],rax
 mov qword ptr [rbx+S_WORDLEN],0
 call .B_select_slots
 mov rdi,[rbx+S_SEL0]
 mov rsi,[rbx+S_POS]
 call .B_candidates
 cmp eax,1
 je .S_accept
 cmp eax,1
 jbe .S_combine
 mov rax,[rbx+S_POS]
 cmp rax,[rbx+S_N]
 jae .S_accept
.S_lookahead_first:
 mov rdi,[rbx+S_SEL1]
 mov rsi,[rbx+S_POS]
 call .B_candidates
 test eax,eax
 jz .S_lookahead_backup_first
 mov rdi,[rbx+S_SEL0]
 call .B_mark
 mov rax,[rbx+S_POS]
 cmp rax,[rbx+S_N]
 jae .S_accept
.S_lookahead_second:
 mov rdi,[rbx+S_SEL2]
 mov rsi,[rbx+S_POS]
 call .B_candidates
 test eax,eax
 jz .S_lookahead_backup_second
 mov rdi,[rbx+S_SEL0]
 call .B_mark
 jmp .S_accept
.S_lookahead_backup_second:
 mov rdi,[rbx+S_SEL1]
 call .B_backup
 test eax,eax
 jnz .S_lookahead_second
.S_lookahead_backup_first:
 mov rdi,[rbx+S_SEL0]
 call .B_backup
 test eax,eax
 jnz .S_lookahead_first
.S_accept:
 mov rdi,[rbx+S_SEL0]
 call .B_accept
 mov [rbx+S_WORDLEN],rax
 inc qword ptr [rbx+S_FOUND]
.S_combine:
 mov rax,[rbx+S_POS]
 cmp rax,[rbx+S_N]
 jae .S_marks
 cmp qword ptr [rbx+S_WORDLEN],3
 jae .S_marks
 call .B_slot_for_found
 mov rsi,[rbx+S_POS]
 call .B_candidates
 test eax,eax
 jnz .S_combine_restore
 cmp qword ptr [rbx+S_WORDLEN],0
 je .S_unknown_scan_start
 call .B_slot_for_found
 cmp qword ptr [rdi+16],3
 jae .S_combine_restore
.S_unknown_scan_start:
 mov qword ptr [rbx+S_CHARS],0
.S_unknown_scan:
 mov rax,[rbx+S_POS]
 mov r13d,[rbx+rax*4+S_PROPS]
 inc rax
 mov [rbx+S_POS],rax
 inc qword ptr [rbx+S_CHARS]
 cmp rax,[rbx+S_N]
 jae .S_unknown_scanned
 test r13d,1<<26
 jz .S_unknown_scan
 test dword ptr [rbx+rax*4+S_PROPS],1<<25
 jz .S_unknown_scan
 # Source probes a word one slot beyond the current accepted-word count.
 call .B_slot_for_found
 add rdi,256
 lea rax,[rbx+S_SLOTS+3*256]
 cmp rdi,rax
 jb .S_unknown_probe_slot
 lea rdi,[rbx+S_SLOTS]
.S_unknown_probe_slot:
 mov rsi,[rbx+S_POS]
 call .B_candidates
 mov edx,eax
 mov rax,[rbx+S_CURRENT]
 add rax,[rbx+S_WORDLEN]
 add rax,[rbx+S_CHARS]
 mov [rbx+S_POS],rax
 test edx,edx
 jz .S_unknown_scan
.S_unknown_scanned:
 cmp qword ptr [rbx+S_WORDLEN],0
 jne .S_unknown_add
 inc qword ptr [rbx+S_FOUND]
.S_unknown_add:
 mov rax,[rbx+S_CHARS]
 add [rbx+S_WORDLEN],rax
 jmp .S_marks
.S_combine_restore:
 mov rax,[rbx+S_CURRENT]
 add rax,[rbx+S_WORDLEN]
 mov [rbx+S_POS],rax
.S_marks:
 mov rax,[rbx+S_POS]
 cmp rax,[rbx+S_N]
 jae .S_suffix
 test dword ptr [rbx+rax*4+S_PROPS],1<<24
 jz .S_suffix
 inc qword ptr [rbx+S_POS]
 inc qword ptr [rbx+S_WORDLEN]
 jmp .S_marks
.S_suffix:
 cmp qword ptr [rbx+S_TYPE],1
 jne .S_push
 mov rax,[rbx+S_POS]
 cmp rax,[rbx+S_N]
 jae .S_push
 cmp qword ptr [rbx+S_WORDLEN],0
 jle .S_push
 call .B_slot_for_found
 mov rsi,[rbx+S_POS]
 call .B_candidates
 test eax,eax
 jnz .S_suffix_restore
 mov rax,[rbx+S_POS]
 mov ecx,[rbx+rax*4+S_CP]
 cmp ecx,0xe2f
 jne .S_suffix_repeat
 mov edx,[rbx+rax*4+S_CP-4]
 cmp edx,0xe2f
 je .S_push
 cmp edx,0xe46
 je .S_push
 inc rax
 inc qword ptr [rbx+S_WORDLEN]
 mov [rbx+S_POS],rax
 cmp rax,[rbx+S_N]
 jae .S_push
 mov ecx,[rbx+rax*4+S_CP]
.S_suffix_repeat:
 cmp ecx,0xe46
 jne .S_push
 cmp dword ptr [rbx+rax*4+S_CP-4],0xe46
 je .S_push
 inc qword ptr [rbx+S_POS]
 inc qword ptr [rbx+S_WORDLEN]
 jmp .S_push
.S_suffix_restore:
 mov rax,[rbx+S_CURRENT]
 add rax,[rbx+S_WORDLEN]
 mov [rbx+S_POS],rax
.S_push:
 mov rax,[rbx+S_CURRENT]
 add rax,[rbx+S_WORDLEN]
 cmp rax,[rbx+S_CURRENT]
 jbe .S_fallback
 cmp rax,[rbx+S_N]
 ja .S_fallback
 mov [rbx+S_POS],rax
 mov byte ptr [rbx+rax+S_BREAK],1
 jmp .S_loop
.S_output_start:
 xor r13d,r13d
 mov r14d,1
 xor r15d,r15d
.S_output_next:
 cmp r14,[rbx+S_N]
 ja .S_output_done
 cmp byte ptr [rbx+r14+S_BREAK],0
 je .S_output_advance
 cmp qword ptr [rbx+S_CAP],0
 je .S_output_count
 cmp r15,[rbx+S_CAP]
 jae .S_capacity
 mov rdx,[rbx+S_OUT]
 test rdx,rdx
 jz .S_fallback
 mov rax,r15
 shl rax,4
 add rdx,rax
 mov rax,[rbx+r13*8+S_MAP]
 mov [rdx],rax
 mov rax,[rbx+r14*8+S_MAP]
 mov [rdx+8],rax
.S_output_count:
 inc r15
 mov r13,r14
.S_output_advance:
 inc r14
 jmp .S_output_next
.S_output_done:
 mov rax,r15
 jmp .S_return
.S_capacity:
 mov rax,-28
 jmp .S_return
.S_fallback:
 mov rax,-1
.S_return:
 add rsp,S_FRAME
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
.section .rodata
.Lcomplex_dictionary_table:
 .quad .Ldictionary_thai-.Lcomplex_dictionary_table,0xe00
 .quad .Ldictionary_lao-.Lcomplex_dictionary_table,0xe80
 .quad .Ldictionary_burmese-.Lcomplex_dictionary_table,0x1000
 .quad .Ldictionary_khmer-.Lcomplex_dictionary_table,0x1780
