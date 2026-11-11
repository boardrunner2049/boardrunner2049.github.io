# Measure and improve performance

FastDyn provides several mechanisms that can reduce avoidable work: shared host-analysis sessions, prepared runtime artifacts, inline modifier operations, in-process model execution, incremental model builds, and parallel independent campaigns. Their value depends on the workload. Measure the complete experiment as well as the boundary being optimized.

This chapter describes a measurement workflow. It does not claim a universal speedup or report a new benchmark result.

## Name the quantity first

| Quantity | What it answers | What it does not establish |
| --- | --- | --- |
| Host wall-clock duration | How long the experiment costs on this host | Guest-realistic execution timing |
| Preparation phase duration | Time spent parsing, analyzing, building, and launching | Steady-state callback cost |
| Guest virtual time | Time visible to modeled firmware events | Physical CPU cycle accuracy |
| Explicit co-simulation budget/progress | How much scheduled guest work was admitted | Universal hardware instruction timing |
| Plant simulation time | How far the physical scenario evolved | Host performance |
| Completed trials per second | Campaign throughput at the defined completion condition | Equivalent trial behavior by itself |

The native `virtual_icount()` helper is a separate implementation detail. In the inspected main revision it returns FastDyn's internal counter, whose increment callback is enabled with twintrace; it may remain zero in ordinary runs. Do not substitute it for the co-simulation protocol's progress accounting or assume every trace's `icount` field is a universal retired-instruction count.

## Start with phase timing

Add or adjust the existing profiling table in an experiment configuration:

```toml
[Run.profiling]
timing = true
timing_echo = true
python = false
perf = "off"
fmu = true
```

Run the configuration with a dedicated work directory, then summarize its event log:

```bash
fastdyn timing-summary out/experiment/fastdyn_timing.jsonl
```

The filename above assumes that the experiment used `-o out/experiment`. Timing records include phase names, durations, process identities, and status. The runner records preparation and execution phases; optional components contribute their own events. JSONL fields such as `duration_s`, `time_monotonic_s`, and `time_wall_s` are in seconds. The native guest-time API and scheduling fields ending in `_ns` use nanoseconds.

Phase intervals may nest or overlap across processes. Adding every reported duration can double-count work. Use the enclosing run interval for end-to-end cost and the component intervals to explain it. Report failures and early exits separately from successfully completed experiments.

## Profile a specific remaining bottleneck

To inspect Python helper scripts and QEMU on a compatible Linux host, use:

```toml
[Run.profiling]
timing = true
python = true
perf = "record"
perf_frequency_hz = 99
fmu = true
```

The Python wrapper uses `cProfile` for supported script commands. QEMU profiling uses Linux `perf` when it is available and permitted. Profile outputs live under the run's `profiles/` directory. Read the actual filenames reported by the run before opening them with `pstats` or `perf report`.

Profilers themselves affect cost. Use them to locate work, then repeat the measurement with the selected production instrumentation settings. Enabling Python profiling does not magically profile native code, and a `perf` request that cannot run is not a captured profile.

## Compare equivalent work

Before timing two variants, establish that both reach the same completion condition with equivalent relevant behavior. A variant that returns sooner because it skipped a controller update or stopped on an error is not a speedup.

Keep the following fixed unless the experiment explicitly studies them: firmware and compiler build, QEMU and FastDyn revisions, machine configuration, model implementation, initial state, inputs, virtual-time policy, enabled observations, and termination rule. Keep host configuration and worker concurrency in the record as well.

Use separate trials for cold preparation and warm/incremental work. An FMU build or a first model compilation can dominate an initial run; a later run that reuses artifacts answers a different question. Measure both when both matter to users.

For each comparison, report the baseline and variant durations and the chosen summary across repeated successful runs. Define the arithmetic explicitly:

```text
speedup = baseline_duration / variant_duration
overhead_percent = 100 * (variant_duration / baseline_duration - 1)
```

The comparison is meaningful only for the stated baseline. Comparing a full environment against a permissive stub also changes behavior and fidelity, which must be explained separately.

## Where to look for improvement

**Repeated analysis.** Reuse the run-scoped host-analysis session rather than reopening the ELF and rebuilding the same indexes in each preprocessor. Keep feature-specific planning outside the shared fact services.

**High-frequency callbacks.** Count how often an event occurs and how much work its handler performs. A small cost in a polling loop may dominate a larger initialization operation. [Inline device modeling](../advanced/inline-device-modeling.md) covers the specialized I/O path; the [JIT patcher](../advanced/jit-patcher.md) covers admitted register-only guest instruction fragments. The [automatic-MMIO design](../designs/automatic-mmio.md) describes the proposed model-analysis generalization.

**Repeated translation.** [Supercache](../advanced/supercache.md) covers persistence and reuse of translated code in the separate backend that implements it. Distinguish a cold cache population run, a subsequent reuse run, and the complete experiment duration. Keep firmware, backend, plugin, machine, and instrumentation identities fixed; inspect cache compatibility and invalidation before attributing a timing difference to reuse.

**Observation volume.** Function traces, register logs, MMIO observations, and detailed QEMU logs can materially change throughput and output volume. Select the evidence the experiment needs. The current finite logging buffer and drain thread do not establish universal lossless observation under arbitrary load.

**Physics and communication.** Separate FMU stepping cost from adapter conversion, telemetry, viewers, and mission helpers. An embedded FMU removes a simulator-process boundary from that path, but does not eliminate physical-model computation.

**Campaign scaling.** Measure completed valid trials as worker count changes. Workers need isolated memory, files, sockets, and ports. More processes can contend for CPU, storage, or a shared external service rather than improve throughput.

## A useful result record

Retain the exact experiment inputs, success criterion, timing log, optional profile, number of successful and failed trials, baseline definition, and raw durations. For a translation optimization, also retain functional equivalence checks and the fraction of accesses or instructions that actually used the optimized path.

This record connects an implementation choice to a reproducible result. It is also more useful to the next developer than an isolated claim that a particular run was fast.

## Source guide

- [Timing events](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/timing.py)
- [Profiling configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runtime_config.py)
- [Profiler wrappers](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/profiling.py)
- [Native instrumentation and internal counter](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/core/core.c)
- [Run phases](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runner.py)
