Assignment 3
============


Question 1 - Watch video and comment
------------------------------------
I watched the video on Bad Gear on the DX-7. 
Like most videos on this channel, I thought it was pretty much on the mark.
I remember getting the Chowning book out of the library when I was about 20 and making some
FM patches in Csound, and being completely intimidated by the math involved in knowning
how to go after specific sidebands. 
One thing I thought was interesting was the bass patch with feedback. 
The feedback significantly improved (to my taste) the patch, and has me interested in
implementing this in software.
I was quite tempted by the Elektron Digitone when it came out, but thought it
ridiculous that, for about a thousand dollars,  it only does 8 voices and 4 operators.
Considering how much faster processors are now than they were in the 80's
this seems like a ludricous limitation and put me off buying it.
I'm interested instead to make my own with some kind of embedded device, such as 
the Bela or Daisy. Of course, I haven't had the time to do so, but the FM
coverage in class (and assignment 4) have me motivated to make this happen now.

Another thing I found interesting, and actually didn't realize until this class,
was how many of the DX algorithms are actually basic additive 
synthesis in parrallel to FM. This has me interested in exploring this with modern
capabilities (i.e. a lot more additive oscillators). 
It also has me wondering whether combining this with modal synthesis would be fruitful,
in that one could run the oscillators into banks of biquad filters as well.
It makes me think that there is real potential in exploring FM with the ability
now to make far more sinusoids and do these, and the envelopes, at higher resolutions
and with dynamic control. I suppose this says something about the instrument
market that there is an FM renaissance happening, but what is being released is
even less capable than the DX7, rather than more. I guess it's further evidence
that even 40 years later FM is still too frightening for the mass market. 
It made me chuckle that the video wrapped up with a pep talk on not being afraid of FM!

Question 2 Interview
--------------------
The interview I watched was Suzanne Cianni on Letterman from 1980.
If found it interesting that she said it's mostly televison commercials on which 
she made her living, and I was fascinated by the conversation on "silly sounds".
In particular, this highlighted for me the connection to some of the psycho-acoustic 
principles we discussed in class, particularly the way formant synthesis gives us an 
implicit idea of the size of the object or creature making the sound, regardless of the fundamental pitch.
Perhaps part of what makes some high pitch sounds seem silly is this, 
somewhat similar to what happens when we breath helium I suppose - after all, the
formant size can't be changing when we do so!
I also thought about this when they were discussing the sound that Letterman
said sounded like the studio was going to blow up. 
I thought it was intriguing that he choose as a metaphor *the studio*, something
so big they are actually **in it**. It was really noticeable how much Letterman
liked this sound, event without any kind of musical context.

As someone who has performed both serious music, physical comedy, and musical comedy,
I also was impressed with how funny she was, how much fun she seemed
to be having, and how well she riffed with Letterman. This is a refreshing
attitude to see compared to staid and deliberately somber attitude so often associated
with Serious Electronic Music. 

Question 3 - plot spectra of two mugs
-------------------------------------
I chose two very different mugs, one of which had a suprisingly tonal pitch 
center, and the other of which was quite dull. Presumably this had to do with
the difference in shape of the lips and body. 
I hit them with a drum stick, giving more body to the sound than a pencil.
I recorded my mugs and loaded the audio in Sonic Visualizer to 
get spectrograms. 

See files **mug-spectograms.png** for the two original mugs, and the
original recordings are in the **recordings** folder.


Question 4 - additive synthesis model
-------------------------------------
I used Max/MSP to make the additive synthesis models of each mug,
using the curve object and function objects to give me the chance
to tune the decay curves of the envelopes. 
Of course with only four partials, they sound much more tuned
than the originals, but it is very clear which is which.

The patch screen shot is in **mug-additive-patch.png** and the Max
file is in **mugs_additive.maxpat**. 

Recordings of the synthesis are in **mug-1-add.wav** and **mug-2-add.wav**.

Question 5 - modal synthesis model
-------------------------------------
I used Max/MSP to make the modal synthesis models of each mug,
using the filtergraph~ object to enter my data for
frequency, amplitude, and resoncance of each partial (returning coefficients), and
the biquad~ object with a burst of noise for the synthesis model. 
I used the same enveloping tools as in question 4. 
It may be that my biquad inputs weren't great, but these sounded
(surprisingly) less like my mugs. It was, however, still very clear
which was which. The first one sounded somewhat close
but one can really hear the noise from the source impulse, so 
I assume my coefficients weren't resonant enough.
The second one sounds like a percussive sound, without the noise
being apparent, but doesn't sound particularly porcelain.
It was, to my ear, a good way to make woody percussion sound.

The patch screen shot is in **mug-biquad-patch.png** and the Max
file is in **mugs_biquad.maxpat**. 

Recordings of the synthesis are in **mug-1-biquad.wav** and **mug-2-biquad.wav**.

Question 6 - comparing spectra
-------------------------------------
I loaded the spectograms in Sonic Visualizer to compare them each.
What is immediately visible is how in the additive version, there
are four very clearly delineated partials with no other frequencies
present, and in the biquad, there is a lot of noise across all frequencies.
They do, however, map quite well to the source compared to each other
(i.e. it's obvious which is which mug).
One can tell looking at the comparison that to get a better copy
we need something with more than four oscillators - the originals
have a higher number of (weaker) sidebands, rather than either none, or
an even distribution of noise. It also looks like the envelopes for the partials have
more variablility in the original.

The comparisons are in **mug-1-spectograms.png** and **mug-2-spectrograms.png**.

Question 7 - FM percussion patch
-------------------------------------
I used this assignment as a chance to learn Gen, so the percussion patch
is a mix of Max/MSP and Gen. The FM part is in Gen, and uses phase modulation.
The FM component uses two operators, with parameters for:

* base freq in Hz
* carrier multiple of base freq (as integer)
* modulator multple of base freq (as integer)
* offset of the modulator for creating non-integer mod ratios
* detune of the modulator as a multiple (i.e. 1 is no change)
* modulator depth

There is also a pitch drop amount that is applied before the value
hits the FM topology, for making percussive sounds from rapid drops
in pitch.

There are three envelopes: amp, mod depth, and pitch drop.
The envelopes are implemented in Max and sent into Gen as a signal.
They use the function and curve~ objects,
allowing me to tune the curvature of the env segments.
This allows one to get precise percussion sounds from altering the curve of
the pitch drop as well as the volume and brightness.

The file **fm_perc_patch.png** shows the Max patch and the Gen patch.
(Output of the gen patch just goes to a reverb and then the DAC).

The file **fm_perc.wav** has a recording of the sound, with real-time
manipulation of some of parameters and envelope settings.

Question 8 & 9
---------------
Not yet done, though I did (attempt) to read the paper.
I will probably come back to these if there is time. 

Question 10
-----------
All of my synthesis models for this assignment work in real time
and all recordings were done playing from Max in real time into Reaper.

