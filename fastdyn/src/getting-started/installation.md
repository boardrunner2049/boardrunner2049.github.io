# Install FastDyn

The shortest path to the bundled firmware example is a Linux source build of FastDyn and its patched QEMU. Add physical-board access, device-model libraries, or Modelica compilation when your experiment needs them. The documented host baseline is Ubuntu 24.04; the repository also provides a Docker image with a broader Gazebo and fuzzing stack.

These instructions use the FastDyn repository root as the working directory. This book describes commit `f9666d7f518c373e89831d8e14a6371a27fe6436`.

## Build the basic runtime

Clone the repository:

```bash
git clone https://github.com/boardrunner2049/FastDyn.git
cd FastDyn
git checkout --detach f9666d7f518c373e89831d8e14a6371a27fe6436
```

The detached checkout pins the exact snapshot used by this book. When working on a newer branch, consult that revision's documentation for changes to the examples and build inputs.

Install the Ubuntu build dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake git meson ninja-build pkg-config python3-venv \
  libglib2.0-dev libcjson-dev libpixman-1-dev libfdt-dev zlib1g-dev flex bison
```

Build the runtime and activate its Python environment:

```bash
source ./setup.sh --build-qemu --skip-optifuzz
```

This creates `fastdyn-env/`, installs the Python requirements and editable FastDyn package, initializes the required submodules, applies FastDyn's compatibility patch to its QEMU fork, and builds `build/libfastdyn.so`. The resulting plugin includes device models, the physics engine, FMI v3 support, and flight-controller adapters. `--skip-optifuzz` omits the Banquo dependency checkout used by the mission-level fuzzer; it does not remove the firmware runtime.

The default setup builds `qemu-system-arm` with the `arm-softmmu` target. FastDyn also contains RISC-V and x86 configuration presets, but this command does not build their QEMU executables. Those targets need a compatible patched QEMU build for their architecture. Architecture support for individual plugins must also be checked separately.

Verify the installed entry point, then run the [first experiment](first-run.md):

```bash
fastdyn --help
fastdyn run --help
fastdyn -q run -c configs/minimal.toml -o out/first-run
```

In a new shell, activate the existing environment instead of repeating setup:

```bash
source fastdyn-env/bin/activate
```

## Add capabilities as needed

| Capability | Setup | What it provides |
| --- | --- | --- |
| Physical board access | Install `libstlink-dev libusb-1.0-0-dev`, then use `--build-libhw` together with `--build-qemu` | Hardware access through libhw for passthrough and trace recording |
| LibVIO device models | `source ./setup.sh --build-libvio --skip-optifuzz` | LibVIO installed under `out/libvio/install`, automatically found by `build-model` |
| Modelica and FMI v3 campaigns | `source ./setup.sh --build-qemu --with-rumoca` | Pinned Rumoca and model sources, FMU generation, and the Banquo checkout used by OptiFuzz |
| Legacy Gazebo path | `source ./setup.sh --build-gazebo` after building QEMU and installing Gazebo Harmonic | Gazebo/Courbet libraries and a plugin configured for them |
| SUNDIALS solver | Install `libsundials-dev`, then build with `SUNDIALS=true` plus the other required flags | Optional FMU solver support |

Installing libhw alone does not rebuild an existing plugin. Include `--build-qemu` when you want setup to rebuild FastDyn with newly available libhw support. Rust/Cargo is needed for Rumoca, OptiFuzz, and the LibAFL backend; it is not needed for the minimal firmware walkthrough.

## Rebuild without losing your build choices

After editing C sources, preserve the configured feature set with:

```bash
ninja -C build
```

The repository's `make` target removes and recreates the build directory. Every optional feature defaults to false unless explicitly supplied. For example, this chooses device models and the LibAFL backend:

```bash
make DEV=true LIBFUZZ=true
```

Include `PHY=true FMU=true FLIGHT_CONTROLLERS=true` when that rebuilt plugin must also retain the vehicle and FMU path:

```bash
make DEV=true LIBFUZZ=true PHY=true FMU=true FLIGHT_CONTROLLERS=true
```

`LIBPY=true` is documented as currently failing to build. Use the supported native virtual and host preprocessing interfaces for extensions.

## Docker alternative

The checked-in Dockerfile builds patched QEMU, libhw, LibAFL, and Gazebo/Courbet. Initialize the sources copied into the image first:

```bash
git submodule update --init --depth 1 \
  third_party/common/qemu third_party/common/libhw \
  third_party/common/cmsis-svd-data \
  third_party/courbet_deps/mavlink_headers \
  third_party/courbet_deps/ardupilot_gazebo \
  third_party/courbet_deps/SITL_Models
docker build -t fastdyn .
docker run --rm -it fastdyn
```

The container starts in `/workspace/FastDyn` with `fastdyn` available. Its current build does not enable `FMU=true` or build Rumoca. Use the native FMU setup above for the maintained Modelica vehicle walkthroughs, or deliberately extend the image for that capability.

## Choose the QEMU that matches your plugin

An explicit `[Machine].qemu_path` takes precedence. Without it, FastDyn checks `FASTDYN_QEMU`, the build metadata beside the plugin, then `qemu-system-<arch>` on `PATH`. A stock QEMU executable is not a substitute for the FastDyn fork and required compatibility patch.

Setup can use an already built sibling checkout at `../qemu`; it reports that choice. To explicitly select another source checkout, use `--qemu-root PATH`. For a new external checkout, combine `--clone-qemu --build-qemu`. Existing sources are preserved rather than reset to a different branch.

## Source guide

- [Build and setup implementation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/setup.sh)
- [QEMU build and compatibility patch handling](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/scripts/setup/qemu.sh)
- [Plugin feature selection](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/scripts/setup/fastdyn.sh)
- [Makefile and feature flags](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/Makefile)
- [Docker build definition](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/Dockerfile)
- [Full upstream build notes](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/Building.md)
