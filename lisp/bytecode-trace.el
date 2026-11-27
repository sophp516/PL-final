;;; bytecode-trace.el

;; Front end for the C-level tracer added to bytecode.c / alloc.c.
;; Requires a patched Emacs that provides the primitives:
;;   (bytecode-trace-start) (bytecode-trace-stop)
;;   (bytecode-trace-reset) (bytecode-trace-counts)
;; where `bytecode-trace-counts' returns an alist of
;;   (FUNCTION . (OPS . CONSES))

;;; Code:

(defun bytecode-trace--check ()
  "Signal a helpful error when running an unpatched Emacs."
  (unless (fboundp 'bytecode-trace-start)
    (error "No tracer primitives in this Emacs. Run the patched build (make repl)")))

(defmacro with-bytecode-trace (&rest body)
  "Run BODY with bytecode tracing enabled; return the counts alist.
Counters are reset first, and tracing is stopped even if BODY
exits non-locally.  BODY's value is discarded; the counts are the
point."
  (declare (indent 0) (debug t))
  `(progn
     (bytecode-trace--check)
     (bytecode-trace-reset)
     (bytecode-trace-start)
     (unwind-protect
         (progn ,@body)
       (bytecode-trace-stop))
     (bytecode-trace-counts)))

(defun bytecode-trace--name-table ()
  "Map byte-code objects to the symbols that name them.
One sweep over the obarray; anonymous closures stay unmapped."
  (let ((names (make-hash-table :test 'eq)))
    (mapatoms
     (lambda (sym)
       (when (fboundp sym)
         (let ((def (symbol-function sym)))
           (when (byte-code-function-p def)
             (puthash def sym names))))))
    names))

(defun bytecode-trace--function-name (fn names)
  "Printable name for byte-code object FN, using the NAMES table."
  (let ((sym (gethash fn names)))
    (if sym
        (symbol-name sym)
      (let ((s (prin1-to-string fn)))
        (if (> (length s) 40)
            (concat (substring s 0 37) "...")
          s)))))

(defun bytecode-trace--rows (counts)
  "Convert COUNTS alist into `tabulated-list-entries' rows."
  (let ((names (bytecode-trace--name-table)))
    (mapcar (lambda (entry)
              (let ((fn (car entry))
                    (ops (cadr entry))
                    (conses (cddr entry)))
                (list fn (vector (bytecode-trace--function-name fn names)
                                 (number-to-string ops)
                                 (number-to-string conses)))))
            ;; Sort by bytecode count, descending.
            (sort (copy-sequence counts)
                  (lambda (a b) (> (cadr a) (cadr b)))))))

(define-derived-mode bytecode-trace-report-mode tabulated-list-mode "ByteTrace"
  "Major mode for viewing per-function bytecode trace counts."
  (setq tabulated-list-format
        [("Function" 40 t)
         ("Bytecodes" 12 nil :right-align t)
         ("Conses" 12 nil :right-align t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun bytecode-trace-report (&optional counts)
  "Show a sorted per-function report of the current trace COUNTS.
Interactively, uses whatever the counters currently hold."
  (interactive)
  (bytecode-trace--check)
  (let ((counts (or counts (bytecode-trace-counts))))
    (with-current-buffer (get-buffer-create "*bytecode-trace*")
      (bytecode-trace-report-mode)
      (setq tabulated-list-entries (bytecode-trace--rows counts))
      (tabulated-list-print)
      (pop-to-buffer (current-buffer)))))

(provide 'bytecode-trace)
;;; bytecode-trace.el ends here
