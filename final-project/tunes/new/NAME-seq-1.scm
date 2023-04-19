; seq-1
(define seq-1 (chord-step-seq 'seq-1 
  :arp #t 
  :channel 1 
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
  :transpose 0
))

; put in chords
(seq-1 'update-chord-seq 0   '(60  63  67  70  ))

; ptrack data
(define (seq-1-base)
  (post "seq-1-base")
  (seq-1 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-1 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-1 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-1 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-1 'update-ptrk 4 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  (seq-1 'update-ptrk 5 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  ;* master loop len
  (seq-1 'set :loop-len 64)
  ; loop lengths for gate dur factor vel
  (seq-1 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-1
(seq-1-base)

(define (seq-1-a)
  (post "seq-1-a"))

