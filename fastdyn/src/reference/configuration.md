# Configuration reference

FastDyn reads one TOML file for a machine experiment. The core sections are `[Machine]`, `[Memory.main]`, and one or more CPU array tables such as `[[CPU.cpu0]]`. Device handling, plugins, FMU generation, and helper processes add their own sections.

This reference describes the current parser. Examples are fragments to merge into a complete configuration; do not paste a second definition of an existing TOML table or key. Use [configure a firmware](../getting-started/configuration.md) for the guided workflow and the feature chapters for plugin-specific settings.

## Machine controls

| Key in `[Machine]` | Preferred value / default | Behavior |
| --- | --- | --- |
| `platform` | Optional string | SVD platform metadata; `generic-cortexm` allows a generic Cortex-M profile. |
| `qemu_path` | Optional executable path | Explicit QEMU selection. Otherwise use `FASTDYN_QEMU`, recorded build metadata, then the architecture executable on `PATH`. |
| `display` | String, `"none"` | QEMU display backend. |
| `serial` | Optional string | Explicit QEMU serial backend. |
| `monitor` | Optional string | Explicit monitor backend, overriding the default TCP choice. |
| `monitor_port` | Integer, `5555` | Default monitor TCP port; `0` disables it. |
| `qmp_socket` | String, `"/tmp/qmp.sock"` | QMP socket; the default is replaced with a run-specific path. |
| `enable_gdb` | Boolean, `false` | Enable QEMU's GDB server. |
| `gdb_port` | Integer, `1234` | GDB server port. |
| `stop_on_start` | Boolean, `false` | Start paused. |
| `launch_gdb` | Boolean, `false` | Request the automatic GDB-launch path. |
| `log_options` | String | QEMU `-d` categories; `"none"` disables instruction logging. |
| `log_file` | Path string | QEMU log destination; relative paths are under the work directory. |
| `semihosting` | Boolean, `false` in the TOML parser | Enable semihosting for supported targets. |
| `semihosting_config` | `"enable=on,target=native"` | QEMU semihosting configuration. |
| `print_command` | Boolean, `false` | Print the generated QEMU command. |
| `exit_timeout_ms` | Positive integer, `5000` | Wait before force-killing QEMU during shutdown. |
| `reset_memory_files` | Boolean, `false` | Clear file-backed RAM before launch. |
| `bios` | Optional path string | Fallback BIOS image for a CPU without its own `bios`. |

The default QMP path becomes `<work-dir>/qmp.sock`. If that path exceeds Unix socket limits, the launcher selects a shorter per-user location. A nondefault explicit socket path remains explicit.

### Simulation time

```toml
[Machine]
icount = { shift = 5, sleep = false, align = false }
timer_irq_period_ns = 1000000
exact_budget_stop = false
```

`icount` accepts a QEMU option string, a boolean, or a table. The table supports `enabled`, nonnegative integer or string `shift`, boolean `sleep` and `align`, and `extra` as a string or string array. `enabled = false` disables it. `FASTDYN_QEMU_ICOUNT` overrides the generated value.

`timer_irq_period_ns` selects the periodic board interrupt interval when used by the configured runtime. The maintained vehicle profiles use 1,000,000 ns. This is a simulation-time setting, not a claim that the host executes a step in one millisecond.

`exact_budget_stop` controls how the co-simulation budget mechanism stops at its deadline. It defaults to false. Use the [multiple-firmware chapter](../simulation/multiple-firmwares.md) for the master/slave timing contract; enabling this field alone does not install an inter-device connection.

### Coverage and fuzzing

| Key | Default | Meaning |
| --- | --- | --- |
| `coverage` | `false` | Enable the configured coverage path; requires a compatible build. |
| `edge_coverage` | `false` | Add cumulative edge output when coverage is available. |
| `fuzzing` | `false` | Start the compiled input backend. |
| `fuzzing_schema` | Absent | JSON schema file for the generic native fuzzer. |
| `finline` | Absent | Existing static inline-I/O mapping path; see [inline device modeling](../advanced/inline-device-modeling.md) for its access-map and original-instruction handling. |
| `savestate_extra_ranges` | Empty array | Additional `{ start, size }` regions for the native save-state machinery. |

`FASTDYN_COVERAGE`, `FASTDYN_EDGE_COVERAGE`, and `FASTDYN_FUZZING` override their corresponding booleans. A save-state range accepts integer or integer-string addresses and a positive size; ranges exceeding the 64-bit address space are rejected. These settings do not make the current ARM-oriented snapshot implementation architecture-independent.

