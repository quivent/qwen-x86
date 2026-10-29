# qwen-x86

**103,120 bytes (100.7 KiB)** — statically linked x86-64 assembly, including TLS and cryptography. No libc, Node.js, Go runtime, or shared TLS library.

## Benchmarks

### Current tool-loop performance

Twenty randomized runs per variant and transport on this machine. Lower is better. The same five tool steps and their outputs are verified in each run.

| Client | HTTP median | HTTP p95 | HTTPS median | HTTPS p95 |
|---|---:|---:|---:|---:|
| **qwen-x86 optimized** | 41.8 ms | 52.6 ms | 47.6 ms | 70.4 ms |
| qwen-go | 100.6 ms | 117.9 ms | 65.6 ms | 93.7 ms |
| qwen-x86 before optimization | 205.7 ms | 301.6 ms | 236.5 ms | 274.6 ms |

The optimized HTTPS median is **4.97× faster than the assembly baseline** and **27.4% lower than Go**. These are client gaps between model responses and subsequent requests, excluding model preparation. TCP_NODELAY and kernel child-exit notifications remove avoidable waits. [Raw measurements, equations, and uncertainty](docs/wait-optimization.json).

### Three-client baseline

These earlier measurements preceded the wait optimization. Streaming and memory figures are five-run medians; memory was sampled in a separate pass. Startup uses 50 warm runs.

| Measurement | qwen-x86 baseline | qwen-go | Original JavaScript |
|---|---:|---:|---:|
| Warm `--version` startup | 0.35 ms | 3.53 ms | 66.91 ms |
| 64 KiB stream, first response byte → exit | 21.5 ms | 80.3 ms | 692.5 ms |
| Peak proportional memory during that stream | 0.37 MiB | 13.55 MiB | 257.98 MiB |

