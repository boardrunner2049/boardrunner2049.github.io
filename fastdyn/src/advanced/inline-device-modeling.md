# Inline device modeling

FastDyn can install a small host-memory operation at a selected guest instruction. For a simple modeled register, this can move the value transfer into translated execution and avoid the ordinary device callback. The current interface is deliberately manual: supply a `finline` access map, identify the guest register, and separately arrange for the original MMIO instruction to be skipped when the inline operation replaces it.

This chapter inspects FastDyn **`5b8bf3ddb01d63a4d5f86701d358e390a950cb9c`**, its pinned QEMU dependency **`99b54836ded8dc3271eba52deee7453efc0a13b9`**, and the accompanying FastDyn patches. It extends [Device models](../devices/device-models.md) and [Virtual instructions and modifiers](../instrumentation/virtuals-and-modifiers.md). The automatic model analyzer described in [Automatically accelerate MMIO](../designs/automatic-mmio.md) remains a proposal.

## What the current path provides

`[Machine].finline` names a text file. FastDyn forwards that path to the native plugin, which parses the file once and looks up each instruction PC during translation. A matching row installs `QEMU_PLUGIN_INLINE_LOAD_IO` or `QEMU_PLUGIN_INLINE_STORE_IO` against a host address.

The backing allocation is currently one global array:

```c
char gpio_memory[0x400];
```

Every selected site uses `&gpio_memory[offset]`. Despite its name, the array does not implement GPIO register semantics. It is a zero-initialized, 1 KiB block in the plugin process. It is shared by the installed inline sites, not created separately for each device or CPU.

This is also distinct from a configured `[Memory.main]` or additional RAM bank. Setting `backend = "file"` and `share = true` shares guest RAM through its backing file; it does not relocate `gpio_memory` or connect it to an elder model. The public `FdModel` descriptor does not currently expose a way to bind an instance's state to this inline allocation.

That makes the existing path useful for controlled register-state experiments and for studying which operations can move out of device dispatch. A general peripheral optimization needs an explicit common state representation first.

## The access-map contract

Each accepted row has five whitespace-separated fields:

```text
0x0800000e W state 0x000 0x0
0x08000010 R state 0x000 0x2
```

| Field | Meaning |
| --- | --- |
| PC | Exact guest instruction address, parsed as hexadecimal |
| Direction | `R`/`READ` or `W`/`WRITE`, case-insensitively |
| Device label | Parsed name, currently unused for selecting backing state |
| Offset | Hexadecimal byte offset into `gpio_memory` |
| Register | Hexadecimal target-backend register slot |

Use explicit hexadecimal spelling throughout. For ARM `r10`, the register field is `0xa`; a bare `10` is parsed as hexadecimal 16. A Thumb instruction's address is its actual even PC, not the odd function-pointer representation.

The first matching row for a PC wins. There is no width, effective-address guard, CPU selector, reset value, or side-effect description in the format. Different labels with the same offset refer to the same bytes. Invalid rows are skipped, and failure to open the file is logged without making this parser terminate the run. Check the file and the resulting behavior before relying on it, particularly if a PC modifier would still skip an access when its map row is missing.

Use `finline = "None"` to disable the map. The native disabled-value check also accepts empty, `null`, `false`, and `0` spellings. Relative map paths are passed through to QEMU, so the examples below run from the FastDyn repository root.

## Replacement requires two operations

At an instruction, the relevant native registration order is:

1. Coverage and register logging.
2. A configured virtual callback.
3. Inline I/O.
4. Modifiers.
5. Legacy detour handling.

The QEMU inline-I/O helpers only generate host loads and stores. **They do not remove the guest instruction.** Without an additional control-flow change, a guest load can overwrite the supplied value and a guest store still performs its original access.

For the ARM32 example below, a modifier writes the address of the following instruction into `r15`. The pinned ARM backend updates the PC and exits the translation block. Because the inline operation was registered first, the intended sequence is the host-memory transfer followed by the PC change; execution resumes after the original MMIO instruction.

