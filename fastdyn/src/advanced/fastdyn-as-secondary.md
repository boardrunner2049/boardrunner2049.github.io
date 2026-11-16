# FastDyn as a secondary simulator

FastDyn can execute firmware under an external controller that decides when the guest may advance. The controller grants a slice of virtual time, waits for the guest to pause, and then inspects or exchanges state before granting another slice. This supports bounded firmware experiments and coordinated runs of several guests.

The implementation calls this **co-simulation slave mode**. Its shipped controller is named `BudgetMaster`, and its examples retain names such as `cosim_slave.toml`. This chapter uses *secondary* for FastDyn's role and preserves those actual API and file names.

The source baseline is FastDyn [`e44dca2`](https://github.com/boardrunner2049/FastDyn/tree/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576), with QEMU submodule `99b54836` and that FastDyn revision's ordered patches. This is an implemented QMP control interface, independent of the [Tempo scheduler](tempo.md). Tempo currently demonstrates its own mock participants; the QMP workflow here runs independently.

## Who controls what

| Component | Responsibility |
| --- | --- |
| External controller | Choose time grants, wait for completion, coordinate exchanges, and manage the experiment's processes |
| Patched QEMU | Execute guest instructions, maintain the virtual clock and budget deadline, and publish QMP events |
| FastDyn | Prepare the machine, load firmware and instrumentation, and supply configured device behavior |
| A physical model | Evolve its own state according to its integration and input policy |

Secondary execution does not replace peripheral models or move physics into the controller. In the shipped RLC example, firmware execution and the physical model share one QEMU process, with the model loaded through FastDyn's native plugin. The external Python program controls when that guest may advance.

There is no single `slave = true` switch. The configuration combines a QMP socket, a paused startup, and an instruction-counted clock. The controller then uses the budget commands supplied by the patched backend.

## Understand the clock and budget

The example uses:

```toml
[Machine]
qmp_socket = "/tmp/fastdyn-cosim.qmp"
stop_on_start = true
icount = { shift = 5, sleep = false, align = false }
```

These are selected fields from `configs/cosim_slave.toml`, not a complete machine configuration. FastDyn emits QEMU's `-S`, Unix QMP server, and `-icount` options. The paused start prevents firmware from running ahead while the controller connects.

The fixed `shift = 5` maps each counted instruction to 32 ns. This is a virtual-time policy, not a Cortex-M cycle-accurate timing model. Wall-clock duration measures the host's cost of executing the experiment; it is a different quantity. QEMU's instruction budgeting rounds to its instruction quantum, so the examples use representable intervals such as 500,000 ns and 20,000,000 ns. See the pinned backend's [icount conversion](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/accel/tcg/icount-common.c#L157-L160), [rounding](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/accel/tcg/icount-common.c#L226-L230), and [system-emulation contract](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/docs/devel/tcg-icount.rst).

The QMP interface has three budget operations:

| Command | Arguments | Meaning |
| --- | --- | --- |
| `run-for` | `{"budget": 20000000}` | Add nanoseconds to the maintained cumulative deadline and resume execution when budget remains |
| `query-budget` | None | Read `totalbudget`, `currenttime`, and `exact` without granting time |
| `set-budget-mode` | `{"exact": true}` | Select synchronous deadline stopping; `false` selects the default mode |

`totalbudget` and `currenttime` are unsigned 64-bit nanosecond values. The former is the backend's deadline; the latter is the virtual time reached. A `run-for` reply acknowledges the grant. **It does not mean the guest finished executing it.** The controller must wait for a `STOP` event and then query the budget. Events can arrive before a command's reply, which is why the shipped client buffers them.

In the default mode, the budget timer requests an asynchronous VM stop. Guest execution can continue before that request takes effect. In exact mode, the timer stops the VM synchronously on the main-loop path. Use the reported clock and deadline to check the result rather than treating the requested duration as an observation.

The deadline is cumulative. For example, after a 20 ms grant, a default-mode guest might report 20.1 ms reached against a 20 ms deadline. Adding another 20 ms normally targets 40 ms, leaving approximately 19.9 ms from the current position. The backend can also move its deadline forward when an exhaustion callback sees time already beyond it. Consequently, read back both fields; `totalbudget` is not an immutable accounting ledger of requested durations. These behaviors are implemented in the [budget patch](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/patches/qemu-fastdyn-plugin-icount.patch#L104-L163).

**Pinned-version detail:** the configuration contains `exact_budget_stop = true`, but at `e44dca2` the native call that applies that option is commented out. Use the controller's **`--exact`** or **`BudgetMaster(..., exact_stop=True)`**. Those paths actively send `set-budget-mode`; the configuration flag alone is insufficient at this revision. Compare the [native option handling](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/core/core.c#L1447-L1458) with the [client connection sequence](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/utils/fastdyn_cosim.py#L73-L92).

## Run the supplied RLC guest

Use a Linux x86-64 host for this fixture. Its FMU build packages an `x86_64-linux` native library, and its firmware targets the Cortex-M3. Install the general build dependencies from [Installation](../getting-started/installation.md), then add the firmware compiler and world runtime dependencies:

```bash
sudo apt-get install -y gcc-arm-none-eabi binutils-arm-none-eabi \
  libxml2-dev libminizip-dev
```

Create a checkout at this chapter's revision. All subsequent commands use its repository root as the working directory:

```bash
git clone https://github.com/boardrunner2049/FastDyn.git FastDyn-secondary
cd FastDyn-secondary
git checkout --detach e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576
source ./setup.sh --build-qemu --skip-optifuzz \
  --qemu-root third_party/common/qemu
```

Setup applies the complete ordered backend patch set and builds the matching plugin. Applying only the icount patch to stock QEMU does not satisfy this FastDyn revision's other required interfaces.

The optional `tools/world` submodule requires access to its PSecLab repository. Build it and the supplied firmware:

```bash
git submodule update --init --checkout tools/world
python3 -m venv tools/world/venv
tools/world/venv/bin/pip install -e tools/world
cmake -S tools/world -B tools/world/build -DWM_BUILD_TESTS=ON
cmake --build tools/world/build
tests/firmwares/world_rlc_gpio/build.sh

meson setup --reconfigure build
ninja -C build
export LD_LIBRARY_PATH="$PWD/tools/world/build:$PWD/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

The world build produces `tools/world/examples/rlc/out/RLC.fmu`. Reconfiguring FastDyn afterward matters: its world plugin is compiled only when Meson finds the world header and shared library. The reconfiguration preserves the existing feature options. The required library discovery and FMU packaging are established by [FastDyn's world build definition](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/virtuals/world/meson.build) and the [pinned world CMake project](https://github.com/PSecLab/world/blob/6ad41ba06a19e6a5151df1502f567837ba5d46d3/CMakeLists.txt).

In terminal 1, start the secondary:

```bash
fastdyn run -c configs/cosim_slave.toml -o out/cosim
```

In terminal 2, from the same checkout, run the controller:

```bash
source fastdyn-env/bin/activate
python utils/fastdyn_cosim.py /tmp/fastdyn-cosim.qmp \
  --exact --slice-ms 20 --slices 6
```

The expected behavior is a connection reporting exact-stop mode, followed by six rows with `paused` status and zero overshoot. Starting from time zero, the final reached time should be 120,000,000 ns. These are checks to make on your run, not measurements obtained while preparing this chapter. Firmware output should show the capacitor charging and discharging as its pin toggles.

The controller exits after its six grants. The continuously running firmware remains paused in terminal 1; stop that process with Ctrl-C when finished. Do not launch another fixture against the same `/tmp/fastdyn-cosim.qmp` socket or RAM file while it is active.

## Use the Python controller

`utils/fastdyn_cosim.py` uses Python's standard library and can also be imported. With a fresh instance waiting in terminal 1, this is a runnable alternative to the CLI controller when executed from the FastDyn root:

```python
from utils.fastdyn_cosim import BudgetMaster

with BudgetMaster("/tmp/fastdyn-cosim.qmp", exact_stop=True) as master:
    for _ in range(6):
        reached = master.run_slice(20_000_000)
        if reached != master.budget_ns:
            raise RuntimeError("guest did not stop at its reported deadline")
        print(master.budget_ns, reached, master.status)
```

| Interface | Contract |
| --- | --- |
| `BudgetMaster(socket, connect_timeout=15.0, slice_timeout=60.0, exact_stop=False)` | Configure the Unix-socket client; timeouts are host seconds |
| `connect()` / context manager entry | Connect, negotiate QMP, optionally request exact mode, and read initial budget state |
| `grant(duration_ns)` | Require a positive duration, acknowledge the grant, and return its cumulative deadline |
| `wait_for_slice()` | Wait for `STOP`, refresh state, and return actual virtual time |
| `run_slice(duration_ns)` | Perform a grant followed by a wait |
| `time_ns`, `budget_ns`, `exact_stop` | Cached state refreshed on connection and completed waits |
| `status` | Query the guest's current QMP run status |
| `close()` / context manager exit | Close the controller connection |

`grant()` does not immediately refresh the cached fields. Use its return value for the acknowledged deadline and `wait_for_slice()` for completion. Passing `exact_stop=False` leaves the backend's mode unchanged; it does not disable a mode another client already enabled.

Use one scheduling owner per guest. The client does not correlate a `STOP` event with a particular reason, so an unrelated debugger pause or manual QMP stop can interrupt the assumed budget sequence. It is a synchronous controller, not a concurrent command dispatcher.

## Coordinate two guests

The supplied lockstep helper launches multiple instances and grants each one a slice before waiting for any of them. After all have stopped, it prints their reached times and their spread:

```bash
python utils/cosim_lockstep.py --config configs/cosim_slave.toml \
  --instances 2 --exact --slice-ms 20 --slices 4 \
  --work-dir /tmp/fastdyn-lockstep-demo
```

Run this from the prepared checkout with its world-library environment. The helper uses `fastdyn-env/bin/fastdyn` directly. It derives separate QMP sockets, RAM files, configurations, work directories, and logs, then terminates the processes it launched on completion. Keep the work path short because these are Unix sockets.

Expect zero spread at each exact-mode boundary and final virtual times of 80,000,000 ns for fresh guests. Time agreement does not demonstrate communication: this example connects no UARTs, radios, or shared plant between its instances. Its configuration rewriting also expects exactly one `qmp_socket` and one `memory_file` line; it is a focused helper for this fixture, not a general resource-isolation engine. See [Multiple firmware instances](../simulation/multiple-firmwares.md) for campaign-level alternatives.

## Keep physics and exchange policy explicit

The RLC plugin advances its world **on pin access**. Before changing an output, it integrates to the current guest time under the previous input value, then applies the new value. Before an analog read, it integrates and samples the result. Its `step_ns = 100000` controls the world's integration/communication quantum, independently of the controller's 20 ms grants.

A budget pause does not itself call `wm_world_advance_to()`. The internal world's last evaluated time can therefore precede a QMP boundary until another pin access occurs. A controller should not infer that every model has reached `currenttime` merely because QEMU stopped there. The [world callbacks](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/virtuals/world/runtime/world_plugin.c#L309-L442) establish this policy.

For an experiment that already has an external transport or shared model, specify what happens between exchanges. A boundary-held input policy uses the values available at one boundary throughout the next interval, then publishes newly observed values at the following boundary. That policy introduces a delay of up to the exchange interval. It is an experiment-level choice, not behavior implemented by `BudgetMaster`.

Smaller grants increase the number of QMP exchanges and pauses. Smaller physical-model steps change numerical integration work and accuracy. Measure host elapsed time separately, and compare outputs across step sizes rather than assuming that a faster run or an exact clock boundary proves equivalent physics. The [World models](../simulation/world-models.md) chapter describes the pin adapter and its peripheral-fidelity boundary.

## Lifecycle and validation limits

The client reports `CosimError` for QMP failures, a closed connection, an observed shutdown during a slice, and a slice that never produces `STOP` before its timeout. Early firmware termination is not returned as a successful partial step. Closing the client does not stop a guest that is still running or reset the experiment.

There is no `reset()` or rollback operation in `BudgetMaster`. A new experiment should launch a fresh process and reinitialize the configured memory and physical state. The fixture's `reset_memory_files = true` applies during launch; it is not coordinated restoration of firmware, devices, and FMUs. Reconnecting to an existing process reads its existing clock and deadline rather than starting them at zero.

The demonstrated path is one Cortex-M3 guest per QEMU process. The QMP budgeting code is not an ARM register API, but that does not establish an architecture-wide validation matrix. This fixture's world pin adapter uses ARM register indices, and QEMU icount is a system-emulation feature incompatible with multi-threaded TCG. External live inputs also remain part of the experiment's reproducibility contract.

**Validation for this chapter:** implementation, configuration, and tests were inspected at the pinned revisions. The 11 `test_fastdyn_cosim.py` tests exercise a fake QMP server, including overshoot reporting, event ordering, exact-mode selection, shutdown, and timeout handling. Their local execution was attempted but blocked at Unix socket creation by the execution environment, before protocol assertions. No QEMU/FMU integration run or timing benchmark was executed for this chapter.

The repository also ships `run_cosim_slave_smoke.sh`. At this pin its exact-mode stage relies on the inactive configuration-only switch discussed above, so its presence is not evidence of a passing end-to-end test. The explicitly requested exact-mode workflows in this chapter avoid that configuration assumption.

## Source guide

- [Complete secondary configuration](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/configs/cosim_slave.toml), including the RLC endpoints and firmware pins
- [BudgetMaster and CLI implementation](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/utils/fastdyn_cosim.py), including event buffering and lifecycle behavior
- [Lockstep process controller](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/utils/cosim_lockstep.py), including resource rewriting and cleanup
- [QEMU budget overlay](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/patches/qemu-fastdyn-plugin-icount.patch) and [ordered backend build](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/scripts/setup/qemu.sh)
- [Protocol unit tests](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/unit/test_fastdyn_cosim.py) and [shipped integration smoke](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/integration/run_cosim_slave_smoke.sh)
- [Continuously running RLC firmware](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/firmwares/world_rlc_gpio/main.c) and its [Arm compiler recipe](https://github.com/boardrunner2049/FastDyn/blob/e44dca2edbc3b32cb1f2a48d3d0be203bd9b5576/tests/firmwares/world_rlc_gpio/build.sh)
