# Run a function without booting the firmware

**Status: proposed reusable workflow.** FastDyn already supplies execution-control hooks, host analyses, guest state access, and device models. A general function-context planner and a packaged function-execution virtual are not part of the documented main interface.

The intended workflow starts the guest at a chosen function with explicitly prepared state. It does not require running the entire firmware first and taking a snapshot after boot. This makes small, repeatable experiments possible when normal startup is expensive, depends on missing hardware, or would change state that the experiment wants to control.

## Two execution changes, one preparation problem

The runtime needs two essential capabilities: select the initial execution point, and install a virtual at the first instruction that supplies the planned context before the original instruction executes. A target adapter establishes whatever architectural startup state must exist even before that callback can run safely. The setup hook is one-shot for a trial and explicitly rearmed for the next trial; recursive calls or ordinary re-entry must not reinitialize the live stack and globals.

The substantial work happens beforehand. Preparation must determine and construct the arguments, stack, reachable memory, static state, and external dependencies needed by the selected function. Reusing the existing virtual machinery keeps the execution mechanism small while allowing the planner to become more capable over time.

No new function-run CLI option is specified here. An implementation should first add a reviewed generic entry-point capability where needed and a feature-owned preparation/runtime pair, using FastDyn's existing public interfaces.

## Keep the image available to its callees

Calling one function does not mean loading only that function's bytes. Its ordinary callees and referenced data can remain mapped from the firmware image and execute normally. The planner should account for dependencies transitively, including indirect calls when their targets can be determined.

| Dependency | Preparation or runtime treatment |
| --- | --- |
| Function arguments | Populate registers and stack using the selected ABI |
| Ordinary direct callees | Keep their code mapped and execute them normally |
| Static globals | Initialize from the image's load/initialization semantics |
| Zero-initialized storage | Establish the required zeroed regions explicitly |
| Objects and pointer graphs | Construct valid reachable storage and target addresses |
| Boot-derived state | Supply a declared state or run a specifically selected initializer |
| Allocators | Execute a modeled allocator or intercept through an explicit contract |
| RTOS services | Supply the required task/service context or a documented interception |
| I/O | Use FastDyn's device and physics handlers |
| Unknown dependency | Report the unresolved requirement or require an explicit model |

A loader's view of ELF segments is not always equivalent to running embedded startup copy tables. The planner must know the relationship between initial image bytes and runtime data addresses. It should retain provenance for values it copied, zeroed, synthesized, or received from the user.

## Conservative analysis with visible assumptions

Host analysis can identify symbols, fixed globals, constant structure offsets, candidate memory accesses, and some call relationships. It cannot generally infer every valid runtime pointer or the meaning of a state machine from a binary.

A conservative plan can include extra mapped data and candidate callees. It should not turn an unknown pointer into a fabricated valid object without recording that decision. Distinguish recovered image facts, declared experiment inputs, and unresolved dependencies in the plan.

This is especially important for indirect calls, function pointers, C++ objects, interrupt-driven buffers, and inputs whose initialization depends on prior protocol exchanges. The useful output is a reviewable context that supports the selected execution, not a claim to recreate every possible boot state.

## Return and repetition

The harness should give the target a valid return destination, observe its return values, and transfer control back to the experiment driver using the existing execution-control mechanisms. The return destination can be a deliberate sentinel or parent route defined by the target adapter; it must obey the ABI and avoid executing unmapped memory.

For repeated invocations, reset the state that belongs to the trial: registers, stack, selected globals, heap allocations, model state, queued events, and any coupled physics state. A CPU-only reset is insufficient if the first call changed a peripheral FIFO or plant state.

Some experiments deliberately carry state between calls. Make that a named experiment policy and record which state persists. The function runner should not guess whether two calls represent independent tests or successive steps of one scenario.

## Keep I/O with its existing owner

The function plugin should use FastDyn's existing I/O infrastructure. It should not grow a second register model, device dispatcher, or physics loop just because the guest starts at a function rather than a reset handler.

For example, a control function that reads a sensor through an existing peripheral model can keep using that model. A function that consumes already prepared sensor data can receive that data through its context. These are different experiment boundaries and should be described as such.

## Architecture and correctness

The generic planner should work with target descriptions. Per-target adapters own argument passing, stack alignment, return-address setup, initial execution mode, and special-register rules. ARM link registers and Thumb addresses are one case; a stack-based return address or an RV64 ABI requires different setup.

A useful first validation set contains a leaf function, a function with ordinary callees, a static global, a pointer/object input, an allocator dependency, and an I/O interaction. For each, show the supplied context, expected observable result, and behavior on missing dependencies. When comparing against a booted execution, compare the relevant initial state explicitly rather than assuming both contexts are equivalent.

## Existing foundations

- [Public preparation contexts](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/src/fastdyn/virtual_preprocessing.py)
- [Host-analysis API](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/HostAnalysisAPI.md)
- [Guest state and execution-control SDK](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/include/fastdyn_runtime.h)
- [Current modifiers and virtuals](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/docs/VirtualsAndModifiers.md)
- [Device-model infrastructure](https://github.com/boardrunner2049/FastDyn/blob/f9666d7f518c373e89831d8e14a6371a27fe6436/device_models/dev.c)
