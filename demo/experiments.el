;;; experiments.el --- Tracer experiments on the lambda-calculus interpreter -*- lexical-binding: t; -*-

;; Run with:  make demo
;; Each experiment byte-compiles the code under test (native-comp is
;; disabled in this build, so byte-compiled code is what the VM runs),
;; traces one run, and prints a small table.

(require 'bytecode-trace)

(defun bct--compile-and-load (file &optional dynamic)
  "Byte-compile FILE and load the .elc.
With DYNAMIC non-nil, compile it as a dynamic-binding file by
stripping the lexical-binding cookie into a temp copy."
  (let ((src file))
    (when dynamic
      (setq src (make-temp-file "bct-dyn-" nil ".el"))
      (with-temp-file src
        (insert-file-contents file)
        (goto-char (point-min))
        (when (re-search-forward "lexical-binding: *t" (line-end-position) t)
          (replace-match "lexical-binding: nil"))))
    (byte-compile-file src)
    (load (concat (file-name-sans-extension src) ".elc") nil t)))

(defun bct--total (counts)
  "Sum (OPS . CONSES) over a COUNTS alist."
  (let ((ops 0) (conses 0))
    (dolist (e counts)
      (setq ops (+ ops (cadr e))
            conses (+ conses (cddr e))))
    (cons ops conses)))

(defun bct--report-line (label counts)
  (let ((tot (bct--total counts)))
    (message "%-28s %12d bytecodes %12d conses" label (car tot) (cdr tot))))

;; TODO: a term big enough to produce meaningful counts — e.g.
;; Church-numeral arithmetic from the midterm test suite.
(defvar bct-test-term nil
  "The lambda-calculus term every experiment evaluates.")

(defun bct-experiment-recursion ()
  "Experiment 1: recursive vs tail-recursive evaluation."
  (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo"))
  (bct--report-line "recursive"
                    (with-bytecode-trace (lc-eval bct-test-term nil)))
  (bct--report-line "tail-recursive"
                    (with-bytecode-trace (lc-eval-tco bct-test-term nil))))

(defun bct-experiment-binding ()
  "Experiment 2: lexical vs dynamic binding."
  (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo"))
  (bct--report-line "lexical"
                    (with-bytecode-trace (lc-eval bct-test-term nil)))
  (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo") 'dynamic)
  (bct--report-line "dynamic"
                    (with-bytecode-trace (lc-eval bct-test-term nil))))

(defun bct-run-all-experiments ()
  "Entry point for `make demo'."
  (message "== Elisp bytecode tracer: experiments ==")
  (bct-experiment-recursion)
  (bct-experiment-binding))

(provide 'experiments)
;;; experiments.el ends here
