;;; lambda-calc.el --- Lambda-calculus interpreter (from the midterm) -*- lexical-binding: t; -*-

;; TODO: paste your midterm interpreter here.
;;
;; The experiment harness (experiments.el) expects two entry points —
;; rename these to match your actual code, or adjust experiments.el:
;;
;;   (lc-eval TERM ENV)       ; plain recursive evaluator
;;   (lc-eval-tco TERM ENV)   ; tail-recursive evaluator
;;
;; Keep both evaluators in this one file so a single byte-compilation
;; covers both, and the lexical-vs-dynamic experiment can recompile the
;; whole thing with `lexical-binding' flipped.

(defun lc-eval (term env)
  "Evaluate TERM in ENV, plain recursive style."
  (error "TODO: paste midterm evaluator"))

(defun lc-eval-tco (term env)
  "Evaluate TERM in ENV, tail-recursive style."
  (error "TODO: paste midterm evaluator"))

(provide 'lambda-calc)
;;; lambda-calc.el ends here
