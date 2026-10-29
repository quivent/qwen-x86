AS ?= as
LD ?= ld
PYTHON ?= python3
SOURCES := runtime json terminal tools agents plugins mcp mcp_server oauth net http stream sha256 x25519 aesgcm rsa x509 tls main
OBJECTS := $(addprefix build/,$(addsuffix .o,$(SOURCES)))
.PHONY: all test clean install
all: qwen-x86
build:
	mkdir -p build
build/%.o: src/%.s src/abi.inc | build
	$(AS) --64 -I src -o $@ $<
build/main.o: src/tools.json src/tools_readonly.json
build/mcp_server.o: src/tools_readonly.json
qwen-x86: $(OBJECTS)
	$(LD) -static -z noexecstack -s -o $@ $(OBJECTS)
test: qwen-x86
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py' -v
install: qwen-x86
	install -m 755 qwen-x86 $(HOME)/.local/bin/qwen-x86
clean:
	rm -rf build qwen-x86