The replacement is appropriate only when it represents all relevant instruction behavior. A simple unconditional word load into a general register is a manageable starting point. An instruction with base-register writeback, multiple transfers, conditional execution, an IT block, sign extension, exclusive-access semantics, or a fault that matters to the experiment needs additional reasoning and support. Skipping it would also skip those effects.

Ordering matters for ordinary register changes too. A modifier setting `r0` at a store site runs after the inline store has sampled `r0`. Set the input at an earlier site. A `printreg` virtual at an inline load site runs before that load; observe the result at the next instruction. Avoid placing required updates after a PC-redirection modifier, which exits the block.

## A small ARM32 lab

The following is a **newly constructed, source-reviewed lab recipe**, not a shipped nonempty-`finline` integration test. It was not executed while writing this chapter. It compares a one-word elder model with the manual inline path using the same tiny firmware. The expected output follows from the reviewed implementation; verify it on your build before using the recipe as evidence.

Prerequisites are a Linux x86_64 host, FastDyn's Python environment and native plugin with device-model support, the pinned patched `qemu-system-arm`, and GNU Arm Embedded `arm-none-eabi-as`, `arm-none-eabi-ld`, and `arm-none-eabi-objdump`. The guest is Cortex-M3 in Thumb state. No C runtime, physical board, or FMU is involved.

Use the host dependencies described in [Installation](../getting-started/installation.md), but select this chapter's source revision explicitly. The core installation walkthrough uses an earlier book baseline. For a separate lab checkout:

```bash
git clone https://github.com/boardrunner2049/FastDyn.git FastDyn-inline-lab
cd FastDyn-inline-lab
git checkout --detach 5b8bf3ddb01d63a4d5f86701d358e390a950cb9c
source ./setup.sh --build-qemu
```

An existing checkout at that exact revision is also suitable. Use its matching built plugin and patched QEMU throughout the comparison; record the Arm binutils version along with the firmware disassembly.

### Create and inspect the firmware

From the FastDyn root:

```bash
mkdir -p out/inline-state
cat > out/inline-state/demo.S <<'ASM'
.syntax unified
.cpu cortex-m3
.thumb
.section .vectors, "a"
.word 0x20010000
.word 0x08000009
.text
.global reset
.thumb_func
reset:
    movs r0, #42
    movs r1, #0x40
    lsls r1, r1, #24
    str.n r0, [r1]
    ldr.n r2, [r1]
    nop
1:  b.n 1b
ASM

cat > out/inline-state/demo.ld <<'LD'
ENTRY(reset)
SECTIONS {
  . = 0x08000000;
  .vectors : { *(.vectors) }
  .text : { *(.text*) }
}
LD

arm-none-eabi-as -mcpu=cortex-m3 \
  out/inline-state/demo.S -o out/inline-state/demo.o
arm-none-eabi-ld -T out/inline-state/demo.ld \
  out/inline-state/demo.o -o out/inline-state/demo.elf
arm-none-eabi-objdump -d out/inline-state/demo.elf

fastdyn build-model tests/models/elder_echo.c \
  -o out/inline-state/models --no-vio
```

Verify that the store is at `0x0800000e`, the load at `0x08000010`, the `nop` at `0x08000012`, and the final branch at `0x08000014`. Both memory instructions must be two-byte encodings. The firmware sets `r1` to `0x40000000`, writes 42, then reads the same word into `r2`. If your disassembly differs, update the vector, map, triggers, and next-PC values together.

### Establish ordinary device behavior

Save this complete configuration as `out/inline-state/baseline.toml`:

