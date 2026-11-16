# Hot-path optimizations: MMIO saved PC and fixed-PC chaining

**Reviewed main revision:** FastDyn [`e44dca2`](https://github.com/boardrunner2049/FastDyn/commit/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576), with pinned QEMU base `99b54836ded8dc3271eba52deee7453efc0a13b9` and the ordered FastDyn patch series. Both mechanisms are implemented in current main. They address different recurring costs and are **independent of automatic MMIO read substitution**.

| Path | Old repeated work | Current admitted optimization |
| --- | --- | --- |
| Ordinary device MMIO callback | Allocate a register buffer and ask the GDB-style register reader for PC | QEMU passes a scalar `saved_pc` directly to version-2 MMIO callbacks |
| ARM32 fixed-PC modifier | Write PC and take a general translated-block exit on every redirect | When safe, emit a QEMU-managed direct `goto_tb` / `exit_tb` chain |

Neither changes firmware bytes, eliminates arbitrary device-model code, or guarantees a speedup for workloads not dominated by these operations.

## Build a matching QEMU

From a separate FastDyn source checkout, on the supported Linux build host:

```bash
git clone https://github.com/boardrunner2049/FastDyn.git FastDyn-hotpaths
cd FastDyn-hotpaths
git checkout --detach e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576
git submodule update --init --depth 1 third_party/common/qemu
source ./setup.sh --build-qemu \
  --qemu-targets arm-softmmu,aarch64-softmmu,x86_64-softmmu,riscv32-softmmu,riscv64-softmmu
```

The setup script applies the **five ordered** overlays: `qemu-fastdyn-plugin-icount.patch`, `qemu-fastdyn-insn-fragments.patch`, `qemu-fastdyn-mmio.patch`, `qemu-fastdyn-mmio-pc.patch`, and `qemu-fastdyn-constant-pc.patch`. Rebuild both QEMU and `build/libfastdyn.so` after changing the patch series; a stock QEMU or stale plugin header is not interchangeable. The [installation chapter](../getting-started/installation.md) describes the other dependencies. The test matrix requires GNU Arm tools and, for x86 fixture assembly, NASM.

## 1. Scalar saved PC in ordinary MMIO callbacks

This is an optimization **of ordinary device dispatch**, not a replacement for it. QEMU snapshots the PC-register value from `first_cpu` at exporter entry and forwards a scalar to the v2 FastDyn callback. Its definition is the value the existing FastDyn register-read path would have returned **at callback entry**; it is *not* a new instruction-exact PC service. Valid zero is distinguished from an absent value using `QEMU_PLUGIN_MMIO_SAVED_PC_VALID`.

The target hooks retain AArch32 R15, the selected AArch64 PC register, and the prior GDB-width normalization for x86 EIP/RIP (without adding `CS.base`) and RISC-V XLEN. The ordinary callback no longer needs a per-access `GByteArray` allocation, free, or GDB register-reader call. `core_get_pc()` remains available for other clients. Model reads/writes and their observations still pass through the normal dispatch path.

Run the **semantic equivalence** probe after building all five QEMU targets:

```bash
FASTDYN_QEMU_BUILD="$PWD/third_party/common/qemu/build" \
  tests/integration/run_fastdyn_mmio_pc_equivalence.sh
```

It compares the scalar with the existing plugin/GDB register value on Cortex-M, AArch32, AArch64, x86-16/32/64, RV32, and RV64; the x86-16 fixture uses nonzero `CS.base`. It also checks a valid saved PC of zero, the non-vCPU `first_cpu` case, and malformed/missing or version-mismatched callback descriptors.

The *separate* timed runner uses a legacy plugin built against the updated header plus a patched plugin, with MMIO substitution disabled:

```bash
FASTDYN_MMIO_PC_BASELINE_PLUGIN=/path/to/legacy/libfastdyn.so \
FASTDYN_MMIO_PC_PATCHED_PLUGIN="$PWD/build/libfastdyn.so" \
FASTDYN_MMIO_PC_ARTIFACTS=/tmp/mmio-pc-results \
  tests/integration/run_fastdyn_mmio_pc.sh
```

The checked-in [benchmark record](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/docs/mmio_saved_pc_benchmark.md) describes five alternating pairs on 11 November 2026: median `machine0.qemu_execution` **0.999059 s** for the legacy path and **0.894460 s** for the scalar path, or **1.1169×** on its million-access fixture. Each run completed 1,000,012 reads and one write. These are source-recorded host results, not measurements rerun for this book.

## 2. ARM32 constant-PC modifier chaining

An existing modifier like this is eligible for automatic promotion *without any syntax or configuration change*:

```toml
[[CPU.cpu0.modifiers]]
at = "0x08001234"
patch = "r15 <- 0x08001000"
```

On 32-bit ARM A32 and Thumb, an unconditional fixed immediate PC assignment may be lowered to QEMU's own `goto_tb` / `exit_tb` with normal linking and invalidation. The source and absolute destination must lie on the same guest page; the destination must fit ARM32 and meet the active instruction-mode alignment. A free outgoing TB slot is required. Promotion is blocked in IT/ECI/ICI or single-step state and for conflicts with fragments, uncertain or state-changing earlier callbacks, legacy detours, context-save/return regions, a second redirect in the TB, state-dependent targets, or disabled chaining. AArch64 `r15` is **not** the PC. Ineligible sites retain the original exit semantics rather than failing the run.

The optimized path keeps the original instruction's identity, accounting and block suffix. PC-relative TB reuse checks the source page at runtime; an alias mismatch performs the **same absolute PC write and general exit** as the legacy path. It does not convert to a relative branch or change ARM mode.

To compare with the legacy lowering, set the switch **before translation**:

```bash
FASTDYN_CONST_PC_CHAIN=0 fastdyn -q run -c /path/to/config.toml
```

For developer translation diagnostics, set `FASTDYN_CONST_PC_CHAIN_TRACE=1`. This is not a per-execution counter. The structural/firmware regression checks both lowering modes, A32 and Thumb outcomes, TCG operation sequences, and actual QEMU link events:

```bash
tests/integration/run_fastdyn_constant_pc.sh
```

The optional benchmark is separate from CI:

```bash
FASTDYN_CONST_PC_ARTIFACTS=/tmp/fastdyn-const-pc-results \
  fastdyn-env/bin/python tests/integration/constant_pc/benchmark.py
```

The [recorded benchmark](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/docs/constant_pc_benchmark.md) (12 November 2026, five alternating pairs of 5 million redirects) reports median **0.122967 s** with `FASTDYN_CONST_PC_CHAIN=0` versus **0.047947 s** with chaining, a **2.565×** ratio on that redirect-heavy fixture. The checked minimal FastDyn configuration has zero fixed-PC candidates; no benefit was claimed there. Neither ratio establishes a speedup for general firmware workloads.

## Reproducibility and security boundaries

Preserve the exact FastDyn and QEMU revisions, compiled plugin, firmware image, CPU/mode, enabled observer/logging settings, success markers, raw timings, and structural evidence. Compare the **same semantic work**. MMIO saved-PC timing includes ordinary dispatch, not automatic read substitution; the constant-PC microbenchmark measures redirect cost, not peripheral access or fuzzing throughput. The source reports no timing threshold as a CI acceptance criterion.

At [main CI run `43180410321`](https://github.com/boardrunner2049/FastDyn/actions/runs/43180410321), the MMIO saved-PC **equivalence** runner is not one of the visible CI steps; its source contains a standalone run script and a source-recorded passing matrix. The constant-PC smoke and automatic-MMIO six-case regression **are** explicit successful CI steps. Do not conflate these with a local rerun or a full-device test. For the separate read-substitution mechanism and its observer gates, see [Automatic MMIO optimization](../designs/automatic-mmio.md).

## Source guide

- [MMIO saved-PC contract and benchmark](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/docs/mmio_saved_pc_benchmark.md)
- [Saved-PC correctness runner](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/run_fastdyn_mmio_pc_equivalence.sh) and [paired timing runner](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/run_fastdyn_mmio_pc.sh)
- [Constant-PC modifier contract](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/docs/VirtualsAndModifiers.md) and [benchmark](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/docs/constant_pc_benchmark.md)
- [Constant-PC fixture and prerequisite notes](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/constant_pc/README.md) and [smoke](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/run_fastdyn_constant_pc.sh)
- [Ordered QEMU patch setup](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/scripts/setup/qemu.sh) and [CI test steps](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/.github/workflows/ci.yml)
