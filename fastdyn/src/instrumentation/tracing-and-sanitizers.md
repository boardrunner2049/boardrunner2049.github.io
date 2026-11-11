# Tracing, watches, and selected-object checking

FastDyn's observation plugins let you choose the abstraction that matches the question. Function Counter summarizes activity. Function Tracer records entry arguments. VariableWatch follows a source variable or address range. ObjectSan tracks the identity and lifetime of selected objects as pointers move through execution.

Each feature prepares its firmware-specific information before QEMU starts and writes results under its own `run-artifacts/<plugin>/` directory. This gives you inspectable manifests as well as runtime output.

| Question | Plugin | Primary result |
| --- | --- | --- |
| Which selected functions execute, and how often? | `function_counter` | `counts.tsv` |
| What arguments reach a selected function? | `function_tracer` | `trace.tsv` |
| Which actual accesses touch this variable or field? | `variable_watch` | `events.tsv` |
| Does a selected object's pointer escape its bounds or survive its lifetime? | `object_sanitizer` | `violations.tsv` |

## Count function entries

Run the bundled example from the repository root after building FastDyn:

```bash
fastdyn run -c configs/function_counter.toml -o fastdyn-function-counter
```

Stop it with Ctrl-C so the native shutdown callback can write final counts. `functions.tsv` records installed entry hooks; `counts.tsv` reports calls, sorted by decreasing count, including selected functions that were never observed.

For your own image, narrow the selection:

```toml
[CPU.cpu0.plugins.function_counter]
enabled = true
include = ["main", "sensor_*"]
exclude = ["sensor_busy_poll"]
max_functions = 128
```

Patterns are shell-style symbol-name globs. The preprocessor uses defined executable function symbols, chooses one name for aliases at an address, and normalizes ARM Thumb function addresses when appropriate. It fails when the selection is empty or exceeds the configured limit. The maximum supported selection is 4096 functions.

These are entry counts, not inclusive execution time. An inlined function without an independent entry is not represented as an ordinary call hook.

## Trace arguments at function entry

Function Tracer augments the same selection pattern with a DWARF-derived argument schema:

```bash
fastdyn run -c configs/function_tracer.toml -o fastdyn-function-tracer
```

Its output includes `functions.tsv`, `arguments.tsv`, `trace.tsv`, and final `counts.tsv`. Each trace record contains the reported guest instruction count, entry PC, function name, and rendered arguments. The schema records how selected values should be obtained from registers or the caller's stack.

The trace's `icount` field comes from FastDyn's native counter. At this revision, the block-execution hook that advances that counter is installed for TwinTrace modes, so a default run can report zero throughout. Do not interpret zero as an absence of execution or use this field as exact instruction-retirement accounting.

```toml
[CPU.cpu0.plugins.function_tracer]
enabled = true
include = ["my_api_*"]
max_functions = 64
max_events = 10000
```

The implementation contains entry-ABI layouts for ARM32/AAPCS, AArch64, RV64, and System V AMD64. It recognizes bounded scalar, pointer, array, and structure descriptions, including up to eight direct scalar or pointer fields of a structure. It does not evaluate arbitrary DWARF locations, dereference arbitrary pointers, decode nested aggregates, or implement every aggregate-classification rule of those ABIs. Treat it as a bounded entry tracer and inspect `arguments.tsv` when an argument matters to your experiment.

The default event cap is 100000; zero removes the cap. Restricting function selection is usually more useful than capturing an enormous trace of frequent internal calls.

Function Counter and Function Tracer can select the same PCs. The virtual dispatcher accepts one distinct callback per PC, so use separate runs or disjoint selections when their hooks overlap.

## Watch a source variable or raw range

VariableWatch resolves a fixed-address global or structure-member path:

```toml
[CPU.cpu0.plugins.variable_watch]
enabled = true
variable = "motor_state.temperature"
access = "write"
changes_only = true
```

It uses the field's actual address and size. An access to an adjacent field does not match unless its byte range overlaps the watched range. Runtime matching considers partial overlap and actual direction, rather than comparing only the starting address.

For an address-based watch, replace `variable` with `address` and a positive `size`:

```toml
[CPU.cpu0.plugins.variable_watch]
enabled = true
address = "0x20001420"
size = 4
access = "read_write"
```

Use exactly one selection form. Address selection needs no DWARF variable lookup. It is a raw **address-range** mode, not a claim of arbitrary flat-binary support: the shipped example still loads an ELF, and the candidate planner reads executable ELF sections. The included examples are:

```bash
fastdyn run -c configs/variable_watch.toml -o fastdyn-variable-watch
fastdyn run -c configs/variable_watch_raw.toml -o fastdyn-variable-watch-raw
```

`watch.tsv` records the normalized target, `candidate_accesses.tsv` records conservative candidate PCs, and `events.tsv` records matched runtime accesses. Events include the PC, containing function, direction, actual address/width, and watched bytes. Byte values retain target byte order. `changes_only` suppresses unchanged writes in the TSV output; native subscribers still receive matching filtered accesses.

The current candidate planner and runtime target ARM Thumb/Cortex-M. The planner retains uncertain indirect accesses rather than discarding them because static pointer recovery failed.

## Track a selected object's identity

ObjectSan instruments selected objects and tracks provenance through supported operations. A static selection can name an object or all fixed-address globals of a supported DWARF type:

```toml
[CPU.cpu0.plugins.object_sanitizer]
enabled = true
object = "packet_buf"
```

For a dynamic allocation, selection can identify a direct allocation call by caller and one-based ordinal:

```toml
[CPU.cpu0.plugins.object_sanitizer]
enabled = true
function = "create_packet"
allocation = 1
allocator_model = "freertos"
```

The included normalized allocator models cover libc, FreeRTOS, Zephyr, NuttX, RT-Thread, ChibiOS, and ThreadX. Custom allocation/free APIs can be described in the plugin's `allocators` array. These models normalize events; they do not imply full support for every allocator calling pattern.

At a selected allocation, the runtime creates an object identity from the returned pointer. Freeing it marks that identity `FREED`. If a numerical address is reused, the new allocation gets a new identity, allowing stale pointers to remain distinguishable. Pointer arithmetic retains a selected object's provenance, so an access beyond its bounds can still be associated with the original object.

Run the purpose-built examples:

```bash
fastdyn run -c configs/object_sanitizer_static_oob.toml -o fastdyn-objectsan-static
fastdyn run -c configs/object_sanitizer_dynamic_oob.toml -o fastdyn-objectsan-dynamic
```

Inspect `objects.tsv`, `object_events.tsv`, `allocation_sites.tsv`, `instructions.tsv`, and `violations.tsv` under `run-artifacts/object_sanitizer/`. The violation reasons are `spatial-overflow`, `use-after-free`, and `unknown-provenance`. The last is an uncertainty report, not a confirmed safe access or necessarily a concrete memory bug.

This is selected-object checking with an ARM Thumb/M-profile planner and supported provenance operations. It is not complete memory-safety verification. Inferred allocation-type selection, indirect allocator calls, and proof-based relevance pruning remain outside the implemented selection contract.

## Source guide

- [Function Counter implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/function_counter/host/preprocessor.py)
- [Function Tracer ABI and schema preparation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/function_tracer/host/preprocessor.py)
- [VariableWatch target resolution and candidate generation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/variable_watch/host/preprocessor.py)
- [VariableWatch runtime and subscriber contract](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VariableWatch.md)
- [ObjectSan configuration, artifacts, and scope](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/ObjectSan.md)
- [Native counter and block-execution hook](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/core/core.c)
