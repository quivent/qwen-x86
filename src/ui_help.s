# Help tabs follow installed Qwen Code0.24.5 Help.tsx (chunk-OICDXWXP.js).
# Static plain UTF8; catalogue contents describe implemented native UI only.
.intel_syntax noprefix
.text
.globl ui_help_catalog
# out24Bitems, capacity_in_items ->3/-22/-28. Zero capacity measures.
# item={labelz,descriptionz,valueptr}; valueptr is a NUL-terminated plain body.
ui_help_catalog:
 test rsi,rsi
 jz .H_measure
 test rdi,rdi
 jz .H_invalid
 cmp rsi,3
 jb .H_capacity
 lea rax,[rip+.h_general_label]
 mov [rdi],rax
 lea rax,[rip+.h_general_description]
 mov [rdi+8],rax
 lea rax,[rip+.h_general]
 mov [rdi+16],rax
 lea rax,[rip+.h_commands_label]
 mov [rdi+24],rax
 lea rax,[rip+.h_commands_description]
 mov [rdi+32],rax
 lea rax,[rip+.h_commands]
 mov [rdi+40],rax
 lea rax,[rip+.h_custom_label]
 mov [rdi+48],rax
 lea rax,[rip+.h_custom_description]
 mov [rdi+56],rax
 lea rax,[rip+.h_custom]
 mov [rdi+64],rax
.H_measure:
 mov eax,3
 ret
.H_invalid:
 mov rax,-22
 ret
.H_capacity:
 mov rax,-28
 ret
.section .rodata
.h_general_label: .asciz "general"
.h_commands_label: .asciz "commands"
.h_custom_label: .asciz "custom-commands"
.h_general_description: .asciz "Shortcuts and terminal controls"
.h_commands_description: .asciz "Available native commands"
.h_custom_description: .asciz "Prompt commands and skills"
.h_general:
.ascii "Qwen Code understands your codebase, makes edits with your permission, and executes commands right from your terminal.\n\n"
.ascii "Shortcuts\n"
.ascii "@                   Add files or folders as context\n"
.ascii "!                   Run shell commands\n"
.ascii "/                   Open command menu\n"
.ascii "Tab                 Accept completion\n"
.ascii "Esc Esc             Clear input or cancel operation\n"
.ascii "Ctrl+L              Clear the screen\n"
.ascii "Ctrl+Q              Queue message for the next turn\n"
.ascii "Ctrl+J              Insert a newline\n"
.ascii "Shift+Tab           Cycle approval modes\n"
.ascii "Alt+←/→             Jump through words\n"
.ascii "↑/↓                 Cycle prompt history\n\n"
.ascii "More controls\n"
.ascii "Ctrl+R              Search prompt history\n"
.ascii "Ctrl+X              Edit prompt in external editor\n"
.ascii "Ctrl+Z              Undo prompt edit\n"
.ascii "Ctrl+Y              Retry a failed request\n"
.ascii "Ctrl+O              Expand or collapse tool output\n"
.ascii "PgUp/PgDn           Scroll conversation\n"
.ascii "Ctrl+End            Follow latest output\n"
.ascii "Ctrl+C              Cancel the current operation\n\n"
.asciz "For more help: https://qwenlm.github.io/qwen-code-docs/"
.h_commands:
.ascii "/help               Show help tabs\n"
.ascii "/new                Start a new conversation\n"
.ascii "/clear, /reset      Start a new conversation\n"
.ascii "/retry              Retry a failed request\n"
.ascii "/model              Select a model\n"
.ascii "/model NAME         Use a provider model name\n"
.ascii "/theme              Preview and select a theme\n"
.ascii "/approval-mode      Select the tool approval mode\n"
.ascii "/approval-mode MODE Set default, auto-edit, plan, or yolo\n"
.ascii "/resume, /sessions  Browse and resume saved conversations\n"
.ascii "/session            Show the current session file\n"
.ascii "/plugins            List loaded prompt commands and skills\n"
.ascii "/agents             Show read-only subagent status\n"
.ascii "/copy latex N       Request clipboard copy of LaTeX block N\n"
.ascii "/copy mermaid N     Request clipboard copy of Mermaid block N\n"
.ascii "/about              Show client information\n"
.asciz "/quit               Exit"
.h_custom:
.ascii "Custom commands\n\n"
.ascii "Use /plugins to see the prompt commands and skills loaded for this workspace.\n\n"
.ascii "/plugin:command arguments\n"
.ascii "Invoke a loaded plugin prompt command. Arguments replace $ARGUMENTS when the prompt contains that placeholder.\n\n"
.ascii "/skill plugin:skill arguments\n"
.ascii "Invoke a loaded SKILL.md instruction with optional arguments.\n\n"
.ascii "Plugin folders\n"
.ascii "~/.config/qwen-go/plugins\n"
.ascii ".qwen-go/plugins (workspace)\n\n"
.ascii "Prompts and skills supply instructions to the model. Tool execution still follows the selected approval mode.\n\n"
.asciz "Optional configured MCP servers connect only after approval; loading a plugin does not start a server."
.section .note.GNU-stack,"",@progbits

