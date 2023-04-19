; seq-2
(define seq-2 (chord-step-seq 'seq-2 
  :arp #t 
  :channel 2 
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
  :transpose 0
))

; put in chords
(seq-2 'update-chord-seq 0   '(60  63  67  70  ))

; ptrack data
(define (seq-2-base)
  (seq-2 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-2 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-2 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-2 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-2 'update-ptrk 4 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  (seq-2 'update-ptrk 5 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  ;* master loop len
  (seq-2 'set :loop-len 64)
  ; loop lengths for gate dur factor vel
  (seq-2 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-2
(seq-2-base)

(define (seq-2-a)
  (post "seq-2-a"))

