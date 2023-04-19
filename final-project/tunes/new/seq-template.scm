; seq-6
(define seq-NUM (chord-step-seq 'seq-NUM 
  :arp #t 
  :channel NUM
  :params 8 
  :steps 128 
  :loop-len 16 
  :time-factor 1
))

; put in chords
(seq-NUM 'update-chord-seq 0   '(60  63  67  74  ))

; ptrack data
(define (seq-NUM-base)
  (seq-NUM 'update-ptrk gate 0    #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-NUM 'update-ptrk dur  0    #(110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 110 ))
  (seq-NUM 'update-ptrk factor 0  #(1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   ))
  (seq-NUM 'update-ptrk vel 0     #(90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  90  ))
  (seq-NUM 'update-ptrk 4 0       #(60  60  60  60  60  60  60  60  60  60  60  60  60  60  60  60  ))
  (seq-NUM 'update-ptrk 5 0       #(60  60  60  60  60  60  60  60  60  60  60  60  60  60  60  60  ))
  ;* master loop len
  (seq-NUM 'set :loop-len 16)
  ; loop lengths for gate dur factor vel
  (seq-NUM 'update-loops #(16 16 16 16 16 16 16 16))
)
; execute the above to set up seq-NUM
(seq-NUM-base)

(define (seq-NUM-a)
  (post "seq-NUM-a"))

