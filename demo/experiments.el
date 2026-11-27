;;; experiments.el

;; Run with:  make demo

(require 'bytecode-trace)
(require 'bytecomp)

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
    (let ((byte-compile-warnings nil))
      (byte-compile-file src))
    (load (concat (file-name-sans-extension src) ".elc") nil t)))

(defun bct--total (counts)
  "Sum (OPS . CONSES) over a COUNTS alist."
  (let ((ops 0) (conses 0))
    (dolist (e counts)
      (setq ops (+ ops (cadr e))
            conses (+ conses (cddr e))))
    (cons ops conses)))

(defun bct--cell (label fn term expected)
  "Trace one run of FN on TERM, check the result, print LABEL's row."
  (let (result)
    (let* ((counts (with-bytecode-trace (setq result (funcall fn term))))
           (tot (bct--total counts)))
      (unless (equal (p-ch result) expected)
        (error "%s: wrong answer %S (wanted %S)" label (p-ch result) expected))
      (message "  %-34s %12d bytecodes %10d conses" label (car tot) (cdr tot)))))

;; Terms: Church-numeral arithmetic from the midterm test suite.
;;   arith = 2^3 * 3        (pure arithmetic, no recursion combinator)
;;   fact4 = factorial 4    (Y combinator, deep recursion)
;; Both normalize to the numeral 24.
(defun bct--terms ()
  `(("arith (2^3*3)" . ,(app l-mult (app l-pow Ch-2 Ch-3) Ch-3))
    ("fact4"         . ,(app factorial Ch-4))))

(defun bct-experiment-recursion ()
  "Experiment 1: recursive vs tail-recursive evaluation (lexical)."
  (message "-- recursive vs tail-recursive (lexical binding) --")
  (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo"))
  (dolist (term (bct--terms))
    (bct--cell (format "%s  recursive" (car term)) #'lc-eval (cdr term) 24)
    (bct--cell (format "%s  tail-recursive" (car term)) #'lc-eval-tco (cdr term) 24)))

(defun bct-experiment-binding ()
  "Experiment 2: lexical vs dynamic binding (recursive evaluator)."
  (message "-- lexical vs dynamic binding (recursive evaluator) --")
  (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo"))
  (let ((terms (bct--terms)))                ; build terms once, lexical build
    (dolist (term terms)
      (bct--cell (format "%s  lexical" (car term)) #'lc-eval (cdr term) 24))
    (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo") 'dynamic)
    (dolist (term terms)
      (bct--cell (format "%s  dynamic" (car term)) #'lc-eval (cdr term) 24))))

(defun bct--determinism-check ()
  "Same term, same counts, run to run — the tracer's selling point."
  (bct--compile-and-load (expand-file-name "lambda-calc.el" "demo"))
  (let* ((term (cdar (bct--terms)))
         (a (bct--total (with-bytecode-trace (lc-eval term))))
         (b (bct--total (with-bytecode-trace (lc-eval term)))))
    (unless (equal a b)
      (error "counts not deterministic: %S vs %S" a b))
    (message "-- determinism: two runs gave identical counts %S --" a)))

(defun bct-run-all-experiments ()
  "Entry point for `make demo'."
  (message "== Elisp bytecode tracer: experiments ==")
  (bct--determinism-check)
  (bct-experiment-recursion)
  (bct-experiment-binding))

(provide 'experiments)
;;; experiments.el ends here
