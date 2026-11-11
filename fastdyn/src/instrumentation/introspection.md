# RTOS introspection and the activity monitor

FastDyn can turn an opaque firmware run into a view of tasks, scheduler activity, and kernel resources. Its introspection plugin combines host-side symbol and layout analysis with native callbacks, then records structured events that a browser monitor can display while the guest executes.

This is useful when the firmware is running but its behavior is difficult to explain. You can ask which task is active, whether synchronization objects are being used, and where execution stops producing scheduler events. The same event log remains available after the run, so observations do not disappear with the browser window.

## Run a complete example

After building FastDyn and patched QEMU, run from the repository root:

```bash
fastdyn run -c configs/introspection/freertos.toml \
  -o fastdyn-introspection-demo
```

This configuration uses a committed FreeRTOS ELF with debug information and enables the local activity monitor. Open the URL printed by the plugin, normally `http://127.0.0.1:8765/`. Let the firmware execute, inspect the task and resource panels, then stop the run with Ctrl-C.

The reusable outputs are:

| Artifact under `run-artifacts/introspection/` | Purpose |
| --- | --- |
| `schema.txt` | Prepared symbols and supported kernel layouts consumed by the native adapter |
| `activity.jsonl` | One structured event per line, recorded during execution |

The generated PC hooks are also visible in the run's `virtuals/virtuals.txt`. Looking at the schema and generated hooks explains what the plugin can observe for this particular firmware build.

## Enable it in your configuration

Add the following tables to a suitable CPU configuration:

```toml
[CPU.cpu0.plugins.introspection]
enabled = true

[CPU.cpu0.plugins.introspection.activity_monitor]
enabled = true
host = "127.0.0.1"
port = 8765
open_browser = true
```

The nested monitor table belongs to the plugin. No extra FastDyn CLI flag or introspection-specific QEMU argument is required. Omit the monitor table, or set `activity_monitor = false` in the parent table, to collect the activity artifact without launching the browser service. The service binds to loopback by default and shuts down with the run.

A firmware needs enough retained symbols for the adapter to identify relevant hooks. DWARF supplies layout details for supported task and resource fields. An optimized-away API cannot be instrumented by its absent symbol, and missing type information limits the fields the runtime can decode.

## Supported RTOS families

The repository provides directly runnable configurations for six RTOS families. These examples use committed debug-symbol fixtures; they do not require cloning and building every RTOS before trying the monitor.

| RTOS | Example configuration | Monitor port | Main observation approach |
| --- | --- | ---: | --- |
| FreeRTOS | `configs/introspection/freertos.toml` | 8765 | Dedicated native task walker, creation/switch events, queue-backed resource classification |
| ChibiOS | `configs/introspection/chibios.toml` | 8766 | Dedicated native task walker and task/resource hooks |
| Zephyr | `configs/introspection/zephyr.toml` | 8767 | Selected architecture switch hook, schema-backed current-thread fields, resource hooks |
| ThreadX | `configs/introspection/threadx.toml` | 8768 | Scheduler/lifecycle events and current-thread pointer when available |
| RT-Thread | `configs/introspection/rtthread.toml` | 8769 | Scheduler/lifecycle events and schema-backed current-thread lookup |
| NuttX | `configs/introspection/nuttx.toml` | 8770 | Supported scheduler transition hook with decoded destination-task metadata |

For example:

```bash
fastdyn run -c configs/introspection/zephyr.toml -o fastdyn-zephyr
```

The adapters intentionally differ in depth. FreeRTOS and ChibiOS have bespoke task walkers. The other adapters use event hooks and schema-backed fields instead of assuming a universal private task-list layout. A scheduler event is not automatically a complete task switch, and observing a resource operation is not automatically evidence that the operation succeeded.

All six adapters declare semaphore, mutex, and timer hooks where those APIs exist. Zephyr, ThreadX, and RT-Thread also include message-queue and event-flag operations; ChibiOS includes mailbox operations. The actual emitted set depends on symbols present in the selected image. FreeRTOS uses its schema to distinguish several resource kinds implemented through queues.

## Read the monitor correctly

The overview identifies the latest active task when a `task_switch` event supplies one. Task and kernel-resource panels let you filter the stream by a stable object identity. The object viewer keeps a selected object in view while later events refresh its captured fields, such as priority, scheduler state, semaphore count, or timeout metadata.

Two visualizations answer different questions:

- **Event rate** shows recorded events across simulated time. A quiet interval means no relevant events were recorded; it is not a host-utilization measurement.
- **Task CPU ownership** estimates guest time between recorded task-switch events. Its accuracy depends on observing those switches and identifying the task. It is not a hardware performance counter or a complete RTOS accounting facility.

The event artifact uses `time_ns` from QEMU's virtual timer. Optional fields include `rtos`, `event`, task identity/name, priority, task state, and adapter-provided decoded fields. Missing fields remain absent rather than being filled with invented values.

For a stalled-looking run, first compare the monitor with the artifact. A populated log with no new events points to a different investigation than a missing or empty file. The guest might be polling a device, waiting for an interrupt, or running code outside the installed hooks. Combine this view with [function tracing and variable watches](tracing-and-sanitizers.md) to localize the behavior.

## Architecture and build scope

Zephyr's host adapter contains switch-symbol selections for several architecture families, including Cortex-M, ARM A/R, AArch64, RISC-V, and selected others. The appropriate symbol differs by port; the adapter does not guess a universal Zephyr switch function. Some ports deliberately have no selected switch hook.

That selection table is not an end-to-end portability guarantee. The committed demonstration path is Cortex-M, and native introspection still contains 32-bit pointer/layout assumptions. The NuttX switch callback explicitly follows ARM AAPCS argument placement. Validate the native pointer width, calling convention, schema, and callback semantics before claiming introspection coverage for another target.

## How to extend the feature

The host preprocessor identifies the RTOS, resolves hooks, emits a schema, and returns declarative virtual rules. The native adapter consumes that schema and appends events. The browser renders generic event fields, so adding a useful decoded field normally belongs in the adapter rather than the UI.

Use shared [host analysis](../extending/host-analysis.md) for symbols and layouts, but keep RTOS hook selection and runtime interpretation in the introspection plugin. Test detection, generated hooks, schema contents, and live callback behavior as separate boundaries. This keeps a newly recognized RTOS from being mistaken for a fully implemented runtime adapter.

## Source guide

- [Runnable RTOS configurations and fixture map](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/IntrospectionExamples.md)
- [Host preparation and monitor lifecycle](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/introspection/host/preprocessor.py)
- [Schema-based RTOS hooks and Zephyr architecture selection](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/introspection/host/rtos/generic_rtos_introspector.py)
- [Generic native adapters and target assumptions](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/introspection/runtime/inspct_generic.c)
- [Structured activity emission](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/virtuals/introspection/runtime/activity.c)
- [Monitor behavior and interpretation](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/ActivityMonitor.md)
