# Native controllers for source AuthDialog/SettingsDialog. Included by main.s.
# Qwen0.24.5 AuthDialog.tsx main categories and provider preset data are adapted
# under Apache2. Every selectable protocol here has a native transport adapter.
.section .text
FUNC app_auth_manage
    cmp qword ptr [rip+app_ui_active],0
    jne .PC_auth_main
    lea rdi,[rip+.PC_interactive_only]
    call app_status
    END
.PC_auth_main:
    call app_ui_choice_reset
    mov edi,1
    call ui_set_choice_layout
    lea rdi,[rip+.PC_auth_title]
    lea rsi,[rip+.PC_main_items]
    mov edx,3
    xor ecx,ecx
    call ui_choose
    call app_ui_choice_reset
    test rax,rax
    js .PC_auth_done
    cmp rax,2
    je .PC_custom
    mov r12,rax
    lea rsi,[rip+.PC_alibaba_items]
    mov edx,3
    lea rdi,[rip+.PC_alibaba_title]
    test r12,r12
    jz .PC_submenu
    lea rsi,[rip+.PC_thirdparty_items]
    mov edx,9
    lea rdi,[rip+.PC_thirdparty_title]
.PC_submenu:
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_auth_main
    test r12,r12
    jz .PC_preset_index
    add rax,3
.PC_preset_index:
    imul rax,rax,80
    lea r12,[rip+.PC_presets]
    add r12,rax
    mov [rip+.PC_selected_preset],r12
    mov rax,[r12+16]
    mov [rip+.PC_selected_protocol],rax
    mov rax,[r12+64]
    mov [rip+.PC_default_base],rax
    cmp qword ptr [r12+40],1
    jbe .PC_base_ready
    lea rdi,[rip+.PC_endpoint_title]
    mov rsi,[r12+32]
    mov rdx,[r12+40]
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_auth_main
    imul rax,rax,24
    mov rdx,[r12+32]
    mov rax,[rdx+rax+16]
    mov [rip+.PC_default_base],rax
.PC_base_ready:
    mov rsi,[rip+.PC_default_base]
    lea rdi,[rip+.PC_base]
    mov edx,2048
    call .PC_copyz
    jmp .PC_collect_key
