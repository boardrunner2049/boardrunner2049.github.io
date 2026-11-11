# Virtual instructions and modifiers

FastDyn lets an experiment change what happens at a chosen guest program counter without rebuilding the firmware. A **virtual instruction** invokes a named native action. A **modifier** requests a direct register or memory assignment through the patched QEMU inline path. These are useful for injecting inputs, observing function arguments, supplying initialization behavior, raising interrupts, and redirecting selected execution paths.

The trigger is a guest instruction address. A rule has no effect until that instruction executes. Use addresses and symbols from the exact firmware image being run.

## Start with the bundled example

After building FastDyn and its patched QEMU, run from the repository root:

```bash
fastdyn -q run -c configs/minimal.toml -o fastdyn-minimal
```

The bundled configuration modifies an argument before a function call, prints the argument inside the callee, and ends the run at the scheduler startup point:

```toml
[[CPU.cpu0.modifiers]]
at = "0x0800397e"
patch = "r0 <- 3"

[[CPU.cpu0.virtuals]]
at = "0x080068b0"
instruction = "printreg"
args = ["0"]

[[CPU.cpu0.virtuals]]
at = "0x08001940"
instruction = "benchmark_end"
args = ["minimal"]
```

The observable result is register 0 containing `0x00000003`, followed by a benchmark result tagged `minimal`. The elapsed time is machine-dependent; the important functional observation is that the callee receives the configured argument. The firmware file itself remains unchanged.

## Choose a mechanism

| Desired behavior | Mechanism |
| --- | --- |
| Assign a fixed input value at an instruction | Modifier |
| Redirect a specific execution path | PC modifier, using the target's explicit PC name |
| Raise an IRQ, start a timer, or load a payload | Existing virtual instruction |
| Perform custom native work | Runtime callback plus Python `VirtualDefinition` |
| Derive many hooks from firmware analysis | Run preprocessor that emits virtual rules |

Both mechanisms are installed during translation and take effect during execution. A virtual uses a C callback. A modifier uses specialized inline update operations. This is a mechanism distinction, not a universal performance result: actual overhead depends on what is instrumented and how often it executes.

## Virtual configuration

Virtual entries live under a CPU's `virtuals` array. `args` is optional and contains string tokens. FastDyn prepares and joins the tokens into the argument string received by the callback. A symbol or `symbol+offset` can identify a trigger when the firmware provides the required symbols.

This fragment illustrates interrupt injection; replace the address with a suitable instruction in your image:

```toml
[[CPU.cpu0.virtuals]]
at = "0x08001234"
instruction = "raise_periodic_irq"
args = ["15,1000000"]
```

Here `15` is the exception vector and `1000000` is the period in nanoseconds. The trigger PC is neither the interrupt vector nor the period. Numeric interrupt arguments are passed through as exception vectors. The Cortex-M preparation adapter can resolve supported symbolic SVD IRQ names.

### Core callback catalog

| Name | Argument shape | Behavior |
| --- | --- | --- |
| `raiseirq` | IRQ vector | Raise the configured IRQ |
| `pulseirq` | IRQ vector | Pulse the configured IRQ |
| `raise_periodic_irq` | `irq[,period_ns]` | Register a periodic interrupt |
| `updatemem` | `address:r\|w:length:byte,...` | Read or write guest memory; both forms require the byte-list parser field |
| `randstate` | Comma-separated register numbers or addresses | Randomize selected state; avoid using it for the PC |
| `printreg` | Register number | Print a register |
| `debug_log` | Message | Emit a diagnostic with CPU and virtual-time information |
| `benchmark_start` | None | Start a host monotonic-time region |
| `bench_tick` | None | Increment that benchmark's tick counter |
| `benchmark_end` | Optional tag | Report elapsed time and terminate QEMU |
| `timer_start` | Ignored | Start the legacy fixed-period virtual-clock timer |
| `start_budgeting` | Ignored | Enter plugin budget waiting |
| `dyninst` | `address:file` | Load a host file's bytes into guest memory |
| `dyninst_lib` | ELF file | Load an ELF through the QEMU plugin API |
| `dumplog` | `logger-index:file` | Write an internal logger buffer |

`dyninst` is a runtime memory-loading operation. The newer [JIT patcher](../advanced/jit-patcher.md) instead registers guest instruction bytes during plugin initialization and emits admitted fragments through the translator without writing those bytes into guest memory. Explore the virtual and modifier catalog with `fastdyn help virtuals --no-browse` and `fastdyn help modifiers --no-browse`; the fragment API is a native runtime SDK facility.

