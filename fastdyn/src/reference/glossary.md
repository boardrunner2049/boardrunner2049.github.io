# Glossary

The terms below distinguish the firmware being executed, the tools preparing its environment, and the native code that implements the experiment. A capability can belong to the general framework while a particular adapter still has an architecture or firmware-specific contract.

## Execution and instrumentation

| Term | Meaning in FastDyn | Read more |
| --- | --- | --- |
| **Guest** | The emulated target CPU, firmware, memory, and visible devices. A guest register or address belongs to this target, not to the machine running FastDyn. | [System model](../architecture/system-model.md) |
| **Host** | The real machine and software running Python preparation, QEMU, native plugins, model libraries, and optional helpers. Host-side analysis is separate from guest execution. | [Execution pipeline](../architecture/execution-pipeline.md) |
| **Rehosting** | Executing a firmware image in a reconstructed environment that supplies the CPU, memory, device behavior, and other dependencies required by the selected workload. Booting is one milestone, not a complete validation criterion. | [Choose a workflow](../getting-started/choose-workflow.md) |
| **ISA** | Instruction set architecture: the instruction encodings and architectural behavior expected by a firmware. CPU mode and enabled extensions also matter; an architecture family name alone may not determine decoding. | [Portability](../architecture/portability.md) |
| **ABI** | Application binary interface: conventions for arguments, return values, stack use, data layout, and related boundaries. A callback replacing a function must honor the target's ABI. FastDyn's x86-64 convenience macros use System V AMD64, not Windows x64. | [Virtual plugins](../extending/virtual-plugins.md) |
| **Guest address / PC** | An address in the target's address space; the program counter identifies execution position. Numeric trigger PCs are tied to an image and load layout. Some architectures also encode execution mode in function-pointer representations. | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| **Translation block (TB)** | QEMU's unit of translated guest code. TB formation depends on translator constraints and runtime state; a TB is not guaranteed to match one source-level basic block. | [Execution pipeline](../architecture/execution-pipeline.md) |
| **TCG** | QEMU's Tiny Code Generator, which uses an intermediate representation to generate host code for guest execution. FastDyn's translation hooks and supported modifiers interact with this path. | [Execution pipeline](../architecture/execution-pipeline.md) |
| **Supercache** | A separately versioned QEMU backend facility for persisting and reusing translated code. Backend compatibility, cache identity, and supported execution modes are part of its setup contract. | [Supercache](../advanced/supercache.md) |
| **Virtual instruction** | A named FastDyn runtime action triggered at a guest PC, usually implemented as a callback. It does not mean a new opcode was written into the firmware image. | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| **Modifier** | A configured state operation associated with a guest PC, such as a register update or supported memory operation. The supported forms are lowered through the patched translation machinery; the original firmware bytes remain unchanged. | [Virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md) |
| **JIT patcher / guest instruction fragment** | A native SDK facility that registers bounded, admitted guest instruction bytes before an original PC. The target frontend translates them without placing the bytes in the firmware image or relocating its instructions. | [JIT patcher](../advanced/jit-patcher.md) |
| **Hook** | A selected event or execution point where instrumentation takes effect. PC callbacks, interrupt entry/exit observers, and translation hooks are different hook types with different contexts. | [Virtual plugins](../extending/virtual-plugins.md) |
| **Host preprocessor** | Python code that runs during preparation to resolve symbols, select instrumentation, generate rules, and write runtime input artifacts. It is not invoked for every guest instruction. | [Host analysis](../extending/host-analysis.md) |
| **Runtime plugin** | A native extension using FastDyn's runtime SDK inside the QEMU process. It can register callbacks and observers and access its artifacts. This differs from the top-level `libfastdyn.so` QEMU plugin that hosts the extensions. | [Plugin catalog](plugin-catalog.md) |
| **Host analysis session** | A lazy, scoped source of reusable facts about an immutable firmware image: image data, symbols, DWARF, and supported decoding. Plugins retain ownership of selection policy and instrumentation plans. | [Host analysis](../extending/host-analysis.md) |

## Devices and physical models

