# Application-facing management workflows. Included by main.s after FUNC macros.
.text
FUNC app_agents_manage
    cmp qword ptr [rip+app_ui_active],0
    je .Um_agent_done
.Um_agent_list:
    lea rdi,[rip+ui_management_items]
    mov esi,58
    call ui_agent_catalog
    test rax,rax
    js .Um_agent_error
    mov r13,rax
    mov [rip+ui_custom_agent_count],rax
    imul rdi,rax,24
    lea rdx,[rip+ui_management_items]
    add rdi,rdx
    mov esi,6
    call ui_agent_builtin_catalog
    test rax,rax
    js .Um_agent_error
    add r13,rax
    xor r14d,r14d
    xor r15d,r15d
.Um_agent_scope_count:
    cmp r15,[rip+ui_custom_agent_count]
    jae .Um_agent_groups_ready
    mov rdi,r15
    call ui_management_item_scope
    cmp rax,1
    jne .Um_agent_scope_next
    inc r14
.Um_agent_scope_next:
    inc r15
    jmp .Um_agent_scope_count
.Um_agent_groups_ready:
    mov rdi,r14
    mov rsi,[rip+ui_custom_agent_count]
    sub rsi,r14
    call ui_set_agent_groups
    mov edi,5
    call ui_set_choice_layout
    lea rdi,[rip+ui_agent_list_controls]
    call ui_set_choice_footer
    lea rdi,[rip+ui_agents_empty]
    call ui_set_choice_empty_text
    lea rdi,[rip+ui_agents_title]
    lea rsi,[rip+ui_management_items]
    mov rdx,r13
    xor ecx,ecx
    call ui_choose
    mov r12,rax
    call app_ui_choice_reset
    test r12,r12
    js .Um_agent_done
    cmp r12,[rip+ui_custom_agent_count]
    jae .Um_builtin_agent_view
    mov rdi,r12
    call ui_management_item_scope
    mov [rip+ui_management_scope],rax
    imul rax,r12,24
    lea rdx,[rip+ui_management_items]
    mov r13,[rdx+rax+16]
    mov r14,[rdx+rax]
.Um_agent_actions_ready:
    jmp .Um_agent_actions
.Um_builtin_agent_view:
    imul rax,r12,24
    lea rdx,[rip+ui_management_items]
    mov r14,[rdx+rax]
    mov rdi,r14
    lea rsi,[rip+ui_management_raw]
    mov edx,65535
    call ui_agent_builtin_read
    test rax,rax
    js .Um_agent_error
    mov rdx,rax
    mov rdi,r14
    lea rsi,[rip+ui_management_raw]
    call ui_view_text
    jmp .Um_agent_list
.Um_agent_actions:
    lea rdi,[rip+ui_agent_action_title]
    lea rsi,[rip+ui_agent_action_items]
    mov edx,3
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .Um_agent_list
    cmp rax,2
    je .Um_agent_delete
    mov r15,rax
    mov rdi,r13
    lea rsi,[rip+ui_management_raw]
    mov edx,65535
    call ui_agent_read
    test rax,rax
    js .Um_agent_error
    test r15,r15
    jnz .Um_agent_edit
    mov rdx,rax
    mov rdi,r14
    lea rsi,[rip+ui_management_raw]
    call ui_view_text
    jmp .Um_agent_actions
.Um_agent_edit:
    mov r15,rax
    call ui_suspend
    lea rdi,[rip+ui_management_raw]
    mov rsi,r15
    lea rdx,[rip+ui_management_edited]
    mov ecx,65536
    mov r8,[rip+app_envp]
    call ui_external_edit
    mov r15,rax
    call ui_resume
    test r15,r15
    js .Um_agent_actions
    mov rdi,r14
    lea rsi,[rip+ui_management_edited]
    mov rdx,r15
    mov rcx,[rip+ui_management_scope]
    call ui_agent_save
    test rax,rax
    js .Um_agent_error
    jmp .Um_agent_list
