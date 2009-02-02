;;;; chicken-thread-object-primitive-inlines.scm
;;;; Kon Lovett, Jan '09

;;;; Provides inlines & macros for thread objects
;;;; MUST be included
;;;; NEEDS "chicken-primitive-inlines" included

;;; Mutex object helpers:

;; Mutex layout:
;
; 0     Tag - 'mutex
; 1     Name (object)
; 2     Thread (thread or #f)
; 3     Waiting threads (FIFO list)
; 4     Abandoned? (boolean)
; 5     Locked? (boolean)
; 6     Specific (object)

(define-inline (%mutex? x)
  (%structure-instance? x 'mutex) )

(define-inline (%mutex-name mx)
  (%structure-ref mx 1) )

(define-inline (%mutex-thread mx)
  (%structure-ref mx 2) )

(define-inline (%mutex-thread-set! mx th)
  (%structure-slot-set! mx 2 th) )

(define-inline (%mutex-thread-clear! mx)
  (%structure-immediate-set! mx 2 #f) )

(define-inline (%mutex-waiters mx)
  (%structure-ref mx 3) )

(define-inline (%mutex-waiters-set! mx wt)
  (%structure-slot-set! mx 3 wt) )

(define-inline (%mutex-waiters-add! mx th)
  (%mutex-waiters-set! mx (%append-item (%mutex-waiters mx) th)) )

(define-inline (%mutex-waiters-delete! mx th)
  (%mutex-waiters-set! mx (##sys#delq th (%mutex-waiters mx))) )

(define-inline (%mutex-waiters-empty? mx)
  (%null? (%mutex-waiters mx)) )

(define-inline (%mutex-waiters-forget! mx)
  (%structure-immediate-set! mx 3 '()) )

(define-inline (%mutex-waiters-pop! mx)
  (let* ([wt (%mutex-waiters mx)]
         [top (%car wt)])
    (%mutex-waiters-set! mx (%cdr wt))
    top ) )

(define-inline (%mutex-abandoned? mx)
  (%structure-ref mx 4) )

(define-inline (%mutex-abandoned-set! mx f)
  (%structure-immediate-set! mx 4 f) )

(define-inline (%mutex-locked? mx)
  (%structure-ref mx 5) )

(define-inline (%mutex-locked-set! mx f)
  (%structure-immediate-set! mx 5 f) )

(define-inline (%mutex-specific mx)
  (%structure-ref mx 6) )

(define-inline (%mutex-specific-set! mx x)
  (%structure-slot-set! mx 6 x) )


;;; Thread object helpers:

;; Thread layout:
;
; 0     Tag - 'thread
; 1     Thunk (procedure)
; 2     Results (list-of object)
; 3     State (symbol)
; 4     Block-timeout (fixnum or #f)
; 5     State buffer (vector)
;       0       Dynamic winds (list)
;       1       Standard input (port)
;       2       Standard output (port)
;       3       Standard error (port)
;       4       Exception handler (procedure)
;       5       Parameters (vector)
; 6     Name (object)
; 7     Reason (condition of #f)
; 8     Mutexes (list-of mutex)
; 9     Quantum (fixnum)
; 10    Specific (object)
; 11    Block object (thread or (pair-of fd io-mode))
; 12    Recipients (list-of thread)
; 13    Unblocked by timeout? (boolean)

(define-inline (%thread? x)
  (%structure-instance? x 'thread) )

(define-inline (%thread-thunk th)
  (%structure-ref th 1) )

(define-inline (%thread-thunk-set! th tk)
  (%structure-slot-set! th 1 tk) )

(define-inline (%thread-results th)
  (%structure-ref th 2) )

(define-inline (%thread-results-set! th rs)
  (%structure-slot-set! th 2 rs) )

(define-inline (%thread-state th)
  (%structure-ref th 3) )

(define-inline (%thread-state-set! th st)
  (%structure-slot-set! th 3 st) )

(define-inline (%thread-block-timeout th)
  (%structure-ref th 4) )

(define-inline (%thread-block-timeout-set! th to)
  (%structure-immediate-set! th 4 to) )

(define-inline (%thread-block-timeout-clear! th)
  (%thread-block-timeout-set! th #f) )

(define-inline (%thread-state-buffer th)
  (%structure-ref th 5) )

(define-inline (%thread-state-buffer-set! th v)
  (%structure-slot-set! th 5 v) )

(define-inline (%thread-name th)
  (%structure-ref th 6) )

(define-inline (%thread-reason th)
  (%structure-ref th 7) )

(define-inline (%thread-reason-set! th cd)
  (%structure-slot-set! th 7 cd) )

(define-inline (%thread-mutexes th)
  (%structure-ref th 8) )

(define-inline (%thread-mutexes-set! th wt)
  (%structure-slot-set! th 8 wx) )

(define-inline (%thread-mutexes-empty? th)
  (%null? (%thread-mutexes th)) )

(define-inline (%thread-mutexes-forget! th)
  (%structure-immediate-set! th 8 '()) )

(define-inline (%thread-mutexes-add! th mx)
  (%thread-mutexes-set! th (%cons mx (%thread-mutexes th))) )

(define-inline (%thread-mutexes-delete! th mx)
  (%thread-mutexes-set! th (##sys#delq mx (%thread-mutexes th))) )

(define-inline (%thread-quantum th)
  (%structure-ref th 9) )

(define-inline (%thread-quantum-set! th qt)
  (%structure-immediate-set! th 9 qt) )

(define-inline (%thread-specific th)
  (%structure-ref th 10) )

(define-inline (%thread-specific-set! th x)
  (%structure-slot-set! th 10 x) )

(define-inline (%thread-block-object th)
  (%structure-ref th 11) )

(define-inline (%thread-block-object-set! th x)
  (%structure-slot-set! th 11 x) )

(define-inline (%thread-block-object-clear! th)
  (%structure-immediate-set! th 11 #f) )

(define-inline (%thread-recipients th)
  (%structure-ref th 12) )

(define-inline (%thread-recipients-set! th x)
  (%structure-slot-set! th 12 x) )

(define-inline (%thread-recipients-add! th rth)
  (%thread-recipients-set! t (%cons rth (%thread-recipients t))) )

(define-inline (%thread-recipients-forget! th)
  (%structure-immediate-set! th 12 '()) )

(define-inline (%thread-recipients-process! th tk)
  (let ([rs (%thread-recipients t)])
    (unless (%null? rs) (for-each tk rs) ) )
  (thread-recipients-forget! t) )

(define-inline (%thread-unblocked-by-timeout? th)
  (%structure-ref th 13) )

(define-inline (%thread-unblocked-by-timeout-set! th f)
  (%structure-immediate-set! th 13 f) )


;;; Condition-variable object:

;; Condition-variable layout:
;
; 0     Tag - 'condition-variable
; 1     Name (object)
; 2     Waiting threads (FIFO list)
; 3     Specific (object)

(define-inline (%condition-variable? x)
  (%structure-instance? x 'condition-variable) )

(define-inline (%condition-variable-name cv)
  (%structure-ref cv 1) )

(define-inline (%condition-variable-waiters cv)
  (%structure-ref cv 2) )

(define-inline (%condition-variable-waiters-set! cv x)
  (%structure-slot-set! cv 2 x) )

(define-inline (%condition-variable-waiters-add! cv th)
  (%condition-variable-waiters-set! cv (%append-item (%condition-variable-waiters cv) th)) )

(define-inline (%condition-variable-waiters-delete! cv th)
  (%condition-variable-waiters-set! cv (##sys#delq th (%condition-variable-waiters cv))) )

(define-inline (%condition-variable-waiters-empty? mx)
  (%null? (%condition-variable-waiters mx)) )

(define-inline (%condition-variable-waiters-pop! mx)
  (let* ([wt (%condition-variable-waiters mx)]
         [top (%car wt)])
    (%condition-variable-waiters-set! mx (%cdr wt))
    top ) )

(define-inline (%condition-variable-waiters-clear! cv)
  (%structure-immediate-set! cv 2 '()) )

(define-inline (%condition-variable-specific cv)
  (%structure-ref cv 3) )

(define-inline (%condition-variable-specific-set! cv x)
  (%structure-slot-set! cv 3 x) )