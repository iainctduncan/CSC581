; file with the note output functions
; todo: will prob become an object that sets override
(post "output.scm loading")

; note is a hashtable with keys :dur :note :vel :mod-1 :mod-2 :mod-3 :mod-4
; it's common to redefine this in the track specific tools to set which tracks
; get what kind of output
(define (note-output channel note)
  ;(post "note-output" channel note)
  ; MIDI version: we send two mod args that get turned into modwheel and pitchbend
  ; todo: we might want to actually send the mods out explicitly in code so they 
  (out 0 (list channel (note :pitch) (note :vel) (note :dur) (note :mod-1) (note :mod-2)))
  ; cv version that doesn't go through midi output, uses code in cv-output.scm
  ; this sends to the es-5 decoder on the s4m device (no sends and receives)
  (if (<= channel 5)
    (cv-note-out (dec channel) (note :dur) (note :pitch) (note :vel)))

  ; todo: make a gate only out
)

; note hashtable has a list in key :pitch
(define (chord-output channel note)
  ;(post "chord-output" channel note)
  (cond 
    ((= channel 6)
      (csound-chord 6 note)
      (midi-chord 6 note)
      )
    (else
      (post "no chord output configured for channel" channel)))
)

(define (midi-chord channel note)
  "send out midi chord notes"
  ;(post "midi-chord" note)
  (let ((pitches (note :pitch)))
    (for-each
      (lambda (pitch)
        (out 0 (list channel pitch (note :vel) (note :dur) (note :mod-1) (note :mod-2))))
      pitches)))


; note: this assumes the playing csound instrument will be i1
; XXX for now this is using (meta :bpm) to get tempo for dur, should not need to do this!
; TODO this needs to send gate output
(define (csound-chord channel note)
  ;(post "csound-chord channel" channel "note" note)
  ;(post "csound-chord channel" channel)
  (let* ((note (copy note))
         (dest (symbol (string-append "cs-" (number->string channel))))
         (pitches (note :pitch))
         (vel (note :vel))
         (dur-ticks (note :dur)) 
         (dur-ms (* dur-ticks (/ 0.125 (meta :bpm))))
         (mod-params (note :mod-params)))
    (dotimes (i (length pitches))
      (let* ((i-num (+ 1 (* (inc i) 0.1)))
             (evt-list (append (list dest 'event 'i i-num 0 dur-ms (pitches i) vel) mod-params)))
        ;(post "evt-list" evt-list)
        (apply send evt-list)))
    ; send a midi style note out too that can be used by the cv-tools (use lowest pitch)
    (set! (note :pitch) ((note :pitch) 0))
    (note-output channel note)
  )
)