.Um_agent_delete:
    lea rdi,[rip+ui_agent_delete_title]
    lea rsi,[rip+ui_delete_confirm_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    cmp rax,1
    jne .Um_agent_actions
    mov rdi,r13
    call ui_agent_delete
    test rax,rax
    js .Um_agent_error
    jmp .Um_agent_list
.Um_agent_error:
    lea rdi,[rip+ui_management_failed]
    call app_error
.Um_agent_done:
    END
FUNC app_agents_create
    lea rdi,[rip+ui_agent_name_title]
    lea rsi,[rip+ui_management_name]
    mov edx,128
    call ui_prompt_text
    test rax,rax
    jle .Um_create_done
    lea rdi,[rip+ui_scope_title]
    lea rsi,[rip+ui_scope_items]
    mov edx,2
    mov ecx,1
    call ui_choose
    test rax,rax
    js .Um_create_done
    mov [rip+ui_management_scope],rax
    lea rdi,[rip+ui_agent_prompt_title]
    lea rsi,[rip+ui_management_prompt]
    mov edx,512
    call ui_prompt_text
    test rax,rax
    jle .Um_create_done
    mov r13,rax
    mov qword ptr [rip+ui_management_builder+16],0
    CAT ui_management_builder,ui_agent_front
    lea rdi,[rip+ui_management_name]
    call qx_strlen
    lea rdi,[rip+ui_management_builder]
    lea rsi,[rip+ui_management_name]
    mov rdx,rax
    call qx_cat
    CAT ui_management_builder,ui_agent_middle
    lea rdi,[rip+ui_management_builder]
    lea rsi,[rip+ui_management_prompt]
    mov rdx,r13
    call qx_cat
    test rax,rax
    js .Um_create_failed
    lea rdi,[rip+ui_management_name]
    lea rsi,[rip+ui_management_raw]
    mov rdx,[rip+ui_management_builder+16]
    mov rcx,[rip+ui_management_scope]
    call ui_agent_save
    test rax,rax
    js .Um_create_failed
    lea rdi,[rip+ui_agent_created]
    call app_status
    jmp .Um_create_done
.Um_create_failed:
    lea rdi,[rip+ui_management_failed]
    call app_error
.Um_create_done:
    END
FUNC app_extensions_manage
    mov qword ptr [rip+ui_extensions_tab],0
    mov qword ptr [rip+ui_source_browsing],0
.Um_extensions_list:
    xor r13d,r13d
    mov rax,[rip+ui_extensions_tab]
    cmp rax,1
    je .Um_extensions_discover
    cmp rax,2
    je .Um_extensions_sources
    lea rdi,[rip+ui_management_items]
    mov esi,64
    call ui_extension_catalog
    test rax,rax
    js .Um_extensions_error
    mov r13,rax
    lea rdi,[rip+ui_extensions_empty]
    jmp .Um_extensions_empty_set
.Um_extensions_discover:
    cmp qword ptr [rip+ui_source_browsing],0
    jne .Um_discover_source
    lea rdi,[rip+ui_management_items]
    mov esi,64
    call ui_extension_source_catalog
    test rax,rax
    js .Um_extensions_error
    mov r13,rax
    lea rdi,[rip+ui_extensions_discover_empty]
    jmp .Um_extensions_empty_set
.Um_discover_source:
    mov qword ptr [rip+net_cancelled],0
    call ui_begin_response
    lea rdi,[rip+ui_extension_discovering]
    call ui_status
    mov rdi,[rip+ui_source_browsing]
    lea rsi,[rip+ui_management_items]
    mov edx,64
    mov rcx,[rip+app_envp]
    call ui_extension_discover
    mov r13,rax
    call ui_end_response
    test r13,r13
    js .Um_extensions_git_error
    lea rdi,[rip+ui_extensions_discover_empty]
    jmp .Um_extensions_empty_set
.Um_extensions_sources:
    lea rdi,[rip+ui_management_items]
    mov esi,63
    call ui_extension_source_catalog
    test rax,rax
    js .Um_extensions_error
    mov [rip+ui_source_count],rax
    imul rdx,rax,24
    lea rcx,[rip+ui_management_items]
    add rdx,rcx
    lea rcx,[rip+ui_source_add_label]
    mov [rdx],rcx
    mov qword ptr [rdx+8],0
    mov qword ptr [rdx+16],0
    lea r13,[rax+1]
    lea rdi,[rip+ui_extensions_sources_empty]
.Um_extensions_empty_set:
    call ui_set_choice_empty_text
    mov edi,6
    call ui_set_choice_layout
    lea rdi,[rip+ui_extensions_tabs]
    mov esi,3
    mov rdx,[rip+ui_extensions_tab]
    call ui_set_choice_tabs
    lea rdi,[rip+ui_extensions_controls]
    call ui_set_choice_footer
    lea rdi,[rip+ui_extensions_title]
    lea rsi,[rip+ui_management_items]
    mov rdx,r13
    xor ecx,ecx
    call ui_choose
    mov r12,rax
    call app_ui_choice_reset
    test r12,r12
    js .Um_extensions_done
    mov rax,r12
    shr rax,32
    cmp rax,1
    je .Um_extensions_next
    cmp rax,2
    je .Um_extensions_previous
    test r13,r13
    jz .Um_extensions_list
    mov r15,rax
    mov eax,r12d
    cmp qword ptr [rip+ui_extensions_tab],2
    je .Um_source_selected
    cmp qword ptr [rip+ui_extensions_tab],1
    je .Um_discover_selected
    cmp rax,r13
    jae .Um_extensions_list
    imul rax,rax,24
    lea rdx,[rip+ui_management_items]
    mov r13,[rdx+rax+16]
    mov r14,[rdx+rax]
    cmp r15,3
    je .Um_extension_toggle
    cmp r15,4
    je .Um_extension_favorite
.Um_extension_actions:
    mov rdi,r14
    lea rsi,[rip+ui_extension_action_items]
    mov edx,5
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .Um_extensions_list
    test rax,rax
    je .Um_extension_view
    cmp rax,3
    je .Um_extension_uninstall
    cmp rax,4
    je .Um_extension_update
    xor esi,esi
    cmp rax,1
    sete sil
    mov rdi,r13
    call ui_extension_set_enabled
    test rax,rax
    js .Um_extensions_error
    jmp .Um_extensions_reload
.Um_discover_selected:
    cmp qword ptr [rip+ui_source_browsing],0
    jne .Um_discover_plugin
    imul rax,rax,24
    lea rdx,[rip+ui_management_items]
    mov r13,[rdx+rax+16]
    jmp .Um_source_browse
.Um_discover_plugin:
    mov eax,r12d
    imul rax,rax,24
    lea rdx,[rip+ui_management_items]
    mov r13,[rdx+rax+16]
    mov r14,[rdx+rax]
.Um_discover_actions:
    mov rdi,r14
    lea rsi,[rip+ui_discover_action_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .Um_extensions_list
    jnz .Um_discover_install
    mov edi,r12d
    lea rsi,[rip+ui_management_raw]
    mov edx,65535
    call ui_extension_discover_item_read
    test rax,rax
    js .Um_extensions_error
    mov rdx,rax
    lea rsi,[rip+ui_management_raw]
    mov rdi,r14
    call ui_view_text
    jmp .Um_discover_actions
.Um_discover_install:
    lea rdi,[rip+ui_scope_title]
    lea rsi,[rip+ui_scope_items]
    mov edx,2
    mov ecx,1
    call ui_choose
    test rax,rax
    js .Um_discover_actions
    mov [rip+ui_management_scope],rax
    mov qword ptr [rip+net_cancelled],0
    call ui_begin_response
    lea rdi,[rip+ui_extension_installing]
    call ui_status
    mov rdi,r13
    mov rsi,r14
    mov rdx,[rip+ui_management_scope]
    mov rcx,[rip+app_envp]
    call ui_extension_install
    mov r15,rax
    call ui_end_response
    test r15,r15
    js .Um_extensions_git_error
    mov qword ptr [rip+ui_extensions_tab],0
    jmp .Um_extensions_reload
.Um_extension_favorite:
    mov rdi,r13
    call ui_extension_is_favorite
    test rax,rax
    js .Um_extensions_error
    xor eax,1
    mov rsi,rax
    mov rdi,r13
    call ui_extension_favorite
    test rax,rax
    js .Um_extensions_error
    jmp .Um_extensions_list
.Um_extension_update:
    mov qword ptr [rip+net_cancelled],0
    call ui_begin_response
    lea rdi,[rip+ui_extension_updating]
    call ui_status
    mov rdi,r13
    mov rsi,[rip+app_envp]
    call ui_extension_update
    mov r15,rax
    call ui_end_response
    test r15,r15
    js .Um_extensions_git_error
    jmp .Um_extensions_reload
.Um_source_selected:
    cmp rax,[rip+ui_source_count]
    je .Um_source_add
    cmp rax,[rip+ui_source_count]
    jae .Um_extensions_list
    imul rax,rax,24
    lea rdx,[rip+ui_management_items]
    mov r13,[rdx+rax+16]
    mov r14,[rdx+rax]
    lea rdi,[rip+ui_source_action_title]
    lea rsi,[rip+ui_source_action_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .Um_extensions_list
    jz .Um_source_browse
    mov rdi,r14
    call ui_extension_source_remove
    test rax,rax
    js .Um_extensions_error
    jmp .Um_extensions_list
.Um_source_browse:
    mov rdi,r13
    call qx_strlen
    cmp rax,4095
    ja .Um_extensions_error
    lea rdi,[rip+ui_source_browse_location]
    mov rsi,r13
    lea rcx,[rax+1]
    rep movsb
    lea rax,[rip+ui_source_browse_location]
    mov [rip+ui_source_browsing],rax
    mov qword ptr [rip+ui_extensions_tab],1
    jmp .Um_extensions_list
.Um_source_add:
    lea rdi,[rip+ui_source_name_title]
    lea rsi,[rip+ui_management_name]
    mov edx,128
    call ui_prompt_text
    test rax,rax
    jle .Um_extensions_list
    lea rdi,[rip+ui_source_location_title]
    lea rsi,[rip+ui_source_location]
    mov edx,512
    call ui_prompt_text
    test rax,rax
    jle .Um_extensions_list
    lea rdi,[rip+ui_management_name]
    lea rsi,[rip+ui_source_location]
    call ui_extension_source_add
    test rax,rax
    js .Um_extensions_error
    jmp .Um_extensions_list
.Um_extensions_git_error:
    call ui_management_last_error
    mov rdi,rax
    call app_error
    jmp .Um_extensions_list
.Um_extension_toggle:
    mov rdi,r13
    call ui_extension_enabled
    test rax,rax
    js .Um_extensions_error
    xor eax,1
    mov rsi,rax
    mov rdi,r13
    call ui_extension_set_enabled
    test rax,rax
    js .Um_extensions_error
    jmp .Um_extensions_reload
.Um_extension_view:
    mov rdi,r13
    lea rsi,[rip+ui_management_raw]
    mov edx,65535
    call ui_extension_read
    test rax,rax
    js .Um_extensions_error
    mov rdx,rax
    lea rsi,[rip+ui_management_raw]
    mov rdi,r14
    call ui_view_text
    jmp .Um_extension_actions
.Um_extension_uninstall:
    lea rdi,[rip+ui_extension_delete_title]
    lea rsi,[rip+ui_delete_confirm_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    cmp rax,1
    jne .Um_extension_actions
    mov rdi,r13
    call ui_extension_uninstall
    test rax,rax
    js .Um_extensions_error
.Um_extensions_reload:
    call app_reload_plugins
    jmp .Um_extensions_list
.Um_extensions_next:
    mov rax,[rip+ui_extensions_tab]
    inc rax
    cmp rax,3
    jb .Um_extensions_store_tab
    xor eax,eax
    jmp .Um_extensions_store_tab
.Um_extensions_previous:
    mov rax,[rip+ui_extensions_tab]
    dec rax
    jns .Um_extensions_store_tab
    mov eax,2
.Um_extensions_store_tab:
    mov [rip+ui_extensions_tab],rax
    jmp .Um_extensions_list
.Um_extensions_error:
    lea rdi,[rip+ui_management_failed]
    call app_error
.Um_extensions_done:
    END
FUNC app_reload_plugins
    mov rdi,[rip+app_envp]
    lea rsi,[rip+env_home]
    call qx_env_get
    mov rsi,rax
    lea rdi,[rip+app_cwd]
    call plugins_init
    END
.section .rodata
ui_agent_list_controls: .asciz "Enter to select, ↑↓ to navigate, Esc to close"
ui_agents_title: .asciz "Agents"
ui_agents_empty: .asciz "No subagents found. Use '/agents create' to create your first subagent."
ui_agent_action_title: .asciz "Choose Action"
ui_agent_view: .asciz "View agent"
ui_agent_edit: .asciz "Edit agent"
ui_agent_delete_label: .asciz "Delete agent"
ui_agent_delete_title: .asciz "Delete this agent definition?"
ui_agent_name_title: .asciz "Agent name (letters, numbers, hyphens)"
ui_agent_prompt_title: .asciz "Agent instructions"
ui_agent_created: .asciz "Agent created. Use /agents manage to view or edit it."
ui_scope_title: .asciz "Save to"
ui_scope_user: .asciz "User"
ui_scope_workspace: .asciz "Project"
ui_management_failed: .asciz "Management action failed. Check the selected file, permissions, and whether saving is enabled."
ui_extensions_title: .asciz "Extensions"
ui_extensions_installed: .asciz "Installed"
ui_extensions_discover: .asciz "Discover"
ui_extensions_sources: .asciz "Sources"
ui_extensions_empty: .asciz "No plugins or MCP servers installed. Use the Discover tab to find and install plugins."
ui_extensions_discover_empty: .asciz "No marketplace sources configured."
ui_extensions_sources_empty: .asciz "No marketplace sources configured."
ui_extensions_controls: .asciz "↑↓ navigate · Space enable/disable · f favorite · Enter details · Esc close"
ui_extension_view: .asciz "View details"
ui_extension_enable: .asciz "Enable"
ui_extension_disable: .asciz "Disable"
ui_extension_uninstall_label: .asciz "Uninstall"
ui_extension_update_label: .asciz "Update"
ui_extension_updating: .asciz "Updating extension..."
ui_extension_discovering: .asciz "Discovering extensions..."
ui_extension_installing: .asciz "Installing extension..."
ui_extension_install_label: .asciz "Install"
ui_source_add_label: .asciz "Add source"
ui_source_name_title: .asciz "Source name"
ui_source_location_title: .asciz "Marketplace source (local path or repository URL)"
ui_source_action_title: .asciz "Marketplace source"
ui_source_browse_label: .asciz "Browse plugins"
ui_source_remove_label: .asciz "Remove source"
ui_extension_delete_title: .asciz "Uninstall this extension and its files?"
LITERAL ui_agent_front,"---\nname: "
LITERAL ui_agent_middle,"\ndescription: Specialized coding assistant\n---\n\n"
.p2align 3
ui_agent_action_items: .quad ui_agent_view,0,0,ui_agent_edit,0,1,ui_agent_delete_label,0,2
ui_scope_items: .quad ui_scope_user,0,0,ui_scope_workspace,0,1
ui_extension_action_items: .quad ui_extension_view,0,0,ui_extension_enable,0,1,ui_extension_disable,0,2,ui_extension_uninstall_label,0,3,ui_extension_update_label,0,4
ui_discover_action_items: .quad ui_extension_view,0,0,ui_extension_install_label,0,1
ui_source_action_items: .quad ui_source_browse_label,0,0,ui_source_remove_label,0,1
ui_extensions_tabs: .quad ui_extensions_installed,ui_extensions_discover,ui_extensions_sources
.data
ui_management_builder: .quad ui_management_raw,65535,0
.bss
.p2align 3
ui_management_scope: .skip 8
ui_custom_agent_count: .skip 8
ui_management_items: .skip 64*24
ui_management_raw: .skip 65536
ui_management_edited: .skip 65536
ui_management_name: .skip 128
ui_management_prompt: .skip 512
ui_extensions_tab: .skip 8
ui_source_count: .skip 8
ui_source_browsing: .skip 8
ui_source_location: .skip 512
ui_source_browse_location: .skip 4096
.text
