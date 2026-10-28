# Consumer rules (kabso_camera_fx, D144). DeepAR's native renderer calls back into
# Java over JNI, which R8 cannot see; without these, minified (release) builds
# abort with NoSuchMethodError on DeepAR's thread. The whole package on
# purpose: the JNI surface is undocumented.
-keep class ai.deepar.ar.** { *; }
-dontwarn ai.deepar.ar.**
