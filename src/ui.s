# Native viewport renderer; all styles originate here or trusted markdown formatter.
.include "ui_abi.inc"
.equ U_RECORDS,512
.equ U_BLOCK,1048576
.section .rodata
.Lu_logo0: .byte 32,226,150,132,226,150,132,226,150,132,226,150,132,226,150,132,226,150,132,32,32,226,150,132,226,150,132,32,32,32,32,32,226,150,132,226,150,132,32,226,150,132,226,150,132,226,150,132,226,150,132,226,150,132,226,150,132,226,150,132,32,226,150,132,226,150,132,226,150,132,32,32,32,32,226,150,132,226,150,132,0
.Lu_logo1: .byte 226,150,136,226,150,136,226,149,148,226,149,144,226,149,144,226,149,144,226,150,136,226,150,136,226,149,151,226,150,136,226,150,136,226,149,145,32,32,32,32,226,150,136,226,150,136,226,149,145,226,150,136,226,150,136,226,149,148,226,149,144,226,149,144,226,149,144,226,149,144,226,149,157,226,150,136,226,150,136,226,150,136,226,150,136,226,149,151,32,32,226,150,136,226,150,136,226,149,145,0
.Lu_logo2: .byte 226,150,136,226,150,136,226,149,145,32,32,32,226,150,136,226,150,136,226,149,145,226,150,136,226,150,136,226,149,145,32,226,150,136,226,149,151,32,226,150,136,226,150,136,226,149,145,226,150,136,226,150,136,226,150,136,226,150,136,226,150,136,226,149,151,32,32,226,150,136,226,150,136,226,149,148,226,150,136,226,150,136,226,149,151,32,226,150,136,226,150,136,226,149,145,0
.Lu_logo3: .byte 226,150,136,226,150,136,226,149,145,226,150,132,226,150,132,32,226,150,136,226,150,136,226,149,145,226,150,136,226,150,136,226,149,145,226,150,136,226,150,136,226,150,136,226,149,151,226,150,136,226,150,136,226,149,145,226,150,136,226,150,136,226,149,148,226,149,144,226,149,144,226,149,157,32,32,226,150,136,226,150,136,226,149,145,226,149,154,226,150,136,226,150,136,226,149,151,226,150,136,226,150,136,226,149,145,0
.Lu_logo4: .byte 226,149,154,226,150,136,226,150,136,226,150,136,226,150,136,226,150,136,226,150,136,226,149,148,226,149,157,226,149,154,226,150,136,226,150,136,226,150,136,226,149,148,226,150,136,226,150,136,226,150,136,226,149,148,226,149,157,226,150,136,226,150,136,226,150,136,226,150,136,226,150,136,226,150,136,226,150,136,226,149,151,226,150,136,226,150,136,226,149,145,32,226,149,154,226,150,136,226,150,136,226,150,136,226,150,136,226,149,145,0
.Lu_logo5: .byte 32,226,149,154,226,149,144,226,149,144,226,150,128,226,150,128,226,149,144,226,149,157,32,32,226,149,154,226,149,144,226,149,144,226,149,157,226,149,154,226,149,144,226,149,144,226,149,157,32,226,149,154,226,149,144,226,149,144,226,149,144,226,149,144,226,149,144,226,149,144,226,149,157,226,149,154,226,149,144,226,149,157,32,32,226,149,154,226,149,144,226,149,144,226,149,144,226,149,157,0
.Lu_logos: .quad .Lu_logo0,.Lu_logo1,.Lu_logo2,.Lu_logo3,.Lu_logo4,.Lu_logo5
.equ U_LOGO_WIDTH,37
.Lu_reset: .byte 27,91,48,109,0
.Lu_default_primary: .byte 27,91,51,56,59,50,59,50,48,53,59,50,49,52,59,50,52,52,109,0
.Lu_default_muted: .byte 27,91,51,56,59,50,59,49,48,56,59,49,49,50,59,49,51,52,109,0
.Lu_default_accent: .byte 27,91,51,56,59,50,59,50,48,51,59,49,54,54,59,50,52,55,109,0
.Lu_default_success: .byte 27,91,51,56,59,50,59,49,54,54,59,50,50,55,59,49,54,49,109,0
.Lu_default_error: .byte 27,91,51,56,59,50,59,50,52,51,59,49,51,57,59,49,54,56,109,0
.Lu_default_warning: .byte 27,91,51,56,59,50,59,50,52,57,59,50,50,54,59,49,55,53,109,0
.Lu_bold: .byte 27,91,49,109,0
.Lu_home: .byte 27,91,72,0
.Lu_clear: .byte 27,91,74,0
.Lu_start: .byte 27,91,63,49,48,52,57,104,27,91,63,50,53,108,27,91,63,50,48,48,52,104,27,91,63,49,48,48,50,104,27,91,63,49,48,48,54,104,0
.Lu_restore: .byte 27,91,63,49,48,48,51,108,27,91,48,109,27,91,63,49,48,48,50,108,27,91,63,49,48,48,54,108,27,91,63,50,48,48,52,108,27,91,63,50,53,104,27,91,63,49,48,52,57,108,0
.Lu_space: .byte 32,0
.Lu_margin: .byte 32,32,0
.Lu_cont: .byte 32,32,32,32,0
.Lu_newline: .byte 13,10,0
.Lu_dash: .byte 226,148,128,0
.Lu_tl: .byte 226,148,140,0
.Lu_tr: .byte 226,148,144,0
.Lu_bl: .byte 226,148,148,0
.Lu_br: .byte 226,148,152,0
.Lu_side: .byte 226,148,130,0
.Lu_title: .byte 62,95,32,81,119,101,110,32,67,111,100,101,0
.Lu_version: .byte 32,40,110,97,116,105,118,101,32,120,56,54,45,54,52,41,0
.Lu_sep: .byte 32,124,32,0
.Lu_hint: .byte 32,40,47,109,111,100,101,108,32,116,111,32,99,104,97,110,103,101,41,0
.Lu_tip: .byte 84,105,112,115,58,32,65,100,100,32,97,32,81,87,69,78,46,109,100,32,102,105,108,101,32,116,111,32,103,105,118,101,32,81,119,101,110,32,67,111,100,101,32,112,101,114,115,105,115,116,101,110,116,32,112,114,111,106,101,99,116,32,99,111,110,116,101,120,116,46,0
.Lu_footer: .byte 63,32,102,111,114,32,115,104,111,114,116,99,117,116,115,32,194,183,32,65,108,116,43,69,110,116,101,114,32,110,101,119,108,105,110,101,0
.Lu_busyfooter: .byte 69,115,99,47,67,116,114,108,43,67,32,105,110,116,101,114,114,117,112,116,32,194,183,32,69,110,116,101,114,32,113,117,101,117,101,115,32,97,32,109,101,115,115,97,103,101,0
.Lu_permission: .byte 226,143,184,32,65,115,107,32,112,101,114,109,105,115,115,105,111,110,115,0
.Lu_placeholder: .byte 32,32,84,121,112,101,32,121,111,117,114,32,109,101,115,115,97,103,101,32,111,114,32,64,112,97,116,104,47,116,111,47,102,105,108,101,0
.Lu_user: .byte 62,32,0
.Lu_assistant: .byte 226,151,134,239,184,142,32,0
.Lu_tool: .byte 226,151,143,32,0
.Lu_ok: .byte 226,156,147,32,0
.Lu_failed: .byte 226,156,151,32,0
.Lu_status: .byte 226,151,143,32,0
.Lu_thinking: .byte 84,104,105,110,107,105,110,103,226,128,166,0
.Lu_allow: .byte 49,46,32,89,101,115,44,32,97,108,108,111,119,32,111,110,99,101,0
.Lu_deny: .byte 50,46,32,68,101,110,121,0
.Lu_choosehint: .byte 85,115,101,32,226,134,145,47,226,134,147,32,97,110,100,32,69,110,116,101,114,32,116,111,32,115,101,108,101,99,116,32,194,183,32,121,32,97,108,108,111,119,32,194,183,32,110,47,69,115,99,32,100,101,110,121,0
.Lu_approvaltitle: .byte 80,101,114,109,105,115,115,105,111,110,32,114,101,113,117,105,114,101,100,0
.Lu_marker: .byte 226,128,186,32,0
.Lu_nomarker: .byte 32,32,0
.Lu_completed_preview_marker: .byte 32,0
.Lu_queued: .byte 77,101,115,115,97,103,101,32,113,117,101,117,101,100,0
.Lu_empty: .byte 0
.Lu_commands_default: .asciz "/help\n/auth\n/connect\n/login\n/settings\n/account\n/clear\n/retry\n/model\n/theme\n/approval-mode\n/new\n/session\n/resume\n/sessions\n/rename\n/delete\n/extensions\n/extensions manage\n/extensions list\n/reload-plugins\n/plugins\n/agents\n/agents manage\n/agents create\n/about\n/copy\n/quit\n"
.section .bss
.balign 16
.Lu_active: .skip 8
.Lu_columns: .skip 8
.Lu_rows: .skip 8
.Lu_winsize: .skip 8
.Lu_model: .skip 1024
.Lu_cwd: .skip 4096
.Lu_auth: .skip 256
.Lu_context: .skip INPUT_CONTEXT_BYTES
.Lu_input: .skip 65536
.Lu_snapshot: .skip 64
.Lu_queue: .skip 524288
.Lu_queue_len: .skip 8
.Lu_busy: .skip 8
.Lu_approval: .skip 8
.Lu_selection: .skip 8
.Lu_preview: .skip 4194304
.Lu_preview_len: .skip 8
.Lu_scroll: .skip 8
.Lu_records: .skip 16384
.Lu_count: .skip 8
.Lu_blocks: .skip 8388608
.Lu_clean: .skip 4194304
.Lu_formatted: .skip 4194304
.Lu_flow: .skip 8388608
.Lu_indices: .skip 1048576
.Lu_flowlen: .skip 8
.Lu_linecount: .skip 8
.Lu_linecol: .skip 8
.Lu_frame: .skip 2097152
.Lu_builder: .skip 24
.Lu_bytes: .skip 256
.Lu_pollfd: .skip 8
.Lu_lasttick: .skip 8
.Lu_time: .skip 16
.Lu_commands: .skip 8192
.Lu_menu: .skip 8
.Lu_menu_count: .skip 8
.Lu_menu_index: .skip 8
.Lu_matches: .skip 2048
.Lu_cursor_row: .skip 8
.Lu_cursor_col: .skip 8
.Lu_composer_rows: .skip 8
.Lu_header_width: .skip 8
.Lu_show_logo: .skip 8
.Lu_flowlimit: .skip 8
.Lu_status_text: .skip 4096
.Lu_status_len: .skip 8
.Lu_dirty: .skip 8
.Lu_poollen: .skip 8
.Lu_choose: .skip 8
.Lu_choose_title: .skip 8
.Lu_choose_items: .skip 8
.Lu_choose_count: .skip 8
.Lu_choose_selection: .skip 8
.Lu_mode: .skip 8
.set .Lu_start_len, 38
.set .Lu_restore_len, 50
.section .text
.globl ui_set_model,ui_set_auth,ui_set_approval_mode,ui_choose,ui_set_theme
.globl ui_start,ui_readline,ui_user,ui_begin_response,ui_delta,ui_end_response,ui_status,ui_tool_begin,ui_tool_end,ui_approve,ui_reset,ui_restore,ui_tick,ui_poll,ui_take_queued,ui_set_commands
# Bounded builder; renderer emits only trusted fixed escape sequences or formatter SGR.
.Lu_put:
 sub rsp,8
 mov rdx,rsi
 mov rsi,rdi
 lea rdi,[rip+.Lu_builder]
 call qx_cat
 test rax,rax
 jns .Lu_put_done
 lea rdx,[rip+.Lu_flow]
 cmp [rip+.Lu_builder],rdx
 jne .Lu_put_done
 mov qword ptr [rip+.Lu_flow_overflow],1
.Lu_put_done:
 add rsp,8
 ret
.Lu_z:
 push rbx
 mov rbx,rdi
 call qx_strlen
 mov rdi,rbx
 mov rsi,rax
 call .Lu_put
 pop rbx
 ret
.Lu_repeat:
 test rsi,rsi
 jg .Lu_repeat_valid
 xor eax,eax
 ret
.Lu_repeat_valid:
 push rbx
 push r12
 sub rsp,8
 mov rbx,rdi
 mov r12,rsi
.Lu_repeat_next:
 test r12,r12
 jz .Lu_repeat_done
 mov rdi,rbx
 call .Lu_z
 dec r12
 jmp .Lu_repeat_next
.Lu_repeat_done:
 add rsp,8
 pop r12
 pop rbx
 ret
.Lu_nl:
 lea rdi,[rip+.Lu_newline]
 jmp .Lu_z
.Lu_reset_color:
 lea rdi,[rip+.Lu_reset]
 jmp .Lu_z
.Lu_copyz_clean:
 push rbx
 push r12
 push r13
 mov rbx,rsi
 mov r12,rdx
 call qx_strlen
 mov rsi,rax
 mov rdx,rbx
 lea rcx,[r12-1]
 call ui_sanitize
 test rax,rax
 js .Lu_copyz_fail
 mov byte ptr [rbx+rax],0
 jmp .Lu_copyz_done
.Lu_copyz_fail:
 mov byte ptr [rbx],0
.Lu_copyz_done:
 pop r13
 pop r12
 pop rbx
 ret
# Clip a UTF8 string to rsi cells, pad to exactly that width, preserve graphemes.
.Lu_field:
 test rsi,rsi
 jg .Lu_field_valid
 xor eax,eax
 ret
.Lu_field_valid:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rbx,rdi
 mov r12,rsi
 call qx_strlen
 mov r13,rax
 xor r14d,r14d
 xor r15d,r15d
.Lu_field_loop:
 cmp r14,r13
 jae .Lu_field_pad
 mov rdi,rbx
 mov rsi,r13
 mov rdx,r14
 call ui_next_grapheme
 test rax,rax
 js .Lu_field_pad
 cmp rax,r14
 jbe .Lu_field_pad
 mov r10,rax
 sub rsp,16
 mov [rsp],r10
 lea rdi,[rbx+r14]
 mov rsi,rax
 sub rsi,r14
 call ui_text_width
 mov r10,[rsp]
 add rsp,16
 cmp byte ptr [rbx+r14],10
 je .Lu_field_control_width
 cmp byte ptr [rbx+r14],13
 jne .Lu_field_width_done
.Lu_field_control_width:
 mov eax,1
.Lu_field_width_done:
 add r15,rax
 cmp r15,r12
 ja .Lu_field_over
 mov rax,r10
 sub rax,r14
 lea rdi,[rbx+r14]
 mov rsi,rax
 push r10
 sub rsp,8
 cmp byte ptr [rdi],10
 je .Lu_field_emit_space
 cmp byte ptr [rdi],13
 je .Lu_field_emit_space
 cmp byte ptr [rdi],9
 jne .Lu_field_emit
 lea rdi,[rip+.Lu_cont]
 mov esi,4
 jmp .Lu_field_emit
.Lu_field_emit_space:
 lea rdi,[rip+.Lu_space]
 mov esi,1
.Lu_field_emit:
 call .Lu_put
 add rsp,8
 pop r14
 jmp .Lu_field_loop
.Lu_field_over:
 sub r15,rax
.Lu_field_pad:
 mov rsi,r12
 sub rsi,r15
 lea rdi,[rip+.Lu_space]
 call .Lu_repeat
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Make room in the8MB logical arena. Drop oldest entire entries, never cut UTF8.
.Lu_reserve:
 push rbx
 push r12
 push r13
 mov r12,rdi
 cmp r12,1048576
 ja .Lu_reserve_bad
.Lu_reserve_again:
 mov rax,[rip+.Lu_poollen]
 add rax,r12
 cmp rax,8388608
 ja .Lu_drop_oldest
 cmp qword ptr [rip+.Lu_count],512
 jae .Lu_drop_oldest
 xor eax,eax
 jmp .Lu_reserve_return
.Lu_drop_oldest:
 cmp qword ptr [rip+.Lu_count],1
 jbe .Lu_reserve_bad
 lea rbx,[rip+.Lu_records]
 mov r13,[rbx+16]
 lea rdi,[rip+.Lu_blocks]
 lea rsi,[rdi+r13]
 mov rcx,[rip+.Lu_poollen]
 sub rcx,r13
 rep movsb
 sub qword ptr [rip+.Lu_poollen],r13
 mov rdi,rbx
 lea rsi,[rbx+32]
 mov rcx,[rip+.Lu_count]
 dec rcx
 shl rcx,2
 rep movsq
 dec qword ptr [rip+.Lu_count]
 cmp qword ptr [rip+.Lu_tool_pending],0
 je .Lu_drop_tool_fixed
 sub qword ptr [rip+.Lu_tool_record],1
 jnc .Lu_drop_tool_fixed
 mov qword ptr [rip+.Lu_tool_pending],0
.Lu_drop_tool_fixed:
 mov rcx,[rip+.Lu_count]
.Lu_fix_offsets:
 sub qword ptr [rbx+8],r13
 add rbx,32
 loop .Lu_fix_offsets
 jmp .Lu_reserve_again
.Lu_reserve_bad:
 mov rax,-28
.Lu_reserve_return:
 pop r13
 pop r12
 pop rbx
 ret
# New record(type) ->record pointer; caller appends through append_last.
.Lu_new:
 push rbx
 mov rbx,rdi
 xor edi,edi
 call .Lu_reserve
 test rax,rax
 js .Lu_new_return
 mov rax,[rip+.Lu_count]
 shl rax,5
 lea rdx,[rip+.Lu_records]
 add rax,rdx
 mov [rax],rbx
 mov rdx,[rip+.Lu_poollen]
 mov [rax+8],rdx
 mov qword ptr [rax+16],0
 mov qword ptr [rax+24],0
 inc qword ptr [rip+.Lu_count]
 mov qword ptr [rip+.Lu_flow_dirty],1
.Lu_new_return:
 pop rbx
 ret
# Append bytes(ptr,len) into the most recent logical entry (max1MB).
.Lu_append_last:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 mov rax,[rip+.Lu_count]
 test rax,rax
 jz .Lu_append_bad
 dec rax
 shl rax,5
 lea rbx,[rip+.Lu_records]
 add rbx,rax
 mov rax,[rbx+16]
 add rax,r13
 cmp rax,1048576
 ja .Lu_append_bad
 mov rdi,r13
 call .Lu_reserve
 test rax,rax
 js .Lu_append_bad
 mov rax,[rip+.Lu_count]
 dec rax
 shl rax,5
 lea rbx,[rip+.Lu_records]
 add rbx,rax
 lea rdi,[rip+.Lu_blocks]
 add rdi,[rip+.Lu_poollen]
 mov rsi,r12
 mov rcx,r13
 rep movsb
 add [rip+.Lu_poollen],r13
 add [rbx+16],r13
 mov qword ptr [rip+.Lu_dirty],1
 mov qword ptr [rip+.Lu_flow_dirty],1
 xor eax,eax
 jmp .Lu_append_return
.Lu_append_bad:
 mov rax,-28
.Lu_append_return:
 pop r13
 pop r12
 pop rbx
 ret
# One complete sanitized logical entry(type,ptr,len).
.Lu_entry:
 push rbx
 push r12
 push r13
 mov rbx,rdi
 mov r12,rsi
 mov r13,rdx
 cmp r13,1048576
 ja .Lu_entry_invalid
 mov rdi,rbx
 call .Lu_new
 test rax,rax
 js .Lu_entry_return
 mov rdi,r12
 mov rsi,r13
 call .Lu_append_last
 jmp .Lu_entry_return
.Lu_entry_invalid:
 mov rax,-28
.Lu_entry_return:
 pop r13
 pop r12
 pop rbx
 ret
ui_set_model:
 push rbx
 lea rsi,[rip+.Lu_model]
 mov edx,1024
 call .Lu_copyz_clean
 mov qword ptr [rip+.Lu_flow_dirty],1
 mov qword ptr [rip+.Lu_dirty],1
 pop rbx
 ret
ui_set_auth:
 push rbx
 lea rsi,[rip+.Lu_auth]
 mov edx,256
 call .Lu_copyz_clean
 mov qword ptr [rip+.Lu_flow_dirty],1
 mov qword ptr [rip+.Lu_dirty],1
 pop rbx
 ret
ui_set_approval_mode:
 mov [rip+.Lu_mode],rdi
 mov qword ptr [rip+.Lu_dirty],1
 ret
ui_get_approval_mode:
 mov rax,[rip+.Lu_mode]
 ret
ui_get_theme:
 mov rax,[rip+.Lu_theme]
 ret
ui_set_theme:
 push rbx
 push r12
 push r13
 mov r13,rdi
 cmp rdi,16
 jb .Lu_theme_builtin
 cmp rdi,17
 jb .Lu_theme_invalid
 mov rax,[rip+.Lu_custom_palette]
 test rax,rax
 jz .Lu_theme_invalid
 xor esi,esi
 call rax
 test rax,rax
 jz .Lu_theme_invalid
 mov r12,rax
 mov rdi,r13
.Lu_theme_builtin:
 mov [rip+.Lu_theme],rdi
 mov rax,rdi
 cmp rax,15
 jne .Lu_theme_resolve_ready
 mov rax,[rip+.Lu_auto_resolved]
.Lu_theme_resolve_ready:
 cmp qword ptr [rip+.Lu_no_color],0
 je .Lu_theme_color_enabled
 mov eax,16
.Lu_theme_color_enabled:
 mov [rip+.Lu_theme_resolved],rax
 cmp rax,17
 jae .Lu_theme_palette_ready
 lea rdx,[rip+.Lu_all_theme_palettes]
 mov r12,[rdx+rax*8]
.Lu_theme_palette_ready:
 xor ebx,ebx
.Lu_theme_copy:
 mov rdi,[r12+rbx*8]
 call qx_strlen
 mov rsi,[r12+rbx*8]
 lea rdx,[rip+.Lu_color_slots]
 mov rdi,[rdx+rbx*8]
 mov rcx,rax
 inc rcx
 rep movsb
 inc rbx
 cmp rbx,7
 jb .Lu_theme_copy
 mov qword ptr [rip+.Lu_dirty],1
 mov qword ptr [rip+.Lu_flow_dirty],1
 call .Lu_render
 xor eax,eax
 jmp .Lu_theme_return
.Lu_theme_invalid:
 mov rax,-22
.Lu_theme_return:
 pop r13
 pop r12
 pop rbx
 ret
ui_set_commands:
 push rbx
 mov rdx,rdi
 mov rax,rsi
 cmp rax,8191
 ja .Lu_commands_bad
 lea rdi,[rip+.Lu_commands]
 mov rsi,rdx
 mov rcx,rax
 rep movsb
 mov byte ptr [rdi],0
 xor eax,eax
 pop rbx
 ret
.Lu_commands_bad:
 mov rax,-28
 pop rbx
 ret
ui_user:
 push rbx
 mov rdx,rsi
 mov rsi,rdi
 mov edi,1
 call .Lu_entry
 call .Lu_render
 pop rbx
 ret
ui_begin_response:
 push rbx
 mov qword ptr [rip+.Lu_busy],1
 mov qword ptr [rip+.Lu_scroll],0
 mov edi,2
 call .Lu_new
 lea rdi,[rip+.Lu_thinking]
 call ui_status
 pop rbx
 ret
ui_delta:
 push rbx
 cmp qword ptr [rip+.Lu_count],0
 je .Lu_delta_new
 mov rax,[rip+.Lu_count]
 dec rax
 shl rax,5
 lea rdx,[rip+.Lu_records]
 cmp qword ptr [rdx+rax],2
 je .Lu_delta_append
.Lu_delta_new:
 push rdi
 push rsi
 mov edi,2
 call .Lu_new
 pop rsi
 pop rdi
.Lu_delta_append:
 call .Lu_append_last
 call ui_tick
 pop rbx
 ret
ui_end_response:
 push rbx
 mov qword ptr [rip+.Lu_busy],0
 mov qword ptr [rip+.Lu_status_len],0
 call .Lu_render
 pop rbx
 ret
ui_status:
 push rbx
 mov rbx,rdi
 call qx_strlen
 mov rdi,rbx
 mov rsi,rax
 lea rdx,[rip+.Lu_status_text]
 mov ecx,4095
 call ui_sanitize
 test rax,rax
 js .Lu_status_done
 mov [rip+.Lu_status_len],rax
 lea rdx,[rip+.Lu_status_text]
 mov byte ptr [rdx+rax],0
 cmp qword ptr [rip+.Lu_busy],0
 jne .Lu_status_render
 mov rdx,rax
 lea rsi,[rip+.Lu_status_text]
 mov edi,3
 call .Lu_entry
.Lu_status_render:
 call .Lu_render
.Lu_status_done:
 pop rbx
 ret
ui_tool_begin:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 mov rbx,rdi
 mov qword ptr [rip+.Lu_tool_pending],0
 mov qword ptr [rip+.Lu_tool_completion_len],0
 lea rsi,[rip+.Lu_tool_name]
 mov edx,512
 call .Lu_copyz_clean
 cmp r13,65535
 ja .Lu_tool_begin_fallback
 lea rdi,[rip+.Lu_tool_args]
 mov rsi,r12
 mov rcx,r13
 rep movsb
 mov byte ptr [rdi],0
 mov [rip+.Lu_tool_args_len],r13
 lea rdi,[rip+.Lu_tool_name]
 lea rsi,[rip+.Lu_tool_args]
 mov rdx,r13
 lea rcx,[rip+.Lu_tool_preview_body]
 mov r8d,1048576
 call ui_tool_preview
 test rax,rax
 js .Lu_tool_cache_done
 cmp rax,20
 jb .Lu_tool_cache_done
 mov rcx,rax
 sub rcx,20
 lea rdi,[rip+.Lu_tool_preview_body]
 add rdi,rcx
 lea rsi,[rip+.Lu_completion_question]
 mov ecx,20
 repe cmpsb
 jne .Lu_tool_cache_done
 sub rax,20
 mov [rip+.Lu_tool_completion_len],rax
.Lu_tool_cache_done:
 lea rdi,[rip+.Lu_tool_name]
 lea rsi,[rip+.Lu_tool_args]
 mov rdx,r13
 lea rcx,[rip+.Lu_tool_description]
 mov r8d,131071
 call ui_tool_describe
 test rax,rax
 js .Lu_tool_begin_fallback
 mov [rip+.Lu_tool_description_len],rax
 mov rdx,rax
 lea rsi,[rip+.Lu_tool_description]
 mov edi,4
 call .Lu_entry
 jmp .Lu_tool_begin_registered
.Lu_tool_begin_fallback:
 mov qword ptr [rip+.Lu_tool_description_len],0
 mov rdi,rbx
 call qx_strlen
 mov rdi,rbx
 mov rsi,rax
 lea rdx,[rip+.Lu_clean]
 mov ecx,1048576
 call ui_sanitize
 test rax,rax
 js .Lu_tool_begin_return
 mov rbx,rax
 lea rdx,[rip+.Lu_clean]
 mov byte ptr [rdx+rbx],10
 inc rbx
 mov rdi,r12
 mov rsi,r13
 add rdx,rbx
 mov ecx,1048576
 sub rcx,rbx
 call ui_sanitize
 test rax,rax
 js .Lu_tool_begin_return
 add rbx,rax
 mov edi,4
 call .Lu_new
 lea rdi,[rip+.Lu_clean]
 mov rsi,rbx
 call .Lu_append_last
.Lu_tool_begin_registered:
 test rax,rax
 js .Lu_tool_begin_return
 mov rax,[rip+.Lu_count]
 dec rax
 mov [rip+.Lu_tool_record],rax
 mov qword ptr [rip+.Lu_tool_pending],1
 call .Lu_render
.Lu_tool_begin_return:
 pop r13
 pop r12
 pop rbx
 ret
ui_tool_end:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 mov rbx,rdx
 cmp qword ptr [rip+.Lu_tool_pending],0
 je .Lu_tool_end_standalone
 mov qword ptr [rip+.Lu_tool_pending],0
 mov rax,[rip+.Lu_tool_record]
 cmp rax,[rip+.Lu_count]
 jae .Lu_tool_end_standalone
 shl rax,5
 lea rdx,[rip+.Lu_records]
 add rdx,rax
 mov rax,rbx
 inc rax
 mov [rdx+24],rax
 # Preserve allocated span: remove pending arrow visually without shrinking record.
 mov rcx,[rdx+16]
 cmp rcx,4
 jb .Lu_tool_arrow_removed
 lea rax,[rip+.Lu_blocks]
 add rax,[rdx+8]
 lea rax,[rax+rcx-4]
 cmp dword ptr [rax],0x9086e220
 jne .Lu_tool_arrow_removed
 mov dword ptr [rax],0x20202020
.Lu_tool_arrow_removed:
 test rbx,rbx
 jnz .Lu_tool_end_group
 mov rax,[rip+.Lu_tool_completion_len]
 test rax,rax
 jz .Lu_tool_end_group
 lea r12,[rip+.Lu_tool_preview_body]
 mov r13,rax
 cmp byte ptr [r12],10
 jne .Lu_tool_end_cached
 inc r12
 dec r13
.Lu_tool_end_cached:
 mov edi,8
 jmp .Lu_tool_end_append
.Lu_tool_end_group:
 mov edi,7
 jmp .Lu_tool_end_append
.Lu_tool_end_standalone:
 mov edi,5
.Lu_tool_end_append:
 mov rsi,r12
 mov rdx,r13
 call .Lu_entry
 test rax,rax
 js .Lu_tool_end_render
 mov rcx,[rip+.Lu_count]
 dec rcx
 shl rcx,5
 lea rdx,[rip+.Lu_records]
 mov [rdx+rcx+24],rbx
.Lu_tool_end_render:
 call .Lu_render
 pop r13
 pop r12
 pop rbx
 ret
ui_reset:
 push rbx
 mov qword ptr [rip+.Lu_flow_dirty],1
 mov qword ptr [rip+.Lu_count],0
 mov qword ptr [rip+.Lu_tool_pending],0
 mov qword ptr [rip+.Lu_poollen],0
 mov qword ptr [rip+.Lu_scroll],0
 mov qword ptr [rip+.Lu_status_len],0
 mov qword ptr [rip+.Lu_busy],0
 call .Lu_render
 pop rbx
 ret
ui_restore:
 push rbx
 cmp qword ptr [rip+.Lu_active],0
 je .Lu_restore_done
 mov edi,1
 lea rsi,[rip+.Lu_restore]
 mov edx,OFFSET FLAT:.Lu_restore_len
 call qx_write_all
 mov qword ptr [rip+.Lu_active],0
 call term_restore
.Lu_restore_done:
 pop rbx
 ret
# Refresh dimensions before frames; no signal handler races or shared SIGWINCH state.
.Lu_resize:
 sub rsp,8
 mov eax,16
 mov edi,1
 mov esi,0x5413
 lea rdx,[rip+.Lu_winsize]
 syscall
 test rax,rax
 js .Lu_resize_default
 movzx ecx,word ptr [rip+.Lu_winsize+2]
 movzx edx,word ptr [rip+.Lu_winsize]
 cmp ecx,12
 jb .Lu_resize_default
 cmp edx,8
 jb .Lu_resize_default
 cmp ecx,400
 jbe .Lu_resize_cols
 mov ecx,400
.Lu_resize_cols:
 cmp edx,200
 jbe .Lu_resize_values
 mov edx,200
.Lu_resize_values:
 cmp [rip+.Lu_columns],rcx
 jne .Lu_resize_changed
 cmp [rip+.Lu_rows],rdx
 je .Lu_resize_return
