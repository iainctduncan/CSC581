(post "a2-q4.scm")

(define sr 44100)

; fill with one period of a sine
(define (fill-sine buffer amp frq)
  "fill a named buffer with a sine"
  (dotimes (i (buffer-size buffer))
    (bufs buffer i 
      (* amp 
        (sin (* i (/ (* 2.0 pi) (/ sr frq))))))))

; add a sinusoid to a named buffer
(define (add-sine buffer amp frq)
  (dotimes (i (buffer-size buffer))
    (let* ((new-smp (* amp (sin (* i (/ (* 2.0 pi) (/ sr frq))))))
           (prv-smp (bufr buffer i))
           (out-smp (+ new-smp prv-smp)))
      (bufs buffer i out-smp))))       

(define (clear-buf buffer)
  (dotimes (i (buffer-size buffer))
    (bufs buffer i 0)))

(define (fill-additive buffer base-frq partials)
  (clear-buf buffer) 
  (let ((amp-offset (/ 1.0 (length partials))))
    (dolist (partial partials)
      (let ((frq (* base-frq (partial 0)))
            (amp (partial 1)))
        ;(add-sine buffer (* amp amp-offset) frq)))))
        (add-sine buffer amp frq)))))


; get the dot-product for a buffer and a given sinusoid
(define (buf-sin-dp buffer sin-frq)
  (define sum 0)
  (let ((buf-size (buffer-size buffer)))
    (dotimes (i buf-size)
      (let* ((sin-val (sin (* i (/ (* 2.0 pi) (/ sr sin-frq)))))
             (buf-val (bufr buffer i))
             (prod (* sin-val buf-val)))
        (set! sum (+ sum prod))))
    (/ sum buf-size)
    ))

(define (buf-buf-dp buf-1 buf-2)
  (define sum 0)
  (let ((buf-size (buffer-size buf-1)))
    (dotimes (i buf-size)
      (set! sum (+ sum (* (bufr buf-1 i) (bufr buf-2 i)))))
    (/ sum buf-size)))


(define (main)
  (define amps (map (lambda(x)(random 0.5)) (range 0 3)))
  (post "our random amps:" amps)

  (fill-additive 'buf-1 100 `((1 ,(amps 0))))
  (fill-additive 'buf-2 100 `((1 0) (2 ,(amps 1))))
  (fill-additive 'buf-3 100 `((1 0) (2 0) (3 ,(amps 2))))
  (fill-additive 'buf-4 100 `((1 ,(amps 0)) (2 ,(amps 1)) (3 ,(amps 2))))

  (post "dot product with sine at 100hz:" (buf-sin-dp 'buf-4 100))
  (post "dot product with sine at 200hz:" (buf-sin-dp 'buf-4 200))
  (post "dot product with sine at 300hz:" (buf-sin-dp 'buf-4 300))

  (post "done"))

