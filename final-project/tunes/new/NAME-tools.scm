; live set specific tool functions
; set specific because they depend on device numbering, fix to not be set specific later

(define (instr-track? track-num)
  (<= track-num 8))
(define (audio-track? track-num)
  (> track-num 9))

(define (gain track value . args)
  (let* ((beats (if (null? args) 0 (car args)))
         (track-num (- track 1))
         (device-num (cond 
                      ((instr-track? track) 2) 
                      ((audio-track? track) 0) 
                      (else #f))))
    ;(post "beats" beats "track-num" track-num "device" device-num)
    (if device-num (begin    
      (l 'set-device-param track-num device-num 3 beats)
      (l 'set-device-param track-num device-num 2 value)))))

(define (fc track value . args)
  (let* ((beats (if (null? args) 0 (car args)))
         (track-num (- track 1))
         (device-num (cond 
                      ((instr-track? track) 2) 
                      ((audio-track? track) 0) 
                      (else #f))))
    ;(post "beats" beats "track-num" track-num "device" device-num)
    (if device-num (begin    
      (l 'set-device-param track-num device-num 5 beats)
      (l 'set-device-param track-num device-num 4 value)))))


; define what happens when selecting a track on the fire
(define (select-track-hook track)
  (post "select-track-hook" track)
  (let ((track-seq (track-sequencers track)))
    (if track-seq (begin
      (arp-controller 'set-seq (track-sequencers track))
      ((*views* 'cs-view-1) 'set :seq (track-sequencers track))
    ))))