.Lu_resize_changed:
 mov qword ptr [rip+.Lu_dirty],1
 mov qword ptr [rip+.Lu_flow_dirty],1
 mov [rip+.Lu_columns],rcx
 mov [rip+.Lu_rows],rdx
 lea rdi,[rip+.Lu_context]
 lea rsi,[rcx-2]
 mov edx,6
 call input_resize
 jmp .Lu_resize_return
.Lu_resize_default:
 cmp qword ptr [rip+.Lu_columns],0
 jne .Lu_resize_return
 mov qword ptr [rip+.Lu_columns],80
 mov qword ptr [rip+.Lu_rows],24
 lea rdi,[rip+.Lu_context]
 mov esi,78
 mov edx,6
 call input_resize
.Lu_resize_return:
 add rsp,8
 ret
ui_start:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 call ui_set_model
 mov rdi,r12
 lea rsi,[rip+.Lu_cwd]
 mov edx,4096
 call .Lu_copyz_clean
 mov rdi,r13
 call ui_set_auth
 call term_init
 test rax,rax
 jne .Lu_start_return
 mov edi,15
 call ui_set_theme
 mov qword ptr [rip+.Lu_active],1
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_input]
 mov edx,65536
 call input_init
 lea rdi,[rip+.Lu_commands_default]
 call qx_strlen
 lea rdi,[rip+.Lu_commands_default]
 mov rsi,rax
 call ui_set_commands
 call .Lu_resize
 mov edi,1
 lea rsi,[rip+.Lu_start]
 mov edx,OFFSET FLAT:.Lu_start_len
 call qx_write_all
 call .Lu_render
 xor eax,eax
.Lu_start_return:
 pop r13
 pop r12
 pop rbx
 ret
# A flow line stores independent offsets; viewport scroll never cuts raw UTF8.
.Lu_flow_newline:
 push rbx
 call .Lu_nl
 mov rax,[rip+.Lu_builder+16]
 mov rcx,[rip+.Lu_linecount]
 cmp rcx,65530
 jae .Lu_flow_line_done
 lea rdx,[rip+.Lu_indices]
 mov [rdx+rcx*8],rax
 inc qword ptr [rip+.Lu_linecount]
 lea rdi,[rip+.Lu_reset]
 call .Lu_z
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_cont]
 cmp qword ptr [rip+.Lu_flow_indent],2
 jne .Lu_flow_newline_prefix
 lea rdi,[rip+.Lu_margin]
.Lu_flow_newline_prefix:
 call .Lu_z
 mov rax,[rip+.Lu_flow_indent]
 mov [rip+.Lu_linecol],rax
.Lu_flow_line_done:
 pop rbx
 ret
# Wrap styled body(ptr,len,prefixz,colorz) using Unicode grapheme display cells.
.Lu_flow_text:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rbx,rdi
 mov r12,rsi
 mov r13,rdx
 mov r14,rcx
 mov qword ptr [rip+.Lu_flow_indent],4
 lea rax,[rip+.Lu_completed_preview_marker]
 cmp rdx,rax
 jne .Lu_flow_regular_marker
 mov qword ptr [rip+.Lu_flow_indent],3
.Lu_flow_regular_marker:
 cmp byte ptr [rdx],0
 jne .Lu_flow_indent_ready
 mov qword ptr [rip+.Lu_flow_indent],2
.Lu_flow_indent_ready:
 cmp qword ptr [rip+.Lu_builder+16],0
 je .Lu_flow_first
 call .Lu_nl
 cmp qword ptr [rip+.Lu_flow_compact],0
 jne .Lu_flow_first
 call .Lu_nl
.Lu_flow_first:
 mov rax,[rip+.Lu_builder+16]
 mov rcx,[rip+.Lu_linecount]
 lea rdx,[rip+.Lu_indices]
 mov [rdx+rcx*8],rax
 inc qword ptr [rip+.Lu_linecount]
 lea rdi,[rip+.Lu_reset]
 call .Lu_z
 mov rdi,r14
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 mov rdi,r13
 call .Lu_z
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 mov rax,[rip+.Lu_flow_indent]
 mov [rip+.Lu_linecol],rax
 xor r15d,r15d
.Lu_flow_char:
 cmp r15,r12
 jae .Lu_flow_done
 cmp qword ptr [rip+.Lu_linecount],65530
 jae .Lu_flow_display_limit
 movzx eax,byte ptr [rbx+r15]
 cmp eax,27
 je .Lu_flow_sgr
 cmp eax,10
 je .Lu_flow_lf
 cmp eax,13
 je .Lu_flow_skip
 mov rdi,rbx
 mov rsi,r12
 mov rdx,r15
 call ui_next_grapheme
 cmp rax,r15
 jbe .Lu_flow_skip
 sub rsp,16
 mov [rsp],rax
 lea rdi,[rbx+r15]
 mov rsi,rax
 sub rsi,r15
 call ui_text_width
 mov [rsp+8],rax
 add rax,[rip+.Lu_linecol]
 cmp rax,[rip+.Lu_columns]
 jbe .Lu_flow_fit
 call .Lu_flow_newline
.Lu_flow_fit:
 mov rax,[rsp+8]
 add [rip+.Lu_linecol],rax
 lea rdi,[rbx+r15]
 mov rsi,[rsp]
 sub rsi,r15
 call .Lu_put
 mov r15,[rsp]
 add rsp,16
 jmp .Lu_flow_char
.Lu_flow_sgr:
 mov r13,r15
.Lu_flow_sgr_next:
 inc r15
 cmp r15,r12
 jae .Lu_flow_done
 cmp byte ptr [rbx+r15],109
 jne .Lu_flow_sgr_next
 inc r15
 lea rdi,[rbx+r13]
 mov rsi,r15
 sub rsi,r13
 call .Lu_put
 jmp .Lu_flow_char
.Lu_flow_lf:
 call .Lu_flow_newline
.Lu_flow_skip:
 inc r15
 jmp .Lu_flow_char
.Lu_flow_display_limit:
 mov qword ptr [rip+.Lu_flow_overflow],1
.Lu_flow_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Lu_build_flow:
 push rbx
 push r12
 push r13
 push r14
 push r15
 lea rax,[rip+.Lu_flow]
 mov [rip+.Lu_builder],rax
 mov qword ptr [rip+.Lu_builder+8],8388480
 mov qword ptr [rip+.Lu_builder+16],0
 mov qword ptr [rip+.Lu_linecount],0
 mov qword ptr [rip+.Lu_flow_overflow],0
 mov qword ptr [rip+.Lu_math_offset],0
 mov qword ptr [rip+.Lu_mermaid_offset],0
.Lu_build_normal:
 call .Lu_header
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 lea rdi,[rip+.Lu_tip]
 mov rsi,[rip+.Lu_columns]
 sub rsi,4
 call .Lu_field
 xor ebx,ebx
.Lu_build_entry:
 cmp rbx,[rip+.Lu_count]
 jae .Lu_build_flow_done
 mov rax,rbx
 shl rax,5
 lea r12,[rip+.Lu_records]
 add r12,rax
 cmp qword ptr [rip+.Lu_approval],0
 je .Lu_build_record_visible
 cmp qword ptr [rip+.Lu_tool_pending],0
 je .Lu_build_record_visible
 cmp qword ptr [r12],4
 jne .Lu_build_record_visible
 mov rax,[rip+.Lu_count]
 dec rax
 cmp rbx,rax
 je .Lu_build_skip
.Lu_build_record_visible:
 cmp qword ptr [r12+16],0
 je .Lu_build_skip
 lea rdi,[rip+.Lu_blocks]
 add rdi,[r12+8]
 mov rsi,[r12+16]
 lea rdx,[rip+.Lu_clean]
 mov ecx,4194304
 call ui_sanitize
 test rax,rax
 js .Lu_build_skip
 mov r14,rax
 lea r13,[rip+.Lu_clean]
 cmp qword ptr [r12],8
 je .Lu_build_numbered_preview
 cmp qword ptr [r12],2
 jne .Lu_build_prefix
 mov rdi,r13
 mov rsi,r14
 lea rdx,[rip+.Lu_formatted]
 mov ecx,4194304
 mov r8,[rip+.Lu_columns]
 sub r8,4
 mov r9,[rip+.Lu_theme_resolved]
 sub rsp,16
 mov rax,[rip+.Lu_math_offset]
 mov [rsp],rax
 mov rax,[rip+.Lu_mermaid_offset]
 mov [rsp+8],rax
 call ui_format_markdown_full
 add rsp,16
 test rax,rax
 js .Lu_build_prefix
 mov r14,rax
 lea r13,[rip+.Lu_formatted]
 jmp .Lu_build_prefix
.Lu_build_numbered_preview:
 mov rdi,r13
 mov rsi,r14
 lea rdx,[rip+.Lu_formatted]
 mov ecx,4194304
 mov r8,[rip+.Lu_columns]
 sub r8,4
 mov r9,[rip+.Lu_theme_resolved]
 sub rsp,16
 mov qword ptr [rsp],0
 call ui_format_numbered_preview
 add rsp,16
 test rax,rax
 js .Lu_build_prefix
 mov r14,rax
 lea r13,[rip+.Lu_formatted]
.Lu_build_prefix:
 lea rdx,[rip+.Lu_status]
 lea rcx,[rip+.Lu_muted]
 cmp qword ptr [r12],1
 jne .Lu_build_notuser
 lea rdx,[rip+.Lu_user]
 lea rcx,[rip+.Lu_accent]
.Lu_build_notuser:
 cmp qword ptr [r12],2
 jne .Lu_build_notassistant
 lea rdx,[rip+.Lu_assistant]
 lea rcx,[rip+.Lu_accent]
.Lu_build_notassistant:
 cmp qword ptr [r12],6
 jne .Lu_build_not_shell_user
 lea rdx,[rip+.Lu_shell_prefix]
 lea rcx,[rip+.Lu_accent]
.Lu_build_not_shell_user:
 cmp qword ptr [r12],4
 jne .Lu_build_nottool
 lea rdx,[rip+.Lu_tool]
 lea rcx,[rip+.Lu_warning]
 cmp qword ptr [r12+24],0
 je .Lu_build_nottool
 lea rdx,[rip+.Lu_ok]
 lea rcx,[rip+.Lu_success]
 cmp qword ptr [r12+24],1
 je .Lu_build_nottool
 lea rdx,[rip+.Lu_failed]
 lea rcx,[rip+.Lu_error]
.Lu_build_nottool:
 cmp qword ptr [r12],5
 jne .Lu_build_output
 lea rdx,[rip+.Lu_ok]
 lea rcx,[rip+.Lu_success]
 cmp qword ptr [r12+24],0
 je .Lu_build_output
 lea rdx,[rip+.Lu_failed]
 lea rcx,[rip+.Lu_error]
.Lu_build_output:
 cmp qword ptr [r12],7
 jne .Lu_build_body_prefix_done
 lea rdx,[rip+.Lu_nomarker]
 lea rcx,[rip+.Lu_primary]
.Lu_build_body_prefix_done:
 cmp qword ptr [r12],8
 jne .Lu_build_preview_prefix_done
 lea rdx,[rip+.Lu_completed_preview_marker]
 lea rcx,[rip+.Lu_primary]
.Lu_build_preview_prefix_done:
 xor r15d,r15d
 cmp qword ptr [r12],8
 je .Lu_build_fold_check
 cmp qword ptr [r12],7
 je .Lu_build_fold_check
 cmp qword ptr [r12],5
 jne .Lu_build_unfolded
.Lu_build_fold_check:
 cmp qword ptr [r12+24],0
 jne .Lu_build_unfolded
 cmp qword ptr [rip+.Lu_details],0
 jne .Lu_build_unfolded
 xor eax,eax
 xor r8d,r8d
.Lu_build_count_lines:
 cmp rax,r14
 jae .Lu_build_unfolded
 cmp byte ptr [r13+rax],10
 jne .Lu_build_count_next
 inc r8
 cmp r8,3
 jb .Lu_build_count_next
 mov r14,rax
 mov r15d,1
 jmp .Lu_build_unfolded
.Lu_build_count_next:
 inc rax
 jmp .Lu_build_count_lines
.Lu_build_unfolded:
 mov qword ptr [rip+.Lu_flow_compact],0
 cmp qword ptr [r12],8
 je .Lu_build_group_compact
 cmp qword ptr [r12],7
 je .Lu_build_group_compact
 cmp qword ptr [r12],4
 jne .Lu_build_group_ready
.Lu_build_group_compact:
 mov qword ptr [rip+.Lu_flow_compact],1
.Lu_build_group_ready:
 mov rdi,r13
 mov rsi,r14
 call .Lu_flow_text
 mov qword ptr [rip+.Lu_flow_compact],0
 test r15,r15
 jz .Lu_build_skip
 lea rdi,[rip+.Lu_more_output]
 mov esi,OFFSET FLAT:.Lu_more_output_len
 lea rdx,[rip+.Lu_nomarker]
 lea rcx,[rip+.Lu_muted]
 call .Lu_flow_text
.Lu_build_skip:
 cmp qword ptr [r12],2
 jne .Lu_build_math_counted
 lea rdi,[rip+.Lu_blocks]
 add rdi,[r12+8]
 mov rsi,[r12+16]
 call ui_math_count
 test rax,rax
 js .Lu_build_math_counted
 add [rip+.Lu_math_offset],rax
 lea rdi,[rip+.Lu_blocks]
 add rdi,[r12+8]
 mov rsi,[r12+16]
 call ui_mermaid_count
 test rax,rax
 js .Lu_build_math_counted
 add [rip+.Lu_mermaid_offset],rax
.Lu_build_math_counted:
 inc rbx
 jmp .Lu_build_entry
.Lu_build_flow_done:
 cmp qword ptr [rip+.Lu_approval],0
 je .Lu_build_no_approval
 mov qword ptr [rip+.Lu_flow_compact],1
 call .Lu_style_approval
 lea rdi,[rip+.Lu_preview]
 mov rsi,[rip+.Lu_preview_len]
 test rax,rax
 js .Lu_build_approval_unstyled
 lea rdi,[rip+.Lu_formatted]
 mov rsi,rax
.Lu_build_approval_unstyled:
 lea rdx,[rip+.Lu_empty]
 lea rcx,[rip+.Lu_warning]
 call .Lu_flow_text
 mov qword ptr [rip+.Lu_flow_compact],0
 call .Lu_flow_approval_choices
.Lu_build_no_approval:
 cmp qword ptr [rip+.Lu_flow_overflow],0
 je .Lu_build_flow_finished
 mov qword ptr [rip+.Lu_builder+8],8388608
 call .Lu_nl
 mov rax,[rip+.Lu_builder+16]
 mov rcx,[rip+.Lu_linecount]
 lea rdx,[rip+.Lu_indices]
 mov [rdx+rcx*8],rax
 inc qword ptr [rip+.Lu_linecount]
 lea rdi,[rip+.Lu_warning]
 call .Lu_z
 lea rdi,[rip+.Lu_display_limit]
 call .Lu_z
.Lu_build_flow_finished:
 mov qword ptr [rip+.Lu_linecount],0
 mov rcx,[rip+.Lu_builder+16]
 test rcx,rcx
 jz .Lu_build_index_done
 lea rdx,[rip+.Lu_indices]
 mov qword ptr [rdx],0
 mov qword ptr [rip+.Lu_linecount],1
 lea rsi,[rip+.Lu_flow]
 xor eax,eax
.Lu_build_index_loop:
 cmp rax,rcx
 jae .Lu_build_index_done
 cmp byte ptr [rsi+rax],10
 jne .Lu_build_index_next
 mov r8,[rip+.Lu_linecount]
 cmp r8,65534
 jae .Lu_build_index_done
 lea r9,[rax+1]
 mov [rdx+r8*8],r9
 inc qword ptr [rip+.Lu_linecount]
.Lu_build_index_next:
 inc rax
 jmp .Lu_build_index_loop
.Lu_build_index_done:
 mov rax,[rip+.Lu_builder+16]
 mov [rip+.Lu_flowlen],rax
 mov rcx,[rip+.Lu_linecount]
 lea rdx,[rip+.Lu_indices]
 mov [rdx+rcx*8],rax
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Header matches source Header.tsx geometry, including narrow-width logo suppression.
.Lu_header:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,[rip+.Lu_columns]
 sub r12,4
 mov qword ptr [rip+.Lu_show_logo],0
 cmp r12,U_LOGO_WIDTH+2+44
 jb .Lu_header_width_ready
 mov qword ptr [rip+.Lu_show_logo],1
 sub r12,U_LOGO_WIDTH+2
 cmp r12,60
 jbe .Lu_header_width_ready
 mov r12,60
.Lu_header_width_ready:
 mov [rip+.Lu_header_width],r12
 xor ebx,ebx
 cmp qword ptr [rip+.Lu_show_logo],0
 je .Lu_header_row
 call .Lu_nl
.Lu_header_row:
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 cmp qword ptr [rip+.Lu_show_logo],0
 je .Lu_header_panel
 lea rax,[rip+.Lu_logos]
 mov r13,[rax+rbx*8]
 mov rdi,r13
 call qx_strlen
 mov r14,rax
 xor r15d,r15d
 xor r10d,r10d
 # Every QWEN logo codepoint is one cell; capture-derived37-column gradient.
.Lu_logo_char:
 cmp r15,r14
 jae .Lu_logo_end
 push r10
 sub rsp,8
 lea rdi,[rip+.Lu_reset]
 cmp qword ptr [rip+.Lu_no_color],0
 jne .Lu_logo_gradient_ready
 lea rax,[rip+.Lu_theme_gradient_themes]
 mov rdx,[rip+.Lu_theme_resolved]
 cmp rdx,17
 jb .Lu_logo_builtin_gradient
 mov rax,[rip+.Lu_custom_gradient]
 test rax,rax
 jz .Lu_logo_custom_accent
 mov rdi,rdx
 mov esi,37
 test rbx,rbx
 jnz .Lu_logo_custom_width
 mov esi,36
.Lu_logo_custom_width:
 call rax
 test rax,rax
 jz .Lu_logo_custom_accent
 mov rdx,[rsp+8]
 mov rdi,[rax+rdx*8]
 jmp .Lu_logo_gradient_ready
.Lu_logo_custom_accent:
 lea rdi,[rip+.Lu_accent]
 jmp .Lu_logo_gradient_ready
.Lu_logo_builtin_gradient:
 mov rax,[rax+rdx*8]
 test rbx,rbx
 jz .Lu_logo_gradient_first_row
 add rax,8
.Lu_logo_gradient_first_row:
 mov rax,[rax]
 mov rdi,[rax+r10*8]
.Lu_logo_gradient_ready:
 call .Lu_z
 mov rdi,r13
 mov rsi,r14
 mov rdx,r15
 call ui_next_grapheme
 mov rsi,rax
 sub rsi,r15
 lea rdi,[r13+r15]
 push rax
 sub rsp,8
 call .Lu_put
 add rsp,8
 pop r15
 add rsp,8
 pop r10
 inc r10
 jmp .Lu_logo_char
.Lu_logo_end:
 lea rdi,[rip+.Lu_reset]
 call .Lu_z
 mov rsi,U_LOGO_WIDTH
 sub rsi,r10
 lea rdi,[rip+.Lu_space]
 call .Lu_repeat
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
.Lu_header_panel:
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 test rbx,rbx
 jz .Lu_header_top
 cmp rbx,5
 je .Lu_header_bottom
 lea rdi,[rip+.Lu_side]
 call .Lu_z
 lea rdi,[rip+.Lu_space]
 call .Lu_z
 cmp rbx,1
 je .Lu_header_title
 cmp rbx,3
 je .Lu_header_model
 cmp rbx,4
 je .Lu_header_cwd
 lea rdi,[rip+.Lu_empty]
 jmp .Lu_header_field
.Lu_header_title:
 lea rdi,[rip+.Lu_accent]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 lea rdi,[rip+.Lu_title]
 mov rsi,r12
 sub rsi,4
 # Title width11; version suffix is shown when the panel allows it.
 cmp rsi,28
 jb .Lu_header_title_short
 lea rdi,[rip+.Lu_title]
 call .Lu_z
 lea rdi,[rip+.Lu_reset]
 call .Lu_z
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_version]
 call .Lu_z
 mov rsi,r12
 sub rsi,4+12+16
 lea rdi,[rip+.Lu_space]
 call .Lu_repeat
 jmp .Lu_header_right
.Lu_header_title_short:
 jmp .Lu_header_field
.Lu_header_model:
 # Assemble auth/model in scratch through an independent temporary builder.
 sub rsp,32
 movdqu xmm0,xmmword ptr [rip+.Lu_builder]
 movdqu [rsp],xmm0
 mov rax,[rip+.Lu_builder+16]
 mov [rsp+16],rax
 lea rax,[rip+.Lu_clean]
 mov [rip+.Lu_builder],rax
 mov qword ptr [rip+.Lu_builder+8],1048575
 mov qword ptr [rip+.Lu_builder+16],0
 lea rdi,[rip+.Lu_auth]
 call .Lu_z
 lea rdi,[rip+.Lu_sep]
 call .Lu_z
 lea rdi,[rip+.Lu_model]
 call .Lu_z
 mov rax,[rip+.Lu_builder+16]
 lea rdx,[rip+.Lu_clean]
 mov byte ptr [rdx+rax],0
 lea rdi,[rip+.Lu_clean]
 mov rsi,rax
 call ui_text_width
 lea rcx,[r12-4]
 add rax,19
 cmp rax,rcx
 ja .Lu_header_model_restore
 lea rdi,[rip+.Lu_hint]
 call .Lu_z
.Lu_header_model_restore:
 mov rax,[rip+.Lu_builder+16]
 lea rdx,[rip+.Lu_clean]
 mov byte ptr [rdx+rax],0
 movdqu xmm0,[rsp]
 movdqu xmmword ptr [rip+.Lu_builder],xmm0
 mov rax,[rsp+16]
 mov [rip+.Lu_builder+16],rax
 add rsp,32
 lea rdi,[rip+.Lu_clean]
 jmp .Lu_header_field
.Lu_header_cwd:
 lea rdi,[rip+.Lu_cwd]
.Lu_header_field:
 mov rsi,r12
 sub rsi,4
 call .Lu_field
.Lu_header_right:
 lea rdi,[rip+.Lu_space]
 call .Lu_z
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_side]
 call .Lu_z
 jmp .Lu_header_row_end
.Lu_header_top:
 lea rdi,[rip+.Lu_tl]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 lea rsi,[r12-2]
 call .Lu_repeat
 lea rdi,[rip+.Lu_tr]
 call .Lu_z
 jmp .Lu_header_row_end
.Lu_header_bottom:
 lea rdi,[rip+.Lu_bl]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 lea rsi,[r12-2]
 call .Lu_repeat
 lea rdi,[rip+.Lu_br]
 call .Lu_z
.Lu_header_row_end:
 call .Lu_reset_color
 call .Lu_nl
 inc rbx
 cmp rbx,6
 jb .Lu_header_row
 cmp qword ptr [rip+.Lu_show_logo],0
 je .Lu_header_end
 call .Lu_nl
.Lu_header_end:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Trusted cursor addressing in framebuffer.
.Lu_move:
 push rbx
 push r12
 sub rsp,8
 mov rbx,rdi
 mov r12,rsi
 lea rdi,[rip+.Lu_csi]
 call .Lu_z
 lea rdi,[rip+.Lu_bytes]
 mov rsi,rbx
 call qx_uint
 lea rdi,[rip+.Lu_bytes]
 mov rsi,rax
 call .Lu_put
 lea rdi,[rip+.Lu_semicolon]
 call .Lu_z
 lea rdi,[rip+.Lu_bytes]
 mov rsi,r12
 call qx_uint
 lea rdi,[rip+.Lu_bytes]
 mov rsi,rax
 call .Lu_put
 lea rdi,[rip+.Lu_H]
 call .Lu_z
 add rsp,8
 pop r12
 pop rbx
 ret
# Measure editor visual rows and cursor in cell coordinates.
.Lu_measure_editor:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rbx,[rip+.Lu_snapshot+IS_TEXT]
 mov r12,[rip+.Lu_snapshot+IS_LENGTH]
 xor r13d,r13d
 xor r14d,r14d
 xor r15d,r15d
 mov qword ptr [rip+.Lu_cursor_row],0
 mov qword ptr [rip+.Lu_cursor_col],0
.Lu_measure_next:
 cmp r13,[rip+.Lu_snapshot+IS_CURSOR]
 jne .Lu_measure_notcursor
 mov [rip+.Lu_cursor_row],r14
 mov [rip+.Lu_cursor_col],r15
.Lu_measure_notcursor:
 cmp r13,r12
 jae .Lu_measure_done
 cmp byte ptr [rbx+r13],10
 je .Lu_measure_lf
 mov rdi,rbx
 mov rsi,r12
 mov rdx,r13
 call ui_next_grapheme
 cmp rax,r13
 jbe .Lu_measure_skip
 sub rsp,16
 mov [rsp],rax
 lea rdi,[rbx+r13]
 mov rsi,rax
 sub rsi,r13
 call ui_text_width
 lea rcx,[r15+rax]
 mov rdx,[rip+.Lu_columns]
 sub rdx,2
 cmp rcx,rdx
 jbe .Lu_measure_fit
 inc r14
 xor r15d,r15d
.Lu_measure_fit:
 add r15,rax
 mov r13,[rsp]
 add rsp,16
 jmp .Lu_measure_next
.Lu_measure_lf:
 inc r14
 xor r15d,r15d
.Lu_measure_skip:
 inc r13
 jmp .Lu_measure_next
.Lu_measure_done:
 inc r14
 cmp r14,6
 jbe .Lu_measure_rows
 mov r14,6
.Lu_measure_rows:
 mov [rip+.Lu_composer_rows],r14
 mov rax,[rip+.Lu_cursor_row]
 sub rax,5
 jns .Lu_measure_scroll
 xor eax,eax
.Lu_measure_scroll:
 mov [rip+.Lu_editor_scroll],rax
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Draw a six-row editor viewport around the active visual cursor.
.Lu_editor:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rbx,[rip+.Lu_snapshot+IS_TEXT]
 mov r12,[rip+.Lu_snapshot+IS_LENGTH]
 xor r13d,r13d
 xor r14d,r14d
 xor r15d,r15d
 call .Lu_mode_color
 call .Lu_z
 lea rdi,[rip+.Lu_user]
 cmp qword ptr [rip+.Lu_mode],3
 jne .Lu_editor_prefix_ready
 lea rdi,[rip+.Lu_yolo_prefix]
.Lu_editor_prefix_ready:
 cmp qword ptr [rip+.Lu_shell_mode],0
 je .Lu_editor_actual_prefix
 lea rdi,[rip+.Lu_shell_prefix]
.Lu_editor_actual_prefix:
 call .Lu_z
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 test r12,r12
 jnz .Lu_editor_next
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_placeholder]
 mov rsi,[rip+.Lu_columns]
 sub rsi,2
 call .Lu_field
 jmp .Lu_editor_done
.Lu_editor_next:
 cmp r13,r12
 jae .Lu_editor_done
 mov rax,[rip+.Lu_editor_scroll]
 add rax,[rip+.Lu_composer_rows]
 cmp r14,rax
 jae .Lu_editor_done
 cmp byte ptr [rbx+r13],10
 je .Lu_editor_lf
 mov rdi,rbx
 mov rsi,r12
 mov rdx,r13
 call ui_next_grapheme
 cmp rax,r13
 jbe .Lu_editor_skip
 sub rsp,16
 mov [rsp],rax
 lea rdi,[rbx+r13]
 mov rsi,rax
 sub rsi,r13
 call ui_text_width
 mov [rsp+8],rax
 add rax,r15
 mov rcx,[rip+.Lu_columns]
 sub rcx,2
 cmp rax,rcx
 jbe .Lu_editor_fit
 call .Lu_editor_advance_row
 mov r14,rax
 xor r15d,r15d
.Lu_editor_fit:
 mov rax,[rsp+8]
 add r15,rax
 cmp r14,[rip+.Lu_editor_scroll]
 jb .Lu_editor_advance
 mov rax,[rip+.Lu_editor_scroll]
 add rax,[rip+.Lu_composer_rows]
 cmp r14,rax
 jae .Lu_editor_advance
 mov rax,[rip+.Lu_snapshot+IS_SELECTION]
 cmp rax,-1
 je .Lu_editor_unselected
 mov rcx,[rip+.Lu_snapshot+IS_CURSOR]
 cmp rax,rcx
 jbe .Lu_editor_selection_bounds
 xchg rax,rcx
.Lu_editor_selection_bounds:
 cmp r13,rax
 jb .Lu_editor_unselected
 cmp r13,rcx
 jae .Lu_editor_unselected
 lea rdi,[rip+.Lu_inverse]
 call .Lu_z
.Lu_editor_unselected:
 cmp byte ptr [rbx+r13],9
 je .Lu_editor_tab
 lea rdi,[rbx+r13]
 mov rsi,[rsp]
 sub rsi,r13
 call .Lu_put
 jmp .Lu_editor_advance
.Lu_editor_tab:
 lea rdi,[rip+.Lu_space]
 mov esi,4
 call .Lu_repeat
.Lu_editor_advance:
 lea rdi,[rip+.Lu_noinverse]
 call .Lu_z
 mov r13,[rsp]
 add rsp,16
 jmp .Lu_editor_next
.Lu_editor_lf:
 call .Lu_editor_advance_row
 mov r14,rax
 xor r15d,r15d
.Lu_editor_skip:
 inc r13
 jmp .Lu_editor_next
.Lu_editor_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Lu_editor_advance_row:
 push r14
 push r15
 sub rsp,8
 inc r14
 xor r15d,r15d
 cmp r14,[rip+.Lu_editor_scroll]
 jbe .Lu_editor_advance_row_done
 mov rax,[rip+.Lu_editor_scroll]
 add rax,[rip+.Lu_composer_rows]
 cmp r14,rax
 jae .Lu_editor_advance_row_done
 call .Lu_nl
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
.Lu_editor_advance_row_done:
 mov rax,r14
 xor edx,edx
 add rsp,8
 pop r15
 pop r14
 ret
# Paint the exact source header, viewport, composer rules and footer geometry.
.Lu_render:
 push rbx
 push r12
 push r13
 push r14
 push r15
 cmp qword ptr [rip+.Lu_active],0
 je .Lu_render_done
 call .Lu_resize
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 call .Lu_measure_editor
 cmp qword ptr [rip+.Lu_flow_dirty],0
 je .Lu_render_flow_cached
 call .Lu_build_flow
 mov qword ptr [rip+.Lu_flow_dirty],0
.Lu_render_flow_cached:
 lea rax,[rip+.Lu_frame]
 mov [rip+.Lu_builder],rax
 mov qword ptr [rip+.Lu_builder+8],2097152
 mov qword ptr [rip+.Lu_builder+16],0
 lea rdi,[rip+.Lu_home]
 call .Lu_z
 lea rdi,[rip+.Lu_clear]
 call .Lu_z
 call .Lu_reset_color
 # Short conversations flow; only overflowing content fills the viewport.
 mov r12,[rip+.Lu_rows]
 sub r12,[rip+.Lu_composer_rows]
 sub r12,3
 mov rax,[rip+.Lu_menu_count]
 cmp rax,5
 jbe .Lu_render_menu_height
 mov eax,5
.Lu_render_menu_height:
 sub rax,2
 jle .Lu_render_menu_reserved
 sub r12,rax
.Lu_render_menu_reserved:
 mov r13,[rip+.Lu_linecount]
 add r13,2
 mov rax,[rip+.Lu_qcount]
 cmp rax,3
 jbe .Lu_render_queue_size
 mov eax,4
