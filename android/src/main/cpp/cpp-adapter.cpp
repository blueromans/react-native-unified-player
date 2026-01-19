#include <jni.h>
#include "UnifiedPlayerOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::unifiedplayer::initialize(vm);
}
