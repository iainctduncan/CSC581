(dotimes (i 4)
  (post "foo" i))

(fill-sine 'buf 0.5 110)

(buffer-size 'buf)

(clear-buf 'buf)

'((1 1) (2 .4))

(fill-additive 'buf 110 '((1 1) (2 1))) 

(fill-additive 'buf-1 110 '((1 1) (2 1))) 
(fill-additive 'buf-1 110 '((1 1) (2 1))) 
(fill-additive 'buf-1 110 '((1 1) (2 1))) 
(fill-additive 'buf-1 110 '((1 1) (2 1))) 
  
(random 1.0)

`((1 ,(random 1.0)) (2 ,(random 1.0)))

(buf-dp 'buf-4 100)

