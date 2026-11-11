# Hardware and trace replay

FastDyn supports a practical progression from a board-dependent experiment to a reusable software model: execute firmware in QEMU, forward selected peripheral accesses to hardware, capture the resulting interaction, and replay it without asking the physical device for every response. A learned or hand-written elder model can then replace that peripheral while the rest of the experiment remains recognizable.

Two handlers implement the hardware and recording paths. `passthrough` forwards accesses through libhw. `twintrace` uses the same hardware mechanism for recording and a binary event tape for replay. Both share a process-level probe-session implementation, which centralizes probe ownership and interrupt coordination.

## Prepare the hardware path

Build libhw with the normal setup command:

```bash
source ./setup.sh --build-qemu --build-libhw
```

A live run also needs a compatible board, debug probe, libhw backend, board-side monitor arrangement, and a firmware/configuration pair prepared for that target. The mere presence of a probe is not sufficient to make an arbitrary board a passthrough backend.

This is a **routing fragment**, to merge with that complete configuration:

```toml
[Device.Models.passthrough]
backend = "stlink"

[Device.physical_uart]
ranges = [["0x40004400", "0x400047FF"]]
irq = [54]

[[Device.physical_uart.handlers]]
model = "passthrough"
enabled = true
```

The interrupt value is a Cortex-M example: USART2's external IRQ 38 corresponds to exception 54 on the relevant STM32 target. Replace the address and IRQ with the actual peripheral description for your platform.

The current shared hardware session supports 1-byte and 4-byte transfers. It handles temporary halted-board conditions with a bounded retry loop, and resumes the board when its captured interrupt is served. Passthrough's current initialization registers IRQs from its first configured device only. Keep that constraint visible when constructing a multi-peripheral hardware configuration; do not assume all listed device interrupts are forwarded.

## Record a tape

Change the selected device handler to `twintrace`, declare its backend, and set the existing CPU entry's recording mode:

```toml
# In the existing [[CPU.cpu0]] entry:
twintrace = "record"

# In the device section:
[Device.Models.twintrace]
backend = "stlink"

[Device.physical_uart]
ranges = [["0x40004400", "0x400047FF"]]
irq = [54]

[[Device.physical_uart.handlers]]
model = "twintrace"
enabled = true
```

This is a configuration edit, not a second CPU declaration. Disable the old passthrough handler on that same device. FastDyn rejects a configuration that enables both hardware-capable handlers for one device.

Recording writes MMIO information and interrupt notifications through FastDyn's I/O log. Retain the resulting `io.log` with the exact firmware image, configuration, model routing, and execution inputs. The event format carries instruction counts, program counters, addresses, values, sizes, and event types. Those fields make later divergence diagnosable.

## Replay without the board

In the existing CPU entry, select replay and point at the captured text trace:

```toml
twintrace = "replay"
hardware_trace = "captures/reference/io.log"
```

Keep `twintrace` enabled for the devices replay should serve. During run preparation, the launcher converts the text trace into `<work-dir>/replay_bin.ttbin`, verifies it, and passes it to the native replay handler. Replay is available even when FastDyn was built without libhw. A run that still routes other devices through `passthrough` continues to require hardware for those devices.

FastDyn supports two useful arrangements:

| Arrangement | Routing | Tape preparation |
| --- | --- | --- |
| All-trace replay | The recorded peripheral interaction is served by twintrace; no passthrough handler remains enabled | Convert the full recorded event stream |
| Target-only replay | Selected devices use twintrace while others retain passthrough | Filter by the replay devices' address ranges and IRQs |

Filtering follows the current routing, rather than trusting a record-time handler label. That lets a trace captured under one arrangement support a later experiment that isolates a particular peripheral.

## Interpret a replay failure

The replay handler consumes an ordered stream. It checks event type, address, access width, and write value under its current defaults; strict PC checking is disabled. Interrupt-taken and interrupt-served events are also checked. Cortex-M SysTick, exception 15, is excluded from this tape path.

On divergence, the diagnostic prints the current record index, expected event, and observed access. Start with the first mismatch. A changed firmware binary, a different initialization path, or an incorrect peripheral range can explain a mismatch long before the final visible failure.

A trace describes a recorded behavior. It does not generalize to every input sequence or every possible hardware state. Use replay for reproduction and controlled comparisons, then use a stateful elder model when the experiment needs behavior beyond the captured path. Instruction-count alignment helps coordinate the trace, but it does not establish cycle accuracy against the physical MCU.

## Source guide

- [Shared hardware-session contract](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/common/hw_session.h)
- [Passthrough implementation and IRQ scope](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/passthrough/passthrough.c)
- [Native replay checks and recording path](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/twintrace/twintrace.c)
- [Replay preparation and target-only filtering](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
- [Trace conversion and format](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/utils/twintrace.py)
