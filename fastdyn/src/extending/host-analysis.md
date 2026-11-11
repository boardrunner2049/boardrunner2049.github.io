# Reusable host analysis

`fastdyn.host` gives plugins and standalone tools a common way to inspect firmware before execution. It supplies image bytes, symbols, function ranges, supported DWARF queries, instruction facts, address resolution, and shared RTOS marker data. Multiple preprocessors examining the same image can reuse this work instead of loading and interpreting the ELF independently.

The API shares **facts**. A plugin still decides what to instrument, what a result means, and how its runtime manifest should look. Function Counter selects functions; ObjectSan selects objects and allocation sites; Courbet validates its firmware-specific hooks. Sharing the underlying symbol and image services does not move those policies into the generic frontend.

## Open a standalone session

With FastDyn's Python environment activated, this example reads the bundled Zephyr ELF from the repository root:

```python
from fastdyn.host import AnalysisSession

with AnalysisSession.open(
    "tests/binaries/rtos/zephyr.elf",
    architecture="arm",
    instruction_mode="thumb-mclass",
) as analysis:
    for function in list(analysis.symbols.function_ranges())[:5]:
        print(
            function.name,
            hex(function.start),
            function.size,
            function.range_provenance,
        )
```

Opening a session resolves the path but does not immediately parse ELF or DWARF. Services are loaded when requested. A context manager closes the session's resources at the end.

During normal FastDyn preparation, use `RunContext.analysis` or `VirtualContext.analysis`. FastDyn manages a run-scoped pool keyed by the resolved firmware path, architecture, and instruction mode. Repeated requests for that image/target reuse the session, and cleanup closes the pool after plugin cleanup callbacks.

## Service reference

| Service | Useful operations | Result contract |
| --- | --- | --- |
| `analysis.image` | `read(address, size)`, `read_bytes(address, size)` | Load-segment reads, with optional file/zero-fill provenance |
| `analysis.symbols` | `all()`, `find()`, `lookup()` | Defined symbols with target-aware code addresses |
| `analysis.symbols` | `function_ranges()`, `containing_function(address)` | Function extents with explicit or inferred provenance |
| `analysis.dwarf` | `global_variable(path)` and supported type/member queries | Fixed-address globals and constant layouts; unknown information remains explicit |
| `analysis.decoder` | `instructions(address, size)`, `return_sites(start, size)` | Cached instruction facts for the supported decoder target |
| `resolve_address(token, symbols)` | Numeric values and `symbol+/-offset` | Shared address-expression primitive |
| `RTOS_SIGNATURES`, `RTOS_HINT_MARKERS`, `identify_rtos()` | Shared markers and strong-signature detection | Reusable evidence with separate consumer thresholds |

`LoopFinder`, `next_pcs`, and `mmiofinder` retain their existing APIs. They are specialized analyses, not aliases for a universal analysis service or an automatic MMIO optimizer.

## Symbols: distinguish code from data

Use a function symbol's `code_address` for a hook and an object symbol's `address` for a data access. In an ARM `thumb-mclass` session, function addresses are normalized to remove the Thumb state bit. Odd data addresses remain odd, and address zero remains a valid value.

`lookup()` is deliberately singular. It raises `SymbolNotFoundError` for a missing symbol and `AmbiguousSymbolError` when distinct definitions remain. Use `find()` for a plural query or qualify a lookup by kind/address. Selecting the first result silently would conceal a choice that belongs to the consumer.

Some ELF functions have zero size. The index can infer their extent from the next function or the end of the same executable section. Check `range_provenance` before treating such an extent as authoritative compiler information.

## Image bytes and layout evidence

`analysis.image.read()` returns both bytes and provenance. Reads can be `file`, `zero-fill`, or `mixed`. A load segment's zero-filled tail is available only within that segment's memory extent. A read does not continue into unrelated file data merely because the requested address fits a numerical range.

This matters when validating an instruction: zero-filled memory is useful for representing a segment, but it is not evidence that an instruction encoding existed in the file. Consumers that require original instruction bytes should require `source == "file"`. Invalid, truncated, unmapped, or overflowing requests raise `ImageAddressError`.