Local controlled fixtures measure client overhead. The clients have different feature sets; JavaScript includes extra default cleanup. These results do not measure real model inference, WAN latency, or interactive TUI rendering. [Usage methodology](docs/usage-benchmark.json) · [Startup methodology](docs/benchmark.json) · [Detailed optimization](#critical-path-wait-optimization).

A Linux x86-64 coding client written in GNU Intel-syntax assembly. The production executable is statically linked assembly: no libc, JavaScript engine, Go runtime, shared TLS library, or HTTPS helper process.


## Build and run

Requires Linux x86-64, GNU `as`, and GNU `ld`. HTTPS requires an AES-NI capable processor and a PEM CA trust store, normally `/etc/ssl/certs/ca-certificates.crt`.

```sh
make
./qwen-x86 --demo --no-save
./qwen-x86 login
./qwen-x86
# Or use an API key:
QWEN_API_KEY=your-key ./qwen-x86
./qwen-x86 --prompt 'Inspect this workspace and explain its entry point'
make install
```

`login` (or `--login`) uses Qwen device authorization with native HTTPS and PKCE. It prints a verification URL and user code for browser approval, then saves a private cache at `~/.config/qwen-x86/oauth.json`. Access and refresh tokens are never printed. Native credentials refresh under a cross-process file lock; unexpired Go/Qwen Code caches can be reused read-only, and expired external caches require a native login. OAuth defaults to `coder-model` and the issued resource URL; explicit endpoint/model settings take precedence.

`--help` lists flags. `--cwd DIR` selects the workspace. `QWEN_BASE_URL` / `OPENAI_BASE_URL`, `QWEN_MODEL` / `OPENAI_MODEL`, and `QWEN_API_KEY` / `OPENAI_API_KEY` configure an OpenAI-compatible streaming endpoint. The client appends `/chat/completions` unless already present. Unencrypted HTTP is allowed only for `localhost` or `127.0.0.1`. `--ca-file FILE` supplies an explicit PEM trust store.

`--yes` explicitly permits workspace changes, unrestricted shell commands, and optional external MCP process startup/tool calls. Without it, terminal sessions ask for approval; headless sessions deny approval-dependent actions. Read-only subagents cannot write, run a shell, use external tools, or delegate even when the parent uses `--yes`.

## Features

- Native streaming SSE/JSON, multi-round tool calls, terminal input, UTF-8 backspace, multiline input with Alt+Enter, interactive cancellation, and terminal restoration.
- Workspace-relative `read_file`, `list_directory`, atomic `write_file`, exact `edit_file`, and approved `run_shell`. File tools reject symlinks and parent traversal, with a 64 KiB text limit. Shell commands execute with the user's ordinary account permissions.
- Up to three concurrent forked read-only agents, separate histories, saved follow-ups, status, waiting, and cancellation.
- Interactive Ctrl+C stops a running shell or MCP operation and skips remaining tool calls in that response. Canceled batches save matching tool results before returning to the prompt.
- Private atomic JSON session snapshots under `~/.local/state/qwen-x86/`; `--resume FILE`, `--no-save`, and `/new`.
- Shared Go-client prompt/skill plugin folders at `~/.config/qwen-go/plugins` and `.qwen-go/plugins`. List with `--plugins` or `/plugins`; invoke `/plugin:command` or `/skill plugin:skill`.
- Optional native stdio MCP client. Configuration loading does not launch servers. `list_mcp_servers`, then approved `connect_mcp_server`, exposes discovered tools. MCP protocol 2024-11-05; four local servers, sixteen tools per server. Remote transport and paginated discovery are unsupported.
- `qwen-x86 --mcp-serve` exposes its two read-only workspace tools as a native stdio MCP server, without model credentials.

The terminal filters model-supplied control sequences. Plugin prompts, repository files, and external tool results remain untrusted text; the model can still misunderstand them. Approval is a local execution boundary, not a claim that generated shell commands are harmless.

## Native network profile

The binary implements IPv4 hosts-file/DNS lookup, nonblocking TCP, HTTP/1.1 framing and persistent single-origin connections, TLS 1.3, SHA-256/HMAC/HKDF, X25519, AES-128-GCM, RSA verification, and bounded DER/PEM X.509 validation. HTTP POSTs are never automatically replayed after connection failure. Forked agents detach inherited network descriptors without closing the parent's TLS connection.

TLS offers `TLS_AES_128_GCM_SHA256`, X25519 key exchange, RSA-PSS/SHA-256 CertificateVerify, and RSA/SHA-256 signed certificate links. Validation includes trust, SAN hostnames, time, basic constraints/path length, key usage and EKU. An explicitly trusted anchor is matched by both subject and public key, allowing a differently signed wrapper of that same anchor. There is no name-only trust.

This deliberately bounded first implementation is not a general browser TLS/PKIX stack. It has no IPv6, proxy support, DNS TCP fallback, ECDSA, arbitrary signature algorithms, AIA fetching, revocation checking, session resumption, TLS KeyUpdate, or general DN normalization. Unsupported critical certificate constraints fail closed. Certificate validation precedes application credential transmission.

## Verification and measurements

```sh
make test
QWEN_X86_LIVE_TLS_TEST=1 python3 -m unittest discover -s tests -p test_tls.py -v
python3 tests/bench_client.py
```

Tests use Python, Python `cryptography`, and local OpenSSL-compatible TLS servers as independent test oracles. These are development dependencies only. Fixtures exercise cryptographic known-answer/random cases, malformed inputs, actual HTTPS model/tool/session flows, denial paths, process cleanup, and native parallel workers. The optional public probe performs verified TLS to the default API host without sending an HTTP request or credentials.

[The verification receipt](docs/verification.json) records the executable hash, source hashes, static linkage, and test scope.

[Benchmark results](docs/benchmark.json) compare the assembly and Go executables and the installed JavaScript command on this machine. They measure warm process startup and, for the native clients, idle offline-terminal memory, not remote model latency, sustained token throughput, or complete Qwen Code feature parity. No authenticated remote model run or real device authorization is implied by local fixtures. The native TLS handshake has separately been verified against `chat.qwen.ai`, `dashscope.aliyuncs.com`, and `dashscope-intl.aliyuncs.com` without sending HTTP or credentials.

## Usage performance before wait optimization

Measured on this machine with five repetitions per workload/client, after one warmup and with an isolated profile. Actual installed clients execute against a local deterministic model fixture. Every stream, file edit, shell checksum, and worker result is verified. Timing runs disable memory sampling; a separate five-run pass measures process-tree proportional resident memory (PSS).

| Workload / metric | Assembly | Go | Original JavaScript |
|---|---:|---:|---:|
| 64 KiB burst, first SSE body to process exit | 21.5 ms | 80.3 ms | 692.5 ms |
| 8 KiB paced stream, first SSE body to exit | 280.6 ms | 278.5 ms | 739.0 ms |
| Five HTTP tool steps, client gaps only | 200.5 ms | 60.6 ms | 717.5 ms |
| Five HTTPS tool steps, client gaps only | 233.5 ms | 68.6 ms | 568.8 ms |
| Peak PSS during burst stream | 0.37 MiB | 13.55 MiB | 257.98 MiB |

The five tools read about 32 KiB, write about 8 KiB, read the written file, edit one marker, and run `sha256sum`. Client gaps run from one completed response to the next request arriving, so exclude the fixture's fixed 20 ms preparation delay per response. Stream-to-exit numbers include output handling, session saving, shutdown, and the original JavaScript client's extra managed-memory request. Paced streaming adds 2 ms per content chunk. These measure client usage overhead; real model inference, WAN latency, and interactive TUI rendering are outside scope.

Two native workers each receive a 150 ms fixture delay and demonstrably overlap: response-to-exit median is 247.8 ms for assembly and 212.7 ms for Go. The JavaScript agent interface was not included in that comparison.

In that baseline, Go had lower tool round-trip latency, while assembly consumed less CPU and memory. The ACK diagnostic changes only server TCP acknowledgement scheduling: assembly's total HTTPS tool gap falls from 243.098 ms to 64.05 ms. Go stays near 64.35–72.797 ms. This supports Nagle/delayed-ACK interaction as a major cause. Go enables TCP_NODELAY; that baseline assembly binary did not. Its shell runner could also add a 100 ms child-reaping polling delay. Those baseline measurements preceded the optimization below.

Output mode matters: original JavaScript headless text mode exposes the first marker at 675.3 ms in this paced fixture; explicit `stream-json --include-partial-messages` exposes it at 13.4 ms (three runs). The text-mode figure does not establish interactive first-token latency.

The clients have different feature sets and default prompts. The JavaScript client performs extra default work, and HTTPS cipher negotiation differs (assembly AES-128-GCM; Go/JavaScript AES-256-GCM). Small timings remain sensitive to fixture and OS scheduling overhead.

[Full usage results and reproduction commands](docs/usage-benchmark.json), [ACK diagnostic](docs/tcp-ack-diagnostic.json), and [JavaScript streaming-mode check](docs/javascript-streaming-mode.json).

## Critical-path wait optimization

The five measured tool rounds form a dependency chain. Their cost is

```text
T_tools = sum(C_i + A_i + R_i + S_i), i = 1..5
C = useful critical-path processing
A = avoidable acknowledgement wait
R = child-exit detection delay
S = remaining scheduling and I/O waits
```

TCP_NODELAY now removes the Nagle/delayed-ACK gate between small request writes. The shell runner now uses a kernel pidfd exit notification, retaining the bounded polling fallback for unsupported/restricted kernels. Cancellation and command timeouts remain enforced. This allows transport progress and acknowledgement handling to overlap, and makes process completion event-driven; the tool dependencies stay ordered.

For a child exit `d > 0` after the first unsuccessful wait probe, periodic detection with period `P` adds `R(d) = P*ceil(d/P)-d`. Previously `P=100 ms`. A uniform phase would give mean `P/2`, but the short EOF/exit race can put `d` close to zero and produce almost a full 100 ms stall. The measurements do not assume a uniform phase. With pidfd, kernel wake and scheduler latency replace that timer quantization.

Twenty randomized blocks per transport compare four native ELF variants and the unchanged Go reference. The server retains its default ACK behavior, memory sampling is disabled, and each run verifies the same five tool operations. The predeclared target was an observed median and p95 below Go in both transports.

| Five-tool client gaps | HTTP median / p95 | HTTPS median / p95 |
|---|---:|---:|
| Assembly baseline | 205.7 / 301.6 ms | 236.5 / 274.6 ms |
| TCP_NODELAY only | 41.8 / 140.4 ms | 52.8 / 144.5 ms |
| pidfd only | 204.0 / 217.7 ms | 237.7 / 257.7 ms |
| Both optimizations | **41.8 / 52.6 ms** | **47.6 / 70.4 ms** |
| Go reference | 100.6 / 117.9 ms | 65.6 / 93.7 ms |

Both observed targets were met. HTTPS median improves 4.97 times against the baseline and is 27.4% lower than Go in this experiment. These are client gaps, excluding model preparation, and do not predict real model inference speed.

For factorial cell means `mu00`, `mu10`, `mu01`, `mu11`, average TCP saving is `(mu00-mu10+mu01-mu11)/2`, and average pidfd saving is `(mu00-mu01+mu10-mu11)/2`. HTTPS estimates are **184.6 ms** for TCP (95% paired-block bootstrap interval **174.2–194.7 ms**) and **10.3 ms** for pidfd (**0.4–21.9 ms**). Their sum equals the **194.9 ms mean total saving**. The smaller pidfd mean effect chiefly removes rare tail stalls; its median-effect interval crosses zero. Quantiles are reported separately rather than decomposed as though they were additive.

The intervals describe 20 paired randomized blocks on this machine. Observed p95 uses the nearest-rank estimate; it is not a population latency guarantee. [Raw runs, equations, hashes, and uncertainty](docs/wait-optimization.json). Reproduce with `python3 tests/bench_wait_optimization.py` after building the baseline object variants; the preserved original baseline inputs are in `build/wait-optimization/` on this machine.
