(post "helpers.scm")

; utility functions that have not yet made it into s74

; this needs to be smarter!
(define (symbol-append . args)
  (symbol (apply string-append (map symbol->string args))))


; naive version, doesn't know about keys  
(define (midi->string note-num)
  (define pitch-names (vector 
    "C ", "C#", "D ", "Eb", "E ", "F ", "F#", "G ", "Ab", "A ", "Bb", "B "))
  (let* ((octave (- (floor (/ note-num 12)) 1))
         (pitch-num (modulo note-num 12)))
    (string-append (pitch-names pitch-num) (number->string octave))))     

(define (smt seq-num . args)
  (let args-loop ((largs args))
    (let ((bbt (largs 0)) (mute-status (largs 1)))
      (at bbt (seq-mute seq-num mute-status)) 
      (if (> (length largs) 2)
        (args-loop (cddr largs))))))


(define (reset)
  (delay 10 (lambda()(send 's4m 'reset))))

; helper to increment a var up a ceiling, exclusive
(define (inc-to var up-to)
  (if (= var (- up-to 1)) 0 (+ 1 var)))

(define-macro (inc-to! var up-to)
  `(set! ,var (if (= ,var (- ,up-to 1)) 0 (+ 1 ,var))))

(define-macro (inc! var)
  "increment a variable in place"
  `(set! ,var (+ 1 ,var)))

(define-macro (dec! var)
  "decrement a variable in place"
  `(set! ,var (- ,var 1)))

(define-macro (zero! var)
  "zero a variable in place"
  `(set! ,var 0))

(define-macro (inc-or-zero! var ceiling)
  "increment a var from 0 to (ceiling - 1), wrapping to zero"
  `(set! ,var (if (< ,var (dec ,ceiling)) (inc ,var) 0)))

(define (not-null? x)
  (not (null? x)))

(define (null-or-false? x)
  (or (null? x) (not x)))

(define (not-eq? val arg)
  (not (eq? val arg)))

(define (between? val lower upper)
  (and (>= val lower) (<= val upper)))

(define (for-enum fun sequence)
  (for-each fun (range 0 (length sequence)) sequence))

(define (hash-table-set* ht . args)
  "update a hash-table from an assoc list, returns update hash"
  (let iter ((k (car args))
             (v (cadr args))
             (rest (cddr args)))  
    (set! (ht k) v)
    (if (not-null? rest) 
      (iter (car rest) (cadr rest) (cddr rest)))
    ht  
))



