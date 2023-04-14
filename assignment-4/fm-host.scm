(post "fm-host.scm")

(define num-voices 3)
; counter for events to determine the oldest
(define event-num 0)

; notes-voices is a hash of notenum keys to voice num entries
; value will be #f if not playing, event num if playing
(define notes-voices (hash-table))
; voices-notes is a vector of notenums keyed by voice
(define voices-notes (make-vector num-voices #f))
; voices-notes is a vector of event numbers keyed by voice
; keeps track of age of voice
(define voices-times (make-vector num-voices #f))

(define (use-voice voice note-num vel)
  "use a voice to play the note, updating data"
  ;(post "use-voice" voice note-num vel)
  (set! (notes-voices note-num) voice)
  (set! (voices-notes voice) note-num)
  (set! event-num (+ 1 event-num))
  (set! (voices-times voice) event-num)
  (post " - playing note" note-num "with voice" voice)
  (send 'fm-poly 'target (+ 1 voice))
  (send 'fm-poly 'noteon note-num vel) 
  #t
  )

(define (noteon note-num vel)
  (post "noteon" note-num vel)
  (cond 
    ; if this note is already playing, use that voice
    ((notes-voices note-num)
      (use-voice (notes-voices note-num) note-num vel))
    ; else we need to look for a free voice or oldest voice
    (else
      (let ((v 0)
            (oldest-voice 0)
            (oldest-event #f))
        (while (< v num-voices)
          (cond 
            ; if we find a free voice, use it
            ((eq? (voices-times v) #f)
              (post " - using free voice" v)
              (use-voice v note-num vel)
              (break))
            ; else find the voice with the oldest playing note
            (else 
              (if (or (eq? #f oldest-event) (< (voices-times v) oldest-event))
                (begin 
                  (set! oldest-voice v)
                  (set! oldest-event (voices-times v))))))
          (cond 
            ; if we are at the end of our voices, use the oldest one
            ((= v (- num-voices 1))
              ; erase its previous entry in the notes hash
              (set! (notes-voices (voices-notes oldest-voice)) #f)
              (use-voice oldest-voice note-num vel)
              (break))
            (else
              (set! v (+ 1 v)))))))))

(define (noteoff note-num vel)      
  (post "noteoff" note-num vel)
  (let ((voice (notes-voices note-num)))
    (set! (notes-voices note-num) #f)
    (if voice
      (begin
        (set! (voices-times voice) #f)
        (set! (voices-notes voice) #f)
        (send 'fm-poly 'target (+ 1 voice))
        (send 'fm-poly 'noteoff note-num)))))
        
(define (midi-in note-num vel)
  (if (= 0 vel)
    (noteoff note-num vel)
    (noteon note-num vel)))
