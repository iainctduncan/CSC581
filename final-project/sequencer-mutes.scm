; sequencer-mutes.scm arms sequencers off track mutes
; this file is loaded in the main interpreter, while seq-mutes is for a separate interpreter which 
; sends messages to this one
(post "sequencer-mutes.scm")

(define tracks-to-sequencers (hash-table
  1  'seq-1
  2  'seq-2
  3  'seq-3
  4  'seq-4
  5  'seq-5
  6  'seq-6
  7  'seq-7
  8  'seq-8
  9  'seq-9
  10 'seq-10
  11 'seq-11
  12 'seq-12
  13 'seq-13
  14 'seq-14
  15 'seq-15
  16 'seq-16
))


(define (seq-mute track status)
  ;(post "seq-mute" track status)
  (let* (;seq will be false if not registered in tracks-to-sequencers
         (seq-sym (tracks-to-sequencers track))
         (seq (if (defined? seq-sym) (eval seq-sym) #f))
         (muted (if (= status 1) #f #t)))
    (cond 
      ((and seq muted)
        ;(post "muting" seq-sym)
        (seq 'set :mute #t))
      ((and seq (not muted))
        ;(post "unmuting" seq-sym)
        (seq 'set :mute #f)))
    '()
))

(define (s-mutes tracks-statuses)
  (let mloop ((args tracks-statuses))
    (seq-mute (car args) (cadr args))
    (if (> (length args) 2)
      (mloop (cddr args)))))


; the seq mute track helper, allows calling mutes for a seq like
;(smt 1   :1-1 1   :1-2 0   :1-3 1)
; NB: this depends on the at macro stuff being loaded, currently in score
(define (smt seq-num . args)
  (let args-loop ((largs args))
    (let ((bbt (largs 0)) (mute-status (largs 1)))
      (at bbt (seq-mute seq-num mute-status)) 
      (if (> (length largs) 2)
        (args-loop (cddr largs))))))

