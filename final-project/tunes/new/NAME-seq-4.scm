; seq-4
(define seq-4 (chord-step-seq 'seq-4 
  :arp #t 
  :channel 4 
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
))

; put in chords
(seq-4 'update-chord-seq 0   '(60  63  67  70  ))

; ptrack data
(define (seq-4-base)
  (seq-4 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   )) 
  (seq-4 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-4 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-4 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-4 'update-ptrk 4 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  (seq-4 'update-ptrk 5 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  ;* master loop len
  (seq-4 'set :loop-len 64)
  ; loop lengths for gate dur factor vel
  (seq-4 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-4
(seq-4-base)

(define (seq-4-a)
  (post "seq-4-a"))

