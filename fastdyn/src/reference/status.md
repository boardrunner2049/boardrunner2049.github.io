# Capability status

This book records the source revision behind each explanation. Core chapters retain the FastDyn baseline `f9666d7f518c373e89831d8e14a6371a27fe6436`; the JIT patcher and manual inline lab use `5b8bf3ddb01d63a4d5f86701d358e390a950cb9c`. Current main hot paths, automatic MMIO, and secondary execution are pinned to `e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576` (12 November 2026). Tempo is reviewed at `771b99650004fcbf3ab216970cf8fd9fae91aa6c`. Supercache has separate frontend/backend requirements in its chapter; its offline optimizer is reviewed at FastDyn `scopt` revision `124699db203aae581735b4bdfb82e9b949332405`. Presence in source does not mean every combination was executed during documentation preparation, and separately pinned branch features are not silently treated as main-branch configuration options.

## Main-branch capabilities

| Capability | Status and scope | Guide |
| --- | --- | --- |
| Configurable firmware execution | Patched QEMU, native plugin, TOML frontend, public Python run API | [First run](../getting-started/first-run.md) |
| Multiple guest targets | ARM examples; RISC-V/x86 templates and architecture-specific helpers; feature support varies | [Portability](../architecture/portability.md) |
| PC-triggered virtuals | Native runtime callbacks selected during preparation/translation | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| Register/memory modifiers | Current specialized inline operation grammar and target restrictions | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| Manual inline device modeling | Explicit `finline` access map and a single fixed GPIO backing buffer; manual site selection and target-specific behavior | [Inline device modeling](../advanced/inline-device-modeling.md) |
| Automatic MMIO optimization | Bounded, tested experimental path at `e44dca2`: ABI 2 effect/predicate/width analysis, live elder-state binding, and guarded Cortex-M Thumb read replacement. Alignment faults and active or later-registered observers remain on original dispatch; unsupported cases decline. Not a proof for arbitrary models; coverage/fuzzing disable substitution. | [Automatic MMIO](../designs/automatic-mmio.md) |
| Saved-PC MMIO exporter | Main `e44dca2`: version-2 callbacks receive the existing saved PC as a scalar instead of allocating a GDB-style register buffer per access; still ordinary device dispatch | [Hot-path optimizations](../advanced/runtime-fast-paths.md) |
| Constant-PC chaining | Main `e44dca2`: safe ARM32 A32/Thumb fixed immediate `r15` redirects can use QEMU TB chaining; same-page, mode, callback and slot restrictions with legacy fallback | [Hot-path optimizations](../advanced/runtime-fast-paths.md) |
| JIT patcher | At `5b8bf3d`: immutable guest instruction fragments inserted before an original PC; explicit ISA/mode profiles and bounded register-only subsets | [JIT patcher](../advanced/jit-patcher.md) |
| Shared host analysis | Lazy image, symbol, DWARF, decoding, and RTOS facts; at `e44dca2`, cached constant-propagation access candidates. Shared decoding currently targets Thumb/M-profile. | [Host analysis](../extending/host-analysis.md) |
| In-tree and external plugins | Preparation registration, native SDK, external runtime ABI v1 | [Plugin development](../extending/virtual-plugins.md) |
| RTOS introspection | Six adapters; task walkers and event hooks have different coverage | [Introspection](../instrumentation/introspection.md) |
| Function counts and traces | Entry instrumentation, counts, and selected argument decoding | [Tracing](../instrumentation/tracing-and-sanitizers.md) |
| VariableWatch | ELF-backed candidate analysis for named data or raw address ranges | [Tracing](../instrumentation/tracing-and-sanitizers.md) |
| ObjectSan | Instrumented object-bound checks with explicit modeled-object and target scope | [Sanitizers](../instrumentation/tracing-and-sanitizers.md) |
| C peripheral models | Elder model ABI v2 and incremental shared-library builder | [Writing models](../devices/writing-a-model.md) |
| Hardware and replay | libhw passthrough and twintrace modes with their current transaction/IRQ rules | [Hardware and traces](../devices/hardware-and-traces.md) |
| FMI physics | In-process FMI 3 runtime, build/package handling, and controller adapters | [Physics](../simulation/physics-and-fmu.md) |
| Flight-controller profiles | ArduPilot and main-branch PX4 examples; selected software boundaries and model shapes | [Flight controllers](../simulation/flight-controllers.md) |
| Optional world integration | Physical endpoint/pin adapter and observer with current ARM/scalar constraints | [World models](../simulation/world-models.md) |
| Independent campaigns | Loop and swarm tooling with worker isolation | [Multiple firmwares](../simulation/multiple-firmwares.md) |
| Coordinated guest progress | QMP budget commands, `BudgetMaster`, and a multi-guest barrier example; application supplies inter-firmware links. At `e44dca2`, select exact stopping explicitly through QMP or the client's `--exact`. | [FastDyn as a secondary simulator](../advanced/fastdyn-as-secondary.md) |
| Fuzzing | Optional fuzz engines, coverage, schema flows, and campaign integrations with target-specific reset semantics | [Fuzzing](../analysis/fuzzing.md) |
| Timing/profiling | Phase records, optional helper cProfile, QEMU perf, and FMU profiling | [Performance](../analysis/performance.md) |

