; seq-6
(define seq-6 (chord-step-seq 'seq-6 
  :arp #f 
  :channel 6 
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
))

; put in chords
(seq-6 'update-chord-seq 0   '(60  63  67  70  ))

; ptrack data
(define (seq-6-base)
  (seq-6 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   )) 
  (seq-6 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-6 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-6 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-6 'update-ptrk 4 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  (seq-6 'update-ptrk 5 0       #(64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  64  ))
  ;* master loop len
  (seq-6 'set :loop-len 64)
  ; loop lengths for gate dur factor vel
  (seq-6 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-6
(seq-6-base)

(define (seq-6-a)
  (post "seq-6-a"))

