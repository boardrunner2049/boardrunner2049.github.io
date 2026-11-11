# Your first experiment

In this walkthrough, FastDyn runs a bundled FreeRTOS firmware, changes a function argument at a chosen instruction, prints the value the callee receives, and stops at the scheduler entry. It demonstrates the central workflow: describe the experiment around the firmware, then execute it through the patched translator and runtime.

No board, device model library, FMU, or separate firmware compilation is required. Complete [installation](installation.md), activate `fastdyn-env`, and run from the FastDyn repository root.

## Run the bundled configuration

```bash
fastdyn -q run -c configs/minimal.toml -o out/first-run
```

The configuration selects the bundled `tests/sample_binaries/RTOS/RTOSDemo.axf`, the generic `cortexm` machine, and a Cortex-M3 CPU. Its hooks are specific to that ELF. It exits by itself when execution reaches `vTaskStartScheduler()`.

The key observable output is:

```text
Reg 0:0x00000003
```

A `[BENCH][minimal]` record also reports elapsed time and the run terminates. Numeric timings depend on the host and build; a particular duration is not the pass criterion. The meaningful checks are the modified argument, the benchmark-end event, and a successful exit.

## Understand what happened

The firmware's `main()` normally calls `vStartLEDFlashTasks(1)`. Four configuration entries turn that behavior into a small experiment:

| Trigger in this ELF | Action | What it demonstrates |
| --- | --- | --- |
| `0x08003972` | `benchmark_start` | Begin a host-side timing interval at `main()` |
| `0x0800397e` | `r0 <- 3` | Set the argument register before the call |
| `0x080068b0` | `printreg`, argument `0` | Observe the value received at the callee entry |
| `0x08001940` | `benchmark_end`, label `minimal` | Report timing and stop at scheduler entry |

These are the actual entries in `configs/minimal.toml`:

```toml
[[CPU.cpu0.virtuals]]
at = "0x08003972"
instruction = "benchmark_start"

[[CPU.cpu0.modifiers]]
at = "0x0800397e"
patch = "r0 <- 3"

[[CPU.cpu0.virtuals]]
at = "0x080068b0"
instruction = "printreg"
args = ["0"]

[[CPU.cpu0.virtuals]]
at = "0x08001940"
instruction = "benchmark_end"
args = ["minimal"]
```

The modifier changes execution state at the selected PC. The virtual instructions invoke named FastDyn actions there. The ELF file is unchanged, so the firmware retains its original addresses and symbols. These mechanisms have different runtime implementations, described in [virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md).

The example uses ARM's `r0` argument convention because its firmware is Cortex-M. The experiment structure is general; register names, ABI assumptions, and hook locations must match the selected architecture and binary.

## Make one visible change

Copy the configuration into the repository root:

```bash
cp configs/minimal.toml first-experiment.toml
```

In `first-experiment.toml`, change the modifier to:

```toml
patch = "r0 <- 7"
```

Leave the rest of the existing modifier table in place, then run:

```bash
fastdyn -q run -c first-experiment.toml -o out/first-run-seven
```

The expected register line becomes `Reg 0:0x00000007`. This is a simple regression check for the relationship between configuration, trigger location, and guest state. Recompiling the firmware may move those locations, so do not carry the addresses into another ELF without resolving them again.

## Inspect the run record

FastDyn writes the resolved rules to:

- `out/first-run/virtuals/virtuals.txt`
- `out/first-run/virtuals/modifiers.txt`

The default timing configuration also records `fastdyn_timing.jsonl`. Summarize it with:

```bash
fastdyn timing-summary out/first-run/fastdyn_timing.jsonl
```

Other outputs depend on enabled features. For example, QEMU instruction logging is disabled in the minimal configuration, so this run does not promise a populated `qemu.log`. Peripheral tracing, coverage, and plugin-specific artifacts appear when those features are enabled.

A new `run` replaces an existing work directory unless `--persist-work-dir` is supplied. Give each experiment its own path when you want to compare results. The minimal fixture also names fixed RAM files and a fixed QMP socket under `/tmp`; run this walkthrough serially. The [multiple-firmware chapter](../simulation/multiple-firmwares.md) explains isolation for concurrent workers.

## Move to a longer-running example

To inspect a running RTOS and its activity monitor:

```bash
fastdyn run -c configs/introspection/freertos.toml -o out/freertos-introspection
```

The configured monitor is at `http://127.0.0.1:8765/`. Stop this example with Ctrl-C when finished. FastDyn requests a normal QEMU shutdown before escalating after its configured timeout, allowing runtime plugins to write their results.

The bundled minimal configuration intentionally allocates roomy emulated RAM. Its `512M` main bank is a test configuration choice, not a statement about the physical RAM capacity of a Cortex-M3 microcontroller.

## Source guide

- [Complete minimal configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/minimal.toml)
- [Virtual callback implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/virtuals.c)
- [Run preparation and work-directory policy](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runner.py)
- [QEMU rule generation and launch](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
- [FreeRTOS introspection configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/introspection/freertos.toml)
