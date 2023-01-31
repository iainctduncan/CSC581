console.log("audio_host.js loading");

let ctx;
let oscNode;
let processorNode;

// create our AudioWorklet webaudio node that will contain
// low level audio processing in JS and WASM
async function createAudioProcessor() {
  console.log("createAudioProcessor()");
  let processorNode;
  if (!ctx) {
    try {
      ctx = new AudioContext();
      // create the audio worklet, which will load processor.js
      await ctx.audioWorklet.addModule("processor.js");
      processorNode = new AudioWorkletNode(ctx, "audio-processor");

      // Fetch the Wasm module we want to use in the processor
      // and send its binary data to the worklet as a message
      // because worklets can't run fetch
      //const res = await fetch('./multiply.wasm');
      const res = await fetch('./audio_process.wasm');
      const moduleBytes = await res.arrayBuffer();
      processorNode.port.postMessage({
        msg: 'load_module',
        body: {arrayBuffer: moduleBytes}
      })
    } catch (e) {
      console.log("exception in createAudioProcessor()", e);
      return null;
    }
  }
  // don't return until all this initialization has settled down
  await ctx.resume();
  // return the ready WebAudio node
  return processorNode;
}

// function to kick off entire page, can't do it on autoload
// because browsers now disable auto play of sound, so we need a user triggered event
async function start(){
  if( ! ctx ){
    console.log("start() - boostrapping audio system");
  }else{
    return console.log(" ** already started, returning harmlessly");
  }
  // make our worklet node, need to use await because it loads
  // its processor code asynchronously
  // (this will hang if the network request fails, so not production appropriate)
  processorNode = await createAudioProcessor();
  if (!processorNode){
    return console.log("** Error: unable to create audio processor");
  }  
  processorNode.port.onmessage = function(e){
    console.log("msg received in main thread:", e.data);
  }

  oscNode = new OscillatorNode(ctx, {frequency: 220, type: "sine"});
  oscNode.connect(processorNode).connect(ctx.destination);
  // to bypass processor for testing
  //oscNode.connect(ctx.destination);
}

function play(){
  console.log("play");
  oscNode.start();
}

function note(){
  console.log("host.note()");
  // play two notes to simulate having two to handle in one blocl
  processorNode.port.postMessage({'msg': 'note',
    'body': {time: 0.0, dur: 1.0, amp: 0.9, pitch: 220}
  })
  //processorNode.port.postMessage({'msg': 'note',
  //  'body': {time: 0.0, dur: 1.0, amp: 0.9, pitch: 440}
  //})
}

function stop(){
  console.log("stop");
  oscNode.stop();
}

function setGain(gain){
  let gainParam = processorNode.parameters.get("gain");
  gainParam.setValueAtTime(gain, 0);
}

