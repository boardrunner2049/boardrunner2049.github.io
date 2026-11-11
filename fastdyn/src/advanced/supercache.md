# Supercache: retain native translations across runs

Supercache saves QEMU's generated native code so that a later process can reuse compatible translations. It targets repeated execution of the same firmware, such as a campaign that starts the same boot path many times. The reusable artifact is translated host code and its translation-block records. Guest RAM, device state, timers, and the state of FastDyn's plugins still belong to the new run.

This is an implemented development-branch capability with a separate QEMU prerequisite. It is not enabled by the current main-branch build.

## Choose the matching revisions

| Component | Reviewed revision | Supercache capability |
| --- | --- | --- |
| FastDyn main | [`5b8bf3d`](https://github.com/boardrunner2049/FastDyn/tree/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c) | No `supercache` or `supercache_flat` frontend configuration |
| QEMU submodule pinned by that main revision and the PX4 preview | [`99b54836`](https://github.com/boardrunner2049/qemu/tree/99b54836ded8dc3271eba52deee7453efc0a13b9) | Does not contain the persistent-cache implementation |
| FastDyn `px4-v1.17-firmware-slicing` preview | [`0e13b739`](https://github.com/boardrunner2049/FastDyn/tree/0e13b73986a66270a6d8452b2c0147af7b874d29) | Configuration fields, input manifest, invalidation, and unit tests |
| QEMU `fastdyn` development revision | [`12f5e688`](https://github.com/boardrunner2049/qemu/tree/12f5e68807650822d3edb7e1073f524e0262bec7) | Persistent native translations, plugin callback reconstruction, and optional flat lookup |

The workflow below deliberately combines the last two revisions. Following the preview's default submodule build alone still selects the older backend. Main's ordered QEMU patch series, including guest-instruction fragments, is a different build path and is not qualified by this example.

## Build the advanced runtime

Use an **x86-64 Linux host** and the native dependencies from [Install FastDyn](../getting-started/installation.md). This restriction describes the host executing cached native code; the example guest is ARM Cortex-M3. The backend is implemented for system emulation and does not provide this cache for user-mode emulation or other host architectures.

Start in the directory where you keep source checkouts. Choose a new external QEMU directory: setup intentionally preserves an existing checkout and will not switch it merely because `--qemu-ref` changes.

```bash
git clone --branch px4-v1.17-firmware-slicing \
  https://github.com/boardrunner2049/FastDyn.git FastDyn-supercache
cd FastDyn-supercache
git checkout --detach 0e13b73986a66270a6d8452b2c0147af7b874d29

source ./setup.sh --clone-qemu --build-qemu --skip-optifuzz \
  --qemu-root ../qemu-supercache-12f5e688 \
  --qemu-repo https://github.com/boardrunner2049/qemu.git \
  --qemu-ref 12f5e68807650822d3edb7e1073f524e0262bec7
```

This setup path builds `qemu-system-arm` with plugin support and builds `build/libfastdyn.so` against the selected QEMU. There is no separate FastDyn `SUPERCACHE=true` build switch. The preview's setup applies its icount/plugin compatibility patch before compiling.

**Validation level:** the setup flags and both implementations were inspected, and `git apply --check` succeeded for the preview's compatibility patch against the exact QEMU `12f5e688` target files. This documentation update did not compile this combination or execute the firmware with it. Patch applicability establishes a concrete build path, not a measured runtime result.

## Run the bundled fixture cold, then warm

Continue from the `FastDyn-supercache` checkout with its environment active. Copy the shipped FreeRTOS example beside the original:

```bash
cp configs/minimal.toml configs/minimal-supercache.toml
```

In the copy's existing `[Machine]` table, enable the following settings. Do not add a second `[Machine]` table. The fixture already contains commented Supercache fields that can be edited:

```toml
supercache = "../cache/minimal.sc"
supercache_flat = false
print_command = true
```

The cache output path is resolved relative to the TOML, so this example writes `cache/minimal.sc` under the checkout. `supercache_flat` must be a TOML boolean; setting it to `true` requires a nonempty `supercache` path. A cache path cannot contain a comma or NUL because it becomes a QEMU accelerator option.

Select the exact executable and run:

```bash
export FASTDYN_QEMU="$PWD/../qemu-supercache-12f5e688/build/qemu-system-arm"

setarch "$(uname -m)" -R \
  fastdyn run -c configs/minimal-supercache.toml -o out/supercache-minimal
```

The copied fixture leaves `[Machine].qemu_path` unset, allowing `FASTDYN_QEMU` to select this build. An explicit `qemu_path` would take precedence.

The `setarch` invocation disables address-space randomization for this process and its children. Cached machine code contains process addresses, and this backend checks that the caller has already selected stable addresses. QEMU does not change the process personality or restart itself. A host that refuses this launch mode cannot run the documented Supercache workflow.

The fixture changes the argument to `vStartLEDFlashTasks` from 1 to 3, prints register 0 at that function, and ends at `vTaskStartScheduler` through `benchmark_end`. A successful cold and warm run should preserve those observations. The printed QEMU command should contain an accelerator argument shaped like this, with an absolute path:

```text
-accel tcg,supercache=/absolute/path/FastDyn-supercache/cache/minimal.sc
```

Run the identical command again without editing the configuration, rebuilding binaries, or changing instrumentation. The first run records the translations it reaches; the next run can restore them and append translations for newly reached paths.

Two files serve different purposes:

| File | Purpose |
| --- | --- |
| `cache/minimal.sc` | QEMU's native code and translation records |
| `cache/minimal.sc.fastdyn.json` | FastDyn's fingerprint and the inputs used to compute it |

The backend defaults to a 2 GiB translation-code capacity when Supercache is enabled. The file is sparse, with metadata after the code area, so logical file size and allocated disk space differ. The presence of these files demonstrates that the path was configured; it is not a cache-hit statistic.

## What happens on a lookup

Ordinary QEMU lookup remains the first step. On a miss, Supercache considers a stored translation using the guest PC, code-segment base, first physical code address, target flags, and compilation flags. For PC-relative translation blocks, the PC component is normalized according to QEMU's `CF_PCREL` convention.

Before activating a stored block, the backend checks the second code-page mapping when present and hashes the current guest instruction bytes. A match permits it to reconstruct the process-local `TranslationBlock`, reset native jump links, and make the cached code available. The normal mode restores QEMU's interval-tree and page/hash-table bookkeeping so ordinary invalidation machinery can find the block.

FastDyn instrumentation is already present in the saved native code. QEMU therefore reruns plugin translation callbacks to rebuild their runtime metadata, without generating replacement TCG operations. A warm run can still perform translation-time plugin work; Supercache does not promise to eliminate every preprocessing or callback cost. Custom plugins must initialize the data that their cached instrumentation references. Replaying these callbacks is not serialization of arbitrary host objects, and extensions need cold-versus-warm behavioral checks.

## Two layers decide whether reuse is valid

FastDyn owns the experiment's identity. Before launching QEMU, it computes a SHA-256 fingerprint over a versioned, deterministically serialized input description:

| Input class | Included examples | Identity used |
| --- | --- | --- |
| Effective settings | Platform, CPU definitions, initial vector address, effective `icount`, log options, machine globals, scalar plugin options, flat mode | Values in the manifest payload |
| Configuration and generated files | Source TOML, device description, virtuals, modifiers, fuzzing schema, snapshot extra ranges, inline-I/O map when present, preprocessing artifacts | File contents hashed with SHA-256, plus size |
| Native and firmware artifacts | QEMU, FastDyn plugin, firmware/kernel, drive, BIOS, FMU library, external virtual libraries | Absolute path, size, and nanosecond modification time |

Changed inputs invalidate an existing `.sc` file. A missing or unreadable FastDyn manifest also causes the existing cache to be discarded. An unchanged manifest is kept without rewriting it. The native-file strategy assumes a trusted filesystem: replacing a binary while preserving its path, size, and timestamp defeats that cheap identity. An extension that depends on additional generated inputs should register those artifacts with preprocessing rather than leave them outside the fingerprint.

QEMU then checks its own compatibility. The header records the cache format, code-buffer size, runtime signature, host page size, target page bits, and `TranslationBlock` structure size. The runtime signature incorporates executable mappings and backing-file metadata. Reuse also requires the stored code-buffer address to be available and the generated prologue layout to agree. Incompatible headers start a fresh cache; an unavailable required address or incompatible prologue can stop startup. Per-block guest-byte checks are a further condition, not a substitute for FastDyn's instrumentation fingerprint.

This is a local executable build artifact. Keep it with the exact runtime and workload that produced it; it is not a portable firmware cache for distribution across machines or arbitrary plugins.

## Flat mode and lifecycle limits

Start with `supercache_flat = false`. Set it to `true` only for an experiment whose executable guest memory remains immutable for the entire run. Restored flat-mode blocks bypass the normal interval tree, page lists, and QEMU hash table. That shortcut removes bookkeeping that writable executable code and self-modifying firmware need.

The backend chooses its index from the **span of cached guest PCs**, not the ELF file's byte size:

| Cached PC span | Flat index |
| --- | --- |
| Up to 32 MiB | Direct index, with one 32-bit slot per byte of span |
| More than 32 MiB, up to 512 MiB | Paged index with compact per-page lookup tables |
| More than 512 MiB | Rejected in flat mode; use normal mode |

Both modes force single-threaded TCG. `split-wx=on` is incompatible. QEMU takes a nonblocking exclusive lock on the cache file; use a separate cache path and work directory for each worker, and avoid sharing a cache between concurrent FastDyn launches that could invalidate it before QEMU acquires the lock.

Each newly translated block persists its native bytes and a committed record, then updates the header. Normal process exit synchronizes the file. Record checksums and bounds checks allow invalid records to be ignored, but the implementation does not establish a general crash-consistent snapshot guarantee.

A QEMU translation flush preserves the persistent allocation state and makes cached blocks eligible for lazy validation and relinking. Cache capacity is not managed as an eviction queue: exhaustion terminates with a diagnostic while preserving cached translations. The reviewed FastDyn frontend exposes the cache path and flat flag, not a TOML cache-capacity setting. Stop users of the cache before removing its `.sc` file and companion manifest to force a fresh population.

## Measure the optimization you need

Use the correctness and completion criteria from [Performance and benchmarking](../analysis/performance.md). Compare at least three conditions on the same builds and firmware: caching disabled, caching enabled with an empty cache, and repeated launches with a populated cache. Keep execution inputs and instrumentation constant within each condition. Switching flat mode changes the fingerprint and requires a new warmup.

Measure full launch-to-completion wall time separately from the fixture's `benchmark_start`/`benchmark_end` interval. Startup, preprocessing, native-code restoration, metadata reconstruction, and file writes may fall outside a selected guest interval. A tiny fixture proves the workflow more readily than it predicts the benefit for a long boot sequence.

Record host and guest architecture, both source revisions, plugin build options, completion condition, cache mode, cache capacity, repetition count, and timing distribution. Check that cold and warm runs reach the same guest outputs and end state. Keep the cache and manifest unchanged between warm samples; avoid rebuilding or touching tracked native artifacts between them. This backend does not expose a FastDyn cache-hit counter, so neither a populated file nor a shorter isolated sample establishes a hit rate or a universal speedup.

The preview includes six frontend unit tests covering unchanged-input reuse, flat-option generation, instrumentation changes, scalar plugin-option changes, native-plugin rebuilds, and an existing cache without a manifest. They were inspected for this chapter, not executed here. They verify invalidation policy; they do not by themselves qualify cached native execution, a custom plugin, or a complete flight mission.

## Source guide

- [Current-main QEMU build and ordered patch selection](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/scripts/setup/qemu.sh), alongside [current-main launch construction](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/src/fastdyn/targets/qemu_target.py)
- [Preview setup flags](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/setup.sh), [QEMU setup and compatibility patch handling](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/scripts/setup/qemu.sh), and [bundled minimal fixture](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/configs/minimal.toml)
- [Frontend fingerprint, invalidation, and launch inputs](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/src/fastdyn/targets/qemu_target.py), [TOML validation](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/src/fastdyn/toml_parser.py), and [frontend unit assertions](https://github.com/boardrunner2049/FastDyn/blob/0e13b73986a66270a6d8452b2c0147af7b874d29/tests/unit/test_supercache.py)
- [Persistent cache, keys, records, compatibility, and flat lookup](https://github.com/boardrunner2049/qemu/blob/12f5e68807650822d3edb7e1073f524e0262bec7/tcg/supercache.c)
- [Plugin metadata reconstruction for restored blocks](https://github.com/boardrunner2049/qemu/blob/12f5e68807650822d3edb7e1073f524e0262bec7/accel/tcg/plugin-gen.c#L649-L739)
- [Backend accelerator contract](https://github.com/boardrunner2049/qemu/blob/12f5e68807650822d3edb7e1073f524e0262bec7/qemu-options.hx#L276-L298), [accelerator setup](https://github.com/boardrunner2049/qemu/blob/12f5e68807650822d3edb7e1073f524e0262bec7/accel/tcg/tcg-all.c), and [ASLR prerequisite check](https://github.com/boardrunner2049/qemu/blob/12f5e68807650822d3edb7e1073f524e0262bec7/system/main.c)

