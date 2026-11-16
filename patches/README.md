# patches/

`make patch` writes `bytecode-tracing.patch` here — the full diff of your
changes inside `emacs/`. Since `emacs/` itself is gitignored, this file
IS the record of the C work: export early, export often.

Re-apply onto a fresh checkout with:

```sh
cd emacs && git apply ../patches/bytecode-tracing.patch
```