.Lu_render_queue_size:
 add r13,rax
 cmp qword ptr [rip+.Lu_busy],0
 je .Lu_render_wanted
 inc r13
.Lu_render_wanted:
 cmp qword ptr [rip+.Lu_choose],0
 jne .Lu_render_choose_geometry
 cmp qword ptr [rip+.Lu_approval],0
 jne .Lu_render_approval_geometry
 cmp r13,r12
 jae .Lu_render_top_set
 mov r12,r13
.Lu_render_top_set:
 mov [rip+.Lu_composer_top],r12
 mov r13,r12
 sub r13,2
 mov rax,[rip+.Lu_qcount]
 cmp rax,3
 jbe .Lu_render_queue_reserved
 mov eax,4
.Lu_render_queue_reserved:
 sub r13,rax
 cmp qword ptr [rip+.Lu_busy],0
 je .Lu_render_busy_reserved
 dec r13
.Lu_render_busy_reserved:
 cmp qword ptr [rip+.Lu_approval],0
 je .Lu_render_approval_reserved
 sub r13,4
.Lu_render_approval_reserved:
 cmp r13,1
 jge .Lu_render_height
 mov r13,1
 jmp .Lu_render_height
.Lu_render_choose_geometry:
 call .Lu_choose_box_geometry
 mov r13,[rip+.Lu_box_top]
 dec r13
 mov r12,[rip+.Lu_rows]
 mov [rip+.Lu_composer_top],r12
 jmp .Lu_render_height
.Lu_render_approval_geometry:
 mov r13,[rip+.Lu_rows]
 sub r13,2
 mov r12,[rip+.Lu_rows]
 mov [rip+.Lu_composer_top],r12
.Lu_render_height:
 mov r14,[rip+.Lu_linecount]
 mov rax,r14
 sub rax,r13
 jns .Lu_scroll_max
 xor eax,eax
.Lu_scroll_max:
 cmp [rip+.Lu_scroll],rax
 jbe .Lu_scroll_clamped
 mov [rip+.Lu_scroll],rax
.Lu_scroll_clamped:
 sub r14,[rip+.Lu_scroll]
 sub r14,r13
 jns .Lu_visible_start
 xor r14d,r14d
.Lu_visible_start:
 mov [rip+.Lu_view_start],r14
 mov [rip+.Lu_view_height],r13
 mov ebx,1
 xor r15d,r15d
.Lu_render_transcript:
 cmp r15,r13
 jae .Lu_render_status
 cmp r14,[rip+.Lu_linecount]
 jae .Lu_render_status
 mov rdi,rbx
 mov esi,1
 call .Lu_move
 lea rax,[rip+.Lu_indices]
 mov rdx,[rax+r14*8]
 mov rsi,[rax+r14*8+8]
 sub rsi,rdx
 lea rdi,[rip+.Lu_flow]
 add rdi,rdx
 # Stored row intervals may include CRLF before the next prefix; trim it.
 test rsi,rsi
 jz .Lu_transcript_put
 cmp byte ptr [rdi+rsi-1],10
 jne .Lu_transcript_put
 dec rsi
 test rsi,rsi
 jz .Lu_transcript_put
 cmp byte ptr [rdi+rsi-1],13
 jne .Lu_transcript_put
 dec rsi
.Lu_transcript_put:
 call .Lu_put
 inc r14
 inc r15
 inc rbx
 jmp .Lu_render_transcript
.Lu_render_status:
 call .Lu_scrollbar
 cmp qword ptr [rip+.Lu_choose],0
 jne .Lu_render_choose_only
 cmp qword ptr [rip+.Lu_approval],0
 jne .Lu_render_approval_only
 call .Lu_queue_view
 lea rdi,[r12-1]
 mov esi,1
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 test qword ptr [rip+.Lu_snapshot+IS_FLAGS],1
 jnz .Lu_render_search
 cmp qword ptr [rip+.Lu_busy],0
 je .Lu_render_idle_status
 # Eight-frame native braille spinner, ticktime in milliseconds.
 mov rax,[rip+.Lu_lasttick]
 xor edx,edx
 mov ecx,100
 div rcx
 and eax,7
 lea rdi,[rip+.Lu_spinners]
 lea rdi,[rdi+rax*4]
 mov esi,3
 call .Lu_put
 lea rdi,[rip+.Lu_space]
 call .Lu_z
 lea rdi,[rip+.Lu_status_text]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 jmp .Lu_render_composer
.Lu_render_search:
 lea rdi,[rip+.Lu_search_label]
 call .Lu_z
 mov rdi,[rip+.Lu_snapshot+IS_HINT]
 mov rsi,[rip+.Lu_snapshot+IS_HINT_LENGTH]
 lea rdx,[rip+.Lu_clean]
 mov ecx,4194303
 call ui_sanitize
 test rax,rax
 js .Lu_render_composer
 lea rdi,[rip+.Lu_clean]
 mov byte ptr [rdi+rax],0
 mov rsi,[rip+.Lu_columns]
 sub rsi,24
 call .Lu_field
 jmp .Lu_render_composer
.Lu_render_idle_status:
 cmp qword ptr [rip+.Lu_scroll],0
 je .Lu_render_composer
 lea rdi,[rip+.Lu_scrolling]
 call .Lu_z
 jmp .Lu_render_composer
.Lu_render_choose_only:
 call .Lu_choose_view
 jmp .Lu_render_cursor_off
.Lu_render_approval_only:
 call .Lu_approval_view
 jmp .Lu_render_cursor_off
.Lu_render_composer:
 mov rdi,r12
 mov esi,1
 call .Lu_move
 call .Lu_border_color
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 call .Lu_repeat
 inc r12
 mov rdi,r12
 mov esi,1
 call .Lu_move
 call .Lu_editor
 mov rdi,r12
 add rdi,[rip+.Lu_composer_rows]
 mov esi,1
 call .Lu_move
 call .Lu_border_color
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 call .Lu_repeat
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_normal_footer
 cmp qword ptr [rip+.Lu_choose],0
 jne .Lu_normal_footer
 cmp qword ptr [rip+.Lu_approval],0
 jne .Lu_normal_footer
 call .Lu_menu_view
 jmp .Lu_render_cursor
.Lu_normal_footer:
 call .Lu_nl
 call .Lu_workspace_footer
 call .Lu_nl
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 call .Lu_indicator_color
 call .Lu_z
 lea rdi,[rip+.Lu_mode_default]
 cmp qword ptr [rip+.Lu_mode],1
 jne .Lu_footer_not_edit
 lea rdi,[rip+.Lu_mode_edit]
.Lu_footer_not_edit:
 cmp qword ptr [rip+.Lu_mode],2
 jne .Lu_footer_not_plan
 lea rdi,[rip+.Lu_mode_plan]
.Lu_footer_not_plan:
 cmp qword ptr [rip+.Lu_mode],3
 jne .Lu_footer_not_yolo
 lea rdi,[rip+.Lu_mode_yolo]
.Lu_footer_not_yolo:
 cmp qword ptr [rip+.Lu_busy],0
 je .Lu_footer_put
 lea rdi,[rip+.Lu_busyfooter]
.Lu_footer_put:
 cmp qword ptr [rip+.Lu_busy],0
 jne .Lu_footer_selected
 mov rax,[rip+.Lu_lasttick]
 cmp rax,[rip+.Lu_hint_deadline]
 ja .Lu_footer_selected
 cmp qword ptr [rip+.Lu_hint_kind],1
 jne .Lu_footer_hint_d
 lea rdi,[rip+.Lu_hint_c]
.Lu_footer_hint_d:
 cmp qword ptr [rip+.Lu_hint_kind],2
 jne .Lu_footer_hint_escape
 lea rdi,[rip+.Lu_hint_d]
.Lu_footer_hint_escape:
 cmp qword ptr [rip+.Lu_hint_kind],3
 jne .Lu_footer_selected
 lea rdi,[rip+.Lu_hint_escape]
.Lu_footer_selected:
 cmp qword ptr [rip+.Lu_shell_mode],0
 je .Lu_footer_final_text
 cmp qword ptr [rip+.Lu_busy],0
 jne .Lu_footer_final_text
 cmp qword ptr [rip+.Lu_hint_kind],0
 jne .Lu_footer_final_text
 lea rdi,[rip+.Lu_shell_footer]
.Lu_footer_final_text:
 mov rsi,[rip+.Lu_columns]
 sub rsi,4
 call .Lu_field
 cmp qword ptr [rip+.Lu_approval],0
 je .Lu_render_choose
 call .Lu_approval_view
 jmp .Lu_render_cursor_off
.Lu_render_choose:
 cmp qword ptr [rip+.Lu_choose],0
 je .Lu_render_menu
 call .Lu_choose_view
 jmp .Lu_render_cursor_off
.Lu_render_menu:
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_render_cursor
 call .Lu_menu_view
.Lu_render_cursor:
 mov rdi,[rip+.Lu_cursor_row]
 sub rdi,[rip+.Lu_editor_scroll]
 cmp rdi,5
 jbe .Lu_cursor_row_ok
 mov edi,5
.Lu_cursor_row_ok:
 add rdi,r12
 mov rsi,[rip+.Lu_cursor_col]
 add rsi,3
 cmp rsi,[rip+.Lu_columns]
 jbe .Lu_cursor_col_ok
 mov rsi,[rip+.Lu_columns]
.Lu_cursor_col_ok:
 call .Lu_move
 lea rdi,[rip+.Lu_cursor_on]
 call .Lu_z
 jmp .Lu_frame_write
.Lu_render_cursor_off:
 lea rdi,[rip+.Lu_cursor_off]
 call .Lu_z
.Lu_frame_write:
 lea rdi,[rip+.Lu_mouse_drag_mode]
 cmp qword ptr [rip+.Lu_choose],0
 jne .Lu_frame_mouse_all
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_frame_mouse_mode
.Lu_frame_mouse_all:
 lea rdi,[rip+.Lu_mouse_all_mode]
.Lu_frame_mouse_mode:
 call .Lu_z
 call .Lu_reset_color
 mov edi,1
 lea rsi,[rip+.Lu_frame]
 mov rdx,[rip+.Lu_builder+16]
 call qx_write_all
 mov qword ptr [rip+.Lu_dirty],0
.Lu_render_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Monotonic50ms frame budget. Resize remains checked on every polling tick.
ui_tick:
 push rbx
 cmp qword ptr [rip+.Lu_activity_busy],0
 jne .Lu_tick_activity_done
 mov rax,[rip+.Lu_activity_hook]
 test rax,rax
 jz .Lu_tick_activity_done
 mov qword ptr [rip+.Lu_activity_busy],1
 call rax
 mov qword ptr [rip+.Lu_activity_busy],0
.Lu_tick_activity_done:
 call .Lu_resize
 cmp qword ptr [rip+.Lu_active],0
 je .Lu_tick_auto_done
 cmp qword ptr [rip+.Lu_environment],0
 je .Lu_tick_auto_done
 cmp qword ptr [rip+.Lu_theme],15
 jne .Lu_tick_auto_done
 cmp qword ptr [rip+.Lu_no_color],0
 jne .Lu_tick_auto_done
 cmp qword ptr [rip+.Lu_auto_known],0
 jne .Lu_tick_auto_done
 cmp qword ptr [rip+.Lu_auto_probed],0
 jne .Lu_tick_auto_done
 mov qword ptr [rip+.Lu_auto_probed],1
 mov edi,1
 lea rsi,[rip+.Lu_osc_query]
 mov edx,7
 call qx_write_all
.Lu_tick_auto_done:
 mov eax,228
 mov edi,1
 lea rsi,[rip+.Lu_time]
 syscall
 test rax,rax
 js .Lu_tick_done
 mov rbx,[rip+.Lu_time]
 imul rbx,rbx,1000
 mov rax,[rip+.Lu_time+8]
 xor edx,edx
 mov ecx,1000000
 div rcx
 add rbx,rax
 mov rax,rbx
 sub rax,[rip+.Lu_lasttick]
 cmp rax,50
 jb .Lu_tick_done
 mov [rip+.Lu_lasttick],rbx
 cmp qword ptr [rip+.Lu_busy],0
 jne .Lu_tick_render
 cmp qword ptr [rip+.Lu_dirty],0
 je .Lu_tick_done
.Lu_tick_render:
 call .Lu_render
.Lu_tick_done:
 pop rbx
 ret
# Rebuild supported slash-command suggestions from explicit command catalogue.
.Lu_update_menu:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov qword ptr [rip+.Lu_menu_count],0
 mov qword ptr [rip+.Lu_completion_kind],0
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 cmp qword ptr [rip+.Lu_menu_dismiss],0
 jne .Lu_update_menu_done
 cmp qword ptr [rip+.Lu_menu],0
 je .Lu_update_menu_active
 test qword ptr [rip+.Lu_snapshot+IS_FLAGS],4
 jnz .Lu_update_menu_active
 mov qword ptr [rip+.Lu_menu],0
 mov qword ptr [rip+.Lu_menu_dismiss],1
 jmp .Lu_update_menu_done
.Lu_update_menu_active:
 mov r12,[rip+.Lu_snapshot+IS_TEXT]
 mov r13,[rip+.Lu_snapshot+IS_LENGTH]
 test r13,r13
 jz .Lu_update_menu_done
 cmp byte ptr [r12],47
 je .Lu_update_slash
 call .Lu_update_paths
 jmp .Lu_update_menu_done
.Lu_update_slash:
 xor eax,eax
.Lu_menu_space:
 cmp rax,r13
 jae .Lu_menu_scan_start
 cmp byte ptr [r12+rax],32
 je .Lu_update_menu_done
 inc rax
 jmp .Lu_menu_space
.Lu_menu_scan_start:
 lea rbx,[rip+.Lu_commands]
.Lu_menu_scan:
 cmp byte ptr [rbx],0
 je .Lu_update_menu_done
 mov r14,rbx
 xor r15d,r15d
.Lu_menu_line:
 cmp byte ptr [rbx+r15],0
 je .Lu_menu_match
 cmp byte ptr [rbx+r15],10
 je .Lu_menu_match
 inc r15
 jmp .Lu_menu_line
.Lu_menu_match:
 cmp r15,r13
 jb .Lu_menu_scan_next
 mov rdi,r12
 mov rsi,r13
 mov rdx,rbx
 mov rcx,r15
 call .Lu_fuzzy_span
 test rax,rax
 jz .Lu_menu_scan_next
 mov rax,[rip+.Lu_menu_count]
 cmp rax,128
 jae .Lu_update_menu_done
 shl rax,4
 lea rdx,[rip+.Lu_matches]
 mov [rdx+rax],rbx
 mov [rdx+rax+8],r15
 inc qword ptr [rip+.Lu_menu_count]
.Lu_menu_scan_next:
 add rbx,r15
 cmp byte ptr [rbx],0
 je .Lu_update_menu_done
 inc rbx
 jmp .Lu_menu_scan
.Lu_update_menu_done:
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_update_menu_off
 mov qword ptr [rip+.Lu_menu],1
 lea rdi,[rip+.Lu_context]
 mov esi,1
 call input_set_completion
 jmp .Lu_update_menu_count_ready
.Lu_update_menu_off:
 mov qword ptr [rip+.Lu_menu],0
 lea rdi,[rip+.Lu_context]
 xor esi,esi
 call input_set_completion
.Lu_update_menu_count_ready:
 mov rax,[rip+.Lu_menu_count]
 cmp [rip+.Lu_menu_index],rax
 jb .Lu_update_menu_return
 mov qword ptr [rip+.Lu_menu_index],0
.Lu_update_menu_return:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Lu_apply_completion:
 push rbx
 cmp qword ptr [rip+.Lu_completion_kind],1
 jne .Lu_apply_slash
 call .Lu_apply_path
 pop rbx
 ret
.Lu_apply_slash:
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_apply_done
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 mov rax,[rip+.Lu_menu_index]
 shl rax,4
 lea rdx,[rip+.Lu_matches]
 mov rcx,[rdx+rax]
 mov r8,[rdx+rax+8]
 lea rdi,[rip+.Lu_context]
 xor esi,esi
 mov rdx,[rip+.Lu_snapshot+IS_LENGTH]
 call input_replace
.Lu_apply_done:
 pop rbx
 ret
# Handle editor/menu/scroll flags; return effective flags.
.Lu_flags:
 push rbx
 mov rbx,rdi
 test ebx,0x80000000
 jz .Lu_flags_no_pointer
 call .Lu_pointer_event
 or rbx,rax
.Lu_flags_no_pointer:
 test rbx,INPUT_CHANGED
 jz .Lu_flags_not_changed
 mov qword ptr [rip+.Lu_menu_dismiss],0
 mov qword ptr [rip+.Lu_menu_tabbed],0
.Lu_flags_not_changed:
 test rbx,134217728
 jz .Lu_flags_no_theme_response
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_osc_rgb]
 call input_osc11_snapshot
 cmp eax,1
 jne .Lu_flags_no_theme_response
 mov rax,[rip+.Lu_osc_rgb]
 imul rax,rax,2126
 mov rdx,[rip+.Lu_osc_rgb+8]
 imul rdx,rdx,7152
 add rax,rdx
 mov rdx,[rip+.Lu_osc_rgb+16]
 imul rdx,rdx,722
 add rax,rdx
 xor edx,edx
 cmp rax,327675000
 jbe .Lu_flags_auto_resolved
 mov edx,4
.Lu_flags_auto_resolved:
 mov [rip+.Lu_auto_resolved],rdx
 mov qword ptr [rip+.Lu_auto_known],1
 cmp qword ptr [rip+.Lu_theme],15
 jne .Lu_flags_no_theme_response
 mov edi,15
 call ui_set_theme
.Lu_flags_no_theme_response:
 test rbx,268435456
 jz .Lu_flags_line_down
 inc qword ptr [rip+.Lu_scroll]
.Lu_flags_line_down:
 test rbx,536870912
 jz .Lu_flags_line_done
 cmp qword ptr [rip+.Lu_scroll],0
 je .Lu_flags_line_done
 dec qword ptr [rip+.Lu_scroll]
.Lu_flags_line_done:
 test rbx,33554432
 jz .Lu_flags_mouse_down
 add qword ptr [rip+.Lu_scroll],3
.Lu_flags_mouse_down:
 test rbx,67108864
 jz .Lu_flags_mouse_done
 mov rax,[rip+.Lu_scroll]
 sub rax,3
 jns .Lu_flags_mouse_store
 xor eax,eax
.Lu_flags_mouse_store:
 mov [rip+.Lu_scroll],rax
.Lu_flags_mouse_done:
 test rbx,16777216
 jz .Lu_flags_shell_no_toggle
 xor qword ptr [rip+.Lu_shell_mode],1
 lea rdi,[rip+.Lu_context]
 mov rsi,[rip+.Lu_shell_mode]
 call input_set_external_history
 call ui_shell_history_reset_nav
.Lu_flags_shell_no_toggle:
 test rbx,4194304
 jz .Lu_flags_shell_next
 call ui_shell_history_prev
 jmp .Lu_flags_shell_recall
.Lu_flags_shell_next:
 test rbx,8388608
 jz .Lu_flags_shell_done
 call ui_shell_history_next
.Lu_flags_shell_recall:
 test rax,rax
 jz .Lu_flags_shell_done
 mov rsi,rax
 lea rdi,[rip+.Lu_context]
 call input_begin
.Lu_flags_shell_done:
 test rbx,INPUT_CHANGED
 jz .Lu_flags_hint_done
 test rbx,INPUT_CANCEL|INPUT_EOF|2097152
 jnz .Lu_flags_hint_done
 mov qword ptr [rip+.Lu_hint_kind],0
.Lu_flags_hint_done:
 test rbx,262144
 jz .Lu_flags_not_clear
 mov qword ptr [rip+.Lu_count],0
 mov qword ptr [rip+.Lu_tool_pending],0
 mov qword ptr [rip+.Lu_poollen],0
 mov qword ptr [rip+.Lu_scroll],0
 mov qword ptr [rip+.Lu_flow_dirty],1
.Lu_flags_not_clear:
 test rbx,524288
 jz .Lu_flags_not_details
 xor qword ptr [rip+.Lu_details],1
 mov qword ptr [rip+.Lu_flow_dirty],1
.Lu_flags_not_details:
 test rbx,1048576
 jz .Lu_flags_not_retry
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_retry_command]
 mov edx,6
 call input_begin
 or rbx,INPUT_SUBMIT
 .Lu_flags_not_retry:
 test rbx,INPUT_EXTERNAL_EDITOR
 jz .Lu_flags_no_editor
 call .Lu_external_editor
.Lu_flags_no_editor:
 test rbx,INPUT_SCROLL_UP
 jz .Lu_flags_down
 add qword ptr [rip+.Lu_scroll],8
.Lu_flags_down:
 test rbx,INPUT_SCROLL_DOWN
 jz .Lu_flags_top
 mov rax,[rip+.Lu_scroll]
 sub rax,8
 jns .Lu_flags_store_scroll
 xor eax,eax
.Lu_flags_store_scroll:
 mov [rip+.Lu_scroll],rax
.Lu_flags_top:
 test rbx,INPUT_SCROLL_TOP
 jz .Lu_flags_bottom
 mov qword ptr [rip+.Lu_scroll],65535
.Lu_flags_bottom:
 test rbx,INPUT_SCROLL_BOTTOM
 jz .Lu_flags_complete
 mov qword ptr [rip+.Lu_scroll],0
.Lu_flags_complete:
 test rbx,INPUT_COMPLETE
 jz .Lu_flags_up
 call .Lu_update_menu
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_flags_up
 cmp qword ptr [rip+.Lu_menu_tabbed],0
 je .Lu_flags_activate
 inc qword ptr [rip+.Lu_menu_index]
 mov rax,[rip+.Lu_menu_index]
 cmp rax,[rip+.Lu_menu_count]
 jb .Lu_flags_activate
 mov qword ptr [rip+.Lu_menu_index],0
.Lu_flags_activate:
 mov qword ptr [rip+.Lu_menu_tabbed],1
 mov qword ptr [rip+.Lu_menu],1
 lea rdi,[rip+.Lu_context]
 mov esi,1
 call input_set_completion
 call .Lu_apply_completion
.Lu_flags_up:
 test rbx,INPUT_MENU_UP
 jz .Lu_flags_menu_down
 cmp qword ptr [rip+.Lu_menu_index],0
 je .Lu_flags_menu_down
 dec qword ptr [rip+.Lu_menu_index]
.Lu_flags_menu_down:
 test rbx,INPUT_MENU_DOWN
 jz .Lu_flags_accept
 mov rax,[rip+.Lu_menu_index]
 inc rax
 cmp rax,[rip+.Lu_menu_count]
 jae .Lu_flags_accept
 mov [rip+.Lu_menu_index],rax
.Lu_flags_accept:
 test rbx,INPUT_MENU_ACCEPT
 jz .Lu_flags_done
 mov rax,[rip+.Lu_completion_kind]
 push rax
 sub rsp,8
 call .Lu_apply_completion
 add rsp,8
 pop rax
 test rax,rax
 jnz .Lu_flags_done
 or rbx,INPUT_SUBMIT
.Lu_flags_done:
 test rbx,131072
 jz .Lu_flags_no_mode
 inc qword ptr [rip+.Lu_mode]
 and qword ptr [rip+.Lu_mode],3
.Lu_flags_no_mode:
 test rbx,rbx
 jz .Lu_flags_clean
 mov qword ptr [rip+.Lu_dirty],1
.Lu_flags_clean:
 mov rax,rbx
 pop rbx
 ret
# Buffered acquisition retains bytes after a submit/cancel boundary across calls.
.Lu_acquire:
 push rbx
 mov rbx,rdi
 cmp qword ptr [rip+.Lu_startup_events],0
 je .Lu_acquire_no_saved_event
 mov rax,[rip+.Lu_startup_events]
 mov qword ptr [rip+.Lu_startup_events],0
 pop rbx
 ret
.Lu_acquire_no_saved_event:
 mov rax,[rip+.Lu_rxpos]
 cmp rax,[rip+.Lu_rxlen]
 jb .Lu_acquire_feed
 mov qword ptr [rip+.Lu_pollfd],0
 mov word ptr [rip+.Lu_pollfd+4],1
 mov eax,7
 lea rdi,[rip+.Lu_pollfd]
 mov esi,1
 mov rdx,rbx
 syscall
 cmp rax,-4
 je .Lu_acquire_none
 test rax,rax
 js .Lu_acquire_eof
 jz .Lu_acquire_timeout
 test word ptr [rip+.Lu_pollfd+6],1
 jz .Lu_acquire_eof
 xor eax,eax
 xor edi,edi
 lea rsi,[rip+.Lu_rx]
 mov edx,256
 syscall
 test rax,rax
 jle .Lu_acquire_eof
 mov [rip+.Lu_rxlen],rax
 mov qword ptr [rip+.Lu_rxpos],0
.Lu_acquire_feed:
.Lu_acquire_editor_feed:
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_rx]
 add rsi,[rip+.Lu_rxpos]
 mov rdx,[rip+.Lu_rxlen]
 sub rdx,[rip+.Lu_rxpos]
 call input_feed
 mov rbx,rax
 lea rdi,[rip+.Lu_context]
 call input_consumed
 add [rip+.Lu_rxpos],rax
 mov rdi,rbx
 call .Lu_flags
 pop rbx
 ret
.Lu_acquire_timeout:
 test rbx,rbx
 jz .Lu_acquire_none
 lea rdi,[rip+.Lu_context]
 call input_timeout
 mov rdi,rax
 call .Lu_flags
 pop rbx
 ret
.Lu_acquire_eof:
 mov eax,INPUT_EOF
 pop rbx
 ret
.Lu_acquire_none:
 xor eax,eax
 pop rbx
 ret
.Lu_queue_current:
 push rbx
 push r12
 push r13
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 mov r12,[rip+.Lu_snapshot+IS_LENGTH]
 test r12,r12
 jz .Lu_queue_empty
 cmp qword ptr [rip+.Lu_qcount],8
 jae .Lu_queue_full
 mov rbx,[rip+.Lu_qhead]
 add rbx,[rip+.Lu_qcount]
 and ebx,7
 mov rax,rbx
 shl rax,16
 lea rdi,[rip+.Lu_queue]
 add rdi,rax
 mov rsi,[rip+.Lu_snapshot+IS_TEXT]
 mov rcx,r12
 rep movsb
 mov byte ptr [rdi],0
 lea rdx,[rip+.Lu_qlengths]
 mov [rdx+rbx*8],r12
 inc qword ptr [rip+.Lu_qcount]
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_empty]
 xor edx,edx
 call input_begin
 mov qword ptr [rip+.Lu_menu_count],0
 mov qword ptr [rip+.Lu_menu],0
.Lu_queue_empty:
 xor eax,eax
 jmp .Lu_queue_return
.Lu_queue_full:
 lea rdi,[rip+.Lu_queue_full_text]
 call ui_status
 mov rax,-28
.Lu_queue_return:
 pop r13
 pop r12
 pop rbx
 ret
ui_poll:
 push rbx
 cmp qword ptr [rip+.Lu_active],0
 je .Lu_poll_idle
 cmp qword ptr [rip+.Lu_approval],0
 jne .Lu_poll_idle
 cmp qword ptr [rip+.Lu_choose],0
 jne .Lu_poll_idle
 xor edi,edi
 call .Lu_acquire
 mov rbx,rax
 test rbx,INPUT_EOF
 jz .Lu_poll_check_cancel
 mov qword ptr [rip+.Lu_exit_pending],1
 jmp .Lu_poll_cancel
.Lu_poll_check_cancel:
 test rbx,INPUT_CANCEL|2097152
 jnz .Lu_poll_cancel
 test rbx,INPUT_SUBMIT|INPUT_QUEUE
 jz .Lu_poll_update
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 cmp qword ptr [rip+.Lu_snapshot+IS_LENGTH],0
 je .Lu_poll_update
 call .Lu_queue_current
 test rax,rax
 js .Lu_poll_update
 test rbx,INPUT_SUBMIT
 jnz .Lu_poll_cancel
.Lu_poll_update:
 test rbx,rbx
 jz .Lu_poll_menu_current
 call .Lu_update_menu
.Lu_poll_menu_current:
 call ui_tick
.Lu_poll_idle:
 xor eax,eax
 pop rbx
 ret
.Lu_poll_cancel:
 mov qword ptr [rip+net_cancelled],1
 mov rax,-125
 pop rbx
 ret
ui_take_queued:
 push rbx
 cmp qword ptr [rip+.Lu_qcount],0
 je .Lu_take_empty
 mov rbx,[rip+.Lu_qhead]
 lea rdx,[rip+.Lu_qlengths]
 mov rax,[rdx+rbx*8]
 cmp rax,rsi
 jae .Lu_take_bad
 mov rdx,rax
 mov rax,rbx
 shl rax,16
 lea rsi,[rip+.Lu_queue]
 add rsi,rax
 mov rcx,rdx
 inc rcx
 rep movsb
 inc rbx
 and ebx,7
 mov [rip+.Lu_qhead],rbx
 dec qword ptr [rip+.Lu_qcount]
 mov rax,rdx
 jmp .Lu_take_done
.Lu_take_empty:
 xor eax,eax
 jmp .Lu_take_done
.Lu_take_bad:
 mov rax,-28
.Lu_take_done:
 pop rbx
 ret
ui_readline:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 cmp qword ptr [rip+.Lu_exit_pending],0
 jne .Lu_readline_exit
 call ui_take_queued
 test rax,rax
 js .Lu_readline_return
 jz .Lu_readline_start
 mov rbx,rax
 lea rdi,[rip+.Lu_context]
 mov rsi,r12
 mov rdx,rbx
 call input_history_add
 mov rax,rbx
 jmp .Lu_readline_return
.Lu_readline_start:
 mov qword ptr [rip+.Lu_dirty],1
.Lu_readline_loop:
 cmp qword ptr [rip+.Lu_dirty],0
 je .Lu_readline_menu_current
 call .Lu_update_menu
.Lu_readline_menu_current:
 call ui_tick
 mov edi,50
 call .Lu_acquire
 mov rbx,rax
 test rbx,INPUT_EOF
 jnz .Lu_readline_ctrl_d
 test rbx,INPUT_CANCEL
 jnz .Lu_readline_ctrl_c
 test rbx,2097152
 jnz .Lu_readline_escape
 test rbx,INPUT_SUBMIT
 jz .Lu_readline_loop
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 mov rbx,[rip+.Lu_snapshot+IS_LENGTH]
 test rbx,rbx
 jz .Lu_readline_loop
 cmp rbx,r13
 jae .Lu_readline_loop
 mov rdi,r12
 mov rsi,[rip+.Lu_snapshot+IS_TEXT]
 mov rcx,rbx
 rep movsb
 mov byte ptr [rdi],0
 cmp qword ptr [rip+.Lu_shell_mode],0
 jne .Lu_readline_shell_history
 lea rdi,[rip+.Lu_context]
 mov rsi,r12
 mov rdx,rbx
 call input_history_add
.Lu_readline_shell_history:
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_empty]
 xor edx,edx
 call input_begin
 mov qword ptr [rip+.Lu_menu],0
 mov qword ptr [rip+.Lu_menu_count],0
 mov rax,rbx
 jmp .Lu_readline_return
.Lu_readline_ctrl_c:
 mov edi,1
 jmp .Lu_readline_control
.Lu_readline_ctrl_d:
 mov edi,2
 jmp .Lu_readline_control
