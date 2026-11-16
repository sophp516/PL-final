# Hacking notes: where to edit in the Emacs tree

All paths relative to `emacs/`. Verify line details against the actual
`emacs-30.1` source — these are pointers, not gospel.

## src/bytecode.c — counting bytecodes + current-function tracking

- `exec_byte_code` is the whole VM. Its signature in Emacs 30:
  `exec_byte_code (Lisp_Object fun, Lisp_Object args_template, ptrdiff_t nargs, Lisp_Object *args)`.
- The dispatch loop: look for the `op = FETCH` / `switch (op)` in the
  `while (true)` loop. **Beware:** if `BYTE_CODE_THREADED` is defined
  (GCC computed-goto dispatch), there is no single switch — the fetch
  happens in the `NEXT` macro. Putting the increment in `NEXT` (or
  disabling threading for simplicity) covers both paths. Decide early.
- Current-function tracking: on entry, save the old "current function"
  into a local, set the global to `fun`, and register a restore with
  `record_unwind_protect` so `throw`/`signal` unwinding restores it.
  Note `exec_byte_code` re-enters itself via `funcall` on `Bcall` ops.
- Resolving the function to a nice key: `fun` is the bytecode object.
  Keying the table by the object (`:test eq`) always works; mapping to
  a symbol name is a report-time problem, not a trace-time problem.
- Register primitives at the bottom: `DEFUN` the four primitives, then
  `defsubr` each inside `syms_of_bytecode`. Global Lisp objects (the
  counts hash table) must be `staticpro`'d.

## src/alloc.c — counting conses

- `Fcons` is the single DEFUN: increment the current function's cons
  counter there, guarded by the same enabled flag.
- Other allocators (`list1`..`list5`, `Fmake_list`) do NOT all go
  through `Fcons` — they use `ALLOCATE_...` macros directly. Out of
  scope for the core project; note the undercount in the writeup.

## Shared state

- Put the flag + table + "current function" in one place (bytecode.c),
  declare `extern` in `lisp.h` so alloc.c sees them.
- Counters: use `EMACS_INT` and make table values conses of fixnums at
  report time (or keep raw C structs and build the alist in the
  `bytecode-trace-counts` DEFUN).

## Workflow

- `make build` from the project root = incremental `make -C emacs`;
  touching only bytecode.c/alloc.c/lisp.h rebuilds in seconds.
- `make patch` snapshots your diff into `patches/` — do it whenever
  something works; it's your backup and your submission artifact.
- Sanity tool: `M-x disassemble RET bct-test--add3 RET` to hand-count.