## Separately pinned components

| Snapshot | What it adds | Evidence boundary |
| --- | --- | --- |
| INAV: `3910be12b82443efe8abb75ef89aa02f5ef047f4` | MATEKF405 firmware adaptation, FMU bridge, receiver input, and smoke tests | Documented source compatibility patch; short functional/flight checks, not a blanket mission qualification |
| PX4: `0e13b73986a66270a6d8452b2c0147af7b874d29` | FMUv6C profiles across five release lines, version sweep, and cache-management work | Version-specific validation levels and cache configuration requirements |
| Supercache | Translated-code caching in a separately pinned QEMU backend; managed cache configuration in the PX4 frontend snapshot | The pinned QEMU submodule base in main `e44dca2`, even after its ordinary five FastDyn patches, does not provide the separately developed persistent-cache backend. Follow the [Supercache chapter](../advanced/supercache.md) for the exact revisions, setup, and compatibility boundary. |
| Supercache optimizer: FastDyn `scopt` at `124699db203aae581735b4bdfb82e9b949332405` | Offline snapshot import, profile-guided layout, cross-block transforms, state-sync reduction, and checked native host inlining | Uses QEMU `934890ed5119ef70da69276991d921573f23ed4f` and pass-specific capture, runtime, metadata, and validation contracts. The [optimizer chapter](../advanced/supercache-optimizer.md) separates inspected code, local checks, and source-recorded runtime evidence. |
| Tempo: `771b99650004fcbf3ab216970cf8fd9fae91aa6c` | Native scheduler, federation compiler, typed port routing, tracing, and Python/TOML control plane | The shipped participant adapter and executable examples use mocks. The [Tempo chapter](../advanced/tempo.md) records the current scheduling and observation limits; this revision has no FastDyn or FMI adapter. |

[Branch previews](../simulation/branch-previews.md) gives the INAV and PX4 checkout commands, firmware identities, source links, and reported outcomes. The [Supercache chapter](../advanced/supercache.md) specifies its separate frontend/backend pair. The book does not independently rerun those flight validations.

## Read a result at its actual boundary

A boot smoke test, a sensor/motor check, and an autonomous mission establish different behavior. A high-level sensor hook and a register-level peripheral model execute different portions of the firmware. A four-channel plant interface does not establish a six-motor integration merely because a hexa configuration file exists.

Record the firmware, model, adaptation, time policy, and success condition with every result. Use the [testing and reproducibility guide](../analysis/testing-and-reproducibility.md) to decide what evidence is needed for the question being asked.

## Source guide

- [Main snapshot](https://github.com/boardrunner2049/FastDyn/tree/f9666d7f518c373e89831d8e14a6371a27fe6436)
- [JIT patcher and manual-lab snapshot](https://github.com/boardrunner2049/FastDyn/tree/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c)
- [Updated MMIO and hot-path implementation snapshot](https://github.com/boardrunner2049/FastDyn/tree/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576)
- [Source documentation overview](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/README.md)
- [Runtime SDK](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn_runtime.h)
- [Host-analysis contract](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisAPI.md)
- [Latest integration-test guide](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/README.md)
- [Secondary-simulator client and protocol](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/utils/fastdyn_cosim.py)
- [Tempo implementation snapshot](https://github.com/boardrunner2049/tempo/tree/771b99650004fcbf3ab216970cf8fd9fae91aa6c)
- [Supercache optimizer implementation](https://github.com/boardrunner2049/FastDyn/tree/124699db203aae581735b4bdfb82e9b949332405/tools/scopt)
- [Optimizer runtime source lock](https://github.com/boardrunner2049/FastDyn/blob/124699db203aae581735b4bdfb82e9b949332405/tools/scopt/fixtures/host-inline/source-lock.json)
