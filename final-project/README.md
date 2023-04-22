# ScmSeq
## Live Sequencing platform for Max for Live

ScmSeq is a platform for live and algorithmic step sequencing in Max and
Ableton Live. It consists of Ableton Live host files, Max for Live devices,
the s4m extenstion for Max, and a collection of Scheme files run by s4m.

## Documentation
Project Documentation: https://iainctduncan.github.io/CSC581
(This is intended to replace the ISMIR format paper.)

## Demonstration Video
A video covering the new functionality implemented for CSC 581 is
here: https://vimeo.com/user29372309/scmseq-demo 

## Credits
ScmSeq was created by Iain C.T. Duncan

It runs on Scheme for Max, also by Iain C.T. Duncan, inside
Max 8 (Cycling 74) and Max for Live (Ableton).

Scheme for Max uses the s7 Scheme interpreter, by Bill Schottstaedt (CCRMA).

## Dependencies
ScmSeq has the following installation dependencies:

* Max 8 - www.cycling74.com
* Ableton Live with Max for Live - www.ableton.com
* Scheme for Max - https://github.com/iainctduncan/scheme-for-max

## Installation
* Install Ableton Live and Max for Live (included in Live Suite, also sold as an addon)
* Install the Scheme for Max extension as per the instructions on the GitHub page
* Copy the .amxd Max for Live devices from the devices folder into your Live devices directory
* Ensure that your Scheme files are included on the Max file path, accessed
  by editing a Max for Live device and opening "Options -> File Preferences"
* In the **tunes** directory, run the **new_tune.py** script for cloning the Ableton Live project file 


## Resources
* Project documentation: https://iainctduncan.github.io/CSC581
* Video tutorials on Scheme for Max, including installation and use in Ableton Live: 
  www.youtube.com/c/musicwithlisp
* Scheme for Max documentation: https://iainctduncan.github.io/scheme-for-max-docs/
* An online ebook on Learning Scheme for Max:
  https://iainctduncan.github.io/learn-scheme-for-max/introduction.html
* A paper on the scheduling system used in ScmSeq:
  http://webyrd.net/scheme_workshop_2021/scheme2021-final48.pdf
* Official documentation for s7 Scheme: 
  https://ccrma.stanford.edu/software/snd/snd/s7.html


## Milestones and Features
These milestones cover only new functionality added as part of CSC 581.
All functionality listed is demonstrated in the demo video.

* Chord-step sequencer (complete)
    * Enable the same sequencer to run in chord mode or regular step mode,
       based on values in pitch track (0-8 mean chord mode)
    * Enable paraphonic chord mode in addition to arpeggiation
* Performance mode (new, complete)
    * Change loop lengths of all tracks and ptracks
    * Change loop lengths of individual ptracks
    * Mute/Unmute sequencers
* Copy mode (new, in progress)
    * Select source bars (complete)
    * Select destination bars (complete)
    * Enable copying only specific ptracks (in progress)
    * Enable copying between tracks (in progress)
* Arp mode (improved, complete)
    * Change chord progression either temporarily (non-destructive) or by replacing
    * Change pitch ptrack loop length from keyboard 2
* Step mode (improved, complete)
    * Selection of duration from keyboard 2, in steps and ticks
    * Follow submode, in which steps auto-advance by current duration
    * Record mode, in which steps are recorded in realtime, entered quantized
    * Improve ability to edit ptrack data from keyboards, including meta
       key capability for creating parameter masks
* Drum mode (new, complete)
    * Enable programming drum patterns using keyboard 1 as step entry
    * Enable editing of param data from keyboard knobs and modwheels
    * Ability to edit ptrack data from keyboards, including meta
       key capability for creating parameter masks