.Lu_readline_escape:
 cmp qword ptr [rip+.Lu_shell_mode],0
 je .Lu_readline_normal_escape
 mov qword ptr [rip+.Lu_shell_mode],0
 lea rdi,[rip+.Lu_context]
 xor esi,esi
 call input_set_external_history
 call ui_shell_history_reset_nav
 mov qword ptr [rip+.Lu_dirty],1
 jmp .Lu_readline_loop
.Lu_readline_normal_escape:
 mov edi,3
.Lu_readline_control:
 mov rax,[rip+.Lu_lasttick]
 cmp rdi,[rip+.Lu_hint_kind]
 jne .Lu_readline_first_control
 cmp rax,[rip+.Lu_hint_deadline]
 ja .Lu_readline_first_control
 cmp edi,3
 jne .Lu_readline_exit
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_empty]
 xor edx,edx
 call input_begin
 mov qword ptr [rip+.Lu_hint_kind],0
 mov qword ptr [rip+.Lu_dirty],1
 jmp .Lu_readline_loop
.Lu_readline_first_control:
 mov [rip+.Lu_hint_kind],rdi
 add rax,1500
 mov [rip+.Lu_hint_deadline],rax
 mov qword ptr [rip+.Lu_dirty],1
 jmp .Lu_readline_loop
.Lu_readline_exit:
 mov rax,-1
.Lu_readline_return:
 pop r13
 pop r12
 pop rbx
 ret
# Slash completion panel is an unboxed list with source margins/accent selection.
.Lu_menu_view:
 push rbx
 push r12
 push r13
 mov r12,[rip+.Lu_composer_top]
 add r12,[rip+.Lu_composer_rows]
 add r12,2
.Lu_menu_row_ok:
 xor ebx,ebx
.Lu_menu_view_row:
 cmp rbx,[rip+.Lu_menu_count]
 jae .Lu_menu_view_done
 cmp rbx,5
 jae .Lu_menu_view_done
 cmp r12,[rip+.Lu_rows]
 ja .Lu_menu_view_done
 mov rdi,r12
 mov esi,1
 call .Lu_move
 lea rdi,[rip+.Lu_accent]
 cmp rbx,[rip+.Lu_menu_index]
 je .Lu_menu_view_color
 lea rdi,[rip+.Lu_muted]
.Lu_menu_view_color:
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 lea rdi,[rip+.Lu_nomarker]
 cmp rbx,[rip+.Lu_menu_index]
 jne .Lu_menu_view_marker
 lea rdi,[rip+.Lu_completion_marker]
.Lu_menu_view_marker:
 call .Lu_z
 mov rax,rbx
 shl rax,4
 lea rdx,[rip+.Lu_matches]
 mov rsi,[rdx+rax]
 mov rcx,[rdx+rax+8]
 cmp qword ptr [rip+.Lu_completion_kind],0
 jne .Lu_menu_label_path
 test rcx,rcx
 jz .Lu_menu_label_path
 inc rsi
 dec rcx
.Lu_menu_label_path:
 cmp rcx,255
 jbe .Lu_menu_copy
 mov ecx,255
.Lu_menu_copy:
 lea rdi,[rip+.Lu_bytes]
 rep movsb
 mov byte ptr [rdi],0
 lea rdi,[rip+.Lu_bytes]
 mov rsi,[rip+.Lu_columns]
 sub rsi,4
 call .Lu_field
 inc r12
 inc rbx
 jmp .Lu_menu_view_row
.Lu_menu_view_done:
 pop r13
 pop r12
 pop rbx
 ret
# Dialog key decoder shares no editor state; escaped key packets may be split.
.Lu_dialog_read:
 push rbx
 call ui_tick
 mov qword ptr [rip+.Lu_pollfd],0
 mov word ptr [rip+.Lu_pollfd+4],1
 mov eax,7
 lea rdi,[rip+.Lu_pollfd]
 mov esi,1
 mov edx,50
 syscall
 test rax,rax
 jle .Lu_dialog_timeout
 test word ptr [rip+.Lu_pollfd+6],1
 jz .Lu_dialog_cancel
 xor eax,eax
 xor edi,edi
 lea rsi,[rip+.Lu_bytes]
 mov edx,1
 syscall
 cmp rax,1
 jne .Lu_dialog_cancel
 movzx ebx,byte ptr [rip+.Lu_bytes]
 mov rax,[rip+.Lu_dialog_escape]
 cmp rax,1
 je .Lu_dialog_after_esc
 cmp rax,2
 je .Lu_dialog_csi
 cmp rax,3
 je .Lu_dialog_pgup
 cmp rax,4
 je .Lu_dialog_pgdown
 cmp rax,5
 je .Lu_dialog_mouse_byte
 cmp rax,6
 je .Lu_dialog_mouse_discard
 cmp rax,7
 je .Lu_dialog_osc_byte
 cmp rax,8
 je .Lu_dialog_csi_discard
 cmp ebx,27
 je .Lu_dialog_esc
 cmp ebx,3
 je .Lu_dialog_force_cancel
 cmp ebx,4
 je .Lu_dialog_force_cancel
 cmp ebx,13
 je .Lu_dialog_enter
 cmp ebx,10
 je .Lu_dialog_enter
 cmp qword ptr [rip+.Lu_choose],0
 jne .Lu_dialog_search_key
 cmp ebx,121
 je .Lu_dialog_allow
 cmp ebx,89
 je .Lu_dialog_allow
 cmp ebx,49
 je .Lu_dialog_allow
 cmp ebx,50
 je .Lu_dialog_always
 cmp ebx,110
 je .Lu_dialog_cancel
 cmp ebx,78
 je .Lu_dialog_cancel
 cmp ebx,51
 je .Lu_dialog_cancel
 cmp ebx,107
 je .Lu_dialog_up
 cmp ebx,106
 je .Lu_dialog_down
 jmp .Lu_dialog_none
.Lu_dialog_search_key:
 cmp ebx,127
 je .Lu_dialog_backspace
 cmp ebx,8
 je .Lu_dialog_backspace
 cmp ebx,21
 je .Lu_dialog_clear_query
 cmp ebx,9
 je .Lu_dialog_tab
 cmp ebx,32
 jb .Lu_dialog_none
 mov eax,9
 jmp .Lu_dialog_return
.Lu_dialog_shift_tab:
 mov eax,15
 jmp .Lu_dialog_return
.Lu_dialog_tab:
 mov eax,14
 jmp .Lu_dialog_return
.Lu_dialog_backspace:
 mov eax,10
 jmp .Lu_dialog_return
.Lu_dialog_clear_query:
 mov eax,11
 jmp .Lu_dialog_return
.Lu_dialog_after_esc:
 cmp ebx,93
 je .Lu_dialog_osc_start
 cmp ebx,79
 je .Lu_dialog_begin_csi
 cmp ebx,91
 jne .Lu_dialog_unknown_escape
.Lu_dialog_begin_csi:
 mov qword ptr [rip+.Lu_dialog_escape],2
 jmp .Lu_dialog_none
.Lu_dialog_unknown_escape:
 mov qword ptr [rip+.Lu_dialog_escape],0
 jmp .Lu_dialog_none
.Lu_dialog_csi:
 mov qword ptr [rip+.Lu_dialog_escape],0
 cmp ebx,90
 je .Lu_dialog_shift_tab
 cmp ebx,60
 je .Lu_dialog_mouse_start
 cmp ebx,65
 je .Lu_dialog_up
 cmp ebx,66
 je .Lu_dialog_down
 cmp ebx,67
 je .Lu_dialog_right
 cmp ebx,68
 je .Lu_dialog_left
 cmp ebx,53
 je .Lu_dialog_mark_up
 cmp ebx,54
 je .Lu_dialog_mark_down
 cmp ebx,0x40
 jae .Lu_dialog_none
 mov qword ptr [rip+.Lu_dialog_escape],8
 jmp .Lu_dialog_none
.Lu_dialog_osc_start:
 mov qword ptr [rip+.Lu_dialog_escape],7
 mov qword ptr [rip+.Lu_dialog_osc_esc],0
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_osc_prefix]
 mov edx,2
 call input_feed
 jmp .Lu_dialog_none
.Lu_dialog_osc_byte:
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_bytes]
 mov edx,1
 call input_feed
 test rax,134217728
 jz .Lu_dialog_osc_framing
 mov rdi,rax
 call .Lu_flags
.Lu_dialog_osc_framing:
 cmp ebx,7
 je .Lu_dialog_osc_done
 cmp qword ptr [rip+.Lu_dialog_osc_esc],0
 je .Lu_dialog_osc_not_st
 cmp ebx,92
 je .Lu_dialog_osc_done
.Lu_dialog_osc_not_st:
 xor eax,eax
 cmp ebx,27
 sete al
 mov [rip+.Lu_dialog_osc_esc],rax
 jmp .Lu_dialog_none
.Lu_dialog_osc_done:
 mov qword ptr [rip+.Lu_dialog_escape],0
 mov qword ptr [rip+.Lu_dialog_osc_esc],0
 jmp .Lu_dialog_none
.Lu_dialog_mouse_start:
 mov qword ptr [rip+.Lu_dialog_escape],5
 mov qword ptr [rip+.Lu_dialog_button],0
 mov qword ptr [rip+.Lu_dialog_x],0
 mov qword ptr [rip+.Lu_dialog_y],0
 mov qword ptr [rip+.Lu_dialog_release],0
 mov qword ptr [rip+.Lu_dialog_mouse_digits],0
 mov qword ptr [rip+.Lu_dialog_mouse_phase],0
 jmp .Lu_dialog_none
.Lu_dialog_mouse_byte:
 cmp ebx,77
 je .Lu_dialog_mouse_final
 cmp ebx,109
 je .Lu_dialog_mouse_final_release
 cmp ebx,59
 je .Lu_dialog_mouse_separator
 cmp ebx,48
 jb .Lu_dialog_mouse_invalid
 cmp ebx,57
 ja .Lu_dialog_mouse_invalid
 mov rdx,[rip+.Lu_dialog_mouse_phase]
 cmp rdx,2
 ja .Lu_dialog_mouse_invalid
 lea rcx,[rip+.Lu_dialog_button]
 mov rax,[rcx+rdx*8]
 imul rax,rax,10
 sub ebx,48
 add rax,rbx
 cmp rax,65535
 ja .Lu_dialog_mouse_invalid
 mov [rcx+rdx*8],rax
 inc qword ptr [rip+.Lu_dialog_mouse_digits]
 jmp .Lu_dialog_none
.Lu_dialog_mouse_separator:
 cmp qword ptr [rip+.Lu_dialog_mouse_digits],0
 je .Lu_dialog_mouse_invalid
 mov qword ptr [rip+.Lu_dialog_mouse_digits],0
 inc qword ptr [rip+.Lu_dialog_mouse_phase]
 cmp qword ptr [rip+.Lu_dialog_mouse_phase],2
 ja .Lu_dialog_mouse_invalid
 jmp .Lu_dialog_none
.Lu_dialog_mouse_final_release:
 mov qword ptr [rip+.Lu_dialog_release],1
.Lu_dialog_mouse_final:
 mov qword ptr [rip+.Lu_dialog_escape],0
 cmp qword ptr [rip+.Lu_dialog_mouse_phase],2
 jne .Lu_dialog_none
 cmp qword ptr [rip+.Lu_dialog_mouse_digits],0
 je .Lu_dialog_none
 cmp qword ptr [rip+.Lu_dialog_x],0
 je .Lu_dialog_none
 cmp qword ptr [rip+.Lu_dialog_y],0
 je .Lu_dialog_none
 mov rax,[rip+.Lu_dialog_button]
 cmp rax,127
 ja .Lu_dialog_none
 and eax,0xe3
 cmp eax,64
 je .Lu_dialog_wheel_up
 cmp eax,65
 je .Lu_dialog_wheel_down
 mov eax,19
 jmp .Lu_dialog_return
.Lu_dialog_mouse_invalid:
 mov qword ptr [rip+.Lu_dialog_escape],6
 jmp .Lu_dialog_none
.Lu_dialog_mouse_discard:
 cmp ebx,27
 je .Lu_dialog_cancel
 cmp ebx,77
 je .Lu_dialog_mouse_release
 cmp ebx,109
 je .Lu_dialog_mouse_release
 jmp .Lu_dialog_none
.Lu_dialog_mouse_release:
 mov qword ptr [rip+.Lu_dialog_escape],0
 jmp .Lu_dialog_none
.Lu_dialog_wheel_up:
 mov eax,12
 jmp .Lu_dialog_return
.Lu_dialog_wheel_down:
 mov eax,13
 jmp .Lu_dialog_return
.Lu_dialog_mark_up:
 mov qword ptr [rip+.Lu_dialog_escape],3
 jmp .Lu_dialog_none
.Lu_dialog_mark_down:
 mov qword ptr [rip+.Lu_dialog_escape],4
 jmp .Lu_dialog_none
.Lu_dialog_csi_discard:
 cmp ebx,0x40
 jb .Lu_dialog_none
 cmp ebx,0x7e
 ja .Lu_dialog_none
 mov qword ptr [rip+.Lu_dialog_escape],0
 jmp .Lu_dialog_none
.Lu_dialog_pgup:
 cmp ebx,126
 jne .Lu_dialog_start_csi_discard
 mov qword ptr [rip+.Lu_dialog_escape],0
 mov eax,6
 jmp .Lu_dialog_return
.Lu_dialog_start_csi_discard:
 mov qword ptr [rip+.Lu_dialog_escape],8
 jmp .Lu_dialog_csi_discard
.Lu_dialog_pgdown:
 cmp ebx,126
 jne .Lu_dialog_start_csi_discard
 mov qword ptr [rip+.Lu_dialog_escape],0
 mov eax,7
 jmp .Lu_dialog_return
.Lu_dialog_esc:
 mov qword ptr [rip+.Lu_dialog_escape],1
 jmp .Lu_dialog_none
.Lu_dialog_timeout:
 cmp qword ptr [rip+.Lu_dialog_escape],1
 je .Lu_dialog_cancel
.Lu_dialog_none:
 xor eax,eax
 jmp .Lu_dialog_return
.Lu_dialog_up:
 mov eax,1
 jmp .Lu_dialog_return
.Lu_dialog_down:
 mov eax,2
 jmp .Lu_dialog_return
.Lu_dialog_right:
 mov eax,17
 jmp .Lu_dialog_return
.Lu_dialog_left:
 mov eax,18
 jmp .Lu_dialog_return
.Lu_dialog_enter:
 mov eax,3
 jmp .Lu_dialog_return
.Lu_dialog_allow:
 mov eax,4
 jmp .Lu_dialog_return
.Lu_dialog_always:
 mov eax,5
 jmp .Lu_dialog_return
.Lu_dialog_force_cancel:
 mov qword ptr [rip+.Lu_dialog_escape],0
 mov qword ptr [rip+.Lu_dialog_osc_esc],0
 mov eax,16
 jmp .Lu_dialog_return
.Lu_dialog_cancel:
 mov qword ptr [rip+.Lu_dialog_escape],0
 mov qword ptr [rip+.Lu_dialog_osc_esc],0
 mov eax,8
.Lu_dialog_return:
 pop rbx
 ret
ui_approve:
 push rbx
 mov rbx,rdi
 call qx_strlen
 mov rdi,rbx
 mov rsi,rax
 lea rdx,[rip+.Lu_preview]
 mov ecx,4194303
 call ui_sanitize
 test rax,rax
 js .Lu_approve_deny
 mov [rip+.Lu_preview_len],rax
 mov rdi,rbx
 call .Lu_prepare_typed_approval
 mov qword ptr [rip+.Lu_approval],1
 mov qword ptr [rip+.Lu_flow_dirty],1
 mov qword ptr [rip+.Lu_selection],0
 mov qword ptr [rip+.Lu_scroll],0
 mov qword ptr [rip+.Lu_dialog_escape],0
.Lu_approve_loop:
 call .Lu_render
 call .Lu_dialog_read
 cmp eax,16
 je .Lu_approve_deny
 cmp eax,8
 je .Lu_approve_deny
 cmp eax,4
 je .Lu_approve_once
 cmp eax,5
 je .Lu_approve_always
 cmp eax,3
 je .Lu_approve_selected
 cmp eax,1
 jne .Lu_approve_down
 cmp qword ptr [rip+.Lu_selection],0
 je .Lu_approve_loop
 dec qword ptr [rip+.Lu_selection]
 mov qword ptr [rip+.Lu_flow_dirty],1
 jmp .Lu_approve_loop
.Lu_approve_down:
 cmp eax,2
 jne .Lu_approve_pgup
 cmp qword ptr [rip+.Lu_selection],2
 jae .Lu_approve_loop
 inc qword ptr [rip+.Lu_selection]
 mov qword ptr [rip+.Lu_flow_dirty],1
 jmp .Lu_approve_loop
.Lu_approve_pgup:
 cmp eax,12
 jne .Lu_approve_page_up
 add qword ptr [rip+.Lu_scroll],3
 jmp .Lu_approve_loop
.Lu_approve_page_up:
 cmp eax,6
 jne .Lu_approve_pgdn
 add qword ptr [rip+.Lu_scroll],8
 jmp .Lu_approve_loop
.Lu_approve_pgdn:
 cmp eax,13
 jne .Lu_approve_page_down
 mov rax,[rip+.Lu_scroll]
 sub rax,3
 jmp .Lu_approve_down_clamp
.Lu_approve_page_down:
 cmp eax,7
 jne .Lu_approve_loop
 mov rax,[rip+.Lu_scroll]
 sub rax,8
.Lu_approve_down_clamp:
 test rax,rax
 jns .Lu_approve_scroll
 xor eax,eax
.Lu_approve_scroll:
 mov [rip+.Lu_scroll],rax
 jmp .Lu_approve_loop
.Lu_approve_selected:
 cmp qword ptr [rip+.Lu_selection],0
 je .Lu_approve_once
 cmp qword ptr [rip+.Lu_selection],1
 je .Lu_approve_always
.Lu_approve_deny:
 xor ebx,ebx
 jmp .Lu_approve_done
.Lu_approve_once:
 mov ebx,1
 jmp .Lu_approve_done
.Lu_approve_always:
 mov ebx,2
.Lu_approve_done:
 mov qword ptr [rip+.Lu_approval],0
 mov qword ptr [rip+.Lu_flow_dirty],1
 mov qword ptr [rip+.Lu_scroll],0
 call .Lu_render
 mov rax,rbx
 pop rbx
 ret
.Lu_dialog_title:
 push rbx
 mov rbx,rdi
 mov edi,10
 mov esi,1
 call .Lu_move
 lea rdi,[rip+.Lu_warning]
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 mov rdi,rbx
 mov rsi,[rip+.Lu_columns]
 sub rsi,4
 call .Lu_field
 pop rbx
 ret
.Lu_approval_view:
 push rbx
 mov rdi,[rip+.Lu_rows]
 mov esi,1
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 mov rax,[rip+.Lu_lasttick]
 xor edx,edx
 mov ecx,100
 div rcx
 and eax,7
 lea rdi,[rip+.Lu_spinners]
 lea rdi,[rdi+rax*4]
 mov esi,3
 call .Lu_put
 lea rdi,[rip+.Lu_waiting_text]
 call .Lu_z
 pop rbx
 ret
# Generic real backend choice table:24B(labelz,descriptionz,valueptr).
ui_choose:
 push rbx
 push r12
 push r13
 mov [rip+.Lu_choose_title],rdi
 mov [rip+.Lu_choose_items],rsi
 mov [rip+.Lu_choose_count],rdx
 cmp rdx,256
 ja .Lu_choose_invalid
 cmp rcx,rdx
 jb .Lu_choose_initial
 xor ecx,ecx
.Lu_choose_initial:
 mov [rip+.Lu_choose_selection],rcx
 mov [rip+.Lu_filtered_selection],rcx
 mov qword ptr [rip+.Lu_query_len],0
 mov byte ptr [rip+.Lu_query],0
 mov qword ptr [rip+.Lu_choice_scope],0
 mov qword ptr [rip+.Lu_scope_focus],0
 mov qword ptr [rip+.Lu_help_scroll],0
 mov qword ptr [rip+.Lu_resume_search_active],0
 mov qword ptr [rip+.Lu_multi_mask],0
 mov qword ptr [rip+.Lu_read_preview_active],0
 cmp qword ptr [rip+.Lu_view_only],0
 je .Lu_choose_read_mode_ready
 mov qword ptr [rip+.Lu_read_preview_active],1
 mov qword ptr [rip+.Lu_read_scroll],0
 call .Lu_format_read_preview
.Lu_choose_read_mode_ready:
 mov qword ptr [rip+.Lu_reader_error],0
 call .Lu_choose_filter
 mov qword ptr [rip+.Lu_choose],1
 mov qword ptr [rip+.Lu_preview_last],-1
 mov qword ptr [rip+.Lu_dialog_escape],0
.Lu_choose_loop:
 mov rax,[rip+.Lu_filtered_selection]
 cmp rax,[rip+.Lu_filtered_count]
 jae .Lu_choose_empty_mapping
 lea rdx,[rip+.Lu_filtered]
 mov rax,[rdx+rax*8]
 mov [rip+.Lu_choose_selection],rax
.Lu_choose_empty_mapping:
 cmp qword ptr [rip+.Lu_filtered_count],0
 je .Lu_choose_paint
 mov rax,[rip+.Lu_choose_selection]
 cmp rax,[rip+.Lu_preview_last]
 je .Lu_choose_paint
 mov [rip+.Lu_preview_last],rax
 mov qword ptr [rip+.Lu_reader_error],0
 mov rcx,[rip+.Lu_preview_callback]
 test rcx,rcx
 jz .Lu_choose_paint
 mov rdi,rax
 imul rax,rax,24
 add rax,[rip+.Lu_choose_items]
 mov rsi,[rax+16]
 call rcx
.Lu_choose_paint:
 call .Lu_render
 call .Lu_dialog_read
 cmp eax,16
 je .Lu_choose_invalid
 cmp eax,19
 je .Lu_choose_mouse_event
 cmp qword ptr [rip+.Lu_choice_tabs_count],0
 je .Lu_choose_nonmanager_key
 cmp eax,14
 je .Lu_manager_tab_next
 cmp eax,15
 je .Lu_manager_tab_previous
 cmp eax,17
 je .Lu_manager_tab_next
 cmp eax,18
 je .Lu_manager_tab_previous
 cmp eax,9
 jne .Lu_choose_nonmanager_key
 cmp byte ptr [rip+.Lu_bytes],32
 je .Lu_manager_toggle
 cmp byte ptr [rip+.Lu_bytes],102
 je .Lu_manager_favorite
.Lu_choose_nonmanager_key:
 cmp qword ptr [rip+.Lu_read_preview_active],0
 jne .Lu_choose_preview_key
 cmp qword ptr [rip+.Lu_choice_layout],4
 je .Lu_choose_help_key
 cmp qword ptr [rip+.Lu_choice_layout],3
 je .Lu_choose_resume_key
 cmp eax,15
 je .Lu_choose_tab
 cmp eax,8
 je .Lu_choose_invalid
 cmp eax,14
 je .Lu_choose_tab
 cmp eax,9
 je .Lu_choose_type
 cmp eax,10
 je .Lu_choose_backspace
 cmp eax,11
 je .Lu_choose_clear
 cmp eax,3
 je .Lu_choose_accept
 cmp eax,1
 jne .Lu_choose_down
 cmp qword ptr [rip+.Lu_scope_focus],0
 je .Lu_choose_theme_up
 mov qword ptr [rip+.Lu_choice_scope],0
 jmp .Lu_choose_loop
.Lu_choose_theme_up:
 cmp qword ptr [rip+.Lu_filtered_selection],0
 je .Lu_choose_loop
 dec qword ptr [rip+.Lu_filtered_selection]
 jmp .Lu_choose_loop
.Lu_choose_down:
 cmp eax,2
 jne .Lu_choose_loop
 cmp qword ptr [rip+.Lu_scope_focus],0
 je .Lu_choose_theme_down
 mov qword ptr [rip+.Lu_choice_scope],1
 jmp .Lu_choose_loop
.Lu_choose_theme_down:
 mov rax,[rip+.Lu_filtered_selection]
 inc rax
 cmp rax,[rip+.Lu_filtered_count]
 jae .Lu_choose_loop
 mov [rip+.Lu_filtered_selection],rax
 jmp .Lu_choose_loop
.Lu_choose_tab:
 cmp qword ptr [rip+.Lu_box_theme],0
 je .Lu_choose_loop
 xor qword ptr [rip+.Lu_scope_focus],1
 jmp .Lu_choose_loop
.Lu_choose_help_key:
 cmp eax,8
 je .Lu_choose_invalid
 cmp eax,14
 je .Lu_help_next_tab
 cmp eax,15
 je .Lu_help_previous_tab
 cmp eax,1
 je .Lu_help_scroll_up_one
 cmp eax,2
 je .Lu_help_scroll_down_one
 cmp eax,6
 je .Lu_help_scroll_up_page
 cmp eax,7
 je .Lu_help_scroll_down_page
 cmp eax,12
 je .Lu_help_scroll_up_wheel
 cmp eax,13
 je .Lu_help_scroll_down_wheel
 jmp .Lu_choose_loop
.Lu_help_next_tab:
 mov rax,[rip+.Lu_filtered_selection]
 inc rax
 cmp rax,[rip+.Lu_choose_count]
 jb .Lu_help_tab_selected
 xor eax,eax
 jmp .Lu_help_tab_selected
.Lu_help_previous_tab:
 mov rax,[rip+.Lu_filtered_selection]
 test rax,rax
 jnz .Lu_help_tab_decrement
 mov rax,[rip+.Lu_choose_count]
.Lu_help_tab_decrement:
 dec rax
.Lu_help_tab_selected:
 mov [rip+.Lu_filtered_selection],rax
 mov qword ptr [rip+.Lu_help_scroll],0
 jmp .Lu_choose_loop
.Lu_help_scroll_up_one:
 mov eax,1
 jmp .Lu_help_scroll_up
.Lu_help_scroll_up_page:
 mov eax,8
 jmp .Lu_help_scroll_up
.Lu_help_scroll_up_wheel:
 mov eax,3
.Lu_help_scroll_up:
 mov rdx,[rip+.Lu_help_scroll]
 sub rdx,rax
 jns .Lu_help_scroll_store
 xor edx,edx
 jmp .Lu_help_scroll_store
.Lu_help_scroll_down_one:
 mov eax,1
 jmp .Lu_help_scroll_down
.Lu_help_scroll_down_page:
 mov eax,8
 jmp .Lu_help_scroll_down
.Lu_help_scroll_down_wheel:
 mov eax,3
.Lu_help_scroll_down:
 mov rdx,[rip+.Lu_help_scroll]
 add rdx,rax
.Lu_help_scroll_store:
 mov [rip+.Lu_help_scroll],rdx
 jmp .Lu_choose_loop
.Lu_choose_type:
 cmp qword ptr [rip+.Lu_scope_focus],0
 je .Lu_choose_query_type
 cmp byte ptr [rip+.Lu_bytes],49
 je .Lu_choose_scope_user
 cmp byte ptr [rip+.Lu_bytes],50
 jne .Lu_choose_loop
 mov qword ptr [rip+.Lu_choice_scope],1
 jmp .Lu_choose_accept
.Lu_choose_scope_user:
 mov qword ptr [rip+.Lu_choice_scope],0
 jmp .Lu_choose_accept
.Lu_choose_query_type:
.Lu_choose_query_regular:
 mov rax,[rip+.Lu_query_len]
 cmp rax,511
 jae .Lu_choose_loop
 lea rdx,[rip+.Lu_query]
 mov cl,[rip+.Lu_bytes]
 mov [rdx+rax],cl
 inc rax
 mov byte ptr [rdx+rax],0
 mov [rip+.Lu_query_len],rax
 jmp .Lu_choose_refilter
.Lu_choose_clear:
 mov qword ptr [rip+.Lu_query_len],0
 mov byte ptr [rip+.Lu_query],0
 jmp .Lu_choose_refilter
.Lu_choose_backspace:
 mov r12,[rip+.Lu_query_len]
 test r12,r12
 jz .Lu_choose_loop
 xor r13d,r13d
.Lu_choose_previous_cluster:
 lea rdi,[rip+.Lu_query]
 mov rsi,r12
 mov rdx,r13
 call ui_next_grapheme
 cmp rax,r12
 jae .Lu_choose_erase_cluster
 cmp rax,r13
 jbe .Lu_choose_erase_cluster
 mov r13,rax
 jmp .Lu_choose_previous_cluster
.Lu_choose_erase_cluster:
 mov [rip+.Lu_query_len],r13
 lea rdx,[rip+.Lu_query]
 mov byte ptr [rdx+r13],0
.Lu_choose_refilter:
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_choose_refilter_mode_ready
 cmp qword ptr [rip+.Lu_query_len],0
 jne .Lu_choose_refilter_mode_ready
 mov qword ptr [rip+.Lu_resume_search_active],0
.Lu_choose_refilter_mode_ready:
 mov qword ptr [rip+.Lu_filtered_selection],0
 mov qword ptr [rip+.Lu_preview_last],-1
 call .Lu_choose_filter
 jmp .Lu_choose_loop
.Lu_choose_accept:
 cmp qword ptr [rip+.Lu_filtered_count],0
 jne .Lu_choose_accept_item
 cmp qword ptr [rip+.Lu_prompt_mode],0
 je .Lu_choose_loop
 xor ebx,ebx
 jmp .Lu_choose_done
.Lu_choose_accept_item:
 mov rbx,[rip+.Lu_choose_selection]
 jmp .Lu_choose_done
.Lu_choose_invalid:
 mov rbx,-1
.Lu_choose_done:
 mov qword ptr [rip+.Lu_choose],0
 call .Lu_render
 mov rax,rbx
 pop r13
 pop r12
 pop rbx
 ret
.Lu_choose_mouse_event:
 cmp qword ptr [rip+.Lu_read_preview_active],0
 jne .Lu_choose_loop
 cmp qword ptr [rip+.Lu_choice_layout],5
 je .Lu_choose_agents_mouse
 cmp qword ptr [rip+.Lu_choice_layout],6
 je .Lu_choose_agents_mouse
 mov rax,[rip+.Lu_dialog_button]
 test eax,128|64
 jnz .Lu_choose_loop
 and eax,3
 cmp eax,0
 je .Lu_choose_mouse_left
 cmp eax,3
 jne .Lu_choose_loop
 cmp qword ptr [rip+.Lu_dialog_release],0
 je .Lu_choose_loop
.Lu_choose_mouse_left:
 mov rax,[rip+.Lu_dialog_x]
 cmp rax,5
 jb .Lu_choose_loop
 mov rdx,[rip+.Lu_columns]
 sub rdx,3
 cmp rax,rdx
 jae .Lu_choose_loop
 mov rax,[rip+.Lu_dialog_y]
 sub rax,[rip+.Lu_box_list_top]
 js .Lu_choose_loop
 xor edx,edx
 mov ecx,2
 cmp qword ptr [rip+.Lu_box_theme],0
 je .Lu_choose_mouse_stride
 mov ecx,1
.Lu_choose_mouse_stride:
 div rcx
 cmp rax,[rip+.Lu_box_visible_rows]
 jae .Lu_choose_loop
 add rax,[rip+.Lu_box_visible_start]
 cmp rax,[rip+.Lu_filtered_count]
 jae .Lu_choose_loop
 mov [rip+.Lu_filtered_selection],rax
 lea rdx,[rip+.Lu_filtered]
 mov rax,[rdx+rax*8]
 mov [rip+.Lu_choose_selection],rax
 cmp qword ptr [rip+.Lu_dialog_release],0
 jne .Lu_choose_accept
 jmp .Lu_choose_loop
