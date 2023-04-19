;(post "s4m-live-code/controllers.scm")

; load the const defs for params to ptrks
(load-from-max "param-constants.scm")

; list of controllers, used to route midi
; XXX I thinks this is now unused!
(define active-controllers '())

(define (note->number note-in base-note)
  "convert a midi note and base offset to a 0-16 step value"
  (let* ((note-map (hash-table 
            0 0   2 1   4  2    5  3   7  4   9  5  10  6  11  7
           12 8  14 9  16 10   17 11  19 12  21 13  22 14  23 15  24 16))
         (number (note-map (- note-in base-note))))
    number))

;* COMPONENT: meta
;* singleton container for active selections that are used across controllers 
;* it doesn't know how selections are made, but gives all controllers 
;* a global way of accessing current global selections (track, bank, bar, step)
;* for now this is single user and includes the current mode
(define meta
  (let ((attrs (list :track :bank :bar :step)) ; ordered attrs for indexed look-up
        (_ (hash-table
          :track    0
          :bank     0
          :bar      0
          :step     0
          :mode     #f  ; holds controller names
          :steps-per-bar  16
          )))

    (define (get-attr index)
      (if (< index (length attrs)) (attrs index) #f))

    (define (grid-btn row col)
      ;(post "meta 'grid-btn" row col)
      (let ((attr (get-attr row)))
        (post "meta: " attr ":" col)
        (cond 
          (attr 
            (set! (_ attr) col)
            ; todo, some better hook mechanism here
            (if (eq? attr :track) (select-track col))
            (update-view attr col)) 
          (else (post " - no attr for row" row))))
    '())    

    (define (mode-btn btn-num)
      (let* ((modes (hash-table 0 'step   1 'arp   2 'drum   3 'perform  4 'copy  ))
             (mode (modes btn-num)))
        (if mode 
          (begin
            (set! (_ :mode) mode)
            (post "meta Mode set to:" mode))
          (post "meta.mode-btn: Unused mode btn" btn-num))))

    (define (update-view attr value)
      (let* ((dest (symbol (string-append "meta-view-" (list->string (cdr (string->list (symbol->string attr))))))))
        ;(post "meta 'update-view" dest attr value)
        (send dest 'set (+ 1 value))))

    (define (select-track track)
      "calls a tunes select-track-hook to allow custom actions on track select"
      (post "select-track" track)
      (if (defined? 'select-track-hook) 
        (eval `(select-track-hook ,track))))

    (define (advance-step steps)
      (set! (_ :step) (+ (_ :step) steps))
      (update-view :step (_ :step)))

    ; get the current step from both bar and step selections
    ; so calling (meta 'step) always gives you the calculated step
    (define (step)
      (+ (* (_ :bar) (_ :steps-per-bar)) (_ :step)))

    ; as above, but getting abs step from col arg and current bar
    (define (step-from-col col)
      (+ (* (_ :bar) (_ :steps-per-bar)) col))

    (lambda args
      (cond 
        ; calling (meta) returns entire inner hash
        ((null? args) _) 
        ; if called as (meta :track), return track
        ((and (= 1 (length args)) (keyword? (args 0))) 
          (_ (args 0)))
        ; if called as (meta :track 99), set track to 99
        ((and (= 2 (length args)) (keyword? (args 0)))
          (set! (_ (args 0)) (args 1)))
        ; if called with (meta 'msg . args), dispatch to handler
        (else 
          ;(post "meta dispatcher, args:" args)
          (let ((method (eval (args 0))))
            (if method (apply method (cdr args))))  
        )
    ))
))    


;* Grid button translation functions, translates position on the launchpad to entry data
(define row->gate  #(1 0 0 0 0 0 0 0 ))
(define row->dur    (reverse #(60 110 170 230 290 350 410 570))) ; not sure about these
(define row->factor (reverse #(0 1 2 3 4 5 6 7)))
(define row->vel    (reverse #(8 24 40 56 72 88 104 120))) 
(define row->param  (reverse #(0 16 32 48 64 80 96 112))) 

;* PERFORM make-perform-controller
;* does track mutes, fades, volume, etc
;* assumes existence of track-sequencers vector
(define (make-perform-controller name . init-args)
  "perform controller (mutes, levels, etc)"
 
  (let* ((active #t)       
         (debug #t)               ; for logging
         (grid-mode 'split)       ; 'split, 'low, 'high or 'ptrk 
         (grid-unit 'steps)       ; can be bars or steps, for setting loop length 
         ; settings hash-table, holds serializable settings
         (_  (hash-table)))          

    (define (get-sequencer track)
      ; assumes this global was setup by the tune
      ; TODO: make this cleaner
      ; will return false if no seq
      (post "get-sequencer" track)
      (track-sequencers track))

    (define (set-grid-unit unit)
      (set! grid-unit unit)
      (post "perform.grid-unit:" grid-unit))

    (define (set-grid-mode mode-num)
      (let* ((modes (hash-table 0 'split  1 'low  2 'high  3 'track))
             (mode  (modes mode-num)))
        (if mode (set! grid-mode mode))
        (post "perform.grid-mode: " grid-mode)))

    ; notes mute and unmute tracks
    (define (note-on note-num vel)
      ;(post "perform-controller 'note-on" note-num vel)
      (cond 
        ((between? note-num 60 83)
          (let ((seq-num (note->number note-num 60)))
            (seq-mute (+ 1 seq-num) 1)))
        ((between? note-num 36 59)
          (let ((seq-num (note->number note-num 36)))
            (seq-mute (+ 1 seq-num) 0)))
      )) 

    ; grid-btns set loop length in bars or steps depending on submode
    (define (grid-btn row col)
      (post "perform.ctl 'grid-btn" row col)
      (case grid-mode
        ('split
          (let* ((track (if (>= col 8) (+ row 8) row)) 
                 (seq-target (get-sequencer track))
                 (val (+ 1 (modulo col 8)))
                 (steps (if (eq? grid-unit 'steps) val (* val (meta :steps-per-bar)))))
            (if seq-target (seq-target 'set :loop-len steps))))
        ('low
          (let* ((track row)
                 (seq-target (get-sequencer track))
                 (steps (if (eq? grid-unit 'steps) (+ 1 col) (* (+ 1 col) (meta :steps-per-bar)))))
            (if seq-target (seq-target 'set :loop-len steps))))
        ('high
          (let* ((track (+ 8 row))
                 (seq-target (get-sequencer track))
                 (steps (if (eq? grid-unit 'steps) (+ 1 col) (* (+ 1 col) (meta :steps-per-bar)))))
            (if seq-target (seq-target 'set :loop-len steps))))
        ('track
          (let* ((ptrk row)
                 (seq-target (get-sequencer (meta :track)))
                 (steps (if (eq? grid-unit 'steps) (+ 1 col) (* (+ 1 col) (meta :steps-per-bar)))))
            (if seq-target (seq-target 'set-ptrk-loop-len ptrk steps))))
      ))
    
    ; in track mode bottom btn does chord loop len
    ; which is not even used yet....
    (define (bottom-btn btn-num)
      (post "(perform-controller 'bottom-btn" btn-num ")")
      (case grid-mode
        ('track
          (let* ((seq-target (get-sequencer (meta :track)))
                 (steps (if (eq? grid-unit 'steps) (+ 1 col) (* (+ 1 col) (meta :steps-per-bar)))))
            (if seq-target (seq-target 'set :c-loop-len steps))))
        ))
        

    ; constructor logic, takes kwargs passed at constructor time
    (define (init init-args)
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      (export-envs name)       
    )
 
    ;********************************************************************************
    ;* My standard object implementation methods 

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    (define (log-debug . args)
      (if debug (apply post args)))
    
    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
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

    (define (export-envs name)
      "export this seqs env to rootlet for debugging/hacking"
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_))
        (post "controller env exported as" env-name)))

         
    ; call the constructor
    (init init-args)

    ; object's message dispatcher
    (lambda args
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs (list 'get 'set))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
)); end controller

;* COPY, etc
;* assumes existence of track-sequencers vector
(define (make-copy-controller name . init-args)
  "copy controller (mutes, levels, etc)"
 
  (let* ((active #t)       
         (debug #t)                       ; for logging
         (grid-mode 'split)               ; 'split, 'low, 'high or 'ptrk 
         (keyb-1-submode 'select )        ; 'select, 'paste for now 
         (keyb-2-submode #f )             ; TBD
         (ptrks (make-vector PARAMS #t))  ; toggle for ptrks active 
         (source-track 0)                 ; track we copy from, from grid
         (source-bar 0)                   ; source bar, from grid
         (start-step 0)                 
         (len-steps 16)
         (bar-mask  (make-vector 16))     ; which bars from meta.bar gets copied (default 1)
         (step-mask (make-vector 16))     ; when used, we copy only specific steps
         (use-step-mask #f) 
         (pedal-on #f)                    ; is the pedal down doesn't have to be a pedal
         (shift-high #f)                  ; shift key from pitch bend high
         (shift-low #f)                   ; shift key from pitch bend low
         (_  (hash-table)))          

    (define (get-sequencer track)
      ; assumes this global was setup by the tune (#f if no seq)
      ; TODO: make this cleaner
      (post "get-sequencer" track)
      (track-sequencers track))

    ;(define (set-grid-unit unit)
    ;  (set! grid-unit unit)
    ;  (post "perform.grid-unit:" grid-unit))

    (define (do-copy source-bar dest-bar)
      (post "COPY.do-copy source:" source-bar "dest:" dest-bar)
      (cond
        ((not source-bar)
          (post "ERROR: no source-bar set"))
        (else
          (post "doing copy"))))

    ; picking a track from grid selects track, and resets step and bar masks
    (define (set-source-track track)
      (reset-bar-mask)
      (reset-step-mask)
      (set! source-track track))

    ; resetting step mask disables and empties the step-mask
    (define (reset-step-mask)
      (post "COPY.reset-step-mask")
      (set! use-step-mask #f)
      (dotimes (i 16) (set! (step-mask i) #f)))

    ; resetting bar mask sets it back to holding only first bar
    (define (reset-bar-mask)
      (post "COPY.reset-bar-mask")
      (dotimes (i 16) (set! (step-mask i) (if (= i 0) #t #f))))

    ; handles keystep submode buttons
    (define (set-submode keyb submode)
      (post "COPY.set-submode keyb:" keyb "submode:" submode)
      ; else normal submode selection
      (if (eq? keyb 1)
        (set! keyb-1-submode submode)
        (set! keyb-2-submode submode)))

    (define (set-grid-mode mode-num)
      (let* ((modes (hash-table 0 'split  1 'low  2 'high))
             (mode  (modes mode-num)))
        (if mode (set! grid-mode mode))
        (post "copy.grid-mode: " grid-mode)))

    ; notes are the main hot action
    (define (note-on note-num vel)
      ;(post "perform-controller 'note-on" note-num vel)
      (case keyb-1-submode
        ('select
          '())
        ('paste
          (let ((dest-bar (note->number note-num 60)))
             (if dest-bar (do-copy source-bar dest-bar))))      
      )) 

    ; grid-btns set source track and bar, and dest track with shift
    (define (grid-btn row col)
      (post "copy.ctl 'grid-btn" row col)
      (case grid-mode
        ('split
          (set-source-track (if (>= col 8) (+ row 8) row)) 
          (set! source-bar (modulo col 8)))
        ('low
          (set-source-track row)
          (set! source-bar col))
        ('high
          (set-source-track (+ 8 row))
          (set! source-bar col))
        ('track
          (post "copy.ctl track submode N/A")))
      (post "source track:" source-track "bar:" source-bar))

    ; in track mode bottom btn does chord loop len
    ; which is not even used yet....
    (define (bottom-btn btn-num)
      (post "(perform-controller 'bottom-btn" btn-num ")")
      (case grid-mode
        ('track
          (let* ((seq-target (get-sequencer (meta :track)))
                 (steps (if (eq? grid-unit 'steps) (+ 1 col) (* (+ 1 col) (meta :steps-per-bar)))))
            (if seq-target (seq-target 'set :c-loop-len steps))))
        ))
        

    ; constructor logic, takes kwargs passed at constructor time
    (define (init init-args)
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      (export-envs name)       
    )
 
    ;********************************************************************************
    ;* My standard object implementation methods 

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    (define (log-debug . args)
      (if debug (apply post args)))
    
    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
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

    (define (export-envs name)
      "export this seqs env to rootlet for debugging/hacking"
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_))
        (post "controller env exported as" env-name)))

         
    ; call the constructor
    (init init-args)

    ; object's message dispatcher
    (lambda args
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs (list 'get 'set))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
)); end controller


; STEP
(define (make-step-controller name . init-args)
  "step-mode controller"
 
  (let* ((active #t)       
         (debug #t)               ; for logging
         (seq-target #f)          ; the sequencer this controller sends to
         (use-note-vel #t)        ; whether to write in the vel from the step note-on
         (use-last-vel #t)        ; should the last mod wheel msg always be used for vel (special case)
         (last-vel 96)            ; start off at a reasonable value
         (last-dur-steps 0)       ; dur in steps (this * ticks-per-step gets added to dur-ticks)
         (last-dur-ticks 100)     
         (keyb-1-submode 'select) ; for step choosing can be 'select, 'follow', 'record
         (keyb-2-submode 'dur)    ; can be dur, erase, or gate
         (pedal-on #f)            ; is the pedal down doesn't have to be a pedal
         (shift-high #f)          ; shift key from pitch bend high
         (shift-low #f)           ; shift key from pitch bend low
         (grid-ptrk VEL)          ; selected grid ptrk, defaults to vel
         ; settings hash-table, holds serializable settings
         (_  (hash-table)))          

    ; handles keystep submode buttons
    (define (set-submode keyb submode)
      (post "step-controller keyb: " keyb "submode:" submode)
      ; if keyb-1 follow button pressed when already following, acts as advance
      (if (and (eq? keyb 1) (eq? submode 'follow) (eq? keyb-1-submode 'follow))
        (advance-step)
        ; else normal submode selection
        (if (eq? keyb 1)
          (set! keyb-1-submode submode)
          (set! keyb-2-submode submode)))
      #t)

    (define (selected-dur)
      "return a compound dur, dur-steps is 0 up, dur ticks abs"
      (+ (* last-dur-steps 120) last-dur-ticks))  
    
    ; set the active destination target
    (define (set-seq sequencer)
      (post "step controller" name "setting dest to" (sequencer 'get 'name))
      (set! seq-target sequencer))

    ; TODO refactor this into a shared mixin between controllers
    (define (erase-step step)
      (post "step-ctl.erase-step" step)
      ; write all params to 0
      (dotimes (p (seq-target 'get :params))
        (let ((dest-step (meta 'step-from-col step)))
          (seq-target 'update-ptrk p dest-step 0))))
  
    (define (erase-bar)
      (post "step-ctl.erase-bar")
      (dotimes (i (meta :steps-per-bar))
        (erase-step i)))  

    (define (erase-seq)
      (post "step-ctl.erase-seq")
      (dotimes (step (seq-target 'get :steps))
        (dotimes (p (seq-target 'get :params))
          (seq-target 'update-ptrk p step 0))))
    
    ; advance the selected step by the current dur in steps
    (define (advance-step)
      (meta 'advance-step (+ 1 last-dur-steps))
      (post "step now:" (meta 'step)))

    ; note on from keyb-1 is hot
    (define (note-on note-num vel . args)
      ;(post "step-controller 'note-on" note-num vel)
      (cond 
        ((and (eq? keyb-1-submode 'record) (seq-target 'get 'playing?))
          (let* ((step (seq-target 'get 'step-index))
                 (step (- step 1)))
            (write-step note-num vel step)))
        ((not-eq? keyb-1-submode 'record)
          (write-step note-num vel)
          (if (eq? keyb-1-submode 'follow)
            (advance-step)))))
 
    ; TODO shared with other controllers
    (define (bend val)
      ;(post "(step-controller 'bend" val ")")
      ; low bend sets shift-low, no bend turns off shifts
      (cond 
        ((= val 64)
          (if (or shift-high shift-low) (post "step-ctl.shift off"))
          (set! shift-low #f) 
          (set! shift-high #f))
        ((< val 64)
          (if (not shift-low) (post "step.ctl shift-low"))
          (set! shift-low #t) 
          (set! shift-high #f))
        ((> val 64)
          (if (not shift-high) (post "step.ctl shift-high"))
          (set! shift-low #f) 
          (set! shift-high #t)))
       ;(post "shift-low:" shift-low "shift-high" shift-high)
       '())

    ;depending on the submode, does erase, dur, or gate
    (define (note-on-2 note-num vel)
      ;(post "step-controller 'note-on-2" note-num vel)
      (case keyb-2-submode
        ('erase
          (cond 
            ((between? note-num 60 83)
              (erase-step (note->number note-num 60)))
            ((and shift-low (eq? note-num 84))
              (erase-seq))
            ((eq? note-num 84)
              (erase-bar))))
        ('dur      
          (cond
            ((and shift-high (between? note-num 60 84))
              (set! last-dur-ticks (* 8 (note->number note-num 60))) 
              (post "dur-ticks:" last-dur-ticks))
            ((between? note-num 60 84)
              (set! last-dur-steps (note->number note-num 60))
              (post "dur-steps:" last-dur-steps))))
        ('gate      
          (cond
            ; shift-low turns gate off
            ((and shift-low (between? note-num 60 83))
              (let ((dest-step (meta 'step-from-col (note->number note-num 60))))
                (seq-target 'update-ptrk GATE dest-step 0)))
            ((between? note-num 60 83)
              (let ((dest-step (meta 'step-from-col (note->number note-num 60))))
                (seq-target 'update-ptrk GATE dest-step 1)))
            ((between? note-num 84 107)
              (let ((dest-step (meta 'step-from-col (note->number note-num 84))))
                (seq-target 'update-ptrk GATE dest-step 0)))))
        ))

    (define (pedal is-down)
      (post "step-controller 'pedal" is-down)
      (set! pedal-on is-down))

    (define (keyb-1-mod val)
      ;(post "step-ctl.keyb-1-mod" val)
      (cond 
        ; S-H means update last-vel but don't write to cur step
        (shift-high  
          (set! last-vel val))
        ; S-L + mod 0 means turn on vel from note
        ((and shift-low (eq? val 0))
          (post "step.ctl note-vel enabled")
          (set! use-note-vel #t)) 
        ; S-L + mod high means turn off vel from note
        ((and shift-low (> val 120))
          (post "step.ctl note-vel disabled")
          (set! use-note-vel #f)) 
        (else
          (seq-target 'update-ptrk VEL (meta 'step) val))))
      
    (define (keyb-2-mod val)
      ;(post "step-ctl.keyb-2-mod" val)
      (set! last-dur-ticks val))
 
    (define (cc cc-num cc-val)
      ;(post "(step-controller 'cc)" cc-num cc-val)
      (let ((dest-step (meta 'step)))
        (cond 
          ;((eq? cc-num 1) ; write mod-wheel to vel
          ;  (set! last-vel cc-val)
          ;  (seq-target 'update-ptrk VEL dest-step cc-val))
          ((between? cc-num 4 7)
            (seq-target 'update-ptrk cc-num dest-step cc-val))
          (else
            '()))))

    ; pad left selects grid ptrk
    (define (left-btn btn-num)
      ;(post "(step-controller 'left-btn" btn-num ")")
      (set! grid-ptrk btn-num)
      (post "step-ctl ptrk:" grid-ptrk))
    
    ; grid-btns update values similar to arp cntrl
    (define (grid-btn row col)
      (post "(step-controller 'grid-btn" row col ")")
      (let ((step (meta 'step-from-col col)))
        (post "updating step:" step)
        (cond
          ((= grid-ptrk 0) ; dur  
            (seq-target 'update-ptrk grid-ptrk step (row->gate row)))   
          ((= grid-ptrk 1) ; dur  
            (seq-target 'update-ptrk grid-ptrk step (row->dur row)))   
          ((= grid-ptrk 2) ; factor  
            (seq-target 'update-ptrk grid-ptrk step (row->factor row)))   
          ((= grid-ptrk 3) ; vel 
            (seq-target 'update-ptrk grid-ptrk step (row->vel row)))   
          (else '()
            (seq-target 'update-ptrk grid-ptrk step (row->param row))))))   

    (define (right-btn btn-num)
      (post "(step-controller 'right-btn" btn-num ")"))

    (define (bottom-btn btn-num)
      (post "(step-controller 'bottom-btn" btn-num ")"))

    (define (write-step note vel . args)
      ;(post "write-step" note vel)
      (let ((dest-step (if (not-null? args) (args 0) (meta 'step))))
         ; always update GATE (for now, could change later)
         (seq-target 'update-ptrk GATE dest-step 1)
         ; copy any active default params in
         ; copy all hot param vals in (takes precedence)
         ;(dotimes (i num-params)
         ;   (let ((pval (params-hot i)))
         ;     (if pval (seq-target 'update-ptrk i dest-step pval))))
         ; if always use last vel val on, copy it in
         (if (and use-last-vel last-vel)
            (seq-target 'update-ptrk VEL dest-step last-vel))
         ; if vel from keyb on, copy that after (takes precedence over the above)
         (if use-note-vel
            (seq-target 'update-ptrk VEL dest-step vel))
         ; always write NOTE from the note played
         (seq-target 'update-ptrk NOTE dest-step note)
         ; write dur from last selected duration
         (seq-target 'update-ptrk DUR dest-step (selected-dur))))
    

    ; constructor logic, takes kwargs passed at constructor time
    (define (init init-args)
      (post "step controller init")
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      (export-envs name)       
    )
 
    ;********************************************************************************
    ;* My standard object implementation methods 

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    (define (log-debug . args)
      (if debug (apply post args)))
    
    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
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

    (define (export-envs name)
      "export this seqs env to rootlet for debugging/hacking"
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_))
        (post "controller env exported as" env-name)))

         
    ; call the constructor
    (init init-args)

    ; object's message dispatcher
    (lambda args
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs (list 'get 'set))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
)); end controller


;* FACTORY: make-arp-controller
;* makes a controller function-object, which gets set to target a sequencer with the 'set-seq msg
;*   (define arp-controller (make-arp-controller 'arp-controller)) 
;*   (arp-controller 'set-seq seq-1)
(define (make-arp-controller name . init-args)
  "factory for a controller"
 
  (let ((active #t)       
        (debug #t)               ; for logging
        (seq-target #f)          ; the sequencer this controller sends to
        (num-notes-on 0)         ; how many notes are held down
        (notes-on 
          (make-vector 128 #f))  ; status of each note
        (chord-entry #f)         ; list of notes being entered in one operation
        (mode 'play)             ; sub-mode, can be 'program, 'play, 'override
        (ptrk 0)                 ; selected ptrk
        (ptrk-len-unit 'steps)   ; can be 'steps or 'bars, determines loop length entry unit
        ; settings hash-table, holds serializable settings
        (_  (hash-table)))          

    ; set the active destination target
    (define (set-seq sequencer)
      (post "arp controller" name "setting dest to" (sequencer 'get 'name))
      (set! seq-target sequencer))

    (define (note-on note-num vel)
      ;(post "arp-controller 'note-on" note-num vel)
      ; track notes down as starting from zero is considered a new entry
      (inc! num-notes-on)
      (set! (notes-on note-num) #t)
      ;(post "  - notes-on:" num-notes-on)
      (if (= 1 num-notes-on) 
        ; this is the first note of new entry so start a new chord list
        (set! chord-entry (list note-num))
        ; this is a subsequent note, so add to the chord list
        (set! chord-entry (cons note-num chord-entry)))
      ;(post "chord-entry:" chord-entry)
      (update-chord chord-entry)) 

    (define (note-off note-num vel)
      ;(post "(arp-controller 'note-off" note-num vel)
      (if (> num-notes-on 0) (dec! num-notes-on))
      (set! (notes-on note-num) #f))
    
    (define (cc cc-num cc-val)
      (post "(arp-controller 'cc)" chan note-num vel)
    )
    (define (left-btn btn-num)
      ;(post "(arp-controller 'left-btn" btn-num ")")
      (set! ptrk btn-num)
      (post "arp-controller ptrk set to" btn-num))

    (define (right-btn btn-num)
      ;(post "(arp-controller 'right-btn" btn-num ")")
      (cond 
        ((= btn-num 0)  ; sets master loop length in bars
          (set! ptrk 'master-loop))
        ((= btn-num 1)
          (set! ptrk 'chord-loop))
        ((= btn-num 2)
          (post "ptrk len unit = steps")
          (set! ptrk-len-unit 'steps))
        ((= btn-num 3)
          (post "ptrk len unit = bars")
          (set! ptrk-len-unit 'bars))
        ((= btn-num 6) 
          (seq-target 'clear-chord-step (meta 'step)))
        ((= btn-num 7) 
          (seq-target 'clear-chord-bar (meta :bar)))
        (else
          (post "  - btn-num" btn-num "unimplemented"))))

    (define (bottom-btn btn-num)
      ;(post "(arp-controller 'bottom-btn" btn-num ")")
      (cond 
        ((eq? ptrk 'master-loop)
          (post "setting master loop len to" (inc btn-num) "bars")
          (seq-target 'set :loop-len (* (inc btn-num) (meta :steps-per-bar))))
        ((eq? ptrk 'chord-loop)
          (post "setting chord loop len to" (inc btn-num) "bars")
          (seq-target 'set :c-loop-len (* (inc btn-num) (meta :steps-per-bar))))
        (else   ;setting loop len for numerical ptrk
          (let ((loop-len (if (eq? ptrk-len-unit 'steps) 
                              (+ 1 btn-num)
                              (* (+ 1 btn-num) (meta :steps-per-bar)))))
            (post "  - setting ptrk" ptrk "to loop len" loop-len)
            (seq-target 'set-ptrk-loop-len ptrk loop-len)))))

    ; grid-btns update values
    (define (grid-btn row col)
      (post "(arp-controller 'grid-btn" row col ")")
      (let ((step (meta 'step-from-col col)))
        (post "updating step:" step)
        (cond
          ; TODO: step should take into account bar?
          ((= ptrk 0) ; dur  
            (seq-target 'update-ptrk ptrk step (row->gate row)))   
          ((= ptrk 1) ; dur  
            (seq-target 'update-ptrk ptrk step (row->dur row)))   
          ((= ptrk 2) ; factor  
            (seq-target 'update-ptrk ptrk step (row->factor row)))   
          ((= ptrk 3) ; vel 
            (seq-target 'update-ptrk ptrk step (row->vel row)))   
          (else '()))))
    
    (define (update-chord chord-entry)
      "send the chord update message to target" 
      ;(post "arp-controller update-chord" chord-entry)
      (case mode
        ('play
          ;(post "arp-controller (update-chord) 'play" chord-entry)
          (seq-target 'set :override #f)
          (seq-target 'update-chord chord-entry))
        ('program
          ;(post "arp-controller (update-chord) 'program" (meta :step) chord-entry)
          (seq-target 'set :override #f)
          (seq-target 'update-chord-seq (meta 'step) chord-entry)) 
        ('override
          ;(post "arp-controller (update-chord) 'override")
          (seq-target 'set :override #t)
          (seq-target 'update-chord chord-entry))
    ))

    ; set to sub-mode of 'play, 'program, 'record
    (define (set-mode mode-sym)
      (post "(arp-controller 'set-mode" mode-sym)
      (set! mode mode-sym))


    ;********************************************************************************
    ;* My standard object implementation methods 
    ;* TODO: figure out how to make these from a mixin

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    (define (log-debug . args)
      (if debug (apply post args)))
    
    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
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

    (define (export-envs name)
      "export this seqs env to rootlet for debugging/hacking"
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_))
        (post "controller env exported as" env-name)))

    ; constructor logic, takes kwargs passed at constructor time
    ; and copies into the settings hash
    (define (init init-args)
      "constructor, sets up values and initializes sequencer"
      ;(post "controller init")
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      ; if initial seq data not passed in as constructor arg, make it
      (export-envs name)       
    )
      
    ; call the constructor
    (init init-args)

    ; object's message dispatcher
    (lambda args
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs (list 'get 'set))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
)); end controller

;* DRUM -mode
(define (make-drum-controller name . init-args)
 
  (let* ((active #t)       
         (debug #t)               ; for logging
         (seq-target #f)          ; the sequencer this controller sends to
         (use-note-vel #f)        ; whether to write in the vel from the step note-on
         (use-last-vel #t)        ; should the last mod wheel msg always be used for vel (special case)
         (use-last-note #t)       ; should the last-note var always set pitch (ie lock it)
         (last-vel 96)            ; start off at a reasonable value
         (last-note 1)            ; default is factor 1
         (last-dur-steps 0)       ; dur in steps (this * ticks-per-step gets added to dur-ticks)
         (last-dur-ticks 120)   
         (erase-all-params? #t)   ; does erasing a step wipe all params or just mute gate
         (ptrk-len-unit 'steps)   ; can be 'steps or 'bars, determines loop length entry unit
         (num-params 16)          ; storing more params than seq uses right now
         (pedal-on #f)            ; is the pedal down doesn't have to be a pedal
         (shift-high #f)          ; shift key from pitch bend high
         (shift-low #f)           ; shift key from pitch bend low
         (param-selected #f)      ; which param is selected for bottom button params-set edit
         ; XXX this should be dynamic
         (param-defaults (make-vector num-params 0))       ; default value for a param
         (params-hot     (make-vector num-params #f))      ; param vals when pedal down
         (params-set     (make-vector num-params #f))      ; params copied regardless of pedal
         (params-last    (make-vector num-params #f))      ; last param, regardless of pedal
         (_  (hash-table)))          

    (define (selected-dur)
      "return a compound dur, dur-steps is 0 up, dur ticks abs"
      (+ (* last-dur-steps 120) last-dur-ticks))  

    ; set the active destination target
    (define (set-seq sequencer)
      (post "drum-controller" name "setting dest to" (sequencer 'get 'name))
      (set! seq-target sequencer))

    ; note on is hot - except when shift high on
    (define (note-on note-num vel)
      ;(post "drum-controller 'note-on" note-num vel)
      (cond
        ; a note when shift-high is on sets the default pitch
        (shift-high 
          (post "default pitch now:" note-num)
          (set! (params-set NOTE) note-num))
        ; shift-low and a note erases it
        ((and shift-low (between? note-num 60 83))
          (let ((step (note->number note-num 60)))
            (erase-step step)))
        ((between? note-num 60 83)
          (let ((step (note->number note-num 60)))
            (if step (write-step step vel))))
        ((between? note-num 84 107)
          (let ((step (note->number note-num 84)))
            (if step (erase-step step))))
        ((eq? note-num 108)
          (erase-bar))
        (else
          (post "  - note" note-num "not assigned"))))

    (define (pedal down)
      (post "drum-controller 'pedal" down)
      (set! pedal-on down)
      (if (eq? down #f)
        (dotimes (i num-params) (set! (params-hot i) #f)))
      ;(post "params-hot:" params-hot)
    )

    (define (note-off note-num vel)
      ;(post "(drum-controller 'note-off" note-num vel)
      '())

    (define (cc cc-num cc-val)
      ;(post "(drum-controller 'cc)" cc-num cc-val)
      (cond 
        ((eq? cc-num 1) ; write mod-wheel to vel
          (set! (params-last VEL) cc-val)
          (set! last-vel cc-val)
          (if shift-low (set! (params-set VEL) #f))
          (if shift-high (set! (params-set VEL) cc-val))
          (if pedal-on (set! (params-hot VEL) cc-val)))
        ((between? cc-num 4 15)
          (set! (params-last cc-num) cc-val)
          (if shift-low (set! (params-set cc-num) #f))
          (if shift-high (set! (params-set cc-num) cc-val))
          (if pedal-on (set! (params-hot cc-num) cc-val)))
        (else
          '()))
      ;(post "params-hot:" params-hot)
      ;(post "params-set:" params-set)
      ;(post "-")
    )
         
    (define (bend val)
      ;(post "(drum-controller 'bend" val ")")
      ; low bend sets shift-low, no bend turns off shifts
      (cond 
        ((= val 64)
          (if (or shift-high shift-low) (post "shift off"))
          (set! shift-low #f) 
          (set! shift-high #f))
        ((< val 64)
          (if (not shift-low) (post "shift-low"))
          (set! shift-low #t) 
          (set! shift-high #f))
        ((> val 64)
          (if (not shift-high) (post "shift-high"))
          (set! shift-low #f) 
          (set! shift-high #t)))
       ;(post "shift-low:" shift-low "shift-high" shift-high)
       '())

    (define (left-btn btn-num)
      (post "(drum-controller 'left-btn unused" btn-num ")"))

    (define (right-btn btn-num)
      ;(post "(drum-controller 'right-btn" btn-num ")")
      (cond 
        (shift-low        ; shift-low removes a param from params-set
          (set! (params-set btn-num) #f)
          (post "params-set:" params-set))
        ((eq? 0 btn-num)
          (set! param-selected 'dur-steps))
        ((eq? 1 btn-num)
          (set! param-selected 'dur-ticks))
        (else
          (set! param-selected btn-num)))
      (post "param selected:" param-selected))
    
    ; btm-btn writes it's octal value to (params-set param-selected)
    (define (bottom-btn btn-num)
      ;(post "(drum-controller 'bottom-btn" btn-num ")")
      (let* ((val (+ 7 (* btn-num 8)))
             ; for non-dur params, treat 7 as 0 so we can enter a 0
             (val (if (and (number? param-selected) (eq? val 7)) 0 val)))  
        (cond
          ((eq? param-selected 'dur-steps)
            (set! last-dur-steps btn-num)
            (set! (params-set DUR) (selected-dur))) 
          ((eq? param-selected 'dur-ticks)
            (set! last-dur-ticks (* 8 (+ 1 btn-num)))
            (set! (params-set DUR) (selected-dur)))
          ((eq? param-selected NOTE)  
            ; for note, we use raw btn-num (0-15)
            (set! (params-set NOTE) btn-num))
          (else 
            (set! (params-set param-selected) val))))
      (post "params-set now:" params-set))


    (define (grid-btn row col)
      (post "(drum-controller 'grid-btn unused" row col ")"))
    
    (define (write-step step vel)
      ;(post "write-step" step vel)
      (let* ((dest-step (meta 'step-from-col step)))
         ; always update GATE (for now, could change later)
         (seq-target 'update-ptrk GATE dest-step 1)
         ; copy any active default params in
         (dotimes (i num-params)
            (let ((pval (params-set i)))
              (if pval (seq-target 'update-ptrk i dest-step pval))))
         ; copy all hot param vals in (takes precedence)
         (dotimes (i num-params)
            (let ((pval (params-hot i)))
              (if pval (seq-target 'update-ptrk i dest-step pval))))
         ; if always use last vel val on, copy it in
         (if (and use-last-vel last-vel)
            (seq-target 'update-ptrk VEL dest-step last-vel))
         ; if vel from keyb on, copy that after (takes precedence over the above)
         (if use-note-vel
            (seq-target 'update-ptrk VEL dest-step vel))
         ; if neither params-set or params-hot at pitch and dur, use defaults
         (if (or use-last-note (and (not (params-set NOTE)) (not (params-hot NOTE))))
            (seq-target 'update-ptrk NOTE dest-step last-note))
         (if (and (not (params-set DUR)) (not (params-hot DUR)))
            (seq-target 'update-ptrk DUR dest-step (selected-dur)))))
            

    ; TODO refactor this into a shared mixin between controllers
    (define (erase-step step)
      (post "erase-step" step)
      (if erase-all-params?
        ; write all params to 0
        (dotimes (p PARAMS)
          (let ((dest-step (meta 'step-from-col step)))
            (seq-target 'update-ptrk p dest-step 0)))
        ; else only write gate to 0
        (let ((dest-step (meta 'step-from-col step)))
           (seq-target 'update-ptrk GATE dest-step 0))))
  
    (define (erase-bar)
      (post "erase-bar")
      (dotimes (i (meta :steps-per-bar))
        (erase-step i)))  
              
    (define (init-defaults)
        ; some defaults that might be passed in during constructor time
        (if (_ :note)
          (set! (params-set NOTE) (_ :note)))
        (if (_ :dur)
          (set! (params-set DUR) (_ :dur)))
    )

    
    ;********************************************************************************
    ;* My standard object implementation methods 

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    (define (log-debug . args)
      (if debug (apply post args)))
    
    (define (get k) 
      "get var from settings hash if keyword, or local env otherwise"
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

    (define (export-envs name)
      "export this seqs env to rootlet for debugging/hacking"
      ; save env as {name}-env and {name-env_} in the global namespace
      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
        (varlet (rootlet) env-name env)
        (varlet (rootlet) env-name_ (env '_))
        (post "controller env exported as" env-name)))

    ; constructor logic, takes kwargs passed at constructor time
    ; and copies into the settings hash
    (define (init init-args)
      "constructor, sets up values and initializes sequencer"
      ;(post "controller init")
      (init-defaults)
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      ; if initial seq data not passed in as constructor arg, make it
      (export-envs name)       
    )
      
    ; call the constructor
    (init init-args)

    ; object's message dispatcher
    (lambda args
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args))
             (no-process-funs (list 'get 'set))  ; list of methods that don't get kwarg processing
             (fun-args (if (member? msg no-process-funs) fun-args (process-kwargs fun-args))))
        (apply (eval msg) fun-args)))
)); end controller

