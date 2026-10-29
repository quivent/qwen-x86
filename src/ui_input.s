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
 test edx,edx
 jnz .Lbyte_ret
 cmp eax,64
 je .Lsgr_wheel_up
 cmp eax,65
 je .Lsgr_wheel_down
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