.Lu_choose_agents_mouse:
 mov rax,[rip+.Lu_dialog_button]
 test eax,192
 jnz .Lu_choose_loop
 and eax,3
 test eax,eax
 jnz .Lu_choose_loop
 mov rcx,[rip+.Lu_agent_hit_count]
 xor edx,edx
.Lu_choose_agents_hit:
 cmp rdx,rcx
 jae .Lu_choose_loop
 lea r8,[rip+.Lu_agent_hit_rows]
 cmp rdx,256
 jae .Lu_choose_loop
 mov rax,[rip+.Lu_dialog_y]
 cmp rax,[r8+rdx*8]
 je .Lu_choose_agents_found
 inc rdx
 jmp .Lu_choose_agents_hit
.Lu_choose_agents_found:
 lea r8,[rip+.Lu_agent_hit_indices]
 mov rdx,[r8+rdx*8]
 mov [rip+.Lu_filtered_selection],rdx
 lea r8,[rip+.Lu_filtered]
 mov rax,[r8+rdx*8]
 mov [rip+.Lu_choose_selection],rax
 cmp qword ptr [rip+.Lu_dialog_release],0
 jne .Lu_choose_accept
 jmp .Lu_choose_loop
.Lu_manager_tab_next:
 mov ebx,1
 jmp .Lu_manager_result
.Lu_manager_tab_previous:
 mov ebx,2
 jmp .Lu_manager_result
.Lu_manager_toggle:
 mov ebx,3
 jmp .Lu_manager_result
.Lu_manager_favorite:
 mov ebx,4
.Lu_manager_result:
 shl rbx,32
 mov eax,dword ptr [rip+.Lu_choose_selection]
 or rbx,rax
 jmp .Lu_choose_done
.Lu_choose_view:
 push rbx
 push r12
 push r13
 push r14
 push r15
 call .Lu_choose_box_geometry
 xor ebx,ebx
.Lu_box_row:
 mov rdi,[rip+.Lu_box_top]
 add rdi,rbx
 mov esi,3
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 test rbx,rbx
 jz .Lu_box_top_row
 mov rax,[rip+.Lu_box_height]
 dec rax
 cmp rbx,rax
 je .Lu_box_bottom_row
 lea rdi,[rip+.Lu_side]
 call .Lu_z
 lea rdi,[rip+.Lu_space]
 mov rsi,[rip+.Lu_columns]
 sub rsi,6
 call .Lu_repeat
 lea rdi,[rip+.Lu_side]
 call .Lu_z
 jmp .Lu_box_next
.Lu_box_top_row:
 lea rdi,[rip+.Lu_round_tl]
 cmp qword ptr [rip+.Lu_choice_layout],4
 je .Lu_box_square_tl
 cmp qword ptr [rip+.Lu_choice_layout],5
 je .Lu_box_square_tl
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_top_corner
.Lu_box_square_tl:
 lea rdi,[rip+.Lu_tl]
.Lu_box_top_corner:
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 sub rsi,6
 call .Lu_repeat
 lea rdi,[rip+.Lu_round_tr]
 cmp qword ptr [rip+.Lu_choice_layout],4
 je .Lu_box_square_tr
 cmp qword ptr [rip+.Lu_choice_layout],5
 je .Lu_box_square_tr
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_top_right
.Lu_box_square_tr:
 lea rdi,[rip+.Lu_tr]
.Lu_box_top_right:
 call .Lu_z
 jmp .Lu_box_next
.Lu_box_bottom_row:
 lea rdi,[rip+.Lu_round_bl]
 cmp qword ptr [rip+.Lu_choice_layout],4
 je .Lu_box_square_bl
 cmp qword ptr [rip+.Lu_choice_layout],5
 je .Lu_box_square_bl
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_bottom_corner
.Lu_box_square_bl:
 lea rdi,[rip+.Lu_bl]
.Lu_box_bottom_corner:
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 sub rsi,6
 call .Lu_repeat
 lea rdi,[rip+.Lu_round_br]
 cmp qword ptr [rip+.Lu_choice_layout],4
 je .Lu_box_square_br
 cmp qword ptr [rip+.Lu_choice_layout],5
 je .Lu_box_square_br
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_bottom_right
.Lu_box_square_br:
 lea rdi,[rip+.Lu_br]
.Lu_box_bottom_right:
 call .Lu_z
.Lu_box_next:
 inc rbx
 cmp rbx,[rip+.Lu_box_height]
 jb .Lu_box_row
 cmp qword ptr [rip+.Lu_read_preview_active],0
 je .Lu_box_not_session_preview
 call .Lu_session_preview_view
 jmp .Lu_box_view_finish
.Lu_box_not_session_preview:
 cmp qword ptr [rip+.Lu_choice_layout],4
 jne .Lu_box_not_help
 call .Lu_help_view
 jmp .Lu_box_view_finish
.Lu_box_not_help:
 cmp qword ptr [rip+.Lu_scope_focus],0
 je .Lu_box_theme_focus
 call .Lu_scope_view
 jmp .Lu_box_view_finish
.Lu_box_theme_focus:
 cmp qword ptr [rip+.Lu_choice_tabs_count],0
 je .Lu_box_regular_title
 call .Lu_manager_tabs_view
 jmp .Lu_box_query_after_title
.Lu_box_regular_title:
 mov rdi,[rip+.Lu_box_top]
 add rdi,2
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_title_row
 dec rdi
.Lu_box_title_row:
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 mov rdi,[rip+.Lu_choose_title]
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 call .Lu_reset_color
.Lu_box_query_after_title:
 cmp qword ptr [rip+.Lu_choice_layout],5
 jne .Lu_box_not_agents_list
 call .Lu_agents_list_view
 jmp .Lu_box_regular_footer
.Lu_box_not_agents_list:
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_not_extensions_list
 call .Lu_extensions_list_view
 jmp .Lu_box_regular_footer
.Lu_box_not_extensions_list:
 mov rdi,[rip+.Lu_box_top]
 add rdi,3
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_query_row
 dec rdi
.Lu_box_query_row:
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_generic_query
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_box_resume_active_search
 cmp qword ptr [rip+.Lu_query_len],0
 jne .Lu_box_resume_filter
 lea rdi,[rip+.Lu_resume_search_hint]
 call .Lu_z
 jmp .Lu_box_no_query
.Lu_box_resume_filter:
 lea rdi,[rip+.Lu_resume_filter_label]
 jmp .Lu_box_query_label
.Lu_box_resume_active_search:
 lea rdi,[rip+.Lu_resume_search_label]
 jmp .Lu_box_query_label
.Lu_box_generic_query:
 cmp qword ptr [rip+.Lu_query_len],0
 je .Lu_box_no_query
 lea rdi,[rip+.Lu_choose_query_label]
.Lu_box_query_label:
 call .Lu_z
 cmp qword ptr [rip+.Lu_prompt_secret],0
 je .Lu_box_visible_query
 lea rdi,[rip+.Lu_password_char]
 mov rsi,[rip+.Lu_query_len]
 mov rax,[rip+.Lu_columns]
 sub rax,18
 cmp rsi,rax
 cmova rsi,rax
 call .Lu_repeat
 jmp .Lu_box_no_query
.Lu_box_visible_query:
 lea rdi,[rip+.Lu_query]
 mov rsi,[rip+.Lu_query_len]
 lea rdx,[rip+.Lu_clean]
 mov ecx,4194303
 call ui_sanitize
 test rax,rax
 js .Lu_box_no_query
 lea rdi,[rip+.Lu_clean]
 mov byte ptr [rdi+rax],0
 mov rsi,rax
 call ui_text_width
 mov rsi,[rip+.Lu_columns]
 sub rsi,18
 cmp rax,rsi
 cmovbe rsi,rax
 lea rdi,[rip+.Lu_clean]
 call .Lu_field
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_no_query
 cmp qword ptr [rip+.Lu_resume_search_active],0
 je .Lu_box_no_query
 lea rdi,[rip+.Lu_resume_search_cursor]
 call .Lu_z
 .Lu_box_no_query:
 cmp qword ptr [rip+.Lu_prompt_mode],0
 jne .Lu_box_controls
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_resume_rule_done
 mov rdi,[rip+.Lu_box_top]
 add rdi,3
 mov esi,4
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 sub rsi,6
 call .Lu_repeat
.Lu_box_resume_rule_done:
 mov r12,[rip+.Lu_box_height]
 sub r12,10
 cmp qword ptr [rip+.Lu_box_theme],0
 jne .Lu_box_visible_count
 shr r12,1
.Lu_box_visible_count:
 cmp r12,1
 jge .Lu_box_list_height
 mov r12,1
.Lu_box_list_height:
 mov [rip+.Lu_box_visible_rows],r12
 cmp qword ptr [rip+.Lu_filtered_count],0
 jne .Lu_box_has_items
 mov rdi,[rip+.Lu_box_top]
 add rdi,5
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_no_matches]
 cmp qword ptr [rip+.Lu_query_len],0
 jne .Lu_box_empty_label
 mov rdi,[rip+.Lu_choice_empty]
 test rdi,rdi
 jnz .Lu_box_empty_label
 lea rdi,[rip+.Lu_no_entries]
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_empty_label
 lea rdi,[rip+.Lu_no_sessions]
.Lu_box_empty_label:
 mov r15,rdi
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_empty_plain
 call qx_strlen
 mov rdi,r15
 mov rsi,rax
 call ui_text_width
 mov rsi,[rip+.Lu_columns]
 sub rsi,rax
 shr rsi,1
 inc rsi
 mov rdi,[rip+.Lu_box_top]
 add rdi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 mov rdi,r15
 call .Lu_z
 jmp .Lu_box_controls
.Lu_box_empty_plain:
 mov rdi,r15
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 jmp .Lu_box_controls
.Lu_box_has_items:
 mov r13,[rip+.Lu_filtered_selection]
 sub r13,r12
 inc r13
 jns .Lu_box_list_start
 xor r13d,r13d
.Lu_box_list_start:
 mov r14,[rip+.Lu_box_top]
 add r14,4
 mov [rip+.Lu_box_list_top],r14
 mov [rip+.Lu_box_visible_start],r13
 xor ebx,ebx
.Lu_box_item:
 cmp rbx,r12
 jae .Lu_box_metadata
 cmp r13,[rip+.Lu_filtered_count]
 jae .Lu_box_metadata
 mov rdi,r14
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_item_selection_color
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_box_item_color
.Lu_box_item_selection_color:
 cmp r13,[rip+.Lu_filtered_selection]
 jne .Lu_box_item_color
 lea rdi,[rip+.Lu_accent]
.Lu_box_item_color:
 call .Lu_z
 lea rdi,[rip+.Lu_nomarker]
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_item_selection_marker
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_box_item_marker
.Lu_box_item_selection_marker:
 cmp r13,[rip+.Lu_filtered_selection]
 jne .Lu_box_item_marker
 lea rdi,[rip+.Lu_marker]
.Lu_box_item_marker:
 cmp qword ptr [rip+.Lu_multi_enabled],0
 je .Lu_box_item_marker_ready
 lea rdi,[rip+.Lu_unchecked]
 mov rax,[rip+.Lu_multi_mask]
 lea rdx,[rip+.Lu_filtered]
 mov rcx,[rdx+r13*8]
 bt rax,rcx
 jnc .Lu_box_multi_marker
 lea rdi,[rip+.Lu_checked]
.Lu_box_multi_marker:
 call .Lu_z
 lea rax,[rip+.Lu_filtered]
 mov r15,[rax+r13*8]
 jmp .Lu_box_item_number_ready
.Lu_box_item_marker_ready:
 call .Lu_z
 lea rax,[rip+.Lu_filtered]
 mov r15,[rax+r13*8]
 cmp qword ptr [rip+.Lu_choice_layout],3
 je .Lu_box_item_number_ready
 lea rdi,[rip+.Lu_bytes]
 lea rsi,[r15+1]
 call qx_uint
 lea rdi,[rip+.Lu_bytes]
 mov rsi,rax
 call .Lu_put
 lea rdi,[rip+.Lu_number_separator]
 call .Lu_z
.Lu_box_item_number_ready:
 imul r15,r15,24
 add r15,[rip+.Lu_choose_items]
 mov rdi,[r15]
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,16
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_item_width_ready
 add rsi,6
.Lu_box_item_width_ready:
 call .Lu_field
 cmp qword ptr [rip+.Lu_box_theme],0
 jne .Lu_box_item_next
 mov rdi,[r15+8]
 test rdi,rdi
 jz .Lu_box_item_next
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[r14+1]
 mov esi,10
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_item_description_column
 mov esi,7
.Lu_box_item_description_column:
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,20
 call .Lu_field
 inc r14
.Lu_box_item_next:
 inc r14
 inc r13
 inc rbx
 jmp .Lu_box_item
.Lu_box_metadata:
 mov rax,[rip+.Lu_choice_metadata]
 test rax,rax
 jz .Lu_box_controls
 mov r12,rax
 mov r13,[rip+.Lu_box_top]
 add r13,[rip+.Lu_box_height]
 sub r13,9
 mov rdi,r13
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_repeat
 inc r13
 xor ebx,ebx
.Lu_box_metadata_line:
 cmp rbx,4
 jae .Lu_box_controls
 cmp byte ptr [r12],0
 je .Lu_box_controls
 mov r14,r12
 xor r15d,r15d
.Lu_box_metadata_scan:
 cmp byte ptr [r12+r15],0
 je .Lu_box_metadata_copy
 cmp byte ptr [r12+r15],10
 je .Lu_box_metadata_copy
 inc r15
 jmp .Lu_box_metadata_scan
.Lu_box_metadata_copy:
 mov rdi,r12
 mov rsi,r15
 lea rdx,[rip+.Lu_clean]
 mov ecx,4095
 call ui_sanitize
 test rax,rax
 js .Lu_box_controls
 lea rdi,[rip+.Lu_clean]
 mov byte ptr [rdi+rax],0
 mov rdi,r13
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 add r12,r15
 cmp byte ptr [r12],10
 jne .Lu_box_metadata_not_nl
 inc r12
.Lu_box_metadata_not_nl:
 inc r13
 inc rbx
 jmp .Lu_box_metadata_line
.Lu_box_controls:
 cmp qword ptr [rip+.Lu_box_theme],0
 je .Lu_box_footer
 call .Lu_theme_preview
.Lu_box_footer:
 cmp qword ptr [rip+.Lu_choice_layout],3
 jne .Lu_box_regular_footer
 cmp qword ptr [rip+.Lu_reader_error],0
 je .Lu_resume_reader_status_done
 mov rdi,[rip+.Lu_box_top]
 add rdi,[rip+.Lu_box_height]
 sub rdi,4
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_error]
 call .Lu_z
 lea rdi,[rip+.Lu_preview_error_text]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
.Lu_resume_reader_status_done:
 mov rdi,[rip+.Lu_box_top]
 add rdi,[rip+.Lu_box_height]
 sub rdi,3
 mov esi,4
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 mov rsi,[rip+.Lu_columns]
 sub rsi,6
 call .Lu_repeat
 mov rdi,[rip+.Lu_box_top]
 add rdi,[rip+.Lu_box_height]
 sub rdi,2
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_resume_controls]
 cmp qword ptr [rip+.Lu_resume_search_active],0
 je .Lu_resume_list_controls
 lea rdi,[rip+.Lu_resume_search_controls]
 jmp .Lu_resume_controls_selected
.Lu_resume_list_controls:
 cmp qword ptr [rip+.Lu_choice_reader],0
 je .Lu_resume_controls_selected
 cmp qword ptr [rip+.Lu_filtered_count],0
 je .Lu_resume_controls_selected
 lea rdi,[rip+.Lu_resume_preview_controls]
.Lu_resume_controls_selected:
 cmp qword ptr [rip+.Lu_multi_enabled],0
 je .Lu_resume_controls_render
 lea rdi,[rip+.Lu_multi_controls]
.Lu_resume_controls_render:
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 jmp .Lu_box_view_finish
.Lu_box_regular_footer:
 mov rdi,[rip+.Lu_box_top]
 add rdi,[rip+.Lu_box_height]
 sub rdi,3
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_footer_row_ready
 inc rdi
.Lu_box_footer_row_ready:
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_box_help]
 cmp qword ptr [rip+.Lu_choice_footer],0
 je .Lu_box_custom_footer_ready
 mov rdi,[rip+.Lu_choice_footer]
.Lu_box_custom_footer_ready:
 cmp qword ptr [rip+.Lu_prompt_mode],0
 je .Lu_box_prompt_footer_ready
 lea rdi,[rip+.Lu_prompt_controls]
.Lu_box_prompt_footer_ready:
 cmp qword ptr [rip+.Lu_box_theme],0
 je .Lu_box_help_selected
 lea rdi,[rip+.Lu_theme_help]
.Lu_box_help_selected:
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
.Lu_box_view_finish:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Lu_csi: .asciz "\033["
.Lu_semicolon: .asciz ";"
.Lu_H: .asciz "H"
.Lu_cursor_on: .asciz "\033[?25h"
.Lu_cursor_off: .asciz "\033[?25l"
.Lu_spinners: .asciz "⠋"
.asciz "⠙"
.asciz "⠹"
.asciz "⠸"
.asciz "⠼"
.asciz "⠴"
.asciz "⠦"
.asciz "⠧"
.Lu_scrolling: .asciz "Scrollback · PgUp/PgDn · Ctrl+End to follow"
.Lu_always: .asciz "2. Allow this action for this session"
.Lu_deny3: .asciz "3. Deny"
.section .bss
.Lu_dialog_escape: .skip 8
.section .note.GNU-stack,"",@progbits

.section .rodata
.Lu_theme_0_0: .asciz "\033[38;2;205;214;244m"
.Lu_theme_0_1: .asciz "\033[38;2;108;112;134m"
.Lu_theme_0_2: .asciz "\033[38;2;203;166;247m"
.Lu_theme_0_3: .asciz "\033[38;2;166;227;161m"
.Lu_theme_0_4: .asciz "\033[38;2;243;139;168m"
.Lu_theme_0_5: .asciz "\033[38;2;249;226;175m"
.Lu_theme_0: .quad .Lu_theme_0_0,.Lu_theme_0_1,.Lu_theme_0_2,.Lu_theme_0_3,.Lu_theme_0_4,.Lu_theme_0_5,.Lu_theme_0_6
.Lu_theme_1_0: .asciz "\033[38;2;163;175;183m"
.Lu_theme_1_1: .asciz "\033[38;2;98;114;164m"
.Lu_theme_1_2: .asciz "\033[38;2;255;121;198m"
.Lu_theme_1_3: .asciz "\033[38;2;80;250;123m"
.Lu_theme_1_4: .asciz "\033[38;2;255;85;85m"
.Lu_theme_1_5: .asciz "\033[38;2;255;247;131m"
.Lu_theme_1: .quad .Lu_theme_1_0,.Lu_theme_1_1,.Lu_theme_1_2,.Lu_theme_1_3,.Lu_theme_1_4,.Lu_theme_1_5,.Lu_theme_1_6
.Lu_theme_2_0: .asciz "\033[38;2;192;196;200m"
.Lu_theme_2_1: .asciz "\033[38;2;106;115;125m"
.Lu_theme_2_2: .asciz "\033[38;2;179;146;240m"
.Lu_theme_2_3: .asciz "\033[38;2;133;232;157m"
.Lu_theme_2_4: .asciz "\033[38;2;249;117;131m"
.Lu_theme_2_5: .asciz "\033[38;2;255;171;112m"
.Lu_theme_2: .quad .Lu_theme_2_0,.Lu_theme_2_1,.Lu_theme_2_2,.Lu_theme_2_3,.Lu_theme_2_4,.Lu_theme_2_5,.Lu_theme_2_6
.Lu_theme_3_0: .asciz "\033[38;2;36;41;46m"
.Lu_theme_3_1: .asciz "\033[38;2;153;153;136m"
.Lu_theme_3_2: .asciz "\033[38;2;153;0;0m"
.Lu_theme_3_3: .asciz "\033[38;2;0;128;128m"
.Lu_theme_3_4: .asciz "\033[38;2;221;17;68m"
.Lu_theme_3_5: .asciz "\033[38;2;153;0;115m"
.Lu_theme_3: .quad .Lu_theme_3_0,.Lu_theme_3_1,.Lu_theme_3_2,.Lu_theme_3_3,.Lu_theme_3_4,.Lu_theme_3_5,.Lu_theme_3_6
.Lu_themes: .quad .Lu_theme_0,.Lu_theme_1,.Lu_theme_2,.Lu_theme_3
.Lu_color_slots: .quad .Lu_primary,.Lu_muted,.Lu_accent,.Lu_success,.Lu_error,.Lu_warning,.Lu_link
.section .bss
.Lu_theme: .skip 8
.Lu_primary: .skip 32
.Lu_muted: .skip 32
.Lu_accent: .skip 32
.Lu_success: .skip 32
.Lu_error: .skip 32
.Lu_warning: .skip 32
.section .text
.globl ui_get_approval_mode,ui_get_theme

.section .rodata
.Lu_mode_default: .asciz "⏸ Ask permissions (shift + tab to cycle)"
.Lu_mode_edit: .asciz "auto-accept edits (shift + tab to cycle)"
.Lu_mode_plan: .asciz "plan mode (shift + tab to cycle)"
.Lu_mode_yolo: .asciz "YOLO mode (shift + tab to cycle)"

.section .bss
.Lu_preview_callback: .skip 8
.Lu_preview_last: .skip 8
.section .text
.globl ui_set_choice_preview,ui_message
ui_set_choice_preview:
 mov [rip+.Lu_preview_callback],rdi
 ret
ui_message:
 push rbx
 mov rdx,rsi
 mov rsi,rdi
 mov edi,3
 call .Lu_entry
 call .Lu_render
 pop rbx
 ret

.section .bss
.Lu_editor_scroll: .skip 8

.section .bss
.Lu_menu_dismiss: .skip 8
.section .rodata
.Lu_inverse: .asciz "\033[7m"
.Lu_noinverse: .asciz "\033[27m"
.Lu_search_label: .asciz "reverse-i-search: "

.section .bss
.Lu_flow_overflow: .skip 8
.section .rodata
.Lu_display_limit: .asciz "  Display limit reached; newer text could not be rendered."

.section .bss
.Lu_rx: .skip 256
.Lu_rxlen: .skip 8
.Lu_rxpos: .skip 8
.Lu_qcount: .skip 8
.Lu_qhead: .skip 8
.Lu_qlengths: .skip 64
.Lu_exit_pending: .skip 8
.Lu_hint_kind: .skip 8
.Lu_hint_deadline: .skip 8
.Lu_details: .skip 8
.section .rodata
.Lu_queue_full_text: .asciz "Message queue is full (8); draft kept."
.Lu_hint_c: .asciz "Press Ctrl+C again to exit."
.Lu_hint_d: .asciz "Press Ctrl+D again to exit."
.Lu_hint_escape: .asciz "Press Esc again to clear."
.Lu_retry_command: .asciz "/retry"

.section .text
.Lu_queue_view:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r13,[rip+.Lu_qcount]
 test r13,r13
 jz .Lu_queue_view_done
 cmp r13,3
 jbe .Lu_queue_preview_count
 mov r13,3
.Lu_queue_preview_count:
 mov r12,[rip+.Lu_composer_top]
 dec r12
 sub r12,r13
 cmp qword ptr [rip+.Lu_qcount],3
 jbe .Lu_queue_preview_first
 dec r12
.Lu_queue_preview_first:
 xor ebx,ebx
.Lu_queue_preview_row:
 cmp rbx,r13
 jae .Lu_queue_preview_more
 mov rdi,r12
 mov esi,1
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_queue_marker]
 call .Lu_z
 mov r14,[rip+.Lu_qhead]
 add r14,rbx
 and r14d,7
 lea rdx,[rip+.Lu_qlengths]
 mov r15,[rdx+r14*8]
 cmp r15,255
 jbe .Lu_queue_preview_size
 mov r15,255
.Lu_queue_preview_size:
 shl r14,16
 lea rsi,[rip+.Lu_queue]
 add rsi,r14
 lea rdi,[rip+.Lu_bytes]
 mov rcx,r15
 rep movsb
 mov byte ptr [rdi],0
 lea rdi,[rip+.Lu_bytes]
 mov rsi,[rip+.Lu_columns]
 sub rsi,4
 call .Lu_field
 inc r12
 inc rbx
 jmp .Lu_queue_preview_row
.Lu_queue_preview_more:
 cmp qword ptr [rip+.Lu_qcount],3
 jbe .Lu_queue_view_done
 mov rdi,r12
 mov esi,1
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_queue_more]
 call .Lu_z
 lea rdi,[rip+.Lu_bytes]
 mov rsi,[rip+.Lu_qcount]
 sub rsi,3
 call qx_uint
 lea rdi,[rip+.Lu_bytes]
 mov rsi,rax
 call .Lu_put
 lea rdi,[rip+.Lu_queue_remaining]
 call .Lu_z
.Lu_queue_view_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Lu_queue_marker: .asciz "  › "
.Lu_queue_more: .asciz "    +"
.Lu_queue_remaining: .asciz " more queued"

.section .rodata
.Lu_more_output: .ascii "… more output (Ctrl+O to expand)"
.set .Lu_more_output_len,.-.Lu_more_output
.section .text
.globl ui_restore_entry
ui_restore_entry:
 push rbx
 push r12
 push r13
 mov rbx,rdi
 mov r12,rsi
 mov r13,rdx
 call .Lu_entry
 cmp rbx,1
 jne .Lu_restore_entry_done
 lea rdi,[rip+.Lu_context]
 mov rsi,r12
 mov rdx,r13
 call input_history_add
.Lu_restore_entry_done:
 pop r13
 pop r12
 pop rbx
 ret

.section .text
.Lu_mode_color:
 lea rdi,[rip+.Lu_accent]
 cmp qword ptr [rip+.Lu_mode],1
 jne .Lu_mode_color_not_edit
 lea rdi,[rip+.Lu_warning]
.Lu_mode_color_not_edit:
 cmp qword ptr [rip+.Lu_mode],3
 jne .Lu_mode_color_done
 lea rdi,[rip+.Lu_error]
.Lu_mode_color_done:
 ret
.Lu_indicator_color:
 lea rdi,[rip+.Lu_muted]
 cmp qword ptr [rip+.Lu_busy],0
 jne .Lu_indicator_done
 cmp qword ptr [rip+.Lu_mode],1
 jne .Lu_indicator_not_edit
 lea rdi,[rip+.Lu_warning]
.Lu_indicator_not_edit:
 cmp qword ptr [rip+.Lu_mode],2
 jne .Lu_indicator_not_plan
 lea rdi,[rip+.Lu_success]
.Lu_indicator_not_plan:
 cmp qword ptr [rip+.Lu_mode],3
 jne .Lu_indicator_done
 lea rdi,[rip+.Lu_error]
.Lu_indicator_done:
 ret
.section .rodata
.Lu_yolo_prefix: .asciz "* "

.section .bss
.Lu_flow_dirty: .skip 8

.section .bss
.Lu_composer_top: .skip 8
.section .rodata
.Lu_workspace_arrow: .asciz "➜ "
.Lu_workspace_dot: .asciz " · "
.section .text
.Lu_workspace_footer:
 push rbx
 push r12
 sub rsp,40
 movdqu xmm0,xmmword ptr [rip+.Lu_builder]
 movdqu [rsp],xmm0
 mov rax,[rip+.Lu_builder+16]
 mov [rsp+16],rax
 lea rax,[rip+.Lu_clean]
 mov [rip+.Lu_builder],rax
 mov qword ptr [rip+.Lu_builder+8],4194303
 mov qword ptr [rip+.Lu_builder+16],0
 lea rdi,[rip+.Lu_workspace_arrow]
 call .Lu_z
 lea rbx,[rip+.Lu_cwd]
 mov r12,rbx
.Lu_basename_next:
 mov al,[rbx]
 test al,al
 jz .Lu_basename_done
 cmp al,47
 jne .Lu_basename_continue
 cmp byte ptr [rbx+1],0
 je .Lu_basename_continue
 lea r12,[rbx+1]
.Lu_basename_continue:
 inc rbx
 jmp .Lu_basename_next
.Lu_basename_done:
 mov rdi,r12
 call .Lu_z
 lea rdi,[rip+.Lu_workspace_dot]
 call .Lu_z
 lea rdi,[rip+.Lu_model]
 call .Lu_z
 mov rax,[rip+.Lu_builder+16]
 lea rdx,[rip+.Lu_clean]
 mov byte ptr [rdx+rax],0
 movdqu xmm0,[rsp]
 movdqu xmmword ptr [rip+.Lu_builder],xmm0
 mov rax,[rsp+16]
 mov [rip+.Lu_builder+16],rax
 lea rdi,[rip+.Lu_accent]
 call .Lu_z
 lea rdi,[rip+.Lu_margin]
 call .Lu_z
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,4
 call .Lu_field
 add rsp,40
 pop r12
 pop rbx
 ret

.section .bss
.Lu_view_start: .skip 8
.Lu_view_height: .skip 8
.section .rodata
.Lu_scroll_thumb: .asciz "█"
.section .text
.Lu_scrollbar:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,[rip+.Lu_view_height]
 mov r13,[rip+.Lu_linecount]
 cmp r13,r12
 jbe .Lu_scrollbar_done
 mov rax,[rip+.Lu_view_start]
 imul rax,r12
 xor edx,edx
 div r13
 mov r14,rax
 mov rax,r12
 imul rax,r12
 xor edx,edx
 div r13
 test rax,rax
 jnz .Lu_scrollbar_size
 inc rax
.Lu_scrollbar_size:
 lea r15,[r14+rax]
 cmp qword ptr [rip+.Lu_scroll],0
 jne .Lu_scrollbar_anchor_ready
 mov r15,r12
 mov r14,r12
 sub r14,rax
.Lu_scrollbar_anchor_ready:
 xor ebx,ebx
.Lu_scrollbar_row:
 cmp rbx,r12
 jae .Lu_scrollbar_done
 lea rdi,[rbx+1]
 mov rsi,[rip+.Lu_columns]
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_side]
 cmp rbx,r14
 jb .Lu_scrollbar_put
 cmp rbx,r15
 jae .Lu_scrollbar_put
 lea rdi,[rip+.Lu_scroll_thumb]
.Lu_scrollbar_put:
 call .Lu_z
 inc rbx
 jmp .Lu_scrollbar_row
.Lu_scrollbar_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .bss
.Lu_editor_callback: .skip 8
.Lu_editor_output: .skip 65536
.Lu_suspended: .skip 8
.section .text
.globl ui_set_editor_callback,ui_suspend,ui_resume
ui_set_editor_callback:
 mov [rip+.Lu_editor_callback],rdi
 ret
ui_suspend:
 push rbx
 cmp qword ptr [rip+.Lu_active],0
 je .Lu_suspend_done
 cmp qword ptr [rip+.Lu_suspended],0
 jne .Lu_suspend_done
 mov edi,1
 lea rsi,[rip+.Lu_restore]
 mov edx,OFFSET FLAT:.Lu_restore_len
 call qx_write_all
 call term_restore
 mov qword ptr [rip+.Lu_suspended],1
.Lu_suspend_done:
 pop rbx
 ret
ui_resume:
 push rbx
 cmp qword ptr [rip+.Lu_suspended],0
 je .Lu_resume_done
 call term_init
 test rax,rax
 jne .Lu_resume_done
 mov edi,1
 lea rsi,[rip+.Lu_start]
 mov edx,OFFSET FLAT:.Lu_start_len
 call qx_write_all
 mov qword ptr [rip+.Lu_suspended],0
 mov qword ptr [rip+.Lu_dirty],1
 call .Lu_render