.text
.globl ui_help_format
# tabIndex,available_body_columns,out,capacity ->plain UTF8 bytes/-22/-28.
# Qwen Help.tsx uses (bodyWidth-2)/2 columns,20-cell key and2-cell gap.
ui_help_format:
 push rbx
 push rbp
 push r12
 push r13
 push r14
 push r15
 sub rsp,104
 mov rbx,rsp
 mov [rbx],rdx
 mov [rbx+8],rcx
 mov qword ptr [rbx+16],0
 mov qword ptr [rbx+24],0
 cmp rdi,3
 jae .F_invalid
 test rsi,rsi
 jnz .F_have_cols
 mov esi,90
.F_have_cols:
 cmp rsi,24
 jb .F_invalid
 cmp rsi,4096
 ja .F_invalid
 mov [rbx+32],rsi
 test rdi,rdi
 jnz .F_other_tab
 mov rax,rsi
 sub rax,2
 shr rax,1
 mov [rbx+40],rax
 cmp rsi,46
 jae .F_two_columns
 mov [rbx+40],rsi
.F_two_columns:
 lea r12,[rip+.h_intro_format]
 mov r13d,OFFSET FLAT:.h_intro_format_len
 xor ebp,ebp
.F_intro_word:
 test r13,r13
 jz .F_intro_done
 xor r14d,r14d
.F_intro_scan:
 cmp r14,r13
 jae .F_intro_found
 cmp byte ptr [r12+r14],' '
 je .F_intro_found
 inc r14
 jmp .F_intro_scan
.F_intro_found:
 test rbp,rbp
 jz .F_intro_emit
 lea rax,[rbp+r14+1]
 cmp rax,[rbx+32]
 jbe .F_intro_space
 call .F_newline
 xor ebp,ebp
 jmp .F_intro_emit
.F_intro_space:
 mov esi,1
 call .F_spaces
 inc rbp
.F_intro_emit:
 mov rdi,r12
 mov rsi,r14
 call .F_put
 add rbp,r14
 add r12,r14
 sub r13,r14
 test r13,r13
 jz .F_intro_done
 inc r12
 dec r13
 jmp .F_intro_word
.F_intro_done:
 call .F_newline
 call .F_newline
 lea rdi,[rip+.h_shortcuts_format]
 mov esi,10
 call .F_put
 xor r15d,r15d
.F_rows:
 cmp qword ptr [rbx+32],46
 jb .F_single_rows
 cmp r15,6
 jae .F_rows_done
 mov rdi,r15
 call .F_shortcut
 cmp r15,5
 jae .F_row_end
 mov esi,2
 call .F_spaces
 lea rdi,[r15+6]
 call .F_shortcut
 jmp .F_row_end
.F_single_rows:
 cmp r15,11
 jae .F_rows_done
 mov rdi,r15
 call .F_shortcut
.F_row_end:
 call .F_newline
 inc r15
 jmp .F_rows
.F_rows_done:
 call .F_newline
 lea r12,[rip+.h_docs_format]
 mov r13d,OFFSET FLAT:.h_docs_format_len
.F_docs_chunk:
 mov r14,r13
 cmp r14,[rbx+32]
 jbe .F_docs_emit
 mov r14,[rbx+32]
.F_docs_emit:
 mov rdi,r12
 mov rsi,r14
 call .F_put
 add r12,r14
 sub r13,r14
 jz .F_complete
 call .F_newline
 jmp .F_docs_chunk
 jmp .F_complete
.F_other_tab:
 lea r12,[rip+.h_commands]
 cmp rdi,1
 je .F_other_selected
 lea r12,[rip+.h_custom]
.F_other_selected:
 mov rdi,r12
 call .F_strlen
 mov rdi,r12
 mov rsi,rax
 call .F_put
.F_complete:
 mov rax,[rbx+24]
 test rax,rax
 jnz .F_return
 mov rax,[rbx+16]
 jmp .F_return
.F_invalid:
 mov rax,-22
.F_return:
 add rsp,104
 pop r15
 pop r14
 pop r13
 pop r12
 pop rbp
 pop rbx
 ret
# index ->one padded column; key cells precomputed for fixed UTF8 literals.
.F_shortcut:
 imul rax,rdi,40
 lea rdx,[rip+.h_shortcuts_table]
 add rdx,rax
 mov [rbx+48],rdx
 mov rdi,[rdx]
 lea rax,[rip+.h_shortcuts_table]
 add rdi,rax
 mov rsi,[rdx+8]
 call .F_put
 mov rdx,[rbx+48]
 mov esi,20
 sub rsi,[rdx+16]
 call .F_spaces
 mov rdx,[rbx+48]
 mov rsi,[rdx+32]
 mov rax,[rbx+40]
 sub rax,21
 mov qword ptr [rbx+56],0
 cmp rsi,rax
 jbe .F_description
 mov rsi,rax
 dec rsi
 mov qword ptr [rbx+56],1
