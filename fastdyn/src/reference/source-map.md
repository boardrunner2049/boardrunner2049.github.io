# Source map and documentation index

The core chapters and original documentation index below retain the FastDyn baseline **`f9666d7f518c373e89831d8e14a6371a27fe6436`**. The Advanced section was reviewed at **`5b8bf3ddb01d63a4d5f86701d358e390a950cb9c`**, with separate backend/frontend pins where required. Links identify the recorded revision so a later change to `main` does not silently change the evidence behind an explanation.

The book organizes the material by reader workflow and system boundary. The original pages, target-specific notes, and example assets remain useful for detailed port work. A mapping below identifies the new chapter that explains the topic; it does not mean every historical command or measured result has been repeated or revalidated.

## How to establish current behavior

Use the implementation and shipped configurations at the recorded revision to determine supported interfaces and defaults. Tests identify intended contracts and meaningful validation paths. Actual run records establish whether a particular build and experiment passed them. The presence of a test or workflow is not a passing result.

Older design documents can describe intent or an earlier implementation. Where they differ from current code, this book identifies the implemented boundary and keeps proposed extensions in the design chapters. This distinction is especially relevant to `docs/chaos.md` and `docs/WorldIntegration.md`, which include forward-looking material.

FastDyn's submodules have their own revisions. The top-level revision pins their gitlinks; check those recorded commits before attributing behavior from a newer upstream QEMU, LibVIO, Rumoca, or model library to this snapshot.

## Advanced execution sources

| Book chapter | Implementation sources and scope |
| --- | --- |
| [Supercache](../advanced/supercache.md) | Separately pinned QEMU Supercache implementation and PX4 frontend cache-management code. The chapter distinguishes these from main's older QEMU gitlink. |
| [Inline device modeling](../advanced/inline-device-modeling.md) | Main `5b8bf3d` access-map preparation, native `LOAD_IO`/`STORE_IO` registration, GPIO backing state, and the pinned QEMU lowering. This is the existing manual mechanism. |
| [JIT patcher](../advanced/jit-patcher.md) | [GuestInstructionFragments.md](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/docs/GuestInstructionFragments.md), native SDK, tracked QEMU patch, and shipped plugin/probes at `5b8bf3d`. |
| [Translation insertion design](../designs/translation-insertion.md) | Implemented address, lifecycle, admission, and observation contracts for guest instruction fragments; retained at its original URL. |

The source guides in these chapters pin the exact files used. The review does not silently promote older design proposals, legacy example configurations, or branch-only frontend keys into supported main-branch workflows.

## Earlier pages in `docs/`

All 31 Markdown pages present in the original `f9666d7` snapshot's `docs/` directory are indexed here. The newer guest-fragment documentation is mapped in the Advanced table above.

