# Flight controllers

The flight-controller examples put several FastDyn capabilities together: execution of embedded firmware, virtual instructions and modifiers, physical feedback, host automation, and observability. Courbet supplies firmware-specific bindings and mission assets. The native physics backend supplies sensor and actuator operations. The ordinary FastDyn configuration ties them into a run.

This chapter covers the main revision recorded by the book. Newer PX4 and INAV work appears in [Branch previews](branch-previews.md).

## Choose a starting configuration

| Configuration | Guest and physical path | Default automation |
| --- | --- | --- |
| `configs/copter462.toml` | ArduCopter 4.6.2 with `FastDyn.Copter` FMU | MAVProxy/MAVCesium and copter mission helper |
| `configs/rover462.toml` | ArduRover 4.6.2 with `FastDyn.Rover` FMU | MAVProxy/MAVCesium and telemetry health check |
| `configs/plane462.toml` | ArduPlane 4.6.2 with `FastDyn.Plane` FMU | MAVProxy/MAVCesium and telemetry health check |
| `configs/px4_fmu_v6c_fire_p2.toml` | PX4 FMUv6C ARM/NuttX bridge with a FIRE P2 plant | Guest boot commands, MAVProxy/MAVCesium, and PX4 mission helper |

The first three use the maintained Rumoca setup described in [Physics and FMUs](physics-and-fmu.md). The PX4 P2 profile additionally requires its configured FIRE model/compiler dependencies and a successfully generated P2 FMU.

Run each command from the FastDyn repository root:

```bash
source ./setup.sh --build-qemu --with-rumoca
fastdyn run -c configs/copter462.toml -o out/copter-demo
```

The first run may build the selected FMU. Look for the FMU backend-loading message, the configured periodic IRQ, and the MAVCesium address. The default copter mission starts near the configured KLAF/Purdue origin, uploads the mission, monitors flight, and ends after the landing workflow completes. Mission progress is the useful outcome to inspect; the mere appearance of a map does not establish a successful run.

For the other maintained ArduPilot examples:

```bash
fastdyn run -c configs/rover462.toml -o out/rover-demo
fastdyn run -c configs/plane462.toml -o out/plane-demo
```

Run these sequentially with their default ports, or use [Multiple firmware instances](multiple-firmwares.md) for isolated parallel launches.

## Understand the firmware boundary

The target CPU executes the embedded firmware image. FastDyn's hooks adapt selected hardware-facing operations to the host environment and physics backend. In the ArduPilot path, this includes sensor data delivery, actuator output, timing, storage, and communication support at selected firmware entry points.

That boundary preserves useful controller and scheduler behavior while avoiding the need to emulate every peripheral before an experiment can start. It also determines what a result covers: an adapter that supplies data at a driver boundary does not exercise the skipped SPI or I²C register transactions. Select an MMIO model when those transactions are the subject of the experiment.

Binding files are specific to the executable and its calling conventions. Replacing an ELF without regenerating and reviewing those bindings can redirect a hook into unrelated code. The common generator supports the supplied ArduCopter, ArduPlane, and PX4 profiles:

```bash
fastdyn-env/bin/python virtuals/physics/flight_controllers/courbet/prepare_execution_configuration.py \
  --profile virtuals/physics/flight_controllers/courbet/ardupilot/copter462/profile.toml
```

The generator resolves symbols, compiles virtual/modifier rules, validates the profile, and writes `virtuals.txt`, `modifiers.txt`, and `firmware.sha256`. Failed validation preserves prior output. ArduPilot profiles pin the supplied ELF digest where their rules retain absolute addresses; PX4 additionally checks the structure layouts and instructions consumed by its bridge. Hook selection and native callback behavior remain authored decisions.

## PX4 on the embedded target

The generic Rumoca setup does not initialize the additional FIRE model submodule or fetch its portable Modelica Standard Library and FMI headers. Prepare those inputs and build the plant first:

```bash
git submodule update --init third_party/courbet_deps/fire_modelica_models
python utils/setup_fire_toolchain.py
python utils/build_fmi3_fmu.py \
  --config configs/px4_fmu_v6c_fire_p2.toml --fmu quad_p2
```

The build should print `Generated FMU:` on success. The configuration also points to the model repository's compiler-limitations record; resolve any plant-build failure before diagnosing guest firmware. The generator and build commands are separate checks from successful closed-loop execution.

With the P2 FMU available, launch:

```bash
fastdyn run -c configs/px4_fmu_v6c_fire_p2.toml -o out/px4-demo
```

The configuration executes the supplied ARM ELF on Cortex-M7 and initializes modules through `boot.nsh`. The bridge replaces selected sensor publications with FMU readings while real uORB distribution, NuttX scheduling, sensor processing, EKF2, and control code execute. Actuator outputs feed the plant. TELEM1 UART bytes are forwarded through UDP to MAVProxy and the host mission helper.

The mission helper checks telemetry and estimator readiness, requests mission mode and normal arming, starts the mission, and monitors landing/disarming. `FASTDYN_PX4_READY` means the boot-command sequence was delivered; it does not establish estimator readiness or a completed mission.

For diagnosis without host mission helpers:

```bash
fastdyn run -c configs/px4_fmu_v6c_fire_p2.toml --no-run-processes
```

Guest module initialization still runs. For an uninitialized NuttX console, explicitly clear the guest boot setting as well:

```bash
FASTDYN_BRIDGE_BOOT= fastdyn run -c configs/px4_fmu_v6c_fire_p2.toml --no-run-processes
```

The profile is a firmware bridge, not a complete Pixhawk6C peripheral model. Its sensor injection uses PX4's simulation publication path; SIH `*_groundtruth` topics therefore do not represent FMU ground truth. Small deterministic sensor dither prevents repeated ideal readings from triggering stale-sensor detection, but it is not a calibrated noise model. The current geodetic adapter also supplies equal MSL and ellipsoid altitudes because this plant has no geoid model.

## Observe and customize a run

The default viewer is `http://127.0.0.1:5000/mavcesium/`. Its telemetry reflects the flight stack's reported position and attitude. Map assets may require network access. Use the console, mission log, and raw physical outputs alongside the viewer when diagnosing disagreement.

Configuration parameters control the initial location, mass/inertia, motor response, and sensor biases supported by the selected model. `FASTDYN_PARAM_FILE` and `FASTDYN_MISSION_FILE` select alternative files where the configuration uses those overrides. Keep the mission's origin, expected altitude convention, actuator ordering, and plant's initial state consistent.

For a concrete smoke check after setup:

```bash
FASTDYN_COURBET_CONFIG=configs/rover462.toml \
  tests/integration/courbet_fmu_vehicle_smoke.sh

tests/integration/courbet_mission_smoke.sh
```

The first checks a vehicle launch and telemetry path; the second exercises the copter mission. PX4 has separate bridge and mission checks under `courbet/tests/`. These checks establish integration properties in the simulator. Physical fidelity requires calibration and comparisons appropriate to the claim being made.

## Source guide

- [Vehicle configuration and mission guide](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/FlightControllerSimulation.md)
- [Courbet profiles, bindings, and helper ownership](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/README.md)
- [PX4 profile, interfaces, and validation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/courbet/px4/fmu_v6c/README.md)
- [Shared firmware-to-physics bridge](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/physics/flight_controllers/ardupilot/ardupilot.c)
- [Copter run configuration](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/configs/copter462.toml)
- [Vehicle launch smoke criteria](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/tests/integration/courbet_fmu_vehicle_smoke.sh)
