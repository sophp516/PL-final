;;; lambda-calc.el  -*- lexical-binding: t -*-

(require 'cl-lib)

(setq max-lisp-eval-depth (max max-lisp-eval-depth 20000))


;;;; Conversion to canonical form: curry, De Bruijn, re-associate

(defun curry-lambda (exp)
  (cond
   ((atom exp) exp)
   ((eq (car exp) 'lambda)
    (let ((params (cadr exp))
          (body (caddr exp)))
      (if (cdr params)
          (list 'lambda (list (car params))
                (curry-lambda (list 'lambda (cdr params) body)))
        (list 'lambda params (curry-lambda body)))))
   (t (mapcar #'curry-lambda exp))))

(defun de-bruijn-helper (exp bindings)
  (cond
   ((symbolp exp)
    (let ((pos (cl-position exp bindings)))
      (if pos (1+ pos) exp)))
   ((atom exp) exp)
   ((eq (car exp) 'lambda)
    (let ((params (cadr exp)))
      (list 'lambda
            (de-bruijn-helper
             (caddr exp)
             (cons (if params (car params) (make-symbol "_")) bindings)))))
   (t (mapcar (lambda (e) (de-bruijn-helper e bindings)) exp))))

(defun conv-de-bruijn (exp)
  (de-bruijn-helper exp nil))

(defun re-associate (exp)
  (cond
   ((atom exp) exp)
   ((eq (car exp) 'lambda)
    (cons 'L (re-associate (cadr exp))))
   (t (cl-reduce #'cons (mapcar #'re-associate exp)))))

(defun to-l-exp (exp)
  (re-associate (conv-de-bruijn (curry-lambda exp))))


;;;; Beta reduction

(defun lambdap (l-exp)
  (and (consp l-exp) (eq 'L (car l-exp))))

(defun l-shift (l-exp by cutoff)
  (cond
   ((numberp l-exp) (if (> l-exp cutoff) (+ l-exp by) l-exp))
   ((lambdap l-exp) (cons 'L (l-shift (cdr l-exp) by (1+ cutoff))))
   ((consp l-exp) (cons (l-shift (car l-exp) by cutoff)
                        (l-shift (cdr l-exp) by cutoff)))
   (t l-exp)))

(defun l-subst (l-exp arg depth)
  (cond
   ((numberp l-exp)
    (cond
     ((= l-exp depth) (if (= depth 1) arg (l-shift arg (1- depth) 0)))
     ((> l-exp depth) (1- l-exp))
     (t l-exp)))
   ((lambdap l-exp) (cons 'L (l-subst (cdr l-exp) arg (1+ depth))))
   ((consp l-exp) (cons (l-subst (car l-exp) arg depth)
                        (l-subst (cdr l-exp) arg depth)))
   (t l-exp)))

(defun b-reduce (l-fun arg)
  (l-subst (cdr l-fun) arg 1))


;;;; Evaluator 1: plain recursion (the midterm's simplify-step)

(defun simplify-step (l-exp full-eval)
  (if (consp l-exp)
      (let ((car-exp (simplify-step (car l-exp) nil))
            (cdr-exp (cdr l-exp)))
        (if (lambdap car-exp)
            (simplify-step (b-reduce car-exp cdr-exp) full-eval)
          (cons (simplify-step car-exp full-eval)
                (if full-eval
                    (simplify-step (simplify-step cdr-exp nil) t)
                  cdr-exp))))
    l-exp))

(defun lc-eval (term)
  "Fully beta-reduce TERM, plain recursive style."
  (simplify-step term t))


;;;; Evaluator 2: tail-recursive (explicit continuation stack)

;; Same reductions as simplify-step, defunctionalized: one driver loop,
;; a value register, and a stack of frames saying what to do with the
;; value.  Frame tags:
;;   1 (orig full)  got whnf of (car orig); beta-reduce or keep walking
;;   2 (orig full)  got simplified car; handle the cdr
;;   3 (a)          got lazily simplified cdr; fully simplify it
;;   4 (a)          got fully simplified cdr; rebuild the cons
(defun lc--tco-drive (exp full)
  (let ((mode 'eval) (e exp) (fl full) (k nil) (v nil) (done nil))
    (while (not done)
      (if (eq mode 'eval)
          (if (consp e)
              (progn (push (list 1 e fl) k)
                     (setq e (car e) fl nil))
            (setq v e mode 'ret))
        (if (null k)
            (setq done t)
          (let* ((frame (pop k))
                 (tag (car frame)))
            (cond
             ((eq tag 1)
              (let ((orig (nth 1 frame)) (full2 (nth 2 frame)))
                (if (lambdap v)
                    (setq e (b-reduce v (cdr orig)) fl full2 mode 'eval)
                  (push (list 2 orig full2) k)
                  (setq e v fl full2 mode 'eval))))
             ((eq tag 2)
              (let ((orig (nth 1 frame)) (full2 (nth 2 frame)))
                (if full2
                    (progn (push (list 3 v) k)
                           (setq e (cdr orig) fl nil mode 'eval))
                  (setq v (cons v (cdr orig)) mode 'ret))))
             ((eq tag 3)
              (push (list 4 (nth 1 frame)) k)
              (setq e v fl t mode 'eval))
             ((eq tag 4)
              (setq v (cons (nth 1 frame) v) mode 'ret)))))))
    v))

(defun lc-eval-tco (term)
  "Fully beta-reduce TERM with an explicit stack, constant Lisp depth."
  (lc--tco-drive term t))


;;;; Term builders and Church-numeral IO

(defun Lx (f) (cons 'L f))

(defun app (&rest all) (cl-reduce #'cons all))

(defun l-def (exp &rest deps)
  (simplify-step (apply #'app (to-l-exp exp) deps) t))

(defun to-church (n)
  (let ((body 1))
    (dotimes (_ n)
      (setq body (cons 2 body)))
    (Lx (Lx body))))

(defun p-ch (l-exp)
  (let ((e-exp (simplify-step l-exp t))
        (n 0))
    (if (and (lambdap e-exp) (lambdap (cdr e-exp)))
        (let ((body (cddr e-exp)))
          (while (and (consp body) (eql (car body) 2))
            (setq n (1+ n)
                  body (cdr body)))
          (if (eql body 1) n 'Not-a-Church-Num))
      'Not-a-Church-Num)))


;;;; The combinators the experiment terms need

(defvar Ch-0 (to-church 0))
(defvar Ch-1 (to-church 1))
(defvar Ch-2 (to-church 2))
(defvar Ch-3 (to-church 3))
(defvar Ch-4 (to-church 4))

(defvar l-succ  (l-def '(lambda (n f x) (f (n f x)))))
(defvar l-zerop (l-def '(lambda (n) (n (lambda (x a b) b) (lambda (a b) a)))))
(defvar l-plus  (l-def '(lambda (m n f x) (m f (n f x)))))
(defvar l-mult  (l-def '(lambda (m n f) (m (n f)))))
(defvar l-pow
  (l-def '(lambda (zerop m n)
            ((zerop m)
             ((zerop n) (lambda (x) x) (lambda (f x) (n m f x)))
             (lambda (f x) (n m f x))))
         l-zerop))

(defvar l-cons (Lx (Lx (Lx (app 1 3 2)))))
(defvar l-car (l-def '(lambda (p) (p (lambda (a b) a)))))
(defvar l-cdr (l-def '(lambda (p) (p (lambda (a b) b)))))

(defvar sai
  (l-def '(lambda (cons cdr succ p) (cons (cdr p) (succ (cdr p))))
         l-cons l-cdr l-succ))

(defvar l-pred
  (l-def '(lambda (car cons sai zero n) (car (n sai (cons zero zero))))
         l-car l-cons sai Ch-0))

(defvar l-if (l-def '(lambda (b x y) (b x y))))

(defvar Y
  (Lx (app (Lx (app 2 (app 1 1)))
           (Lx (app 2 (app 1 1))))))

(defvar factorial
  (app Y (l-def '(lambda (if zerop mult pred one f n)
                   (if (zerop n) one (mult n (f (pred n)))))
                l-if l-zerop l-mult l-pred Ch-1)))

(provide 'lambda-calc)
;;; lambda-calc.el ends here
