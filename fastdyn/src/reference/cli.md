# Command-line reference

The installed entry point is `fastdyn`, provided by `fastdyn.main:cli`. Run commands from the FastDyn repository root unless your paths are explicitly configured for another location. The examples assume the environment from [installation](../getting-started/installation.md) is active.

```bash
fastdyn --help
fastdyn COMMAND --help
```

This reference covers the core CLI at `f9666d7f518c373e89831d8e14a6371a27fe6436`, with later additions labeled by revision. Plugin-specific settings belong in TOML rather than new top-level flags.

## Global options

Place these before the command:

| Option | Effect |
| --- | --- |
| `--version` | Print the installed FastDyn version. |
| `-v`, `--verbose` | Set the default console log level to DEBUG. |
| `-q`, `--quiet` | Set it to WARNING. Cannot be combined with `-v`. |
| `--log-level [LOGGER=]LEVEL` | Set a global or namespace-specific level; repeatable. |
| `--log-file PATH` | Also write Python log messages at DEBUG and above to a file. |
| `--help` | Display group help. |

Without a level option, `FASTDYN_LOG_LEVEL` supplies the default, falling back to INFO. Native plugin messages use the native threshold but are emitted directly by QEMU, so `--log-file` does not collect them. Put saved log files outside a work directory that the runner will replace.

```bash
fastdyn --log-level fastdyn.targets=DEBUG run -c configs/minimal.toml
```

## `run`

```bash
fastdyn run -c CONFIG [-o WORK_DIR]
```

| Option | Default | Meaning |
| --- | --- | --- |
| `-c`, `--config PATH` | Required | Existing TOML file. |
| `-o`, `--work-dir PATH` | `./fastdyn_work` | Run outputs; an existing directory is replaced by default. |
| `-s`, `--svd PATH` | Repository default | Explicit SVD file or catalog. |
| `-p`, `--persist-work-dir` | Off | Retain an existing work directory. |
| `--fmu NAME` | TOML selection | Override the active FMU model. |
| `--no-build-fmu` | Off | Skip automatic FMU generation. The required artifact must already exist. |
| `--no-run-processes` | Off | Skip `[Rumoca]` and `[Run.processes]` helpers. |
| `-m`, `--map-file PATH` | None | Accepted legacy option; currently unused by the run implementation. |

The run path validates runtime configuration, prepares the output directory, handles optional FMU generation, starts configured helpers, preprocesses the target, and launches QEMU. Guest module boot through `[Run].bridge_boot` remains active with `--no-run-processes`; it is a separate mechanism.

Configuration or launch failures produce an error. An unexpected QEMU failure also produces a nonzero command result. Ctrl-C produces the conventional exit status 130 after shutdown handling.

## `loop`

`loop` accepts the same options as `run`:

```bash
fastdyn loop -c configs/target.toml -o out/repeated-target
```

After a clean exit it restarts with a fresh work directory. After a QEMU runtime error or a terminating helper failure, it restarts while preserving the directory for inspection. Configuration and setup errors stop the loop instead of retrying indefinitely. Automatic FMU generation is attempted only for the first iteration.

This is repeated execution of the configured experiment. It does not itself construct a function-level calling context or define a fuzzing snapshot boundary.

## `swarm`

`swarm` launches isolated copies of one configuration:

```bash
fastdyn swarm -c configs/copter462.toml -n 2 \
  -o out/swarm/copter --base-port 18000 --dry-run
```

| Option | Default | Meaning |
| --- | --- | --- |
| `-c`, `--config PATH` | Required | Shared configuration template. |
| `-n`, `--instances N` | `1` | Number of workers. |
| `-o`, `--work-dir-root PATH` | `./fastdyn_swarm` | Parent of worker output directories. |
| `--base-port N` | `15000` | Base for worker port allocation. |
| `--port-stride N` | `20` | Spacing between each worker's port set. |
| `--jobs N` | Number of instances | Maximum concurrently running workers. |
| `--loop` | Off | Use `fastdyn loop` for each worker. |
| `--fmu NAME` | TOML selection | Select the active model. |
| `--no-build-fmu` | Off | Skip the one-time build before workers start. |
| `--no-run-processes` | Off | Skip helper processes in each worker. |
| `--timeout-sec SECONDS` | None | Overall campaign timeout. |
| `--smoke-sec SECONDS` | None | Require workers to remain alive for a bounded smoke interval, then stop. |
| `--stop-on-failure` | Off | Stop launching new workers after a nonzero exit. |
| `--skip-port-check` | Off | Skip the preflight TCP/UDP conflict check. |
| `--dry-run` | Off | Print plans and commands without launching workers or building the FMU. |

