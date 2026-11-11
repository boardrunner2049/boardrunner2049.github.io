# JIT patcher

FastDyn can insert a bounded sequence of guest instruction bytes immediately before an existing firmware instruction. Its patched QEMU translates those bytes through the target's own instruction decoder and emits their operations into the same TCG stream as the original instruction. This is useful for computing a register value, masking an argument, or changing the flags that the next firmware instruction observes.

The implementation described here is present in FastDyn main at [`5b8bf3d`](https://github.com/boardrunner2049/FastDyn/commit/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c). Its public name is **guest instruction fragments**, and its native SDK entry point is `virtual_insert_before`. The API accepts encoded guest bytes and an explicit encoding profile. Assembly text is assembled ahead of time with external tools; there is no public runtime assembler API.

For a fixed register assignment or a native action, see [virtual instructions and modifiers](../instrumentation/virtuals-and-modifiers.md). The [translation insertion design](../designs/translation-insertion.md) explains the address and decoder boundaries behind this facility.

## What executes, and where

A fragment is attached to an existing guest PC. Its bytes live in a host-owned registration, outside the firmware image. Decoding advances through that buffer without relocating the original code. If the original instruction is at `P` and its length is `L`, its ordinary fallthrough remains the architecture-defined `P + L`. Symbols, original instruction bytes, and plugin instruction identities remain tied to the firmware.

At a matching site, the start-of-instruction observer executes first, fragments execute in registration order, and the original instruction then observes their effects. Fragments deliberately change architectural registers and flags; FastDyn does not automatically save or restore them. A fragment runs whenever execution reaches its site. If an exception retry reaches that site again, the fragment runs again, so the contract is not exactly once per retired original instruction.

Inserted operations do not create extra guest instruction handles or increase guest instruction counts. They add translated host work and can change the firmware's subsequent path. Instruction counting therefore does not measure the amount of inserted work, and this mechanism does not assign simulated cycle costs to that work.

## Public C API and lifecycle

Include `fastdyn_runtime.h`, which requires the patched QEMU header `qemu/fastdyn-fragments.h`:

```c
bool virtual_insert_before(const VirtualContext *ctx, uint64_t guest_pc,
                           const uint8_t *code, size_t code_size,
                           const FastDynCodeSpec *code_spec,
                           uint64_t *out_hook_id);
```

| Argument | Contract |
| --- | --- |
| `ctx` | The plugin's runtime context, supplied to its initializer |
| `guest_pc` | Numeric original instruction address, subject to the profile's width and alignment rules |
| `code`, `code_size` | Nonempty buffer of complete instructions for the specified guest encoding |
| `code_spec` | `FastDynCodeSpec` with `isa`, `mode`, and `instruction_order` |
| `out_hook_id` | Optional output pointer; receives a nonzero opaque ID on success and zero on failure |

Register from the native plugin initializer, before guest translation starts. Calling from a translation hook is already too late. The first translation seals the registry, and there is no live replacement, removal, or per-vCPU variant. Registrations survive ordinary translation-block invalidation; retranslation emits the registered operations again from the same immutable plan.

A successful call copies both the descriptor and the bytes. Stack-backed descriptors and temporary byte buffers can therefore be released or changed after registration. The ID identifies a registration for diagnostics; it is not a patch-editing handle. Matching uses the numeric PC plus the complete ISA, mode, and instruction-order profile. Different profiles can coexist at the same numeric address, but bytes registered for one profile are never reinterpreted as another. An inactive profile does not make its fragment execute.

The limits are **128 decoded instructions** and **2048 input bytes**, checked independently for each fragment and for all matching fragments at one site/profile. The current registry holds at most **1024 registrations** across the QEMU execution. Splitting a larger sequence into several registrations at the same site does not evade the combined limit.

### A concrete initializer

This reduced example uses the committed Thumb bytes from the shipped plugin. It is specific to `tests/integration/guest_code_fragments/thumb_external.S`, whose original `mov r1, r0` is at `0x0a`:

```c
#include <fastdyn_runtime.h>

static int initialize(const VirtualContext *ctx)
{
    /* and.w r0, r0, #255; add.w r0, r0, #7 */
    static const uint8_t code[] = {
        0x00, 0xf0, 0xff, 0x00, 0x00, 0xf1, 0x07, 0x00,
    };
    const FastDynCodeSpec spec = {
        .isa = FASTDYN_GUEST_ISA_ARM,
        .mode = FASTDYN_CODE_MODE_THUMB,
        .instruction_order = FASTDYN_INSN_ORDER_LITTLE_ENDIAN,
    };
    uint64_t hook_id = 0;

    if (!virtual_insert_before(ctx, UINT64_C(0x0a), code, sizeof(code),
                               &spec, &hook_id)) {
        return -1;
    }
    return 0;
}

FASTDYN_EXTERNAL_PLUGIN("guest_code_fragments", initialize);
```

The address is the even Thumb instruction address, not a function pointer carrying the Thumb-state bit. For another firmware image, determine the actual instruction address and active mode again. The shipped initializer reads its address and profile from a prepared artifact instead of hard-coding them.

## Encoding profiles and inline eligibility

The profile constants use the prefixes `FASTDYN_GUEST_ISA_`, `FASTDYN_CODE_MODE_`, and `FASTDYN_INSN_ORDER_`. For example, the Thumb descriptor above combines ISA `ARM`, mode `THUMB`, and order `LITTLE_ENDIAN`.

| ISA and modes | Address and instruction-order rules | Examples of admitted forms |
| --- | --- | --- |
| `ARM`: `A32` | 32-bit PC, 4-byte alignment, active instruction byte order | AL-condition scalar register/immediate arithmetic and logical forms, comparisons, immediate operand shifts, MOVW/MOVT |
| `ARM`: `THUMB` | 32-bit PC, 2-byte alignment, active instruction byte order | 16-bit scalar shifts and data processing; selected Thumb-2 logical/arithmetic forms, ADDW/SUBW, SBFX/UBFX |
| `AARCH64`: `A64` | 4-byte alignment, little-endian instruction bytes | Add/sub, logical forms, MOVZ/MOVN/MOVK, bitfield shifts and extensions |
| `X86`: `X86_16`, `X86_32`, `X86_64` | Any byte address; 16/32-bit modes require a 32-bit PC; little-endian | Register-only MOV/ADD/OR/AND/SUB/XOR/CMP/TEST, selected immediates and shifts, MOVZX/MOVSX, long-mode MOVSXD |
| `RISCV`: `RV32`, `RV64` | 2-byte alignment; RV32 requires a 32-bit PC; little-endian | LUI, base integer arithmetic, logical operations, shifts, comparisons, RV64 word forms, selected compressed integer forms |

These are bounded subsets, not all instructions in each family. Guest-memory operands, PC-relative and literal accesses, branches and other control transfers, exception instructions, system operations, atomics, floating point, and vectors are excluded. There is no callback or interpreter fallback for an ineligible fragment. Admitted instructions use the existing frontend's lowering; the API does not expose arbitrary TCG operations, host helpers, or host-state bindings.

Architecture semantics still matter. AArch32 rejects insertion at an IT instruction or in active IT/ECI/ICI state. Fragment instructions execute when the site is reached and can alter the flags used by the original instruction. A64 retains the operand-dependent ZR/SP meaning of register 31 and zero-extension on W-register writes. x86 retains partial-register, operand-size, REX, and lazy-condition-code behavior. RISC-V preserves x0, restores operation width between inserted instructions, and requires C or Zca for admitted compressed encodings.

FastDyn also checks the QEMU target before registration. The `arm` target accepts A32/Thumb; `aarch64` accepts A64 and its AArch32 profiles; `x86_64` accepts all three x86 modes, while `i386` accepts 16/32-bit modes. The `riscv32` and `riscv64` targets admit their corresponding profiles. Availability of a profile does not establish that every CPU model, instruction encoding, or machine setup has been exercised.

### Other hooks at the same address

The current observer whitelist contains `printreg`, `debug_log`, `benchmark_start`, and `bench_tick`. These callbacks can coexist with fragments and observe the state before fragment execution. A custom callback does not become compatible merely because its author intends it to be read-only; the public API has no fragment-specific observer classification flag.

A same-site program-counter modifier, detour, or unclassified/state-changing virtual callback is rejected before the affected block executes. This preserves the insertion's placement relative to the original instruction. Choose separate sites when the experiment needs both fragment arithmetic and a control-changing action.

## Run the shipped external plugin

Use revision `5b8bf3d` for this workflow; the older checkout in the core installation tutorial predates the fragment API and smoke scripts. After installing the [build prerequisites](../getting-started/installation.md), create a dedicated checkout from the directory where you keep repositories:

```bash
git clone --filter=blob:none https://github.com/boardrunner2049/FastDyn.git FastDyn-jit
cd FastDyn-jit
git checkout --detach 5b8bf3ddb01d63a4d5f86701d358e390a950cb9c
```

Run the remaining commands from this **FastDyn source repository root**. The public smoke needs a host C compiler, `pkg-config` with GLib development files, GNU Arm assembler/linker tools, patched `qemu-system-arm`, `build/libfastdyn.so`, and the FastDyn Python environment.

```bash
source ./setup.sh --build-qemu \
  --qemu-root "$PWD/third_party/common/qemu" --skip-optifuzz
tests/integration/run_fastdyn_guest_code_fragment_smoke.sh
```

Setup applies `qemu-fastdyn-plugin-icount.patch` followed by `qemu-fastdyn-insn-fragments.patch`. Its [ordered patch handling](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/scripts/setup/qemu.sh) recognizes an applied series and rejects an incompatible checkout. A stale header cannot silently disable the feature: the runtime SDK requires the fragment ABI include.

The runner compiles `tests/plugins/guest_code_fragments/runtime/guest_code_fragments.c` into a shared library linked against the same `libfastdyn.so` that QEMU loads. It copies the host preprocessor into a temporary plugin directory, assembles the Cortex-M fixture, writes a complete configuration, and launches FastDyn. The preprocessor writes a namespaced `settings.txt`; the native initializer selects the committed bytes and registers them.

For your own configuration, the plugin settings have this shape. The `source` directory must contain the prepared `host/` code and compiled `runtime/` library; use the fixture's PC only with that fixture:

```toml
[CPU.cpu0.plugins.guest_code_fragments]
enabled = true
source = "/absolute/path/to/prepared-plugin"
profile = "thumb"
pc = 0x0a
```

The available plugin profile strings are `a32`, `thumb`, `a64`, `x86_16`, `x86_32`, `x86_64`, `rv32`, and `rv64`.

The fixture initializes `r0` to 1. Its `printreg` observer runs at `0x0a` before the fragment, so the expected observation is `Reg 0:0x00000001`. The fragment computes `(r0 & 255) + 7`; the unchanged original `mov r1, r0` then copies 8 into `r1`. The fixture checks that result and prints `PASS fastdyn external fragment`. The runner also requires these success markers:

```text
PASS FastDyn external-plugin initialization and public fragment API
PASS same-site observer ordering: observer, fragment, original instruction
```

Further cases deliberately reject a PC modifier, a state-changing callback, and an A64 profile requested from the ARM target. Those expected failures are part of the smoke. The runner removes its temporary files on exit. Override `FASTDYN_QEMU_ROOT`, `FASTDYN_QEMU_BIN`, `FASTDYN_PLUGIN_LIB`, or `FASTDYN_BIN` when using nondefault source, binary, library, or environment paths.

## Architecture probes and byte regeneration

The wider matrix uses a direct QEMU plugin to test the fragment ABI and target frontends. It additionally needs NASM, LLVM's `llvm-mc`, LLD's `ld.lld`, and host binutils. Build the five QEMU executables and run:

```bash
source ./setup.sh --build-qemu \
  --qemu-root "$PWD/third_party/common/qemu" --skip-optifuzz \
  --qemu-targets arm-softmmu,aarch64-softmmu,x86_64-softmmu,riscv32-softmmu,riscv64-softmmu
FASTDYN_QEMU_BUILD="$PWD/third_party/common/qemu/build" \
  tests/integration/run_guest_code_fragments_smoke.sh
```

| Shipped probe | Assertions and boundaries |
| --- | --- |
| Cortex-A A32/Thumb and Cortex-M Thumb | 100 inserted arithmetic instructions, consumption by original firmware, fragment-produced flags; separate Thumb IT rejection |
| A64 on Cortex-A53 | 100-instruction sequence including X20, 64-bit values, W-write zero-extension, and XZR sources |
| x86-16/32/64 | Real, protected, and long-mode sites; ordering, copied buffers, retranslation, original plugin handles/sizes, page-boundary rollback, and lazy-flag exception restoration |
| RV32/RV64 | 100-instruction sequences exercising integer predicates, x0, and RV64 word results; separate RV32 compressed-extension acceptance/rejection |
| Registry validation | Malformed/truncated input, a forbidden x86 tail, address constraints, separate byte/instruction limits, combined-site limits, and registration after translation starts |

The complete FastDyn SDK and external-plugin path is exercised by the separate Thumb smoke above. The matrix uses little-endian fixtures; it does not establish big-endian AArch32 coverage, every CPU model, or every admitted encoding. Both runners are configured in the pinned [FastDyn CI workflow](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/.github/workflows/ci.yml). The tests and assertions described here were inspected in source; no QEMU build or firmware smoke was executed while preparing this chapter.

To verify that source assembly still produces the committed plugin byte arrays, run:

```bash
tests/plugins/guest_code_fragments/fragments/regenerate.sh
```

This script uses GNU Arm tools, LLVM including `llvm-objcopy`, and NASM, rejects unresolved relocations, and compares the emitted `.text` bytes with the committed arrays. Its expected success line is `PASS generated fragment bytes match the committed C fixtures and contain no relocations`. These assemblers are development dependencies; registration consumes the prepared bytes directly.

## Diagnose a rejected or inactive fragment

Validation has two stages. Registration checks the descriptor, target availability, address, buffer structure, instruction count, and byte limits. A failed registration returns `false`, leaves the output ID zero, and installs no new fragment. Return an initializer error when registration is required, as the shipped plugin does.

Live translation completes the target-specific checks, including instruction eligibility, CPU extensions, and ARM continuation state. A successful registration alone does not prove that every matching site can translate. A translation failure reports the hook ID, PC, fragment byte offset, encoding profile, and reason, then terminates translation before that block executes. A valid prefix is not executed as a partial fallback.

For an inactive fragment, verify that execution reaches the numeric PC in the registered mode and instruction byte order. For `translation has started`, move registration into initialization. For an unavailable profile, select the matching patched QEMU target. For a subset or continuation-state rejection, choose admitted encodings and a legal site. For an unexpected register value, check observer ordering and whether the original instruction overwrites the fragment's result.

## Source guide

- [Feature contract and profile catalog](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/docs/GuestInstructionFragments.md)
- [Public runtime header](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/include/fastdyn_runtime.h) and [SDK implementation](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/virtuals/runtime_sdk.c)
- [Target checks and hook conflicts](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/core/core.c), plus the [observer whitelist](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/virtuals/virtuals.c)
- [QEMU registry, shared ABI, and architecture adapters](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/patches/qemu-fastdyn-insn-fragments.patch)
- [Shared external plugin and source assembly](https://github.com/boardrunner2049/FastDyn/tree/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/tests/plugins/guest_code_fragments) and [public SDK smoke](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/tests/integration/run_fastdyn_guest_code_fragment_smoke.sh)
- [Architecture runner](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/tests/integration/run_guest_code_fragments_smoke.sh) and [probe assertions](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/tests/integration/guest_code_fragments/qemu_fragment_probe.c)
