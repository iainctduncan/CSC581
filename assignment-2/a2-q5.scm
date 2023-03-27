(post "a2-q5.scm")

(define sr 44100)

; fill with one period of a sine
(define (fill-sine buffer amp frq)
  "fill a named buffer with a sine"
  (dotimes (i (buffer-size buffer))
    (bufs buffer i 
      (* amp 
        (sin (* i (/ 
          ; full circle is 2 pi radians
          (* 2.0 pi) 
          ; number of samples a complete period takes is sr / frq
          (/ sr frq))))))))

; fill sine*, uses phase
(define (fill-sine* buffer amp frq phase)
  "fill a named buffer with a sine"
  (let* ((radians-per-cycle  (* 2 pi))
         (samples-per-cycle  (/ sr frq))
         ; radians-per-sample is the phase increment per sample in radians
         (radians-per-sample (/ radians-per-cycle samples-per-cycle))
         (phase-in-radians   (* phase radians-per-cycle)) 
         )
    (dotimes (sample-index (buffer-size buffer))
      (bufs buffer sample-index
        (* amp 
          ; sample-index * radians-per-sample = phase for smp in radians
          ; to adjust phase, add phase offset in radians
          (sin (+ phase-in-radians (* sample-index radians-per-sample))))))))

; add a sinusoid to a named buffer
(define (add-sine buffer amp frq phs)
  (let* ((radians-per-cycle  (* 2 pi))
         (samples-per-cycle  (/ sr frq))
         (radians-per-sample (/ radians-per-cycle samples-per-cycle))
         (phase-in-radians   (* phs radians-per-cycle)))
    (dotimes (sample-index (buffer-size buffer))
      (let* ((new-smp (* amp (sin (+ phase-in-radians 
                                  (* sample-index radians-per-sample)))))
             (prv-smp (bufr buffer sample-index))
             (out-smp (+ new-smp prv-smp)))
        (bufs buffer sample-index out-smp)))))       


(define (clear-buf buffer)
  (dotimes (i (buffer-size buffer))
    (bufs buffer i 0)))

(define (fill-additive buffer base-frq partials)
  (clear-buf buffer) 
  (let ((amp-offset (/ 1.0 (length partials))))
    (dolist (partial partials)
      (let ((frq (* base-frq (partial 0)))
            (amp (partial 1))
            (phs (partial 2)))
        (add-sine buffer amp frq phs)))))


(define (main)
  (define amps   (map (lambda(x)(random 0.5)) (range 0 3)))
  (define phases (map (lambda(x)(random 1.0)) (range 0 3)))
  (post "amps:" amps "phases:" phases)

  (fill-additive 'buf-1 100 `((1 ,(amps 0) ,(phases 0))))
  (fill-additive 'buf-2 100 `((1 0 0) (2 ,(amps 1) ,(phases 1))))
  (fill-additive 'buf-3 100 `((1 0 0) (2 0 0) (3 ,(amps 2) ,(phases 2))))
  (fill-additive 'buf-4 100 `((1 ,(amps 0) ,(phases 0)) (2 ,(amps 1) ,(phases 1)) (3 ,(amps 2) ,(phases 2))))

  ;(post "dot product with sine at 100hz:" (buf-sin-dp 'buf-4 100))
  ;(post "dot product with sine at 200hz:" (buf-sin-dp 'buf-4 200))
  ;(post "dot product with sine at 300hz:" (buf-sin-dp 'buf-4 300))

  (post "done"))

