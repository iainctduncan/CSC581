(post "s4m-live-code/midi-input")

; helper function to parse from generic midi into a generic hashtable
; representing a midi msg with key'd values: :msg :chan: :note :vel :cc-num :cc-val
(define (parse-midi data-bytes)
  ;(post "parse-midi" data-bytes)
  (let* ((data-1 (data-bytes 0))
         (data-2 (data-bytes 1))
         ; note: aftertouch messages are missing data byte 3
         (data-3 (if (= (length data-bytes) 3) (data-bytes 2) #f))  
         (msg (cond 
                  ((and (>= data-1 128) (< data-1 144)) 'note-off)
                  ((and (>= data-1 144) (< data-1 160)) 'note-on)
                  ((and (>= data-1 176) (< data-1 192)) 'cc)
                  ((and (>= data-1 224) (< data-1 240)) 'bend)
                  ; todo: program 
                  (else #f)))
         (chan   (modulo data-1 16))
         (note   (if (or (eq? msg 'note-on) (eq? msg 'note-off)) data-2 #f))
         (vel    (if (or (eq? msg 'note-on) (eq? msg 'note-off)) data-3 #f))
         (cc-num (if (eq? msg 'cc) data-2 #f)) 
         (cc-val (if (eq? msg 'cc) data-3 #f))
         (bend-l (if (eq? msg 'bend) data-3 #f))
         )
    ; return the generic hash-table for an input msg
    (hash-table :msg msg :chan chan :note note :vel vel 
      :cc-num cc-num :cc-val cc-val :bend-l bend-l)))  


; helper to get a controller object from its name 
; assumes there exists a variable of instantiated controller, named {mode-name}-controller
; TODO: prob better to change this to a registry look up later
(define (get-controller mode-name)
  ;(post "get-controller" mode-name)
  (let* ((controller-name (string-append (symbol->string mode-name) "-controller"))
         (controller (eval-string controller-name)))
    controller)) 
    

;* MAX FUNCTION: midi-in
;* handles incoming midi messages, with device symbol prepended by Max
;* this is called from patcher, using the midi-devices sub-patch
;* looks for device specific parser functions and calls them if they exist
;* this depends on access to the meta object
;* and, by necessity, depends on controllers being active, because it has to route to them
(define (midi-in device . data-bytes)
  ;(post "midi-in" device data-bytes)
  (let* ((m (parse-midi data-bytes))
         ; call device parser, which may add :action, ie :action 'grid-btn
         (m (parse-input-for-device device m))
         (mode (meta :mode))
         )
    ; debug output 
    ;(if (and (m :msg) (not (eq? (m :msg) 'note-off)) (not (eq? (m :vel) 0))) 
    ;  (post "(midi-in) device:" device " input:" m))
    ;(post "(midi-in) device:" device " input:" m)
   
    ; branching by mode and device here 
    (define handled-by-mode
      (case mode 
        ;('name   ; MODE MAP TEMPLATE
        ;  (cond 
        ;    ((eq? device 'keystep)
        ;      (cond 
        ;        ((eq? (m :msg) 'note-on)
        ;          ((get-controller 'arp) 'note-on (m :note) (m :vel)))
        ;        ; add other arp mode mappings to the controller functions here
        ;        (else #f)))
        ;    (else #f)) ; must return false to have message bubble up to meta
        ;  );end mode mode 
        ('perform   ; MODE MAP TEMPLATE
          (cond 
            ((eq? device 'keystep) 
              (cond 
                ((eq? (m :msg) 'note-on)
                  ((get-controller 'perform) 'note-on (m :note) (m :vel)))
                ; add other arp mode mappings to the controller functions here
                (else #f)))
            ((eq? device 'keystep-2)
              (cond 
                ((eq? (m :msg) 'note-on)
                  ; normalize the keysteps to each because mini is set an octave lower for some reason
                  ((get-controller 'perform) 'note-on (+ 12 (m :note)) (m :vel)))
                ; add other arp mode mappings to the controller functions here
                (else #f)))
            ((eq? device 'fire)
              (cond 
                ; green fire meta buttons set grid submode
                ((eq? (m :action) 'meta-btn)
                  ((get-controller 'perform) 'set-grid-mode (m :btn)))
                ; fire upper right "grid" buttons set bars or steps
                ((and (eq? (m :msg) 'note-on) (eq? (m :note) 34))
                  ((get-controller 'perform) 'set-grid-unit 'steps))
                ((and (eq? (m :msg) 'note-on) (eq? (m :note) 35))
                  ((get-controller 'perform) 'set-grid-unit 'bars))
                (else #f)))
            ((or (eq? device 'pad-1) (eq? device 'pad-2))
              (cond
                ((eq? (m :action) 'grid-btn)
                  ((get-controller 'perform) 'grid-btn (m :row) (m :col)))
                ;((eq? (m :action) 'left-btn)
                ;  ((get-controller 'perform) 'left-btn (m :btn)))
                ;((eq? (m :action) 'right-btn)
                ;  ((get-controller 'arp) 'right-btn (m :btn)))
                ((eq? (m :action) 'bottom-btn)
                  ((get-controller 'perform) 'bottom-btn (m :btn)))
              ))

            (else #f)) ; must return false to have message bubble up to meta
        );end perform mode 

        ('copy   ; MODE MAP TEMPLATE
          (cond 
            ((eq? device 'keystep) 
              (cond 
                ((eq? (m :msg) 'note-on)
                  ((get-controller 'copy) 'note-on (m :note) (m :vel)))
                ; record btn - sets record
                ;((and (eq? (m :msg) 'cc) (= (m :cc-num) 50) (= (m :cc-val) 127)) 
                ;  ((get-controller 'copy) 'set-submode 1 'record)) 
                ; stop btb
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 51) (> (m :cc-val) 0)) 
                    ((get-controller 'copy) 'set-submode 1 'select))
                ; pause/play
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 54) (> (m :cc-val) 0)) 
                    ((get-controller 'copy) 'set-submode 1 'paste))
                ; add other arp mode mappings to the controller functions here
                (else #f)))
            ;((eq? device 'keystep-2)
            ;  (cond 
            ;    ((eq? (m :msg) 'note-on)
            ;      ; normalize the keysteps to each because mini is set an octave lower for some reason
            ;      ((get-controller 'perform) 'note-on (+ 12 (m :note)) (m :vel)))
            ;    ; add other arp mode mappings to the controller functions here
            ;    (else #f)))
            ((eq? device 'fire)
              (cond 
                ; green fire meta buttons set grid submode
                ((eq? (m :action) 'meta-btn)
                  ((get-controller 'copy) 'set-grid-mode (m :btn)))))
            ;    ; fire upper right "grid" buttons set bars or steps
            ;    ((and (eq? (m :msg) 'note-on) (eq? (m :note) 34))
            ;      ((get-controller 'perform) 'set-grid-unit 'steps))
            ;    ((and (eq? (m :msg) 'note-on) (eq? (m :note) 35))
            ;      ((get-controller 'perform) 'set-grid-unit 'bars))
            ;    (else #f)))
            ((or (eq? device 'pad-1) (eq? device 'pad-2))
              (cond
                ((eq? (m :action) 'grid-btn)
                  ((get-controller 'copy) 'grid-btn (m :row) (m :col)))
                ;((eq? (m :action) 'left-btn)
                ;  ((get-controller 'perform) 'left-btn (m :btn)))
                ;((eq? (m :action) 'right-btn)
                ;  ((get-controller 'arp) 'right-btn (m :btn)))
                ;((eq? (m :action) 'bottom-btn)
                ;  ((get-controller 'perform) 'bottom-btn (m :btn)))
              ))

            (else #f)) ; must return false to have message bubble up to meta
        );end perform mode 
  
        ('step   ; STEP MODE MAPPINGS
          (cond 
            ((eq? device 'keystep)
              (cond 
                ((eq? (m :msg) 'note-on)
                  ((get-controller 'step) 'note-on (m :note) (m :vel)))
                ((eq? (m :msg) 'note-off)
                  #f)
                ; record btn - sets record
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 50) (= (m :cc-val) 127)) 
                  ((get-controller 'step) 'set-submode 1 'record)) 
                ; stop btb
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 51) (> (m :cc-val) 0)) 
                    ((get-controller 'step) 'set-submode 1 'select))
                ; pause/play
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 54) (> (m :cc-val) 0)) 
                    ((get-controller 'step) 'set-submode 1 'follow))
                ; pedal 
                ((and (eq? (m :msg) 'cc) (eq? (m :cc-num) 64) (eq? (m :cc-val) 127))
                  ((get-controller 'step) 'pedal (if (eq? (m :cc-val) 127) #t #f)))
                ; keystep knobs 
                ((and (eq? (m :msg) 'cc) (between? (m :cc-num) 4 15))
                  ((get-controller 'step) 'cc (m :cc-num) (m :cc-val)))
                ; mod
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 1))
                  ((get-controller 'step) 'keyb-1-mod (m :cc-val)))
                ; pitchbend
                ((eq? (m :msg) 'bend) 
                  ((get-controller 'step) 'bend (m :bend-l)))
                (else #f)))
            ((eq? device 'keystep-2)
              (cond 
                ((eq? (m :msg) 'note-on)
                  ; normalize the keysteps to each because mini is set an octave lower for some reason
                  ((get-controller 'step) 'note-on-2 (+ 12 (m :note)) (m :vel)))
                ; record btn
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 50) (= (m :cc-val) 127)) 
                  ((get-controller 'step) 'set-submode 2 'erase)) 
                ; stop btb
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 51) (> (m :cc-val) 0)) 
                  ((get-controller 'step) 'set-submode 2 'dur))   
                ; pause/play
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 54) (> (m :cc-val) 0)) 
                  ((get-controller 'step) 'set-submode 2 'gate))
                ; mod
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 1))
                  ((get-controller 'step) 'keyb-2-mod (m :cc-val)))
                ; bend
                ((eq? (m :msg) 'bend) 
                  ((get-controller 'step) 'bend (m :bend-l)))
                ; add other arp mode mappings to the controller functions here
                (else #f)))
            ((or (eq? device 'pad-1) (eq? device 'pad-2))
              ;(post "step mode launchpad mini input")
              (cond
                ((eq? (m :action) 'grid-btn)
                  ((get-controller 'step) 'grid-btn (m :row) (m :col)))
                ((eq? (m :action) 'left-btn)
                  ((get-controller 'step) 'left-btn (m :btn)))
                ;((eq? (m :action) 'right-btn)
                ;  ((get-controller 'arp) 'right-btn (m :btn)))
                ;((eq? (m :action) 'bottom-btn)
                ;  ((get-controller 'arp) 'bottom-btn (m :btn)))
              ))

            (else #f) ; must return false to have message bubble up to meta
         ));end step mode 
        
        ('arp   ; ARP MODE MAPPINGS
          (cond 
            ((eq? device 'keystep)
              (cond 
                ((eq? (m :msg) 'note-on)
                  ((get-controller 'arp) 'note-on (m :note) (m :vel)))
                ((eq? (m :msg) 'note-off)
                  ((get-controller 'arp) 'note-off (m :note) 0))
                ; play vs program mode on the keystep from the top buttons
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 51) (= (m :cc-val) 127)) 
                  ((get-controller 'arp) 'set-mode 'program))
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 54) (= (m :cc-val) 127)) 
                  ((get-controller 'arp) 'set-mode 'play))
                ((and (eq? (m :msg) 'cc) (= (m :cc-num) 50) (= (m :cc-val) 127)) 
                  ((get-controller 'arp) 'set-mode 'override))
                ; add other arp mode mappings to the controller functions here
                (else #f)))
            ((or (eq? device 'pad-1) (eq? device 'pad-2))
              ;(post "arp mode launchpad mini input")
              (cond
                ((eq? (m :action) 'grid-btn)
                  ((get-controller 'arp) 'grid-btn (m :row) (m :col)))
                ((eq? (m :action) 'left-btn)
                  ((get-controller 'arp) 'left-btn (m :btn)))
                ((eq? (m :action) 'right-btn)
                  ((get-controller 'arp) 'right-btn (m :btn)))
                ((eq? (m :action) 'bottom-btn)
                  ((get-controller 'arp) 'bottom-btn (m :btn)))
              ))
            (else #f) ; must return false to have message bubble up to meta
          ));end arp mode            
        ('drum   ; DRUM MODE MAPPINGS
          (cond 
            ((eq? device 'keystep)
              (cond 
                ((eq? (m :msg) 'note-on)
                  ((get-controller 'drum) 'note-on (m :note) (m :vel)))
                ((eq? (m :msg) 'note-off)
                  ((get-controller 'drum) 'note-off (m :note) (m :vel)))
                ; keystep record, stop, play buttons
                ((and (eq? (m :msg) 'cc) (eq? (m :cc-num) 50) (eq? (m :cc-val) 127)) 
                  (post "keystep record button unused"))
                ((and (eq? (m :msg) 'cc) (eq? (m :cc-num) 51) (eq? (m :cc-val) 127)) 
                  (post "keystep stop button unused"))
                ((and (eq? (m :msg) 'cc) (eq? (m :cc-num) 54) (eq? (m :cc-val) 127)) 
                  (post "keystep play button unused"))
                ((and (eq? (m :msg) 'cc) (eq? (m :cc-num) 64) (eq? (m :cc-val) 127))
                  ((get-controller 'drum) 'pedal #t))
                ((and (eq? (m :msg) 'cc) (eq? (m :cc-num) 64) (eq? (m :cc-val) 0))
                  ((get-controller 'drum) 'pedal #f))
                ((and (eq? (m :msg) 'cc) (or (between? (m :cc-num) 4 15) (eq? (m :cc-num) 1)))
                  ((get-controller 'drum) 'cc (m :cc-num) (m :cc-val)))
                ((eq? (m :msg) 'bend) 
                  ((get-controller 'drum) 'bend (m :bend-l)))
                ; add other drum mode mappings to the controller functions here
                (else #f)))
            ((or (eq? device 'pad-1) (eq? device 'pad-2))
              ;(post "drum mode launchpad mini input")
              (cond
                ((eq? (m :action) 'grid-btn)
                  ((get-controller 'drum) 'grid-btn (m :row) (m :col)))
                ((eq? (m :action) 'left-btn)
                  ((get-controller 'drum) 'left-btn (m :btn)))
                ((eq? (m :action) 'right-btn)
                  ((get-controller 'drum) 'right-btn (m :btn)))
                ((eq? (m :action) 'bottom-btn)
                  ((get-controller 'drum) 'bottom-btn (m :btn)))
              ))
            (else #f) ; must return false to have message bubble up to meta
          )) 

        ; other mode mappings here
        ; ...
        (else #f)); end case mode
    ); end mode branch

    ; non-modal meta routings - handles global messages (track, bank, bar, etc)
    ;(post "  - msg now: " m)
    ; handled-by-mode will be #f if the msg was not caught by a case above
    (if (not handled-by-mode)
      (begin
        ;(if (and (not-eq? (m :msg) 'note-off) (not-eq? (m :cc-num) 123))
        ;  (post "msg not handled by mode:" m))
        (case (m :action) 
          ('grid-btn  
            (meta 'grid-btn (m :row) (m :col)))
          ('mode-btn
            ; TODO mode btns should go to meta too
            (meta 'mode-btn (m :btn)))
        )))
        
))

; top level dispatcher for parsing input from hardware devices
; looks for appropriately named device input parser function, ie. parse-input-pad-1 
; if found, this is called to alter or augment the input hash
; also adds the source device name to the msg hashtable
(define (parse-input-for-device device-name in-ht)
  (let* ((device-parser-fun-sym (symbol (string-append "parse-input-" (symbol->string device-name))))
        (device-parser-fun (if (defined? device-parser-fun-sym) (eval device-parser-fun-sym) #f)))
    ; add the device source to the msg hash
    (set! (in-ht :source) device-name)
    ; either parse and return the hash or just return hash as is
    ;(post "parse-input-for-device" device-parser-fun-sym device-parser-fun)
    (if device-parser-fun (device-parser-fun in-ht) in-ht)
    
))

; parse midi input from the left launchpad mini that is upside down
(define (parse-input-pad-1 msg-ht)
  ;(post "(parse-input-pad-1)")
  (let ((msg  (msg-ht :msg))
        (note (msg-ht :note))
        (vel  (msg-ht :vel))
        (cc-num (msg-ht :cc-num))
        (cc-val (msg-ht :cc-val)))
    ; helper for reversing midi note number lookup    
    (define (invert-0-7 num) (#(7 6 5 4 3 2 1 0) num))

    (case msg
      ('note-on
        (cond 
          ((and (<= note 119) (>= note 112) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 0  :col (invert-0-7 (- note 112))))
          ((and (<= note 103) (>= note 96) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 1  :col (invert-0-7 (- note 96))))
          ((and (<= note 87)  (>= note 80) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 2  :col (invert-0-7 (- note 80))))
          ((and (<= note 71)  (>= note 64) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 3  :col (invert-0-7 (- note 64))))
          ((and (<= note 55)  (>= note 48) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 4  :col (invert-0-7 (- note 48))))
          ((and (<= note 39)  (>= note 32) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 5  :col (invert-0-7 (- note 32))))
          ((and (<= note 23)  (>= note 16) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 6  :col (invert-0-7 (- note 16))))
          ((and (<= note 7)   (>= note 0) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 7  :col (invert-0-7 (- note 0))))
          ; left side buttons 
          ((and (= 0 (modulo (- note 8) 16)) (> vel 0))
            (hash-table-set* msg-ht :action 'left-btn  :btn (invert-0-7 (/ (- note 8) 16))))
          (else #f))
        ) 
      ('cc
        ; bottom buttons are cc, not note
        (if (= 127 cc-val)
          (hash-table-set* msg-ht :action 'bottom-btn  :btn (invert-0-7 (- cc-num 104)))))
    ); end case
    ;(post "row: " (msg-ht :row) "col:" (msg-ht :col))
    ; return the updated input-hash
    ;(post "parse-input-pad-1 returning msg hash:" msg-ht)
    msg-ht
))

; parse midi input from the right launchpad mini that is 90 degrees clockwise 
; probably should have just done this with a big hash table to be honest...
(define (parse-input-pad-2 msg-ht)
  ;(post "(parse-input-pad-2), msg-ht:" msg-ht)
  (let ((msg  (msg-ht :msg))
        (note (msg-ht :note))
        (vel  (msg-ht :vel))
        (cc-num (msg-ht :cc-num))
        (cc-val (msg-ht :cc-val)))
    ; helper for reversing midi note number lookup    
    (define (invert-0-7 num) (#(7 6 5 4 3 2 1 0) num))
    (define bottom-btn-table (hash-table 
      120 8  104 9  88 10  72 11  56 12  40 13  24 14  8 15))   

    (case msg
      ('note-on
        (cond
          ((bottom-btn-table note) 
            (hash-table-set* msg-ht :action 'bottom-btn  :btn (bottom-btn-table note)))
          (else
            (let ((row (remainder (modulo note 16) 16))
                   (col (+ 8 (invert-0-7 (floor (/ note 16.0))))))
              (hash-table-set* msg-ht :action 'grid-btn  :row row :col col)))
        )) 
      ('cc
        (if (= 127 cc-val)
           (hash-table-set* msg-ht :action 'right-btn  :btn (- cc-num 104))))
    ); end case
    ;(post "row: " (msg-ht :row) "col:" (msg-ht :col))
    ; return the update input-hash
    msg-ht
))

 
; parse midi input from the fire, adding to the midi-hash
(define (parse-input-fire msg-ht)
  ;(post "(parse-input-fire)")
  (let ((msg  (msg-ht :msg))
        (note (msg-ht :note))
        (vel  (msg-ht :vel))
        (cc-num (msg-ht :cc-num))
        (cc-val (msg-ht :cc-val)))
    
    (case msg
      ('note-on
        (cond 
          ((and (>= note 54) (<= note 69) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 0  :col (- note 54)))
          ((and (>= note 70) (<= note 85) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 1  :col (- note 70)))
          ((and (>= note 86) (<= note 101) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 2  :col (- note 86)))
          ((and (>= note 102) (<= note 117) (> vel 0))
            (hash-table-set* msg-ht :action 'grid-btn  :row 3  :col (- note 102)))
          ; side buttons act as meta keys, sending the 'meta-btn message
          ((and (>= note 36) (<= note 39))
            (hash-table-set* msg-ht :action 'meta-btn  :btn (- note 36)))
          ; bottom (fire mode) buttons send 'mode-btn 
          ((and (>= note 44) (<= note 53) (> vel 0))
            (hash-table-set* msg-ht :action 'mode-btn  :btn (- note 44)))
          (else #f))
        ) ; TODO add fire rotary later
    )
    ; return the update input-hash
    msg-ht
))
    

