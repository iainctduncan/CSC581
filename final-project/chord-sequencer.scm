; current version of chord seq/arp player, Jan 2022
; - const step time
; - does not use inheritance
; - holds settings in _ hash, everything that can be updated from kw pairs
; - uses constant time for step, in step-dur
; - exports named envs to top level (as {seq-name}-env) and {name}-env_ for the inner hash

;TODO
; - modulo math to protect loop-len
; - loop-top offset


;(post "loading s4m-live-code/chord-sequencer.scm")
(load-from-max "helpers.scm")

; the multi-live version where each seq has separate vectors per ptrack with
; independent loop controls, acts like a ganged set of cv seqs
; on this one, all loop controls are vectors of ints, ptracks in size
; for now, this does not have any hook functions
(define (chord-step-seq name . init-args)
  "chord step seq with separate p-trk looping and chord storage"
  ;(post "chord-step-seq.scm constructor running")
 
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

        ; ordered list of the state keys for serialization
        (meta-keywords '(
          :params :steps :step-dur :loop-len :loop-top :loop-wrap 
          :p-loop-len :p-loop-top :c-loop-len :c-loop-top
          :arp-on :arp-wrap :wrap-8va
          :vel-factor :dur-factor :time-factor :transpose :loop-reps ))

        ; settings hash-table, holds serializable settings
        (_  (hash-table         
          :params         8     ; number of param tracks 
          :steps          128   ; number of steps in a sequence
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
          :loop-reps      #f    ; if set, player stops after x reps
          :mute           #f    ;           
          :seq-data       #f    ; sequence data, will be multi-dimensional vector 
          ; ptrk specific data, these become vectors of length :params
          :p-loop-len     #f
          :p-loop-top     #f
          ; settings for the arpeggiator
          :chord-data     #f    ; chord data is a vector, each point is null or a list
          :chord          '()   ; the current chord, as a list of midi notes
          :override       #f    ; when true, chords from seq are ignored so playing overrides
          :c-loop-len     #f    ; chord loop len - not yet used
          :c-loop-top     0     ; chord loop top - not yet used
          :arp-on         #t    ; is the arpeggiator on or are we playing poly chords
          :arp-wrap       #t    ; if true, out of range factors wrap around, else silent 
          :wrap-8va       #t    ; if true, wrapped arp factors are bumped 8va per wrap
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

    (define (get-arp-note factor-arg)
      "translate note-factor to actual note, counts from 1 up, false on 0"
      (if (= 0 factor-arg)
        #f  ; factor 0 means no note
        (let* ((factor        (dec factor-arg))   ; adjust to count from 1 up
               (chord-factors (_ :chord))
               (num-factors   (length chord-factors))
               (base-note     (chord-factors (modulo factor (length chord-factors))))
               (octave-offset (if (_ :wrap-8va) (floor (/ factor num-factors)) 0))
               (note-num      (+ base-note (* octave-offset 12))))
          note-num)))

    ; default play-note method, intent is that this is commonly overridden
    ; not used for poly output
    (define (play-note step-data)
      (log-debug "play-note" step-data)
      (let* ((gate     (step-data 0))
             (dur      (step-data 1))
             (note-num (step-data 2))
             ; if there is no active chord or note-num is higher than 11, keep note-num
             ; else, use it as a factor in the chord track 
             (note-num (if (or (null? (_ :chord)) (> note-num 11))
                            note-num
                            (get-arp-note (step-data 2))))
             (vel      (step-data 3))
            )
        ; note-num zero (or #f) always means no output
        (if (and note-num (> note-num 0))
          (let ((transposed-note (+ note-num (_ :transpose)))
                (vel-out (* vel (_ :vel-factor)))
                (dur-out (* dur (_ :dur-factor) (_ :time-factor))))
            ;(post "chord-seq output:" transposed-note vel-out dur-out)
            ; call the note-ouput top level function which routes according to the tune setup
            ; should this be an object? probably...
            (note-output (_ :channel) 
              (hash-table 
                :dur dur-out 
                :pitch transposed-note 
                :vel  vel-out 
                :mod-params (list (step-data 4) (step-data 5) (step-data 6) (step-data 7))
                :mod-1 (step-data 4)
                :mod-2 (step-data 5)
                :mod-3 (step-data 6)
                :mod-4 (step-data 7)))
    ))))

    ; if arp is not on, then this is called instead of play-note
    (define (play-chord step-data)
      (log-debug "(play-chord" step-data ")")
      (let ((gate     (step-data 0))
            (dur      (step-data 1))
            ; step data 2 does nothing in poly mode, notes are just the chord
            (notes    (if (null? (_ :chord)) #f (_ :chord)))
            (vel      (step-data 3)))
        ; don't play if there is no current chord
        (if notes
          (let ((transposed-notes (map (lambda(n)(+ n (_ :transpose))) notes))
                (vel-out (* vel (_ :vel-factor)))
                (dur-out (* dur (_ :dur-factor) (_ :time-factor))))
            ;(post "  - output:" transposed-notes vel-out dur-out)
            ; send out an output message for each note in the collection
            ; note that this uses the output mapping for the tune, set in 
            (chord-output (_ :channel) 
              (hash-table 
                :dur dur-out 
                :pitch transposed-notes
                :vel  vel-out 
                :mod-params (list (step-data 4) (step-data 5) (step-data 6) (step-data 7))
                :mod-1 (step-data 4)
                :mod-2 (step-data 5)
                :mod-3 (step-data 6)
                :mod-4 (step-data 7))))))
    )

    ; version with independent ptrk look up
    ; step is the master step, and (_ :loop-len) is the master loop 
    (define (play-step step)
      (log-debug "play-step, step:" step)
      (let* (
        (loop-len-main (_ :loop-len))
        (loop-lengths (_ :p-loop-len))
        (loop-tops (_ :p-loop-top))
        (step-pvals (map (lambda (param)
                            ; if ptrack loop length is higher than main loop, use the lower val
                            (let* ((p-loop-len (if (>= (loop-lengths param) loop-len-main) 
                                                   loop-len-main 
                                                   (loop-lengths param)))  
                                   (p-index (modulo step p-loop-len))
                                   (p-index (+ p-index (loop-tops param))))
                              (((_ :seq-data) param) p-index)))
                      (range 0 (_ :params)))))
          ;(post "step-data for step:" step ":" step-pvals)
          (if (and (not (_ :mute)) (> (step-pvals 0) 0)) 
            (if (_ :arp-on) 
              (play-note step-pvals)
              (play-chord step-pvals)))))
  
    ; look up chord data for a step, if override is on, does nothing
    ; (_ :chord) evals to the current chord, used when no chord data is found in a sequence
    ; step is the step index according to the master loop
    (define (get-chord step)
      (log-debug "get-chord" step)
      (if (not (_ :override))
        (let* ((chord-step-index (modulo step (chord-loop-len))) 
               (chord-datum ((_ :chord-data) chord-step-index)))
          (if (not-null? chord-datum) chord-datum (_ :chord)))
        ; if in override mode, chord seq data is not looked up (playing whatever is played on keyboard)
        (_ :chord)))

    ; step handler that does step logic, this is what gets scheduled
    (define (run-step)
      (log-debug "run-step: step-index" step-index "step-abs:" step-abs)
      
      ; if defined and its the right time, call the before-loop and before-step methods
      (if (and before-loop (= step-index 0)) (before-loop))
      (if before-step (before-step))

      ; set the current chord from the chord sequence
      (set! (_ :chord) (get-chord step-index))
      ;(log-debug "chord now:" (_ :chord))

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
          (set! delay-handle (delay-t delay-dur run-step))))
    ); end run-step

    (define (loop-len)
      "get loop-len, either explictly set or taken from length of sequence"
      (or (_ :loop-len) (length (_ :seq-data))))

    (define (chord-loop-len)
      "get chord loop len, using main loop len if not set"
      (or (_ :c-loop-len) (loop-len)))
   
    (define (ptrk-loop-len ptrk-num)
      "return the loop length for a ptrk"
      ((_ :p-loop-len) ptrk-num))

    (define (set-ptrk-loop-len ptrk-num loop-len)
      "set the loop length for a ptrk"
      (set! ((_ :p-loop-len) ptrk-num) loop-len))

    (define (ptrk-loop-top ptrk-num)
      "return the loop top for a ptrk"
      ((_ :p-loop-top) ptrk-num))

    ; cancel next scheduled iteration and stop playback
    (define (stop)
      (cancel-delay delay-handle)
      (set! playing? #f)
      (if on-stop (on-stop)))

    ; reset state to beginning and start playback
    (define (start)
      (post name "starting")
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
 
    (define (update-seq-data index data)
      "load sequence data from a 2D vector, ptrcks by steps - no reinit"
      (post "update-seq-data")
      (for-each
        (lambda (ptrk data-vector)(update-ptrk ptrk index data-vector))
        (range 0 (_ :params)) data))

    (define (load-seq-data index data)
      "load sequence data from a 2D vector, ptrcks by steps - reinit"
      (post "load-seq-data")
      (init-seq-data (_ :params) (_ :steps))
      (for-each
        (lambda (ptrk data-vector)(update-ptrk ptrk index data-vector))
        (range 0 (_ :params)) data))

    (define (update-step step vals)
      "update pars for a single step"
      ;(post "update-step" step vals)
      (for-enum 
        (lambda (ptrk v) (set! (((_ :seq-data) ptrk) step) v)) 
        vals))

    (define (update index step-vals)
      "update a series of steps"
      ;(post "update" index step-vals)
      (for-each
        (lambda (i v)
          (if (and v (not-null? v)) 
            ;(post "update-step" i v)))
            (update-step i v)))
        (range index (+ index (length step-vals))) step-vals)
    )

    ; data update function for cv style version 
    (define (update-ptrk param index data)
      (log-debug "update-ptrk" param index data)
      ; this can handle data as either one number or a sequence
      (define (update-point index datum)
        (set! (((_ :seq-data) param) index) datum))
      (if (sequence? data)
        ; if passed sequence, update all points
        (for-enum (lambda (i v)(update-point (+ index i) v)) data)
        ; else update single point
        (update-point index data)))

    (define (get-ptrk param index count)
      "return a subvector of ptrk data"
      (let* ((ptrk-vector ((_ :seq-data) param))
             (len-ptrk    (length ptrk-vector))
             (end         (+ index count)) 
             (end-index   (if (< end len-ptrk) end len-ptrk)))
        ; return a subvector - NB: this is a slice of the vector, not a copy!
        ; writing to it would change the seq's data
        (subvector ptrk-vector index end-index)))
   
    (define (update-loops loop-lengths)
      "update ptrack loop lengths from a list"
      (dotimes (pnum (length loop-lengths))
        (if (integer? (loop-lengths pnum))
          (set-p :p-loop-len pnum (loop-lengths pnum))))) 

    (define (update-chord chord-list)
      "update the current playing chord, copying list"
      (let ((new-chord-list (sort! (copy chord-list) <)))
        ;(post "(update-chord)" new-chord-list)
        (set! (_ :chord) new-chord-list)))

    ; update the chord data, false or null enter null list
    (define (update-chord-seq index data)
      ;(post "(update-chord-seq)" index data)
      (let ((new-data (if (null-or-false? data) '() (sort! (copy data) <))))
        (set! ((_ :chord-data) index) new-data))) 

    ; wipe the whole chord seq
    (define (clear-chord-seq index steps)
      (post "clear-chord-seq") 
      (for-each
        (lambda(i) (set! ((_ :chord-data) i) '()))
        (range 0 steps)))

    ; clear chord for a step
    (define (clear-chord-step step)
      (post "clear-chord-step" step) 
      (set! ((_ :chord-data) step) '()))

    ; clear chord for a bar
    (define (clear-chord-bar bar)
      (post "clear-chord-bar" bar) 
      (let* ((steps-per-bar (meta :steps-per-bar))
             (start-step (* (meta :bar) steps-per-bar))) 
        (dotimes (i steps-per-bar)
          (set! ((_ :chord-data) i) '()))))

    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
      (if (keyword? k) (_ k) (env k)))
      
    (define (set k v) 
      "set var in settings hash for keywords, local env otherwise"
      (if (keyword? k) (set! (_ k) v) (set! (env k) v)))

    ; getter and setter for ptrk vectorized values
    (define (get-p k param) 
      "get pvar from settings hash for a specific ptrk"
      ((_ k) param))

    (define (set-p k param v) 
      "set pvar in settings hash for a specific ptrk"
      (set! ((_ k) param) v))
   
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

    (define (export-envs name)
      "export this seqs env to rootlet for debugging/hacking"
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_))
        ;(post "step-seq env exported as" env-name)
    ))

    (define (init-seq-data params steps)
      "initialize the internal sequence data, specific to step-seq-cv"
      (log-debug "init-seq-data params: " params "steps:" steps)
      ; for step-seq-cv, data is a vector of params size containing vectors of steps 
      (set! (_ :seq-data) (make-vector params #f)) 
      (for-each 
        (lambda(i)(set! ((_ :seq-data) i) (make-vector steps 0))) 
        (range 0 params)))

    (define (init-chord-data steps)
      "initialize the internal chord data, specific to step-chord-cv"
      (log-debug "init-chord-data params steps:" steps)
      ; for step-chord-cv, data is a vector of params size containing vectors of steps 
      (set! (_ :chord-data) (make-vector steps #f)) 
      (for-each 
        (lambda(i)(set! ((_ :chord-data) i) (list))) 
        (range 0 steps)))

    ; constructor logic, takes kwargs passed at constructor time
    ; and copies into the settings hash
    (define (init init-args)
      "constructor, sets up values and initializes sequencer"
      ;(post "step-seq-cv init")
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      ; if initial seq data not passed in as constructor arg, make it
      (if (not (_ :seq-data))   (init-seq-data (_ :params) (_ :steps)))
      (if (not (_ :chord-data)) (init-chord-data (_ :steps)))
      ; init loop-len and loop-top to num steps if not set in constructor
      (if (not (_ :loop-len)) (set! (_ :loop-len) (_ :steps)))
      (if (not (_ :loop-top)) (set! (_ :loop-top) (_ :steps)))
      ; init ptrk loop settings 
      (if (not (_ :p-loop-len)) (set! (_ :p-loop-len) (make-vector (_ :params) (_ :steps))))
      (if (not (_ :p-loop-top)) (set! (_ :p-loop-top) (make-vector (_ :params) 0)))
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

