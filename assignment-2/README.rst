Assignment 2
=============
Assignment 2 is very late, because I have spent so long learning complex numbers. 


**1)** MIDI to MIDI communication
---------------------------------
I used a 5-pin DIN cable to connect my controller keyboard to my Moog Grandmother,
from the MIDI out to MIDI in. I did not have to figure anything out because I am old and
wrote a school project in Computer Science 11 in 1990 on MIDI networks. ;-)


**2)** Complex Number Multiplication
------------------------------------
This took a lot of work because I am old and haven't done math in 30 years! Damn..
Anyway, after much reading, these are (mostly) making sense now.

To multiple (2 + j) by j, we can consider both multiplicands to be complex numbers with a real
and imaginary component. That is to say, j is equivalent to (0 + 1j).
As j squared is always -1, this means we can expand as follows:

* (2 + j) * j
* (2 + 1j) * (0 + 1j)
* (2 x 0) + (1 x 1 x j x j) + (2 x 1j) + (1j x 0)
* 0 - 1 + 2j + 0
* (-1 + 2j)

When complex numbers are expressed as vectors, we have the real component on the x axis
and the imaginary component on the y. Given that the product of two complex
numbers is the product of their magnitude and sum of their angles, we can see that
multiplying by a complex number is equivalent to rotating counter-clockwise.
Specifically, multiply by j is a rotation counter-clockwise of 90 degress.

This is born out by the above expansion, as our new number is at -1 on the x-axis
and 2j on the y.

**3)** MIDI to Computer
-----------------------
See project here: https://github.com/iainctduncan/CSC581/tree/main/final-project

MIDI input is handled in the file **midi-input.scm** in which it is converted from
raw MIDI data to normalized hash-tables prior to use by the rest of the system.

**4)** Amplitude Estimation in Mixtures 
---------------------------------------
I implemented this in a Max patch and accompanying Scheme file.
Plots are done in the Max patch and may be seen in the screenshot.

* Max patch: **a2_q4.maxpat**
* Scm file: **a2-q4.scm**
* Screenshot: **a2_q4.scm**
* Recording: **amplitude_mixture.wav**

**5)** Amplitude and Phase Estimation in Mixture 
------------------------------------------------
I implemented this in a Max patch and accompanying Scheme file.
Plots are done in the Max patch and may be seen in the screenshot.

* Max patch: **a2_q5.maxpat**
* Scm file: **a2-q5.scm**
* Screenshot: **a2_q5.scm**
* Recording: **amp_phase_mixture.wav**

**6**) Arpeggiator
--------------------------
See project here: https://github.com/iainctduncan/CSC581/tree/main/final-project

Files of interest are **chord-sequencer.scm** and **controllers.scm** (arp mode).


**7)** Equal Temperaments
--------------------------
I created a Max patch and a Scheme for Max program to play equal tempered scales of any division.

* Patch file: **a2-q7-scales.maxpat**
* Scheme file: **a2-q7.scm**
* Wav file: **scales.wav**
* Patch screenshot: **a2-q7.png**

**8**) Complex Number Plotting
------------------------------
Not done

**9**) Step Sequencer
------------------------------
Code and docs for a step-sequencer is here:
https://iainctduncan.github.io/s4m-stk/

**10**) Drum Machine
------------------------------
See project demo and code here:
https://github.com/iainctduncan/CSC581/tree/main/final-project

See the drum-controller in the file **controllers.scm**.




