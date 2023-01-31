console.log("audio_host.js loading");

let ctx;
let oscNode;
let gainNode;

async function createGainProcessor() {
  console.log("createGainProcessor()");
  let processorNode;
  if (!ctx) {
    try {
      ctx = new AudioContext();
      await ctx.audioWorklet.addModule("processor.js");
      processorNode = new AudioWorkletNode(ctx, "gain-processor");
    } catch (e) {
      console.log("exception in createGainProcessor()", e);
      return null;
    }
  }
  await ctx.resume();
  return processorNode;
}


async function start(){
  if( ! ctx ){
    console.log("start() - boostrapping audio system");
  }else{
    return console.log(" ** already started, returning");
  }
  // make our worklet node, need to use await because it loads
  // its processor code asynchronously
  gainNode = await createGainProcessor();
  if (!gainNode){
    return console.log("** Error: unable to create gain processor");
  }  
  gainNode.port.onmessage = function(e){
    console.log("msg received in main thread:", e.data);
  }

  oscNode = new OscillatorNode(ctx, {frequency: 220, type: "sine"});
  oscNode.connect(gainNode).connect(ctx.destination); 
  oscNode.onended = oscEnded;
}

function play(){
  console.log("play");
  oscNode.start();
}

function stop(){
  console.log("stop");
  oscNode.stop();
}

function setGain(gain){
  let gainParam = gainNode.parameters.get("gain"); 
  gainParam.setValueAtTime(gain, 0);
}

// send a message to the gainNode's worklet thread
function sendMsg(msg){
  gainNode.port.postMessage(msg);
}

function oscEnded(){
  console.log("oscEnded handler");
}
