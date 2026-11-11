# Branch previews: INAV and PX4

Two development branches extend the flight-controller examples beyond this book's main revision. Both execute embedded board firmware and connect it to an FMU loaded inside the FastDyn/QEMU process. The controller, scheduler, and physical feedback can run together without a separate physics server.

Use the matching source revision for the commands below. These features and results should not be assumed to exist on the core chapters' `f9666d7` baseline; a later main-branch merge also needs its own source and validation review.

| Preview | Reviewed FastDyn revision | Focus |
| --- | --- | --- |
| INAV | `3910be12b82443efe8abb75ef89aa02f5ef047f4` | MATEKF405 firmware, receiver input, sensor conversion, takeoff and receiver-loss checks |
| PX4 | `0e13b73986a66270a6d8452b2c0147af7b874d29` | Five explicit FMUv6C version profiles, autonomous missions, and optional persistent translation caching |

The reported outcomes below come from the pinned repository's validation records and test definitions. They were reviewed for this book; the book-writing process did not rerun the flight demonstrations.

Use a separate checkout for each preview so its build products and generated bindings stay with its source revision. For INAV:

```bash
git clone --branch codex/inav-fmu-integration \
  https://github.com/boardrunner2049/FastDyn.git FastDyn-inav
cd FastDyn-inav
git checkout --detach 3910be12b82443efe8abb75ef89aa02f5ef047f4
```

For PX4, from the parent directory where you keep checkouts:

```bash
git clone --branch px4-v1.17-firmware-slicing \
  https://github.com/boardrunner2049/FastDyn.git FastDyn-px4
cd FastDyn-px4
git checkout --detach 0e13b73986a66270a6d8452b2c0147af7b874d29
```

The setup commands in each section run inside its corresponding checkout.


## INAV: a complete path from receiver to plant