## Modifier grammar

Use `patch = "target <- value"`. The parser also accepts `=`, `:=`, and `->`, but `<-` is the canonical spelling.

| Form | Interpretation |
| --- | --- |
| `rN` or `xN` | Numeric register slot |
| `[rN]` or `[xN]` | Memory through a register-held pointer |
| `0xADDRESS` on the left | Absolute guest-memory target |
| Decimal or hexadecimal integer on the right | Immediate value |
| Register or register dereference on the right | Source operand, where the target backend implements the form |
| `rip`, `rsp` | Explicit x86-64 inline-register aliases |
| `riscv_pc`, `pc32` | Explicit RISC-V PC slot |

Use `r15`/`r13` for ARM32 PC/SP, `rip`/`rsp` for x86-64, and `riscv_pc` with the appropriate `xN` registers for RV64. The generic `pc` alias currently resolves to slot 32 in the native parser, while `sp` resolves to 13. They are not portable architecture selectors. Modifier slots also belong to the inline backend's convention; do not assume they equal every runtime SDK register index.

The current absolute-memory target path warns and skips an address greater than `0x40000000`. It should therefore not be presented as a general MMIO-write facility. Memory access widths and supported operand combinations follow the patched backend; this syntax is not an arbitrary typed expression language.

## Composition and troubleshooting

Host preparation allows one distinct virtual callback at a trigger PC. Identical rules collapse; different rules at the same PC produce a conflict naming their origins. Function Counter and Function Tracer, for example, may both select the same function entry. Narrow their selections or run separate experiments.

Modifiers may coexist with a virtual, but overlapping updates need deliberate semantics. The current native registration order is logging, virtual callback, inline I/O, modifiers, then legacy detours. Avoid treating file order as a callback-composition API.

For an unexpected result, inspect `virtuals/virtuals.txt` and `virtuals/modifiers.txt` in the work directory, confirm the instruction is reached, and check the architecture-specific register mapping. An instruction may overwrite a value you assigned immediately before it; select the hook location according to the intended data flow.

## Legacy manual inline I/O

`[Machine].finline` accepts a user-supplied static access-map file. The frontend forwards its path to the native parser; this path consumes an already prepared table and does not itself run the MMIO discovery helper. A schematic record is:

```text
0x08001234 R gpioa 0x10 0x0
```

The five fields are hexadecimal PC, direction, device label, hexadecimal offset, and hexadecimal register slot. Direction accepts `R`/`READ` and `W`/`WRITE`, case-insensitively. The first matching record for a PC is used. The table has no transaction-width field; admitted register and access semantics belong to the patched backend.

This manual translation path uses the offset into a single 1 KiB `gpio_memory` buffer and does not select a backing region from the device label. Keep every access within that buffer: the native table reader does not bounds-check the offset. The hook runs before the original instruction; it does not suppress that instruction by itself. The [inline device modeling chapter](../advanced/inline-device-modeling.md) explains the backend's transfer width, an explicit same-site PC modifier for skipping the original MMIO, and the required control-flow checks in a lab pinned to `5b8bf3d`.

## Experimental automatic MMIO

Revision **`a38af408451394ea2f41be1e9cf1e96bc46c370f`** adds the `mmio_opt` run plugin. It combines model-operation metadata with discovered Cortex-M Thumb access sites, binds reads to initialized elder instances, and registers guarded replacements through the native runtime SDK. The [runtime module](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/virtuals/mmio_opt/runtime/mmio_opt.c) and [QEMU patch](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/patches/qemu-fastdyn-mmio.patch) implement this separate path.

A successful fast arm replaces the original scalar read directly; it needs no manual PC-skipping modifier. The [host compatibility gate](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/virtuals/mmio_opt/host/preprocessor.py) disables automatic substitution when `finline` is active. Use [Automatic MMIO optimization](../designs/automatic-mmio.md) for configuration, the shipped demonstration, and the experimental limits that must be checked before treating a replacement as equivalent.

## Source guide

- [Runnable minimal example](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/minimal.toml)
- [Native modifier parser, access-map parser, and instrumentation order](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/core/core.c)
- [Built-in native callbacks](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/virtuals.c)
- [Trigger preparation and conflict detection](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/virtual_preprocessing.py)
- [Forwarding the supplied inline-I/O table](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
- [Existing callback and modifier reference](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VirtualsAndModifiers.md)