| Original source | New book chapter | Material to retain |
| --- | --- | --- |
| [ActivityMonitor.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/ActivityMonitor.md) | [RTOS introspection](../instrumentation/introspection.md) | Activity events, monitor configuration, and observation workflow. |
| [Building.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/Building.md) | [Installation](../getting-started/installation.md) | Source builds, optional components, and model-build installation. |
| [BuildingAConfig.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/BuildingAConfig.md) | [Configure a firmware](../getting-started/configuration.md) | ELF-to-config and guided discovery. |
| [ClassicDeviceModel.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/ClassicDeviceModel.md) | [Device models](../devices/device-models.md) | Classic backend entry point. |
| [CoSimulationOverview.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/CoSimulationOverview.md) | [Multiple firmwares](../simulation/multiple-firmwares.md) | Coordination, model coupling, and clock boundaries. |
| [CoSimulationSlave.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/CoSimulationSlave.md) | [Multiple firmwares](../simulation/multiple-firmwares.md) | QMP budget protocol, slices, and stop semantics. |
| [CodingConventions.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/CodingConventions.md) | [Virtual plugins](../extending/virtual-plugins.md), [testing](../analysis/testing-and-reproducibility.md) | Source conventions, SDK boundaries, and contributor expectations. |
| [Configuration.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/Configuration.md) | [Configuration reference](configuration.md) | Tables, runtime options, paths, and environment overrides. |
| [ElderScrollDeviceModel.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/ElderScrollDeviceModel.md) | [Writing a model](../devices/writing-a-model.md) | Native model libraries and device callbacks. |
| [FastDynDeviceModel.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/FastDynDeviceModel.md) | [Device models](../devices/device-models.md) | Handler families and their role in a run. |
| [FastDyn_STR_Integration.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/FastDyn_STR_Integration.md) | [Fuzzing](../analysis/fuzzing.md), [CLI](cli.md) | Integration inputs, schema concepts, and campaign artifacts; check examples against the current schema parser. |
| [FlightControllerSimulation.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/FlightControllerSimulation.md) | [Flight controllers](../simulation/flight-controllers.md) | Vehicle runs, mission helpers, visualization, and parallel campaigns. |
| [FunctionCounterPlugin.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/FunctionCounterPlugin.md) | [Tracing and sanitizers](../instrumentation/tracing-and-sanitizers.md) | Function selection, entry counts, and output artifacts. |
| [FunctionTracerPlugin.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/FunctionTracerPlugin.md) | [Tracing and sanitizers](../instrumentation/tracing-and-sanitizers.md) | Function-entry and argument observation. |
| [Fuzzing.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/Fuzzing.md) | [Fuzzing](../analysis/fuzzing.md) | Native input fuzzing and OptiFuzz workflow selection. |
| [HostAnalysisAPI.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisAPI.md) | [Host analysis](../extending/host-analysis.md) | Shared image, symbol, DWARF, and decoder contracts. |
| [HostAnalysisMigration.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisMigration.md) | [Host analysis](../extending/host-analysis.md) | Extraction inventory, consumers, deliberate non-migrations, and historical verification records. |
| [HostAnalysisRuntimeGuide.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisRuntimeGuide.md) | [Host analysis](../extending/host-analysis.md) | Preparation-time use, sessions, and division between reusable facts and plugin policy. |
| [IntrospectionExamples.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/IntrospectionExamples.md) | [RTOS introspection](../instrumentation/introspection.md) | Bundled RTOS fixture configurations. |
| [ObjectSan.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/ObjectSan.md) | [Tracing and sanitizers](../instrumentation/tracing-and-sanitizers.md) | Object selection, static/dynamic checks, and supported analysis scope. |
| [PassthroughDeviceModel.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/PassthroughDeviceModel.md) | [Hardware and traces](../devices/hardware-and-traces.md) | Physical-board access entry point. |
| [PlatformBrowser.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/PlatformBrowser.md) | [Configure a firmware](../getting-started/configuration.md), [CLI](cli.md) | Architecture presets and SVD platform discovery. |
| [RunningFastDyn.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/RunningFastDyn.md) | [First experiment](../getting-started/first-run.md), [debugging](../analysis/debugging-and-observability.md) | Run lifecycle, output directory, and logging. |
| [VariableWatch.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VariableWatch.md) | [Tracing and sanitizers](../instrumentation/tracing-and-sanitizers.md) | Symbolic and raw-range data-access observation. |
| [VirtualPluginBrowser.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VirtualPluginBrowser.md) | [Plugin catalog](plugin-catalog.md), [CLI](cli.md) | Discoverable virtual/plugin choices. |
| [VirtualPreprocessing.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VirtualPreprocessing.md) | [Virtual plugins](../extending/virtual-plugins.md) | Preparation contexts, results, generated artifacts, and collisions. |
| [VirtualsAndModifiers.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VirtualsAndModifiers.md) | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) | User syntax, built-in actions, and translation/runtime distinction. |
| [WorldIntegration.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/WorldIntegration.md) | [World models](../simulation/world-models.md) | Earlier physical-register integration proposal; distinguish it from the current World plugin. |
| [WorldPlugin.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/WorldPlugin.md) | [World models](../simulation/world-models.md) | Implemented endpoints, pin hooks, advancement, and observers. |
| [WritingVirtuals.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/WritingVirtuals.md) | [Virtual plugins](../extending/virtual-plugins.md) | Adding native and host halves, registering modules, and testing. |
| [chaos.md](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/chaos.md) | [Fuzzing](../analysis/fuzzing.md) | Task-loop motivation and implemented control/coverage mechanisms; proposed automatic inference is identified separately. |

## Specialized READMEs and fixture guides

These links preserve the concrete entry points that a broad chapter cannot replace.