```toml
[Memory.main]
id = "ram0"
base_address = "0x20000000"
memory_size = "512K"
backend = "ram"
share = false

[Machine]
platform = "generic-cortexm"
enable_gdb = false
stop_on_start = false
monitor_port = 0
qmp_socket = "/tmp/fastdyn-inline-state.qmp"
log_options = "none"
coverage = false
finline = "None"

[[CPU.cpu0]]
arch = "arm"
machine = "cortexm"
cpu = "cortex-m3"
plugin_library = "build/libfastdyn.so"
binary = "out/inline-state/demo.elf"
init_nsvtor = "0x08000000"

[[CPU.cpu0.virtuals]]
at = "0x08000008"
instruction = "benchmark_start"

[[CPU.cpu0.virtuals]]
at = "0x08000012"
instruction = "printreg"
args = ["2"]

[[CPU.cpu0.virtuals]]
at = "0x08000014"
instruction = "benchmark_end"
args = ["inline-state"]

[Device.Models.elder]

[Device.state]
ranges = [["0x40000000", "0x4000000f"]]
reset = 0

[[Device.state.handlers]]
model = "elder"
enabled = true
scroll = "out/inline-state/models/elder_echo.so"
```

Run it:

```bash
fastdyn -q run -c out/inline-state/baseline.toml \
  -o out/inline-state/baseline-run
```

The shipped echo model stores and returns its data word at offset zero. The expected functional observation is:

```text
Reg 2:0x0000002a
```

A `[BENCH][inline-state]` line follows and ends QEMU. Here that line is a completion marker; its elapsed time is not a comparative performance result. The baseline's `io.log` should record the store and load through elder.

### Install the manual replacement

Create `out/inline-state/accesses.txt` with the two map rows shown earlier. Copy `baseline.toml` to `inline.toml`, replace its existing `finline` setting with:

```toml
finline = "out/inline-state/accesses.txt"
```

Append these two modifiers to `inline.toml`:

```toml
[[CPU.cpu0.modifiers]]
at = "0x0800000e"
patch = "r15 <- 0x08000010"

[[CPU.cpu0.modifiers]]
at = "0x08000010"
patch = "r15 <- 0x08000012"
```

Run the second configuration separately:

```bash
test -s out/inline-state/accesses.txt
fastdyn -q run -c out/inline-state/inline.toml \
  -o out/inline-state/inline-run
```

The expected register output is again 42, now transferred through the shared inline word. Those two original MMIO transactions should no longer appear in device dispatch's `io.log`. Inspect the generated `virtuals/modifiers.txt` and `virtuals/virtuals.txt` if the register value or termination differs.

This compares two independently initialized implementations of one word. Keeping elder configured in the inline run does **not** synchronize its private state with `gpio_memory`: elder's data word remains at its reset value. An unmodified third access to the same register would take the ordinary path and could see different state. That is why a partial optimization requires a common backing-state contract, not just matching addresses and return values.

## Keep the ordinary path available deliberately

An instruction without a map row retains its ordinary execution. Its MMIO follows the configured QEMU/FastDyn device route described in [Device models](../devices/device-models.md). That gives a manual way to leave FIFO operations, commands, interrupts, and external I/O in a full model.

There is no generated runtime guard in the current `finline` format. A selected PC always uses its configured host offset, even if the guest instruction's effective address changes between visits. Neither a different device label nor a failed semantic assumption triggers an automatic fallback. Only select sites whose address and behavior you have established.

Similarly, normal device routing is not a general ordered chain of models. Dynamic ranges are first-match; configure ownership explicitly. A `classic` fallback currently returns zero on reads and ignores writes. It does not provide coherence with the inline array or complete peripheral semantics.

## Architecture and state invariants

The ARM32 helpers use `tcg_gen_ld_i32` and `tcg_gen_st_i32`: a native 32-bit host transfer, independent of the original instruction's width. For this path, keep offsets four-byte aligned and in `0x000..0x3fc`, and use suitable general-register slots. The parser does not validate register bounds or allocation bounds. Byte loads, halfword stores, signed extension, and endian conversion are not inferred from the guest instruction.

