# qwen-x86 native application ABI and data layouts.
# System V AMD64: preserve rbx, rbp, r12-r15; stack 16-byte aligned at call.
.intel_syntax noprefix
.equ JT_OBJECT, 1
.equ JT_ARRAY, 2
.equ JT_STRING, 3
.equ JT_NUMBER, 4
.equ JT_TRUE, 5
.equ JT_FALSE, 6
.equ JT_NULL, 7
.equ TOKEN_SIZE, 32
.equ T_TYPE, 0
.equ T_START, 8
.equ T_LEN, 16
.equ T_END, 24
.equ MAX_LINE, 65536
.equ MAX_JSON, 1048576
.equ MAX_TOKENS, 8192
