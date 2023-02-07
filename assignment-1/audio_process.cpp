#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <math.h>
#include <emscripten.h>

#include "params.h"

#ifdef __cplusplus
extern "C" {
#endif

const int EVT_BUF_SIZE = 128;
const int AUDIO_BLOCK_SIZE = 128;
const int SAMPLE_RATE = 44100;
const int OSC_TABLE_SIZE = 1024;
const int NUM_VOICES = 4;
enum shape { SINE, SAW, TRIANGLE, SQUARE, PULSE};

// a global static buffer for handling incoming event messages
float evt_buf[EVT_BUF_SIZE];
// JS can call getEvtBuf to get at the pointer to it
float* getEvtBuf() { return &evt_buf[0]; }

// a global static buffer for passing back audio to JS
// this becomes shared memory with the JS side
float g_out_buf[AUDIO_BLOCK_SIZE];
// function to hand JS the location in shared memory of the buffer
float* getOutBuf() { return &g_out_buf[0]; }


// a multi table oscillator (like a modular synth)
// shares one freq and phase, but can output three different waves
// they just use dumb geometric tables for now (aliases badly)
class WaveTableOsc {
  static const int waveforms = 5;
  public:
    int sr;
    // a phasor value that runs from 0 to 1
    float freq;
    float phasor;
    float wavetables[waveforms][OSC_TABLE_SIZE];
    // levels of sine, saw, square, noise
    float levels[waveforms];

    void init(float start_freq, float sine_lvl, float saw_lvl, float tri_lvl,
              float square_lvl, float pulse_lvl){
        freq = start_freq;
        levels[SINE] = sine_lvl;
        levels[SAW] = saw_lvl;
        levels[TRIANGLE] = tri_lvl;
        levels[SQUARE] = square_lvl;
        levels[PULSE] = pulse_lvl;
        initWaveTables();
        initAdditiveSaw();
        initAdditiveSquare();
    }

    void reset(){ phasor = 0.0; }

    // freq setter, stuff to implement glide will go here later
    void setFreq(float frq){ freq = frq; }

    void initWaveTables(){
      // SINE:
      for(int i=0; i < OSC_TABLE_SIZE; i++)
        wavetables[SINE][i] = sin( ((2 * M_PI) / OSC_TABLE_SIZE) * i);
      // Naive SAW
      for(int i=0; i < OSC_TABLE_SIZE; i++)
          wavetables[SAW][i] = ((2.0 / OSC_TABLE_SIZE) * i) - 1.0;
      // TRI
      for(int i = 0; i < OSC_TABLE_SIZE / 2; i++)
        wavetables[TRIANGLE][i] = ((2.0 / (OSC_TABLE_SIZE / 2)) * i) - 1.0;
      for(int i = OSC_TABLE_SIZE / 2; i < OSC_TABLE_SIZE; i++)
        wavetables[TRIANGLE][i] = wavetables[TRIANGLE][ i - (OSC_TABLE_SIZE / 2)] * -1.0;
      // Naive SQUARE
      for(int i=0; i < OSC_TABLE_SIZE; i++)
         wavetables[SQUARE][i] = i < OSC_TABLE_SIZE / 2 ? -1 : 1;
      // PULSE, fixed 10% duty cycle
      for(int i=0; i < OSC_TABLE_SIZE; i++)
        wavetables[PULSE][i] = i < OSC_TABLE_SIZE / 10 ? -1 : 1;
    }

    void initAdditiveSaw(){
      // create a saw wave table through additive synthesis
      // for C 256, 64 partials give us content up to 16384
      // we need to stay under the nyquist to not alias
      // should have one of these for each pitch ideally, like a sample
      for(int i=0; i < OSC_TABLE_SIZE; i++)
        wavetables[SAW][i] = 0.0;
      for(int partial = 1; partial <= 64; partial++){
        for(int i=0; i < OSC_TABLE_SIZE; i++)
          wavetables[SAW][i] += sin( ((2 * M_PI) / (OSC_TABLE_SIZE / partial) ) * i) * (1.0 / partial);
      }
    }

    void initAdditiveSquare(){
      // create a square wave table through additive synthesis
      // for C 256, 64 partials give us content up to 16384
      // we need to stay under the nyquist to not alias
      // should have one of these for each pitch ideally, like a sample
      for(int i=0; i < OSC_TABLE_SIZE; i++)
        wavetables[SQUARE][i] = 0.0;
      for(int partial = 1; partial <= 64; partial++){
        if(partial % 2 == 1)
          for(int i=0; i < OSC_TABLE_SIZE; i++)
            wavetables[SQUARE][i] += sin( ((2 * M_PI) / (OSC_TABLE_SIZE / partial) ) * i) * (1.0 / partial);
      }
    }

    // XXX: no idea why this isn't working, putting it to bed for now
    void setWaveLevel(int number, float value){
        if( value < 0) value = 0.0;
        if( value > 1.0) value = 1.0;
        levels[number] = value;
    }

    float renderSample(){
      // update the internal phasor and use it to look up table
      phasor = phasor + (freq / SAMPLE_RATE);
      if(phasor >= 1.0) phasor = 0;
      int tableIndex = (int) (OSC_TABLE_SIZE * phasor);
      float outSample = 0;
      for(int i=0; i < waveforms; i++){
          outSample += wavetables[i][tableIndex] * levels[i];
      }
      return outSample;
    }
};

// a statically timed linear attack sustain decay envelope
// for use with score events where total time is known
// does not handle envelope take over or allow editing env
// values mid note
// this is for Csound style scores - note dur known in advance
// unlike like MIDI note on/off envelopes
class ADEnv {

  private:
    float value;        // current value as it runs
    int sampleIndex;  // sampleIndex in this fire
    float dur;

  public:
    float attackTime;
    int   attackSamples;
    float attackIncr;
    float decayTime;
    int   decaySamples;
    int   decayStartSample;
    float decayDecr;

    void init(float attackSeconds, float decaySeconds){
      value = 0.0;
      dur = 0.0;
      sampleIndex = 0;
      attackTime = attackSeconds;
      decayTime = decaySeconds;
    }

    // restart the envelope with a new total duration
    // note, this does not do take-over (yet)
    void trigger(float duration){
      // recalculate the trajectory based on current vals
      dur = duration;
      value = 0.0;
      sampleIndex = 0;
      attackSamples = attackTime * SAMPLE_RATE;
      attackIncr = 1.0 / attackSamples;
      decaySamples = decayTime * SAMPLE_RATE;
      decayStartSample = (dur * SAMPLE_RATE) - decaySamples;
      decayDecr = 1.0 / decaySamples;
    }

    float renderSample(){
      if(sampleIndex < attackSamples){
        value += attackIncr;
      }else if(sampleIndex > decayStartSample){
        value -= decayDecr;
      }
      // clamp at 1 or 0
      if( value > 1.0) value = 1.0;
      if( value < 0.0) value = 0.0;
      sampleIndex += 1;
      return value;
    }
};


// a voice of a synth
// has some number of oscillators and an amp env
class Voice {
  public:
    static const int numOscillators = 3;
    const int startFreq = 110;
    WaveTableOsc oscillators[numOscillators];
    ADEnv ampEnv;
    float levels[numOscillators];
    float _gain;

    void init(float gain, float sineLevel, float sawLevel, float triLevel, float squareLevel, float pulseLevel){
      for(int i=0; i < numOscillators; i++){
        // add some chorus be detuning the oscillators
        float frq = startFreq + (i * 0.001 * startFreq);
        oscillators[i].init(frq, sineLevel, sawLevel, triLevel, squareLevel, pulseLevel);
        // start with osc levels as 1.0 / numOscillators
        levels[i] = 1.0 / numOscillators;
      }
      // init the amp env with an attack and decay time
      ampEnv.init(0.01, 0.1);
      _gain = gain;
    }

    void setFreq(float note){
      for(int i=0; i < numOscillators; i++){
        // conver midi note to hz
        float freq = (440.0 / 32) * pow(2, ((note - 9) / 12.0));
        oscillators[i].setFreq(freq);
      }
    }

    void playNote(float dur, float amp, float noteNum){
      // set the osc frq and trigger the env
      setFreq(noteNum);
      ampEnv.trigger(dur);
    }

    float renderSample(){
      float outSample = 0.0;
      float envLevel = ampEnv.renderSample();
      for(int i=0; i < numOscillators; i++){
        outSample += oscillators[i].renderSample() * levels[i];
      }
      return outSample * _gain * envLevel;
    }
};

class Engine {
  public:
    const static int numVoices = 4;
    int sampleRate;
    int blockSize;
    int blockNumber;
    Voice voices[NUM_VOICES];
    float perVoiceGain;

    int init(int sampleRate, int blockSize){
      for(int i=0; i < numVoices; i++){
        // initial voice levels for gain, sine, saw, tri, square, pulse
        //voices[i].init(1.0, 0.0, 1.0, 0.0, 0.0, 0.0);
        voices[i].init(1.0, 0.0, 0.5, 0.0, 0.7, 0.0); // SQR
      }
      perVoiceGain = 1.0 / numVoices;
      return 1;
    }

    // for now, voice allocation is coming from outside the engine
    void playNote(int voice, float dur, float amp, float noteNum){
      voices[voice].playNote(dur, amp, noteNum);
    }

    // render an entire block of samples, writing to the global output buffer
    // that is shared memory with the JavaScript side
    int renderAudioBlock(){
      for(int i=0; i < AUDIO_BLOCK_SIZE; i++){
        g_out_buf[i] = 0.0;
        for(int j=0; j < AUDIO_BLOCK_SIZE; j++){
          g_out_buf[i] += voices[j].renderSample() * perVoiceGain;
        }
      }
      blockNumber += 1;
      return 1;
    }
};

// generate a noise sample, keeping here to use later
float genNoise(){
    float randomSample = (static_cast <float> (rand()) / static_cast <float> (RAND_MAX / 2) ) - 1.0;
    return randomSample;
}

////////////////////////////////////////////////////////////////////////////////
// FFI functions, exported and called from JS
// easiest FFI is simple functions that take and receive ints or floats only

// not sure why, but doing the below with pointers does not work in WASM standalone
// we get a browser error msg:
//   "TypeError: import object field 'wasi_snapshot_preview1' is not an Object"
// compiles fine, but won't run

// Engine * engine = new Engine();

// so instead, the engine (and its children) are just variables, and
// we will use explicit init methods instead of constructors
Engine engine;

struct SchedulerEvent {
  int active;
  float time;
  float params[4];
};

class Scheduler {
  // Max number of events that can be on the scheduler
  static const int SIZE = 1024;
  // number of float data points per event
  static const int PARAMS = 4;

  private:
    SchedulerEvent data[SIZE];
    int numScheduled = 0;
    float timeNow;

  public:

    // add an event to the scheduler
    // looks for first empty row and uses it
    int add(float time, float p1, float p2, float p3, float p4){
      for(int i = 0; i < SIZE; i++){
        if( data[i].active )
          continue;
        else {
          data[i].active = 1;
          data[i].time = timeNow + time;
          data[i].params[0] = p1;
          data[i].params[1] = p2;
          data[i].params[2] = p3;
          data[i].params[3] = p4;
          numScheduled += 1;
          break;
        }
      }
      return 1;
    }

    void seek(float time){
      timeNow = time;
    }

    void processBlock(){
      // so we don't go through the whole data store unnecessarily
      int eventsSeen = 0;
      int eventsToSee = numScheduled;

      for(int i = 0; i < SIZE; i++){
        if( data[i].active && data[i].time > timeNow ){
          eventsSeen += 1;
        }
        if( data[i].active  && data[i].time <= timeNow ){
          engine.playNote( (int) data[i].params[0], data[i].params[1], data[i].params[2], data[i].params[3] );
          data[i].active = 0;
          numScheduled -= 1;
          eventsSeen += 1;
        }
        // once we have seen all the events that were scheduled when we entered this function
        // we can stop looking for events in the store
        if( eventsSeen == eventsToSee)
          break;
      }
      timeNow += (1.0 / SAMPLE_RATE) * AUDIO_BLOCK_SIZE;
    }
};
Scheduler scheduler;

// FFI function to setup our audio engine
// this is called from JS
int initEngine(){
    engine.init(SAMPLE_RATE, AUDIO_BLOCK_SIZE);
    return 1;
}

// FFI function called on incoming events once per block
// JS side will fill the buffer and this will empty it
// FUTURE: make this use a ring buffer and accept/send number of events
// each event is 8 floats in the buf
int processEvents(int numEvents){
    for(int i = 0; i < numEvents * 8; i += 8){
      int voice   = (int) evt_buf[i];
      float time  = evt_buf[i + 1];
      float dur   = evt_buf[i + 2];
      float amp   = evt_buf[i + 3];
      float freq  = evt_buf[i + 4];
      if(time <= 0){
        engine.playNote(voice, dur, amp, freq);
      }else{
        scheduler.add(time, voice, dur, amp, freq);
      }
    }
    return 1;
}

// patch manager, takes param messages from JS, maps to synth settings
void updateParam(int param, int number, int value){
    float normValue;
    normValue = value / 128.0;
    switch( param ){
      case WAVELEVEL:
        for(int v = 0; v < engine.numVoices; v++){
          for(int o = 0; o < engine.voices[0].numOscillators; o++){
            engine.voices[v].oscillators[o].setWaveLevel(number, normValue);
          }
        }
        break;
    }
}

// FFI function that JS calls once per block to render a block of audio
int processAudio(){
    if( engine.blockNumber == 0){
      // anything that should play automatically on start goes here
      // seek scheduler to 0
      scheduler.seek(0);
    }
    scheduler.processBlock();
    engine.renderAudioBlock();
    return 1;
}

#ifdef __cplusplus
}
#endif