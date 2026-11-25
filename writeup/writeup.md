# A Bytecode-Level Tracer for the Emacs Lisp VM

*CS58 final project*

## 1. Survey: how Emacs code gets profiled today, and what's missing

Emacs ships with a surprising number of performance tools for a text
editor. None of them can answer the question this project is about:
*exactly how many bytecode instructions did function F execute, and how
many cons cells did it allocate?* This section goes through each tool,
what it actually measures, and why it falls short of that question.

### profiler.el — the sampling profiler

`M-x profiler-start` is the modern, built-in profiler. It works by
sampling: a timer fires roughly every millisecond (`profiler-sampling-interval`,
in CPU time), and on each tick the profiler records the current Lisp
backtrace. The report is a call tree weighted by how many samples landed
in each function. It also has a memory mode that records backtraces at
allocation points.

Sampling is the right design for finding hotspots in big programs with
low overhead, but it is statistical by construction. A function that
runs for 50 microseconds per call will be invisible unless it is called
enough times that samples happen to land in it, and two runs of the same
program produce different numbers. The memory profiler reports bytes
observed at sampled allocation events, not a complete per-function
count. For comparing two implementations of the same small function —
the whole point of this project — sample counts are too noisy to
interpret, and "0 samples vs 1 sample" tells you nothing.

### elp.el — the instrumenting profiler

`elp-instrument-function` wraps a function so every call records
wall-clock time and bumps a call counter. Unlike the sampler it is
exact about *call counts*, but the thing it measures per call is time,
which is noisy (GC pauses, other processes, CPU frequency scaling) and
gets distorted by the instrumentation itself: the wrapper's own overhead
is significant relative to a small function's body, which is exactly the
regime our experiments live in. It measures nothing about allocation.

### benchmark-run and benchmark.el

`(benchmark-run N FORM)` evaluates a form N times and reports elapsed
time, GC runs, and GC time. This is the standard tool for A/B timing
comparisons at the REPL, and it's what you'd normally reach for to
compare two evaluators. But it is whole-expression only — there is no
per-function breakdown — and it is still time, so runs have to be
repeated and averaged, and small differences drown in noise.

### memory-use-counts and cons-cells-consed

The C core keeps global counters of every object ever allocated, by
type; `memory-use-counts` returns them and `cons-cells-consed` is the
cons one. These are exact and deterministic — the right *kind* of
number — but global. You can bracket a form with two reads and subtract
to get "this form consed K cells," which is effectively benchmark-style
whole-expression granularity. There is no way to attribute the K cells
to the functions that allocated them. This project is, in a sense, the
per-function version of these counters.

### trace.el

`trace-function` logs every call and return of a function with its
arguments and nesting depth. Useful for understanding control flow, but
it counts nothing — turning the log into counts means post-processing,
and it still gives no instruction or allocation information.

### disassemble

`M-x disassemble` prints a function's compiled bytecode. This is the
static side of the picture: you can see what instructions *could*
execute and hand-simulate small cases. What it can't tell you is what
*did* execute — how many iterations a loop ran, which branches were
taken, how counts scale with input. It is, however, the perfect
validation oracle for a dynamic tracer: for a straight-line function the
hand count from the disassembly must equal the traced count exactly,
and we use that as the correctness gate for the whole project.

### byte-code-meter — the closest ancestor

Buried in `bytecode.c` is `BYTE_CODE_METER`, a compile-time option (off
by default, and off in every distributed build) that makes the VM count
executed opcodes into a global histogram keyed by opcode pairs. It's
the closest thing to this project in spirit — exact instruction counts
from inside the dispatch loop — but it aggregates globally per opcode,
with no per-function attribution and nothing about allocation. It also
forces the VM into its slower switch-based dispatch mode. Its existence
is encouraging, though: the instrumentation point this project uses is
one Emacs developers have reached for before.

### Summary

| Tool | Exact? | Per-function? | Instructions? | Allocation? |
| --- | --- | --- | --- | --- |
| profiler.el | no (sampled) | yes | no | bytes, sampled |
| elp.el | calls yes, time no | yes | no | no |
| benchmark-run | no (time) | no | no | GC runs only |
| memory-use-counts | yes | no | no | yes, global |
| trace.el | n/a | yes | no | no |
| disassemble | static only | yes | static listing | no |

No row has "yes" across the board. The gap is a tool that is exact,
per-function, and counts both instructions executed and cons cells
allocated. That combination is what makes clean comparisons of
evaluation strategies possible: the numbers are deterministic, so a
single run is the answer, and ratios between two implementations mean
something. The rest of this writeup describes a tracer built into the
VM's dispatch loop and allocator that provides exactly that.

## 2. Design

*(TODO — instrumentation points, current-function tracking, data model.)*

## 3. Evaluation

*(TODO — sanity check vs. disassemble; recursive vs. tail-recursive;
lexical vs. dynamic binding. One table, exact counts.)*

## 4. Limitations and future work

*(TODO — undercounted conses outside Fcons, native-comp bypass,
stretch goals.)*