.PC_custom:
    mov qword ptr [rip+.PC_selected_preset],0
    lea rdi,[rip+.PC_protocol_title]
    lea rsi,[rip+.PC_protocol_items]
    mov edx,3
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_auth_main
    lea rdx,[rip+.PC_protocol_values]
    mov rax,[rdx+rax*8]
    mov [rip+.PC_selected_protocol],rax
    mov rdi,rax
    lea rsi,[rip+.PC_openai]
    call qx_streq
    test eax,eax
    jz .PC_custom_base
    lea rdi,[rip+.PC_wire_title]
    lea rsi,[rip+.PC_wire_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_auth_main
    test rax,rax
    jz .PC_custom_base
    lea rax,[rip+.PC_responses]
    mov [rip+.PC_selected_protocol],rax
.PC_custom_base:
    lea rdi,[rip+.PC_base_title]
    lea rsi,[rip+.PC_base]
    mov edx,2048
    call ui_prompt_text
    test rax,rax
    js .PC_auth_main
    jnz .PC_validate_base
    mov rdi,[rip+.PC_selected_protocol]
    call .PC_protocol_default
    mov rsi,rax
    lea rdi,[rip+.PC_base]
    mov edx,2048
    call .PC_copyz
.PC_validate_base:
    lea rdi,[rip+.PC_base]
    call .PC_valid_base
    test eax,eax
    jz .PC_auth_invalid
.PC_collect_key:
    call .PC_key_form
    test rax,rax
    js .PC_auth_main
    mov r12,[rip+.PC_selected_preset]
    test r12,r12
    jz .PC_model_input
    cmp qword ptr [r12+56],0
    je .PC_model_input
    lea rdi,[rip+.PC_models_title]
    mov rsi,[r12+48]
    mov rdx,[r12+56]
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_auth_main
    imul rax,rax,24
    mov rdx,[r12+48]
    mov rsi,[rdx+rax+16]
    lea rdi,[rip+.PC_model]
    mov edx,1024
    call .PC_copyz
    jmp .PC_auth_review
.PC_model_input:
    lea rdi,[rip+.PC_models_title]
    lea rsi,[rip+.PC_model]
    mov edx,1024
    call ui_prompt_text
    test rax,rax
    js .PC_auth_main
    jz .PC_auth_invalid
.PC_auth_review:
    call .PC_build_review
    mov edi,1
    call ui_set_choice_layout
    lea rdi,[rip+.PC_info]
    call ui_set_choice_metadata
    lea rdi,[rip+.PC_review_title]
    lea rsi,[rip+.PC_review_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    mov r12,rax
    call app_ui_choice_reset
    test r12,r12
    jne .PC_auth_main
    call .PC_commit_connection
    test rax,rax
    js .PC_auth_save_error
    lea rdi,[rip+.PC_connected]
    call app_status
    jmp .PC_auth_done
.PC_auth_invalid:
    lea rdi,[rip+.PC_invalid]
    call app_error
    jmp .PC_auth_done
.PC_auth_save_error:
    lea rdi,[rip+.PC_save_error]
    call app_error
.PC_auth_done:
    END

# Key form returns0ready/-1cancel/-error; secret text is never rendered.
FUNC .PC_key_form
    lea rdi,[rip+.PC_key_title]
    lea rsi,[rip+.PC_key_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_key_cancel
    test rax,rax
    jnz .PC_key_environment
    lea rdi,[rip+.PC_key_title]
    lea rsi,[rip+.PC_key]
    mov edx,4096
    call ui_prompt_secret
    test rax,rax
    jle .PC_key_cancel
    mov byte ptr [rip+.PC_env],0
    lea rax,[rip+.PC_stored]
    mov [rip+.PC_key_source],rax
    xor eax,eax
    END
.PC_key_environment:
    lea rdi,[rip+.PC_env_title]
    lea rsi,[rip+.PC_env]
    mov edx,256
    call ui_prompt_text
    test rax,rax
    jle .PC_key_cancel
    mov rdi,[rip+app_envp]
    lea rsi,[rip+.PC_env]
    call qx_env_get
    test rax,rax
    jz .PC_key_missing
    cmp byte ptr [rax],0
    je .PC_key_missing
    mov rsi,rax
    lea rdi,[rip+.PC_key]
    mov edx,4096
    call .PC_copyz
    test rax,rax
    js .PC_key_cancel
    lea rax,[rip+.PC_environment]
    mov [rip+.PC_key_source],rax
    xor eax,eax
    END
.PC_key_missing:
    lea rdi,[rip+.PC_missing_env]
    call app_error
.PC_key_cancel:
    mov rax,-1
    END

FUNC .PC_commit_connection
    mov rax,[rip+.PC_selected_protocol]
    mov [rip+.PC_connection],rax
    lea rax,[rip+.PC_model]
    mov [rip+.PC_connection+8],rax
    lea rax,[rip+.PC_base]
    mov [rip+.PC_connection+16],rax
    lea rax,[rip+.PC_env]
    mov [rip+.PC_connection+24],rax
    lea rax,[rip+.PC_key]
    mov [rip+.PC_connection+32],rax
    mov rdi,[rip+.PC_key_source]
    mov [rip+.PC_connection+40],rdi
    lea rsi,[rip+.PC_environment]
    call qx_streq
    test eax,eax
    jz .PC_commit_ready
    lea rax,[rip+.PC_empty]
    mov [rip+.PC_connection+32],rax
.PC_commit_ready:
    lea rdi,[rip+.PC_connection]
    xor esi,esi
    call ui_preferences_set_connection
    test rax,rax
    js .PC_commit_done
    mov rax,[rip+.PC_selected_protocol]
    mov [rip+app_protocol],rax
    lea rsi,[rip+.PC_model]
    lea rdi,[rip+.PC_active_model]
    mov edx,1024
    call .PC_copyz
    lea rax,[rip+.PC_active_model]
    mov [rip+app_model],rax
    lea rsi,[rip+.PC_base]
    lea rdi,[rip+.PC_active_base]
    mov edx,2048
    call .PC_copyz
    lea rax,[rip+.PC_active_base]
    mov [rip+app_base],rax
    lea rsi,[rip+.PC_key]
    lea rdi,[rip+.PC_active_key]
    mov edx,4096
    call .PC_copyz
    lea rax,[rip+.PC_active_key]
    mov [rip+app_key],rax
    mov qword ptr [rip+app_oauth],0
    mov qword ptr [rip+app_needs_auth],0
    mov qword ptr [rip+app_auth_type_explicit],1
    mov qword ptr [rip+app_base_explicit],1
    mov qword ptr [rip+app_model_explicit],1
    call http_close
    call app_build_url
    mov rdi,[rip+app_model]
    call ui_set_model
    lea rdi,[rip+ui_auth_key]
    call ui_set_auth
    xor eax,eax
.PC_commit_done:
    END

FUNC app_provider_account
.PC_account_menu:
    call app_ui_choice_reset
    lea rdi,[rip+.PC_account_title]
    lea rsi,[rip+.PC_account_items]
    mov edx,3
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_account_done
    test rax,rax
    jz .PC_account_info
    cmp rax,1
    je .PC_oauth_login
    lea rdi,[rip+.PC_disconnect_title]
    lea rsi,[rip+.PC_disconnect_items]
    mov edx,2
    xor ecx,ecx
    call ui_choose
    cmp rax,1
    jne .PC_account_done
    mov rdi,[rip+app_envp]
    lea rsi,[rip+env_home]
    call qx_env_get
    test rax,rax
    jz .PC_account_done
    mov r12,rax
    cmp qword ptr [rip+app_oauth],0
    je .PC_disconnect_key
    mov rdi,r12
    call oauth_logout
    test rax,rax
    js .PC_account_error
.PC_disconnect_key:
    lea rdi,[rip+.PC_empty]
    xor esi,esi
    call ui_preferences_set_api_key
    test rax,rax
    js .PC_account_error
    lea rdi,[rip+.PC_none]
    xor esi,esi
    call ui_preferences_set_key_source
    test rax,rax
    js .PC_account_error
    mov qword ptr [rip+app_oauth],0
    mov qword ptr [rip+app_needs_auth],1
    lea rax,[rip+.PC_empty]
    mov [rip+app_key],rax
    call http_close
    lea rdi,[rip+.PC_disconnected_label]
    call ui_set_auth
    lea rdi,[rip+.PC_disconnected]
    call app_status
    jmp .PC_account_done
.PC_oauth_login:
    mov rdi,[rip+app_envp]
    lea rsi,[rip+env_home]
    call qx_env_get
    test rax,rax
    jz .PC_account_error
    mov r12,rax
    call ui_suspend
    mov rdi,r12
    call oauth_login
    mov r13,rax
    call ui_resume
    test r13,r13
    js .PC_account_oauth_error
    mov qword ptr [rip+app_oauth],1
    mov qword ptr [rip+app_needs_auth],0
    mov qword ptr [rip+app_model_explicit],0
    mov qword ptr [rip+app_base_explicit],0
    lea rax,[rip+.PC_qwen_oauth]
    mov [rip+app_protocol],rax
    call app_oauth_config
    lea rdi,[rip+.PC_qwen_oauth]
    xor esi,esi
    call ui_preferences_set_auth_type
    mov rdi,[rip+app_model]
    call ui_set_model
    lea rdi,[rip+ui_auth_oauth]
    call ui_set_auth
    lea rdi,[rip+.PC_oauth_connected]
    call app_status
    jmp .PC_account_done
.PC_account_info:
    call .PC_build_account
    lea rdi,[rip+.PC_info]
    call qx_strlen
    mov rdx,rax
    lea rsi,[rip+.PC_info]
    lea rdi,[rip+.PC_account_title]
    call ui_view_text
    jmp .PC_account_menu
.PC_account_oauth_error:
    call oauth_error
    mov rdi,rax
    call app_error
    jmp .PC_account_done
.PC_account_error:
    lea rdi,[rip+.PC_save_error]
    call app_error
.PC_account_done:
    END

FUNC app_provider_settings
.PC_settings_loop:
    call app_ui_choice_reset
    mov rax,[rip+app_model]
    mov [rip+.PC_settings_items+8],rax
    mov rax,[rip+app_base]
    mov [rip+.PC_settings_items+24+8],rax
    mov rax,[rip+app_protocol]
    mov [rip+.PC_settings_items+48+8],rax
    lea rdi,[rip+.PC_settings_title]
    lea rsi,[rip+.PC_settings_items]
    mov edx,7
    xor ecx,ecx
    call ui_choose
    test rax,rax
    js .PC_settings_done
    cmp rax,0
    je .PC_settings_model
    cmp rax,1
    je .PC_settings_base
    cmp rax,2
    je .PC_settings_auth
    cmp rax,3
    je .PC_settings_key
    cmp rax,4
    je .PC_settings_theme
    cmp rax,5
    je .PC_settings_approval
    call app_provider_account
    jmp .PC_settings_loop
.PC_settings_model:
    lea rdi,[rip+.PC_model_command]
    call app_ui_command
    jmp .PC_settings_loop
.PC_settings_auth:
    call app_auth_manage
    jmp .PC_settings_loop
.PC_settings_theme:
    lea rdi,[rip+.PC_theme_command]
    call app_ui_command
    jmp .PC_settings_loop
.PC_settings_approval:
    lea rdi,[rip+.PC_approval_command]
    call app_ui_command
    call ui_get_approval_mode
    lea rdx,[rip+ui_approval_names]
    mov rdi,[rdx+rax*8]
    xor esi,esi
    call ui_preferences_set_approval_mode
    test rax,rax
    js .PC_settings_error
    jmp .PC_settings_loop
.PC_settings_base:
    lea rdi,[rip+.PC_base_title]
    lea rsi,[rip+.PC_base_edit]
    mov edx,2048
    call ui_prompt_text
    test rax,rax
    jle .PC_settings_loop
    lea rdi,[rip+.PC_base_edit]
    call .PC_valid_base
    test eax,eax
    jz .PC_settings_invalid
    lea rdi,[rip+.PC_base_edit]
    xor esi,esi
    call ui_preferences_set_base_url
    test rax,rax
    js .PC_settings_error
    lea rsi,[rip+.PC_base_edit]
    lea rdi,[rip+.PC_active_base]
    mov edx,2048
    call .PC_copyz
    lea rax,[rip+.PC_active_base]
    mov [rip+app_base],rax
    mov qword ptr [rip+app_base_explicit],1
    call http_close
    call app_build_url
    jmp .PC_settings_loop
.PC_settings_key:
    cmp qword ptr [rip+app_oauth],0
    jne .PC_settings_auth
    call .PC_key_form
    test rax,rax
    js .PC_settings_loop
    mov rax,[rip+app_protocol]
    mov [rip+.PC_selected_protocol],rax
    mov rsi,[rip+app_model]
    lea rdi,[rip+.PC_model]
    mov edx,1024
    call .PC_copyz
    mov rsi,[rip+app_base]
    lea rdi,[rip+.PC_base]
    mov edx,2048
    call .PC_copyz
    call .PC_commit_connection
    test rax,rax
    js .PC_settings_error
    jmp .PC_settings_loop
.PC_settings_invalid:
    lea rdi,[rip+.PC_invalid]
    call app_error
    jmp .PC_settings_loop
.PC_settings_error:
    lea rdi,[rip+.PC_save_error]
    call app_error
    jmp .PC_settings_loop
.PC_settings_done:
    END

# Copy a bounded z-string; destination,value,capacity including NUL.
.PC_copyz:
    xor ecx,ecx
.PC_copy_loop:
    cmp rcx,rdx
    jae .PC_copy_bad
    mov al,[rsi+rcx]
    mov [rdi+rcx],al
    inc rcx
    test al,al
    jnz .PC_copy_loop
    xor eax,eax
    ret
.PC_copy_bad:
    mov byte ptr [rdi],0
    mov rax,-28
    ret
.PC_valid_base:
    cmp dword ptr [rdi],0x70747468
    jne .PC_base_bad
    cmp dword ptr [rdi+4],0x2f2f3a73
    je .PC_base_good
    cmp word ptr [rdi+4],0x2f3a
    jne .PC_base_bad
    cmp byte ptr [rdi+6],'/'
    jne .PC_base_bad
    # HTTP remains restricted by the native transport to localhost/127.0.0.1.
.PC_base_good:
    mov eax,1
    ret
.PC_base_bad:
    xor eax,eax
    ret
.PC_protocol_default:
    push rbx
    mov rbx,rdi
    lea rsi,[rip+.PC_anthropic]
    call qx_streq
    test eax,eax
    jnz .PC_default_anthropic
    mov rdi,rbx
    lea rsi,[rip+.PC_gemini]
    call qx_streq
    test eax,eax
    jnz .PC_default_gemini
    lea rax,[rip+.PC_openai_base]
    jmp .PC_default_return
.PC_default_anthropic:
    lea rax,[rip+.PC_anthropic_base]
    jmp .PC_default_return
.PC_default_gemini:
    lea rax,[rip+.PC_gemini_base]
.PC_default_return:
    pop rbx
    ret
FUNC .PC_build_review
    mov qword ptr [rip+.PC_info_builder+16],0
    lea rdi,[rip+.PC_protocol_info]
    call .PC_info_z
    mov rdi,[rip+.PC_selected_protocol]
    call .PC_info_z
    lea rdi,[rip+.PC_model_info]
    call .PC_info_z
    lea rdi,[rip+.PC_model]
    call .PC_info_z
    lea rdi,[rip+.PC_base_info]
    call .PC_info_z
    lea rdi,[rip+.PC_base]
    call .PC_info_z
    lea rdi,[rip+.PC_hidden_info]
    call .PC_info_z
    call .PC_info_terminate
    END
FUNC .PC_build_account
    mov qword ptr [rip+.PC_info_builder+16],0
    lea rdi,[rip+.PC_protocol_info]
    call .PC_info_z
    mov rdi,[rip+app_protocol]
    call .PC_info_z
    lea rdi,[rip+.PC_model_info]
    call .PC_info_z
    mov rdi,[rip+app_model]
    call .PC_info_z
    lea rdi,[rip+.PC_base_info]
    call .PC_info_z
    mov rdi,[rip+app_base]
    call .PC_info_z
    lea rdi,[rip+.PC_key_missing_info]
    mov rax,[rip+app_key]
    cmp byte ptr [rax],0
    je .PC_account_key_state
    lea rdi,[rip+.PC_hidden_info]
.PC_account_key_state:
    call .PC_info_z
    cmp qword ptr [rip+app_oauth],0
    je .PC_account_no_oauth
    lea rdi,[rip+.PC_oauth_status]
    call oauth_account_status
    lea rdi,[rip+.PC_expiry_info]
    call .PC_info_z
    lea rdi,[rip+.PC_number]
    mov rsi,[rip+.PC_oauth_status+16]
    call qx_uint
    lea rdi,[rip+.PC_number]
    mov byte ptr [rdi+rax],0
    call .PC_info_z
.PC_account_no_oauth:
    call .PC_info_terminate
    END
.PC_info_z:
    push r12
    mov r12,rdi
    call qx_strlen
    mov rdx,rax
    mov rsi,r12
    lea rdi,[rip+.PC_info_builder]
    call qx_cat
    pop r12
    ret
.PC_info_terminate:
    mov rax,[rip+.PC_info_builder+16]
    lea rdx,[rip+.PC_info]
    mov byte ptr [rdx+rax],0
    ret

.section .rodata
.PC_auth_title: .asciz "Connect a Provider"
.PC_alibaba_title: .asciz "Alibaba ModelStudio · Access Method"
.PC_thirdparty_title: .asciz "Third-party Providers · Provider"
.PC_main_alibaba: .asciz "Alibaba ModelStudio"
.PC_main_alibaba_desc: .asciz "Official recommended setup: Coding Plan, Token Plan, or Standard API Key"
.PC_main_thirdparty: .asciz "Third-party Providers"
.PC_main_thirdparty_desc: .asciz "Choose a built-in provider and connect with an API key"
.PC_main_custom: .asciz "Custom Provider"
.PC_main_custom_desc: .asciz "Manually connect a local server, proxy, or unsupported provider"
.PC_protocol_title: .asciz "Custom Provider · Protocol"
.PC_wire_title: .asciz "Custom Provider · API"
.PC_base_title: .asciz "Base URL (blank uses protocol default)"
.PC_endpoint_title: .asciz "Endpoint"
.PC_models_title: .asciz "Model IDs"
.PC_key_title: .asciz "API Key"
.PC_env_title: .asciz "API key environment variable"
.PC_review_title: .asciz "Review"
.PC_connect_label: .asciz "Connect"
.PC_back_label: .asciz "Back"
.PC_stored_label: .asciz "Enter API key"
.PC_stored_desc: .asciz "Save privately for this user; value remains hidden"
.PC_environment_label: .asciz "Use environment variable"
.PC_environment_desc: .asciz "Keep only the variable name in settings"
.PC_openai_label: .asciz "OpenAI-compatible"
.PC_anthropic_label: .asciz "Anthropic"
.PC_gemini_label: .asciz "Gemini"
.PC_chat_label: .asciz "Chat Completions"
.PC_responses_label: .asciz "Responses"
.PC_openai: .asciz "openai"
.PC_responses: .asciz "openai-responses"
.PC_anthropic: .asciz "anthropic"
.PC_gemini: .asciz "gemini"
.PC_qwen_oauth: .asciz "qwen-oauth"
.PC_openai_base: .asciz "https://api.openai.com/v1"
.PC_anthropic_base: .asciz "https://api.anthropic.com/v1"
.PC_gemini_base: .asciz "https://generativelanguage.googleapis.com"
.PC_stored: .asciz "stored"
.PC_environment: .asciz "environment"
.PC_none: .asciz "none"
.PC_empty: .asciz ""
.PC_connected: .asciz "Provider connected."
.PC_invalid: .asciz "Enter a valid HTTP(S) base URL and a nonempty model ID."
.PC_save_error: .asciz "Could not safely save provider settings. The active connection was not changed."
.PC_missing_env: .asciz "The selected API key environment variable is missing or empty."
.PC_interactive_only: .asciz "Provider setup is available in interactive mode."
.PC_account_title: .asciz "Account"
.PC_account_info_label: .asciz "Account information"
.PC_account_info_desc: .asciz "Provider, model, endpoint and credential status; key stays hidden"
.PC_oauth_label: .asciz "Qwen OAuth device login"
.PC_oauth_desc: .asciz "Native device authorization for existing OAuth access"
.PC_disconnect_label: .asciz "Disconnect"
.PC_disconnect_desc: .asciz "Remove native saved credentials; keep other clients’ caches"
.PC_disconnect_title: .asciz "Disconnect native account?"
.PC_cancel_label: .asciz "Cancel"
.PC_disconnected_label: .asciz "Not connected"
.PC_disconnected: .asciz "Disconnected. External environment credentials and other clients’ caches were not removed."
.PC_oauth_connected: .asciz "Qwen OAuth account connected."
.PC_settings_title: .asciz "Settings"
.PC_settings_model_label: .asciz "Model"
.PC_settings_base_label: .asciz "Base URL"
.PC_settings_auth_label: .asciz "Authentication"
.PC_settings_key_label: .asciz "API Key"
.PC_settings_key_desc: .asciz "Configure a key without displaying its value"
.PC_settings_theme_label: .asciz "Theme"
.PC_settings_theme_desc: .asciz "Preview and persist the selected theme scope"
.PC_settings_approval_label: .asciz "Approval mode"
.PC_settings_approval_desc: .asciz "Choose and save actual tool permissions"
.PC_settings_account: .asciz "Account"
.PC_settings_account_desc: .asciz "View account status, device login, or disconnect"
.PC_model_command: .asciz "/model"
.PC_theme_command: .asciz "/theme"
.PC_approval_command: .asciz "/approval-mode"
.PC_protocol_info: .asciz "Protocol: "
.PC_model_info: .asciz "\nModel: "
.PC_base_info: .asciz "\nBase URL: "
.PC_hidden_info: .asciz "\nAPI Key: (configured; hidden)"
.PC_key_missing_info: .asciz "\nAPI Key: (not set)"
.PC_expiry_info: .asciz "\nOAuth expiry (Unix milliseconds): "
.balign 8
.PC_main_items:
 .quad .PC_main_alibaba,.PC_main_alibaba_desc,0
 .quad .PC_main_thirdparty,.PC_main_thirdparty_desc,1
 .quad .PC_main_custom,.PC_main_custom_desc,2
.PC_alibaba_items:
 .quad .PC_preset_label_0,.PC_preset_desc_0,0
 .quad .PC_preset_label_1,.PC_preset_desc_1,1
 .quad .PC_preset_label_2,.PC_preset_desc_2,2
.PC_thirdparty_items:
 .quad .PC_preset_label_3,.PC_preset_desc_3,3
 .quad .PC_preset_label_4,.PC_preset_desc_4,4
 .quad .PC_preset_label_5,.PC_preset_desc_5,5
 .quad .PC_preset_label_6,.PC_preset_desc_6,6
 .quad .PC_preset_label_7,.PC_preset_desc_7,7
 .quad .PC_preset_label_8,.PC_preset_desc_8,8
 .quad .PC_preset_label_9,.PC_preset_desc_9,9
 .quad .PC_preset_label_10,.PC_preset_desc_10,10
 .quad .PC_preset_label_11,.PC_preset_desc_11,11
.PC_protocol_items:
 .quad .PC_openai_label,.PC_empty,.PC_openai
 .quad .PC_anthropic_label,.PC_empty,.PC_anthropic
 .quad .PC_gemini_label,.PC_empty,.PC_gemini
.PC_protocol_values: .quad .PC_openai,.PC_anthropic,.PC_gemini
.PC_wire_items:
 .quad .PC_chat_label,.PC_empty,.PC_openai
 .quad .PC_responses_label,.PC_empty,.PC_responses
.PC_key_items:
 .quad .PC_stored_label,.PC_stored_desc,0
 .quad .PC_environment_label,.PC_environment_desc,1
.PC_review_items:
 .quad .PC_connect_label,.PC_empty,0
 .quad .PC_back_label,.PC_empty,1
.PC_account_items:
 .quad .PC_account_info_label,.PC_account_info_desc,0
 .quad .PC_oauth_label,.PC_oauth_desc,1
 .quad .PC_disconnect_label,.PC_disconnect_desc,2
.PC_disconnect_items:
 .quad .PC_cancel_label,.PC_empty,0
 .quad .PC_disconnect_label,.PC_disconnect_desc,1
.PC_presets:
 .quad .PC_preset_label_0,.PC_preset_desc_0,.PC_openai,.PC_preset_env_0,.PC_regions_0,2,.PC_models_0,10,.PC_url_0_0,.PC_preset_id_0
 .quad .PC_preset_label_1,.PC_preset_desc_1,.PC_openai,.PC_preset_env_1,.PC_regions_1,2,.PC_models_1,18,.PC_url_1_0,.PC_preset_id_1
 .quad .PC_preset_label_2,.PC_preset_desc_2,.PC_openai,.PC_preset_env_2,.PC_regions_2,4,.PC_models_2,14,.PC_url_2_0,.PC_preset_id_2
 .quad .PC_preset_label_3,.PC_preset_desc_3,.PC_openai,.PC_preset_env_3,.PC_regions_3,1,.PC_models_3,2,.PC_url_3_0,.PC_preset_id_3
 .quad .PC_preset_label_4,.PC_preset_desc_4,.PC_openai,.PC_preset_env_4,.PC_regions_4,1,.PC_models_4,6,.PC_url_4_0,.PC_preset_id_4
 .quad .PC_preset_label_5,.PC_preset_desc_5,.PC_openai,.PC_preset_env_5,.PC_regions_5,2,.PC_models_5,7,.PC_url_5_0,.PC_preset_id_5
 .quad .PC_preset_label_6,.PC_preset_desc_6,.PC_openai,.PC_preset_env_6,.PC_regions_6,2,.PC_models_6,4,.PC_url_6_0,.PC_preset_id_6
 .quad .PC_preset_label_7,.PC_preset_desc_7,.PC_openai,.PC_preset_env_7,.PC_regions_7,2,.PC_models_7,4,.PC_url_7_0,.PC_preset_id_7
 .quad .PC_preset_label_8,.PC_preset_desc_8,.PC_openai,.PC_preset_env_8,.PC_regions_8,1,.PC_models_8,4,.PC_url_8_0,.PC_preset_id_8
 .quad .PC_preset_label_9,.PC_preset_desc_9,.PC_openai,.PC_preset_env_9,.PC_regions_9,1,.PC_models_9,3,.PC_url_9_0,.PC_preset_id_9
 .quad .PC_preset_label_10,.PC_preset_desc_10,.PC_openai,.PC_preset_env_10,.PC_regions_10,1,.PC_models_10,2,.PC_url_10_0,.PC_preset_id_10
 .quad .PC_preset_label_11,.PC_preset_desc_11,.PC_openai,.PC_preset_env_11,.PC_regions_11,1,.PC_models_11,2,.PC_url_11_0,.PC_preset_id_11
 .quad .PC_preset_label_12,.PC_preset_desc_12,.PC_openai,.PC_preset_env_12,.PC_regions_12,1,.PC_models_12,0,.PC_url_12_0,.PC_preset_id_12
.PC_preset_label_0: .asciz "Coding Plan"
.PC_preset_desc_0: .asciz "For individual developers · Weekly quota included"
.PC_preset_env_0: .asciz "BAILIAN_CODING_PLAN_API_KEY"
.PC_preset_id_0: .asciz "coding-plan"
.balign 8
.PC_regions_0:
 .quad .PC_region_0_0,.PC_url_0_0,.PC_url_0_0
 .quad .PC_region_0_1,.PC_url_0_1,.PC_url_0_1
.PC_region_0_0: .asciz "China (Beijing)"
.PC_url_0_0: .asciz "https://coding.dashscope.aliyuncs.com/v1"
.PC_region_0_1: .asciz "Singapore (International)"
.PC_url_0_1: .asciz "https://coding-intl.dashscope.aliyuncs.com/v1"
.balign 8
.PC_models_0:
 .quad .PC_model_label_0_0,.PC_empty,.PC_model_id_0_0
 .quad .PC_model_label_0_1,.PC_empty,.PC_model_id_0_1
 .quad .PC_model_label_0_2,.PC_empty,.PC_model_id_0_2
 .quad .PC_model_label_0_3,.PC_empty,.PC_model_id_0_3
 .quad .PC_model_label_0_4,.PC_empty,.PC_model_id_0_4
 .quad .PC_model_label_0_5,.PC_empty,.PC_model_id_0_5
 .quad .PC_model_label_0_6,.PC_empty,.PC_model_id_0_6
 .quad .PC_model_label_0_7,.PC_empty,.PC_model_id_0_7
 .quad .PC_model_label_0_8,.PC_empty,.PC_model_id_0_8
 .quad .PC_model_label_0_9,.PC_empty,.PC_model_id_0_9
.PC_model_label_0_0: .asciz "qwen3.5-plus"
.PC_model_id_0_0: .asciz "qwen3.5-plus"
.PC_model_label_0_1: .asciz "qwen3.6-plus"
.PC_model_id_0_1: .asciz "qwen3.6-plus"
.PC_model_label_0_2: .asciz "qwen3.7-plus"
.PC_model_id_0_2: .asciz "qwen3.7-plus"
.PC_model_label_0_3: .asciz "glm-5"
.PC_model_id_0_3: .asciz "glm-5"
.PC_model_label_0_4: .asciz "kimi-k2.5"
.PC_model_id_0_4: .asciz "kimi-k2.5"
.PC_model_label_0_5: .asciz "MiniMax-M2.5"
.PC_model_id_0_5: .asciz "MiniMax-M2.5"
.PC_model_label_0_6: .asciz "qwen3-coder-plus"
.PC_model_id_0_6: .asciz "qwen3-coder-plus"
.PC_model_label_0_7: .asciz "qwen3-coder-next"
.PC_model_id_0_7: .asciz "qwen3-coder-next"
.PC_model_label_0_8: .asciz "qwen3-max-2026-01-23"
.PC_model_id_0_8: .asciz "qwen3-max-2026-01-23"
.PC_model_label_0_9: .asciz "glm-4.7"
.PC_model_id_0_9: .asciz "glm-4.7"
.PC_preset_label_1: .asciz "Token Plan"
.PC_preset_desc_1: .asciz "For teams and companies · Usage-based billing with dedicated endpoint"
.PC_preset_env_1: .asciz "BAILIAN_TOKEN_PLAN_API_KEY"
.PC_preset_id_1: .asciz "token-plan"
.balign 8
.PC_regions_1:
 .quad .PC_region_1_0,.PC_url_1_0,.PC_url_1_0
 .quad .PC_region_1_1,.PC_url_1_1,.PC_url_1_1
.PC_region_1_0: .asciz "China (Beijing)"
.PC_url_1_0: .asciz "https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
.PC_region_1_1: .asciz "Singapore (International)"
.PC_url_1_1: .asciz "https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1"
.balign 8
.PC_models_1:
 .quad .PC_model_label_1_0,.PC_empty,.PC_model_id_1_0
 .quad .PC_model_label_1_1,.PC_empty,.PC_model_id_1_1
 .quad .PC_model_label_1_2,.PC_empty,.PC_model_id_1_2
 .quad .PC_model_label_1_3,.PC_empty,.PC_model_id_1_3
 .quad .PC_model_label_1_4,.PC_empty,.PC_model_id_1_4
 .quad .PC_model_label_1_5,.PC_empty,.PC_model_id_1_5
 .quad .PC_model_label_1_6,.PC_empty,.PC_model_id_1_6
 .quad .PC_model_label_1_7,.PC_empty,.PC_model_id_1_7
 .quad .PC_model_label_1_8,.PC_empty,.PC_model_id_1_8
 .quad .PC_model_label_1_9,.PC_empty,.PC_model_id_1_9
 .quad .PC_model_label_1_10,.PC_empty,.PC_model_id_1_10
 .quad .PC_model_label_1_11,.PC_empty,.PC_model_id_1_11
 .quad .PC_model_label_1_12,.PC_empty,.PC_model_id_1_12
 .quad .PC_model_label_1_13,.PC_empty,.PC_model_id_1_13
 .quad .PC_model_label_1_14,.PC_empty,.PC_model_id_1_14
 .quad .PC_model_label_1_15,.PC_empty,.PC_model_id_1_15
 .quad .PC_model_label_1_16,.PC_empty,.PC_model_id_1_16
 .quad .PC_model_label_1_17,.PC_empty,.PC_model_id_1_17
.PC_model_label_1_0: .asciz "qwen3.7-plus"
.PC_model_id_1_0: .asciz "qwen3.7-plus"
.PC_model_label_1_1: .asciz "qwen3.6-plus"
.PC_model_id_1_1: .asciz "qwen3.6-plus"
.PC_model_label_1_2: .asciz "qwen3.7-max"
.PC_model_id_1_2: .asciz "qwen3.7-max"
.PC_model_label_1_3: .asciz "qwen3.8-max"
.PC_model_id_1_3: .asciz "qwen3.8-max"
.PC_model_label_1_4: .asciz "qwen3.8-max-preview"
.PC_model_id_1_4: .asciz "qwen3.8-max-preview"
.PC_model_label_1_5: .asciz "qwen3.6-flash"
.PC_model_id_1_5: .asciz "qwen3.6-flash"
.PC_model_label_1_6: .asciz "deepseek-v4-pro"
.PC_model_id_1_6: .asciz "deepseek-v4-pro"
.PC_model_label_1_7: .asciz "deepseek-v4-flash-0731"
.PC_model_id_1_7: .asciz "deepseek-v4-flash-0731"
.PC_model_label_1_8: .asciz "deepseek-v3.2"
.PC_model_id_1_8: .asciz "deepseek-v3.2"
.PC_model_label_1_9: .asciz "kimi-k2.7-code"
.PC_model_id_1_9: .asciz "kimi-k2.7-code"
.PC_model_label_1_10: .asciz "kimi-k2.6"
.PC_model_id_1_10: .asciz "kimi-k2.6"
.PC_model_label_1_11: .asciz "kimi-k2.5"
.PC_model_id_1_11: .asciz "kimi-k2.5"
.PC_model_label_1_12: .asciz "glm-5.2"
.PC_model_id_1_12: .asciz "glm-5.2"
.PC_model_label_1_13: .asciz "glm-5.1"
.PC_model_id_1_13: .asciz "glm-5.1"
.PC_model_label_1_14: .asciz "glm-5"
.PC_model_id_1_14: .asciz "glm-5"
.PC_model_label_1_15: .asciz "MiniMax-M2.5"
.PC_model_id_1_15: .asciz "MiniMax-M2.5"
.PC_model_label_1_16: .asciz "qwen3.8-flash"
.PC_model_id_1_16: .asciz "qwen3.8-flash"
.PC_model_label_1_17: .asciz "deepseek-v4-pro-0813"
.PC_model_id_1_17: .asciz "deepseek-v4-pro-0813"
.PC_preset_label_2: .asciz "Standard API Key"
.PC_preset_desc_2: .asciz "Connect with an existing ModelStudio API key"
.PC_preset_env_2: .asciz "DASHSCOPE_API_KEY"
.PC_preset_id_2: .asciz "alibabaStandard"
.balign 8
.PC_regions_2:
 .quad .PC_region_2_0,.PC_url_2_0,.PC_url_2_0
 .quad .PC_region_2_1,.PC_url_2_1,.PC_url_2_1
 .quad .PC_region_2_2,.PC_url_2_2,.PC_url_2_2
 .quad .PC_region_2_3,.PC_url_2_3,.PC_url_2_3
.PC_region_2_0: .asciz "China (Beijing)"
.PC_url_2_0: .asciz "https://dashscope.aliyuncs.com/compatible-mode/v1"
.PC_region_2_1: .asciz "Singapore"
.PC_url_2_1: .asciz "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
.PC_region_2_2: .asciz "US (Virginia)"
.PC_url_2_2: .asciz "https://dashscope-us.aliyuncs.com/compatible-mode/v1"
.PC_region_2_3: .asciz "China (Hong Kong)"
.PC_url_2_3: .asciz "https://cn-hongkong.dashscope.aliyuncs.com/compatible-mode/v1"
.balign 8
.PC_models_2:
 .quad .PC_model_label_2_0,.PC_empty,.PC_model_id_2_0
 .quad .PC_model_label_2_1,.PC_empty,.PC_model_id_2_1
 .quad .PC_model_label_2_2,.PC_empty,.PC_model_id_2_2
 .quad .PC_model_label_2_3,.PC_empty,.PC_model_id_2_3
 .quad .PC_model_label_2_4,.PC_empty,.PC_model_id_2_4
 .quad .PC_model_label_2_5,.PC_empty,.PC_model_id_2_5
 .quad .PC_model_label_2_6,.PC_empty,.PC_model_id_2_6
 .quad .PC_model_label_2_7,.PC_empty,.PC_model_id_2_7
 .quad .PC_model_label_2_8,.PC_empty,.PC_model_id_2_8
 .quad .PC_model_label_2_9,.PC_empty,.PC_model_id_2_9
 .quad .PC_model_label_2_10,.PC_empty,.PC_model_id_2_10
 .quad .PC_model_label_2_11,.PC_empty,.PC_model_id_2_11
 .quad .PC_model_label_2_12,.PC_empty,.PC_model_id_2_12
 .quad .PC_model_label_2_13,.PC_empty,.PC_model_id_2_13
.PC_model_label_2_0: .asciz "qwen3.6-plus"
.PC_model_id_2_0: .asciz "qwen3.6-plus"
.PC_model_label_2_1: .asciz "qwen3.7-plus"
.PC_model_id_2_1: .asciz "qwen3.7-plus"
.PC_model_label_2_2: .asciz "qwen3.7-max"
.PC_model_id_2_2: .asciz "qwen3.7-max"
.PC_model_label_2_3: .asciz "glm-5.1"
.PC_model_id_2_3: .asciz "glm-5.1"
.PC_model_label_2_4: .asciz "deepseek-v4-pro"
.PC_model_id_2_4: .asciz "deepseek-v4-pro"
.PC_model_label_2_5: .asciz "deepseek-v4-flash"
.PC_model_id_2_5: .asciz "deepseek-v4-flash"
.PC_model_label_2_6: .asciz "qwen3.8-max"
.PC_model_id_2_6: .asciz "qwen3.8-max"
.PC_model_label_2_7: .asciz "qwen3.8-max-0902"
.PC_model_id_2_7: .asciz "qwen3.8-max-0902"
.PC_model_label_2_8: .asciz "qwen3.8-flash"
.PC_model_id_2_8: .asciz "qwen3.8-flash"
.PC_model_label_2_9: .asciz "deepseek-v4-pro-0813"
.PC_model_id_2_9: .asciz "deepseek-v4-pro-0813"
.PC_model_label_2_10: .asciz "deepseek-v4-flash-0731"
.PC_model_id_2_10: .asciz "deepseek-v4-flash-0731"
.PC_model_label_2_11: .asciz "kimi-k3"
.PC_model_id_2_11: .asciz "kimi-k3"
.PC_model_label_2_12: .asciz "kimi-k2.7-code"
.PC_model_id_2_12: .asciz "kimi-k2.7-code"
.PC_model_label_2_13: .asciz "kimi-k2.6"
.PC_model_id_2_13: .asciz "kimi-k2.6"
.PC_preset_label_3: .asciz "DeepSeek API Key"
.PC_preset_desc_3: .asciz "Quick setup for DeepSeek (deepseek-v4-flash, deepseek-v4-pro)"
.PC_preset_env_3: .asciz "DEEPSEEK_API_KEY"
.PC_preset_id_3: .asciz "deepseek"
.balign 8
.PC_regions_3:
 .quad .PC_region_3_0,.PC_url_3_0,.PC_url_3_0
.PC_region_3_0: .asciz "Endpoint"
.PC_url_3_0: .asciz "https://api.deepseek.com"
.balign 8
.PC_models_3:
 .quad .PC_model_label_3_0,.PC_empty,.PC_model_id_3_0
 .quad .PC_model_label_3_1,.PC_empty,.PC_model_id_3_1
.PC_model_label_3_0: .asciz "deepseek-v4-pro"
.PC_model_id_3_0: .asciz "deepseek-v4-pro"
.PC_model_label_3_1: .asciz "deepseek-v4-flash"
.PC_model_id_3_1: .asciz "deepseek-v4-flash"
.PC_preset_label_4: .asciz "Grok (xAI) API Key"
.PC_preset_desc_4: .asciz "Quick setup for xAI Grok chat & code models"
.PC_preset_env_4: .asciz "XAI_API_KEY"
.PC_preset_id_4: .asciz "grok"
.balign 8
.PC_regions_4:
 .quad .PC_region_4_0,.PC_url_4_0,.PC_url_4_0
.PC_region_4_0: .asciz "Endpoint"
.PC_url_4_0: .asciz "https://api.x.ai/v1"
.balign 8
.PC_models_4:
 .quad .PC_model_label_4_0,.PC_empty,.PC_model_id_4_0
 .quad .PC_model_label_4_1,.PC_empty,.PC_model_id_4_1
 .quad .PC_model_label_4_2,.PC_empty,.PC_model_id_4_2
 .quad .PC_model_label_4_3,.PC_empty,.PC_model_id_4_3
 .quad .PC_model_label_4_4,.PC_empty,.PC_model_id_4_4
 .quad .PC_model_label_4_5,.PC_empty,.PC_model_id_4_5
.PC_model_label_4_0: .asciz "grok-4.5"
.PC_model_id_4_0: .asciz "grok-4.5"
.PC_model_label_4_1: .asciz "grok-4.3"
.PC_model_id_4_1: .asciz "grok-4.3"
.PC_model_label_4_2: .asciz "grok-4.20-0309-reasoning"
.PC_model_id_4_2: .asciz "grok-4.20-0309-reasoning"
.PC_model_label_4_3: .asciz "grok-4.20-0309-non-reasoning"
.PC_model_id_4_3: .asciz "grok-4.20-0309-non-reasoning"
.PC_model_label_4_4: .asciz "grok-4.20-multi-agent-0309"
.PC_model_id_4_4: .asciz "grok-4.20-multi-agent-0309"
.PC_model_label_4_5: .asciz "grok-build-0.1"
.PC_model_id_4_5: .asciz "grok-build-0.1"
.PC_preset_label_5: .asciz "MiniMax API Key"
.PC_preset_desc_5: .asciz "Quick setup for MiniMax models"
.PC_preset_env_5: .asciz "MINIMAX_API_KEY"
.PC_preset_id_5: .asciz "minimax"
.balign 8
.PC_regions_5:
 .quad .PC_region_5_0,.PC_url_5_0,.PC_url_5_0
 .quad .PC_region_5_1,.PC_url_5_1,.PC_url_5_1
.PC_region_5_0: .asciz "International"
.PC_url_5_0: .asciz "https://api.minimax.io/v1"
.PC_region_5_1: .asciz "China"
.PC_url_5_1: .asciz "https://api.minimaxi.com/v1"
.balign 8
.PC_models_5:
 .quad .PC_model_label_5_0,.PC_empty,.PC_model_id_5_0
 .quad .PC_model_label_5_1,.PC_empty,.PC_model_id_5_1
 .quad .PC_model_label_5_2,.PC_empty,.PC_model_id_5_2
 .quad .PC_model_label_5_3,.PC_empty,.PC_model_id_5_3
 .quad .PC_model_label_5_4,.PC_empty,.PC_model_id_5_4
 .quad .PC_model_label_5_5,.PC_empty,.PC_model_id_5_5
 .quad .PC_model_label_5_6,.PC_empty,.PC_model_id_5_6
.PC_model_label_5_0: .asciz "MiniMax-M3"
.PC_model_id_5_0: .asciz "MiniMax-M3"
.PC_model_label_5_1: .asciz "MiniMax-M2.7"
.PC_model_id_5_1: .asciz "MiniMax-M2.7"
.PC_model_label_5_2: .asciz "MiniMax-M2.7-highspeed"
.PC_model_id_5_2: .asciz "MiniMax-M2.7-highspeed"
.PC_model_label_5_3: .asciz "MiniMax-M2.5"
.PC_model_id_5_3: .asciz "MiniMax-M2.5"
.PC_model_label_5_4: .asciz "MiniMax-M2.5-highspeed"
.PC_model_id_5_4: .asciz "MiniMax-M2.5-highspeed"
.PC_model_label_5_5: .asciz "image-01"
.PC_model_id_5_5: .asciz "image-01"
.PC_model_label_5_6: .asciz "image-01-live"
.PC_model_id_5_6: .asciz "image-01-live"
.PC_preset_label_6: .asciz "Z.AI API Key"
.PC_preset_desc_6: .asciz "Quick setup for Z.AI models"
.PC_preset_env_6: .asciz "ZAI_API_KEY"
.PC_preset_id_6: .asciz "zai"
.balign 8
.PC_regions_6:
 .quad .PC_region_6_0,.PC_url_6_0,.PC_url_6_0
 .quad .PC_region_6_1,.PC_url_6_1,.PC_url_6_1
.PC_region_6_0: .asciz "Standard API Key"
.PC_url_6_0: .asciz "https://api.z.ai/api/paas/v4"
.PC_region_6_1: .asciz "Coding Plan"
.PC_url_6_1: .asciz "https://api.z.ai/api/coding/paas/v4"
.balign 8
.PC_models_6:
 .quad .PC_model_label_6_0,.PC_empty,.PC_model_id_6_0
 .quad .PC_model_label_6_1,.PC_empty,.PC_model_id_6_1
 .quad .PC_model_label_6_2,.PC_empty,.PC_model_id_6_2
 .quad .PC_model_label_6_3,.PC_empty,.PC_model_id_6_3
.PC_model_label_6_0: .asciz "GLM-5.2"
.PC_model_id_6_0: .asciz "GLM-5.2"
.PC_model_label_6_1: .asciz "GLM-5.1"
.PC_model_id_6_1: .asciz "GLM-5.1"
.PC_model_label_6_2: .asciz "GLM-5"
.PC_model_id_6_2: .asciz "GLM-5"
.PC_model_label_6_3: .asciz "GLM-5-Turbo"
.PC_model_id_6_3: .asciz "GLM-5-Turbo"
.PC_preset_label_7: .asciz "Kimi (Moonshot AI) API Key"
.PC_preset_desc_7: .asciz "Quick setup for Kimi models"
.PC_preset_env_7: .asciz "MOONSHOT_API_KEY"
.PC_preset_id_7: .asciz "moonshot"
.balign 8
.PC_regions_7:
 .quad .PC_region_7_0,.PC_url_7_0,.PC_url_7_0
 .quad .PC_region_7_1,.PC_url_7_1,.PC_url_7_1
.PC_region_7_0: .asciz "International"
.PC_url_7_0: .asciz "https://api.moonshot.ai/v1"
.PC_region_7_1: .asciz "China"
.PC_url_7_1: .asciz "https://api.moonshot.cn/v1"
.balign 8
.PC_models_7:
 .quad .PC_model_label_7_0,.PC_empty,.PC_model_id_7_0
 .quad .PC_model_label_7_1,.PC_empty,.PC_model_id_7_1
 .quad .PC_model_label_7_2,.PC_empty,.PC_model_id_7_2
 .quad .PC_model_label_7_3,.PC_empty,.PC_model_id_7_3
.PC_model_label_7_0: .asciz "kimi-k3"
.PC_model_id_7_0: .asciz "kimi-k3"
.PC_model_label_7_1: .asciz "kimi-k2.7-code"
.PC_model_id_7_1: .asciz "kimi-k2.7-code"
.PC_model_label_7_2: .asciz "kimi-k2.7-code-highspeed"
.PC_model_id_7_2: .asciz "kimi-k2.7-code-highspeed"
.PC_model_label_7_3: .asciz "kimi-k2.6"
.PC_model_id_7_3: .asciz "kimi-k2.6"
.PC_preset_label_8: .asciz "Idealab API Key"
.PC_preset_desc_8: .asciz "Alibaba internal LLM service (Qwen3.6-Plus-DogFooding, DeepSeek V4, Kimi K2.6)"
.PC_preset_env_8: .asciz "IDEALAB_API_KEY"
.PC_preset_id_8: .asciz "idealab"
.balign 8
.PC_regions_8:
 .quad .PC_region_8_0,.PC_url_8_0,.PC_url_8_0
.PC_region_8_0: .asciz "Endpoint"
.PC_url_8_0: .asciz "https://idealab.alibaba-inc.com/api/openai/v1"
.balign 8
.PC_models_8:
 .quad .PC_model_label_8_0,.PC_empty,.PC_model_id_8_0
 .quad .PC_model_label_8_1,.PC_empty,.PC_model_id_8_1
 .quad .PC_model_label_8_2,.PC_empty,.PC_model_id_8_2
 .quad .PC_model_label_8_3,.PC_empty,.PC_model_id_8_3
.PC_model_label_8_0: .asciz "Qwen3.6-Plus-DogFooding"
.PC_model_id_8_0: .asciz "Qwen3.6-Plus-DogFooding"
.PC_model_label_8_1: .asciz "bailian/deepseek-v4-pro"
.PC_model_id_8_1: .asciz "bailian/deepseek-v4-pro"
.PC_model_label_8_2: .asciz "bailian/deepseek-v4-flash"
.PC_model_id_8_2: .asciz "bailian/deepseek-v4-flash"
.PC_model_label_8_3: .asciz "bailian/kimi-k2.6"
.PC_model_id_8_3: .asciz "bailian/kimi-k2.6"
.PC_preset_label_9: .asciz "ModelScope API Key"
.PC_preset_desc_9: .asciz "Quick setup for ModelScope API Inference"
.PC_preset_env_9: .asciz "MODELSCOPE_API_KEY"
.PC_preset_id_9: .asciz "modelscope"
.balign 8
.PC_regions_9:
 .quad .PC_region_9_0,.PC_url_9_0,.PC_url_9_0
.PC_region_9_0: .asciz "Endpoint"
.PC_url_9_0: .asciz "https://api-inference.modelscope.cn/v1"
.balign 8
.PC_models_9:
 .quad .PC_model_label_9_0,.PC_empty,.PC_model_id_9_0
 .quad .PC_model_label_9_1,.PC_empty,.PC_model_id_9_1
 .quad .PC_model_label_9_2,.PC_empty,.PC_model_id_9_2
.PC_model_label_9_0: .asciz "deepseek-ai/DeepSeek-V4-Flash"
.PC_model_id_9_0: .asciz "deepseek-ai/DeepSeek-V4-Flash"
.PC_model_label_9_1: .asciz "Qwen/Qwen3.5-397B-A17B"
.PC_model_id_9_1: .asciz "Qwen/Qwen3.5-397B-A17B"
.PC_model_label_9_2: .asciz "ZhipuAI/GLM-5.1"
.PC_model_id_9_2: .asciz "ZhipuAI/GLM-5.1"
.PC_preset_label_10: .asciz "OpenRouter"
.PC_preset_desc_10: .asciz "Connect with an OpenRouter API key (get one from openrouter.ai/keys)"
.PC_preset_env_10: .asciz "OPENROUTER_API_KEY"
.PC_preset_id_10: .asciz "openrouter"
.balign 8
.PC_regions_10:
 .quad .PC_region_10_0,.PC_url_10_0,.PC_url_10_0
.PC_region_10_0: .asciz "Endpoint"
.PC_url_10_0: .asciz "https://openrouter.ai/api/v1"
.balign 8
.PC_models_10:
 .quad .PC_model_label_10_0,.PC_empty,.PC_model_id_10_0
 .quad .PC_model_label_10_1,.PC_empty,.PC_model_id_10_1
.PC_model_label_10_0: .asciz "z-ai/glm-4.5-air:free"
.PC_model_id_10_0: .asciz "z-ai/glm-4.5-air:free"
.PC_model_label_10_1: .asciz "openai/gpt-oss-120b:free"
.PC_model_id_10_1: .asciz "openai/gpt-oss-120b:free"
.PC_preset_label_11: .asciz "Requesty"
.PC_preset_desc_11: .asciz "Connect with a Requesty API key (get one from app.requesty.ai/api-keys)"
.PC_preset_env_11: .asciz "REQUESTY_API_KEY"
.PC_preset_id_11: .asciz "requesty"
.balign 8
.PC_regions_11:
 .quad .PC_region_11_0,.PC_url_11_0,.PC_url_11_0
.PC_region_11_0: .asciz "Endpoint"
.PC_url_11_0: .asciz "https://router.requesty.ai/v1"
.balign 8
.PC_models_11:
 .quad .PC_model_label_11_0,.PC_empty,.PC_model_id_11_0
 .quad .PC_model_label_11_1,.PC_empty,.PC_model_id_11_1
.PC_model_label_11_0: .asciz "openai/gpt-4o-mini"
.PC_model_id_11_0: .asciz "openai/gpt-4o-mini"
.PC_model_label_11_1: .asciz "openai/gpt-4o"
.PC_model_id_11_1: .asciz "openai/gpt-4o"
.PC_preset_label_12: .asciz "Custom Provider"
.PC_preset_desc_12: .asciz "Manually connect a local server, proxy, or unsupported provider"
.PC_preset_env_12: .asciz ""
.PC_preset_id_12: .asciz "custom-openai-compatible"
.balign 8
.PC_regions_12:
 .quad .PC_region_12_0,.PC_url_12_0,.PC_url_12_0
.PC_region_12_0: .asciz "Endpoint"
.PC_url_12_0: .asciz ""
.balign 8
.PC_models_12:

.section .data
.PC_info_builder: .quad .PC_info,16383,0
.PC_settings_items:
 .quad .PC_settings_model_label,.PC_empty,0
 .quad .PC_settings_base_label,.PC_empty,1
 .quad .PC_settings_auth_label,.PC_empty,2
 .quad .PC_settings_key_label,.PC_settings_key_desc,3
 .quad .PC_settings_theme_label,.PC_settings_theme_desc,4
 .quad .PC_settings_approval_label,.PC_settings_approval_desc,5
 .quad .PC_settings_account,.PC_settings_account_desc,6
.section .bss
.PC_selected_preset: .skip 8
.PC_selected_protocol: .skip 8
.PC_default_base: .skip 8
.PC_key_source: .skip 8
.PC_base: .skip 2048
.PC_base_edit: .skip 2048
.PC_model: .skip 1024
.PC_key: .skip 4096
.PC_active_key: .skip 4096
.PC_active_base: .skip 2048
.PC_active_model: .skip 1024
.PC_env: .skip 256
.PC_connection: .skip 48
.PC_info: .skip 16384
.PC_number: .skip 32
.PC_oauth_status: .skip 32
.section .text
