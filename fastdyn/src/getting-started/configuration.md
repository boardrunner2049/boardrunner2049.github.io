# Configure a firmware

A FastDyn TOML file is the experiment's executable description. It identifies the guest CPU and firmware, maps memory, routes peripheral accesses, and selects the instrumentation and optional physics required by the experiment. Start from a working profile close to your target, then make the assumptions explicit.

The full key reference is in [configuration reference](../reference/configuration.md). This chapter explains the decisions in the order a new target usually needs them.

## Start from the ELF or the starter

For an ELF with usable metadata, generate a draft:

```bash
./fastdyn-env/bin/python tools/elf2config/elf_to_config.py build/my_firmware.elf \
  --output configs/my_firmware.toml
```

Replace `build/my_firmware.elf` with your actual image. The tool extracts architecture, entry point, loadable writable ranges, and available Cortex-M, MCU, or RTOS hints. It produces a starting configuration for review. An ELF alone does not establish the complete board memory map or the behavior of its peripherals.

Alternatively, copy the small starter:

```bash
cp configs/bare_bones.toml my_firmware.toml
```

The starter intentionally names `firmware.elf` as a placeholder. Update it before launching.

Use the built-in discovery commands while editing:

```bash
fastdyn help platforms
fastdyn help machine
fastdyn help memory
fastdyn help firmware
fastdyn help device-models
fastdyn help plugins
```

On an interactive terminal, these commands offer choices and emit TOML fragments. `--no-browse` requests plain output. The SVD platform browser needs the catalog initialized by setup.

## Describe the machine and CPU separately

`[Machine]` contains run-wide controls. `[[CPU.cpu0]]` selects the QEMU architecture, machine model, CPU model, firmware, and native FastDyn plugin. For example, this fragment describes a Cortex-M target; it is not a complete runnable configuration:

```toml
[Machine]
platform = "STM32F429"
display = "none"
monitor_port = 0
log_options = "none"

[[CPU.cpu0]]
arch = "arm"
machine = "cortexm"
cpu = "cortex-m4"
binary = "firmware.elf"
init_nsvtor = "0x08000000"
```

The CPU model must match the ISA and optional features used by the image. `init_nsvtor` is a Cortex-M vector-table setting; it is not a portable entry-point option for RISC-V or x86. Use the corresponding shipped architecture configuration as the starting point for those targets.

The SVD `platform` supplies peripheral and interrupt metadata. It does not generate a functioning peripheral implementation. `generic-cortexm` permits a Cortex-M experiment without an exact SVD match.

A single QEMU run can contain homogeneous CPUs, meaning the same architecture, CPU model, machine model, and firmware. Different firmware images belong in separate instances with explicit coordination, as covered in [multiple firmwares](../simulation/multiple-firmwares.md).

## Map memory from evidence

Define `[Memory.main]` first. Additional banks use array-table syntax such as `[[Memory.ram1]]`:

```toml
[Memory.main]
id = "ram0"
base_address = "0x20000000"
memory_size = "256K"
backend = "file"
share = true
```

This fragment lets FastDyn place the backing file inside the run directory. Use the target's actual map when validating memory behavior. Oversized RAM can conceal invalid accesses or missing memory regions.

`backend` may be `file`, `ram`, or `memfd`. File-backed memory can be inspected by host tools. Reusing an external RAM file can retain data between runs; select `[Machine].reset_memory_files = true` when the experiment requires it to be cleared before launch.

The generic Cortex-M machine supports additional RAM mapping properties. Other QEMU board models own their address layout, so creating a backend object alone does not give every board arbitrary remapping.

## Route peripheral accesses

A device model registration names an available handler. A device table assigns address ranges and enables handlers for them:

```toml
[Device.Models.classic]

[Device.peripheral_window]
ranges = [["0x40000000", "0x5fffffff"]]
description = "Initial peripheral routing for this target."

[[Device.peripheral_window.handlers]]
model = "classic"
enabled = true
```

This is a configuration example, not a complete hardware model. Replace broad fallback routing with the models required by the firmware's behavior. If different regions require different models, give them separate device tables. A run with no peripheral handling can omit `[Device]` entirely.

For Cortex-M interrupts, numeric values are CPU exception numbers, so a device IRQ number has the architectural exception offset added. SVD interrupt names can be resolved for you. The reference explains the accepted list syntax and model-specific options.

## Add only the instrumentation you need

Use a virtual for a named runtime action, a modifier for a guest state update at a PC, or a run-wide plugin for generated instrumentation. Plugin settings live under the CPU:

```toml
[CPU.cpu0.plugins.variable_watch]
enabled = true
variable = "motor_state.temperature"
access = "write"
```

This illustrative watch requires that variable to exist and be resolvable in your firmware. Each plugin defines its own prerequisites. Start with one observable result, such as an entry count or a known variable write, before combining multiple analyses.

## Keep paths and run records predictable

Firmware, hardware-trace, model-library, and Python endpoint paths are checked relative to the configuration directory first. If the referenced file is absent there, the existing current-directory behavior remains. External plugin `source` paths are always resolved against the configuration directory. Helper working directories and FMU source paths use repository-root rules. These are different interfaces; do not assume every TOML string shares one path resolver.

Run from the repository root while bringing up a new profile:

```bash
fastdyn run -c configs/my_firmware.toml -o out/my-firmware-bringup
```

Inspect the generated rules, native logs, and first useful guest behavior. The initial success criterion should be concrete: reaching a known function, servicing one device transaction, advancing both RTOS tasks, or producing a valid sensor update. Reaching the entry point alone does not validate the whole board model.

## Source guide

- [ELF-to-configuration utility](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tools/elf2config/README.md)
- [Bare-bones starter](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/bare_bones.toml)
- [TOML parser and path rules](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/toml_parser.py)
- [QEMU machine and memory construction](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/targets/qemu_target.py)
- [Feature discovery implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/feature_browser.py)
