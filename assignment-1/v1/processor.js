// audio worklet processor
// this is a processor file that will get loaded into an AudioWorklet through its addModule method

// a processor that just changes volume of input
class GainProcessor extends AudioWorkletProcessor {
  constructor() {
    console.log("GainProcessor.constructor()");
    super();
    
    this.gainOffset = 0.5;

    // callback to receive messages from the main thread
    this.port.onmessage = (e) => {
      console.log("gainProcessor received msg: ", e.data);
      let offset = parseFloat(e.data);
      console.log("  - new offset:", offset);
      this.gainOffset = offset;
      this.port.postMessage("OK");
    };
  }

  static get parameterDescriptors() {
    return [
      {
        name: "gain",
        defaultValue: 0.1,
        minValue: 0,
        maxValue: 1,
      },
    ];
  }

  // read/write samples for one block
  process(inputList, outputList, parameters) {
    // inputList and outputList arrays of input/outputs, each of which is in turn an array of `Float32Array`s,
    // each of which contains the audio data for one channel (left/right/etc)
    // parameters` is an object containing the AudioParam values for the current block of audio data. 
  
    // read the gain param for this block of samples, see parameterDescriptors above
    const gain = parameters.gain[0];
    const gainOffset = this.gainOffset;
    //console.log("gain: ", gain, "gainOffset: ", gainOffset);

    // for number of inputs/outputs, we take the lower of either
    const numSources = Math.min(inputList.length, outputList.length);

    // input/output loo[
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
          sample = sample * gain * gainOffset;
          output[channel][i] = sample;
        }
      }  
    }
    // need to return true to indicate processor is active and ready
    return true;
  }

};

// when AudioWorklet invokes this processor, this will register the processor
// on the audio worklet
registerProcessor("gain-processor", GainProcessor);