The INAV profile runs Cortex-M4 firmware for MATEKF405 against `FastDyn.Copter`. Its source declares version **10.0.0**, at upstream commit `d0c611e040887940226c9536bc84a3795ef9e800`. The [version record](https://github.com/boardrunner2049/FastDyn/blob/3910be12b82443efe8abb75ef89aa02f5ef047f4/virtuals/physics/flight_controllers/inav/versions/INAV-10.0.0.md) identifies this as development source, not a verified 10.0.0 release tag.

This firmware requires the supplied source compatibility patch. It enables a 16 KiB RAM settings store, simulated GPS and other sensor interfaces, MSP receiver input, and an AUX1 arm switch. It also marks ideal simulated accelerometer and compass values as calibrated. Settings reset each run. The normal gyro calibration, estimator, filtering, PID, and motor mixer still execute.

The MPU6500 path is especially useful: the bridge provides device identity and raw sensor bursts, then lets INAV's actual MPU driver perform alignment and filtering. It compensates for the board's 180-degree sensor mounting and converts the FMU's FRD values into the driver's raw counts. Other selected board initialization and bus operations are bypassed by firmware-specific hooks. This boundary supports controller experiments without requiring a complete STM32 peripheral model.

### Run the profile

From the root of the INAV revision, with the usual native build dependencies installed:

```bash
source ./setup.sh --build-qemu --with-rumoca --skip-optifuzz
python utils/setup_fire_toolchain.py
fastdyn run -c configs/inav_matekf405.toml -o inav-fastdyn_work
```

Rumoca requires its pinned nightly Rust toolchain, `rustfmt`, and the `libudev` development files. The toolchain helper supplies pinned FMI headers for packaging. The run builds or uses the Copter FMU and advances it every millisecond of QEMU virtual time. INAV configures its own SysTick; this FMU timer does not inject a second one.

In another terminal on the same host, send receiver frames:

```bash
python virtuals/physics/flight_controllers/inav/send_rc.py \
  --arm --throttle 1500 --duration 30
```

The helper first sends disarmed input, then arms and raises throttle. The receiver endpoint is fixed at `127.0.0.1:14590`, so run one such profile at a time. Its packet is `FDRC` followed by eight little-endian unsigned 16-bit PWM values: AETR, then AUX1 through AUX4. Values must be 900–2100 microseconds; AUX1 at 1700–2100 requests arming. Stopping frames exercises INAV's receiver timeout and failsafe.

### What the checks establish

```bash
python -m pytest -q tests/integration/test_inav_fmu_smoke.py

# After building out/fmi3/Copter/FastDyn_Copter.fmu:
FASTDYN_RUN_INAV_COPTER=1 \
  python -m pytest -q tests/integration/test_inav_fmu_smoke.py
```

The default integration check boots the real firmware against a deterministic test FMU. It inspects calibrated and filtered sensor values, GPS fix, and the initialized mixer; rejects an oversized receiver packet; arms through receiver input; and confirms that throttle reaches the FMU motor input.

The optional Copter check uses the actual plant. It requires normal receiver arming, a climb greater than one metre, receiver-loss failsafe, and all four motor commands returning to at most 1000 microseconds. The version record reports that this check was rerun after fixing the firmware's 64-bit microsecond return convention.

These checks establish a useful closed feedback loop and a specific failure response. Sustained flight stability, all-axis response, mission upload, telemetry interfaces, and physical sensor calibration are not established by this profile. Each rebuilt ELF also needs its own symbol/layout review and checksum; absolute hook addresses are not portable.

## PX4: one board, five explicit firmware profiles

The PX4 branch runs unmodified ARM/NuttX ELFs built from official source tags, with symbols and DWARF retained. Runtime slicing bypasses selected unavailable hardware operations and bridges selected firmware data boundaries. NuttX scheduling, uORB, EKF2, commander, navigation, control, and MAVLink continue to execute in the guest.

Sensor samples enter at uORB publication, above the physical SPI/I²C sensor drivers. PX4's simulation publishers own sample scheduling and metadata; the bridge replaces selected numeric fields with FMU values. Actuator publications drive the P2 plant. This makes the profile useful for flight-stack behavior while leaving physical driver transactions outside its coverage.

The pinned version-sweep record distinguishes successful boot/sensor/motor checks from complete autonomous missions:

| PX4 version | Profile directory under `courbet/px4/` | Recorded result |
| --- | --- | --- |
| `v1.13.3` | `fmu_v6c_v1_13` | Boot, sensors, and motor output; mission develops a compass-calibration error |
| `v1.14.4` | `fmu_v6c_v1_14` | Boot, sensors, and motor output; navigation failure during horizontal flight leads to failsafe landing |
| `v1.15.4` | `fmu_v6c_v1_15` | Autonomous mission, landing, and disarm |
| `v1.16.2` | `fmu_v6c_v1_16` | Autonomous mission, landing, and disarm |
| `v1.17.0` | `fmu_v6c` | Autonomous mission, landing, and disarm; default in this revision |

Version handling includes real ABI differences. Older GPS topics contain scaled integers; later ones use doubles, with further structure changes in v1.17. The generator checks each ELF's DWARF and HRT instruction pattern before producing its bindings. A successful v1.17 run therefore does not automatically qualify another binary.

### Run and inspect a mission

Prepare the native build and FIRE P2 dependencies described in [Flight controllers](flight-controllers.md), then use the selected revision's wrapper:

```bash
virtuals/physics/flight_controllers/courbet/px4/fmu_v6c_v1_16/run.sh

# Run separately for the default v1.17.0 profile:
virtuals/physics/flight_controllers/courbet/px4/fmu_v6c/run.sh
```

Each wrapper validates its bindings, builds the plugin, derives a temporary version-specific TOML, and launches the common machine and plant. The generator requires Python-enabled GDB and `pyelftools`. Wait for mission progress through normal arming, takeoff, waypoints, landing, and disarm. The viewer at `http://127.0.0.1:5000/mavcesium/` provides position and attitude; `FASTDYN_PX4_READY` alone only confirms that boot commands were delivered.

After a successful P2 FMU build, run the stronger check:

```bash
fastdyn-env/bin/python \
  virtuals/physics/flight_controllers/courbet/tests/smoke_px4_mission.py \
  --version 1.17.0
```

It retains console output, viewer messages, and `summary.json` under `out/px4-mission-*`. Success requires the actual mission to finish landed and disarmed, at least 10 metres of relative altitude, 5 metres of horizontal movement, 50 attitude samples, a working viewer, and a successful process exit. This test uses `--no-build-fmu` internally, so it needs the plant built beforehand.

QEMU virtual time drives the FMU and PX4 HRT service; NuttX SysTick remains separate. Deterministic sensor dither avoids stale-sample detection but does not supply calibrated noise. SIH ground-truth topics describe SIH's internal plant, not this FMU, and the current altitude adapter has no geoid correction. Preserve these distinctions when comparing simulated and measured flight data.

## Optional persistent translation caching

The reviewed PX4 revision also adds FastDyn configuration support for the QEMU fork's persistent TCG cache:

```toml
[Machine]
supercache = "../cache/firmware.sc"
supercache_flat = false
```

The preview's pinned QEMU submodule does not contain Supercache. The [advanced Supercache chapter](../advanced/supercache.md) pairs this frontend with the separately pinned QEMU implementation and gives the complete build and cold/warm workflow. Begin with normal mode; flat mode additionally requires immutable executable guest memory and its documented address-span limits.

The cache path is relative to the TOML. FastDyn records effective configuration, generated instrumentation, and native input identities in an adjacent manifest, and discards stale caches when those inputs change. Large native files use path, size, and modification time rather than a complete content digest. Use a trusted filesystem and separate cache files for independent workers.

This optional mode requires ASLR to be disabled for the launched process, as documented by that revision. Treat it as a measured optimization for a particular workload; the branch's existence does not establish a universal acceleration factor.

## Source guide

- [INAV setup, source patch, receiver contract, and frame conventions](https://github.com/boardrunner2049/FastDyn/blob/3910be12b82443efe8abb75ef89aa02f5ef047f4/virtuals/physics/flight_controllers/inav/README.md)
- [INAV integration and actual-Copter test assertions](https://github.com/boardrunner2049/FastDyn/blob/3910be12b82443efe8abb75ef89aa02f5ef047f4/tests/integration/test_inav_fmu_smoke.py)
- [PX4 slicing, ABI, calibration, and timing contract](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/docs/PX4FirmwareSlicing.md)
- [PX4 version sweep and recorded outcomes](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/virtuals/physics/flight_controllers/courbet/px4/version_sweep/README.md)
- [PX4 mission smoke implementation](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/virtuals/physics/flight_controllers/courbet/tests/smoke_px4_mission.py)
- [Branch configuration and persistent-cache requirements](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/docs/Configuration.md)
