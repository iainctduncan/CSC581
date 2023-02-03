// audio worklet processor
// this is a processor file that will get loaded into an AudioWorklet through its addModule method
// it is constructed when the worklet is instantiated, and its processor method runs to
// generate a block (128) of samples

const EVT_BUF_SIZE = 128;
const BLOCK_SIZE = 128;

class AudioProcessor extends AudioWorkletProcessor {
  constructor() {
    console.log("AudioProcessor.constructor()");
    super();
    this.initEvents();
    this.port.onmessage = (e) => this.handleMsg(e);
    this.sample = 0;
  }

  // setup up our input event store
  initEvents(){
    this._events = Array();
  }

  // call back for receiving messages from main thread
  handleMsg(e){
    //console.log("AudioProcessor.handleMsg()", e);
    switch( e.data.msg ) {
      case 'load_module':
        // load module msgs contain the wasm bytes, fetched in main thread
        // because we can't make network requests in an AudioWorklet
        this.initWasm(e.data.body);
        break;
      case 'note':
        this.noteMsg(e.data.body);
        break;
      default:
        console.log(" - unhandled msg: ", e.data.msg);
    }
  }

  // compile and instantiate the wasm module
  async initWasm(data){
    console.log("initWasm()");
    // setup linear memory for the WASM module, 'memory' for heap, 'table' for references
    const importObject = { 'env': {
        __memory_base: 0,
        __table_base: 0,
        memory: new WebAssembly.Memory({initial: 1}),
        table: new WebAssembly.Table({initial: 0, element: 'anyfunc'})
    }}
    this.module = await WebAssembly.compile(data.arrayBuffer);
    this.instance = await WebAssembly.instantiate(this.module, importObject);
    this.wa_buf = this.instance.exports.memory.buffer;
    //console.log("exports:", this.instance.exports);

    // set up the output sample buffer
    // this is a handle to the memory processAudio will write to
    this.audioOut = new Float32Array(this.wa_buf, this.instance.exports.getOutBuf(), BLOCK_SIZE);
    this.instance.exports.initEngine();
  }

  static get parameterDescriptors() {
    return [
        { name: "gain", defaultValue: 0.4, minValue: 0, maxValue: 1 },
    ];
  }

  // worklet message handler for incoming note messages
  noteMsg(noteData){
    console.log("AudioProcessor.noteMsg() data:", noteData);
    // get at the evt buf
    var buf = new Float32Array(this.wa_buf, this.instance.exports.getEvtBuf(), EVT_BUF_SIZE);
    // write an event, which consists of five floats, but we will use 8 points per line
    // voice, time, dur, amp, freq
    buf.set( [1, 0.0, 1.0, 1.0, 60], 0);
    buf.set( [2, 0.0, 1.0, 1.0, 64], 8);
    buf.set( [3, 0.0, 1.0, 1.0, 67], 16);
    // call C, tell it how many events there are
    buf.set( [1, 2.0, 1.0, 1.0, 60], 24);
    buf.set( [2, 2.0, 1.0, 1.0, 64], 32);
    buf.set( [3, 2.0, 1.0, 1.0, 67], 40);
    var res = this.instance.exports.processEvents(6);
    console.log("got", res);
  }

  // log helper for in the audio loop, logs every X samples
  log(msg){
      if(this.sample % 10000 == 0){
          console.log(this.sample, msg);
      }
  }

  // read/write samples for one block
  process(inputList, outputList, parameters) {
    // inputList and outputList arrays of input/outputs, each of which is in turn an array of `Float32Array`s,
    // each of which contains the audio data for one channel (left/right/etc)
    // parameters` is an object containing the AudioParam values for the current block of audio data. 
    // read the gain param for this block of samples, see parameterDescriptors above
    const gain = parameters.gain[0];
    // for number of inputs/outputs, we take the lower of either
    const numSources = Math.min(inputList.length, outputList.length);

    // input/output loop
    for (let inputNum = 0; inputNum < numSources; inputNum++) {
      let input = inputList[inputNum];
      let output = outputList[inputNum];
      let numChannels = Math.min(input.length, output.length);

      // channel loop
      for (let channel = 0; channel < numChannels; channel++) {
        // call C++ to process audio, side effect of populating this.audioOut
        // because we can't easily pass in a pointer to a block in a WASM worklet
        this.instance.exports.processAudio();
        for(var i=0; i < BLOCK_SIZE; i++){
          output[channel][i] = this.audioOut[i] * gain * 0.5;
        }
      }
    }
    // keep a running count of samples for debugging purposes
    this.sample += BLOCK_SIZE;
    // need to return true to indicate processor is active and ready
    return true;
  }
};

// when AudioWorklet invokes this processor, this will register the processor
// on the audio worklet
registerProcessor("audio-processor", AudioProcessor);