Workers receive separate RAM backing, QMP sockets, output paths, and configured service ports. Dry-run output verifies the plan, not firmware or FMU execution. A swarm does not implicitly connect the guest devices or physical worlds; see [multiple firmwares](../simulation/multiple-firmwares.md).

## `build-model`

Compile C device models into shared libraries:

```bash
fastdyn build-model models/uart.c -o build/models
fastdyn build-model models/ -o build/models -r -j 8
fastdyn build-model --name spi4 models/spi4.c models/spi4_dma.c -o build/models
```

The source paths must exist. `-o/--out-dir` is required. By default each C source becomes a model; `--name` combines the given files into one named model.

| Option | Meaning |
| --- | --- |
| `-r`, `--recursive` | Find C sources below input directories. |
| `-j`, `--jobs N` | Parallel compilation; defaults to CPU count. |
| `-k`, `--keep-going` | Continue other model builds after a failure. |
| `--exclude PATTERN` | Exclude matching sources; repeatable. |
| `--no-vio` | Build without LibVIO. |
| `--pkg NAME` | Add a pkg-config package; repeatable. `fastdyn` links the fuzzer hooks. |
| `--json` | Emit a machine-readable build report. |

Sources, headers, and the compiler command determine whether a model is rebuilt. A failed model does not retain an old output `.so`, and any failure makes the command exit with status 1. See [writing a model](../devices/writing-a-model.md) for the ABI.

### Addition at `a38af40`: `--mmio-opt`

At [`a38af408451394ea2f41be1e9cf1e96bc46c370f`](https://github.com/boardrunner2049/FastDyn/commit/a38af408451394ea2f41be1e9cf1e96bc46c370f), `build-model --mmio-opt` enables experimental extraction of read-operation metadata. Run this example from a matching FastDyn checkout with the corresponding QEMU headers and build environment:

```bash
fastdyn build-model --mmio-opt --no-vio \
  tests/models/elder_echo.c -o build/mmio-models --json
```

This option selects `clang-18`, falling back to `clang`, and currently requires one C source per model. It embeds metadata in the normal `.so` and writes `elder_echo.mmio.json` beside it. The separate `--json` flag prints the build report, including `mmio_operations`; it is not required to create the metadata report.

Building metadata does not enable substitution by itself. Configure the library as an elder scroll and enable `[CPU.cpu0.plugins.mmio_opt]` in the run configuration. The feature has reviewed correctness limitations; use the [automatic MMIO workflow](../designs/automatic-mmio.md) for its matching setup, supported execution scope, reports, and validation requirements. Ordinary `build-model` usage does not require this option or its Clang dependency.

## `help`

This command browses configuration choices, distinct from Click's `--help` option:

```bash
fastdyn help
fastdyn help platforms STM32
fastdyn help virtuals --no-browse
```

Available topics are `platforms`, `virtuals`, `plugins`, `modifiers`, `device-models`, `machine`, `memory`, `firmware`, and `run`. `plugins` currently aliases `virtuals`, so both display virtual actions and run-wide plugins.

Use `--browse` to force the picker or `--no-browse` for plain output. `platforms` accepts an optional vendor/platform query and `-s/--svd PATH`. The top-level help browser also accepts an SVD path. The platform catalog must be present, normally from setup.

## `timing-summary`

```bash
fastdyn timing-summary out/first-run/fastdyn_timing.jsonl --top 20
```

The positional file must exist. `--top` defaults to 30. The command reports completed phases and marks, then lists phases by descending duration. Nested phases overlap, so summing all displayed durations does not give total execution time.

## Source guide

- [CLI definitions and option defaults](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/main.py)
- [Installed entry point](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/pyproject.toml)
- [Runner lifecycle](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/runner.py)
- [Worker planning and execution](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/swarm.py)
- [Model compiler](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/model_build.py)
- [`a38af40` experimental `--mmio-opt` option](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/src/fastdyn/main.py)