.Lu_resume_done:
 pop rbx
 ret
.Lu_external_editor:
 push rbx
 push r12
 push r13
 mov rbx,[rip+.Lu_editor_callback]
 test rbx,rbx
 jz .Lu_external_done
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_snapshot]
 call input_snapshot
 mov r12,[rip+.Lu_snapshot+IS_TEXT]
 mov r13,[rip+.Lu_snapshot+IS_LENGTH]
 call ui_suspend
 mov rdi,r12
 mov rsi,r13
 lea rdx,[rip+.Lu_editor_output]
 mov ecx,65536
 call rbx
 mov r12,rax
 # Re-enter native mode on success and failure before touching the editor model.
 call ui_resume
 test r12,r12
 js .Lu_external_done
 cmp r12,65535
 ja .Lu_external_done
 lea rdi,[rip+.Lu_context]
 xor esi,esi
 mov rdx,r13
 lea rcx,[rip+.Lu_editor_output]
 mov r8,r12
 call input_replace
 mov qword ptr [rip+.Lu_dirty],1
.Lu_external_done:
 pop r13
 pop r12
 pop rbx
 ret

.section .bss
.Lu_query: .skip 512
.Lu_query_len: .skip 8
.Lu_filtered: .skip 2048
.Lu_filtered_count: .skip 8
.Lu_filtered_selection: .skip 8
.section .rodata
.Lu_choose_query_label: .asciz "  Search: "
.section .text
# Stable ASCII case-insensitive subsequence matching; UTF8 bytes match literally.
.Lu_choose_filter:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov qword ptr [rip+.Lu_filtered_count],0
 xor ebx,ebx
.Lu_filter_item:
 cmp rbx,[rip+.Lu_choose_count]
 jae .Lu_filter_done
 imul rax,rbx,24
 add rax,[rip+.Lu_choose_items]
 mov r12,[rax]
 xor r13d,r13d
 xor r14d,r14d
.Lu_filter_query:
 cmp r13,[rip+.Lu_query_len]
 jae .Lu_filter_accept
 lea rdx,[rip+.Lu_query]
 movzx r15d,byte ptr [rdx+r13]
 cmp r15d,65
 jb .Lu_filter_scan
 cmp r15d,90
 ja .Lu_filter_scan
 add r15d,32
.Lu_filter_scan:
 movzx eax,byte ptr [r12+r14]
 test eax,eax
 jz .Lu_filter_reject
 inc r14
 cmp eax,65
 jb .Lu_filter_compare
 cmp eax,90
 ja .Lu_filter_compare
 add eax,32
.Lu_filter_compare:
 cmp eax,r15d
 jne .Lu_filter_scan
 inc r13
 jmp .Lu_filter_query
.Lu_filter_accept:
 mov rax,[rip+.Lu_filtered_count]
 lea rdx,[rip+.Lu_filtered]
 mov [rdx+rax*8],rbx
 inc qword ptr [rip+.Lu_filtered_count]
.Lu_filter_reject:
 inc rbx
 jmp .Lu_filter_item
.Lu_filter_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.Lu_no_matches: .asciz "  No matching entries. Change the search or press Esc."
.section .text
.globl ui_last_assistant,ui_copy_text
# Borrowed raw transcript span, valid until the next arena mutation.
ui_last_assistant:
 mov rcx,[rip+.Lu_count]
 lea r8,[rip+.Lu_records]
.Lu_last_assistant_find:
 test rcx,rcx
 jz .Lu_last_assistant_none
 dec rcx
 mov rax,rcx
 shl rax,5
 cmp qword ptr [r8+rax],2
 jne .Lu_last_assistant_find
 mov rdx,[r8+rax+16]
 test rdx,rdx
 jz .Lu_last_assistant_find
 mov rax,[r8+rax+8]
 lea r8,[rip+.Lu_blocks]
 add rax,r8
 ret
.Lu_last_assistant_none:
 xor eax,eax
 xor edx,edx
 ret
# Explicit trusted clipboard action only. Payload base64 never carries controls.
ui_copy_text:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 cmp r13,1048576
 ja .Lu_clipboard_invalid
 lea r14,[rip+.Lu_clipboard_encoded]
 lea r15,[rip+.Lu_b64]
 xor ebx,ebx
 xor r8d,r8d
.Lu_clipboard_group:
 cmp rbx,r13
 jae .Lu_clipboard_write
 movzx eax,byte ptr [r12+rbx]
 shl eax,16
 xor r9d,r9d
 lea rcx,[rbx+1]
 cmp rcx,r13
 jae .Lu_clipboard_one
 movzx edx,byte ptr [r12+rcx]
 shl edx,8
 or eax,edx
 inc r9
 inc rcx
 cmp rcx,r13
 jae .Lu_clipboard_one
 movzx edx,byte ptr [r12+rcx]
 or eax,edx
 inc r9
.Lu_clipboard_one:
 mov ecx,eax
 shr ecx,18
 mov cl,[r15+rcx]
 mov [r14+r8],cl
 mov ecx,eax
 shr ecx,12
 and ecx,63
 mov cl,[r15+rcx]
 mov [r14+r8+1],cl
 mov byte ptr [r14+r8+2],61
 mov byte ptr [r14+r8+3],61
 test r9,r9
 jz .Lu_clipboard_advance
 mov ecx,eax
 shr ecx,6
 and ecx,63
 mov cl,[r15+rcx]
 mov [r14+r8+2],cl
 cmp r9,2
 jne .Lu_clipboard_advance
 and eax,63
 mov al,[r15+rax]
 mov [r14+r8+3],al
.Lu_clipboard_advance:
 add rbx,3
 add r8,4
 jmp .Lu_clipboard_group
.Lu_clipboard_write:
 mov rbx,r8
 mov edi,1
 lea rsi,[rip+.Lu_clipboard_prefix]
 mov edx,7
 call qx_write_all
 test rax,rax
 js .Lu_clipboard_done
 mov edi,1
 mov rsi,r14
 mov rdx,rbx
 call qx_write_all
 test rax,rax
 js .Lu_clipboard_done
 mov edi,1
 lea rsi,[rip+.Lu_clipboard_end]
 mov edx,1
 call qx_write_all
 test rax,rax
 js .Lu_clipboard_done
 xor eax,eax
 jmp .Lu_clipboard_done
.Lu_clipboard_invalid:
 mov rax,-22
.Lu_clipboard_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Lu_b64: .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
.Lu_clipboard_prefix: .ascii "\033]52;c;"
.Lu_clipboard_end: .byte 7
.section .bss
.Lu_path_callback: .skip 8
.Lu_path_items: .skip 3072
.Lu_completion_kind: .skip 8
.Lu_completion_start: .skip 8
.Lu_completion_end: .skip 8
.Lu_completion_text: .skip 8192
.Lu_menu_tabbed: .skip 8
.section .text
.globl ui_set_path_completer
ui_set_path_completer:
 mov [rip+.Lu_path_callback],rdi
 ret

.section .text
# UI-layer fuzzy matching, independent of actual command/backend routing.
.Lu_fuzzy_span:
 mov r8,rdi
 mov r9,rsi
 mov r10,rdx
 mov r11,rcx
 xor edi,edi
 xor esi,esi
.Lu_fuzzy_query:
 cmp rdi,r9
 jae .Lu_fuzzy_yes
 movzx edx,byte ptr [r8+rdi]
 cmp edx,65
 jb .Lu_fuzzy_scan
 cmp edx,90
 ja .Lu_fuzzy_scan
 add edx,32
.Lu_fuzzy_scan:
 cmp rsi,r11
 jae .Lu_fuzzy_no
 movzx eax,byte ptr [r10+rsi]
 inc rsi
 cmp eax,65
 jb .Lu_fuzzy_compare
 cmp eax,90
 ja .Lu_fuzzy_compare
 add eax,32
.Lu_fuzzy_compare:
 cmp eax,edx
 jne .Lu_fuzzy_scan
 inc rdi
 jmp .Lu_fuzzy_query
.Lu_fuzzy_yes:
 mov eax,1
 ret
.Lu_fuzzy_no:
 xor eax,eax
 ret
# Find a workspace reference at the active input tail; no filesystem work here.
.Lu_update_paths:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r15,[rip+.Lu_path_callback]
 test r15,r15
 jz .Lu_paths_done
 mov r12,[rip+.Lu_snapshot+IS_TEXT]
 mov r13,[rip+.Lu_snapshot+IS_CURSOR]
 cmp r13,[rip+.Lu_snapshot+IS_LENGTH]
 jne .Lu_paths_done
 xor ebx,ebx
 mov r14,-1
.Lu_paths_find_at:
 cmp rbx,r13
 jae .Lu_paths_query
 cmp byte ptr [r12+rbx],64
 jne .Lu_paths_find_next
 test rbx,rbx
 jz .Lu_paths_found
 cmp byte ptr [r12+rbx-1],32
 je .Lu_paths_found
 cmp byte ptr [r12+rbx-1],10
 jne .Lu_paths_find_next
.Lu_paths_found:
 lea r14,[rbx+1]
.Lu_paths_find_next:
 inc rbx
 jmp .Lu_paths_find_at
.Lu_paths_query:
 cmp r14,-1
 je .Lu_paths_done
 mov [rip+.Lu_completion_start],r14
 mov [rip+.Lu_completion_end],r13
 mov rbx,r14
 cmp rbx,r13
 jae .Lu_paths_callback
 cmp byte ptr [r12+rbx],34
 je .Lu_paths_quoted
.Lu_paths_check_space:
 cmp rbx,r13
 jae .Lu_paths_callback
 cmp byte ptr [r12+rbx],32
 je .Lu_paths_done
 cmp byte ptr [r12+rbx],10
 je .Lu_paths_done
 inc rbx
 jmp .Lu_paths_check_space
.Lu_paths_quoted:
 inc r14
 cmp r13,r14
 jbe .Lu_paths_callback
 cmp byte ptr [r12+r13-1],34
 jne .Lu_paths_callback
 dec r13
.Lu_paths_callback:
 lea rdi,[r12+r14]
 mov rsi,r13
 sub rsi,r14
 lea rdx,[rip+.Lu_path_items]
 mov ecx,128
 call r15
 test rax,rax
 jle .Lu_paths_done
 cmp rax,128
 ja .Lu_paths_done
 mov [rip+.Lu_menu_count],rax
 mov qword ptr [rip+.Lu_completion_kind],1
 xor ebx,ebx
.Lu_paths_matches:
 cmp rbx,[rip+.Lu_menu_count]
 jae .Lu_paths_done
 imul rax,rbx,24
 lea rdx,[rip+.Lu_path_items]
 mov r12,[rdx+rax+16]
 mov rdi,r12
 call qx_strlen
 mov rdx,rbx
 shl rdx,4
 lea rcx,[rip+.Lu_matches]
 mov [rcx+rdx],r12
 mov [rcx+rdx+8],rax
 inc rbx
 jmp .Lu_paths_matches
.Lu_paths_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
# Insert a real catalogue path after @. Quote whitespace and escape quote/slash.
.Lu_apply_path:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rax,[rip+.Lu_menu_index]
 shl rax,4
 lea rdx,[rip+.Lu_matches]
 mov r12,[rdx+rax]
 mov r13,[rdx+rax+8]
 cmp r13,4095
 ja .Lu_apply_path_done
 xor r14d,r14d
 xor r15d,r15d
.Lu_path_needs_quote:
 cmp r14,r13
 jae .Lu_path_quote_known
 mov al,[r12+r14]
 cmp al,32
 je .Lu_path_set_quote
 cmp al,34
 je .Lu_path_set_quote
 cmp al,92
 jne .Lu_path_quote_next
.Lu_path_set_quote:
 mov r15d,1
.Lu_path_quote_next:
 inc r14
 jmp .Lu_path_needs_quote
.Lu_path_quote_known:
 lea rdi,[rip+.Lu_completion_text]
 test r15,r15
 jz .Lu_path_copy_start
 mov byte ptr [rdi],34
 inc rdi
.Lu_path_copy_start:
 xor r14d,r14d
.Lu_path_copy:
 cmp r14,r13
 jae .Lu_path_copy_finish
 mov al,[r12+r14]
 cmp al,34
 je .Lu_path_escape_char
 cmp al,92
 jne .Lu_path_copy_char
.Lu_path_escape_char:
 mov byte ptr [rdi],92
 inc rdi
.Lu_path_copy_char:
 mov [rdi],al
 inc rdi
 inc r14
 jmp .Lu_path_copy
.Lu_path_copy_finish:
 xor ebx,ebx
 test r13,r13
 jz .Lu_path_is_file
 cmp byte ptr [r12+r13-1],47
 jne .Lu_path_is_file
 mov ebx,1
 jmp .Lu_path_finish_text
.Lu_path_is_file:
 test r15,r15
 jz .Lu_path_file_space
 mov byte ptr [rdi],34
 inc rdi
.Lu_path_file_space:
 mov byte ptr [rdi],32
 inc rdi
.Lu_path_finish_text:
 mov byte ptr [rdi],0
 mov r8,rdi
 lea rcx,[rip+.Lu_completion_text]
 sub r8,rcx
 lea rdi,[rip+.Lu_context]
 mov rsi,[rip+.Lu_completion_start]
 mov rdx,[rip+.Lu_completion_end]
 call input_replace
 lea rdi,[rip+.Lu_context]
 mov rsi,rbx
 call input_set_completion
 mov [rip+.Lu_menu],rbx
 mov qword ptr [rip+.Lu_menu_index],0
 mov qword ptr [rip+.Lu_menu_tabbed],0
.Lu_apply_path_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.Lu_completion_marker: .asciz "> "

.section .rodata

.section .bss
.Lu_tool_name: .skip 512
.Lu_tool_args: .skip 65536
.Lu_tool_args_len: .skip 8
.Lu_tool_description: .skip 131072
.Lu_tool_description_len: .skip 8
.Lu_tool_preview_body: .skip 1048576
.Lu_tool_pending: .skip 8
.Lu_tool_record: .skip 8
.Lu_tool_completion_len: .skip 8
.section .rodata
.Lu_question_prefix: .asciz "? "
.Lu_completion_question: .ascii "\n\nApply this change?"
.section .text
# Typed presentation only applies to the exact pending action's JSON arguments.
.Lu_prepare_typed_approval:
 push rbx
 push r12
 push r13
 cmp qword ptr [rip+.Lu_tool_pending],0
 je .Lu_typed_unavailable
 cmp qword ptr [rip+.Lu_tool_description_len],0
 je .Lu_typed_unavailable
 mov rbx,rdi
.Lu_typed_find_args:
 mov al,[rbx]
 test al,al
 jz .Lu_typed_unavailable
 cmp al,123
 je .Lu_typed_compare_args
 inc rbx
 jmp .Lu_typed_find_args
.Lu_typed_compare_args:
 mov rdi,rbx
 lea rsi,[rip+.Lu_tool_args]
 mov rcx,[rip+.Lu_tool_args_len]
 repe cmpsb
 jne .Lu_typed_unavailable
 cmp byte ptr [rdi],0
 jne .Lu_typed_unavailable
 lea rdi,[rip+.Lu_tool_name]
 lea rsi,[rip+.Lu_tool_args]
 mov rdx,[rip+.Lu_tool_args_len]
 lea rcx,[rip+.Lu_tool_preview_body]
 mov r8d,1048576
 call ui_tool_preview
 test rax,rax
 js .Lu_typed_unavailable
 mov r12,rax
 lea rax,[rip+.Lu_clean]
 mov [rip+.Lu_builder],rax
 mov qword ptr [rip+.Lu_builder+8],4194303
 mov qword ptr [rip+.Lu_builder+16],0
 lea rdi,[rip+.Lu_question_prefix]
 call .Lu_z
 lea rdi,[rip+.Lu_tool_description]
 mov rsi,[rip+.Lu_tool_description_len]
 call .Lu_put
 call .Lu_nl
 cmp r12,18
 jb .Lu_typed_body_full
 lea rdi,[rip+.Lu_tool_preview_body]
 add rdi,r12
 sub rdi,18
 lea rsi,[rip+.Lu_apply_question_plain]
 mov ecx,18
 repe cmpsb
 jne .Lu_typed_body_full
 lea rdi,[rip+.Lu_tool_preview_body]
 lea rsi,[r12-18]
 call .Lu_put
 lea rdi,[rip+.Lu_apply_question_indented]
 call .Lu_z
 jmp .Lu_typed_body_done
.Lu_typed_body_full:
 lea rdi,[rip+.Lu_tool_preview_body]
 mov rsi,r12
 call .Lu_put
.Lu_typed_body_done:
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_builder+16]
 lea rdx,[rip+.Lu_preview]
 mov ecx,4194303
 call ui_sanitize
 test rax,rax
 js .Lu_typed_unavailable
 mov [rip+.Lu_preview_len],rax
 xor eax,eax
 jmp .Lu_typed_done
.Lu_typed_unavailable:
 mov rax,-1
.Lu_typed_done:
 pop r13
 pop r12
 pop rbx
 ret

.section .bss
.Lu_options_top: .skip 8
.section .rodata
.Lu_source_always: .asciz "2. Yes, allow always"
.Lu_source_deny: .asciz "3. No, suggest changes (esc)"
.Lu_waiting_confirmation: .asciz "  ⠋ Waiting for user confirmation..."

.section .rodata
.Lu_edit_name: .asciz "edit_file"
.Lu_write_name: .asciz "write_file"
.section .text
.Lu_is_edit_tool:
 push rbx
 cmp qword ptr [rip+.Lu_tool_pending],0
 je .Lu_not_edit_tool
 lea rdi,[rip+.Lu_tool_name]
 lea rsi,[rip+.Lu_edit_name]
 call qx_streq
 test rax,rax
 jnz .Lu_edit_tool_done
 lea rdi,[rip+.Lu_tool_name]
 lea rsi,[rip+.Lu_write_name]
 call qx_streq
 jmp .Lu_edit_tool_done
.Lu_not_edit_tool:
 xor eax,eax
.Lu_edit_tool_done:
 pop rbx
 ret

.section .rodata
.Lu_theme_0_6: .asciz "\033[38;2;137;180;250m"
.Lu_theme_1_6: .asciz "\033[38;2;139;233;253m"
.Lu_theme_2_6: .asciz "\033[38;2;121;184;255m"
.Lu_theme_3_6: .asciz "\033[38;2;68;85;136m"
.section .bss
.Lu_link: .skip 32
.section .text
.Lu_border_color:
 lea rdi,[rip+.Lu_link]
 cmp qword ptr [rip+.Lu_mode],1
 jne .Lu_border_not_edit
 lea rdi,[rip+.Lu_warning]
.Lu_border_not_edit:
 cmp qword ptr [rip+.Lu_mode],3
 jne .Lu_border_done
 lea rdi,[rip+.Lu_error]
.Lu_border_done:
 ret

.section .bss
.Lu_flow_indent: .skip 8
.Lu_flow_compact: .skip 8
.section .rodata
.Lu_three_spaces: .asciz "   "
.Lu_five_spaces: .asciz "     "
.Lu_waiting_text: .asciz " Waiting for user confirmation..."
.section .text
# Choices live in the same scrollable content as the exact pending tool preview.
.Lu_flow_approval_choices:
 push rbx
 call .Lu_nl
 call .Lu_nl
 xor ebx,ebx
.Lu_flow_approval_option:
 lea rdi,[rip+.Lu_muted]
 cmp rbx,[rip+.Lu_selection]
 jne .Lu_flow_approval_color
 lea rdi,[rip+.Lu_success]
.Lu_flow_approval_color:
 call .Lu_z
 cmp rbx,[rip+.Lu_selection]
 jne .Lu_flow_approval_unselected
 lea rdi,[rip+.Lu_three_spaces]
 call .Lu_z
 lea rdi,[rip+.Lu_marker]
 call .Lu_z
 jmp .Lu_flow_approval_text
.Lu_flow_approval_unselected:
 lea rdi,[rip+.Lu_five_spaces]
 call .Lu_z
.Lu_flow_approval_text:
 lea rdi,[rip+.Lu_allow]
 test rbx,rbx
 je .Lu_flow_approval_label
 cmp rbx,1
 jne .Lu_flow_approval_no
 call .Lu_is_edit_tool
 lea rdi,[rip+.Lu_always]
 test rax,rax
 jz .Lu_flow_approval_label
 lea rdi,[rip+.Lu_source_always]
 jmp .Lu_flow_approval_label
.Lu_flow_approval_no:
 lea rdi,[rip+.Lu_source_deny]
.Lu_flow_approval_label:
 call .Lu_z
 call .Lu_nl
 inc rbx
 cmp rbx,3
 jb .Lu_flow_approval_option
 pop rbx
 ret

.section .bss
.Lu_shell_mode: .skip 8
.Lu_math_offset: .skip 8
.Lu_clipboard_encoded: .skip 1398104
.section .rodata
.Lu_shell_prefix: .asciz "! "
.Lu_shell_running: .asciz "Executing shell command…"
.section .text
.globl ui_get_shell_mode,ui_shell_begin,ui_copy_latex
ui_get_shell_mode:
 mov rax,[rip+.Lu_shell_mode]
 ret
ui_shell_begin:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 call ui_shell_history_add
 mov edi,6
 mov rsi,r12
 mov rdx,r13
 call .Lu_entry
 mov qword ptr [rip+.Lu_busy],1
 lea rdi,[rip+.Lu_shell_running]
 call ui_status
 pop r13
 pop r12
 pop rbx
 ret
ui_copy_latex:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r13,rdi
 test r13,r13
 jle .Lu_copy_latex_bad
 xor r12d,r12d
.Lu_copy_latex_record:
 cmp r12,[rip+.Lu_count]
 jae .Lu_copy_latex_missing
 mov rax,r12
 shl rax,5
 lea rbx,[rip+.Lu_records]
 add rbx,rax
 cmp qword ptr [rbx],2
 jne .Lu_copy_latex_next
 lea r14,[rip+.Lu_blocks]
 add r14,[rbx+8]
 mov r15,[rbx+16]
 mov rdi,r14
 mov rsi,r15
 call ui_math_count
 test rax,rax
 jle .Lu_copy_latex_next
 cmp r13,rax
 jbe .Lu_copy_latex_extract
 sub r13,rax
.Lu_copy_latex_next:
 inc r12
 jmp .Lu_copy_latex_record
.Lu_copy_latex_extract:
 mov rdi,r14
 mov rsi,r15
 mov rdx,r13
 lea rcx,[rip+.Lu_clean]
 mov r8d,4194304
 call ui_extract_math
 test rax,rax
 js .Lu_copy_latex_done
 lea rdi,[rip+.Lu_clean]
 mov rsi,rax
 call ui_copy_text
 jmp .Lu_copy_latex_done
.Lu_copy_latex_missing:
 mov rax,-1
 jmp .Lu_copy_latex_done
.Lu_copy_latex_bad:
 mov rax,-22
.Lu_copy_latex_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .bss
.Lu_choice_layout: .skip 8
.Lu_choice_metadata: .skip 8
.Lu_choice_empty: .skip 8
.Lu_box_top: .skip 8
.Lu_box_height: .skip 8
.Lu_box_theme: .skip 8
.section .rodata
.Lu_round_tl: .asciz "╭"
.Lu_round_tr: .asciz "╮"
.Lu_round_bl: .asciz "╰"
.Lu_round_br: .asciz "╯"
.Lu_number_separator: .asciz ". "
.Lu_no_entries: .asciz "No entries available."
.Lu_no_sessions: .asciz "No sessions found"
.Lu_box_help: .asciz "Enter to select, ↑↓ to navigate, type to search, Esc to close"
.section .text
.globl ui_set_choice_layout,ui_set_choice_metadata,ui_set_choice_empty_text
ui_set_choice_layout:
 mov [rip+.Lu_choice_layout],rdi
 ret
ui_set_choice_metadata:
 mov [rip+.Lu_choice_metadata],rdi
 ret
ui_set_choice_empty_text:
 mov [rip+.Lu_choice_empty],rdi
 ret
.Lu_choose_box_geometry:
 mov qword ptr [rip+.Lu_box_theme],0
 mov eax,16
 cmp qword ptr [rip+.Lu_choice_layout],6
 jne .Lu_box_not_extensions_geometry
 mov rax,[rip+.Lu_choose_count]
 imul rax,rax,2
 add rax,8
 jmp .Lu_box_geometry_clamp
.Lu_box_not_extensions_geometry:
 cmp qword ptr [rip+.Lu_choice_layout],5
 jne .Lu_box_not_agents_geometry
 mov rax,[rip+.Lu_choose_count]
 add rax,12
 jmp .Lu_box_geometry_clamp
.Lu_box_not_agents_geometry:
 cmp qword ptr [rip+.Lu_choice_layout],4
 jne .Lu_box_not_help_geometry
 mov eax,20
 jmp .Lu_box_geometry_clamp
.Lu_box_not_help_geometry:
 cmp qword ptr [rip+.Lu_choice_layout],1
 je .Lu_box_geometry_clamp
 cmp qword ptr [rip+.Lu_choice_layout],3
 je .Lu_box_resume_geometry
 cmp qword ptr [rip+.Lu_choose_count],0
 je .Lu_box_resume_geometry
 cmp qword ptr [rip+.Lu_choice_layout],2
 je .Lu_box_theme_geometry
 cmp qword ptr [rip+.Lu_preview_callback],0
 je .Lu_box_geometry_clamp
.Lu_box_theme_geometry:
 mov qword ptr [rip+.Lu_box_theme],1
 mov eax,21
 jmp .Lu_box_geometry_clamp
.Lu_box_resume_geometry:
 mov rax,[rip+.Lu_rows]
 sub rax,5
.Lu_box_geometry_clamp:
 mov rcx,[rip+.Lu_rows]
 sub rcx,2
 cmp rax,rcx
 cmova rax,rcx
 cmp rax,8
 jae .Lu_box_geometry_height
 mov eax,8
.Lu_box_geometry_height:
 mov [rip+.Lu_box_height],rax
 mov ecx,6
 lea rdx,[rax+5]
 cmp rdx,[rip+.Lu_rows]
 jbe .Lu_box_geometry_top
 mov rcx,[rip+.Lu_rows]
 sub rcx,rax
 inc rcx
.Lu_box_geometry_top:
 mov [rip+.Lu_box_top],rcx
 ret
.Lu_theme_preview:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,32
 mov rax,[rip+.Lu_columns]
 sub rax,8
 mov ecx,45
 imul rax,rcx
 xor edx,edx
 mov ecx,100
 div rcx
 lea r14,[rax+7]
 mov r15,[rip+.Lu_columns]
 sub r15,rax
 sub r15,10
 mov r13,[rip+.Lu_box_top]
 lea rdi,[r13+2]
 mov rsi,r14
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 lea rdi,[rip+.Lu_preview_label]
 call .Lu_z
 call .Lu_reset_color
 add r13,3
 xor ebx,ebx
.Lu_theme_pane_row:
 lea rdi,[r13+rbx]
 mov rsi,r14
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 test rbx,rbx
 jz .Lu_theme_pane_top
 cmp rbx,12
 je .Lu_theme_pane_bottom
 lea rdi,[rip+.Lu_side]
 call .Lu_z
 lea rdi,[rip+.Lu_space]
 lea rsi,[r15-2]
 call .Lu_repeat
 lea rdi,[rip+.Lu_side]
 call .Lu_z
 jmp .Lu_theme_pane_next
.Lu_theme_pane_top:
 lea rdi,[rip+.Lu_tl]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 lea rsi,[r15-2]
 call .Lu_repeat
 lea rdi,[rip+.Lu_tr]
 call .Lu_z
 jmp .Lu_theme_pane_next
.Lu_theme_pane_bottom:
 lea rdi,[rip+.Lu_bl]
 call .Lu_z
 lea rdi,[rip+.Lu_dash]
 lea rsi,[r15-2]
 call .Lu_repeat
 lea rdi,[rip+.Lu_br]
 call .Lu_z
.Lu_theme_pane_next:
 inc rbx
 cmp rbx,13
 jb .Lu_theme_pane_row
 lea rdi,[rip+.Lu_theme_sample]
 mov esi,OFFSET FLAT:.Lu_theme_sample_len
 lea rdx,[rip+.Lu_formatted]
 mov ecx,4194304
 lea r8,[r15-4]
 mov r9,[rip+.Lu_theme_resolved]
 call ui_format_markdown_ex
 test rax,rax
 js .Lu_theme_pane_done
 lea r12,[rip+.Lu_formatted]
 lea rax,[r12+rax]
 mov [rsp],rax
 mov ebx,2
.Lu_theme_sample_line:
 cmp rbx,12
 jae .Lu_theme_pane_done
 cmp r12,[rsp]
 jae .Lu_theme_pane_done
 mov rax,r12
.Lu_theme_sample_scan:
 cmp rax,[rsp]
 jae .Lu_theme_sample_print
 cmp byte ptr [rax],10
 je .Lu_theme_sample_print
 inc rax
 jmp .Lu_theme_sample_scan
.Lu_theme_sample_print:
 mov [rsp+8],rax
 lea rdi,[r13+rbx]
 lea rsi,[r14+2]
 call .Lu_move
 mov rdi,r12
 mov rsi,[rsp+8]
 sub rsi,r12
 call .Lu_put
 mov r12,[rsp+8]
 cmp r12,[rsp]
 jae .Lu_theme_pane_done
 inc r12
 inc rbx
 jmp .Lu_theme_sample_line
.Lu_theme_pane_done:
 add rsp,32
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.Lu_apply_question_plain: .ascii "Apply this change?"
.Lu_apply_question_indented: .asciz " Apply this change?"

.section .rodata
.Lu_preview_label: .asciz "Preview"
.Lu_theme_sample: .ascii "```python\n# function\ndef fibonacci(n):\n    a, b = 0, 1\n    for _ in range(n):\n        a, b = b, a + b\n    return a\n```\n\n```diff\n- print(\"Hello, \" + name)\n+ print(f\"Hello, {name}!\")\n```"
.set .Lu_theme_sample_len,.-.Lu_theme_sample

.section .bss
.Lu_dialog_button: .skip 8
.Lu_dialog_x: .skip 8
.Lu_dialog_y: .skip 8
.Lu_dialog_release: .skip 8
.Lu_dialog_mouse_digits: .skip 8
.Lu_dialog_mouse_phase: .skip 8

.include "ui_themes.inc"
.section .bss
.Lu_theme_resolved: .skip 8
.Lu_auto_resolved: .skip 8
.Lu_no_color: .skip 8
.section .text
.globl ui_theme_catalog,ui_theme_name,ui_theme_find
ui_theme_catalog:
 push rbx
 push r12
 push r13
 mov r12,rdi
 mov r13,rsi
 xor ebx,ebx
 test rsi,rsi
 jz .Lu_theme_catalog_custom_measure
 test rdi,rdi
 jz .Lu_theme_catalog_bad
 cmp rsi,16
 jbe .Lu_theme_catalog_copy
 mov esi,16
.Lu_theme_catalog_copy:
 mov rbx,rsi
 imul rcx,rsi,3
 lea rsi,[rip+.Lu_all_theme_catalog]
 rep movsq
 cmp r13,16
 jbe .Lu_theme_catalog_done
 mov rsi,r13
 sub rsi,16
 jmp .Lu_theme_catalog_custom
.Lu_theme_catalog_custom_measure:
 mov ebx,16
 xor esi,esi
