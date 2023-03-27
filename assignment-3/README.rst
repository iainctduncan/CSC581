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
coverage in class (and assignment 4) have me motivate to make this happen now.

Another thing I found interesting, and actually didn't realize until this class,
was how many of the DX algorithms are really very basic additive 
synthesis added to FM. This has me interested in exploring this with modern
capabilities (i.e. a lot more additive oscillators). 
It also has me wondering whether combining this with modal synthesis would be fruitful,
in that one could run the oscillators into banks of biquad filters as well.
It makes me think that there is real potential in exploring FM with the ability
now to make far more sinusoids and do these, and the envelopes, at higher resolutions
and with dynamic control. I suppose this says something about the instrument
market that there is an FM renaissance happening, but what is being released is
even less capable than the DX7 rather than more. 

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
I also was really impressed with how much funny she was, how much fun she seemed
to be having, and how well she riffed with Letterman.

Question 3 - plot spectra of two mugs
-------------------------------------
I chose two very different mugs, one of which had a suprisingly tonal pitch 
center, and the other of which was quite dull. Presumably this had to do with
the difference in shape of the lips and body. 
I recorded my mugs and loaded the audio in Sonic Visualizer to 
get spectrograms. See files `mug-spectograms.png`_ for the two original mugs.

Question 4 - additive synthesis model
-------------------------------------
I used Max/MSP to make additive synthesis models of each mug,
using the curve object and function objects to give me the chance
to tune the decay curves of the envelopes. 
Of course with only four partials, they sound much more tuned
than the originals, but it is very clear which is which.
The patch screen shot is in **mug-additive-patch.png** and the Max
file is in **a3q4.maxpat**. 
Recordings of the synthesis are in **mug-1-add.wav** and **mug-2-add.wav**.

Question 5 - additive synthesis model
-------------------------------------
I used Max/MSP to make the modal synthesis models of each mug,
using the filtergraph~ object to get enter my data for
frequency, amplitude, and resoncance of each partial, and
the biquad~ object with a burst of noise for the synthesis model. and function objects to give me the chance
I used the same enveloping tools as in question 4. 
It maybe that my biquad inputs weren't great, but these sounded
(surprisingly) less like my mugs. It was still very clear
which was which however. The first one sounded somewhat close
but once can really hear the noise from the source.
The second one sounds like a percussive sound, without the noise
being apparent, but doesn't sound particularly porcelain.

The patch screen shot is in **mug-biquad-patch.png** and the Max
file is in **a3q4.maxpat**. 

Recordings of the synthesis are in **mug-1-biquad.wav** and **mug-2-biquad.wav**.

Question 6 - comparing spectra
-------------------------------------
I loaded the spectograms in Sonic Visualizer to compare them each.
What is immediately visible is how in the additive version, there
are four very clearly dilineated partials with no other frequencies
present, and in the biquad, there is a lot of noise across all frequencies.
They do, however, map quite well to the source compared to each other.
One can tell looking at the comparison that to get a better copy
we need something with more than four oscillators - the originals
have a lot more sidebands that are weaker, rather than either none, or
an even distribution. It also looks like the envelopes for the partials have
more variablility in the original.

The comparisons are in **mug-1-spectograms.png** and **mug-2-spectrograms.png**.

Question 8 & 9
---------------
Not yet done, though I did (attempt) to read the paper.

Question 10
-----------
All of my synthesis models for the assignment work in real-time.