.F_description:
 mov [rbx+64],rsi
 mov rdi,[rdx+24]
 lea rax,[rip+.h_shortcuts_table]
 add rdi,rax
 call .F_put
 cmp qword ptr [rbx+56],0
 je .F_description_padding
 lea rdi,[rip+.h_ellipsis]
 mov esi,3
 call .F_put
 inc qword ptr [rbx+64]
.F_description_padding:
 mov rsi,[rbx+40]
 sub rsi,20
 sub rsi,[rbx+64]
 call .F_spaces
 ret
.F_strlen:
 xor eax,eax
.F_strlen_next:
 cmp byte ptr [rdi+rax],0
 je .F_strlen_done
 inc rax
 jmp .F_strlen_next
.F_strlen_done:
 ret
.F_spaces:
 test rsi,rsi
 jz .F_spaces_done
 mov [rbx+72],rsi
.F_spaces_next:
 lea rdi,[rip+.h_space_format]
 mov esi,1
 call .F_put
 dec qword ptr [rbx+72]
 jnz .F_spaces_next
.F_spaces_done:
 ret
.F_newline:
 lea rdi,[rip+.h_newline_format]
 mov esi,1
 jmp .F_put
.F_put:
 cmp qword ptr [rbx+24],0
 jne .F_put_done
 mov rax,[rbx+16]
 add rax,rsi
 jc .F_capacity
 cmp rax,[rbx+8]
 ja .F_capacity
 mov rdx,[rbx]
 test rdx,rdx
 jz .F_bad_output
 mov rcx,rsi
 mov rsi,rdi
 lea rdi,[rdx]
 add rdi,[rbx+16]
 rep movsb
 mov [rbx+16],rax
.F_put_done:
 ret
.F_capacity:
 mov qword ptr [rbx+24],-28
 ret
.F_bad_output:
 mov qword ptr [rbx+24],-22
 ret
.section .rodata
.h_intro_format: .ascii "Qwen Code understands your codebase, makes edits with your permission, and executes commands right from your terminal."
.equ .h_intro_format_len,.-.h_intro_format
.h_shortcuts_format: .ascii "Shortcuts\n"
.h_docs_format: .ascii "For more help: https://qwenlm.github.io/qwen-code-docs/"
.equ .h_docs_format_len,.-.h_docs_format
.h_space_format: .ascii " "
.h_newline_format: .ascii "\n"
.h_ellipsis: .ascii "…"
.balign 8
.h_shortcuts_table:
 .quad .h_key_0-.h_shortcuts_table,1,1,.h_desc_0-.h_shortcuts_table,31
 .quad .h_key_1-.h_shortcuts_table,1,1,.h_desc_1-.h_shortcuts_table,18
 .quad .h_key_2-.h_shortcuts_table,1,1,.h_desc_2-.h_shortcuts_table,17
 .quad .h_key_3-.h_shortcuts_table,3,3,.h_desc_3-.h_shortcuts_table,17
 .quad .h_key_4-.h_shortcuts_table,7,7,.h_desc_4-.h_shortcuts_table,31
 .quad .h_key_5-.h_shortcuts_table,6,6,.h_desc_5-.h_shortcuts_table,16
 .quad .h_key_6-.h_shortcuts_table,6,6,.h_desc_6-.h_shortcuts_table,31
 .quad .h_key_7-.h_shortcuts_table,6,6,.h_desc_7-.h_shortcuts_table,16
 .quad .h_key_8-.h_shortcuts_table,9,9,.h_desc_8-.h_shortcuts_table,20
 .quad .h_key_9-.h_shortcuts_table,11,7,.h_desc_9-.h_shortcuts_table,18
 .quad .h_key_10-.h_shortcuts_table,7,3,.h_desc_10-.h_shortcuts_table,20
.h_key_0: .ascii "@"
.h_desc_0: .ascii "Add files or folders as context"
.h_key_1: .ascii "!"
.h_desc_1: .ascii "Run shell commands"
.h_key_2: .ascii "/"
.h_desc_2: .ascii "Open command menu"
.h_key_3: .ascii "Tab"
.h_desc_3: .ascii "Accept completion"
.h_key_4: .ascii "Esc Esc"
.h_desc_4: .ascii "Clear input or cancel operation"
.h_key_5: .ascii "Ctrl+L"
.h_desc_5: .ascii "Clear the screen"
.h_key_6: .ascii "Ctrl+Q"
.h_desc_6: .ascii "Queue message for the next turn"
.h_key_7: .ascii "Ctrl+J"
.h_desc_7: .ascii "Insert a newline"
.h_key_8: .ascii "Shift+Tab"
.h_desc_8: .ascii "Cycle approval modes"
.h_key_9: .ascii "Alt+←/→"
.h_desc_9: .ascii "Jump through words"
.h_key_10: .ascii "↑/↓"
.h_desc_10: .ascii "Cycle prompt history"
.section .note.GNU-stack,"",@progbits
