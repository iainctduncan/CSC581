Assignment 4
============

**1)** I watched the documentary about the origins of the DX7 and FM Synthesis. 
This begins with a fascinating history, with great photos, of the connections
between Max Matthews' work at Bell, the Stanford AI lab, and Chowning's discovery of FM.
I did not previously know that the AI lab as run by John McCarthy, and 
was delighted to find this out as my project for this assignment is a 4 operator
FM synthesizer Max external designed to work well with Scheme.
I particularly like the background slides showing the various Music N 
versions and the machines they ran on. 
I also thought it was neat to see that Mathews gave Chowning a big stack
of punch cards to run the program. 
For me personally, it was also encouraging to learn that Chowning
came from a music background and had to learn to program to do this work.

**2)** I used the Ableton Live "Operator" instrument rather than the DX21. 
This is similar in many ways to a DX 21, and four operators with a
harmonic multiplier control (the "course" knob), a frequency control,
and an amplitude for each operator. A difference is that the amplitude
replaces the Modulation Index control, and is a dial with a scale
in dB. It is not clear from the interface how this maps to the phase shift.
Presumably it scales the output from the operators, but we don't know
how much phase shift full corresponds to.

I found two patches, "FM Bass Disto" and "FM Harpsichord Lead". 
These were recorded into Reaper and plotted using Sonic Visualizer, with screenshots
of the plots enclosed. One can see at a glance that the harpsichord
like sound was created by using a high degree of modulation 
producing a large number of similarly strong sidebands, all of which
last some time, while the bass sound has a smaller number of sidebands,
with a more pronounced change in their decay right from high to low.

**3)**
These are both based on a single multiple operator stack, the former
using three and the latter all four operators, thus only the first
operator is a carrier, and the remaining are acting as modulators
for the next operator down the stack. 
On the DX21 this would have been operator 1, though neither of these patches are using 
feedback, as is possible on the top operator in the DX algorithm.

The Deep Bass patch uses a ratio of 1:2:4 for the three operators,
with a detune of 500 cents on the 4. 
The top operator (ratio 4) uses a flat envelope with a high sustain
rate, and a triangle waveform. Muting it demonstrates that it
is contributing the higher overtones. 
The second operator and first both have sharp decay envelopes,
contributing to the punchiness of the sound.
This produces a sound that is similar to a substractive square wave bass, 
though one can see in the spectrogram that the partials do not descend in strength
linearly the way we would see with a square or saw source wave. 

The harpsichord uses a ratio of 1:1:4:8, with the top (8) operator
also detuned (though this makes little audible difference).
The top operator is at full amplitude, and essentially just provides
noise ("chuff") for the attack:
it has a very short decay time, and if one increases the sustain
on this operator to hear it for longer, it really just provides
some digital distortion type noise.
The second from top operator is providing the bright sound of the harpsichord,
turning it off leaves something sounding a bit like a filtered moog.
It's amplitude is also at 0 dB, but with an envelope that keeps this
open, thus producing many sidebands.
The third from top operator is at a 1:1 ratio with the carrier and
an amplitude of -11db, giving weight to lower end of the sound.

**4)**
I edited the bass sound by changing the ration from 1:2:4 to 1:2:3.
This changed the sound to make it sound much more like a distorted
pulse wave, rather than the hollow square sound. I also pulled the
envelope on the top operator down into a sharp decay, thus
producing an effect similar to a sharply decaying resonant filter
over a pulse wave. 
The spectogram and waveform plots are attached.

**5 and 6**)
I created a real-time FM synthesizer by making a Max external
for a 4 operator synthesizer, called **fm4op~**.
This is programmed in C using the Max SDK, and includes 4 oscillators,
4 envelopes, and 4 lfos (all of which are implemented in C).
Similar to the Ableton synth, I have a ratio control on each 
operator that is applied to the incoming pitch, which is then
applied to the base frequency of the incoming note.

Envelopes are all linear ADSR.
Oscillators and LFOs use wavescanning of a sine wave table populated on start.
Each envelope and oscillator can modulate their numerically equivalent
operators' tune and modulation index, where tune is a ratio in cents
used to adjust the operators frequency, and mod index is a value in
radians that is added to the phase increment for the operator 
(i.e. an amout of 1 moves the phase by 1 radian at peak amplitude
of the sine wave).
The synth is triggered by sending it a noteon or noteoff message.  The external is monophonic. 

Source code is **fm4op~.c** and the Max patcher files
are **fm4op-poly.maxpat** and **fm4op-host-mono.maxpat**.


**7)**
I attempted to copy my bass sound, and got pretty close. 
This uses 3 operators in 1:2:3 ratio with sharp envelopes on all
of them and a high amount of envelope to modulation index.

A screen shot of my path is in **my_bass_UI.png**.

Recordings are **recordings/my_bass_C.wav** and **recordings/my_bass_G.wav**.


**8)**
LFO and pitch modulation is enabled with both operator tune
and operator mod amount as targets.

Audio file demonstrating this is the same as question 9,
**recordings/my_poly.wav**

**9)**
I implemented polyphony at the Max level, using the **poly~** object. 
This allows a Scheme controller function to handle 
voice allocation via the **target** message to the poly object,
which specifices which instance should receive the message.

The polyphonic voice allocation is handled in Scheme, in the file **fm-host.scm**.
This implements voice stealing. The logic is that on a note in, 
entries are made in three data structures, one a hashtable keyed by note number and
holding voices, one a vector by voice number holding note numbers, 
and one a vector by voice number holding the id of the incoming event
(an auto incrementing integer).

On a new note:
* we check if the note is already being played, and reuse the playing voice if so
* if not, we iterate through the voices, keeping track of the current oldest event
* if a free voice is found, we use it
* if no free voice is found, we use the voice playing the oldest event

On a note off this is reversed.

A demo recording demonstrating polyphony, voice stealing, and a patch
using LFOs and envelopes on the modulation is in **recordings/my_poly.wav**.

**10**)
The external includes a message receiving layer and a dispatch table
such that all parameters can be changed by sending symbolic messages
to the object (e.g. "set evn1_to_tune 50"). 
I designed it this way in order to be able to script the synth
from Scheme for Max, allowing realtime modulation of any of the
parameters at a control rate equivalent to Max's signal vector size.

The UI is implemented in Max by connecting number boxes to messages 
that are then passed into the external and result in the set messages
detailed above. This allows seeing a large number of parameter on 
screen at once, and will also allow messages from S4M to easily 
update the GUI.

A screen shot of the path with the UI controls is
**fm_poly_patch.png** and one of the UI in presentation mode
is **fm4op_UI.png**.