DWARF support is similarly bounded. The API follows qualifiers and typedefs, resolves fixed `DW_OP_addr` globals and nested constant member paths, and handles supported constant member-offset encodings. It does not evaluate arbitrary expressions, dynamic locations, location lists, or bit-field layouts. Unknown sizes are represented as unknown, not guessed as four bytes.

Courbet's richer GDB-based C++ layout verification remains specialized. A narrower shared query is not a behavior-equivalent replacement for that workflow.

## Instruction decoding has an explicit target

The current shared decoder accepts `architecture="arm"` with `instruction_mode="thumb-mclass"`. Unsupported combinations raise `UnsupportedTargetError`. Its instruction records include address, size, mnemonic, operands, memory-transfer information, direct targets when recognized, and recognized return forms.

Image, symbol, and DWARF services can serve other compatible ELF targets without invoking this decoder. Select properties that match the actual image; the architecture family `arm` alone is not a request to treat every image as Cortex-M.

ObjectSan keeps operand-specific propagation logic local while using shared decoding. VariableWatch and ObjectSan reuse conservative candidate-memory-access analysis. Unresolved pointer flow remains a candidate rather than becoming evidence of irrelevance.

## Use it inside a plugin

The following is a `prepare()` method excerpt for a registered run preprocessor. It discovers a function through the shared service and returns a plugin-owned hook:

```python
from fastdyn.machine import VirtualInstruction
from fastdyn.virtual_preprocessing import RunPrepareResult


def prepare(self, ctx):
    function = ctx.analysis.symbols.lookup("main", kind="function")
    manifest = ctx.plugin_artifact_path("entry.tsv")
    manifest.write_text(
        f"0x{function.code_address:x}\t{function.name}\n",
        encoding="utf-8",
    )
    return RunPrepareResult(
        virtuals=[VirtualInstruction(
            at=function.code_address,
            instruction="entry_probe_hit",
            args=[],
        )],
        artifacts=[manifest],
    )
```

The plugin must separately register and implement `entry_probe_hit`; see [writing plugins](virtual-plugins.md). The shared session never stores this mutable hook plan.

## Reuse extends into physics, with clear ownership

The same principle applies beyond firmware ELF analysis:

| Reused behavior | Current owner | What stays specialized |
| --- | --- | --- |
| `modelDescription.xml` metadata parsing | `fastdyn.fmu_metadata.parse_model_description()` | Required vehicle variables, packaging/extraction policy, model execution, and physics state |
| Coverage block and growth parsing | `utils/coverage_helpers.py` | Plotting, report formats, and presentation |
| Common ELF reads and symbols used by Courbet | `fastdyn.host`, with compatibility adapters | Firmware profiles, target ABI validation, live GDB queries, and hook policy |
| Device description lookup | Existing SVD/configuration helpers | Configuration-generation choices and model behavior |

The FMU metadata parser returns FMI version, a validated model identifier when available, an instantiation token, and variable/value-reference metadata. It is a domain-local shared parser, not a reason to import FMI, Gazebo, or physics state into `fastdyn.host`.

## Session lifetime and errors

A session treats its image as immutable. It does not poll or hash the file to notice replacements. Open a new session after rebuilding the firmware; do not reuse stale analysis indexes. Runtime mutations to guest memory are not updates to the host image's cached facts.

Public analysis errors derive from `HostAnalysisError`, including `ImageAddressError`, `SymbolNotFoundError`, `AmbiguousSymbolError`, `DwarfQueryError`, and `UnsupportedTargetError`. Handle these at the consumer boundary with the configuration key or requested analysis in the diagnostic.

## Source guide

- [Public analysis exports](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/host/__init__.py)
- [Lazy sessions and pool identity](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/host/session.py)
- [Shared decoder and supported target](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/host/decode.py)
- [Image, symbol, DWARF, and failure contracts](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisAPI.md)
- [Reusable versus specialized analysis inventory](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisMigration.md)
- [Shared FMU metadata parser](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/fmu_metadata.py)
