console.log("audio_host.js loading");

let ctx;
let oscNode;
let node;

// create our AudioWorklet webaudio node that will contain
// low level audio processing in JS and WASM
async function createAudioProcessor() {
  console.log("createAudioProcessor()");
  let node;
  if (!ctx) {
    try {
      ctx = new AudioContext();
      // create the audio worklet, which will load processor.js
      await ctx.audioWorklet.addModule("processor.js");
      node = new AudioWorkletNode(ctx, "audio-processor");

      // Fetch the Wasm module we want to use in the processor
      // and send its binary data to the worklet as a message
      // because worklets can't run fetch
      //const res = await fetch('./multiply.wasm');
      const res = await fetch('./audio_process.wasm');
      const moduleBytes = await res.arrayBuffer();
      node.port.postMessage({
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
  return node;
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
  node = await createAudioProcessor();
  if (!node){
    return console.log("** Error: unable to create audio processor");
  }  
  node.port.onmessage = function(e){
    console.log("msg received in main thread:", e.data);
  }
  // can we get rid of this osc node somehow?
  oscNode = new OscillatorNode(ctx, {frequency: 220, type: "sine"});
  oscNode.connect(node).connect(ctx.destination);
  oscNode.start();
}

function note(){
  console.log("host.note()");
  node.port.postMessage({'msg': 'note', 'body': {voice: 1, time: 0.0, dur: 1.0, amp: 0.9, pitch: 60} })
}

function chord(){
  console.log("host.chord()");
  node.port.postMessage({'msg': 'note', 'body': {voice: 1, time: 0.0, dur: 1.0, amp: 0.9, pitch: 60} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 2, time: 0.0, dur: 1.0, amp: 0.9, pitch: 64} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 3, time: 0.0, dur: 1.0, amp: 0.9, pitch: 67} })
}

function chordProg(){
  console.log("host.chordProg()");
  // play two notes to simulate having two to handle in one blocl
  node.port.postMessage({'msg': 'note', 'body': {voice: 1, time: 0.0, dur: 1.0, amp: 0.9, pitch: 65} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 2, time: 0.0, dur: 1.0, amp: 0.9, pitch: 69} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 3, time: 0.0, dur: 1.0, amp: 0.9, pitch: 72} })

  node.port.postMessage({'msg': 'note', 'body': {voice: 1, time: 1.0, dur: 1.0, amp: 0.9, pitch: 67} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 2, time: 1.0, dur: 1.0, amp: 0.9, pitch: 71} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 3, time: 1.0, dur: 1.0, amp: 0.9, pitch: 74} })

  node.port.postMessage({'msg': 'note', 'body': {voice: 1, time: 2.0, dur: 1.0, amp: 0.9, pitch: 60} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 2, time: 2.0, dur: 1.0, amp: 0.9, pitch: 64} })
  node.port.postMessage({'msg': 'note', 'body': {voice: 3, time: 2.0, dur: 1.0, amp: 0.9, pitch: 67} })

}

function updateSlider(oscNum, level){
  //console.log("updateSlider", oscNum, level);
  node.port.postMessage({'msg': 'param', 'body': {param: 0, wave: oscNum, value: level}})
}

function stop(){
  console.log("stop");
  oscNode.stop();
}

function setGain(gain){
  let gainParam = node.parameters.get("gain");
  gainParam.setValueAtTime(gain, 0);
}