## Memory banks

The main bank is a plain table. Additional banks use array tables:

```toml
[Memory.main]
id = "ram0"
base_address = "0x20000000"
memory_size = "256K"
backend = "file"
share = true

[[Memory.ram1]]
id = "ram1"
base_address = "0x30000000"
memory_size = "64K"
backend = "ram"
```

| Key | Default | Meaning |
| --- | --- | --- |
| `memory_size` | Required | QEMU size string, for example `"256K"` or `"8M"`. |
| `base_address` | Unset | Guest mapping base where supported by the machine. |
| `id` | Bank name | QEMU memory-backend identifier. |
| `memory_type` | `"SRAM"` | Metadata label: `SRAM`, `MMIO`, `FLASH`, `DRAM`, `RAM`, or `SYSTEM`. |
| `backend` | `"file"` | `file`, `ram`, or `memfd`. |
| `memory_file` | Run-local file | Backing path for a file backend. |
| `share` | `true` | Request shared mapping of the backend. |

The generic Cortex-M machine maps additional banks through its custom properties. Other QEMU machines retain their own memory layout. Additional bank indices are generated in sorted name order. `index` and `prealloc` appear in some historical examples but are not consumed by the current TOML memory parser; do not rely on those keys to change the run.

Explicitly use `backend = "file"` when depending on swarm's `FASTDYN_QEMU_MEMORY_DIR` override. Keep arbitrary external RAM paths separate between concurrent runs. `reset_memory_files` clears guest RAM backing, not external device or helper state.

## CPU and firmware

```toml
[[CPU.cpu0]]
arch = "arm"
machine = "cortexm"
cpu = "cortex-m4"
binary = "firmware.elf"
init_nsvtor = "0x08000000"
plugin_library = "build/libfastdyn.so"
```

| Key | Default / purpose |
| --- | --- |
| `arch` | `"arm"`; selects architecture-specific launch behavior. |
| `machine` | `"cortexm"`; QEMU machine model. |
| `cpu` | `"cortex-m4"`; QEMU CPU model. |
| `binary` | Firmware path; supply the correct image for the selected machine. |
| `init_nsvtor` | Cortex-M initial vector address; when omitted for the generic Cortex-M ELF path, the launcher attempts to derive it. |
| `plugin_library` | Default FastDyn build library path. |
| `drive_file`, `drive_format` | Optional disk-image boot input; format defaults to `"raw"`. |
| `bios` | Optional CPU BIOS image, with machine-level fallback. |
| `monitor_elf` | Optional monitor image used by existing monitor-based integrations. |
| `twintrace` | `"record"`, `"replay"`, or disabled/`"None"`. |
| `hardware_trace` | Trace file for record/replay. |
| `existing_config_path` | Directory containing existing virtual/modifier rules; false or empty disables it. |
| `logger_content` | Existing plugin-logger configuration text. |

A QEMU instance with multiple CPUs requires homogeneous `arch`, `machine`, `cpu`, and `binary`, plus a common plugin library. The parser consumes the first entry under each CPU name. Do not put different firmware images into multiple entries of `[[CPU.cpu0]]` expecting separate instances.

Virtuals and modifiers are child arrays:

```toml
[[CPU.cpu0.virtuals]]
at = "0x080068b0"
instruction = "printreg"
args = ["0"]

[[CPU.cpu0.modifiers]]
at = "0x0800397e"
patch = "r0 <- 3"
```

Those addresses are from the bundled minimal fixture. The exact grammar and register support are described in [virtuals and modifiers](../instrumentation/virtuals-and-modifiers.md).

### Run-wide plugins

```toml
[CPU.cpu0.plugins.function_counter]
enabled = true
```

Each plugin owns the remaining fields of its table. An optional `source` names an external plugin directory, resolved relative to the configuration file. FastDyn removes `source` before handing settings to the plugin. See [virtual plugins](../extending/virtual-plugins.md) for the host/runtime contract.

## Devices and handlers

`[Device.Models.<name>]` registers a model family and its optional `backend`. `[Device.<device>]` declares regions and model-specific configuration. Each `[[Device.<device>.handlers]]` entry needs `model` and `enabled`; optional fields include `scroll`, `args`, and `type`.

```toml
[Device.Models.elder]

[Device.uart]
ranges = [["0x40004400", "0x400047ff"]]
irq = [54]

[[Device.uart.handlers]]
model = "elder"
enabled = true
scroll = "models/uart.so"
```

This fragment requires an actual model implementing the selected device. Device-specific fields outside FastDyn's reserved keys are carried to the model. `slaves` and `connections` support attached devices and host endpoints as documented in the device chapters.

