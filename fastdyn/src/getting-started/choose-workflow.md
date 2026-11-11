# Choose a workflow

A productive FastDyn experiment starts with a question that has a visible result. Booting a new image, measuring a function, validating a sensor interaction, and testing a controller against a plant require different amounts of environment modeling. Start with the smallest setup that answers the question, then add fidelity where it changes the result.

## Find your starting point

| Question | Starting point | Observable result |
| --- | --- | --- |
| Can I run FastDyn and change guest state? | `configs/minimal.toml` | Changed argument printed by the firmware hook; automatic termination |
| Which functions execute? | `configs/function_counter.toml` | Function-entry counts written on shutdown |
| What arguments reach selected functions? | `configs/function_tracer.toml` | Selected entry arguments and decoded values |
| Which RTOS tasks run? | `configs/introspection/freertos.toml` | Task/activity records and configured monitor |
| Does a memory object stay within its modeled bounds? | ObjectSan example configurations | Reports at instrumented candidate accesses |
| How should an unmapped peripheral respond? | An Elder C model | Explicit register and device-state behavior |
| Can I compare against a real peripheral? | Passthrough or twintrace | Probe-backed interactions or a replay record |
| Does a controller behave correctly in a scenario? | An appropriate flight-controller/FMU configuration | Sensor/controller/actuator progress and a scenario outcome |
| How do I repeat many independent trials? | `fastdyn loop` or `fastdyn swarm` | Separate trial or worker artifacts |
| How do several firmware instances interact? | Co-simulation plus explicit links | Ordered communication and coupled plant evolution |

The configuration examples are entry points, not interchangeable board descriptions. Their addresses, firmware images, register conventions, and optional dependencies belong to the named experiment.

## New to FastDyn

Install the native build, run the [first experiment](first-run.md), and inspect the generated `virtuals.txt` and `modifiers.txt`. Change one modifier, repeat the run, and check the observed value. This short loop teaches the operating model before adding device synthesis, a physical board, or physics.

Next, run an introspection or function-counting configuration. These examples demonstrate the second important pattern: a host preprocessor derives many runtime hooks from one small plugin table. You can read the resulting artifacts to understand exactly what was installed.

## Bringing your own firmware

Prefer an ELF with symbols and, for layout-dependent analyses, DWARF. A raw image can still be executed when you know its load map and architecture, but missing metadata changes what the preparation stage can resolve automatically.

The ELF configuration generator is a useful first pass:

```bash
./fastdyn-env/bin/python tools/elf2config/elf_to_config.py firmware.elf   --output configs/my_firmware.toml
```

This command belongs to the FastDyn source checkout and assumes `firmware.elf` is your input. Review the generated CPU, memory, vector-table, and platform assumptions before running it. The tool's legacy generated QEMU path may point at a sibling checkout; use the executable built for your installation as described in [installation](installation.md).

An ELF supplies facts about an image. It does not fully describe the physical board, peripheral state machines, startup side effects, or available RAM. Treat inferred defaults as decisions to review. [Configuration](configuration.md) explains the fields and their path-resolution rules.

## Choosing where to intervene

Use a **modifier** for an operation expressible by the current register/memory rule language. Use a **virtual callback** when the intervention needs native behavior, such as reading a model or recording a structured event. Use a **device model** when the firmware should exercise a peripheral interface repeatedly with meaningful state and side effects.

Use a **run preprocessor** when hook selection depends on the firmware. It can resolve symbols, inspect layouts, or select a family of sites once, then serialize a runtime plan. Use the **Python run API** when building an experiment driver or another tool around FastDyn. These choices can be combined; each addresses a different boundary.

For controller experiments, choose a sensor boundary intentionally. Injecting at a high-level sensor publication exercises the downstream controller but bypasses the physical device driver. Modeling SPI or I2C transactions exercises more of the driver path and requires more peripheral detail. Record that choice alongside the scenario.

## Define completion before launching

Choose a termination event, a maximum run budget where the workflow provides one, and a result to inspect. Examples include reaching a function, writing a final counter file, satisfying a mission condition, or reporting a replay mismatch. A console that keeps running is not by itself evidence of correct execution.

For every new target, retain the firmware digest, configuration, generated hooks, model versions, and observed result. This makes the next run a comparison rather than a reconstruction of the setup.

## Source guide

- [Configuration-generation utility and limits](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tools/elf2config/README.md)
- [Starter configuration workflow](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/BuildingAConfig.md)
- [Bundled configurations](https://github.com/boardrunner2049/FastDyn/tree/f9666d7f518c373e89831d8e14a6371a27fe6436/configs)
- [Running and output conventions](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/RunningFastDyn.md)
