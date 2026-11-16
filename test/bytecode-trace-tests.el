;;; bytecode-trace-tests.el --- ERT tests for the bytecode tracer -*- lexical-binding: t; -*-

;; Run with:  make test
;; These all skip (rather than fail) on an unpatched Emacs, so the
;; suite is runnable from day one.

(require 'ert)
(require 'bytecode-trace)

(defun bct-test--add3 (x)
  "Tiny function to hand-count via `disassemble'."
  (+ x 3))

(ert-deftest bct-primitives-exist ()
  "The patched build exposes all four primitives."
  (skip-unless (fboundp 'bytecode-trace-start))
  (should (fboundp 'bytecode-trace-stop))
  (should (fboundp 'bytecode-trace-reset))
  (should (fboundp 'bytecode-trace-counts)))

(ert-deftest bct-counts-match-hand-count ()
  "THE sanity check: tracer count = hand count from `disassemble'.
Milestone 2 gate — nothing downstream is trustworthy until this passes."
  (skip-unless (fboundp 'bytecode-trace-start))
  (byte-compile 'bct-test--add3)
  ;; Hand count: run (disassemble 'bct-test--add3), count the
  ;; instructions executed on the straight-line path, put it here.
  (let ((expected-ops :TODO-hand-count)
        (counts (with-bytecode-trace (bct-test--add3 4))))
    (let ((entry (assq 'bct-test--add3 counts)))
      ;; TODO: the key may be the bytecode object rather than the
      ;; symbol, depending on your attribution design — adjust.
      (should entry)
      (should (equal (cadr entry) expected-ops)))))

(ert-deftest bct-cons-counting ()
  "A function that conses N times reports N conses."
  (skip-unless (fboundp 'bytecode-trace-start))
  (let ((f (byte-compile (lambda (n) (let (acc)
                                       (dotimes (i n) (push i acc))
                                       acc)))))
    (let ((counts (with-bytecode-trace (funcall f 100))))
      ;; TODO: find f's entry and assert conses >= 100 (exactly 100 if
      ;; nothing else in the body conses).
      (should counts))))

(ert-deftest bct-nonlocal-exit-restores-attribution ()
  "After a `throw' out of a traced function, later counts still
attribute to the right function (record_unwind_protect works)."
  (skip-unless (fboundp 'bytecode-trace-start))
  ;; TODO: call a byte-compiled function that throws, catch it, then
  ;; run bct-test--add3 and check its counts land on bct-test--add3.
  (should t))

(provide 'bytecode-trace-tests)
;;; bytecode-trace-tests.el ends here
