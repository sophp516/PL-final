;;; bytecode-trace-tests.el --- ERT tests for the bytecode tracer -*- lexical-binding: t; -*-

;; Run with:  make test
;; These all skip (rather than fail) on an unpatched Emacs, so the
;; suite is runnable from day one.

(require 'ert)
(require 'bytecode-trace)

(defun bct-test--add3 (x)
  "Tiny function to hand-count via `disassemble'."
  (+ x 3))

(defun bct-test--entry (fn counts)
  "Return the (OPS . CONSES) entry for symbol FN in COUNTS.
The tracer keys by the byte-code object, so look up via `symbol-function'."
  (cdr (assq (symbol-function fn) counts)))

(defun bct-test--disassembly-length (fn)
  "Number of instructions in FN's disassembly."
  (with-temp-buffer
    (disassemble fn (current-buffer))
    (goto-char (point-min))
    (let ((n 0))
      (while (re-search-forward "^[0-9]+\t" nil t)
        (setq n (1+ n)))
      n)))

(ert-deftest bct-primitives-exist ()
  "The patched build exposes all four primitives."
  (skip-unless (fboundp 'bytecode-trace-start))
  (should (fboundp 'bytecode-trace-stop))
  (should (fboundp 'bytecode-trace-reset))
  (should (fboundp 'bytecode-trace-counts)))

(ert-deftest bct-counts-match-hand-count ()
  "THE sanity check: tracer count = hand count from `disassemble'.
Milestone 2 gate — nothing downstream is trustworthy until this passes.
bct-test--add3 is straight-line code, so every listed instruction
executes exactly once: 4 ops (dup / constant 3 / plus / return)."
  (skip-unless (fboundp 'bytecode-trace-start))
  (byte-compile 'bct-test--add3)
  (let* ((counts (with-bytecode-trace (bct-test--add3 4)))
         (entry (bct-test--entry 'bct-test--add3 counts)))
    (should entry)
    (should (= (car entry) 4))
    ;; Same thing, without a hard-coded number: straight-line code
    ;; executes each instruction in its disassembly exactly once.
    (should (= (car entry)
               (bct-test--disassembly-length 'bct-test--add3)))
    (should (= (cdr entry) 0))))

(ert-deftest bct-repeated-calls-accumulate ()
  "N calls of a function count N times its per-call ops."
  (skip-unless (fboundp 'bytecode-trace-start))
  (byte-compile 'bct-test--add3)
  (let* ((counts (with-bytecode-trace
                   (bct-test--add3 1) (bct-test--add3 2) (bct-test--add3 3)))
         (entry (bct-test--entry 'bct-test--add3 counts)))
    (should (= (car entry) (* 3 4)))))

(ert-deftest bct-cons-counting ()
  "A function that conses N times reports exactly N conses."
  (skip-unless (fboundp 'bytecode-trace-start))
  (let* ((f (byte-compile (lambda (n) (let (acc)
                                        (dotimes (i n) (push i acc))
                                        acc))))
         (counts (with-bytecode-trace (funcall f 100)))
         (entry (cdr (assq f counts))))
    (should entry)
    (should (= (cdr entry) 100))))

(ert-deftest bct-nested-call-attribution ()
  "Caller and callee each get their own ops across the VM's fast path."
  (skip-unless (fboundp 'bytecode-trace-start))
  (defun bct-test--callee (x) (+ x 3))
  (defun bct-test--caller (x) (bct-test--callee (bct-test--callee x)))
  (byte-compile 'bct-test--callee)
  (byte-compile 'bct-test--caller)
  (let* ((per-call (bct-test--disassembly-length 'bct-test--callee))
         (counts (with-bytecode-trace (bct-test--caller 0)))
         (callee (bct-test--entry 'bct-test--callee counts))
         (caller (bct-test--entry 'bct-test--caller counts)))
    (should (= (car callee) (* 2 per-call)))
    (should (= (car caller)
               (bct-test--disassembly-length 'bct-test--caller)))))

(ert-deftest bct-nonlocal-exit-restores-attribution ()
  "After a `throw' out of a traced function, later counts still
attribute to the right function (the VM frame stack unwinds)."
  (skip-unless (fboundp 'bytecode-trace-start))
  (defun bct-test--thrower () (throw 'bct-out nil))
  (byte-compile 'bct-test--thrower)
  (byte-compile 'bct-test--add3)
  (let* ((counts (with-bytecode-trace
                   (catch 'bct-out (bct-test--thrower))
                   (bct-test--add3 4)))
         (entry (bct-test--entry 'bct-test--add3 counts)))
    ;; add3's counts must look exactly as they do when traced alone.
    (should (= (car entry) 4))
    (should (= (cdr entry) 0))))

(provide 'bytecode-trace-tests)
;;; bytecode-trace-tests.el ends here
