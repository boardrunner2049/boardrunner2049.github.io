# Debugging and observability

FastDyn exposes both sides of a firmware experiment: the guest's execution and the host machinery that makes the run possible. Use the smallest observation that answers the immediate question. A register print can establish that a hook fired; an RTOS activity record can establish that scheduling progressed; an FMU heartbeat can establish that firmware and physics are exchanging data.

All commands below assume an activated FastDyn environment and the FastDyn repository root. Paths such as `configs/target.toml` refer to your reviewed target configuration.

## Start with the run record

Assign a distinct work directory before debugging:

```bash
fastdyn run -c configs/minimal.toml -o out/debug-minimal
```

The generated `virtuals/virtuals.txt` and `virtuals/modifiers.txt` show the addresses and operations actually handed to the native runtime. These are the first place to look when a symbolic trigger or preprocessing-generated hook does not behave as expected.

Other useful artifacts depend on the enabled features:

| Artifact | What it answers |
| --- | --- |
| `run-artifacts/<plugin>/` | What did host preprocessing discover and generate? |
| `io.log` | Which peripheral transactions did device handling observe? |
| `qemu.log` | What did the selected QEMU `-d` logging categories report? |
| `fastdyn_timing.jsonl` | Which instrumented host phases ran, and how long did they take? |
| `bbl.txt`, optionally `edges.txt` | What cumulative coverage did the enabled coverage implementation record? |
| Plugin result files | What functions, accesses, tasks, or violations did that plugin observe? |

An absent file may mean the feature was disabled, the build lacks it, or the run never reached its initialization point. The minimal configuration uses `log_options = "none"`, so it does not request instruction logs.

## Control host and native logs

Global logging options precede the subcommand:

```bash
fastdyn -v run -c configs/minimal.toml -o out/debug-minimal
fastdyn --log-level fastdyn.targets=DEBUG run -c configs/minimal.toml -o out/debug-target
fastdyn --log-level fastdyn.native=DEBUG run -c configs/minimal.toml -o out/debug-native
```

`-v` selects debug output and `-q` selects warnings and errors; they are mutually exclusive. Repeat `--log-level` to adjust multiple logger namespaces. `FASTDYN_LOG_LEVEL` supplies the default when no CLI level is selected.

To retain Python-side logs, use a file outside the work directory that the runner may replace:

```bash
mkdir -p out/logs
fastdyn --log-file out/logs/minimal-python.log \
  run -c configs/minimal.toml -o out/debug-minimal
```

The file records Python debug messages regardless of the console threshold. Native plugin output is written by QEMU directly and is not copied into that Python log file. Capture both process streams when you need the complete launch transcript:

```bash
fastdyn run -c configs/minimal.toml -o out/debug-minimal \
  > out/logs/minimal-console.log 2>&1
```

Native debug statements additionally require a build with `DEBUG_PRINT=true`.

## Attach GDB to a known point

For a target you have configured, edit its existing `[Machine]` table:

```toml
[Machine]
enable_gdb = true
gdb_port = 1234
stop_on_start = true
launch_gdb = false
print_command = true
```

This is a settings fragment, not a complete configuration. `stop_on_start` pauses before execution; the firmware will appear idle until the debugger continues it. In another terminal, load the exact ELF and attach. For the bundled minimal target:

```bash
gdb-multiarch tests/sample_binaries/RTOS/RTOSDemo.axf
```

```gdb
target remote :1234
break main
continue
info registers
```

Keep symbol files synchronized with the loaded binary. If a trigger was taken from another build, a valid-looking address can silently observe a different instruction. The generated rules, disassembly, and current PC give complementary checks.

`monitor_port` controls the textual QEMU monitor; `qmp_socket` controls its machine-readable QMP interface. They are distinct from GDB. Setting `monitor_port = 0` disables the default TCP monitor. The default QMP socket is made run-specific, but a manually configured fixed socket remains your responsibility when launching concurrent runs.

## Inspect through Ghidra

The repository supplies a custom GDB launcher under `decompilers/ghidra/` for inspecting an executing target through Ghidra's debugger. Load the project corresponding to the exact guest image and verify its address mapping before attaching. The pinned integration note identifies the launcher to replace; adapt that integration to your installed Ghidra layout rather than assuming every version uses the same path.

## Move from instructions to behavior

A complete instruction trace is often unnecessary. Choose an observer with the right scope:

- **FunctionCounter** identifies frequently reached functions.
- **FunctionTracer** records function-entry activity selected by its preprocessing.
- **VariableWatch** observes selected data accesses.
- **RTOS introspection** produces task and scheduling records and can serve the activity monitor.
- **ObjectSan** checks supported object-boundary conditions in its instrumented target.

Their prerequisites and example configurations are covered in [tracing and sanitizers](../instrumentation/tracing-and-sanitizers.md) and [RTOS introspection](../instrumentation/introspection.md). A source name alone is insufficient if the plugin needs DWARF information that the image does not contain.

## Diagnose the first failing layer

| Symptom | Focused next check |
| --- | --- |
| Executable or plugin not found | Inspect the logged QEMU selection, plugin path, build metadata, and active environment. |
| Boot stalls immediately | Verify CPU features, vector/entry settings, ELF identity, and mapped writable memory. |
| CPU waits at the first instruction | Check `stop_on_start` and continue through GDB. |
| Peripheral polling never finishes | Inspect the status-register model, relevant interrupt delivery, and expected side effects. |
| A hook never runs | Resolve its PC in this ELF, then inspect generated rules and control flow. |
| Vehicle run exits early | Inspect FMU initialization and the exit status of helpers marked `terminate_run_on_exit`. |
| A second run behaves differently | Check external RAM backing, plugin state, input files, and helper lifecycle. |

FastDyn sends SIGINT to QEMU on an orderly stop and waits up to `exit_timeout_ms`, default 5000 ms, before killing it. Prefer that path when collecting plugin exit artifacts. `fastdyn loop` restarts runtime failures, which is useful for campaigns but can obscure a single failing launch; use `run` while diagnosing the cause.

## Source guide

- [Run orchestration and artifacts](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runner.py)
- [Python and native logging thresholds](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/logs.py)
- [QEMU command construction and shutdown](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
- [Helper process lifecycle](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runtime_config.py)
- [Coverage accumulation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/cov_bbl.c)
- [Ghidra launcher integration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/decompilers/ghidra/README.md)
