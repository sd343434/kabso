# kabso_streamer (D262 / D346): the plugin reads and writes these flutter_webrtc
# members by name (StreamerRules.PROJECTION_PATH / CONSENT_PATH). flutter_webrtc's
# own consumer rules keep all of com.cloudwebrtc.webrtc.** today; these lines keep
# the names even if a later flutter_webrtc narrows its rules (R8 in release builds).
-keepclassmembers class com.cloudwebrtc.webrtc.FlutterWebRTCPlugin { *** methodCallHandler; }
-keepclassmembers class com.cloudwebrtc.webrtc.MethodCallHandlerImpl { *** getUserMediaImpl; }
-keepclassmembers class com.cloudwebrtc.webrtc.GetUserMediaImpl {
    *** mediaProjectionData;
    *** mVideoCapturers;
}
-keepclassmembers class com.cloudwebrtc.webrtc.video.VideoCapturerInfo { *** capturer; }
-keepclassmembers class com.cloudwebrtc.webrtc.OrientationAwareScreenCapturer { *** mediaProjection; }
