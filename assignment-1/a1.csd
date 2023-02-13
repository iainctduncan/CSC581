<CsoundSynthesizer>
<CsOptions>
</CsOptions>
; ==============================================
<CsInstruments>

sr	=	44100
ksmps	=	1
nchnls=	2
0dbfs	=	1

; make a sine table using using gen 10
giSine   ftgen     1, 0, 8192, 10, 1
; geometric saw, square, pulse
giSaw      ftgen     2, 0, 8192, 7,  0, 4096, 1, 0, -1, 4096, 0
giSquare   ftgen     3, 0, 8192, 7,  1, 4096, 1, 0, -1, 4096, -1
giPulse    ftgen     4, 0, 8192, 7,  1, 1024, 1, 0, -1, 7168, -1

instr 1
  ; takes the table number from above as p6 to choose waveform
  aosc  oscili  p4, mtof(p5), p6
  aenv  adsr    0.2, 0.0, 1.00, 0.4
  asig  = aosc * aenv
  outs  asig, asig
endin

instr 2
  anoise rand  1
  aenv  adsr    0.01, 0.1, 0.0, 0.01
  asig  = anoise * aenv
  outs  asig, asig
endin

</CsInstruments>
; ==============================================
<CsScore>

i1 0 1 0.5 60 1
i1 + . 0.5 62 2
i1 + . 0.5 64 3
i1 + . 0.5 60 4

i1 + . 0.5 60 1
i1 + . 0.5 62 2
i1 + . 0.5 64 3
i1 + . 0.5 60 4

i1 + . 0.5 64 1
i1 + . 0.5 65 2
i1 + 2 0.5 67 3

i1 + 1 0.5 64 1
i1 + . 0.5 65 2
i1 + 2 0.5 67 3

; and some noise
i2 17 2 1  


</CsScore>
</CsoundSynthesizer>

