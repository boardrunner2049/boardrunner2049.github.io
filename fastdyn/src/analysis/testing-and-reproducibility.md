# Testing and reproducibility

A FastDyn experiment has several independently testable layers: configuration, host analysis, native instrumentation, device behavior, firmware progress, and physical outcomes. A good validation plan checks the layer changed by the work and one observable result at the next boundary.

The commands in this chapter are repository-provided validation paths. Their presence establishes what the repository is designed to test; it is not a claim that every test passed on every host or that this book's preparation reran the full QEMU and vehicle suite.

## Run the Python unit suite

From the FastDyn repository root, after setup:

```bash
source fastdyn-env/bin/activate
PYTHONPATH=src python -m pytest tests/unit/ -v
```

The suite covers configuration defaults and paths, model builds, CLI behavior, run orchestration, external plugins, shared host analysis, introspection, FMU handling, swarm plans, and other host components. It uses mocked external boundaries where appropriate. Passing these tests does not establish that a physical peripheral model or firmware mission is correct.

Use a focused test while iterating:

```bash
PYTHONPATH=src python -m pytest tests/unit/test_config_paths.py -v
PYTHONPATH=src python -m pytest tests/unit/test_virtual_preprocessing.py -v
```

A useful test should verify observable behavior or a contract: for example, whether two symbolic hooks resolve to a collision, whether a stale model library is removed after compilation failure, or whether workers receive distinct ports. Merely restating a helper's implementation does not improve confidence in the experiment.

## Check the full minimal execution path

After building patched QEMU and `build/libfastdyn.so`:

```bash
fastdyn -q run -c configs/minimal.toml -o out/validation/minimal
```

Require the register result `Reg 0:0x00000003`, a `[BENCH][minimal]` record, and a successful exit. This exercises the configuration-to-QEMU path, a modifier, native virtual actions, and guest execution. It does not exercise active peripheral models, a complete RTOS workload, or physics.

The push/PR workflow in `.github/workflows/ci.yml` builds the runtime, runs the unit suite, checks those minimal-run outputs, and runs the bundled FreeRTOS introspection smoke test.

## Validate introspection against real guest execution

The bundled smoke test uses a committed debug-symbol FreeRTOS image and checks RTOS detection, generated hooks, a schema symbol, and live task activity:

```bash
FASTDYN_QEMU_BIN="$PWD/third_party/common/qemu/build/qemu-system-arm" \
  tests/integration/run_bundled_freertos_introspection_smoke.sh
```

The explicit environment setting matches a normal pinned-submodule build. The script's own fallback uses the older sibling checkout at `../qemu`, so set the path when your layout differs. The script also accepts `FASTDYN_BIN` and `FASTDYN_PLUGIN_LIB` for alternate builds.

The upstream RTOS smoke scripts build additional fixtures and therefore have extra compiler and network requirements. For example:

```bash
FASTDYN_QEMU_BIN="$PWD/third_party/common/qemu/build/qemu-system-arm" \
  tests/integration/run_freertos_introspection_smoke.sh
```

Other scripts cover ThreadX, RT-Thread, ChibiOS, NuttX, and Zephyr. Inspect each script's prerequisites rather than assuming that a committed ELF and a rebuild-from-upstream test are equivalent. The STM32F429I LED fixture additionally checks that two task-owned counters advance, giving a behavioral scheduling check.

## Test raw-image and ELF paths deliberately

`tests/raw/README.md` records how to regenerate flat images from the RTOS ELF fixtures and gives their load addresses. A raw image preserves bytes but discards ELF architecture, load-region, symbol, and DWARF metadata. Use raw images to test the explicitly supported numeric-address paths; retain the source ELF for tests that require symbolic triggers, type information, or RTOS discovery. The [source map](../reference/source-map.md) links the fixture guide.

## Validate a vehicle in stages

Prepare the maintained FMI v3 stack first:

```bash
source ./setup.sh --build-qemu --with-rumoca
```

A vehicle launch smoke checks FMU loading, clock integration, the board tick, heartbeat, and telemetry. For a rover:

```bash
FASTDYN_COURBET_CONFIG=configs/rover462.toml \
FASTDYN_COURBET_LABEL=ardurover \
  tests/integration/courbet_fmu_vehicle_smoke.sh
```

A full copter mission adds stronger requirements:

```bash
tests/integration/courbet_mission_smoke.sh
```

That script checks mission upload, arming, sufficient climb, mission progression, and landing. A successful launch is a weaker result than successful mission completion. Neither establishes physical fidelity without a separate comparison to the intended system and measurements.

For concurrency, first inspect the plan without launching firmware:

```bash
fastdyn swarm -c configs/copter462.toml -n 2 \
  -o out/validation/swarm-plan --base-port 18000 --dry-run
```

Then use `tests/integration/courbet_swarm_smoke.sh` for actual workers. The manually triggered Courbet Mission workflow contains these broader vehicle, OptiFuzz wiring, and swarm checks. Its configuration is useful evidence of test scope; consult actual CI results when reporting a pass.

## Preserve the experiment inputs

Before comparing two executions, record enough information to reconstruct both:

| Record | Why it matters |
| --- | --- |
| FastDyn commit and local diff | Local instrumentation changes alter the experiment. |
| Submodule revisions and QEMU patch state | The translator, libraries, compiler, and models are separate dependencies. |
| Firmware hash and symbol-file identity | Trigger PCs and debug metadata are binary-specific. |
| Complete TOML and enabled build features | A config cannot enable a feature absent from the native build. |
| Device-model sources or binaries and hashes | Device behavior is part of the executed system. |
| FMU package, parameters, timing, and initial state | Physics results depend on more than the firmware image. |
| Fuzzer input or seed and property definition | A finding needs a reproducible input and an explicit oracle. |
| Helper commands and relevant environment overrides | Ports, mutation files, and runtime selection can change behavior. |
| Result files, process exit statuses, and logs | A silent early exit can otherwise resemble success. |

Record relevant values rather than dumping the entire environment, which may contain unrelated credentials. Useful local commands include `git rev-parse HEAD`, `git diff`, `git submodule status`, and `sha256sum` on the actual experiment artifacts.

## Keep state and timing comparisons controlled

A fresh work directory does not clear an external RAM file named by the configuration. When a clean boot is required, use fresh backing paths or the explicit `reset_memory_files` option. Similarly, a guest snapshot does not automatically reset host services or a physical board.

Hold logging, tracing, solver settings, input sequence, and stopping criteria constant when measuring performance. Report what was timed: host setup, guest execution, an entire mission, or multiple independent workers. Instruction-counted simulation time and elapsed host time answer different questions. Preserve both when interpreting a controller's behavior or claiming throughput.

## Source guide

- [Unit-test conventions and commands](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/unit/README.md)
- [Default CI workflow](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/.github/workflows/ci.yml)
- [Bundled introspection smoke and path overrides](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/integration/run_bundled_freertos_introspection_smoke.sh)
- [Integration test guide](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/integration/README.md)
- [Full vehicle and swarm workflow](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/.github/workflows/courbet-mission.yml)
- [Memory reset and shutdown implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
