; 4th version of player, 2021-06-08
; - const step time
; - does not use inheritance
; - holds settings in _ hash, everything that can be updated from kw pairs
; - uses constant time for step, in step-dur
; - stores data in vector of lists per step, chords can be done with list of lists
; - exports named envs to top level (as {seq-name}-env) and {name}-env_ for the inner hash

;TODO
; - modulo math to protect loop-len
; - loop-top offset


;(post "loading s4m-live-code/step-sequencers.scm")
(load-from-max "helpers.scm")

(define (step-seq name . init-args)
  "single track step seq with data as vector of ptrack vectors"
  ;(post "step-seq.scm constructor running")
 
  (let ((playing? #f)             ; flag for if on or not (regardless of how clocked) 
        (self-scheduling? #t)     ; whether sequencer should schedule the next step
        (delay-handle #f)         ; handle for self-scheduling
        (step-index 0)            ; step index within full pattern
        (step-abs 0)              ; running absolute total of steps played since starting
        (tick-abs 0)              ; likewise for ticks
        (loop-rep 0)              ; running count of loop iterations 
        (envelopes (hash-table))  ;  
        (debug #f)                ; for logging

        ; hook functions
        (before-step #f)
        (after-step #f)
        (before-loop #f)
        (after-loop #f)
        (before-reps #f)
        (after-reps #f)
        (on-start #f)
        (on-stop #f)

        ; settings hash-table, holds serializable settings
        (_  (hash-table         
          :params         8     ; number of pars per step
          :steps          16    ; number of steps in a sequence
          :step-dur       120   ; step-duration in ticks
          :loop-len       #f    ; if set, is length of loops in steps, if #f, loop is length of sequence vector
          :loop-top       0
          :loop-wrap      #f
          :vel-factor     1
          :dur-factor     1
          :time-factor    1     ; affects entire time rate of player
          :transpose      0
          :outlet         0
          :channel        0     
          :stop-ticks     #f    ; if set, stops after X ticks
          :loop-reps      #f    ; if set, player stops after x reps
          :mute           #f    ;           
          :seq-data           #f    ; sequence data, will be multi-dimensional vector 
          )))          

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    (define (log-debug . args)
      (if debug (apply post args)))

    ;* METHODS
    (define (on-last-step?)
      "return whether we are on the last step of a loop"
      (= step-index (dec (_ :loop-len))))

    (define (on-last-loop?)
      "return whether we are on the last loop of loop-reps"
      (= loop-rep (dec (_ :loop-reps))))   

    ; default play-note method, intent is that this is commonly overridden
    (define (play-note step-data)
      (log-debug "play-note" step-data)
      (let ((gate     (step-data 0))
            (dur      (step-data 1))
            (note-num (step-data 2))
            (vel      (step-data 3)))
        (let ((transposed-note (+ note-num (_ :transpose)))
              (vel-out (* vel (_ :vel-factor)))
              (dur-out (* dur (_ :dur-factor) (_ :time-factor))))
          (log-debug "output:" transposed-note vel-out dur-out)
          (out (_ :outlet) (list (_ :channel) transposed-note vel-out dur-out))
          ; output using the modular
          ;(es-note-m 0 dur-out transposed-note)
    )))

    ; function for playing a step, not including the counting and so on
    ; this so that derived versions can simply reimplement this
    (define (play-step step)
      "play a step"
      (log-debug "play-step, step:" step)
      ; TODO: needs the modulo math here or whatever protection one wants
      (let* ((step-dur  (* (_ :time-factor) (_ :step-dur)))
             ;attempting to read out of range just gives us 0s 
             (step-data (if (< step (length (_ :seq-data)))
                           ((_ :seq-data) step) (make-list (_ :params) 0))))
        ; do output
        (log-debug "step-data:" step-data)
        ; if step-data is not the null list and has gate ON, play
        (if (and (not-null? step-data) (> (step-data 0) 0) (not (_ :mute))) 
          (play-note step-data))))

    ; step handler that does step logic, this is what gets scheduled
    (define (run-step)
      (log-debug "run-step: step-index" step-index "step-abs:" step-abs)
      
      ; if defined, call the before-loop and before-step methods
      ; these could alter inner state, such as step-index
      (if (and before-loop (= step-index 0)) (before-loop))
      (if before-step (before-step))

      ; call play-step with current step-index
      (play-step step-index)

      ; call the post step/loop/loop-reps callbacks if defined and it's time
      (if after-step (after-step))
      (if (and after-loop (on-last-step?)) (after-loop))
      (if (and after-reps (on-last-step?) (on-last-loop?)) (after-reps))

      ; update state counters for ticks, steps, loops
      (set! tick-abs (+ tick-abs (_ :step-dur)))
      (inc-to! step-index (_ :loop-len))
      (inc! step-abs)
      (if (on-last-step?) (inc! loop-rep))

      ; schedule next step if playing and self-scheduling
      (if (and playing? self-scheduling?)
        (let ((delay-dur (* (_ :time-factor) (_ :step-dur))))
          ;(set! delay-handle (delay-t delay-dur run-step))))
          (set! delay-handle (delay-tq delay-dur delay-dur run-step))))
    ); end run-step

    (define (loop-len)
      "get loop-len, either explictly set or taken from length of sequence"
      (or (_ :loop-len) (length (_ :seq-data))))
    
    ; cancel next scheduled iteration and stop playback
    (define (stop)
      (log-debug "step-seq" name "stoping")
      (cancel-delay delay-handle)
      (set! playing? #f)
      (if on-stop (on-stop)))

    ; reset state to beginning and start playback
    (define (start)
      (log-debug "step-seq" name "starting")
      (reset)
      (set! playing? #t)
      (if on-start (on-start))
      (run-step))

    (define (reset)
      (cancel-delay delay-handle)
      (set! step-index 0)
      (set! step-abs 0)
      (set! tick-abs 0)
      (set! loop-rep 0))

    (define (mute) 
      (set! (_ :mute) #t))
    (define (unmute) 
      (set! (_ :mute) #f))
  
    ;********************************************************************************
    ;* Object implementation methods
    (define (update-step step vals)
      "update pars for a single step"
      ;(post "update-step" step vals)
      (for-enum (lambda (i v)(set! (((_ :seq-data) step) i) v)) vals))

    (define (update index step-vals)
      "update a series of steps from list values"
      ;(post "update" index step-vals)
      (for-each
        (lambda (i v)(update-step i v))
        (range index (+ index (length step-vals))) step-vals))
    
    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
      ;(post "(get k) k:" k)
      (if (keyword? k) (_ k) (env k)))
      
    (define (set k v) 
      "set var in settings hash for keywords, local env otherwise"
      (if (keyword? k) (set! (_ k) v) (set! (env k) v)))
   
    ; loop through an arg list, stripping out kw/v pairs and applying them
    ; this allows setting state vars using k/v pairs in any method call
    (define (process-kwargs args)
      "filter kwargs arguments, setting in settings hash and removing from args"
      ;(post "process-kwargs" args)
      (let kwargs-loop ((args args))
        (cond 
          ((null? args) '())
          ((keyword? (car args))
            ; keywords go into the state dict
            (set! (_ (car args)) (cadr args))
            (kwargs-loop (cddr args)))
          (else 
              (cons (car args) (kwargs-loop (cdr args)))))))

    ; constructor logic, takes kwargs passed at constructor time
    ; and copies into the settings hash
    (define (init init-args)
      "constructor, sets up values and initializes sequencer"
      ;(post "step-player init")
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      ; if sequence was not set from kwargs, initialize it
      (if (not (_ :seq-data))
        (let ((params (_ :params))
              (steps (_ :steps)))
          ;(post "initializing sequence data with params: " params "steps:" steps)
          (set! (_ :seq-data) (make-vector steps #f)) 
          (for-each 
            (lambda(i)(set! ((_ :seq-data) i) (make-vector params 0))) 
            (range 0 steps))))
      
      ; init loop-len to sequence length if given
      (if (not (_ :loop-len))
        (set! (_ :loop-len) (length (_ :seq-data))))
          
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_)))
    )
      
    ; call the constructor
    (init init-args)

    (lambda args
      "message dispatcher for our object"
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs '(ramp get set))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
     
)); end base-player let and define

