; view functions for the tune
(load-from-max "views.scm")

; init the view model and have it track seq 1 params
(set! (*views* 'cs-view-1) (cs-view 'cs-view-1 :seq seq-1 :rows 8 :cols 64 :chord-rows 5))

(post "created views")