| Term | Meaning in FastDyn | Read more |
| --- | --- | --- |
| **MMIO** | Memory-mapped input/output: accesses to guest addresses whose meaning is supplied by a device rather than ordinary RAM. Reads and writes may have side effects such as consuming data, clearing status, or starting DMA. | [Device models](../devices/device-models.md) |
| **Device model** | A runtime implementation of a device's observable behavior, including registers, transactions, state transitions, and interrupts as required by the experiment. A physical transfer function supplies only part of this behavior. | [Writing a model](../devices/writing-a-model.md) |
| **Inline device modeling** | A translated device operation at a selected firmware PC using host backing state. The legacy manual `finline` path uses a separate buffer and requires explicit handling of the original instruction. | [Inline device modeling](../advanced/inline-device-modeling.md) |
| **Automatic MMIO optimization** | The experimental `mmio_opt` pipeline introduced at `a38af40`: model-operation extraction, shared firmware access discovery, binding to initialized elder state, and guarded load replacement. Its analyzer and runtime have documented correctness limits. | [Automatic MMIO](../designs/automatic-mmio.md) |
| **Hardware passthrough** | Forwarding selected peripheral interactions to a real board through libhw and a probe. The real peripheral contributes behavior while firmware execution remains in QEMU. | [Hardware and traces](../devices/hardware-and-traces.md) |
| **TwinTrace** | FastDyn's hardware-trace recording and replay machinery. Replay follows the recorded interaction contract; it does not create an unrestricted generative model of the device. | [Hardware and traces](../devices/hardware-and-traces.md) |
| **LibVIO** | The companion library providing reusable bus, signal, DMA, and host-I/O mechanisms for C device models. Device-specific register semantics still belong to the model. | [Writing a model](../devices/writing-a-model.md) |
| **SVD** | CMSIS System View Description data used for device/register and interrupt metadata. Selecting an SVD platform does not automatically implement that platform's peripherals. | [Configuration](configuration.md) |
| **Firmware profile** | A concrete configuration and associated hooks or adapters for a particular firmware, version, and execution path. Courbet vehicle profiles contain this firmware-specific knowledge. | [Flight controllers](../simulation/flight-controllers.md) |
| **FMI** | Functional Mock-up Interface, the interface through which a model is instantiated, receives inputs, advances, and supplies outputs. The maintained FastDyn path uses FMI 3 Co-Simulation. | [Physics and FMU](../simulation/physics-and-fmu.md) |
| **FMU** | Functional Mock-up Unit: the model artifact, commonly packaged with `modelDescription.xml`, executable binaries or sources, and resources. FastDyn's current backend loads the compiled model into the QEMU process. | [Physics and FMU](../simulation/physics-and-fmu.md) |
| **Plant** | The physical system modeled around the controller, such as a motor, vehicle, circuit, or thermal process. Firmware produces actuation inputs; the plant produces states or observations delivered back through an adapter. | [World models](../simulation/world-models.md) |

## Time and orchestration

| Term | Meaning in FastDyn | Read more |
| --- | --- | --- |
| **Host elapsed time** | Real elapsed duration on the computer executing the experiment. It includes the work being measured and can be affected by scheduling, logging, and other host load. It is distinct from simulated time. | [Performance](../analysis/performance.md) |
| **Guest virtual time** | QEMU's simulation clock, exposed by FastDyn in nanoseconds. How it advances depends on the configured timing mode; it is not automatically a cycle-accurate MCU clock. | [Multiple firmwares](../simulation/multiple-firmwares.md) |
| **Plant time** | The time to which a physical model has been advanced. The integration policy aligns plant progress with guest time; the FMI boundary may express times in seconds while FastDyn scheduling uses nanoseconds. | [Physics and FMU](../simulation/physics-and-fmu.md) |
| **Instruction count / `icount`** | QEMU `icount` relates instruction progress to virtual time. It is separate from FastDyn's `virtual_icount()` counter, whose current wiring depends on twintrace. Neither establishes real hardware instruction latency. | [Configuration](configuration.md) |
| **Slice** | A bounded interval of virtual execution granted to a co-simulation slave by its controller. The stopping policy determines whether the slave stops exactly at the budget deadline or at an allowed boundary. | [Multiple firmwares](../simulation/multiple-firmwares.md) |
| **Physics step** | An advancement interval used by the physical model or its integration loop. It is separate from a TB and from a controller's execution slice, even when the experiment coordinates these intervals. | [World models](../simulation/world-models.md) |
| **Lockstep** | Coordinated advancement in which participants exchange required inputs or results at defined synchronization boundaries. Synchronizing clocks alone does not define the data connections between participants. | [Multiple firmwares](../simulation/multiple-firmwares.md) |
| **Swarm** | FastDyn's orchestration of isolated copies of a configuration with distinct worker resources. It scales independent experiments; cross-worker device or physical connections must be defined separately. | [CLI reference](cli.md) |

## Analysis and testing

| Term | Meaning in FastDyn | Read more |
| --- | --- | --- |
| **Fuzzing schema** | A JSON description of input fields, incremental streams, injection hooks, and optional snapshot/synchronization flow. The schema describes a chosen harness; it does not prove its state assumptions are valid. | [Fuzzing](../analysis/fuzzing.md) |
| **Coverage** | Feedback recording executed regions or transitions, such as translated-block PCs and cumulative edges. It helps compare exploration but does not establish correctness, physical feasibility, or a lossless instruction trace. | [Fuzzing](../analysis/fuzzing.md) |
| **Snapshot** | Captured guest state used to repeat an execution boundary. The current native fuzzing implementation has ARM-oriented register and memory contracts. Rewinding it does not automatically rewind arbitrary host services, physical boards, or external model state. | [Fuzzing](../analysis/fuzzing.md) |

## Source guide

- [Native SDK and architecture contracts](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/README.md)
- [Automatic MMIO pipeline at a38af40](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/docs/AutomaticMMIOOptimization.md)
- [Host analysis contracts](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisRuntimeGuide.md)
- [Co-simulation semantics](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/CoSimulationSlave.md)
- [FMU runtime preparation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/fmu_runtime.py)
- [Schema and snapshot semantics](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/schema/README.md)
- [Native coverage and state handling](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/fuzz.c)
