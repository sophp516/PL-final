# Hacking notes: where to edit in the Emacs tree

Verified against the actual `emacs-30.1` checkout (commit 8ac894e,
"Release Emacs 30.1"). Line numbers are from that tag.

## Big finding: the VM already tracks the current function

The plan assumed we'd need our own "current function" global plus
`record_unwind_protect`. Not so in Emacs 30. The VM keeps its own frame
stack (`struct bc_frame`, bytecode.c:376) inside a per-thread buffer,
and `bc->fp->fun` is always the currently executing bytecode object:

- `setup_frame` (bytecode.c:484) pushes a frame and sets `fp->fun = fun`.
- `Breturn` (bytecode.c:882) pops it.
- Bytecode→bytecode calls to lexbound closures don't recurse into
  `exec_byte_code` at all — `Bcall` has a fast path that does
  `goto setup_frame` (bytecode.c:806). Dynbound closures and subrs go
  through `funcall_general`, which re-enters `exec_byte_code` and
  pushes a frame the same way.
- Non-local exits are already handled: `struct handler` saves `act_rec`
  (= `bc->fp`) at catch entry (eval.c:1760) and `eval.c:1359` restores
  it on unwind. So `throw`/`signal` keep `fp->fun` correct for free.

So the current function is just `current_thread->bc.fp->fun`
(`get_act_rec` in lisp.h:5290). No new tracking code, no unwind-protect.
The bottom dummy frame is zeroed by `init_bc_thread` and is the only
frame with `saved_fp == NULL` — check that before trusting `fp->fun`,
and attribute allocation outside any bytecode to a "no bytecode" bucket
(or skip it).

## src/bytecode.c — counting bytecodes

- Signature in 30.1:
  `exec_byte_code (Lisp_Object fun, ptrdiff_t args_template, ptrdiff_t nargs, Lisp_Object *args)`
  (args_template is a ptrdiff_t bitfield now, not a Lisp object).
- Dispatch is threaded on this build: `BYTE_CODE_THREADED` is defined
  whenever `__GNUC__` is (bytecode.c:51), and clang defines it. With
  threading there is no per-instruction trip around the `while (true)`
  loop — `NEXT` is `goto *(targets[op = FETCH])` (bytecode.c:568) and
  jumps case-to-case directly. So the increment must go in `NEXT`
  (and `FIRST`, which is just `NEXT` in threaded mode). In the
  switch build, `NEXT` is `break` and the fetch is the single
  `op = FETCH` at the loop top (bytecode.c:552) — increment there.
  Every executed instruction passes through exactly one FIRST/NEXT
  dispatch, so this counts instructions exactly. Don't instrument
  `FETCH` itself — it's also used for operand bytes.
- Precedent: `BYTE_CODE_METER` (off by default, bytecode.c:45) is a
  compile-time global histogram of opcode pairs — right idea, but
  global and per-opcode, not per-function. Also incompatible with
  threading; ours shouldn't be.
- Register primitives in `syms_of_bytecode`: `DEFUN` + `defsubr`, and
  `staticpro` the counts hash table.
- Key the table by the closure object itself (`fp->fun`, `:test eq`);
  resolving to a symbol name is a report-time problem.
- `maybe_gc` runs inside the dispatch loop, so the table really must
  be staticpro'd before first use.

## src/alloc.c — counting conses

- `Fcons` is at alloc.c:2857. Increment the current function's cons
  counter there, guarded by the enabled flag, using
  `current_thread->bc.fp` as above. When bytecode calls a subr that
  conses, `bc->fp` still points at the bytecode caller — which is
  exactly the attribution we want.
- Better than feared: in 30.1 `list1`..`list5`, `listn`, and
  `Fmake_list` all funnel through `Fcons`, so instrumenting it catches
  essentially all list allocation reachable from Lisp. The undercount
  is limited to C code using the cons block internals directly.

## Shared state

- Flag + table live in bytecode.c; declare `extern` in lisp.h so
  alloc.c sees them. Counters as `EMACS_INT`; build the alist of
  fixnums inside the `bytecode-trace-counts` DEFUN.
