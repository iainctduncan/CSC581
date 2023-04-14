(post "fm-host-mono.scm")

(define (noteon note-num vel)
  (post "noteon" note-num vel)
  (send 'fm4op 'noteon note-num vel))

(define (noteoff note-num vel)      
  (post "noteoff" note-num vel)
  (send 'fm4op 'noteoff note-num vel))
        
(define (midi-in note-num vel)
  (if (= 0 vel)
    (noteoff note-num vel)
    (noteon note-num vel)))
