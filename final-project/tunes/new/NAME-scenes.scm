; scene definitions for tunes
; these are triggered if the M&S channel has midi triggering enabled, to allow
; triggering these s4m scene functions from ableton scenes

; convenience alias
(define sm seq-mute)

(s-mutes '(1 1   2 0   3 0   4 0   5 0   6 0   7 0   8 0))



(define (s-init) (post "s-init"))

(define (s-1) (post "(s-1)") 
  (s-init)
  ; start with all sequencers muted
  ; (s-mutes '(1 0   2 0   3 0   4 0   5 0   6 1   7 0   8 0))
  ; example of unmuting at a time
  ;(at :8-2 (sm 6 0)) 
  ; example of a chain of mute/unmute for seq 1
  ;(smt 1  :2-1 1  :3-1 0  :4-1 1  :5-1 0  :6-1 1  :7-1 0  :8-1 1  );:9-1 0)
)
(define (s-2) (post "(s-2)")) 
(define (s-3) (post "(s-3)")) 
(define (s-4) (post "(s-4)")) 
(define (s-5) (post "(s-5)")) 
(define (s-6) (post "(s-6)")) 
(define (s-7) (post "(s-7)")) 
(define (s-8) (post "(s-8)")) 
