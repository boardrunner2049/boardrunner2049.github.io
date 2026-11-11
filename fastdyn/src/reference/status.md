# Capability status

This book records the source revision behind each explanation. Core chapters retain the FastDyn baseline `f9666d7f518c373e89831d8e14a6371a27fe6436`; the JIT patcher and manual inline lab use `5b8bf3ddb01d63a4d5f86701d358e390a950cb9c`. Automatic MMIO and the related API additions were reviewed at main `a38af408451394ea2f41be1e9cf1e96bc46c370f`. Supercache has separate frontend/backend requirements in its chapter. Presence in source does not mean every combination was executed during documentation preparation, and separately pinned branch features are not silently treated as main-branch configuration options.

## Main-branch capabilities

| Capability | Status and scope | Guide |
| --- | --- | --- |
| Configurable firmware execution | Patched QEMU, native plugin, TOML frontend, public Python run API | [First run](../getting-started/first-run.md) |
| Multiple guest targets | ARM examples; RISC-V/x86 templates and architecture-specific helpers; feature support varies | [Portability](../architecture/portability.md) |
| PC-triggered virtuals | Native runtime callbacks selected during preparation/translation | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| Register/memory modifiers | Current specialized inline operation grammar and target restrictions | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| Manual inline device modeling | Explicit `finline` access map and a single fixed GPIO backing buffer; manual site selection and target-specific behavior | [Inline device modeling](../advanced/inline-device-modeling.md) |
| Automatic MMIO optimization | Experimental at `a38af40`: model extraction, shared Thumb access discovery, live elder-state binding, and guarded load replacement. Review found admitted unsafe expressions, alignment-fault bypass, and missing MMIO observations; restrict evaluation to explicitly audited models and workloads. | [Automatic MMIO](../designs/automatic-mmio.md) |
| JIT patcher | At `5b8bf3d`: immutable guest instruction fragments inserted before an original PC; explicit ISA/mode profiles and bounded register-only subsets | [JIT patcher](../advanced/jit-patcher.md) |
| Shared host analysis | Lazy image, symbol, DWARF, decoding, and RTOS facts; at `a38af40`, cached constant-propagation access candidates. Shared decoding currently targets Thumb/M-profile. | [Host analysis](../extending/host-analysis.md) |
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
| Coordinated guest progress | Co-simulation slave and lockstep controller; application supplies inter-firmware links | [Multiple firmwares](../simulation/multiple-firmwares.md) |
| Fuzzing | Optional fuzz engines, coverage, schema flows, and campaign integrations with target-specific reset semantics | [Fuzzing](../analysis/fuzzing.md) |
| Timing/profiling | Phase records, optional helper cProfile, QEMU perf, and FMU profiling | [Performance](../analysis/performance.md) |

## Separately pinned branches and backends

| Snapshot | What it adds | Evidence boundary |
| --- | --- | --- |
| INAV: `3910be12b82443efe8abb75ef89aa02f5ef047f4` | MATEKF405 firmware adaptation, FMU bridge, receiver input, and smoke tests | Documented source compatibility patch; short functional/flight checks, not a blanket mission qualification |
| PX4: `0e13b73986a66270a6d8452b2c0147af7b874d29` | FMUv6C profiles across five release lines, version sweep, and cache-management work | Version-specific validation levels and cache configuration requirements |
| Supercache | Translated-code caching in a separately pinned QEMU backend; managed cache configuration in the PX4 frontend snapshot | The stock QEMU submodule pin in main `a38af40` does not provide this feature. Follow the [Supercache chapter](../advanced/supercache.md) for the exact revisions, setup, and compatibility boundary. |

[Branch previews](../simulation/branch-previews.md) gives the INAV and PX4 checkout commands, firmware identities, source links, and reported outcomes. The [Supercache chapter](../advanced/supercache.md) specifies its separate frontend/backend pair. The book does not independently rerun those flight validations.

## Proposed extensions

| Direction | Existing foundations | Work still proposed |
| --- | --- | --- |
| [Direct function execution](../designs/function-execution.md) | Host facts, state access, execution control, device models | Reusable context planner and one-shot/rearmed function harness |
| [ESCape32 multi-firmware demo](../designs/escape32.md) | Vehicle/FMU integration and coordination mechanisms | ESC target adaptation, explicit links, motor boundary, and end-to-end validation |

These chapters document the intended direction and acceptance reasoning. They do not provide commands that pretend those proposed interfaces already exist.

## Read a result at its actual boundary

A boot smoke test, a sensor/motor check, and an autonomous mission establish different behavior. A high-level sensor hook and a register-level peripheral model execute different portions of the firmware. A four-channel plant interface does not establish a six-motor integration merely because a hexa configuration file exists.

Record the firmware, model, adaptation, time policy, and success condition with every result. Use the [testing and reproducibility guide](../analysis/testing-and-reproducibility.md) to decide what evidence is needed for the question being asked.

## Source guide

- [Main snapshot](https://github.com/boardrunner2049/FastDyn/tree/f9666d7f518c373e89831d8e14a6371a27fe6436)
- [JIT patcher and manual-lab snapshot](https://github.com/boardrunner2049/FastDyn/tree/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c)
- [Automatic MMIO implementation snapshot](https://github.com/boardrunner2049/FastDyn/tree/a38af408451394ea2f41be1e9cf1e96bc46c370f)
- [Source documentation overview](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/README.md)
- [Runtime SDK](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn_runtime.h)
- [Host-analysis contract](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisAPI.md)
- [Integration-test guide](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/integration/README.md)
