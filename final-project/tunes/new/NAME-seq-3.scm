; seq-3
(define seq-3 (chord-step-seq 'seq-3 
  :arp #t 
  :channel 3 
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
))

; put in chords
(seq-3 'update-chord-seq 0   '(60  63  67  70  ))

; ptrack data
(define (seq-3-base)
  (seq-3 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   )) 
  (seq-3 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-3 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-3 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-3 'update-ptrk 4 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  (seq-3 'update-ptrk 5 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  ;* master loop len
  (seq-3 'set :loop-len 64)
  ; loop lengths for gate dur factor vel
  (seq-3 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-3
(seq-3-base)

(define (seq-3-a)
  (post "seq-3-a"))

