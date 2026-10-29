AS ?= as
LD ?= ld
PYTHON ?= python3
SOURCES := runtime json terminal tools agents plugins mcp mcp_server oauth net http stream sha256 x25519 aesgcm rsa x509 tls ui_input ui_markdown ui_mermaid ui_sessions ui_external_editor ui_paths ui_tool_preview ui_shell ui_preferences ui_error_response ui_help ui main
OBJECTS := $(addprefix build/,$(addsuffix .o,$(SOURCES)))
.PHONY: all test clean install
all: qwen-x86
build:
	mkdir -p build
build/%.o: src/%.s src/abi.inc | build
	$(AS) --64 -I src -o $@ $<
build/main.o: src/tools.json src/tools_readonly.json
build/ui.o build/ui_input.o: src/ui_abi.inc
build/ui_input.o: src/ui_unicode.inc
build/ui.o: src/ui_themes.inc
build/ui_markdown.o: src/ui_formatter_palettes.inc
build/ui_mermaid.o: src/ui_mermaid_palettes.inc
build/mcp_server.o: src/tools_readonly.json
qwen-x86: $(OBJECTS)
	$(LD) -static -z noexecstack -s -o $@ $(OBJECTS)
test: qwen-x86
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py' -v
install: qwen-x86
	install -D -m 755 qwen-x86 "$(HOME)/.local/bin/qwen-x86"
clean:
	rm -rf build qwen-x86
