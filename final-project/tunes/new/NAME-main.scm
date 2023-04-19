; top level file for the live code project dir
(post "loading NAME-main.scm")

(load-from-max "helpers.scm")
(load-from-max "step-sequencers.scm")
(load-from-max "chord-sequencer.scm")
(load-from-max "controllers.scm")
(load-from-max "midi-input.scm")
(load-from-max "score.scm")
(load-from-max "live-remote.scm")
(load-from-max "seq-load-save.scm")
(load-from-max "cv-output.scm")
(load-from-max "output.scm")
(load-from-max "sequencer-mutes.scm")

(define gate    0)
(define dur     1)
(define factor  2)
(define vel     3)

; this gets patched by the new tune script to set it to the data dir
(define *save-dir*  "SAVEDIR" )

(load-from-max "NAME-seq-1.scm")
(load-from-max "NAME-seq-2.scm")
(load-from-max "NAME-seq-3.scm")
(load-from-max "NAME-seq-4.scm")
(load-from-max "NAME-seq-5.scm")
(load-from-max "NAME-seq-6.scm")
(load-from-max "NAME-views.scm")
(load-from-max "NAME-scenes.scm")
(load-from-max "NAME-tools.scm")

(define track-sequencers (vector seq-1 seq-2 seq-3 seq-4 seq-5 seq-6 #f #f))

(define arp-controller (make-arp-controller 'arp-controller)) 
(arp-controller 'set-seq seq-1)
(meta :mode 'arp)
(meta :bpm 110)


(define (init)
  (post "(init) - empty"))

(define (start)
  (post "(start)")
  ; start all sequencers, they might be muted
  (for-each 
    (lambda (seq)(if seq (seq 'start))) 
    track-sequencers)
)

(define (stop) 
  (post "(stop)")
  (for-each (lambda (seq)(if seq (seq 'stop))) track-sequencers)
  (at-clear)
)



(post "NAME-main.scm loaded...")


