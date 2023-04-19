(post "views.scm")
; view model for the arp view with a 2x8, 64x8, and 64x5 grid
; grid-names: {name}-main, {name}-meta, {name}-chords
; this view model only ever shows one sequencer, with option to change it's bar
; loop info in side bar

; global view registry
(define *views* (hash-table))

; todo: stagger these over time
(define (view-refresh . view-names)
  (if (null? view-names)
    ; if called with no view name, refresh all views
    (for-each (lambda (name-view) ((cdr name-view) 'refresh)) *views*)
    ; else refresh the ones called
    (for-each (lambda (view-name) ((*views* view-name) 'refresh)) view-names)))

; names to keep track of: view-model, patcher, arrays, sequencer it's watching
; chord-step view
(define (cs-view name . init-args)
 
  (let ((data  #f)                ; will hold vector of vectors
        (formatters (hash-table)) ; hash of rows to formatter functions
        (name-main        (symbol-append name '-main))
        (name-loops       (symbol-append name '-loops))
        (name-chords      (symbol-append name '-chords))

        ; max object scripting names in the linked patcher, set here to lower calls during refresh
        (seq-name-mobj    (symbol-append name '-seq-name))      ; message box id for showing seq in view

        (main-grid-mobj   (symbol-append name '-main-grid))     ; dest for sending grid the readarray messages
        (loops-grid-mobj  (symbol-append name '-loops-grid))  
        (chords-grid-mobj (symbol-append name '-chords-grid)) 
        (main-defer-mobj   (symbol-append name '-main-defer))   
        (loops-defer-mobj  (symbol-append name '-loops-defer))  
        (m-loops-defer-mobj  (symbol-append name '-m-loops-defer))  
        (chords-defer-mobj (symbol-append name '-chords-defer)) 
        (bar-1-mobj       (symbol-append name '-bar-1))
        (bar-2-mobj       (symbol-append name '-bar-2))
        (bar-3-mobj       (symbol-append name '-bar-3))
        (bar-4-mobj       (symbol-append name '-bar-4))

        (_  (hash-table           ; settings hash-table, holds serializable settings
          :rows 16
          :cols 32    
          :chord-rows 5
          :loop-cols 2
          :row-meta #f      ; will hold the meta-data for each row in the view
          :receiver #f      ; view message receiver
          :bar      1       ; note: counts from 1 up so display is sensible
          :seq      #f      ; this view only watches one sequencer
          )))          

    ; save this let environment as 'env locally (used in getters and setters below)
    (define env (curlet))

    ; row meta data is a vector of hash-tables of seq ref, ptrk num, and offset
    ; it holds the metadata used to query the right things for data in a view
    (define (init-row-meta)
      ;(post "init-row-meta")
      (set! (_ :row-meta) (make-vector (_ :rows) #f))
      (dotimes (row-num (_ :rows))
        (set! ((_ :row-meta) row-num) (hash-table)) 
        ; setup defaults, each line shows the corresponding ptrack
        (set-row row-num (_ :seq) row-num 0))
    )

    ; public function to set row-meta for a row (seq, param, offset) 
    (define (set-row row-num seq param offset)
      "set a rows meta-data"
      (let ((row-ht ((_ :row-meta) row-num)))
        (set! (row-ht :seq) seq)
        (set! (row-ht :param) param)
        (set! (row-ht :offset) offset)))

    ; public functions for setting individual row-meta attributes
    (define (set-row-seq row-num seq) 
      (set! (((_ :row-meta) row-num) :seq) seq))
    (define (set-row-param! row-num param) 
      (set! (((_ :row-meta) row-num) :param) param))
    (define (set-row-offset! row-num offset) 
      (set! (((_ :row-meta) row-num) :offset) offset))

    ; refresh, used to update the internal data by querying all
    ; the seqs referred to in the row-meta data
    ; depends on the sequencer implementing the 'get-ptrk msg
    ; writes to the s4m array used as the frame buffer
    (define (refresh)
      ;(post name "refreshing" name-main name-loops name-chords)
      ;(post "showing bar: " (_ :bar))
     
      ; update message boxes
      ;(post "seq-name-mobj:" seq-name-mobj)
      (let ((seq (_ :seq)))
        (send seq-name-mobj 'set (seq 'get 'name))
        (send bar-1-mobj 'set (_ :bar))
        (send bar-1-mobj 'bang) ; the bang ripples to the other bar objects
        (send m-loops-defer-mobj (seq 'loop-len) (seq 'chord-loop-len)))

      ;(post "refresh, name-main:" name-main "name-loops:" name-loops)

      ; loop through rows for main data view and side loop data
      (dotimes (row-num (_ :rows))
        (let* ((rm ((_ :row-meta) row-num))
               ;(seq (rm :seq))
               (seq (_ :seq))
               (param (rm :param))
               (offset (get-offset))
               (row-data (if  (and seq param offset)  
                              ; get seq data from the sequencer
                              (seq 'get-ptrk (rm :param) offset (_ :cols))
                              #f))
               (loop-data (if (and seq param offset)
                              (vector (seq 'ptrk-loop-len (rm :param)) 
                                    (seq 'ptrk-loop-top (rm :param)))
                              #f)))
          (if row-data
            (let* ((array-index (* row-num (_ :cols)))
                   (row-data-out row-data)) 
              (array-set-from-vector! name-main array-index row-data-out)))
          (if loop-data
            (let* ((array-index (* row-num (_ :loop-cols))))
              (array-set-from-vector! name-loops array-index loop-data)))
         )); end let and do times row

      ; chord view loop
      ; get the chord data - we take the seq ref from row meta for row 0 
      ; NB: this does not yet deal with bars, starts on 0
      (let* ((seq (_ :seq)) 
             (num-cols (_ :cols))
             (chord-data (copy (seq 'get :chord-data)))
             (chord-vector (make-vector (* (_ :cols) (_ :chord-rows)) 0)))
        ;(post "chord-data:" (chord-data 0) (chord-data 16))
        ; chord data IS correct at this point, even when gui is not
        (dotimes (col (_ :cols))
          (let* ((chord-index (+ (get-offset) col))
                 (col-chord (chord-data chord-index))
                 (col-chord-sorted (sort! (copy col-chord) >))    
                 )
            (dotimes (i (length col-chord))
              (let ((chord-grid-index (+ col (* i num-cols)))
                    (chord-note-num (col-chord-sorted i))
                   )
                (set! (chord-vector chord-grid-index) chord-note-num)
              ))))
        ;(post "chord-vector" chord-vector)
        (array-set-from-vector! name-chords 0 chord-vector)
      )

      ; now send a message to the defer receivers to trigger a refresh of the gui    
      ;(post "sending to" name-main name-loops name-chords)
      (send main-defer-mobj 'readarray name-main)     
      (send loops-defer-mobj 'readarray name-loops)     
      (send chords-defer-mobj 'readarray name-chords)     
      ; return null so as not to log 
      '()
    )

    ; method to format data according to view-model settings  
    (define (format-data row-num row-data)
      (let ((formatter (formatters row-num)))
        (if formatter 
          (list->vector (map formatter row-data))
          row-data)))

    ;* display formatters 
    (define (blank-zeros val) 
      (if (= 0 val) "" val))
    
    (define (count-from-one val)
      (+ 1 val))

    (define (get-offset)
      (* (dec (_ :bar)) (meta :steps-per-bar)))

    ;********************************************************************************
    ;* Boiler plate object implementation methods
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
        ;(post "step-seq env exported as" env-name)
    ))

    ; constructor logic, takes kwargs passed at constructor time
    ; and copies into the settings hash
    (define (init init-args)
      "constructor, sets up values and initializes sequencer"
      ; call process-kwargs to setup kwarg settings
      (process-kwargs init-args)
      (export-envs name)       

      (init-row-meta)
      ; create the s4m-arrays that act as this view's framebuffers
      (make-array name-main :int (* (_ :rows) (_ :cols)))
      (make-array name-loops :int (* (_ :rows) 2))
      (make-array name-chords :int (* (_ :chord-rows) (_ :cols)))

      (post "view" name "initialized")
    )
      
    ; call the constructor
    (init init-args)

    (lambda args
      "message dispatcher"
      ;(log-debug "dispatch:" args)
      (let* ((msg (car args)) 
             (fun-args (cdr args)))
        (apply (eval msg) fun-args)))
     
)); end object



; names to keep track of: view-model, patcher, arrays, sequencer it's watching
; chord-step view
;(define (cs-view-str name . init-args)
; 
;  (let ((data  #f)                ; will hold vector of vectors
;        (formatters (hash-table)) ; hash of rows to formatter functions
;        (name-main        (symbol-append name '-main))
;        (name-loops       (symbol-append name '-loops))
;        (name-chords      (symbol-append name '-chords))
;
;        ; max object scripting names in the linked patcher, set here to lower calls during refresh
;        (seq-name-mobj    (symbol-append name '-seq-name))    ; message box id for showing seq in view
;        (main-grid-mobj   (symbol-append name '-main-grid))   ; dest for sending grid the readarray messages
;        (loops-grid-mobj  (symbol-append name '-loops-grid))  ; dest for sending grid the readarray messages
;        (chords-grid-mobj (symbol-append name '-chords-grid)) 
;        (bar-1-mobj       (symbol-append name '-bar-1))
;        (bar-2-mobj       (symbol-append name '-bar-2))
;        (bar-3-mobj       (symbol-append name '-bar-3))
;        (bar-4-mobj       (symbol-append name '-bar-4))
;
;        (_  (hash-table           ; settings hash-table, holds serializable settings
;          :rows 16
;          :cols 32    
;          :chord-rows 5
;          :loop-cols 2
;          :row-meta #f      ; will hold the meta-data for each row in the view
;          :receiver #f      ; view message receiver
;          :bar      1       ; note: counts from 1 up so display is sensible
;          :seq      #f      ; this view only watches one sequencer
;          )))          
;
;    ; save this let environment as 'env locally (used in getters and setters below)
;    (define env (curlet))
;
;    ; row meta data is a vector of hash-tables of seq ref, ptrk num, and offset
;    (define (init-row-meta)
;      ;(post "init-row-meta")
;      (set! (_ :row-meta) (make-vector (_ :rows) #f))
;      (dotimes (row-num (_ :rows))
;        (set! ((_ :row-meta) row-num) (hash-table)) 
;        ; setup defaults, each line shows the corresponding ptrack
;        (set-row row-num (_ :seq) row-num 0))
;    )
;
;    ; public function to set row-meta for a row (seq, param, offset) 
;    (define (set-row row-num seq param offset)
;      "set a rows meta-data"
;      (let ((row-ht ((_ :row-meta) row-num)))
;        (set! (row-ht :seq) seq)
;        (set! (row-ht :param) param)
;        (set! (row-ht :offset) offset)))
;
;    ; public functions for setting individual row-meta attributes
;    (define (set-row-seq row-num seq) 
;      (set! (((_ :row-meta) row-num) :seq) seq))
;    (define (set-row-param! row-num param) 
;      (set! (((_ :row-meta) row-num) :param) param))
;    (define (set-row-offset! row-num offset) 
;      (set! (((_ :row-meta) row-num) :offset) offset))
;
;    ; refresh, used to update the internal data by querying all
;    ; the seqs referred to in the row-meta data
;    ; depends on the sequencer implementing the 'get-ptrk msg
;    ; writes to the s4m array used as the frame buffer
;    (define (refresh)
;      (post name "refreshing" name-main name-loops name-chords)
;      ;(post "showing bar: " (_ :bar))
;     
;      ; update message boxes
;      ;(post "seq-name-mobj:" seq-name-mobj)
;      (send seq-name-mobj 'set ((_ :seq) 'get 'name))
;      (send bar-1-mobj 'set (_ :bar))
;      (send bar-1-mobj 'bang)
;
;      ; loop through rows for main data view and side loop data
;      (dotimes (row-num (_ :rows))
;        (let* ((rm ((_ :row-meta) row-num))
;               (seq (rm :seq))
;               (param (rm :param))
;               (offset (get-offset))
;               (row-data (if  (and seq param offset)  
;                              (seq 'get-ptrk (rm :param) offset (_ :cols))
;                              #f))
;               (loop-data (if (and seq param offset)
;                              (vector (seq 'ptrk-loop-len (rm :param)) 
;                                    (seq 'ptrk-loop-top (rm :param)))
;                              #f)))
;          (if row-data
;            (let* ((array-index (* row-num (_ :cols)))
;                   ;(row-data-out (format-data row-num row-data))
;                   (row-data-out row-data)  ; trying skipping formatting
;                  ) 
;              (array-set-from-vector! name-main array-index row-data-out)))
;          (if loop-data
;            (let* ((array-index (* row-num (_ :loop-cols))))
;              (array-set-from-vector! name-loops array-index loop-data)))
;         )); end let and do times row
;
;      ; chord view loop
;      ; get the chord data - we take the seq ref from row meta for row 0 
;      ; NB: this does not yet deal with bars, starts on 0
;      ; XXX: something is fucked up in here badly
;      ; need to trace through how it's different from the main grid part which is working fine
;      
;      ; could try writing without dotimes? is there a var capture issue or something?
;      (let* ((seq (_ :seq)) 
;             (num-cols (_ :cols))
;             (chord-data (copy (seq 'get :chord-data)))
;             (chord-vector (make-vector (* (_ :cols) (_ :chord-rows)) "")))
;        (post "chord-data:" (chord-data 0) (chord-data 16))
;        ; chord data IS correct at this point, even when gui is not
;        (dotimes (col (_ :cols))
;          (let* ((chord-index (+ (get-offset) col))
;                 (col-chord (chord-data chord-index))
;                 (col-chord-sorted (sort! (copy col-chord) >))    
;                 (col-chord-str (map midi->string col-chord-sorted))
;                 )
;            (if (or (= col 16) (= col 0)) (post "chord at:" col col-chord col-chord-sorted col-chord-str))
;            ; ok to here too
;            (dotimes (i (length col-chord))
;              (let ((chord-grid-index (+ col (* i num-cols)))
;                    (chord-string (col-chord-str i))
;                    (chord-note-num (col-chord-sorted i))
;                   )
;                ; in the *console* the data here is all fine
;                (post "writing '" chord-string "' to grid index" chord-grid-index)
;                (set! (chord-vector chord-grid-index) chord-string)
;                ; NB: it's fine if I don't write the string!
;                ;(set! (chord-vector chord-grid-index) chord-note-num)
;                ; this is fine too
;                ;(set! (chord-vector chord-grid-index) "A99")
;                ; this is fucked up
;                ;(set! (chord-vector chord-grid-index) (number->string chord-note-num))
;
;                ; but it's also fine on the below, wtf???
;                ; (set! (chord-vector chord-grid-index) "C 5")
;                ; the below is borked
;                ;(array-set-from-vector! name-chords chord-grid-index (vector chord-string) )
;                ; ? this is ok though
;                ;(array-set-from-vector! name-chords chord-grid-index (vector "C88"))
;                ; but this is haywire
;                ;(array-set-from-vector! name-chords chord-grid-index (vector (number->string chord-grid-index) ))
;                
;              ))))
;        ;(post "chord-vector" chord-vector)
;        ;(array-set-from-vector! name-chords 0 chord-vector)
;        (send* chords-defer-mobj 'list 
;      )
;
;      ; now send a message to the low-instance to trigger a refresh of the gui    
;      (post "sending to" name-main name-loops name-chords)
;      (send main-grid-mobj 'readarray name-main)     
;      (send loops-grid-mobj 'readarray name-loops)     
;      ;(post "sending to" chords-grid-mobj "for array" name-chords)
;      (send chords-grid-mobj 'readarray name-chords)     
;      ; return null so as not to log 
;      '()
;    )
;
;    ; method to format data according to view-model settings  
;    (define (format-data row-num row-data)
;      (let ((formatter (formatters row-num)))
;        (if formatter 
;          (list->vector (map formatter row-data))
;          row-data)))
;
;    ;* display formatters 
;    (define (blank-zeros val) 
;      (if (= 0 val) "" val))
;    
;    (define (count-from-one val)
;      (+ 1 val))
;
;    (define (get-offset)
;      (* (dec (_ :bar)) (meta :steps-per-bar)))
;
;    ;********************************************************************************
;    ;* Boiler plate object implementation methods
;    (define (get k) 
;      "get var from settings hash if keyword, or local env otherwise"
;      (if (keyword? k) (_ k) (env k)))
;      
;    (define (set k v) 
;      "set var in settings hash for keywords, local env otherwise"
;      (if (keyword? k) (set! (_ k) v) (set! (env k) v)))
;
;    ; loop through an arg list, stripping out kw/v pairs and applying them
;    ; this allows setting state vars using k/v pairs in any method call
;    (define (process-kwargs args)
;      "filter kwargs arguments, setting in settings hash and removing from args"
;      ;(post "process-kwargs" args)
;      (let kwargs-loop ((args args))
;        (cond 
;          ((null? args) '())
;          ((keyword? (car args))
;            ; keywords go into the state dict
;            (set! (_ (car args)) (cadr args))
;            (kwargs-loop (cddr args)))
;          (else 
;              (cons (car args) (kwargs-loop (cdr args)))))))
;
;    (define (export-envs name)
;      "export this seqs env to rootlet for debugging/hacking"
;      ; save env as {name}-env and {name-env_} in the global namespace
;      (let ((env-name (string->symbol (string-append (symbol->string name) "-env")))
;            (env-name_ (string->symbol (string-append (symbol->string name) "-env_"))))
;        (varlet (rootlet) env-name env)
;        (varlet (rootlet) env-name_ (env '_))
;        ;(post "step-seq env exported as" env-name)
;    ))
;
;    ; constructor logic, takes kwargs passed at constructor time
;    ; and copies into the settings hash
;    (define (init init-args)
;      "constructor, sets up values and initializes sequencer"
;      ; call process-kwargs to setup kwarg settings
;      (process-kwargs init-args)
;      (export-envs name)       
;
;      (init-row-meta)
;      ; create the s4m-array to act as this views framebuffer
;      ;(post "creating string array, name:" name-main "rows:" (_ :rows) "cols:" (_ :cols))
;      ;(make-array name-main :string (* (_ :rows) (_ :cols)))
;      ;(make-array name-loops :string (* (_ :rows) 2))
;      ;(make-array name-chords :string (* (_ :chord-rows) (_ :cols)))
;      (make-array name-main :int (* (_ :rows) (_ :cols)))
;      (make-array name-loops :int (* (_ :rows) 2))
;      (make-array name-chords :int (* (_ :chord-rows) (_ :cols)))
;
;      (set! (formatters 0) blank-zeros)
;      (set! (formatters 2) inc)
;      (set! (formatters 4) blank-zeros)
;      (set! (formatters 5) blank-zeros)
;      (set! (formatters 6) blank-zeros)
;      (set! (formatters 7) blank-zeros)
;      (post "view" name "initialized")
;    )
;      
;    ; call the constructor
;    (init init-args)
;
;    (lambda args
;      "message dispatcher"
;      ;(log-debug "dispatch:" args)
;      (let* ((msg (car args)) 
;             (fun-args (cdr args)))
;        (apply (eval msg) fun-args)))
;     
;)); end object
;
;
;
