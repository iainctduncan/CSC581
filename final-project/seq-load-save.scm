;load-save.scm - functions for loading and saving sequencers
(post "seq-load-save.scm")

(define *save-dir* #f)

(define (set-save-dir args)
  (let ((save-dir-joined (format #f "~{~a ~}" args)))
    ; trim trailing space
    (set! *save-dir* (substring save-dir-joined 0 (dec (string-length save-dir-joined)))))
  (post "project save dir now:" (string-append "'" *save-dir* "'"))
)
(listen 1 'set-save-dir set-save-dir)

(define (render-meta meta-hash key-list)
  ;(post "render-meta")
  (let (
        ;(out-str  "(load-meta seq (hash-table")
        (out-str   "\n (hash-table")
        (footer   "\n )"))
    (for-each
      (lambda (k)
        (set! out-str (string-append out-str (format #f "\n  ~W ~W" k (meta-hash k)))))
      key-list)
    (set! out-str (string-append out-str footer))
    out-str))

; render the seq data vector of vectors with space padding
(define (render-seq-data seq-data . args)
  ;(post "render-seq-data")
  (let* ((index  (if (null? args) 0 (car args)))
         ;(out-str  (format #f "\n(load-seq-data seq ~D (vector" index))
         (out-str  "\n (vector")
         (footer   "\n )"))
    (for-each
      (lambda (v)
        (set! out-str (string-append out-str (format #f "\n  #(~{~3d ~})" v))))
      seq-data)
    (set! out-str (string-append out-str footer))
    out-str))

;render the chord-sequence data to text
(define (render-chord-data chord-data . args)
  ;(post "render-chord-data")
  (let* ((index  (if (null? args) 0 (car args)))
         ;(out-str  (format #f "\n(load-chord-data seq ~D (vector" index))
         (out-str  "\n (vector")
         (footer   "\n )"))
    (for-each
      (lambda (l)
        (set! out-str (string-append out-str (format #f "\n  (list ~{~3d ~})" l))))
      chord-data)
    (set! out-str (string-append out-str footer))
    out-str))


(define (save-seq seq filename)
  (post "save-seq" filename "save-dir:" *save-dir*)
  "save a sequencers meta, seq-data, and chord data to a saved data list"
  (if *save-dir*
    (let* ((fullpath (string-append *save-dir* filename))
           (tag    (format #f "; saved file for sequencer ~A" (seq-1 'get 'name)))
           (header "\n(list\n")
           (seq-meta-str (render-meta (seq 'get '_) (seq 'get 'meta-keywords)))
           (seq-data-str (render-seq-data ((seq 'get '_) :seq-data)))
           (chord-data-str (render-chord-data ((seq 'get '_) :chord-data)))
           (footer "\n)")
           (out-str (string-append tag header seq-meta-str seq-data-str chord-data-str footer)))
      (call-with-output-file fullpath
        (lambda (port) (display out-str port)))
      (post "saved" (seq-1 'get 'name) "to" fullpath))
    ; else if no save-dir, error message
    (post "Error: no data save directory set")))

; TODO option that does *not* use save-dir?
(define (load-seq seq filename)
  "load a sequencers meta, seq-data, and chord data from a saved data list"
  (post "loading sequencer" (seq 'get 'name)) 
  (let* ((fullpath (string-append *save-dir* filename))
        (data (load fullpath))
        (seq-meta   (seq 'get '_))
        (seq-data   (seq 'get :seq-data))
        (seq-chords (seq 'get :chord-data)))
    (if (not-null? (data 0))
      (for-each
        (lambda (kv)(set! (seq-meta (car kv)) (cdr kv)))
        (data 0)))
    (if (not-null? (data 1))
      (seq 'set :seq-data (data 1)))
    (if (not-null? (data 2))
      (seq 'set :chord-data (data 2)))
    )) 


(define (load-seq seq file-or-data)
  "load a sequencers meta, seq-data, and chord data from a saved data list"
  (post "loading sequencer" (seq 'get 'name)) 
  (let* ((fullpath (if (list? file-or-data) #f (string-append *save-dir* file-or-data)))
        ; get the data
        (data (if (list? file-or-data) file-or-data (load fullpath)))
        (seq-meta   (seq 'get '_))
        (seq-data   (seq 'get :seq-data))
        (seq-chords (seq 'get :chord-data)))
    (if (not-null? (data 0))
      (for-each
        (lambda (kv)(set! (seq-meta (car kv)) (cdr kv)))
        (data 0)))
    (if (not-null? (data 1))
      (seq 'set :seq-data (data 1)))
    (if (not-null? (data 2))
      (seq 'set :chord-data (data 2)))
    )) 


(define (load-seq-data filename)
  "load a sequence to a global list variable set as var-name"
 (let* ((fullpath (string-append *save-dir* filename))
        (data (load fullpath)))
   ; return the loaded list
   (post "fullpath:" fullpath)
   (post "data:" data)
   data))


; example of simple serialization with no text output formatting
; filename needs to be absolute path for now
; object->string :readable saves in a reloadable form, but there is no formatting or ordering of keys
; so it's not great as a file one would then edit by hand
(define (save-seq-simple seq-obj filename)
  (let ((data (object->string (seq-1 'get '_) :readable)))
    (call-with-output-file filename
      (lambda (port) (write data port)))))



