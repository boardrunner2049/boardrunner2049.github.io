# FastDyn

## Firmware execution you can shape

FastDyn brings firmware execution, peripheral behavior, runtime instrumentation, and physical simulation into one configurable experiment. Load a firmware image, describe its machine and environment, and decide where to observe or intervene. The same framework can change a function argument, inspect an RTOS, replay peripheral interactions, connect a controller to a vehicle model, or drive a fuzzing campaign.

The execution engine combines a patched QEMU with a native FastDyn plugin. A Python frontend prepares the experiment from TOML or a public API. Host analysis resolves information before execution; runtime plugins and device models supply behavior while the guest runs. The result is a reusable place to investigate embedded software without rebuilding an entire physical test setup for each question.

Start with [your first experiment](getting-started/first-run.md), or use [Choose a workflow](getting-started/choose-workflow.md) to find the right entry point.

## What makes FastDyn useful

### Shape execution at the point that matters

A modifier can change a register or memory value at a chosen guest program counter. A virtual instruction can invoke a named native behavior there. These rules live alongside the experiment configuration, so the minimal example changes the argument received by a real firmware function while preserving the firmware image and its original addresses.

This is useful for supplying missing platform behavior, skipping a known initialization dependency, injecting a fault, collecting evidence, or making a narrow experiment repeatable. The [instrumentation chapter](instrumentation/virtuals-and-modifiers.md) explains the different costs and contracts of virtuals, modifiers, and the existing inline-I/O path.

### Give each device the environment it needs

Use a compiled C model for a peripheral, connect an access to a physical board through a debug probe, or replay an interaction trace. A permissive stub helps bring up an early experiment; an explicit model provides the state and side effects needed for meaningful execution. These options share FastDyn's device-dispatch infrastructure, allowing the model boundary to evolve as the experiment matures.

[Device models](devices/device-models.md) explains the available mechanisms. [Writing a model](devices/writing-a-model.md) walks through the ABI and model build workflow.

### Move beyond boot success

Function counts, argument traces, variable observations, RTOS activity, object-bound checks, MMIO observations, and coverage expose what the firmware actually does. Host preprocessors can install instrumentation across an image rather than requiring a long manual list of addresses.

The shared [host-analysis API](extending/host-analysis.md) supplies reusable image, symbol, DWARF, decoding, and RTOS facts. Individual plugins retain the policy that decides what to instrument.

### Close the loop with physics

FastDyn can execute controller firmware against a physical model and feed the resulting sensor values back to the controller. Its FMI 3 path loads the FMU into the execution process; the core plant does not require a separate simulator process. Vehicle profiles, mission helpers, telemetry, and optional viewers turn that capability into practical experiments.

Read [Physics and FMUs](simulation/physics-and-fmu.md), then [Flight controllers](simulation/flight-controllers.md). The [branch previews](simulation/branch-previews.md) cover newer INAV and PX4 work with the exact revisions and evidence levels that apply to each.

### Scale experiments and grow the framework

Use `fastdyn swarm` for independent workers, and the co-simulation controller/slave facilities for experiments that coordinate guest progress. Add explicit communication and plant coupling when the experiment contains interacting firmware instances. [Multiple firmwares](simulation/multiple-firmwares.md) explains these distinct arrangements.

Extensions can use the Python run API, a preparation plugin, a native runtime plugin, a peripheral model, or a physics adapter. [The system model](architecture/system-model.md) helps choose the smallest appropriate extension point.

## A small first taste

After [installation](getting-started/installation.md), run this from the FastDyn source checkout:

```bash
fastdyn -q run -c configs/minimal.toml -o out/first-run
```

The bundled configuration changes a function argument to `3`, prints the observed register value, and ends the run at the scheduler entry. It provides a short, concrete check of the entire path from configuration to guest execution. The tutorial shows how to change the argument again and inspect the generated rules.

## How to read this book

| Your goal | Start here |
| --- | --- |
| Run a firmware experiment | [Installation](getting-started/installation.md), [first run](getting-started/first-run.md), [configuration](getting-started/configuration.md) |
| Understand the machinery | [System model](architecture/system-model.md), [execution pipeline](architecture/execution-pipeline.md) |
| Observe or modify behavior | [Virtuals and modifiers](instrumentation/virtuals-and-modifiers.md), [introspection](instrumentation/introspection.md), [tracing and sanitizers](instrumentation/tracing-and-sanitizers.md) |
| Supply hardware behavior | [Device models](devices/device-models.md), [hardware and traces](devices/hardware-and-traces.md) |
| Run a controller against a plant | [Physics and FMUs](simulation/physics-and-fmu.md), [flight controllers](simulation/flight-controllers.md) |
| Build an analysis or downstream tool | [Python API](extending/python-api.md), [virtual plugins](extending/virtual-plugins.md), [host analysis](extending/host-analysis.md) |
| Work with advanced execution mechanisms | [Supercache](advanced/supercache.md), [inline device modeling](advanced/inline-device-modeling.md), [experimental automatic MMIO](designs/automatic-mmio.md), [JIT patcher](advanced/jit-patcher.md) |
| Explore the next capabilities | [Function execution](designs/function-execution.md), [ESCape32](designs/escape32.md) |

## Revision and evidence

This edition was prepared on **11 November 2026**. Core chapters retain the FastDyn baseline [`f9666d7`](https://github.com/boardrunner2049/FastDyn/commit/f9666d7f518c373e89831d8e14a6371a27fe6436). The JIT patcher and manual inline lab are pinned to [`5b8bf3d`](https://github.com/boardrunner2049/FastDyn/commit/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c). The automatic MMIO workflow and related API additions were reviewed at [`a38af40`](https://github.com/boardrunner2049/FastDyn/commit/a38af408451394ea2f41be1e9cf1e96bc46c370f); that implementation is experimental and has the correctness limits recorded in its chapter. Supercache requires the separate frontend/backend revisions identified in its chapter. Each source guide records its implementation evidence; reviewing one feature at a newer revision does not revalidate every older chapter. Proposed extensions remain separate from implemented workflows.

The book was checked against source, configuration examples, and test programs. It is not a new measurement campaign. See the [capability status](reference/status.md) and [testing guide](analysis/testing-and-reproducibility.md) for the scope of an experiment and the evidence to retain.

FastDyn itself is distributed under Apache-2.0; bundled firmware and dependencies retain their own licenses. See the source repository's [LICENSE](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/LICENSE) and [NOTICE](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/NOTICE).

## Source guide

- [FastDyn overview and maintained examples](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/README.md)
- [Execution and extension ownership conventions](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/CodingConventions.md)
- [Public runtime SDK](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn_runtime.h)
