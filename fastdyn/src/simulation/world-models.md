# World models

The `world` plugin connects firmware-visible actions to FMI 3 physical models. A firmware function can drive a physical input, another can sample a physical output, and FastDyn advances the model to the guest's current time before either action. The bundled example connects a GPIO-like output to an RLC circuit and returns capacitor voltage through an analog-input hook.

The model supplies physical behavior. FastDyn supplies the bridge to guest execution. This provides a small, concrete way to study how firmware responds to a changing environment before building an entire vehicle experiment.

## Build the optional runtime

The plugin uses the `tools/world` submodule, which is optional and requires access to its repository. Its native component is included only when Meson finds both the world header and `tools/world/build/libworld_model.so`. A configuration can be parsed even when the native component was omitted, so build order matters.

After the normal FastDyn installation, run from the repository root. The firmware build also requires the Arm bare-metal compiler `arm-none-eabi-gcc`:

```bash
git submodule update --init --checkout tools/world
python3 -m venv tools/world/venv
tools/world/venv/bin/pip install -e tools/world
cmake -S tools/world -B tools/world/build -DWM_BUILD_TESTS=ON
cmake --build tools/world/build
cmake --build tools/world/build --target rlc_fmu
tests/firmwares/world_rlc_gpio/build.sh
```

Reconfigure the existing FastDyn build after the world library exists, preserving the options selected during your original setup:

```bash
meson setup --reconfigure build
ninja -C build
export LD_LIBRARY_PATH="$PWD/tools/world/build:$PWD/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fastdyn run -c configs/world_rlc_gpio.toml -o out/world-rlc
```

The firmware prints capacitor-voltage samples while it alternates the input level. Expect charging while the pin is high and discharging while it is low. It runs continuously; stop it with Ctrl-C. The trace and runtime log are under `out/world-rlc/run-artifacts/world/`.

## Connect a physical endpoint

The existing example declares one FMU and gives its variables stable local names:

```toml
[CPU.cpu0.plugins.world]
enabled = true
step_ns = 100000

[CPU.cpu0.plugins.world.models.rlc]
path = "tools/world/examples/rlc/out/RLC.fmu"

[CPU.cpu0.plugins.world.models.rlc.parameters]
resistance = 10.0
inductance = 0.01
capacitance = 0.001

[CPU.cpu0.plugins.world.endpoints]
supply = { target = "rlc.voltage", direction = "in" }
vcap = { target = "rlc.output_voltage", direction = "out" }
```

FMU paths in this plugin resolve against the working directory. Running from the FastDyn root keeps the supplied paths valid. Endpoint targets use `<model>.<variable>`, where the variable belongs to the FMU's metadata.

The pin rules bind those endpoints to firmware functions:

```toml
[[CPU.cpu0.plugins.world.pins]]
at = "world_gpio_write"
kind = "digital_out"
endpoint = "supply"
register = "r0"
low = 0.0
high = 3.3

[[CPU.cpu0.plugins.world.pins]]
at = "world_adc_read"
kind = "analog_in"
endpoint = "vcap"
register = "r0"
scale = 1000.0
```

A digital output maps zero and nonzero register values to the configured physical levels. An analog input multiplies the physical output by `scale` and writes an integer to the guest register. Here, volts become millivolts. Choose a range and scale representable by the 32-bit register conversion; this is not a floating-point guest-return interface.

The supplied firmware exposes short stub functions so the hook's register effects survive the return. When adapting a real function, inspect its calling convention and remaining instructions. A later instruction that overwrites the register will overwrite the injected result too.

## Preparation and execution

The Python preprocessor validates model, endpoint, and pin tables; resolves named triggers through the shared ELF analysis; and rejects conflicting pin addresses. It emits `world.manifest` plus ordinary FastDyn virtual rules. The native plugin constructs the world, resolves endpoint handles once, and registers `world_digital_out` and `world_analog_in` callbacks.

This uses FastDyn's regular extension mechanism. Model-specific parsing stays in the plugin, while the core handles virtual dispatch and artifact delivery. Multiple FMUs can be declared in the same world, with model connections passed to the world runtime. Their physical composition remains separate from connecting multiple firmware instances.

## Advance on access

Before a pin callback reads or changes an endpoint, it advances the world to `virtual_guest_time_ns`. Repeated accesses at the same guest timestamp do no additional integration work. For an output change, the elapsed interval is integrated under the previous value, then the new value takes effect.

`step_ns` controls the world's communication quantum. The numerical consequence depends on the FMU: the bundled RLC implementation performs an integration step at that scale, while another FMU may substep internally. Check convergence when changing the quantum; a visually plausible waveform can still contain integration error.

Advance-on-access also defines an important boundary. A guest sleeping until a physics-generated interrupt cannot cause physics to advance through an access that has not happened. Such an integration needs an explicit periodic or event-driven advance mechanism. The RLC example does not claim to provide that autonomous interrupt scheduler.

## Inspect the world

The observer plots trace artifacts and displays runtime events. To use the prepared observer example:

```bash
fastdyn run -c configs/world_rlc_observer_master.toml -o out/world-observer
```

Open the printed observer URL, normally `http://127.0.0.1:8770`. The observer is read-only: it does not advance the physical world. Its display is a rolling trace window, so increasing the display horizon and changing the integration quantum have different purposes.

The slave variant starts the guest paused so an external master can grant time:

```bash
# Terminal 1
fastdyn run -c configs/world_rlc_observer_slave.toml -o out/world-observer-slave

# Terminal 2
python3 utils/fastdyn_cosim.py /tmp/fastdyn-observer.qmp --slice-ms 5 --slices 40
```

See [Multiple firmware instances](multiple-firmwares.md) for the budget protocol.

## Current contract

The pin adapter currently accepts ARM register names and scalar Float64 endpoints. It does not implement an ADC's complete register map, DMA behavior, or peripheral interrupt logic; an elder model can supply those layers when needed. It also lacks coordinated guest-and-world snapshot restoration, so a guest-only in-process fuzzing reset cannot restore a consistent physical experiment. The documented world runtime rejects early-return/event-mode FMUs; use the pinned exporter/runtime contract for this optional path.

## Source guide

- [World configuration and runtime guide](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/WorldPlugin.md)
- [RLC machine, endpoint, and pin configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/world_rlc_gpio.toml)
- [Host validation and generated rules](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/world/host/preprocessor.py)
- [Native callbacks and time policy](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/world/runtime/world_plugin.c)
- [Optional build detection](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/world/meson.build)
- [Firmware build prerequisites](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/firmwares/world_rlc_gpio/build.sh)
