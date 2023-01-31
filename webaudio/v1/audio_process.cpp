#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <emscripten.h>

#ifdef __cplusplus
extern "C" {
#endif

const int SIZE = 10;
int data[SIZE];

// Maximum num of evt messages that come in on one block
const int EVT_BUF_SIZE = 128;
float evt_buf[EVT_BUF_SIZE];
EMSCRIPTEN_KEEPALIVE
float* getEvtBuf() { return &evt_buf[0]; }


EMSCRIPTEN_KEEPALIVE
void add(int value) {
  for (int i=0; i<SIZE; i++) {
    data[i] = data[i] + value;
  }
}

EMSCRIPTEN_KEEPALIVE
int* getData() {
  //return data;
  return &data[0];
}




EMSCRIPTEN_KEEPALIVE
float multiply(float arg1, float arg2){
    return arg1 * arg2;
}

//EMSCRIPTEN_KEEPALIVE
uint8_t getEvents(int* buf, int offset){
    //uint8_t sum = buf[0] + buf[1];
    //return buf[offset];
    buf[1] = 666;
    return (uint8_t) *(buf + offset);

    //return 42;
}

// from the tutorial: https://marcoselvatici.github.io/WASM_tutorial/#memory
// add one to the value in the input ptr and write this to the content of the output ptr
// but... I don't know how to use this without Module.setValue
void addOne(int* input_ptr, int* output_ptr){
	*output_ptr = (*input_ptr) + 1;
}

#ifdef __cplusplus
}
#endif