FastDyn supports several guest architectures, but this particular primitive is not one uniform portable contract. The pinned [x86 backend](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/target/i386/tcg/translate.c) uses target-word loads and stores. The [RISC-V backend](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/target/riscv/translate.c) defines a store helper but no corresponding load override; the generic load helper is a no-op. The ARM32 helper does not establish an AArch64 `xN` implementation. Port this experiment only after reviewing the target's helpers and PC-update behavior.

Before extending the lab, preserve these invariants:

| Concern | Required decision |
| --- | --- |
| Exactly one operation | Either execute the original access or perform a complete replacement; avoid duplicate effects |
| Shared state | Every participating fast and ordinary path must use the same authoritative state |
| Device side effects | Preserve read-to-clear, write masks, FIFO movement, IRQ changes, and scheduling, or leave the operation ordinary |
| Observation | A bypassed MMIO does not call `virtual_notify_mmio`, the device logger, or its trace/replay handler |
| Time and interrupts | Compare virtual-time progress and IRQ ordering under the same instruction-count and timer policy |
| Reset | The inline array is host state; guest RAM restoration does not automatically restore it |
| Concurrency | One global array has no per-device isolation or synchronization protocol for concurrent writers |
| Translation lifetime | Host addresses and site bindings must remain valid while generated code can use them |

Fresh process launches initialize the array again. In-process fuzzing resets, device resets, and coordinated physical-model restoration need an explicit state policy. Do not treat a successful guest-only snapshot restore as evidence that the inline model also returned to its initial state.

## Discovery, browser flags, and evidence

The CLI's **inline device-model browser** is a terminal interface for discovering configuration forms. Its name does not select inline execution:

```bash
fastdyn help device-models --browse
fastdyn help device-models --no-browse
fastdyn help modifiers --no-browse
```

Interactive browsing defaults on when stdin and stdout are terminals. `--browse` forces the picker and `--no-browse` prints the catalog. These flags do not enable `finline`, discover MMIO sites, or rewrite models.

The shipped `configs/minimal.toml` uses the current machine/CPU schema with `finline` disabled. The older `configs/inline_classic_config.toml` contains placeholder paths and earlier schema placement; use it as historical context rather than a ready-to-run configuration.

`find_mmio_accesses()` is a separate Capstone-based ARM32/ARM64 heuristic. The current launcher does not call it when `finline` is set. It does not analyze model callbacks, prove all possible effective addresses, bind elder state, or create the required replacement policy. Its `MMIOAccess.size` is the instruction's encoding length, not the memory transaction width. Its existing test depends on an optional firmware path and checks discovery, not inline-runtime equivalence.

There is no dedicated nonempty-`finline` integration test in this reviewed checkout. A useful validation campaign would extend the lab with boundary offsets, changed values, deliberate ordinary-path accesses, conditional instructions that remain unoptimized, observer behavior, and repeated resets. Compare outcomes and model transitions before measuring dispatch reduction. Include the cost of PC redirection and translation-block exits in that measurement. The proposed automatic optimizer should produce and validate these decisions; the current manual feature makes them the experiment author's responsibility.

## Source guide

- [FastDyn access-map parser, backing array, registration order, and modifiers](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/core/core.c)
- [Pinned QEMU ARM32 load/store and PC-update helpers](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/target/arm/tcg/translate.c)
- [Pinned QEMU callback injection and generic helper defaults](https://github.com/boardrunner2049/qemu/blob/99b54836ded8dc3271eba52deee7453efc0a13b9/accel/tcg/plugin-gen.c)
- [Ordinary device dispatch and MMIO observation](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/device_models/dev.c)
- [Echo model used by the lab's baseline](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/tests/models/elder_echo.c)
- [Launcher forwarding of the manual map](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/src/fastdyn/targets/qemu_target.py)
- [Discovery helper and its separate analysis contract](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/src/fastdyn/binary/mmiofinder.py)
- [Device-model and modifier browser flags](https://github.com/boardrunner2049/FastDyn/blob/5b8bf3ddb01d63a4d5f86701d358e390a950cb9c/src/fastdyn/main.py)
