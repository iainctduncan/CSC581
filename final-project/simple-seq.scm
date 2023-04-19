; example of a simple sequencer with four ptracks, but no separate ptrack loop controls

(define (simple-seq name . init-args)

  (let ((playing? #f)             ; flag for if on or not (regardless of how clocked) 
        (delay-handle #f)         ; handle for self-scheduling
        (step-index 0)            ; step index within full pattern

        ; ordered list of the state keys for serialization
        (meta-keywords '(
          :channel :params :steps :step-dur :loop-len
        '))

        ; settings hash-table, holds serializable settings
        (_  (hash-table         
          :params         8     ; number of param tracks 
          :steps          128   ; number of steps in a sequence
          :step-dur       120   ; step-duration in ticks
          :loop-len       #f    ; if set, is length of loops in steps, if #f, loop is length of sequence vector
          :channel        0     
          :seq-data       #f    ; sequence data, will be multi-dimensional vector 
          :time-factor    1     ; a multipler for the sequencers conception of time
          )))          

    (define env (curlet))

    ; default play-note method, intent is that this is commonly overridden
    ; this calls the external note-output function
    (define (play-note step-data)
      (let* ((gate     (step-data 0))
             (dur      (step-data 1))
             (note-num (step-data 2))
             (vel      (step-data 3))
            )
        ; gate off or note-num zero (or #f) always means no output
        (if (and gate note-num (> note-num 0))
            ;(post "chord-seq output:" transposed-note vel-out dur-out)
            ; call the note-ouput top level function which routes according to the tune setup
            ; should this be an object? probably...
            (note-output (_ :channel) 
              (hash-table 
                :dur dur-out 
                :pitch note-num 
                :vel  vel
              )))))

    ; function to look up values for an individual step and call play-note with them
    (define (play-step step)
      (log-debug "play-step, step:" step)
      (let* ((loop-len-main (_ :loop-len))
             (loop-lengths (_ :p-loop-len))
             (loop-tops (_ :p-loop-top))
             (step-pvals (map (lambda (param)
                                 (let* ((p-index (modulo step (loop-lengths param)))
                                        (p-index (+ p-index (loop-tops param))))
                                   (((_ :seq-data) param) p-index)))
                           (range 0 (_ :params)))))
        ;(post "step-data for step:" step ":" step-pvals)
        (if (and (not (_ :mute)) (> (step-pvals 0) 0)) 
          (if (_ :arp-on) 
            (play-note step-pvals)
            (play-chord step-pvals)))))
 
    ; step handler that does step logic, this is what gets scheduled
    (define (run-step)
      ; call play-step with current step-index
      (play-step step-index)

      ; update step counter, inc-to automatically rolls over to zero
      (inc-to! step-index (_ :loop-len))

      ; schedule next step if playing 
      (if playing? 
        (let ((delay-dur (* (_ :time-factor) (_ :step-dur))))
          (set! delay-handle (delay-t delay-dur run-step))))
    ); end run-step

    ; cancel next scheduled iteration and stop playback
    (define (stop)
      (cancel-delay delay-handle)
      (set! playing? #f))

    ; reset state to beginning and start playback
    (define (start)
      (reset)
      (set! playing? #t)
      (run-step))

    (define (reset)
      (cancel-delay delay-handle)
      (set! step-index 0))
  
    (define (init-seq-data params steps)
      "initialize the internal sequence data, specific to step-seq-cv"
      ; make a vector of {params} vectors to hold our seq data
      ; and initialize to zeros
      (set! (_ :seq-data) (make-vector params #f)) 
      (for-each 
        (lambda(i)(set! ((_ :seq-data) i) (make-vector steps 0))) 
        (range 0 params)))
 
    ; constructor logic
    (define (init init-args)
      "constructor, sets up values and initializes sequencer"
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      ; if initial seq data not passed in as constructor arg, make it
      (if (not (_ :seq-data))   (init-seq-data (_ :params) (_ :steps)))
      ; init loop-len and loop-top to num steps if not set in constructor
      (if (not (_ :loop-len)) (set! (_ :loop-len) (_ :steps)))
      (export-envs name)       
    )
      
    ; call the constructor
    (init init-args)

    (lambda args
      "message dispatcher"
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs '(ramp get set get-p set-p))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
     
)); end base-player let and define

