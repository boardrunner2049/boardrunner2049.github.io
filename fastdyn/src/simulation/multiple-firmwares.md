# Multiple firmware instances

FastDyn provides two complementary ways to run several firmware instances. `fastdyn swarm` launches isolated workers for parallel experiments. The co-simulation utilities let an external master grant virtual time to individual guests and synchronize their observation boundaries. Together, these give experiments a path from independent repetitions to explicitly coordinated systems.

Choose the mechanism according to the experiment:

| Goal | Starting mechanism | What you supply |
| --- | --- | --- |
| Repeat a mission or fuzzing workload concurrently | `fastdyn swarm` | Configured workload, parameters, inputs, and result analysis |
| Advance a guest in controlled virtual-time slices | `BudgetMaster` or `fastdyn_cosim.py` | Slice schedule and any external model |
| Keep several guests at common boundaries | `cosim_lockstep.py` | Base slave configuration and time quantum |
| Model communicating devices or firmware sharing a plant | A master plus explicit device/transport connections | Communication semantics, exchange policy, and shared state ownership |

The existing lockstep example synchronizes time. It does not automatically connect UARTs, radios, buses, or actuators between its guests.

## Launch an isolated campaign

After preparing the selected firmware and FMU, inspect a worker plan without launching QEMU:

```bash
fastdyn swarm -c configs/copter462.toml -n 2 \
  -o out/swarm/copter --base-port 15000 --dry-run
```

Remove `--dry-run` to launch it:

```bash
fastdyn swarm -c configs/copter462.toml -n 2 \
  -o out/swarm/copter --base-port 15000
```

The supervisor assigns separate work directories, QMP sockets, RAM backing files, logs, and standard service ports. With the default stride of 20, worker 0's MAVCesium address is `http://127.0.0.1:15003/mavcesium/`, and worker 1's is `http://127.0.0.1:15023/mavcesium/`. Logs appear in `out/swarm/copter/logs/worker-000.log`, `worker-001.log`, and so forth.

The port assignment for worker index `i` starts at `base_port + i * port_stride`:

| Offset | Service |
| --- | --- |
| `+0` | QEMU monitor |
| `+1`, `+2` | Firmware and GCS MAVLink endpoints |
| `+3` | MAVCesium |
| `+4`, `+5` | Optional Rumoca HTTP and WebSocket endpoints |
| `+6` | GDB |

The supervisor checks those ports before launch. A custom helper or device model must likewise avoid hardcoded shared files and endpoints. Standard worker isolation does not automatically rewrite every resource created by application-specific code.

## Drive one guest as a slave

The shipped slave example uses the RLC world model, so complete [World models](world-models.md) first. Its key machine settings are:

```toml
[Machine]
qmp_socket = "/tmp/fastdyn-cosim.qmp"
stop_on_start = true
icount = { shift = 5, sleep = false, align = false }
exact_budget_stop = true
```

Start the guest and its master in separate terminals:

```bash
# Terminal 1
fastdyn run -c configs/cosim_slave.toml -o out/cosim

# Terminal 2
python3 utils/fastdyn_cosim.py /tmp/fastdyn-cosim.qmp --slice-ms 20 --slices 6
```

The guest starts paused. The master grants slices and reports the virtual time actually reached. A pending slice is asynchronous: the immediate response to `run-for` is an acknowledgment of the grant, not evidence that execution has finished.

## Respect the budget protocol

The patched QEMU provides three relevant commands:

| QMP command | Meaning |
| --- | --- |
| `run-for` with `budget` in nanoseconds | Add a positive duration to the cumulative execution deadline and resume |
| `query-budget` | Read `totalbudget`, actual `currenttime`, and whether exact mode is enabled |
| `set-budget-mode` with `exact` | Select the stopping mode for the current run |

The master waits for the `STOP` event after each grant, then queries the budget. If a guest terminates instead, the master must handle shutdown rather than waiting indefinitely for a pause.

In the default stopping mode, the guest can stop beyond the deadline. The cumulative budget still tracks the granted time, but the observation instant can differ from that budget. `exact_budget_stop = true`, or the CLI's `--exact`, selects synchronous stopping at the virtual-time deadline. This is a synchronization property of the emulator, not a hardware-cycle accuracy guarantee.

For a custom Python master, this is runnable from the repository root while the guest above is waiting:

```bash
PYTHONPATH=utils python3 - <<'PY'
from fastdyn_cosim import BudgetMaster

with BudgetMaster("/tmp/fastdyn-cosim.qmp", exact_stop=True) as guest:
    for _ in range(10):
        reached_ns = guest.run_slice(1_000_000)
        print(reached_ns, guest.budget_ns, guest.status)
PY
```

The client also separates `grant()` from `wait_for_slice()`, allowing a master to grant every participant before waiting for any of them.

## Synchronize several guests

The supplied example derives unique QMP sockets, RAM files, and output directories from its base slave configuration:

```bash
python3 utils/cosim_lockstep.py \
  --instances 2 --slice-ms 0.5 --slices 40 --exact \
  --work-dir out/lockstep
```

It launches through the standard `fastdyn-env/bin/fastdyn` installation, grants each guest the same interval, waits for every guest to stop, and reports their time spread. In exact mode, the expected outcome is agreement at the boundaries. The utility is an example for the supplied single-RAM-file configuration; its config rewriting is not a general scheduler for arbitrary machine layouts.

To create a coupled experiment, add the exchange logic at that barrier: collect outputs, apply the shared physical or communication model, and publish the next inputs before granting more time. Define whether messages produced during an interval become visible immediately or only at the next boundary, who owns the shared state, and how faults or a terminated participant affect the run. Those choices determine the experiment's causality.

The budget interface is monotonic and does not provide rewind. Likewise, restoring guest memory alone does not restore an external plant or message queue. Preserve the full state needed by the experiment or restart its participants consistently between trials.

## Verify the chosen property

Use `tests/integration/courbet_swarm_smoke.sh` to exercise parallel vehicle launches and `tests/integration/run_cosim_slave_smoke.sh` to exercise budget stops and lockstep after their prerequisites are built. A successful swarm check establishes launch isolation; a successful budget check establishes synchronization. Communication correctness and physical fidelity require checks for the connections and models you add.

## Source guide

- [Worker planning, ports, and supervision](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/swarm.py)
- [BudgetMaster and single-guest CLI](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/utils/fastdyn_cosim.py)
- [Multi-guest barrier example](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/utils/cosim_lockstep.py)
- [Slave-mode configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/cosim_slave.toml)
- [QEMU budget implementation patch](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/patches/qemu-fastdyn-plugin-icount.patch)
- [Exact-stop and lockstep integration checks](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/integration/run_cosim_slave_smoke.sh)
