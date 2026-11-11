# Fuzzing firmware and physical behavior

FastDyn lets a fuzzing campaign choose the execution boundary that matters: a parser, a persistent task loop, a device input path, or an entire vehicle mission. Execution controls, input injection, coverage, snapshots, and the physics backend supply different parts of that experiment.

The current tree contains two main workflows. Native LibAFL/AFLNet integration drives repeated firmware input processing. OptiFuzz/CP-Explore mutates parameters and evaluates mission behavior through the ArduPilot and FMU path. They use different execution boundaries and feedback; select one according to the property being investigated.

## Choose a campaign boundary

| Workflow | Input and boundary | Main feedback |
| --- | --- | --- |
| Firmware loop or handler | Registers, memory, streams, and modeled device inputs around chosen PCs | Coverage, configured assertions, crashes, timeouts |
| Stateful protocol | Sequences of messages through an AFLNet-compatible target harness | Protocol feedback and firmware execution outcomes |
| Vehicle mission | Parameter mutations applied through mission helpers to firmware plus a plant | Physical traces, temporal properties, mission outcomes, optional coverage |

A useful harness begins after the required initialization and ends after one meaningful input has been processed. That avoids repeatedly paying for unrelated boot work while retaining the state required by the selected behavior.

## Task-loop fuzzing, including the chaos direction

Embedded tasks often run forever. FastDyn's existing virtuals and modifiers can select an iteration boundary, redirect execution, arrange inputs, and return to a repeatable point. The native fuzzer supplies snapshot and synchronization callbacks; the schema layer can install those callbacks from JSON.

For a task or loop, the practical workflow is:

1. Establish a working execution path to the relevant code.
2. Identify the state it needs, including globals, stack, queue state, and peripheral inputs.
3. Choose snapshot and completion PCs, with all normal exits covered.
4. Inject the inputs that the loop consumes, then collect outcomes after one iteration.
5. Replay interesting inputs and check whether the resulting state is feasible for the real system.

This implements the execution machinery behind the task-centric approach described in `docs/chaos.md`. Automatically discovering every task, deriving its complete dependencies, and isolating arbitrary firmware loops is a broader design goal, not an established universal capability. Binary loop and MMIO analyses can provide evidence; they do not remove the need to validate the harness.

Coverage PCs are logged from translated code into a circular buffer and drained by a tracer thread. That keeps the event producer in the translated path and supports an in-process LibAFL consumer. The current buffer and synchronization implementation should not be described as a proven lossless logger for arbitrary producer rates. Coverage identifies execution progress; it is not by itself a complete record of every instruction or scheduling event.

## Build the native input backend

After the basic source setup, use a plugin built with the appropriate backend. LibAFL requires Rust/Cargo:

```bash
make DEV=true LIBFUZZ=true
```

`make` recreates the build directory, so include the other required feature flags if this same plugin must retain physics or hardware support. `AFLNET=true` selects the modified AFLNet integration and requires the corresponding external build at `aflnet_path`. Do not enable both input backends in one build without first resolving their shared backend interface.

Enable a schema-driven LibAFL campaign in the target's existing machine table:

```toml
[Machine]
fuzzing = true
coverage = true
fuzzing_schema = "schema.json"
```

`coverage = true` alone is observation mode: `fuzzing = false` avoids starting the input backend. The plugin must still include the coverage implementation needed by that experiment. The default basic build does not include the LibAFL coverage writer.

## Describe structured inputs in JSON

The following is a **schematic ARM32 harness**, not a runnable profile for the bundled firmware. Replace all PCs and the destination with locations verified in your target:

```json
{
  "flow": {
    "snap": { "at": "0x08002000" },
    "sync": [
      { "at": "0x08002080", "resume": "0x08002000" }
    ]
  },
  "fields": [
    {
      "name": "mode",
      "location": "reg(0)",
      "type": "uint",
      "size": 1
    },
    {
      "name": "payload",
      "location": "0x20001000",
      "type": "data",
      "size": 16
    }
  ]
}
```

`flow.snap` establishes the per-input boundary. Each entry in the nonempty `flow.sync` array ends an iteration and supplies the resume PC. An optional `flow.state` provides a longer-lived initialization snapshot. Direct fields are injected at the snapshot unless assigned to a hook.

The schema has four top-level sections: `flow`, `fields`, `streams`, and `hooks`. Its loader rejects unknown or duplicate properties and inconsistent references. `reg(N)` is the register-destination form. A location such as `r2 + 4` is a memory address computed from register 2. Ordinary pointer dereferences are little-endian 32-bit reads in the current implementation.

Fields support integer, float, and raw data types, constants, numeric ranges, and selected integer values. Computed `length` and `checksum` fields preserve message structure. Streams deliver a sequence incrementally, such as bytes returned by a UART function; hooks select where those bytes are injected. A `checksum` can cover previously emitted stream bytes, so protocol order matters.

The current register and snapshot machinery includes ARM32 and Cortex-M assumptions. Validate support before applying this harness to another architecture. A snapshot also needs the relevant mutable state: restoring selected guest memory does not automatically rewind every external service, physical board, or arbitrary device-model state.

## Run a mission-level campaign

For the maintained FMU workflow, from the FastDyn repository root:

```bash
source ./setup.sh --build-qemu --with-rumoca
cd virtuals/fuzzer/libafl_phi
FASTDYN_OPTIFUZZ_SMOKE=1 FASTDYN_OPTIFUZZ_DRY_RUN=1 \
  cargo run --bin baby_fuzzer
```

The dry run checks command wiring without launching QEMU. It still requires the Rust dependencies. To run the default copter campaign from that crate directory:

```bash
cargo run --bin baby_fuzzer
```

The default backend is `fmuv3` and the default configuration is `configs/copter462.toml`. Per-execution artifacts go under `out/optifuzz/execution-<n>` in the FastDyn work tree. Mission helpers receive the mutation file through `FASTDYN_OPTIFUZZ_MUTATION_BIN` and apply the named parameters. Physical-property handling lives in the crate's observer code and `stl_formulas.txt`.

Select another vehicle using `FASTDYN_OPTIFUZZ_VEHICLE` and `FASTDYN_OPTIFUZZ_CONFIG`. `FASTDYN_OPTIFUZZ_SWARM_INSTANCES=2` or greater launches isolated workers through `fastdyn swarm`. This scales campaigns; it does not connect the vehicles into one physical world. Enable `FASTDYN_OPTIFUZZ_COVERAGE=1` only with a compatible coverage-enabled plugin.

## Interpret a finding

Retain the exact firmware, configuration, schema, model versions, input, and property definition. First replay the failure under the same harness. Then minimize the input and determine whether the state or event sequence is reachable under the intended device, protocol, and physics constraints. Direct register or memory mutation can expose a real bug while also allowing states that a deployed device could never produce.

A mission-property violation and a memory-safety crash are different results. Report the violated property, observed trace, and reproduction boundary rather than treating every negative robustness score as a firmware crash.

## Source guide

- [Native fuzzing lifecycle and snapshots](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/fuzz.c)
- [Schema reference and implemented grammar](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/schema/README.md)
- [Coverage producer and tracer](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/core/core.c)
- [Fuzzer build selection](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/meson.build)
- [Task-centric motivation and design discussion](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/chaos.md)
- [OptiFuzz/CP-Explore usage](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/fuzzer/libafl_phi/README.md)
