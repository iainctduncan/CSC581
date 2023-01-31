echo "building wasm file"
source /Users/iainduncan/Documents/code/emsdk/emsdk_env.sh
rm *.wasm

# the below compile, but I get no malloc
# but it does compile. Note that WASM=1 and -O2 are necessarty (-O0 or O1 produce link errors)
#emcc multiply.c -O2 -s WASM=1 -s SIDE_MODULE=2 -s EXPORTED_FUNCTIONS=['_multiply'] -o multiply.wasm
# emcc multiply.c -O2 -s WASM=1 -s SIDE_MODULE=2 -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -o multiply.wasm

# attempt with the get_offset technique
#emcc multiply.c -O2 -s WASM=1 -s SIDE_MODULE=2 -s EXPORTED_FUNCTIONS=['_get_offset','_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o multiply.wasm

# this is successfully exporting malloc!
#emcc multiply.c -O2 -s WASM=1 --no-entry -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o multiply.wasm
emcc audio_process.cpp -O2 -s WASM=1 --no-entry -s EXPORTED_FUNCTIONS=['_free','_malloc','_multiply','_addOne','_getEvents'] \
-s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString','getValue','setValue'] -o audio_process.wasm

#emcc audio_process.cpp -O2 --no-entry -s WASM=1 -s MAIN_MODULE=2 -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o audio_process.wasm


# problem is that side modules do not include standard library
# trying this out, it compiles something big, but gives me an error: TypeError: import object field 'wasi_snapshot_preview1' is not an Object
# console message says you need to use MAIN_MODULE=2 with exported functions
# using --no-entry allows building a MAIN_MODULE without a main entry point
#emcc multiply.c -O2 --no-entry -s WASM=1 -s MAIN_MODULE=2 -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o multiply.wasm


# this doesn't work, I get no malloc
#emcc multiply.c -s SIDE_MODULE=2 -O1 -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -o multiply.wasm

# trying to figure out incantation to be able to call malloc
# this one does not work, I don't get malloc in the exports, maybe because of side module??
#emcc multiply.c -O1 -s SIDE_MODULE=2 -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o multiply.wasm

# this one gives me: TypeError: import object field 'wasi_snapshot_preview1' is not an Object
#emcc multiply.c -O0 -s WASM=2 -s EXPORTED_FUNCTIONS=['_malloc','_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o multiply.wasm
#emcc multiply.c -O1 -s SIDE_MODULE=2 -s EXPORTED_FUNCTIONS=['_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o multiply.wasm
#emcc multiply.c -O1 -s SIDE_MODULE=2 -s EXPORTED_FUNCTIONS=['_multiply']  -o multiply.wasm



#emcc audio_process.cpp -s SIDE_MODULE=2 -O1 -o audio_process.wasm -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString']

#emcc audio_process.cpp -s SIDE_MODULE=2 -O1 -s EXPORTED_FUNCTIONS=['_multiply'] -s EXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString'] -o audio_process.wasm

