# The Python API

Use the Python API when FastDyn is one part of a larger workflow: a campaign driver, a model-generation system, a target-analysis tool, or a notebook that prepares and runs experiments. The public runner gives these callers the same orchestration as `fastdyn run`, including configuration validation, work-directory setup, optional FMU building, helper-process lifecycle, and QEMU execution.

Run the examples in the activated FastDyn environment from the FastDyn source checkout unless another location is stated. They require the same native build as the corresponding CLI command.

## Run a configuration

The smallest program uses `run_config()`:

```python
import fastdyn

results = fastdyn.run_config(
    "configs/minimal.toml",
    work_dir="out/python-first-run",
)

for result in results:
    print(result.machine_name, result.exit_code, result.work_dir)
```

The call blocks until execution finishes. The minimal example terminates itself; a long-running firmware needs the stop behavior appropriate to its experiment. The return value is a list of `RunResult` objects, one per machine processed by the runner.

| Result field | Meaning |
| --- | --- |
| `machine_name` | Runner identity, such as `machine0` |
| `exit_code` | Exit status returned by the run machinery |
| `work_dir` | Resolved path containing the run artifacts |

The current runner iterates its machines sequentially. Receiving a list of results does not make this API a parallel multi-firmware scheduler. Use the [campaign and co-simulation facilities](../simulation/multiple-firmwares.md) for those execution arrangements.

## Control preparation explicitly

`load()` prepares a session without starting its machines:

```python
import fastdyn

session = fastdyn.load(
    "configs/minimal.toml",
    work_dir="out/prepared-run",
    build_fmu=False,
    run_processes=False,
)

results = session.run()
```

In this example the configuration does not require an FMU or helper process, so both options are appropriate. For a scenario that needs them, leave their defaults enabled or supply equivalent prepared resources intentionally.

`load()` is not a side-effect-free parser. It validates the configuration, prepares the work directory, configures measurement, and may build an FMU. `Session.run()` starts the configured helpers and parses the machine configuration before execution. A session is a preparation/lifecycle object, not a guest snapshot or an isolated repeated-trial reset mechanism.

## Options shared by the run entry points

| Parameter | Default | Purpose |
| --- | --- | --- |
| `work_dir` | `"fastdyn_work"` | Location for generated rules and results |
| `svd` | Built-in catalog location | Override the SVD source |
| `persist_work_dir` | `False` | Keep an existing work directory instead of replacing it |
| `fmu` | `None` | Select an FMU name where the configuration supports selection |
| `build_fmu` | `True` | Allow configured automatic FMU preparation |
| `run_processes` | `True` | Start configured helper processes |
| `validate` | `True` | Validate configuration before preparing the run directory |
| `report` | Module logger | Receive preparation status messages |

Choose a dedicated output directory. With the default `persist_work_dir=False`, an existing directory at that path is replaced. Persisting files is different from resetting guest RAM, device state, or plant state; the experiment must define each of those separately.

`run_config()` also accepts `adjust` and `phase_name`. `Session.run()` accepts `adjust`. The adjustment callback receives the parsed `Fastdyn` handle before a machine starts, allowing an application to change machine objects without writing a temporary TOML. Keep target-specific changes in the application or adapter, and preserve the same validation assumptions as the equivalent configuration.

## Handle errors at the application boundary

Preparation failures may raise `fastdyn.RunError`; an unexpected QEMU exit can raise `QemuExitError` from `fastdyn.targets.qemu_target`. Configuration and analysis failures have their own specific exception classes. Do not treat an empty output file or a partial set of artifacts as a successful experiment merely because a process was launched.

A downstream application should attach the configuration, output directory, and failure context to its own result record. It can then distinguish a setup failure, a terminated run, a detected property violation, and an ordinary successful result.

FastDyn library code uses Python logging. Configure application logging at your entry point. This keeps the engine usable inside a larger program without taking over its log handlers.

## Build models programmatically

The public model builder accepts source files, directories, or named groups of source files. This example builds the supplied ABI demonstration without LibVIO:

```python
import fastdyn

report = fastdyn.build_models(
    ["tests/models/elder_echo.c"],
    out_dir="build/models",
    vio=False,
)

print(report.summary())
if not report.ok:
    for model in report.results:
        if model.status == "failed":
            print(model.name, model.first_error)
    raise RuntimeError("Device model build failed")
```

`BuildReport` exposes per-model results, a summary, and `to_dict()` for machine-readable reporting. Builds are incremental, include dependency tracking, and remove stale outputs on failure. The [model chapter](../devices/writing-a-model.md) describes the ABI and CLI equivalents.

For a model spread across several files, construct `fastdyn.Model(name, sources)` and pass it to `build_models()`. This declares one shared-library output instead of treating every C file as an independent model.

## Construct a machine directly

The lower-level builder is available through `fastdyn.fastdyn.Fastdyn`. It can create machines, CPUs, memories, devices, model handlers, virtual instructions, and modifiers. The repository contains two useful examples:

```bash
./fastdyn-env/bin/python configs/python_api/example.py
./fastdyn-env/bin/python configs/python_api/stm32f429i-disc0.py
```

The first is a non-running API tour with illustrative addresses. The second builds and runs the bundled FreeRTOS machine and remains active until stopped. Do not treat the tour's mixed addresses as one executable firmware setup.

Prefer `run_config()` for a downstream tool whose inputs are already TOML. Use the builder when constructing the machine itself is the application's job. In either case, call the API directly rather than spawning another `fastdyn` CLI process and recreating its orchestration.

## Source guide

- [Public package exports](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/__init__.py)
- [Runner signatures and lifecycle](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runner.py)
- [Model builder and result types](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/model_build.py)
- [Machine builder](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/fastdyn.py)
- [Non-running API tour](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/python_api/example.py)
- [Runnable builder example](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/python_api/stm32f429i-disc0.py)