| Source guide | New book chapter | Specific purpose |
| --- | --- | --- |
| [Repository README](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/README.md) | [Welcome](../index.md), [installation](../getting-started/installation.md) | Project entry point and repository quick start. |
| [Runtime SDK](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/README.md) | [Virtual plugins](../extending/virtual-plugins.md) | Public native operations, architecture headers, and complete module examples. |
| [Fuzzer implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/README.md) | [Fuzzing](../analysis/fuzzing.md) | Native backends and protocol-harness entry points. |
| [LibAFL library](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/fastdyn_fuzz_lib/README.md) | [Fuzzing](../analysis/fuzzing.md), [installation](../getting-started/installation.md) | Rust backend and older container workflow. |
| [OptiFuzz/CP-Explore](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/libafl_phi/README.md) | [Fuzzing](../analysis/fuzzing.md) | Parameters, physical properties, vehicle selection, and campaign outputs. |
| [Generic schema](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/schema/README.md) | [Fuzzing](../analysis/fuzzing.md) | Complete field, expression, stream, hook, and flow grammar. |
| [Physics integration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/README.md) | [Physics and FMU](../simulation/physics-and-fmu.md), [flight controllers](../simulation/flight-controllers.md) | Maintained FMU path, timing, and legacy backend notes. |
| [Physics backend contract](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/physics_engines/README.md) | [Physics and FMU](../simulation/physics-and-fmu.md) | Native backend boundary and backend implementations. |
| [Legacy high-fidelity altimeter](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/physics_engines/fmu/hifi_altimeter/README.md) | [Physics and FMU](../simulation/physics-and-fmu.md) | OpenModelica/FMI 2 harness; it cannot directly load an FMI 3 model. |
| [Courbet](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/README.md) | [Flight controllers](../simulation/flight-controllers.md) | Firmware profiles, MAVLink helpers, mission assets, and local tests. |
| [PX4 FMUv6C](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/px4/fmu_v6c/README.md) | [Flight controllers](../simulation/flight-controllers.md) | Console initialization, UART bridging, and the specific PX4 profile. |
| [Rover 4.6.2](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/rover462/README.md) | [Flight controllers](../simulation/flight-controllers.md) | Title-only port stub; inspect its surrounding assets and the active config. |
| [Rover lidar variant](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/rover462_lidar/README.md) | [Flight controllers](../simulation/flight-controllers.md) | Title-only variant stub; it is not a complete verified walkthrough. |
| [Rover fuzzing variant](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/rover_fuzz462/README.md) | [Fuzzing](../analysis/fuzzing.md) | Title-only historical port stub; follow the current campaign interfaces. |
| [ELF-to-config](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tools/elf2config/README.md) | [Configure a firmware](../getting-started/configuration.md) | Metadata extraction, hints, and reviewable configuration generation. |
| [Ghidra launcher](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/decompilers/ghidra/README.md) | [Debugging](../analysis/debugging-and-observability.md) | Repository-provided GDB launcher integration for a matching Ghidra project. |
| [Unit tests](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/unit/README.md) | [Testing and reproducibility](../analysis/testing-and-reproducibility.md) | Python test commands and conventions. |
| [Integration tests](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/integration/README.md) | [Testing and reproducibility](../analysis/testing-and-reproducibility.md) | Native execution, RTOS, vehicle, and swarm checks. |
| [STM32F429I FreeRTOS fixture](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/firmwares/freertos_stm32f429i_discovery/README.md) | [Testing](../analysis/testing-and-reproducibility.md), [introspection](../instrumentation/introspection.md) | Two task-owned LED counters and the fixture build. |
| [Raw firmware fixtures](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/raw/README.md) | [Testing and reproducibility](../analysis/testing-and-reproducibility.md) | Raw conversion commands and the metadata discarded by that format. |
| [Idle hardware firmware](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/idle_firmwares/README.md) | [Hardware and traces](../devices/hardware-and-traces.md) | Board-side interrupt servers, prebuilt images, and the IRQ-number contract. |

## Find the owning implementation

| Location | Start here when changing or checking |
| --- | --- |
| `src/fastdyn/main.py` | Command names, Click options, and CLI defaults. |
| `src/fastdyn/runner.py`, `runtime_config.py` | Run preparation, helper lifecycle, work directories, and profiling configuration. |
| `src/fastdyn/toml_parser.py`, `targets/qemu_target.py` | TOML consumption, path resolution, QEMU options, and generated native rules. |
| `src/fastdyn/virtual_preprocessing.py` | Host extension discovery, preparation contexts, and rule validation. |
| `src/fastdyn/host/` | Reusable immutable-image analysis; plugin-specific policies stay with their consumer. |
| `core/core.c` | Translation instrumentation, dispatch infrastructure, coverage producer/consumer behavior, and core lifecycle. |
| `include/fastdyn_runtime.h`, `include/fastdyn/arch/` | Native SDK contracts and target register/ABI constants. |
| `include/fastdyn/device_model.h`, `device_models/` | Device ABI, routing, model-family implementations, and hardware sessions. |
| `configs/` | Concrete user settings and examples; inspect placeholder paths and feature prerequisites. |
| `virtuals/<feature>/host/`, `runtime/` | A feature's preprocessing policy, manifest, native behavior, and outputs. |
| `virtuals/physics/` | Physics backends, vehicle adapters, Courbet profiles, and mission assets. |
| `virtuals/fuzzer/` | Native fuzzing lifecycle, schemas, input backends, and OptiFuzz. |
| `tests/unit/`, `tests/integration/` | Expected contracts and executable validation boundaries. |
| `tests/firmwares/`, `tests/binaries/` | Fixture source and image identity behind smoke tests. |
| `tools/`, `utils/` | Configuration generation, binary utilities, co-simulation controllers, reports, and optional tool integrations. |
| `.gitmodules`, `third_party/` | Dependency ownership and pinned source boundaries. `tools/raw2elf` and `tools/world` are also submodules. |
| `setup.sh`, `scripts/setup/`, `Makefile`, `meson.build` | What a build actually enables and how dependencies are selected. |

Use `rg` from the FastDyn repository root to follow a feature across its layers:

```bash
rg --files src core include configs tests virtuals tools utils
rg -n 'register_run_preprocessor|VIRTUAL_PLUGIN' src virtuals tests/plugins
rg -n 'timer_irq_period_ns|exact_budget_stop' src core include configs virtuals
rg -n 'fuzzing_schema|schema_load' src virtuals
```

Begin with the user-facing configuration, find where the parser consumes it, follow the generated artifact or native argument, and then read the runtime consumer. Finally, check tests for the precise boundary the repository exercises. This makes it easier to spot a stale example, an unsupported field, or an implementation detail that should not be advertised as a portable contract.
