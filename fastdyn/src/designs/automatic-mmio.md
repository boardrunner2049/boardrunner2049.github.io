# Automatic MMIO optimization

**Status: implemented, conservatively gated on FastDyn [`e44dca2`](https://github.com/boardrunner2049/FastDyn/commit/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576).** The initial `a38af40` implementation has since been corrected: extraction rejects unproven effects and address predicates, the backend preserves alignment faults, and active or late-registered MMIO observers retain the ordinary access path. These are bounded validation results, **not a general semantic equivalence proof for arbitrary C models**.

The workflow needs neither a hand-written PC list nor a second register description. Model compilation produces operation metadata; run preparation finds candidate accesses; native initialization binds those candidates to the model's existing state. Guest loads with an admitted replacement can read that live state directly, while other operations retain ordinary device dispatch.

This is a separate mechanism from the manual [inline device modeling](../advanced/inline-device-modeling.md) access map and the [JIT patcher](../advanced/jit-patcher.md). Automatic MMIO replaces a load inside the decoder's instruction implementation. It does not insert an extra guest instruction or require a PC modifier to skip the original access.

## Build the matching revision

The [installation chapter](../getting-started/installation.md) supplies the Ubuntu 24.04 build prerequisites. Its core walkthrough uses an older source snapshot, so select this feature's revision explicitly. Also provide **Clang 18 or a compatible `clang`**, GNU Arm Embedded assembler/linker tools (`arm-none-eabi-as`, `arm-none-eabi-ld`), and the normal GLib development headers and `pkg-config`. Setup installs the Python dependencies used for firmware decoding and ELF analysis.

For a separate checkout:

```bash
git clone https://github.com/boardrunner2049/FastDyn.git FastDyn-mmio
cd FastDyn-mmio
git checkout --detach e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576
git submodule update --init --depth 1 third_party/common/qemu
source ./setup.sh --build-qemu \
  --qemu-root "$PWD/third_party/common/qemu" --skip-optifuzz
```

Run the remaining commands from this **FastDyn repository root**. An existing checkout at the same revision is also suitable. Setup builds `qemu-system-arm` and `build/libfastdyn.so` with device-model support. Its **five-patch** QEMU series is ordered as follows:

1. `qemu-fastdyn-plugin-icount.patch`
2. `qemu-fastdyn-insn-fragments.patch`
3. `qemu-fastdyn-mmio.patch`
4. `qemu-fastdyn-mmio-pc.patch`
5. `qemu-fastdyn-constant-pc.patch`

The setup script detects an already applied prefix and applies the remaining patches. It rejects an incompatible checkout instead of resetting it. Use matching QEMU headers, executable, plugin, and model library; the runtime SDK now includes the required `qemu/fastdyn-mmio.h` ABI.

## Start with the shipped demonstration

```bash
FASTDYN_KEEP_TEST_TMP=1 tests/integration/run_fastdyn_mmio_opt.sh
```

The runner prints the temporary artifact directory, assembles a Cortex-M4 Thumb fixture, builds the unmodified `tests/models/elder_echo.c` with MMIO metadata, and creates complete optimized and baseline configurations. It runs both, checks their firmware success markers, validates the optimized installation report, and prints fresh timing measurements. Keeping the temporary directory lets you inspect its generated models, configurations, logs, and work directories.

The runner now checks **six baseline/optimized pairs**: `echo`, `safety`, `predicates`, `alignment`, `observer`, and `late-observer`. For each case it requires a firmware PASS and applies focused counters and observation assertions. Output includes lines such as `PASS echo: installed=... fast=... fallback=...`, followed by `summary.json`. The firmware ELF is **stripped** before running, so the test now exercises symbol-independent discovery.

The safety case includes read-to-clear state, unused volatile/effectful operations, mutable selectors, and narrow integer behavior. Predicate tests preserve multiple selector conditions; alignment checks exercise the original fault behavior. Observer checks cover both an observer registered during setup and one registered after translation; the latter must force the original path even when sites were previously registered. The echo loop executes one million reads. These are repository test contracts and CI evidence, not a local firmware run performed while editing this book.

The default executables are `third_party/common/qemu/build/qemu-system-arm`, `build/libfastdyn.so`, and `fastdyn-env/bin/fastdyn`. Override them with `FASTDYN_QEMU_BIN`, `FASTDYN_PLUGIN_LIB`, and `FASTDYN_BIN`. Without `FASTDYN_KEEP_TEST_TMP=1`, the runner deletes its temporary directory on exit. Set `FASTDYN_MMIO_ARTIFACTS=/absolute/new/directory` to retain a reproducible artifact tree, including the paired configurations, stripped ELFs, compressed ordinary `io.log.gz` traces, timing events, model build reports, and `summary.json`. The destination must not already exist.

## Build and configure your model

The public model-build command enables extraction explicitly:

```bash
fastdyn build-model --mmio-opt --no-vio \
  tests/models/elder_echo.c -o out/mmio-models --json
```

This produces `out/mmio-models/elder_echo.so` and `elder_echo.mmio.json`. The shared library retains its normal `fastdyn_model` descriptor and includes a generated `fastdyn_mmio_model` table. The JSON file is an inspection report; the runtime reads the embedded table, so copying a JSON file beside an ordinary library does not enable optimization.

`--mmio-opt` selects `clang-18` when available, otherwise `clang`, rather than the ordinary `CC` selection. Analysis and optimized-model compilation use the same host LLVM IR, generated with `-fPIC -O1` before user `CFLAGS`. The actual library links that analyzed IR rather than recompiling C with different preprocessor flags. Dependencies include the IR, so changes affecting only slow callbacks or initialization still trigger a rebuild. Host LLVM's data layout computes GEP offsets and checks that every byte lies within a proven allocation; TBAA metadata is not an address source. Model metadata ABI **2** is required: rebuild any older `--mmio-opt` model libraries. `--no-vio` avoids the optional LibVIO dependency for this echo example; it is not the optimization switch. `--json` prints the build result, including each model's `mmio_operations` count.

The current extractor requires **one C source file per model**. A directory can still contain several independent models, but combining several sources into one model with `--name` is unsupported for this pass. If no admissible operation is found, the requested optimized build fails and removes an older output library. To retain ordinary execution for such a model, build it without `--mmio-opt`.

Extend an existing single-CPU Cortex-M configuration with the following settings. Replace the absolute library path with the output you just built; this fragment supplies device/plugin settings, not a complete machine configuration:

```toml
[CPU.cpu0.plugins.mmio_opt]
enabled = true

[Device.Models.elder]

[Device.echo]
ranges = [["0x40010000", "0x400100ff"]]
irq = [16]
reset = 287454020

[[Device.echo.handlers]]
model = "elder"
enabled = true
scroll = "/absolute/path/to/out/mmio-models/elder_echo.so"
```

The plugin currently consumes only its `enabled` setting. It obtains device ranges and the firmware analysis session from the ordinary run context; there are no user-facing PC, register, or expression lists to maintain. Keep `[Machine].finline = "None"` for this workflow. The complete smoke configuration uses `arch = "arm"`, `machine = "cortexm"`, `cpu = "cortex-m4"`, `coverage = false`, and `twintrace = "None"`.

For a comparison, create a second configuration with `mmio_opt.enabled = false`, use a separate work directory, and keep the firmware, compiled model, initial state, and execution policy fixed. Disabling the plugin leaves the same library usable through its ordinary elder callbacks.

## From model source to a guarded load

 ```mermaid
flowchart TD
    A["Elder model C source"] --> B["Analyze one matching LLVM IR"]
    C["Firmware and device ranges"] --> D["Discover effective-address candidates"]
    B --> E["Prove pure reads, bounds and predicates"]
    D --> F["Bind initialized elder instance"]
    E --> F
    F --> G{"Address / predicate / observer / alignment / MPU guards"}
    G -->|Admitted| H["Read live model state"]
    G -->|Declined or guard fails| I["Original protected load"]
    H --> J["Complete original instruction"]
    I --> J
```

The model pass starts at the `fastdyn_model` initializer and proves a single constant-sized `malloc`/`calloc` state allocation (or NULL), bounded state accesses, and read-only paths under an explicit instruction admission list. Stores, volatile/atomic operations, calls, fences, unknown operations, escaping state pointers, and unproved state lifetime decline rather than substitute. This rejects read-to-clear and other side-effectful operations, including effects whose return value is unused. Selector fields must be immutable across the reachable read/write/IRQ callbacks and aliases; each admitted address predicate is retained at binding (up to eight conjuncts). Unsupported combinations remain slow.

The bounded expression format supports constants, unsigned 8/16/32-bit state loads, and representable arithmetic/bitwise computations. It preserves narrow unsigned wraparound, truncation, and zero extension. Sign extension, unrepresentable wide or variable-shift operations, and unknown offset/alias cases decline; they are not approximated. Expressions remain limited to 16 operations.

The firmware pass uses the shared, cached `ctx.analysis.constant_propagation` service for ELF inputs. It follows vector/ELF entry points and direct control flow and attempts bounded constant propagation through literal loads, `movw`/`movt`, register copies, and immediate arithmetic. The MMIO plugin filters the resulting address candidates against configured device ranges. It distinguishes the instruction's encoded length from the memory transfer width. Undiscovered sites use ordinary execution. The [host-analysis chapter](../extending/host-analysis.md) records the current limits of these candidates; the API's `KnownMemoryAccess` name does not establish a complete dataflow proof.

The native module loads its pending plan during plugin initialization and registers `virtual_register_post_device_init()` work. After `dev_init`, elder resolves each candidate against an initialized device and its `opaque` allocation. `virtual_register_mmio_replacement()` installs the typed descriptor and copied expression; the state pointer remains bound to the live allocation. Register before guest execution: load translation seals the registry, and normal TB invalidation does not discard it.

At execution, the fast branch checks the actual effective address, active MMIO observers, alignment, and enabled MPU state. A matching admitted load evaluates the expression from live model state. A failed guard runs the **original protected QEMU load with its original MemOp flags**. Unaligned predicted sites decline installation; finalized MemOps demanding alignment checks also decline substitution. Thus `CCR.UNALIGN_TRP` faults are retained. Fast/fallback counters count completed loads rather than retries or faulted attempts. The decoder retains destination placement, predication, writeback, PC advancement, and instruction accounting. The host still restricts automatic substitution to compatible serialized runs.

## Supported scope and compatibility gates

The automatic runtime path currently targets **little-endian Cortex-M Thumb scalar `LDR`, `LDRB`, and `LDRH`**, with 1-, 2-, or 4-byte transfers. It does not optimize writes. Signed loads, wider transfers, other guest architectures, and arbitrary device side effects are outside this workflow.

| Condition | Current behavior |
| --- | --- |
| More than one CPU | Preparation error: one serialized CPU is required |
| Architecture other than `arm`, or machine other than `cortexm`/`cortexm7` | Preparation error |
| No configured device ranges | Preparation error |
| Coverage, edge coverage, fuzzing, manual `finline`, twintrace, hardware trace, or exact-budget capability enabled | Optimization disabled; `installation.json` records `disabled_reason`, and no pending plan is used |
| An effectful/volatile/atomic callback, unproved allocation or selector, unsupported predicate, or unsupported expression | Site declined; ordinary execution remains |
| Unaligned predicted site or finalized alignment-sensitive MemOp | Optimization declined or original protected load retained |
| MMIO observer active at binding | Site declined; ordinary dispatch and notifications retained |
| MMIO observer registered after translation | Live guard redirects installed sites to ordinary dispatch |
| Admitted site with a different live address or enabled MPU | Guarded fallback to the original load |

The capability names checked by the host plugin are exactly `coverage`, `edge_coverage`, `fuzzing`, `finline`, `twintrace`, `hardware_trace`, and `exact_budget`. This list is not a universal detection system for every custom observer or runtime extension.

The current plan and replacement registries each hold up to 4096 records; the ARM load emitter considers up to 64 matching records for a PC and width. A successful registration does not prove that a site was reached or that its target load was emitted through the fast path. Check execution counters as well as installation status.

## Read the generated artifacts

| Artifact | What it establishes |
| --- | --- |
| `<model>.mmio.json` beside the library | Read callback, claimed state size, operation count, declined-path count, selectors, and expression instructions produced by model analysis |
| `run-artifacts/mmio_opt/discovery.json` | Firmware path, configured ranges, decoded access records, and discovery/plan preparation time |
| `run-artifacts/mmio_opt/pending-plan.txt` | Model-independent rows: PC, address, transfer size, instruction size, and direction |
| `run-artifacts/mmio_opt/installation.json` | Prepared and registered counts; per-site address, width, device, hook ID, installation reason, fast count, and guarded fallback count |

`installation.json` first contains a pending-device-initialization marker, is rewritten after binding, and is updated with counters by the exit callback. Stop normally when you need final counts. Its `installed` field means QEMU accepted a registration; `fast_count` establishes completed fast executions. `fallback_count` counts completed guarded slow loads, excluding retries and faults, not every unoptimized access in the run. Where several records match one instruction and width, that branch is counted against the first matching record.

`discovery.json`'s `preparation_seconds` measures firmware discovery and plan creation. It excludes model compilation, native device binding, and guest execution. The model report counts declined paths but does not provide a detailed reason for every such path. Treat each artifact as evidence of its own stage.

## Safety and observation contract

The revised extractor and native guards close the specific failures reproduced during the previous review: read-to-clear or volatile operations no longer silently disappear; LLVM GEP offsets replace misleading TBAA offsets; mutable selector fields and incomplete address predicates decline; narrow unsigned arithmetic retains wraparound; and fault-sensitive unaligned loads fall back to the original memory operation. Host-generated metadata and linked library code now derive from the **same** analyzed LLVM IR.

MMIO observers are deliberately **not accelerated**. Observers active when the model is bound cause sites to decline. A later registration sets a live guard that forces already translated sites through ordinary dispatch, preserving observer counts. This assumes the serialized vCPU observer-registration lifecycle; concurrent host-thread registration is outside the evaluated contract. Fast reads without observers still skip ordinary device dispatch and per-read `io.log` writes. A model with effects or a workload requiring complete ordinary I/O tracing is not an appropriate candidate for this optimization.

These properties are bounded by the admitted model language, the Cortex-M Thumb scalar load path, and the available regression fixtures. They do not prove equivalence for arbitrary device models, other CPU architectures, unmodeled resets, or external state writers. Compare return values, post-read model state, faults, callback observations, and firmware outcomes against normal dispatch before using a new model in a fuzzing campaign. **Fuzzing and coverage currently disable this optimization**, rather than relying on an unproven fast-path equivalence.

## Evidence and recorded measurement

The source-pinned [six-case reference report](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/mmio_opt/reference-results.json) contains these echo-case values:

| Echo workload quantity | Checked-in value |
| --- | ---: |
| Discovered / installed / declined sites | 12 / 10 / 2 |
| Fast reads / completed guarded fallbacks | 1,000,010 / 2 |
| Baseline `machine0.qemu_execution` | 1.1445 seconds |
| Optimized `machine0.qemu_execution` | 0.1354 seconds |
| Firmware discovery and plan | 0.0319 seconds |
| Shared optimized-model compilation for three fixtures | 0.4957 seconds |

These numbers come from the checked-in reference on its development host, **not from an execution performed during this book update**. The echo comparison removes both dispatch and ordinary `io.log` writes; it is **not** an isolated dispatch-speed claim. Two observer cases compare equal per-access observer counters, with zero fast reads. The safety, predicates, and alignment cases exercise conservative declines and fallbacks. CI uses functional checks and counters, not timing thresholds. Review individual `summary.json`, `installation.json`, and compressed logs when comparing your own model.

[FastDyn CI for `e44dca2`](https://github.com/boardrunner2049/FastDyn/actions/runs/43180410321) completed successfully on 12 November 2026. Its successful steps included the unit suite, the six-case MMIO integration runner, two fragment smoke suites, the constant-PC chaining smoke, the minimal configuration, and bundled FreeRTOS introspection. This is a reported CI run, not an independent physical-board or firmware-fuzzing campaign run by the book maintainer.

The public regression is [`tests/integration/run_fastdyn_mmio_opt.sh`](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/run_fastdyn_mmio_opt.sh); it writes complete evidence when `FASTDYN_MMIO_ARTIFACTS` is supplied. [Performance measurement](../analysis/performance.md) explains how to report compilation, discovery, binding, guest execution, and changed observation volume separately.

## Source guide

- [Current feature overview](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/docs/AutomaticMMIOOptimization.md), [CLI option](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/src/fastdyn/main.py), and [model builder](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/src/fastdyn/model_build.py)
- [LLVM model extractor](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/src/fastdyn/mmio_model.py) and [generated metadata ABI](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/include/fastdyn/device_model.h)
- [Shared constant propagation](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/src/fastdyn/host/constants.py), [plan/report construction](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/src/fastdyn/mmio_plan.py), and [host plugin gates](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/virtuals/mmio_opt/host/preprocessor.py)
- [Runtime binding and reports](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/virtuals/mmio_opt/runtime/mmio_opt.c), [elder instance resolution](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/device_models/elder/elder.c), [ordinary device dispatch](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/device_models/dev.c), and [public runtime SDK](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/include/fastdyn_runtime.h)
- [QEMU guard and expression lowering](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/patches/qemu-fastdyn-mmio.patch) and [ordered patch setup](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/scripts/setup/qemu.sh)
- [Integration runner](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/run_fastdyn_mmio_opt.sh), [fixture/configuration](https://github.com/boardrunner2049/FastDyn/tree/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/mmio_opt), and [analyzer unit assertions](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/unit/test_mmio_model.py)
