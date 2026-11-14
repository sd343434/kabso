# Consumer rules (kabso_camera_fx, D144). DeepAR's native renderer calls back into
# Java over JNI, which R8 cannot see; without these, minified (release) builds
# abort with NoSuchMethodError on DeepAR's thread. The whole package on
# purpose: the JNI surface is undocumented.
-keep class ai.deepar.ar.** { *; }
-dontwarn ai.deepar.ar.**

# D228 (free engine): MediaPipe Tasks' native graph calls back into Java over
# JNI (com.google.mediapipe.framework.*) and parses its protobuf-lite options
# by reflection; its AARs ship no consumer rules. ML Kit ships its own.
# Removing the free engine removes this block too.
-keep class com.google.mediapipe.** { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.ai.edge.litertlm.**
-dontwarn com.google.auto.value.**
