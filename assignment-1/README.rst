Assignment 1 - 2023-02-06 
=========================

My assignment is implemented as a website using the WebAudio API, a WebAudio worklet, and a 
WebAssembly synthesizer created in C++ and run in the worklet.

A 7 minute video walkthrough of my submission is here:
https://youtu.be/TgRyDQjHNh8
This includes demo of the app, playback of all the waves and the score, and code walkthrough.


Basic 
---------------
See the video for the code walk through. All code for the synth is in audio_process.cpp
All oscillator questions have been implemented with wavetables and phasors.

Expected
---------
Polyphony and scoring is handled using a Csound like score language and a scheduler. See video.

2023-02-06 - missing is the Max and Csound implementation for questions 7 and 8, these will be added tomorrow.


Advanced questions
------------------
I have implemented anti-aliasing saw and square oscillators using additive synthesis in wavetables in
lieu of question 20.

I have (foolishly) implemented the whole thing in WebAudio/WASM as a sub for question 11/12


Files
------
This repository contains the following:

audio_process.cpp
  The C++ implementation of the synthesizer that is compiled to WebAssembly

index.html 
  the containing page

audio_host.js
  the main JS host running off the index, which creates a WebAudio context and instantiates the AudioWorklet

processor.js
  The JS for the worklet, which instantiates the Web Assembly module

build.sh
  the Emscripten build file




