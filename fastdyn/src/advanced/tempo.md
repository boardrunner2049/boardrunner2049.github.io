# Tempo: schedule a federation

Tempo coordinates participants under one logical clock and controls when values cross their connections. Its native scheduler, federation compiler, typed ports, and trace buffer provide a concrete way to experiment with communication timing. Python and TOML describe the experiment; C executes it.

This chapter reviews Tempo at [`771b99650004fcbf3ab216970cf8fd9fae91aa6c`](https://github.com/boardrunner2049/tempo/tree/771b99650004fcbf3ab216970cf8fd9fae91aa6c). **The shipped participants are mocks. This source contains no working FastDyn or FMI adapter.** Names such as `firmware_a` and `world` in the examples identify roles in an experiment, not attached firmware or a physical simulator. The examples are useful for understanding and checking the scheduler's actual contracts.

## What Tempo owns

A *federation* is a set of participants, typed ports, and connections compiled into an execution plan. Tempo owns the federation's logical time, participant execution order, delivery queue, and synchronization points. Each participant owns its internal behavior and reports how far it advanced.

| Component | Responsibility |
| --- | --- |
| Python/TOML control plane | Declare participants and connections, request compilation, start runs, inspect plans and traces |
| Native federation compiler | Validate declarations and resolve names into participant, port, and route indices |
| Native scheduler | Choose deadlines, call participants, publish inputs, and manage same-time iteration |
| Participant implementation | Advance its own state, read input slots, write output slots, and report a stop reason |
| Trace infrastructure | Record execution and communication events without converting them to text in the execution loop |

Python calls the native library through CFFI. A call to `sim.run()` enters the native scheduler; it does not invoke Python for each participant step or routed value. The scheduler works with the public participant interface, without QEMU instructions, peripheral registers, or FMI semantics in its core.

## Build and run the supplied mocks

Use a C11 compiler, Python 3.11 or newer with virtual-environment support, Meson, Ninja, CFFI, and pytest. The following follows the repository's build path while selecting the reviewed revision explicitly:

```bash
git clone https://github.com/boardrunner2049/tempo.git
cd tempo
git checkout --detach 771b99650004fcbf3ab216970cf8fd9fae91aa6c
python3 -m venv .venv
source .venv/bin/activate
python -m pip install meson ninja cffi pytest
meson setup build --buildtype=debugoptimized
ninja -C build
meson test -C build --print-errorlogs
python -m pip install -e .
```

The native build produces `libtempo` and the trace-conversion tool. The editable Python installation supplies the `tempo` import and `tempo-run` command. If the Python loader cannot find a separately built library, `TEMPO_LIB` can name its full path. The Meson test setup includes Python tests only when its selected interpreter can import CFFI and pytest; check the test list rather than assuming a C-only success covered both layers.

Run these commands from the Tempo repository root:

```bash
tempo-run examples/two_firmware.toml --explain
tempo-run examples/two_firmware.toml --stats --trace run.trace
./build/tools/tempo-trace/tempo-trace info run.trace
./build/tools/tempo-trace/tempo-trace dump run.trace
python examples/motor_and_sensor.py
```

`--explain` compiles and prints the plan without running participants. The normal run reaches the configured `10ms`, prints scheduler counters, and saves a trace. The Python example also prints final values: command `0.350`, world output `1.120`, and observed value `1.120`.

Those values come from simple mock behavior. The first participant emits `0.70` at `3ms` and `0.35` at `7ms`. The world mock multiplies a changed input by `3.2`; the receiving mock copies it. Each connection declares `500us`. This is an algebraic echo experiment, not motor dynamics or a firmware flight test. Read the trace to see when the scheduler actually harvests and delivers each value; adding the two connection delays alone does not describe every participant's reaction time.

## Declare ports and connections

The supplied TOML separates `[simulation]`, `[scheduler]`, `[trace]`, `[[participants]]`, `[[connections]]`, and optional `[[subscriptions]]` tables. At this revision, `mock` is the registered participant type.

| Setting | Meaning |
| --- | --- |
| `[simulation].end_time` | Required positive logical end time |
| `[scheduler].policy` | `conservative`, the implemented scheduling policy |
| `[scheduler].quantum` | Maximum communication window before other constraints shorten it |
| `[scheduler].default_delay` | Delay for connections that omit one; otherwise follows the quantum |
| `[scheduler].max_microsteps` | Bound on same-time iteration and persistent lack of progress |
| `[trace].enabled`, `capacity` | Whether to allocate a trace buffer and how many records to retain |

Durations accept strings such as `"500us"`, `"3.5ms"`, or `"10s"`; bare numbers mean nanoseconds. A connection names an output and an input, for example:

```toml
[[connections]]
from = "firmware_a.motor_command"
to = "world.motor_command"
delay = "500us"
```

This fragment belongs to a federation that already declares those participants and ports. The compiler rejects missing endpoints, wrong directions, type mismatches, and multiple writers to one input. Unknown TOML keys also fail during setup, with a table or connection location in the diagnostic.

Ports support `bool`, `int64`, `float32`, `float64`, and `bytes`. A byte port declares a capacity, capped at 4096 bytes; a connection cannot route a wider declared sender into a narrower receiver. Participants access native slot arrays directly. Input slots have a `generation` counter that changes when the scheduler publishes a delivery, allowing inexpensive change detection.

Outputs are compared against shadow copies. Rewriting the same bytes normally creates no new delivery; a participant can increment the output generation to request a repeated value. Port names have become indices by this point, so ordinary routing does not search strings.

## Use the Python control plane

This complete example uses the same mock API and leaves the connection at its default delay, which equals the `1ms` quantum:

```python
from tempo import Mock, Simulation

sim = Simulation(end_time="10ms", quantum="1ms", trace=True)
source = sim.add(Mock(
    "source",
    script="3ms:emit_sync 0 0.70",
    outputs={"command": "float64"},
))
sink = sim.add(Mock(
    "sink", echo=True, gain=3.2,
    inputs={"command": "float64"},
    outputs={"response": "float64"},
))
sim.connect(source["command"], sink["command"])

with sim:
    print(sim.explain())
    sim.run("5ms")
    print(sim.now, sim.value("sink.response"))
    sim.run()
    print(sim.finished, sim.stats)
```

The intermediate logical time is `5000000` nanoseconds and the response is approximately `2.24`. The second `run()` continues to the federation's end; it does not restart it. The context manager releases the native participants, scheduler, plan, and trace.

Use `sim.step()` to execute one communication window. It returns whether more work remains. `sim.participant_time(name)` exposes individual progress, which can be ahead of `sim.now`; global time and every participant's current time are not interchangeable. Inspect `sim.plan.execution_order`, `routes`, `components`, and `cyclic_components` when a connection behaves differently from your expectation.

## Time, horizons, and early return

Logical time is an unsigned 64-bit nanosecond count. Same-time ordering uses a separate microstep, forming a tag `(time, microstep)`. A change from `(3000000, 0)` to `(3000000, 1)` advances event ordering without adding a fictitious nanosecond of physical time.

The native participant contract is `advance_to(target, result)`: execute without passing the target, then report `reached_time` and a stop reason. Returning before the target is valid. The scheduler rejects backwards time and overshoot; participants can report target reached, an externally relevant event, blocked execution, completion, or failure.

A window first delivers values due at the current communication point. It then computes a horizon from the quantum, run limit, earliest queued delivery, and advertised next-event predictions. Participants below that horizon advance in compiled order. Global time becomes the minimum live participant time, capped at the horizon.

**Timing boundary at this revision:** that horizon is computed before the participant loop. A new short-delay delivery created during the loop does not immediately shorten the deadline already used for the remaining participants. A recipient can therefore have advanced beyond a newly discovered delivery time. A focused public-API check during handbook validation reproduced this: with a `1ms` quantum, a source emitting at `250us`, and a `100us` connection delay, the recipient reached `1ms` before the `350us` delivery was processed.

Inspect recipient times and delivery traces around unexpected early returns. The default delay equal to the quantum avoids this particular within-window delivery case. Arbitrary short-delay or zero-delay experiments should not be treated as a general proof of conservative causality.

When a participant returns, Tempo harvests its output slots and dates changes at the reported reached time. A producer that returns as it writes provides a precise production boundary. A producer that continues running exposes its latest output only when the call ends; several intervening writes can be coalesced. A trace observation and a routed output are consequently different records with different purposes.

The mock makes this distinction directly testable:

| Script action | Behavior |
| --- | --- |
| `trap` | Return control without writing an output |
| `emit_sync 0 0.7` | Write output slot zero and return |
| `emit_observe 0 0.7` | Write the slot and continue executing the script |
| `mark 0 0.7` | Emit an observation without stopping |
| `finish` | Report that the participant has finished |

For example, `"3500us:trap"` produces an early return with a `1ms` quantum. Adding `predict=True` lets the scheduler select `3500us` as a horizon first, so the same stop is no longer early. `max_step` separately limits how far a mock advances per call. These options make timing behavior observable without attaching another simulator.

## Same-time propagation

Zero-delay routes use microsteps. At a communication point, Tempo publishes due inputs, notifies affected participants, and invokes eligible same-time reactions until no additional due delivery remains. Reactions require the participant to be at the current logical time; a participant already ahead is not rewound.

The destination of a zero-delay route must advertise `SAME_TIME_ITER`, and its source must advertise `EARLY_RETURN` or `PREDICT_NEXT`. An echo mock supplies same-time behavior. Setup rejects missing capabilities instead of discovering them halfway through execution.

The compiler keeps the full dependency graph and a separate graph containing only zero-delay connections. Strongly connected components of the latter determine a stable execution order, with participant IDs breaking ties. A delayed connection does not create a same-time cycle. `max_microsteps` bounds propagation, and a cycle that keeps changing values reports `TEMPO_ERR_NON_CONVERGENT` instead of iterating forever. The supplied `examples/same_time_chain.py` demonstrates this mechanism with mocks.

## Observe, reset, and compare

Tempo records fixed-size native events containing logical time, microstep, participant ID, type, flags, and sequence number. Observation records do not themselves stop a participant. Synchronizing behavior comes from the participant returning control; a trace flag describes that distinction.

With `trace=True`, Python requests 65,536 records. The default event selection includes scheduler decisions, port writes, and route deliveries. Explicit subscriptions narrow recording through the implemented type/namespace and participant masks; post-run filtering selects among records already collected. Address/argument predicates and subscription break requests are represented in configuration but are not enforced by the current execution path. Use the actual emitted records rather than assuming an address-specific subscription has filtered everything else.

The CLI warns when the ring drops records. Python exposes `sim.trace.dropped`; check it before treating a trace as complete. Save and convert outside the scheduling loop:

```bash
./build/tools/tempo-trace/tempo-trace dump --format=jsonl run.trace > run.jsonl
./build/tools/tempo-trace/tempo-trace dump --format=csv run.trace > run.csv
```

`sim.reset()` requires reset support from every participant. It resets participant progress, delivery state, slots, scheduler counters, and global time. It also emits a reset event. It **does not clear the trace buffer**, and `sim.trace.clear()` discards retained records without restarting sequence numbers or the cumulative dropped-record count. For repeat-run comparisons, save the first trace, reset, clear the buffer explicitly, and compare behavioral fields while accounting for sequence offsets. Record the starting dropped count and check its change during the run. Independent fresh runs can use fresh buffers for exact record comparison.

The repository's tests cover early return, prediction, delayed propagation, same-time chains and cycles, capability errors, deterministic mock runs, reset, configuration validation, and trace overflow. During handbook validation on x86-64 Linux with GCC 14.2.0 and Python 3.12.14, all six Meson test targets passed, including 51 Python cases. The README mock example and TOML run, plan inspection, and trace conversion also completed successfully.

Those results establish specific synthetic cases, not a blanket guarantee for every participant interaction. The implementation is single-threaded and exposes one scheduling policy. Its trace `cause` field is not automatically populated with complete causal parents by the scheduler, so chronological communication records alone are not a full data-provenance analysis.

## Source guide

- [Build prerequisites and current scope](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/README.md)
- [Complete three-participant mock configuration](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/examples/two_firmware.toml) and [Python experiment](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/examples/motor_and_sensor.py)
- [Native participant and capability contract](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/include/tempo/participant.h)
- [Federation validation and compiled routes](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/src/federation/compile.c)
- [Horizon, output harvesting, same-time iteration, and reset](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/src/scheduler/scheduler.c)
- [Python lifecycle and run API](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/python/tempo/simulation.py)
- [Trace filtering, storage, and clearing](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/src/trace/trace.c)
- [Native scheduler tests](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/tests/test_scheduler.c) and [Python behavior tests](https://github.com/boardrunner2049/tempo/blob/771b99650004fcbf3ab216970cf8fd9fae91aa6c/tests/test_python_api.py)