.Lu_theme_catalog_custom:
 mov rax,[rip+.Lu_custom_catalog]
 test rax,rax
 jz .Lu_theme_catalog_done
 call rax
 test rax,rax
 js .Lu_theme_catalog_done
 add rbx,rax
.Lu_theme_catalog_done:
 mov rax,rbx
 jmp .Lu_theme_catalog_return
.Lu_theme_catalog_bad:
 mov rax,-22
.Lu_theme_catalog_return:
 pop r13
 pop r12
 pop rbx
 ret
ui_theme_name:
 cmp rdi,16
 jb .Lu_theme_name_builtin
 mov rax,[rip+.Lu_custom_name]
 test rax,rax
 jz .Lu_theme_name_bad
 jmp rax
.Lu_theme_name_builtin:
 lea rax,[rip+.Lu_all_theme_names]
 mov rax,[rax+rdi*8]
 ret
.Lu_theme_name_bad:
 xor eax,eax
 ret
ui_theme_find:
 push rbx
 push r12
 sub rsp,8
 mov r12,rdi
 test r12,r12
 jz .Lu_theme_find_bad
 xor ebx,ebx
.Lu_theme_find_next:
 lea rax,[rip+.Lu_all_theme_names]
 mov rsi,[rax+rbx*8]
 mov rdi,r12
 call .Lu_case_equal
 test rax,rax
 jnz .Lu_theme_find_found
 inc rbx
 cmp rbx,16
 jb .Lu_theme_find_next
 mov rax,[rip+.Lu_custom_find]
 test rax,rax
 jz .Lu_theme_find_bad
 mov rdi,r12
 call rax
 jmp .Lu_theme_find_done
.Lu_theme_find_bad:
 mov rax,-1
 jmp .Lu_theme_find_done
.Lu_theme_find_found:
 mov rax,rbx
.Lu_theme_find_done:
 add rsp,8
 pop r12
 pop rbx
 ret
.Lu_case_equal:
 xor ecx,ecx
.Lu_case_equal_byte:
 movzx eax,byte ptr [rdi+rcx]
 movzx edx,byte ptr [rsi+rcx]
 cmp eax,65
 jb .Lu_case_equal_second
 cmp eax,90
 ja .Lu_case_equal_second
 add eax,32
.Lu_case_equal_second:
 cmp edx,65
 jb .Lu_case_equal_compare
 cmp edx,90
 ja .Lu_case_equal_compare
 add edx,32
.Lu_case_equal_compare:
 cmp eax,edx
 jne .Lu_case_equal_no
 test eax,eax
 jz .Lu_case_equal_yes
 inc rcx
 cmp rcx,1024
 jb .Lu_case_equal_byte
.Lu_case_equal_no:
 xor eax,eax
 ret
.Lu_case_equal_yes:
 mov eax,1
 ret

.section .bss
.Lu_choice_scope: .skip 8
.Lu_scope_focus: .skip 8
.section .rodata
.Lu_theme_help: .asciz "(Use Enter to select, Tab to configure scope)"
.Lu_scope_help: .asciz "(Use Enter to apply scope, Tab to go back)"
.Lu_scope_title: .asciz "> Apply To"
.Lu_scope_user: .asciz "1. User Settings"
.Lu_scope_project: .asciz "2. Workspace Settings"
.section .text
.globl ui_get_choice_scope
ui_get_choice_scope:
 mov rax,[rip+.Lu_choice_scope]
 ret
.Lu_scope_view:
 push rbx
 push r12
 sub rsp,8
 mov r12,[rip+.Lu_box_top]
 lea rdi,[r12+2]
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 lea rdi,[rip+.Lu_scope_title]
 call .Lu_z
 call .Lu_reset_color
 xor ebx,ebx
.Lu_scope_option:
 lea rdi,[r12+rbx+4]
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 cmp rbx,[rip+.Lu_choice_scope]
 jne .Lu_scope_option_color
 lea rdi,[rip+.Lu_accent]
.Lu_scope_option_color:
 call .Lu_z
 lea rdi,[rip+.Lu_nomarker]
 cmp rbx,[rip+.Lu_choice_scope]
 jne .Lu_scope_option_marker
 lea rdi,[rip+.Lu_marker]
.Lu_scope_option_marker:
 call .Lu_z
 lea rdi,[rip+.Lu_scope_user]
 test rbx,rbx
 jz .Lu_scope_option_label
 lea rdi,[rip+.Lu_scope_project]
.Lu_scope_option_label:
 call .Lu_z
 inc rbx
 cmp rbx,2
 jb .Lu_scope_option
 mov rdi,r12
 add rdi,[rip+.Lu_box_height]
 sub rdi,3
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_scope_help]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 add rsp,8
 pop r12
 pop rbx
 ret

.section .bss
.Lu_auto_known: .skip 8
.Lu_auto_probed: .skip 8
.Lu_osc_rgb: .skip 32
.Lu_startup_events: .skip 8
.Lu_environment: .skip 8
.section .rodata
.Lu_env_no_color: .asciz "NO_COLOR"
.Lu_env_colorfgbg: .asciz "COLORFGBG"
.Lu_osc_query: .ascii "\033]11;?\007"
.section .text
.globl ui_detect_theme
# Before ui_start this is env-only; afterpreferences it probes Auto once,200ms.
ui_detect_theme:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov [rip+.Lu_environment],rdi
 mov qword ptr [rip+.Lu_no_color],0
 test r12,r12
 jz .Lu_detect_apply
 lea rsi,[rip+.Lu_env_no_color]
 call qx_env_get
 test rax,rax
 jz .Lu_detect_bg
 cmp byte ptr [rax],0
 je .Lu_detect_bg
 mov qword ptr [rip+.Lu_no_color],1
.Lu_detect_bg:
 mov rdi,r12
 lea rsi,[rip+.Lu_env_colorfgbg]
 call qx_env_get
 test rax,rax
 jz .Lu_detect_apply
 cmp byte ptr [rax],0
 je .Lu_detect_apply
 mov rdx,rax
 xor ecx,ecx
.Lu_detect_bg_last:
 cmp ecx,1024
 jae .Lu_detect_apply
 mov bl,[rax+rcx]
 test bl,bl
 jz .Lu_detect_bg_number
 cmp bl,59
 jne .Lu_detect_bg_next
 lea rdx,[rax+rcx+1]
.Lu_detect_bg_next:
 inc ecx
 jmp .Lu_detect_bg_last
.Lu_detect_bg_number:
 xor r14d,r14d
 xor r15d,r15d
.Lu_detect_bg_space:
 movzx eax,byte ptr [rdx]
 cmp eax,32
 ja .Lu_detect_bg_sign
 test eax,eax
 jz .Lu_detect_apply
 inc rdx
 jmp .Lu_detect_bg_space
.Lu_detect_bg_sign:
 cmp eax,45
 jne .Lu_detect_bg_plus
 mov r15d,1
 inc rdx
 jmp .Lu_detect_bg_digits
.Lu_detect_bg_plus:
 cmp eax,43
 jne .Lu_detect_bg_digits
 inc rdx
.Lu_detect_bg_digits:
 xor ecx,ecx
.Lu_detect_bg_digit:
 movzx eax,byte ptr [rdx]
 sub eax,48
 cmp eax,9
 ja .Lu_detect_bg_parsed
 inc ecx
 imul r14,r14,10
 add r14,rax
 cmp r14,16
 jbe .Lu_detect_bg_digit_next
 mov r14d,16
.Lu_detect_bg_digit_next:
 inc rdx
 jmp .Lu_detect_bg_digit
.Lu_detect_bg_parsed:
 test ecx,ecx
 jz .Lu_detect_apply
 mov qword ptr [rip+.Lu_auto_known],1
 mov qword ptr [rip+.Lu_auto_resolved],0
 test r15,r15
 jnz .Lu_detect_apply
 cmp r14,7
 je .Lu_detect_bg_light
 cmp r14,9
 jb .Lu_detect_apply
 cmp r14,15
 ja .Lu_detect_apply
.Lu_detect_bg_light:
 mov qword ptr [rip+.Lu_auto_resolved],4
.Lu_detect_apply:
 mov rdi,[rip+.Lu_theme]
 call ui_set_theme
 cmp qword ptr [rip+.Lu_active],0
 je .Lu_detect_done
 cmp qword ptr [rip+.Lu_no_color],0
 jne .Lu_detect_done
 cmp qword ptr [rip+.Lu_theme],15
 jne .Lu_detect_done
 cmp qword ptr [rip+.Lu_auto_known],0
 jne .Lu_detect_done
 cmp qword ptr [rip+.Lu_auto_probed],0
 jne .Lu_detect_done
 mov qword ptr [rip+.Lu_auto_probed],1
 mov edi,1
 lea rsi,[rip+.Lu_osc_query]
 mov edx,7
 call qx_write_all
 test rax,rax
 js .Lu_detect_done
 call .Lu_monotonic_ms
 test rax,rax
 js .Lu_detect_done
 lea r13,[rax+200]
.Lu_detect_wait:
 call .Lu_monotonic_ms
 cmp rax,r13
 jae .Lu_detect_done
 mov edi,20
 call .Lu_acquire
 mov rbx,rax
 test rbx,INPUT_SUBMIT|INPUT_QUEUE
 jz .Lu_detect_no_submission
 call .Lu_queue_current
 jmp .Lu_detect_done
.Lu_detect_no_submission:
 mov rax,rbx
 and eax,INPUT_CANCEL|INPUT_EOF|2097152
 jz .Lu_detect_no_control
 mov [rip+.Lu_startup_events],rax
 jmp .Lu_detect_done
.Lu_detect_no_control:
 cmp qword ptr [rip+.Lu_auto_known],0
 je .Lu_detect_wait
.Lu_detect_done:
 xor eax,eax
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Lu_monotonic_ms:
 sub rsp,24
 mov eax,228
 mov edi,1
 mov rsi,rsp
 syscall
 test rax,rax
 js .Lu_monotonic_done
 mov r8,[rsp]
 imul r8,r8,1000
 mov rax,[rsp+8]
 xor edx,edx
 mov ecx,1000000
 div rcx
 add rax,r8
.Lu_monotonic_done:
 add rsp,24
 ret

.section .bss
.Lu_dialog_osc_esc: .skip 8
.section .rodata
.Lu_osc_prefix: .ascii "\033]"

.section .bss
.Lu_mermaid_offset: .skip 8
.section .text
.globl ui_copy_mermaid
ui_copy_mermaid:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r13,rdi
 test r13,r13
 jle .Lu_copy_mermaid_bad
 xor r12d,r12d
.Lu_copy_mermaid_record:
 cmp r12,[rip+.Lu_count]
 jae .Lu_copy_mermaid_missing
 mov rax,r12
 shl rax,5
 lea rbx,[rip+.Lu_records]
 add rbx,rax
 cmp qword ptr [rbx],2
 jne .Lu_copy_mermaid_next
 lea r14,[rip+.Lu_blocks]
 add r14,[rbx+8]
 mov r15,[rbx+16]
 mov rdi,r14
 mov rsi,r15
 call ui_mermaid_count
 test rax,rax
 jle .Lu_copy_mermaid_next
 cmp r13,rax
 jbe .Lu_copy_mermaid_extract
 sub r13,rax
.Lu_copy_mermaid_next:
 inc r12
 jmp .Lu_copy_mermaid_record
.Lu_copy_mermaid_extract:
 mov rdi,r14
 mov rsi,r15
 mov rdx,r13
 lea rcx,[rip+.Lu_clean]
 mov r8d,4194304
 call ui_extract_mermaid
 test rax,rax
 js .Lu_copy_mermaid_done
 lea rdi,[rip+.Lu_clean]
 mov rsi,rax
 call ui_copy_text
 jmp .Lu_copy_mermaid_done
.Lu_copy_mermaid_missing:
 mov rax,-1
 jmp .Lu_copy_mermaid_done
.Lu_copy_mermaid_bad:
 mov rax,-22
.Lu_copy_mermaid_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .bss
.Lu_help_scroll: .skip 8
.Lu_help_line_count: .skip 8
.Lu_help_lines: .skip 32768
.section .rodata
.Lu_help_brand: .asciz "Qwen Code   "
.Lu_help_tab_gap: .asciz "   "
.Lu_help_hint: .asciz "Tab/Shift+Tab to switch tabs  ·  Esc to cancel"
.section .text
.Lu_help_view:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rdi,[rip+.Lu_box_top]
 add rdi,2
 mov esi,6
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 lea rdi,[rip+.Lu_help_brand]
 call .Lu_z
 call .Lu_reset_color
 xor ebx,ebx
.Lu_help_tab:
 cmp rbx,[rip+.Lu_choose_count]
 jae .Lu_help_body
 lea rdi,[rip+.Lu_muted]
 cmp rbx,[rip+.Lu_choose_selection]
 jne .Lu_help_tab_color
 lea rdi,[rip+.Lu_accent]
.Lu_help_tab_color:
 call .Lu_z
 imul rax,rbx,24
 add rax,[rip+.Lu_choose_items]
 mov rdi,[rax]
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[rip+.Lu_clean]
 call .Lu_z
 lea rdi,[rip+.Lu_help_tab_gap]
 call .Lu_z
 inc rbx
 jmp .Lu_help_tab
.Lu_help_body:
 cmp qword ptr [rip+.Lu_choose_count],0
 je .Lu_help_footer
 mov rdi,[rip+.Lu_choose_selection]
 mov rsi,[rip+.Lu_columns]
 sub rsi,10
 lea rdx,[rip+.Lu_clean]
 mov ecx,4194303
 call ui_help_format
 test rax,rax
 js .Lu_help_footer
 lea rdi,[rip+.Lu_clean]
 mov rsi,rax
 lea rdx,[rip+.Lu_formatted]
 mov ecx,4194304
 mov r8,[rip+.Lu_columns]
 sub r8,10
 mov r9,[rip+.Lu_theme_resolved]
 call ui_format_markdown_ex
 test rax,rax
 js .Lu_help_footer
 lea r12,[rip+.Lu_formatted]
 lea r13,[r12+rax]
 mov qword ptr [rip+.Lu_help_line_count],0
.Lu_help_index_line:
 cmp r12,r13
 jae .Lu_help_index_done
 mov rax,[rip+.Lu_help_line_count]
 cmp rax,2048
 jae .Lu_help_index_done
 shl rax,4
 lea rdx,[rip+.Lu_help_lines]
 mov [rdx+rax],r12
 mov r14,r12
.Lu_help_index_scan:
 cmp r14,r13
 jae .Lu_help_index_end
 cmp byte ptr [r14],10
 je .Lu_help_index_end
 inc r14
 jmp .Lu_help_index_scan
.Lu_help_index_end:
 mov rcx,r14
 sub rcx,r12
 mov [rdx+rax+8],rcx
 inc qword ptr [rip+.Lu_help_line_count]
 lea r12,[r14+1]
 jmp .Lu_help_index_line
.Lu_help_index_done:
 mov r15,[rip+.Lu_box_height]
 sub r15,7
 mov rax,[rip+.Lu_help_line_count]
 sub rax,r15
 jns .Lu_help_scroll_limit
 xor eax,eax
.Lu_help_scroll_limit:
 cmp [rip+.Lu_help_scroll],rax
 jbe .Lu_help_scroll_clamped
 mov [rip+.Lu_help_scroll],rax
.Lu_help_scroll_clamped:
 mov r12,[rip+.Lu_help_scroll]
 mov r13,[rip+.Lu_box_top]
 add r13,4
 xor ebx,ebx
.Lu_help_render_line:
 cmp rbx,r15
 jae .Lu_help_footer
 cmp r12,[rip+.Lu_help_line_count]
 jae .Lu_help_footer
 mov rdi,r13
 mov esi,6
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 mov rax,r12
 shl rax,4
 lea rdx,[rip+.Lu_help_lines]
 mov rdi,[rdx+rax]
 mov rsi,[rdx+rax+8]
 call .Lu_put
 inc r12
 inc r13
 inc rbx
 jmp .Lu_help_render_line
.Lu_help_footer:
 mov rdi,[rip+.Lu_box_top]
 add rdi,[rip+.Lu_box_height]
 sub rdi,3
 mov esi,6
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_help_hint]
 mov rsi,[rip+.Lu_columns]
 sub rsi,10
 call .Lu_field
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.Lu_resume_search_hint: .asciz "Press / to search"
.Lu_resume_controls: .asciz "↑↓ to navigate · Type to search · Esc to cancel"

.section .rodata
.Lu_shell_footer: .asciz "shell mode enabled (esc to disable)"
.section .text
.globl ui_get_busy
ui_get_busy:
 mov rax,[rip+.Lu_busy]
 ret

.section .bss
.Lu_choice_reader: .skip 8
.Lu_read_preview_active: .skip 8
.Lu_reader_error: .skip 8
.Lu_read_raw: .skip 1048576
.Lu_read_raw_len: .skip 8
.Lu_read_formatted: .skip 4194304
.Lu_read_formatted_theme: .skip 8
.Lu_read_formatted_columns: .skip 8
.Lu_read_lines: .skip 1048576
.Lu_read_count: .skip 8
.Lu_read_scroll: .skip 8
.Lu_read_truncated: .skip 8
.section .rodata
.Lu_resume_preview_controls: .asciz "Space to preview · ↑↓ to navigate · Type to search · Esc to cancel"
.Lu_session_preview_title: .asciz "Session Preview"
.Lu_session_preview_hint: .asciz "Enter to resume · ↑↓/PgUp/PgDn to scroll · Esc back"
.section .text
.globl ui_set_choice_preview_reader,ui_set_session_preview_callback
ui_set_session_preview_callback:
ui_set_choice_preview_reader:
 mov [rip+.Lu_choice_reader],rdi
 ret
.Lu_open_read_preview:
 push rbx
 push r12
 push r13
 mov rbx,[rip+.Lu_choice_reader]
 test rbx,rbx
 jz .Lu_open_preview_fail
 mov rax,[rip+.Lu_choose_selection]
 imul rax,rax,24
 add rax,[rip+.Lu_choose_items]
 mov rdi,[rax+16]
 test rdi,rdi
 jz .Lu_open_preview_fail
 lea rsi,[rip+.Lu_read_raw]
 mov edx,1048575
 call rbx
 test rax,rax
 js .Lu_open_preview_fail
 cmp rax,1048575
 ja .Lu_open_preview_fail
 mov [rip+.Lu_read_raw_len],rax
 mov qword ptr [rip+.Lu_read_scroll],0
 call .Lu_format_read_preview
 test rax,rax
 js .Lu_open_preview_fail
 mov qword ptr [rip+.Lu_read_preview_active],1
 mov qword ptr [rip+.Lu_reader_error],0
 jmp .Lu_open_preview_done
.Lu_open_preview_fail:
 mov qword ptr [rip+.Lu_reader_error],1
.Lu_open_preview_done:
 pop r13
 pop r12
 pop rbx
 ret
.Lu_format_read_preview:
 push rbx
 push r12
 push r13
 lea rdi,[rip+.Lu_read_raw]
 mov rsi,[rip+.Lu_read_raw_len]
 lea rdx,[rip+.Lu_read_formatted]
 mov ecx,4194304
 mov r8,[rip+.Lu_columns]
 sub r8,10
 mov r9,[rip+.Lu_theme_resolved]
 call ui_format_markdown_ex
 test rax,rax
 jns .Lu_read_format_index
 lea rdi,[rip+.Lu_read_raw]
 mov rsi,[rip+.Lu_read_raw_len]
 lea rdx,[rip+.Lu_read_formatted]
 mov ecx,4194304
 call ui_sanitize
 test rax,rax
 js .Lu_read_format_done
.Lu_read_format_index:
 mov rcx,[rip+.Lu_theme_resolved]
 mov [rip+.Lu_read_formatted_theme],rcx
 mov rcx,[rip+.Lu_columns]
 mov [rip+.Lu_read_formatted_columns],rcx
 lea r12,[rip+.Lu_read_formatted]
 lea r13,[r12+rax]
 mov qword ptr [rip+.Lu_read_count],0
 mov qword ptr [rip+.Lu_read_truncated],0
.Lu_read_index_line:
 cmp r12,r13
 jae .Lu_read_index_complete
 mov rax,[rip+.Lu_read_count]
 cmp rax,65535
 jae .Lu_read_index_truncate
 shl rax,4
 lea rdx,[rip+.Lu_read_lines]
 mov [rdx+rax],r12
 mov rbx,r12
.Lu_read_index_end:
 cmp rbx,r13
 jae .Lu_read_index_store
 cmp byte ptr [rbx],10
 je .Lu_read_index_store
 inc rbx
 jmp .Lu_read_index_end
.Lu_read_index_store:
 mov rcx,rbx
 sub rcx,r12
 mov [rdx+rax+8],rcx
 inc qword ptr [rip+.Lu_read_count]
 lea r12,[rbx+1]
 jmp .Lu_read_index_line
.Lu_read_index_truncate:
 mov qword ptr [rip+.Lu_read_truncated],1
.Lu_read_index_complete:
 xor eax,eax
.Lu_read_format_done:
 pop r13
 pop r12
 pop rbx
 ret
.Lu_choose_preview_key:
 cmp qword ptr [rip+.Lu_view_only],0
 je .Lu_choose_preview_session_key
 cmp eax,8
 je .Lu_choose_invalid
 cmp eax,3
 je .Lu_choose_invalid
.Lu_choose_preview_session_key:
 cmp eax,8
 je .Lu_close_read_preview
 cmp eax,3
 je .Lu_choose_accept
 cmp eax,1
 je .Lu_read_scroll_up_one
 cmp eax,2
 je .Lu_read_scroll_down_one
 cmp eax,6
 je .Lu_read_scroll_up_page
 cmp eax,7
 je .Lu_read_scroll_down_page
 cmp eax,12
 je .Lu_read_scroll_up_wheel
 cmp eax,13
 je .Lu_read_scroll_down_wheel
 jmp .Lu_choose_loop
.Lu_close_read_preview:
 mov qword ptr [rip+.Lu_read_preview_active],0
 jmp .Lu_choose_loop
.Lu_read_scroll_up_one:
 mov eax,1
 jmp .Lu_read_scroll_up
.Lu_read_scroll_up_page:
 mov eax,8
 jmp .Lu_read_scroll_up
.Lu_read_scroll_up_wheel:
 mov eax,3
.Lu_read_scroll_up:
 mov rdx,[rip+.Lu_read_scroll]
 sub rdx,rax
 jns .Lu_read_scroll_store
 xor edx,edx
 jmp .Lu_read_scroll_store
.Lu_read_scroll_down_one:
 mov eax,1
 jmp .Lu_read_scroll_down
.Lu_read_scroll_down_page:
 mov eax,8
 jmp .Lu_read_scroll_down
.Lu_read_scroll_down_wheel:
 mov eax,3
.Lu_read_scroll_down:
 mov rdx,[rip+.Lu_read_scroll]
 add rdx,rax
.Lu_read_scroll_store:
 mov [rip+.Lu_read_scroll],rdx
 jmp .Lu_choose_loop
.Lu_session_preview_view:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov rax,[rip+.Lu_theme_resolved]
 cmp rax,[rip+.Lu_read_formatted_theme]
 jne .Lu_read_preview_reformat
 mov rax,[rip+.Lu_columns]
 cmp rax,[rip+.Lu_read_formatted_columns]
 je .Lu_read_preview_ready
.Lu_read_preview_reformat:
 call .Lu_format_read_preview
.Lu_read_preview_ready:
 mov rdi,[rip+.Lu_box_top]
 inc rdi
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 lea rdi,[rip+.Lu_session_preview_title]
 cmp qword ptr [rip+.Lu_view_only],0
 je .Lu_read_title_ready
 mov rdi,[rip+.Lu_choose_title]
.Lu_read_title_ready:
 call .Lu_z
 call .Lu_reset_color
 mov rax,[rip+.Lu_choose_selection]
 imul rax,rax,24
 add rax,[rip+.Lu_choose_items]
 mov rdi,[rax]
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 mov rdi,[rip+.Lu_box_top]
 add rdi,2
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 mov r15,[rip+.Lu_box_height]
 sub r15,7
 mov rax,[rip+.Lu_read_count]
 sub rax,r15
 jns .Lu_read_scroll_limit
 xor eax,eax
.Lu_read_scroll_limit:
 cmp [rip+.Lu_read_scroll],rax
 jbe .Lu_read_scroll_clamped
 mov [rip+.Lu_read_scroll],rax
.Lu_read_scroll_clamped:
 mov r12,[rip+.Lu_read_scroll]
 mov r13,[rip+.Lu_box_top]
 add r13,4
 xor ebx,ebx
.Lu_read_render_line:
 cmp rbx,r15
 jae .Lu_read_preview_footer
 cmp r12,[rip+.Lu_read_count]
 jae .Lu_read_preview_footer
 mov rdi,r13
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 mov rax,r12
 shl rax,4
 lea rdx,[rip+.Lu_read_lines]
 mov rdi,[rdx+rax]
 mov rsi,[rdx+rax+8]
 call .Lu_put
 inc r12
 inc r13
 inc rbx
 jmp .Lu_read_render_line
.Lu_read_preview_footer:
 mov rdi,[rip+.Lu_box_top]
 add rdi,[rip+.Lu_box_height]
 sub rdi,2
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_session_preview_hint]
 cmp qword ptr [rip+.Lu_read_truncated],0
 je .Lu_session_preview_hint_selected
 lea rdi,[rip+.Lu_session_preview_limited]
.Lu_session_preview_hint_selected:
 cmp qword ptr [rip+.Lu_view_only],0
 je .Lu_read_hint_ready
 lea rdi,[rip+.Lu_view_hint]
.Lu_read_hint_ready:
 mov rsi,[rip+.Lu_columns]
 sub rsi,8
 call .Lu_field
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.Lu_preview_error_text: .asciz "Unable to preview this session."
.Lu_session_preview_limited: .asciz "Preview display limit · Enter to resume · Esc back"

.section .bss
.Lu_resume_search_active: .skip 8
.section .text
.Lu_choose_resume_key:
 cmp eax,8
 je .Lu_resume_escape
 cmp eax,3
 je .Lu_resume_enter
 cmp eax,1
 je .Lu_resume_up
 cmp eax,2
 je .Lu_resume_down
 cmp eax,9
 je .Lu_resume_printable
 cmp qword ptr [rip+.Lu_resume_search_active],0
 je .Lu_choose_loop
 cmp eax,10
 je .Lu_choose_backspace
 cmp eax,11
 je .Lu_resume_clear
 jmp .Lu_choose_loop
.Lu_resume_escape:
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_resume_clear
 cmp qword ptr [rip+.Lu_query_len],0
 je .Lu_choose_invalid
.Lu_resume_clear:
 mov qword ptr [rip+.Lu_resume_search_active],0
 jmp .Lu_choose_clear
.Lu_resume_enter:
 cmp qword ptr [rip+.Lu_resume_search_active],0
 je .Lu_choose_accept
 cmp qword ptr [rip+.Lu_filtered_count],0
 je .Lu_choose_loop
 mov qword ptr [rip+.Lu_resume_search_active],0
 jmp .Lu_choose_loop
.Lu_resume_up:
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_resume_commit_navigation
 cmp qword ptr [rip+.Lu_filtered_selection],0
 jne .Lu_resume_move_up
 mov qword ptr [rip+.Lu_resume_search_active],1
 jmp .Lu_choose_loop
.Lu_resume_move_up:
 dec qword ptr [rip+.Lu_filtered_selection]
 jmp .Lu_choose_loop
.Lu_resume_down:
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_resume_commit_navigation
 mov rax,[rip+.Lu_filtered_selection]
 inc rax
 cmp rax,[rip+.Lu_filtered_count]
 jae .Lu_choose_loop
 mov [rip+.Lu_filtered_selection],rax
 jmp .Lu_choose_loop
.Lu_resume_commit_navigation:
 cmp qword ptr [rip+.Lu_filtered_count],0
 je .Lu_choose_loop
 mov qword ptr [rip+.Lu_resume_search_active],0
 jmp .Lu_choose_loop
.Lu_resume_printable:
 cmp qword ptr [rip+.Lu_resume_search_active],0
 jne .Lu_choose_query_regular
 mov al,[rip+.Lu_bytes]
 cmp al,32
 je .Lu_resume_open_preview
 cmp al,47
 je .Lu_resume_begin_search
 cmp al,107
 je .Lu_resume_move_up_checked
 cmp al,106
 je .Lu_resume_down
 mov qword ptr [rip+.Lu_resume_search_active],1
 jmp .Lu_choose_query_regular
.Lu_resume_move_up_checked:
 cmp qword ptr [rip+.Lu_filtered_selection],0
 je .Lu_choose_loop
 jmp .Lu_resume_move_up
.Lu_resume_begin_search:
 mov qword ptr [rip+.Lu_resume_search_active],1
 jmp .Lu_choose_loop
.Lu_resume_open_preview:
 cmp qword ptr [rip+.Lu_multi_enabled],0
 jne .Lu_multi_toggle
 cmp qword ptr [rip+.Lu_choice_reader],0
 je .Lu_choose_loop
 cmp qword ptr [rip+.Lu_filtered_count],0
 je .Lu_choose_loop
 call .Lu_open_read_preview
 jmp .Lu_choose_loop
.Lu_multi_toggle:
 cmp qword ptr [rip+.Lu_filtered_count],0
 je .Lu_choose_loop
 mov rcx,[rip+.Lu_choose_selection]
 cmp rcx,64
 jae .Lu_choose_loop
 mov rax,1
 shl rax,cl
 xor [rip+.Lu_multi_mask],rax
 jmp .Lu_choose_loop

.section .rodata
.Lu_resume_filter_label: .asciz "Filter: "
.Lu_resume_search_label: .asciz "Search: "
.Lu_resume_search_cursor: .asciz "▌"
.Lu_resume_search_controls: .asciz "Type to search · Enter to commit · Esc to clear"
.Lu_multi_controls: .asciz "Space to select · ↑↓ to navigate · Enter to delete · Esc to cancel"
.Lu_checked: .asciz "☑ "
.Lu_unchecked: .asciz "☐ "
.Lu_prompt_controls: .asciz "Enter to save · Esc to cancel"
.Lu_password_char: .asciz "*"
.Lu_two_spaces: .asciz "  "
.Lu_tabs_hint: .asciz "(Tab / ←→ to switch)"
.Lu_view_hint: .asciz "↑↓/PgUp/PgDn to scroll · Esc back"
.section .bss
.Lu_multi_enabled: .skip 8
.Lu_multi_mask: .skip 8
.Lu_prompt_mode: .skip 8
.Lu_prompt_secret: .skip 8
.Lu_custom_catalog: .skip 8
.Lu_custom_name: .skip 8
.Lu_custom_find: .skip 8
.Lu_custom_palette: .skip 8
.Lu_custom_gradient: .skip 8
.Lu_activity_hook: .skip 8
.Lu_activity_busy: .skip 8
.Lu_choice_tabs: .skip 8
.Lu_choice_tabs_count: .skip 8
.Lu_choice_tab_index: .skip 8
.Lu_box_list_top: .skip 8
.Lu_box_visible_start: .skip 8
.Lu_box_visible_rows: .skip 8
.Lu_choice_footer: .skip 8
.Lu_view_only: .skip 8
.Lu_view_item: .skip 24
.Lu_numbered: .skip 4194304
.section .text
.globl ui_view_text
# (titleZ,raw,len) displays a read-only, scrollable Markdown viewport.
ui_view_text:
 push rbx
 push r12
 push r13
 mov r12,rdi
 cmp rdx,1048575
 ja .Lu_view_invalid
 mov [rip+.Lu_read_raw_len],rdx
 lea rdi,[rip+.Lu_read_raw]
 mov rcx,rdx
 rep movsb
 mov qword ptr [rip+.Lu_view_only],1
 mov [rip+.Lu_view_item],r12
 mov edi,3
 call ui_set_choice_layout
 mov rdi,r12
 lea rsi,[rip+.Lu_view_item]
 mov edx,1
 xor ecx,ecx
 call ui_choose
 mov qword ptr [rip+.Lu_view_only],0
 xor edi,edi
 call ui_set_choice_layout
 xor eax,eax
 jmp .Lu_view_return
