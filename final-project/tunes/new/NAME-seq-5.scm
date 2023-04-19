; seq-5
(define seq-5 (chord-step-seq 'seq-5 
  :arp #t 
  :channel 5 
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
  :transpose -12
))

; put in chords
(seq-5 'update-chord-seq 0   '(60  63  67  70  ))

; ptrack data
(define (seq-5-base)
  (seq-5 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   )) 
  (seq-5 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-5 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-5 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-5 'update-ptrk 4 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  (seq-5 'update-ptrk 5 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  ;* master loop len
  (seq-5 'set :loop-len 64)
  ; loop lengths for gate dur factor vel
  (seq-5 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-5
(seq-5-base)

(define (seq-5-a)
  (post "seq-5-a"))

