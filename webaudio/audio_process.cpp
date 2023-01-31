#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <emscripten.h>

#ifdef __cplusplus
extern "C" {
#endif

const int EVT_BUF_SIZE = 128;
const int AUDIO_BLOCK_SIZE = 128;
const int SAMPLE_RATE = 44100;
const int OSC_TABLE_SIZE = 1024;
const int NUM_VOICES = 4;
enum shape { SINE, SAW, SQUARE, NOISE};

// static buffer for handling incoming event messages
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
class WaveTableOsc {
  static const int waveforms = 4;
  public:
    int sr;
    // a phasor value that runs from 0 to 1
    float freq;
    float phasor;
    float wavetables[waveforms][OSC_TABLE_SIZE];
    // levels of sine, saw, square, noise
    float levels[waveforms];

    void init(float start_freq, float sine_lvl, float saw_lvl, float square_lvl){
        freq = start_freq;
        levels[SINE] = sine_lvl;
        levels[SAW] = saw_lvl;
        levels[SQUARE] = square_lvl;
        initSine();
        initSaw();
        initSquare();
    }

    void reset(){ phasor = 0.0; }

    // freq setter so we can do glide later
    void setFreq(float frq){ freq = frq; }

    void initSine(){
      // TODO formula for sine here yo
    }
    void initSaw(){
      for(int i=0; i < OSC_TABLE_SIZE; i++)
        wavetables[SAW][i] = (1.0 / OSC_TABLE_SIZE) * i;
    }
    void initSquare(){
      for(int i=0; i < OSC_TABLE_SIZE; i++)
        wavetables[SQUARE][i] = i < OSC_TABLE_SIZE / 2 ? -1 : 1;
    }

    float renderSample(){
      // update the internal phasor and use it to look up table
      phasor = phasor + (freq / SAMPLE_RATE);
      if(phasor >= 1.0)
        phasor -= 1.0;
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
  static const int NUM_OSC = 3;
  const int startFreq = 110;
  public:
    WaveTableOsc oscillators[NUM_OSC];
    ADEnv ampEnv;
    float levels[NUM_OSC];
    float _gain;

    void init(float gain, float sineLevel, float sawLevel, float squareLevel){
      for(int i=0; i < NUM_OSC; i++){
        // add some chorus be detuning the oscillators
        float frq = startFreq + (i * 0.001 * startFreq);
        oscillators[i].init(frq, sineLevel, sawLevel, squareLevel);
        // start with osc levels as 1.0 / NUM_OSC
        levels[i] = 1.0 / NUM_OSC;
      }
      // init the amp env with an attack and decay time
      ampEnv.init(0.2, 0.5);
      _gain = gain;
    }

    void setFreq(float freq){
      for(int i=0; i < NUM_OSC; i++){
        oscillators[i].setFreq(freq);
      }
    }

    void playNote(float dur, float amp, float frq){
      // set the osc frq and trigger the env
      setFreq(frq);
      ampEnv.trigger(dur);
    }

    float renderSample(){
      float outSample = 0.0;
      float envLevel = ampEnv.renderSample();
      for(int i=0; i < NUM_OSC; i++){
        outSample += oscillators[i].renderSample() * levels[i];
      }
      return outSample * _gain * envLevel;
    }
};

class Engine {
  const static int NUM_VOICES = 1;

  public:
    int sampleRate;
    int blockSize;
    int numVoices;
    Voice voices[NUM_VOICES];
    float perVoiceGain;

    int blockNumber;

    int init(int sampleRate, int blockSize, int numVoices){
      for(int i=0; i < NUM_VOICES; i++){
        // initial voice levels for gain, sine, saw, square
        voices[i].init(1.0, 0.0, 1.0, 1.0);
      }
      perVoiceGain = 1.0 / NUM_VOICES;
      return 1;
    }

    // for now, just delegate to the first voice
    void playNote(float dur, float amp, float freq){
      voices[0].playNote(dur, amp, freq);
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

// generate a noise sample
float genNoise(){
    float randomSample = (static_cast <float> (rand()) / static_cast <float> (RAND_MAX / 2) ) - 1.0;
    return randomSample;
}

////////////////////////////////////////////////////////////////////////////////
// FFI functions, exported and called from JS
// easiest FFI is simple functions that take and receive ints or floats only

// haven't figured out how to have this thing instantiate pointers with
// new in WASM, so all references are static for now and use explicit
// init methods for setup
Engine engine;

// setup our audio engine
int initEngine(){
    // create an engine as a global var for now, with 4 voices
    //engine.init(SAMPLE_RATE, AUDIO_BLOCK_SIZE, NUM_VOICES);
    engine.init(SAMPLE_RATE, AUDIO_BLOCK_SIZE, NUM_VOICES);
    return 1;
}

// this will become the function that gets incoming events
// JS side will fill the buffer and this will empty it
// TODO: make this use a ring buffer and accept/send number of events
int processEvents(){
    int i = 0;
    while( evt_buf[i] != 0){
      float time = evt_buf[i + 1];
      float dur  = evt_buf[i + 2];
      float amp  = evt_buf[i + 3];
      float freq = evt_buf[i + 4];
      engine.playNote(dur, amp, freq);
      // set flag bit to indicate evt processed
      evt_buf[i] = 0;
      i += 5;
    }

    return 1;
}

int processAudio(){
    if( engine.blockNumber == 0){
      // anything that should play automatically goes here
    }
    engine.renderAudioBlock();
    return 1;
}





#ifdef __cplusplus
}
#endif