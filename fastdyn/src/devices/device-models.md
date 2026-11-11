# Device models

FastDyn lets you choose a peripheral implementation independently of the firmware image. A UART can be served by a native C model, another peripheral can remain attached to real hardware, and a recorded interaction can be replayed later. The configuration names the address ranges, interrupts, and handler used for each device. The firmware continues to issue its normal loads and stores.

This is useful during incremental rehosting. You can replace one hardware dependency at a time, retain the rest of a working environment, and reuse the resulting model across firmware that targets the same peripheral. A register model belongs to the device; a hook at a firmware function belongs to that firmware's execution configuration.

## Choose a handler

| Handler | What the current implementation does | Use it for |
| --- | --- | --- |
| `elder` | Loads a C shared library exporting the versioned `fastdyn_model` descriptor; creates a separate state object for each configured device | Reusable, stateful peripheral models |
| `passthrough` | Forwards reads and writes through a libhw probe session and coordinates interrupts with the board | Keeping a physical peripheral in a rehosted execution |
| `twintrace` | Records hardware-backed interactions or replays a prepared MMIO/interrupt tape | Reproducing a recorded interaction and comparing model behavior |
| `classic` | Provides a built-in callback implementation whose current reads return zero and writes do nothing | A permissive bring-up stub or a starting point for a built-in handler |

`elder` is the normal extension point for new models. Its library can be hand-written or produced by a model-generation workflow. FastDyn loads the same ABI in either case. BoardRunner's learning and verification workflow is a separate producer of these libraries.

The `classic` label describes the callback route, not a catalog of complete peripherals. Do not select it expecting a UART, timer, or DMA controller to acquire realistic behavior automatically.

## Describe one device

The following is a **device-table fragment** to add to an otherwise complete machine configuration after building the referenced model:

```toml
[Device.Models.elder]

[Device.usart2]
ranges = [["0x40004400", "0x400047FF"]]
irq = ["USART2"]
pty = "usart2"

[[Device.usart2.handlers]]
model = "elder"
enabled = true
scroll = "build/models/stm32_usart.so"
```

Address-range ends are inclusive. A handler receives the absolute address, access width, and guest program counter. The model converts the address to an offset relative to the relevant range. Device-specific settings such as `pty` become the model's JSON configuration; FastDyn removes its own routing fields before calling the model.

Named IRQs require the selected platform's interrupt map. On Cortex-M, numeric entries are exception numbers, so an external interrupt numbered `IRQn` is represented as `IRQn + 16`. This is an architecture-specific convention, not a rule to transplant to another interrupt controller. Lists can contain individual numbers, names, or two-element ranges. The former string syntax such as `"0-20:21-25"` is rejected.

## What happens on an access

The patched QEMU exposes an I/O interception interface to FastDyn. The dispatcher associates the address with a configured handler, invokes its read or write callback, and notifies registered MMIO observers. An elder handler then selects the device instance and invokes that instance's model callback. Reads return a value to the emulated execution; writes update model state or trigger the model's chosen effects.

The dispatcher also receives interrupt-entry and interrupt-return notifications. Elder forwards those notifications only to instances whose configured IRQ list contains the interrupt. These callbacks observe servicing; a model that needs to assert an interrupt must explicitly use the supported QEMU interrupt API.

Current dispatch supports dynamic 64-bit ranges and a handler-name route for generic PCIe devices, in addition to the legacy address-region lookup tables. That is broader than a single Cortex-M memory map. Individual model implementations and IRQ mechanisms still need to match the selected target.

## Compose devices with explicit ownership

Prefer one enabled owner for each MMIO range. In the current dynamic-range path, matching is first-match and registration prepends entries. Overlapping ranges therefore depend on registration order; a configuration is not a general priority-controlled fallback chain. A `read_priority` field should not be treated as a portable composition contract.

For mixed hardware and software experiments, partition the peripherals or address regions deliberately. The parser rejects a device that enables both `passthrough` and `twintrace`, because both are hardware-capable handlers. The same principle applies to FIFOs, clear-on-write registers, and other operations that must happen once.

FastDyn retains useful boundaries for extension:

| Concern | Owner |
| --- | --- |
| Firmware instruction execution | QEMU and the FastDyn runtime |
| Address-to-device selection | FastDyn device dispatcher |
| Register semantics and peripheral state | The selected model |
| Reusable buses, DMA, signals, and host I/O helpers | LibVIO, when used by the model |
| Physical transfer functions and plant state | The connected physics model |

This separation lets a new peripheral library improve many firmware experiments without introducing firmware-specific logic into the central dispatcher.

## Continue

Build an elder library in [Writing a device model](writing-a-model.md), or connect a board and record a trace in [Hardware and trace replay](hardware-and-traces.md). For selected access sites, [inline device modeling](../advanced/inline-device-modeling.md) explains the specialized translation path, its current backing-state limitations, and the checks needed before replacing an ordinary device access.

## Source guide

- [Public model ABI](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn/device_model.h)
- [MMIO and IRQ dispatch](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/dev.c)
- [Elder library loader](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/elder/elder.c)
- [Classic implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/classic/classic.c)
- [Configuration parsing and handler validation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/toml_parser.py)
