# Architecture and portability

FastDyn's architecture spans more than Cortex-M. Its machine configuration and native SDK include multiple guest targets, while some of its most developed examples and analyses use ARM microcontrollers. Portability is therefore a property of a particular combination of execution backend, firmware, plugin, and model.

## Four questions to ask

1. Is the appropriate patched QEMU target built?
2. Does the selected machine provide the execution environment needed by the image?
3. Do the enabled analyses and runtime plugins support the guest's ISA, mode, widths, and ABI?
4. Does the environment model implement the boundary this experiment uses?

Answer all four before moving a configuration between architectures. A register-name mapping cannot by itself port a Cortex-M interrupt model or a Thumb-specific instruction analysis.

## Current source coverage

| Layer | Evidence in the inspected revision | Practical interpretation |
| --- | --- | --- |
| Default build and shortest tutorials | `arm-softmmu`, Cortex-M fixtures | The native quick start is centered on ARM microcontroller examples |
| Additional guest configurations | `configs/riscv_64.toml`, `configs/intel_x86_64.toml` | Target templates exist; they require their own binaries, paths, and matching QEMU builds |
| Native architecture helpers | ARM32, ARMv7-M, AArch64, RV64, x86-64 headers | Runtime plugins can select explicit register and ABI definitions |
| Function entry tracing | ARM32, AArch64, RV64, System V AMD64 layouts | The tracer has explicit entry-argument layouts rather than one universal register scheme |
| Shared instruction decoder | ARM with `thumb-mclass` | Unsupported combinations raise a target error |
| VariableWatch and ObjectSan planning | Current shared Thumb/M-profile analysis | These plugins do not become portable solely by changing `arch` |
| RTOS introspection | Six adapters with different discovery and runtime behavior | Use the adapter-specific contract and demonstrated fixture, not a blanket architecture claim |
| Device and interrupt infrastructure | Several current windows and IRQ paths are M-profile-specific | Review these paths when adapting a different machine |

The target templates are not a claim that every example has been executed on every architecture. The [capability status](../reference/status.md) records what each category means in this book.

## Guest state needs its actual width

The native SDK provides `virtual_read_register_bytes()` and `virtual_write_register_bytes()` for complete target-register representations. Its 32-bit convenience operations remain useful when a register or value is actually 32 bits. A portable plugin must not truncate an RV64 or x86-64 pointer simply because the original example used `uint32_t`.

Use the selected architecture header for register identifiers and argument conventions. Account for byte order, stack alignment, return-value layout, and registers that have special write semantics. Cortex-M's link-register and Thumb conventions are local target rules, not the definition of a FastDyn virtual instruction.

Guest addresses also differ from host pointers. Use the runtime memory APIs to access guest memory and the model API's supplied instance state to access host-side device state. A shared backing block needs an explicit mapping; it is not established by casting an address.

## Host platforms and dependencies

The documented source installation targets Ubuntu 24.04. The FMI package/runtime code handles Linux host binaries for x86-64 and AArch64. This describes that subsystem's packaging capability; it is not a tested claim that every FastDyn dependency, optional backend, and board probe works on every host.

The default setup builds the ARM QEMU executable. When using another guest, select the corresponding patched QEMU build target and executable. A system QEMU that lacks FastDyn's extensions is not a drop-in substitute. Keep the firmware compiler, guest architecture, QEMU target, native plugin, and host FMU binary identities distinct in your experiment record.

## Designing portable extensions

Keep generic policy separate from architecture mechanics. A host analysis can return an address or a candidate access description; an architecture adapter supplies decoding, ABI rules, and instruction effects. A runtime plugin can share its event logic while using target-specific state-access helpers.

The [JIT patcher](../advanced/jit-patcher.md), reviewed at the newer main revision `5b8bf3d`, follows this rule: one byte-fragment registration contract with explicit ISA, mode, and instruction order, backed by target-specific admission and decoding. Its [translation insertion design](../designs/translation-insertion.md) explains how original guest addresses remain stable. The proposed [function harness](../designs/function-execution.md) likewise separates dependency planning from ABI setup. Neither interface is defined around one microcontroller family.

## Source guide

- [Build defaults and target selection](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/setup.sh)
- [RISC-V configuration template](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/riscv_64.toml)
- [x86-64 configuration template](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/intel_x86_64.toml)
- [Native register access contract](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn_runtime.h)
- [Host-analysis support boundary](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisAPI.md)
- [Function-tracer host implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/function_tracer/host/preprocessor.py)
