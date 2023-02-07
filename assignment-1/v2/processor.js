// audio worklet processor
// this is a processor file that will get loaded into an AudioWorklet through its addModule method
// it is constructed when the worklet is instantiated, and its processor method runs to
// generate a block (128) of samples

// convenience container for exported C functions compiled with WASM
var wa = {};

const blockSize = 128;

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
    console.log("exports:", this.instance.exports);
  }

  static get parameterDescriptors() {
    return [
      {
        name: "gain",
        defaultValue: 0.4,
        minValue: 0,
        maxValue: 1,
      },
    ];
  }

  noteMsg(noteData){
    console.log("AudioProcessor.noteMsg() data:", noteData);
    //this._events.push(noteData);

    // obtain the offset to the array
    var offset = this.instance.exports.getData();
    // create a view on the memory that points to this array, from offset for 10 points
    var linearMemory = new Uint32Array(this.wa_buf, offset, 10);
    // populate with some data
    for (var i = 0; i < linearMemory.length; i++) {
      linearMemory[i] = i;
    }
    // note that logging from the shared memory during processing makes glitches
    console.log("calling C add function")
    // mutate the array within the WebAssembly module
    this.instance.exports.add(10);
    console.log("now memory is:", linearMemory);
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

    // process input events, filling some data structure that the C code can get at
    if(this._events.length){
      let evt = this._events.pop();
      this.log("in process, got evt:", evt);

    }

    // input/output loop
    for (let inputNum = 0; inputNum < numSources; inputNum++) {
      let input = inputList[inputNum];
      let output = outputList[inputNum];
      let numChannels = Math.min(input.length, output.length);

      // channel loop
      for (let channel = 0; channel < numChannels; channel++) {
        let blockSize = input[channel].length;

        // process sample loop
        for (let i = 0; i < blockSize; i++) {
          let sample = input[channel][i];
          // calculate audio and write it back to the output buffer
          //sample = sample * gain;
          //sample = wa.multiply(sample, gain);
          output[channel][i] = sample;
        }
      }  
    }

    this.sample += blockSize;
    // need to return true to indicate processor is active and ready
    return true;
  }

};

// when AudioWorklet invokes this processor, this will register the processor
// on the audio worklet
registerProcessor("audio-processor", AudioProcessor);
