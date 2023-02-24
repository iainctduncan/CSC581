(post "a2-a7.scm scale loader")

(define (play-cps frq dur)
  "play a note of given cps and duration"
  (post "play-note")
  ; send messages to the Max objects ID'd by scripting names
  (send 'saw frq)
  (send 'adsr 1)
  (delay dur (lambda ()(send 'adsr 0))))

(define (et->cps base steps degree)
  "return the cps given base, steps/oct, and scale degree"
  (* base (expt 2 (/ degree steps))))

(define (play-scale steps)
  (for-each 
    (lambda (step)
      (let ((cps    (et->cps 110 steps (+ 1 step)))
            (at-ms  (* step 500)))
        (delay at-ms (lambda()(play-cps cps 400)))))
    (range 0 (+ 1 steps))))
        

