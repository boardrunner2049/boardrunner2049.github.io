# Writing a device model

An elder model is a shared library with a small, explicit interface: initialize a device instance, read a register, write a register, and optionally observe interrupt entry and return. The library is loaded into the emulator process. No separate model server is required.

The current interface is **model ABI version 2**, defined in `<fastdyn/device_model.h>`. Start from this header and the shipped `tests/models/elder_echo.c` example. The loader rejects an incompatible ABI, a missing descriptor, or missing required callbacks at startup.

## Build the supplied example

After the normal FastDyn setup has installed the Python command, compiler dependencies, and patched QEMU headers, run these commands from the repository root:

```bash
fastdyn build-model tests/models/elder_echo.c -o build/models --no-vio
```

The result is `build/models/elder_echo.so`. The command detects dependencies and compile-command changes, so a subsequent invocation can reuse an up-to-date build. If compilation fails, it removes the model's stale output instead of leaving an old library available to a later run.

The shipped echo model has a useful test contract:

| Offset | Meaning |
| --- | --- |
| `0x00` | Writable data register, initialized from the model's `reset` setting |
| `0x04` | Count of interrupt-entry notifications received by this instance |
| `0x08` | Count of interrupt-return notifications received by this instance |
| Last byte of the configured range | Reads as `0xAA`, exercising the inclusive range boundary |

To bind it, add this **fragment** to a complete firmware configuration that actually accesses the chosen range:

```toml
[Device.Models.elder]

[Device.echo]
ranges = [["0x40000000", "0x4000000F"]]
reset = 7

[[Device.echo.handlers]]
model = "elder"
enabled = true
scroll = "build/models/elder_echo.so"
```

The fragment does not create firmware traffic. A guest must read or write the range to exercise it. The echo model is an ABI example, not a substitute for the real register semantics of a device at that address.

## Implement the descriptor

These are the exact callback shapes accepted by the public header. This **interface excerpt** shows how the functions are registered; supply their definitions in your model:

```c
#include <fastdyn/device_model.h>

static void *my_init(const FdDevice *dev,
                     const char *config_json,
                     const FdHost *host);
static uint64_t my_read(void *opaque, hwaddr addr,
                        unsigned size, uint64_t pc);
static void my_write(void *opaque, hwaddr addr, uint64_t value,
                     unsigned size, uint64_t pc);

const FdModel fastdyn_model = {
    FASTDYN_MODEL_ABI_FIELDS,
    .init = my_init,
    .read = my_read,
    .write = my_write,
};
```

`FASTDYN_MODEL_ABI_FIELDS` supplies the interface version and descriptor size. Required members are `init`, `read`, and `write`. Optional `interrupt` and `serve` members both have signature `void callback(void *opaque, int irq)`.

`FdDevice` provides the instance's name, ranges, and IRQs. Its ranges use `base` plus `size`, even though TOML uses inclusive start/end pairs. `FdHost` currently provides the logging service. The model header also includes declarations for the patched QEMU host APIs; include the FastDyn header rather than independently selecting a potentially incompatible QEMU header.

## Keep state per instance

Allocate a state object in `init` and return it. FastDyn passes that object back as `opaque` on every callback. This allows one UART library to serve UART2 and UART3 without sharing FIFOs or configuration accidentally.

Return `NULL` when the configuration cannot be supported. Preserve or copy values you need from `config_json` and `host` during initialization; their API contract guarantees their validity only for that call. The `FdDevice` description remains valid until unload. ABI v2 has no model teardown callback, so plan ownership around the current process lifetime rather than inventing a destructor interface.

Handle access width explicitly. A one-byte write to a data register need not mean the same thing as a four-byte write, and read-to-clear or write-one-to-clear behavior needs deliberate implementation. Keep unsupported accesses diagnosable with `host->log` and include the address, size, and guest PC when that context helps explain a failure.

## Reuse LibVIO

LibVIO supplies reusable I/O mechanisms, including buses, signals, DMA support, and host endpoints. It is useful when a model needs those facilities; a small register-only model can build without it, as the echo example does.

Prepare the pinned dependency with:

```bash
source ./setup.sh --build-libvio
fastdyn build-model models/ -o build/models -r -j 8
```

The second command assumes your `models/` directory exists. FastDyn looks for LibVIO through its prepared build or `pkg-config vio`, and the model includes `<vio/vio.h>` when using it. Elder routes LibVIO logging into the same FastDyn log when the library exposes its logger setter. Use the LibVIO API from the pinned dependency for bus operations; FastDyn's `FdModel` contract remains the surrounding peripheral interface.

For a model implemented across multiple source files:

```bash
fastdyn build-model --name spi4 models/spi4.c models/spi4_dma.c -o build/models
```

That command produces one `spi4.so`. Without `--name`, each input C file is a separate model. Review duplicate output names before combining directories.

## Experimental extraction at `a38af40`

FastDyn [`a38af408451394ea2f41be1e9cf1e96bc46c370f`](https://github.com/boardrunner2049/FastDyn/commit/a38af408451394ea2f41be1e9cf1e96bc46c370f) adds optional automatic MMIO metadata generation. This is a later addition to the core `f9666d7` model workflow above. Follow the [automatic MMIO setup](../designs/automatic-mmio.md) to build that revision with its matching patched QEMU and plugin before using it.

With **Clang 18 or a compatible `clang`** available, run from the FastDyn repository root:

```bash
fastdyn build-model --mmio-opt --no-vio \
  tests/models/elder_echo.c -o build/mmio-models
```

The outputs are `build/mmio-models/elder_echo.so` and `build/mmio-models/elder_echo.mmio.json`. The library retains its ordinary `fastdyn_model` callbacks and embeds a generated `fastdyn_mmio_model` operation table. The JSON report exposes the extracted operations for inspection; the runtime consumes the embedded table. Clang is required for this extraction option, while ordinary model builds retain their existing compiler selection.

The extractor currently accepts one C source per model, so the multi-source `--name` example above does not apply with `--mmio-opt`. Configure the generated library as the normal elder `scroll`, then extend the existing CPU configuration with this fragment:

```toml
[CPU.cpu0.plugins.mmio_opt]
enabled = true
```

The first execution path targets a single Cortex-M CPU. **This is experimental:** an accepted operation is not a proof that it preserves the original callback. Use an explicitly audited model, inspect its build and installation reports, and compare against ordinary execution. The [complete workflow and reviewed limitations](../designs/automatic-mmio.md) explain the extractor and guest-semantics boundaries. Leaving the plugin disabled keeps the same library usable through its ordinary elder callbacks.

## Validate behavior at the boundary

A useful model check exercises reset state, width-sensitive reads and writes, boundary addresses, per-instance isolation, and interrupt ordering. Then run the target firmware path that motivated the model and compare its I/O against a recorded trace or known hardware behavior. Successful loading establishes ABI compatibility; successful firmware progress establishes only the behavior exercised by that run.

## Source guide

- [ABI definitions and lifetime contracts](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn/device_model.h)
- [Complete echo model](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/models/elder_echo.c)
- [Incremental model builder](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/model_build.py)
- [CLI options](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/main.py)
- [Loader validation and LibVIO logging](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/elder/elder.c)
- [`a38af40` optional Clang extraction and generated reports](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/src/fastdyn/model_build.py)
- [`a38af40` model operation extractor](https://github.com/boardrunner2049/FastDyn/blob/a38af408451394ea2f41be1e9cf1e96bc46c370f/src/fastdyn/mmio_model.py)