.Lu_view_invalid:
 mov rax,-22
.Lu_view_return:
 pop r13
 pop r12
 pop rbx
 ret
.globl ui_set_choice_tabs,ui_set_choice_footer
ui_set_choice_tabs:
 mov [rip+.Lu_choice_tabs],rdi
 mov [rip+.Lu_choice_tabs_count],rsi
 mov [rip+.Lu_choice_tab_index],rdx
 ret
ui_set_choice_footer:
 mov [rip+.Lu_choice_footer],rdi
 ret
.Lu_manager_tabs_view:
 push rbx
 push r12
 push r13
 mov rdi,[rip+.Lu_box_top]
 inc rdi
 mov esi,5
 call .Lu_move
 xor ebx,ebx
.Lu_manager_tabs_label:
 cmp rbx,[rip+.Lu_choice_tabs_count]
 jae .Lu_manager_tabs_hint
 lea rdi,[rip+.Lu_muted]
 cmp rbx,[rip+.Lu_choice_tab_index]
 jne .Lu_manager_tab_style
 lea rdi,[rip+.Lu_accent]
 call .Lu_z
 lea rdi,[rip+.Lu_inverse]
.Lu_manager_tab_style:
 call .Lu_z
 lea rdi,[rip+.Lu_space]
 call .Lu_z
 mov rax,[rip+.Lu_choice_tabs]
 mov rdi,[rax+rbx*8]
 call .Lu_z
 lea rdi,[rip+.Lu_space]
 call .Lu_z
 call .Lu_reset_color
 lea rdi,[rip+.Lu_two_spaces]
 call .Lu_z
 inc rbx
 jmp .Lu_manager_tabs_label
.Lu_manager_tabs_hint:
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_tabs_hint]
 call .Lu_z
 call .Lu_reset_color
 pop r13
 pop r12
 pop rbx
 ret
.globl ui_set_custom_theme_hooks
.globl ui_set_activity_hook
ui_set_activity_hook:
 mov [rip+.Lu_activity_hook],rdi
 ret
.globl ui_set_custom_gradient_hook
ui_set_custom_gradient_hook:
 mov [rip+.Lu_custom_gradient],rdi
 ret
ui_set_custom_theme_hooks:
 mov [rip+.Lu_custom_catalog],rdi
 mov [rip+.Lu_custom_name],rsi
 mov [rip+.Lu_custom_find],rdx
 mov [rip+.Lu_custom_palette],rcx
 ret
.globl ui_set_choice_multi,ui_get_choice_multi,ui_prompt_text
.globl ui_prompt_secret
ui_prompt_secret:
 push rbx
 mov qword ptr [rip+.Lu_prompt_secret],1
 call ui_prompt_text
 mov rbx,rax
 mov qword ptr [rip+.Lu_prompt_secret],0
 lea rdi,[rip+.Lu_query]
 xor eax,eax
 mov ecx,512
 rep stosb
 mov rax,rbx
 pop rbx
 ret
ui_set_choice_multi:
 mov [rip+.Lu_multi_enabled],rdi
 mov qword ptr [rip+.Lu_multi_mask],0
 ret
ui_get_choice_multi:
 mov rax,[rip+.Lu_multi_mask]
 ret
# Single-line text modal, sharing UTF-8 editing and cancellation with dialogs.
# (titleZ,out,capacity including NUL) -> length/-1.
ui_prompt_text:
 push rbx
 push r12
 push r13
 mov r12,rsi
 mov r13,rdx
 mov qword ptr [rip+.Lu_prompt_mode],1
 xor esi,esi
 xor edx,edx
 xor ecx,ecx
 call ui_choose
 mov qword ptr [rip+.Lu_prompt_mode],0
 test rax,rax
 js .Lu_prompt_done
 mov rbx,[rip+.Lu_query_len]
 cmp rbx,r13
 jae .Lu_prompt_failed
 mov rdi,r12
 lea rsi,[rip+.Lu_query]
 mov rcx,rbx
 rep movsb
 mov byte ptr [rdi],0
 mov rax,rbx
 jmp .Lu_prompt_done
.Lu_prompt_failed:
 mov rax,-1
.Lu_prompt_done:
 pop r13
 pop r12
 pop rbx
 ret

.section .text
# Source confirmation header: warning?; bolddefaulttool; muteddescription.
.Lu_style_approval:
 push rbx
 push r12
 push r13
 push r14
 push r15
 sub rsp,32
 lea r12,[rip+.Lu_preview]
 mov r13,[rip+.Lu_preview_len]
 cmp r13,3
 jb .Lu_style_approval_unavailable
 cmp word ptr [r12],0x203f
 jne .Lu_style_approval_unavailable
 movdqu xmm0,xmmword ptr [rip+.Lu_builder]
 movdqu [rsp],xmm0
 mov rax,[rip+.Lu_builder+16]
 mov [rsp+16],rax
 lea rax,[rip+.Lu_formatted]
 mov [rip+.Lu_builder],rax
 mov qword ptr [rip+.Lu_builder+8],4194304
 mov qword ptr [rip+.Lu_builder+16],0
 lea rdi,[rip+.Lu_warning]
 call .Lu_z
 mov rdi,r12
 mov esi,2
 call .Lu_put
 call .Lu_reset_color
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 mov r14d,2
.Lu_style_tool_word:
 cmp r14,r13
 jae .Lu_style_tool_word_done
 mov al,[r12+r14]
 cmp al,32
 je .Lu_style_tool_word_done
 cmp al,10
 je .Lu_style_tool_word_done
 inc r14
 jmp .Lu_style_tool_word
.Lu_style_tool_word_done:
 lea rdi,[r12+2]
 lea rsi,[r14-2]
 call .Lu_put
 call .Lu_reset_color
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 mov r15,r14
.Lu_style_tool_description:
 cmp r15,r13
 jae .Lu_style_tool_description_done
 cmp byte ptr [r12+r15],10
 je .Lu_style_tool_description_done
 inc r15
 jmp .Lu_style_tool_description
.Lu_style_tool_description_done:
 lea rdi,[r12+r14]
 mov rsi,r15
 sub rsi,r14
 call .Lu_put
 call .Lu_reset_color
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[r12+r15]
 mov rsi,r13
 sub rsi,r15
 lea rdx,[rip+.Lu_numbered]
 mov ecx,4194304
 mov r8,[rip+.Lu_columns]
 sub r8,4
 mov r9,[rip+.Lu_theme_resolved]
 sub rsp,16
 mov qword ptr [rsp],0
 call ui_format_numbered_preview
 add rsp,16
 test rax,rax
 js .Lu_style_numbered_fallback
 mov rsi,rax
 lea rdi,[rip+.Lu_numbered]
 jmp .Lu_style_numbered_put
.Lu_style_numbered_fallback:
 lea rdi,[r12+r15]
 mov rsi,r13
 sub rsi,r15
.Lu_style_numbered_put:
 call .Lu_put
 mov rax,[rip+.Lu_builder+16]
 mov rbx,rax
 movdqu xmm0,[rsp]
 movdqu xmmword ptr [rip+.Lu_builder],xmm0
 mov rax,[rsp+16]
 mov [rip+.Lu_builder+16],rax
 mov rax,rbx
 jmp .Lu_style_approval_done
.Lu_style_approval_unavailable:
 mov rax,-1
.Lu_style_approval_done:
 add rsp,32
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret

.section .rodata
.Lu_mouse_all_mode: .asciz "\033[?1002l\033[?1003h"
.Lu_mouse_drag_mode: .asciz "\033[?1003l\033[?1002h"
.section .bss
.Lu_mouse_packet: .skip 32
.Lu_mouse_drag: .skip 8
.Lu_mouse_dragged: .skip 8
.Lu_mouse_grab: .skip 8
.Lu_mouse_last_x: .skip 8
.Lu_mouse_last_y: .skip 8
.Lu_mouse_last_time: .skip 8
.Lu_mouse_clicks: .skip 8
.Lu_mouse_selection: .skip 16
.Lu_transcript_selected: .skip 8
.Lu_selection_anchor_row: .skip 8
.Lu_selection_anchor_col: .skip 8
.Lu_selection_focus_row: .skip 8
.Lu_selection_focus_col: .skip 8
.section .text
.Lu_pointer_event:
 push rbx
 push r12
 push r13
 push r14
 push r15
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_mouse_packet]
 call input_mouse_snapshot
 mov r12,[rip+.Lu_mouse_packet]
 test r12d,192
 jnz .Lu_pointer_none
 mov r13,[rip+.Lu_mouse_packet+8]
 mov r14,[rip+.Lu_mouse_packet+16]
 mov r15,[rip+.Lu_mouse_packet+24]
 mov eax,r12d
 and eax,3
 cmp eax,2
 je .Lu_pointer_context
 test r15,r15
 jnz .Lu_pointer_release
 test r12d,32
 jnz .Lu_pointer_move
 test eax,eax
 jnz .Lu_pointer_none
 # Menus receive hover/press selection before editor hit-testing.
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_pointer_scrollbar_press
 mov rax,[rip+.Lu_composer_top]
 add rax,[rip+.Lu_composer_rows]
 add rax,2
 mov rdx,r14
 sub rdx,rax
 js .Lu_pointer_scrollbar_press
 cmp rdx,5
 jae .Lu_pointer_scrollbar_press
 cmp rdx,[rip+.Lu_menu_count]
 jae .Lu_pointer_scrollbar_press
 mov [rip+.Lu_menu_index],rdx
 mov qword ptr [rip+.Lu_mouse_drag],4
 jmp .Lu_pointer_changed
.Lu_pointer_scrollbar_press:
 cmp r13,[rip+.Lu_columns]
 jne .Lu_pointer_editor_press
 cmp r14,[rip+.Lu_view_height]
 ja .Lu_pointer_none
 mov qword ptr [rip+.Lu_mouse_drag],3
 mov qword ptr [rip+.Lu_mouse_grab],0
 jmp .Lu_pointer_scrollbar
.Lu_pointer_editor_press:
 mov rax,[rip+.Lu_composer_top]
 inc rax
 cmp r14,rax
 jb .Lu_pointer_transcript_press
 add rax,[rip+.Lu_composer_rows]
 cmp r14,rax
 jae .Lu_pointer_none
 mov qword ptr [rip+.Lu_mouse_drag],1
 mov qword ptr [rip+.Lu_mouse_dragged],0
 mov qword ptr [rip+.Lu_transcript_selected],0
 mov ecx,r12d
 and ecx,4
 call .Lu_pointer_editor_position
 mov rax,[rip+.Lu_lasttick]
 mov rdx,rax
 sub rdx,[rip+.Lu_mouse_last_time]
 cmp rdx,400
 ja .Lu_pointer_first_click
 cmp r13,[rip+.Lu_mouse_last_x]
 jne .Lu_pointer_first_click
 cmp r14,[rip+.Lu_mouse_last_y]
 jne .Lu_pointer_first_click
 inc qword ptr [rip+.Lu_mouse_clicks]
 cmp qword ptr [rip+.Lu_mouse_clicks],3
 jbe .Lu_pointer_click_counted
.Lu_pointer_first_click:
 mov qword ptr [rip+.Lu_mouse_clicks],1
.Lu_pointer_click_counted:
 mov [rip+.Lu_mouse_last_time],rax
 mov [rip+.Lu_mouse_last_x],r13
 mov [rip+.Lu_mouse_last_y],r14
 cmp qword ptr [rip+.Lu_mouse_clicks],2
 jne .Lu_pointer_not_double
 lea rdi,[rip+.Lu_context]
 call input_select_word
 jmp .Lu_pointer_changed
.Lu_pointer_not_double:
 cmp qword ptr [rip+.Lu_mouse_clicks],3
 jne .Lu_pointer_changed
 lea rdi,[rip+.Lu_context]
 call input_select_line
 jmp .Lu_pointer_changed
.Lu_pointer_transcript_press:
 cmp r14,1
 jb .Lu_pointer_none
 cmp r14,[rip+.Lu_view_height]
 ja .Lu_pointer_none
 lea rax,[r14-1]
 add rax,[rip+.Lu_view_start]
 cmp rax,[rip+.Lu_linecount]
 jae .Lu_pointer_none
 mov [rip+.Lu_selection_anchor_row],rax
 mov [rip+.Lu_selection_focus_row],rax
 lea rdx,[r13-1]
 mov [rip+.Lu_selection_anchor_col],rdx
 mov [rip+.Lu_selection_focus_col],rdx
 mov qword ptr [rip+.Lu_transcript_selected],1
 mov qword ptr [rip+.Lu_mouse_drag],2
 jmp .Lu_pointer_changed
.Lu_pointer_move:
 cmp qword ptr [rip+.Lu_mouse_drag],0
 jne .Lu_pointer_dragging
 # With any-motion reporting, hover changes completion focus without submitting.
 cmp qword ptr [rip+.Lu_menu_count],0
 je .Lu_pointer_none
 mov rax,[rip+.Lu_composer_top]
 add rax,[rip+.Lu_composer_rows]
 add rax,2
 mov rdx,r14
 sub rdx,rax
 js .Lu_pointer_none
 cmp rdx,5
 jae .Lu_pointer_none
 cmp rdx,[rip+.Lu_menu_count]
 jae .Lu_pointer_none
 mov [rip+.Lu_menu_index],rdx
 jmp .Lu_pointer_changed
.Lu_pointer_dragging:
 mov qword ptr [rip+.Lu_mouse_dragged],1
 cmp qword ptr [rip+.Lu_mouse_drag],3
 je .Lu_pointer_scrollbar
 cmp qword ptr [rip+.Lu_mouse_drag],2
 je .Lu_pointer_transcript_move
 cmp qword ptr [rip+.Lu_mouse_drag],1
 jne .Lu_pointer_none
 mov ecx,1
 call .Lu_pointer_editor_position
 jmp .Lu_pointer_changed
.Lu_pointer_transcript_move:
 mov rax,r14
 cmp rax,1
 jae .Lu_pointer_transcript_min
 mov eax,1
.Lu_pointer_transcript_min:
 cmp rax,[rip+.Lu_view_height]
 cmova rax,[rip+.Lu_view_height]
 dec rax
 add rax,[rip+.Lu_view_start]
 mov [rip+.Lu_selection_focus_row],rax
 lea rax,[r13-1]
 mov [rip+.Lu_selection_focus_col],rax
 jmp .Lu_pointer_changed
.Lu_pointer_scrollbar:
 mov rax,[rip+.Lu_linecount]
 mov rcx,[rip+.Lu_view_height]
 cmp rax,rcx
 jbe .Lu_pointer_none
 lea rdx,[r14-1]
 imul rax,rdx
 xor edx,edx
 test rcx,rcx
 jz .Lu_pointer_none
 div rcx
 mov rdx,[rip+.Lu_linecount]
 sub rdx,rcx
 sub rdx,rax
 jns .Lu_pointer_scroll_store
 xor edx,edx
.Lu_pointer_scroll_store:
 mov [rip+.Lu_scroll],rdx
 jmp .Lu_pointer_changed
.Lu_pointer_release:
 mov rbx,[rip+.Lu_mouse_drag]
 mov qword ptr [rip+.Lu_mouse_drag],0
 cmp rbx,4
 jne .Lu_pointer_release_not_menu
 mov eax,INPUT_MENU_ACCEPT
 jmp .Lu_pointer_done
.Lu_pointer_release_not_menu:
 cmp rbx,1
 jne .Lu_pointer_release_transcript
 lea rdi,[rip+.Lu_context]
 lea rsi,[rip+.Lu_mouse_selection]
 call input_selection
 test rax,rax
 jz .Lu_pointer_changed
 mov rdi,[rip+.Lu_mouse_selection]
 mov rsi,[rip+.Lu_mouse_selection+8]
 call ui_copy_text
 jmp .Lu_pointer_changed
.Lu_pointer_release_transcript:
 cmp rbx,2
 jne .Lu_pointer_changed
 call .Lu_copy_transcript_selection
 jmp .Lu_pointer_changed
.Lu_pointer_context:
 test r15,r15
 jnz .Lu_pointer_none
 # This opens the same explicit terminal clipboard operation as /copy.
 call ui_last_assistant
 test rax,rax
 jz .Lu_pointer_none
 mov rdi,rax
 mov rsi,rdx
 call ui_copy_text
 jmp .Lu_pointer_changed
.Lu_pointer_editor_position:
 lea rdi,[rip+.Lu_context]
 mov rsi,r14
 sub rsi,[rip+.Lu_composer_top]
 dec rsi
 jns .Lu_pointer_editor_row
 xor esi,esi
.Lu_pointer_editor_row:
 add rsi,[rip+.Lu_editor_scroll]
 lea rdx,[r13-3]
 test rdx,rdx
 jns .Lu_pointer_editor_col
 xor edx,edx
.Lu_pointer_editor_col:
 jmp input_pointer
.Lu_pointer_changed:
 mov eax,INPUT_CHANGED
 jmp .Lu_pointer_done
.Lu_pointer_none:
 xor eax,eax
.Lu_pointer_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .bss
.Lu_selection_first_row: .skip 8
.Lu_selection_first_col: .skip 8
.Lu_selection_last_row: .skip 8
.Lu_selection_last_col: .skip 8
.Lu_mouse_plain: .skip 4194304
.Lu_selection_copy: .skip 1048576
.section .data
.Lu_selection_copy_builder: .quad .Lu_selection_copy,1048576,0
.section .text
.Lu_selection_bounds:
 mov r8,[rip+.Lu_selection_anchor_row]
 mov r9,[rip+.Lu_selection_anchor_col]
 mov r10,[rip+.Lu_selection_focus_row]
 mov r11,[rip+.Lu_selection_focus_col]
 cmp r8,r10
 jb .Lu_selection_ordered
 ja .Lu_selection_swap
 cmp r9,r11
 jbe .Lu_selection_ordered
.Lu_selection_swap:
 xchg r8,r10
 xchg r9,r11
.Lu_selection_ordered:
 mov [rip+.Lu_selection_first_row],r8
 mov [rip+.Lu_selection_first_col],r9
 mov [rip+.Lu_selection_last_row],r10
 mov [rip+.Lu_selection_last_col],r11
 ret
# Select bytes only at extended-grapheme boundaries, measured in terminal cells.
.Lu_mouse_column:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov r12,rdi
 mov r13,rsi
 mov r14,rdx
 xor r15d,r15d
 xor ebx,ebx
.Lu_mouse_column_next:
 cmp r15,r13
 jae .Lu_mouse_column_done
 cmp rbx,r14
 jae .Lu_mouse_column_done
 mov rdi,r12
 mov rsi,r13
 mov rdx,r15
 call ui_next_grapheme
 push rax
 sub rsp,8
 lea rdi,[r12+r15]
 mov rsi,rax
 sub rsi,r15
 call ui_text_width
 lea rcx,[rbx+rax]
 cmp rcx,r14
 ja .Lu_mouse_column_inside
 add rbx,rax
 add rsp,8
 pop r15
 jmp .Lu_mouse_column_next
.Lu_mouse_column_inside:
 add rsp,16
.Lu_mouse_column_done:
 mov rax,r15
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.Lu_copy_transcript_selection:
 push rbx
 push r12
 push r13
 push r14
 push r15
 cmp qword ptr [rip+.Lu_transcript_selected],0
 je .Lu_copy_selection_done
 call .Lu_selection_bounds
 mov r12,r8
 mov r13,r10
 mov qword ptr [rip+.Lu_selection_copy_builder+16],0
.Lu_copy_selection_row:
 cmp r12,r13
 ja .Lu_copy_selection_send
 cmp r12,[rip+.Lu_linecount]
 jae .Lu_copy_selection_send
 lea rax,[rip+.Lu_indices]
 mov rdx,[rax+r12*8]
 mov rsi,[rax+r12*8+8]
 sub rsi,rdx
 lea rdi,[rip+.Lu_flow]
 add rdi,rdx
 lea rdx,[rip+.Lu_mouse_plain]
 mov ecx,4194304
 call ui_sanitize
 test rax,rax
 js .Lu_copy_selection_done
 mov r14,rax
 lea rdx,[rip+.Lu_mouse_plain]
.Lu_copy_selection_trim:
 test r14,r14
 jz .Lu_copy_selection_start
 mov al,[rdx+r14-1]
 cmp al,10
 je .Lu_copy_selection_trim_byte
 cmp al,13
 jne .Lu_copy_selection_start
.Lu_copy_selection_trim_byte:
 dec r14
 jmp .Lu_copy_selection_trim
.Lu_copy_selection_start:
 xor edx,edx
 cmp r12,[rip+.Lu_selection_first_row]
 jne .Lu_copy_selection_start_ready
 mov rdx,[rip+.Lu_selection_first_col]
.Lu_copy_selection_start_ready:
 lea rdi,[rip+.Lu_mouse_plain]
 mov rsi,r14
 call .Lu_mouse_column
 mov r15,rax
 mov edx,65536
 cmp r12,[rip+.Lu_selection_last_row]
 jne .Lu_copy_selection_end_ready
 mov rdx,[rip+.Lu_selection_last_col]
.Lu_copy_selection_end_ready:
 lea rdi,[rip+.Lu_mouse_plain]
 mov rsi,r14
 call .Lu_mouse_column
 mov rdx,rax
 sub rdx,r15
 jbe .Lu_copy_selection_next
 lea rsi,[rip+.Lu_mouse_plain]
 add rsi,r15
 lea rdi,[rip+.Lu_selection_copy_builder]
 call qx_cat
 test rax,rax
 js .Lu_copy_selection_done
.Lu_copy_selection_next:
 cmp r12,r13
 je .Lu_copy_selection_send
 lea rdi,[rip+.Lu_selection_copy_builder]
 lea rsi,[rip+.Lu_mouse_selection_newline]
 mov edx,1
 call qx_cat
 test rax,rax
 js .Lu_copy_selection_done
 inc r12
 jmp .Lu_copy_selection_row
.Lu_copy_selection_send:
 mov rsi,[rip+.Lu_selection_copy_builder+16]
 test rsi,rsi
 jz .Lu_copy_selection_done
 lea rdi,[rip+.Lu_selection_copy]
 call ui_copy_text
.Lu_copy_selection_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Lu_mouse_selection_newline: .byte 10
.section .rodata
.Lu_agent_project_group: .asciz "Project Level"
.Lu_agent_user_group: .asciz "User Level"
.Lu_agent_builtin_group: .asciz "Built-in Agents"
.Lu_agent_builtin_suffix: .asciz " (built-in)"
.Lu_agent_marker: .asciz "●︎ "
.Lu_agent_using: .asciz "Using: "
.Lu_agent_count_suffix: .asciz " agents"
.section .bss
.Lu_agent_project_count: .skip 8
.Lu_agent_user_count: .skip 8
.Lu_agent_hit_count: .skip 8
.Lu_agent_hit_rows: .skip 256*8
.Lu_agent_hit_indices: .skip 256*8
.section .text
.globl ui_set_agent_groups
ui_set_agent_groups:
 mov [rip+.Lu_agent_project_count],rdi
 mov [rip+.Lu_agent_user_count],rsi
 ret
.Lu_agents_list_view:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov qword ptr [rip+.Lu_agent_hit_count],0
 mov r12,[rip+.Lu_box_top]
 add r12,4
 mov r13,[rip+.Lu_box_top]
 add r13,[rip+.Lu_box_height]
 sub r13,5
 xor ebx,ebx
 # Keep the selected row visible. Group boundaries consume two display rows.
 mov rax,[rip+.Lu_filtered_selection]
 mov rcx,r13
 sub rcx,r12
 sub rcx,3
 cmp rcx,1
 jae .Lu_agents_visible_budget
 mov ecx,1
.Lu_agents_visible_budget:
 cmp rax,rcx
 jb .Lu_agents_start
 mov rbx,rax
 sub rbx,rcx
 inc rbx
.Lu_agents_start:
 mov r14,-1
.Lu_agents_row:
 cmp rbx,[rip+.Lu_filtered_count]
 jae .Lu_agents_using
 cmp r12,r13
 jae .Lu_agents_using
 lea rax,[rip+.Lu_filtered]
 mov r15,[rax+rbx*8]
 mov edx,2
 cmp r15,[rip+.Lu_agent_project_count]
 jb .Lu_agents_is_project
 mov rax,[rip+.Lu_agent_project_count]
 add rax,[rip+.Lu_agent_user_count]
 cmp r15,rax
 jae .Lu_agents_group_ready
 mov edx,1
 jmp .Lu_agents_group_ready
.Lu_agents_is_project:
 xor edx,edx
.Lu_agents_group_ready:
 cmp rdx,r14
 je .Lu_agents_item
 mov r14,rdx
 mov rdi,r12
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 call .Lu_z
 lea rdi,[rip+.Lu_bold]
 call .Lu_z
 lea rdi,[rip+.Lu_agent_builtin_group]
 cmp r14,2
 je .Lu_agents_group_label
 lea rdi,[rip+.Lu_agent_user_group]
 cmp r14,1
 je .Lu_agents_group_label
 lea rdi,[rip+.Lu_agent_project_group]
.Lu_agents_group_label:
 call .Lu_z
 call .Lu_reset_color
 add r12,2
 cmp r12,r13
 jae .Lu_agents_using
.Lu_agents_item:
 mov rax,[rip+.Lu_agent_hit_count]
 lea rdx,[rip+.Lu_agent_hit_rows]
 mov [rdx+rax*8],r12
 lea rdx,[rip+.Lu_agent_hit_indices]
 mov [rdx+rax*8],rbx
 inc qword ptr [rip+.Lu_agent_hit_count]
 mov rdi,r12
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 cmp rbx,[rip+.Lu_filtered_selection]
 jne .Lu_agents_item_color
 lea rdi,[rip+.Lu_accent]
.Lu_agents_item_color:
 call .Lu_z
 lea rdi,[rip+.Lu_two_spaces]
 cmp rbx,[rip+.Lu_filtered_selection]
 jne .Lu_agents_item_marker
 lea rdi,[rip+.Lu_agent_marker]
.Lu_agents_item_marker:
 call .Lu_z
 imul rax,r15,24
 add rax,[rip+.Lu_choose_items]
 mov rdi,[rax]
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,12
 cmp r14,2
 jne .Lu_agents_item_label
 sub rsi,11
.Lu_agents_item_label:
 push rsi
 sub rsp,8
 call qx_strlen
 mov rsi,rax
 lea rdi,[rip+.Lu_clean]
 call ui_text_width
 add rsp,8
 pop rsi
 cmp rax,rsi
 cmovb rsi,rax
 lea rdi,[rip+.Lu_clean]
 call .Lu_field
 cmp r14,2
 jne .Lu_agents_item_next
 lea rdi,[rip+.Lu_muted]
 cmp rbx,[rip+.Lu_filtered_selection]
 jne .Lu_agents_suffix_style
 lea rdi,[rip+.Lu_accent]
.Lu_agents_suffix_style:
 call .Lu_z
 lea rdi,[rip+.Lu_agent_builtin_suffix]
 call .Lu_z
.Lu_agents_item_next:
 inc r12
 inc rbx
 jmp .Lu_agents_row
.Lu_agents_using:
 mov rdi,r13
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_agent_using]
 call .Lu_z
 lea rdi,[rip+.Lu_bytes]
 mov rsi,[rip+.Lu_choose_count]
 call qx_uint
 lea rdi,[rip+.Lu_bytes]
 mov rsi,rax
 call .Lu_put
 lea rdi,[rip+.Lu_agent_count_suffix]
 call .Lu_z
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
.section .rodata
.Lu_extensions_none: .asciz "No plugins or MCP servers installed."
.Lu_extensions_none_hint: .asciz "Use the Discover tab to find and install plugins."
.section .text
.Lu_extensions_list_view:
 push rbx
 push r12
 push r13
 push r14
 push r15
 mov qword ptr [rip+.Lu_agent_hit_count],0
 mov r12,[rip+.Lu_box_top]
 add r12,3
 cmp qword ptr [rip+.Lu_filtered_count],0
 jne .Lu_extensions_has_items
 mov rdi,r12
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_extensions_none]
 cmp qword ptr [rip+.Lu_choice_tab_index],0
 je .Lu_extensions_empty_label
 mov rdi,[rip+.Lu_choice_empty]
 test rdi,rdi
 jnz .Lu_extensions_empty_label
 lea rdi,[rip+.Lu_no_entries]
.Lu_extensions_empty_label:
 mov rsi,[rip+.Lu_columns]
 sub rsi,10
 call .Lu_field
 cmp qword ptr [rip+.Lu_choice_tab_index],0
 jne .Lu_extensions_view_done
 lea rdi,[r12+1]
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_extensions_none_hint]
 mov rsi,[rip+.Lu_columns]
 sub rsi,10
 call .Lu_field
 jmp .Lu_extensions_view_done
.Lu_extensions_has_items:
 mov r13,[rip+.Lu_box_top]
 add r13,[rip+.Lu_box_height]
 sub r13,3
 mov rax,r13
 sub rax,r12
 shr rax,1
 mov r14,[rip+.Lu_filtered_selection]
 sub r14,rax
 inc r14
 jns .Lu_extensions_first_item
 xor r14d,r14d
.Lu_extensions_first_item:
 cmp r12,r13
 jae .Lu_extensions_view_done
 cmp r14,[rip+.Lu_filtered_count]
 jae .Lu_extensions_view_done
 mov rax,[rip+.Lu_agent_hit_count]
 lea rdx,[rip+.Lu_agent_hit_rows]
 mov [rdx+rax*8],r12
 lea rdx,[rip+.Lu_agent_hit_indices]
 mov [rdx+rax*8],r14
 inc qword ptr [rip+.Lu_agent_hit_count]
 mov rdi,r12
 mov esi,5
 call .Lu_move
 lea rdi,[rip+.Lu_primary]
 cmp r14,[rip+.Lu_filtered_selection]
 jne .Lu_extensions_item_color
 lea rdi,[rip+.Lu_accent]
.Lu_extensions_item_color:
 call .Lu_z
 lea rdi,[rip+.Lu_two_spaces]
 cmp r14,[rip+.Lu_filtered_selection]
 jne .Lu_extensions_item_marker
 lea rdi,[rip+.Lu_agent_marker]
.Lu_extensions_item_marker:
 call .Lu_z
 lea rax,[rip+.Lu_filtered]
 mov rax,[rax+r14*8]
 imul r15,rax,24
 add r15,[rip+.Lu_choose_items]
 mov rdi,[r15]
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,12
 call .Lu_field
 mov rdi,[r15+8]
 test rdi,rdi
 jz .Lu_extensions_item_next
 lea rsi,[rip+.Lu_clean]
 mov edx,4096
 call .Lu_copyz_clean
 lea rdi,[r12+1]
 mov esi,7
 call .Lu_move
 lea rdi,[rip+.Lu_muted]
 call .Lu_z
 lea rdi,[rip+.Lu_clean]
 mov rsi,[rip+.Lu_columns]
 sub rsi,14
 call .Lu_field
.Lu_extensions_item_next:
 add r12,2
 inc r14
 jmp .Lu_extensions_first_item
.Lu_extensions_view_done:
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbx
 ret