`irq` is a list of numbers, numeric strings, SVD names, or inclusive `[first, last]` ranges. Cortex-M numeric values are exception numbers. The old colon-separated string form is rejected. FastDyn also rejects enabling both passthrough and twintrace hardware backends for the same device, because both would issue accesses to the physical probe.

## FMU selection and generation

```toml
[FMU]
active = "quadrotor"
auto_build = true

[FMU.models.quadrotor]
model = "FastDyn.Copter"
model_file = "modelica/FastDyn/Copter.mo"
source_roots = ["modelica", "third_party/common/modelica_models"]
output = "out/fmi3/Copter"
build = true
release = false
```

`active`, `FASTDYN_FMI_NAME`, or `--fmu` selects a named entry, in increasing precedence. A configuration may alternatively place one model directly in `[FMU]`, in which case `--fmu NAME` is not applicable.

`model` and `model_file` identify the Modelica model. Supply `source_roots` as a nonempty path array, or `source_root` for one root. `output` defaults under `out/fmi3/`. `build = true` requests a packaged FMU; false emits a source tree that still needs a compiled runtime binary before execution. `auto_build` defaults to false, while the maintained vehicle profiles enable it. `release` controls the Rumoca Cargo build mode.

`[FMU.models.<name>.parameters]` holds numeric parameter overrides. `compose` selects a composition file; an inline `physics` table is an alternative and must name the same model. These alternatives cannot be combined. `[FMU].rumoca_dir` or `FASTDYN_RUMOCA_DIR` selects the compiler checkout. See [physics and FMU](../simulation/physics-and-fmu.md) for package loading and the model interface.

## Helpers, bridge boot, and profiling

`[Run]` supplies `cwd` and `env` defaults for helpers. Each `[Run.processes.<name>]` accepts:

| Key | Default / behavior |
| --- | --- |
| `command` | Required string or string array. A string uses a shell by default. |
| `enabled` | `true` |
| `cwd` | Run default, then repository root |
| `env` | Additional helper environment |
| `background` | `true`; false runs the helper synchronously during startup |
| `quiet` | `false`; true discards stdout/stderr |
| `start_delay_sec` | `0`; delayed startup |
| `ready_message` | Printed after starting; it is not a readiness probe |
| `stop_on_exit` | `true`; stop the helper when FastDyn exits |
| `terminate_run_on_exit` | `false`; when true, helper exit stops QEMU |
| `shell` | Explicit shell behavior override |

`[Run].bridge_boot` selects the console initialization script used by profiles such as PX4. It is independent of helpers. `FASTDYN_BRIDGE_BOOT` overrides it; an explicitly empty value disables automatic console initialization.

`[Rumoca]` configures the optional separate Rumoca viewer/lockstep process. It is normally disabled in the in-process ArduPilot FMU path.

`[Run.profiling]` supports `timing` and `timing_echo` (both default true), `python` (false), `fmu` (defaults to the timing setting), `perf` (`"off"`, `"stat"`, or `"record"`), `perf_events`, and `perf_frequency_hz` (99). Profiling outputs live under the work directory; Linux perf use also depends on host availability and permissions.

## Path and environment rules

| Field family | Resolution |
| --- | --- |
| Firmware, hardware trace, `scroll`, slave `device_scroll`, Python endpoint helper | Configuration directory first if the file exists there; otherwise current-directory behavior. |
| External plugin `source` | Configuration directory. |
| `existing_config_path`, fuzzing schema | Configuration directory, current directory, then discovered repository root. |
| FMU sources/output and helper working directories | Repository-root-relative unless absolute. |
| TOML `bridge_boot` | Repository root; environment override is caller-directory-relative. |
| QEMU `log_file` | Work directory when relative. |

Helper strings support `${NAME}` and `${NAME:-default}` expansion. That is not a promise of arbitrary shell expansion in every TOML field. Swarm injects explicit overrides for monitor/GDB/service ports, RAM backing, and QMP sockets.

Core configuration is not a uniformly closed schema: a key found in an old example may be ignored by today's parser. Use this reference and the source of the consuming plugin, and inspect generated artifacts when changing a critical field.

## Source guide

- [Core TOML parsing and defaults](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/toml_parser.py)
- [Memory, CPU, and device data structures](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/fastdyn.py)
- [QEMU launch and generated options](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
- [FMU selection and build resolution](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/fmu_build.py)
- [Helper and profiling configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runtime_config.py)
- [Vehicle configuration example](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/copter462.toml)
