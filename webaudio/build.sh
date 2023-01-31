echo "building wasm file"
source /Users/iainduncan/Documents/code/emsdk/emsdk_env.sh
rm *.wasm

emcc audio_process.cpp -O2 -s WASM=1 --no-entry \
  -s EXPORTED_FUNCTIONS=['_free','_malloc','_getOutBuf','_getEvtBuf','_initEngine','_processEvents','_processAudio'] \
  -o audio_process.wasm

