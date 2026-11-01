# Third-party notices — kabso_camera_fx (D144)

## DeepAR SDK (`ai.deepar.ar:DeepAR:5.6.22`)

Proprietary SDK by DeepAR, used under DeepAR's terms of service and the plan bought for the
licence key (see `docs/DEPLOYMENT.md` §9.1). It is downloaded at build time from DeepAR's
Maven repository; none of its files are in this repository. Phase 1 uses only the SDK's
built-in background blur, so no DeepAR effect files are redistributed.

## D228 — the free effects engine (FreeFxStage.kt, FreeFxGl.kt, FreeFxRules.kt)

Added beside DeepAR so the owner can compare the two; removable on its own (docs/KNOWN_LIMITATIONS.md, D228). Both
dependencies come from Google's Maven repository at build time; none of their files are in this repository. No API
key, no account.

| Dependency | Version | Licence | What ships in the APK |
|---|---|---|---|
| `com.google.mlkit:segmentation-selfie` | 16.0.0-beta6 | Google ML Kit Terms of Service (proprietary, free of charge; <https://developers.google.com/ml-kit/terms>); its open-source parts are listed in the AAR's `third_party_licenses` | the 256 × 256 selfie model (`selfiesegmentation_mlkit-256x256-2021_01_19-v1215.f16.tflite`, 249 KB asset) and, through `com.google.mlkit:mediapipe-internal:17.0.0-beta10`, `libxeno_native.so` (arm64-v8a 21.6 MB, armeabi-v7a 16.0 MB, x86 19.9 MB, x86_64 19.9 MB uncompressed) |
| `com.google.mediapipe:tasks-vision` (+ `tasks-core`) | 1.1.1 | Apache-2.0 (the POM; the AAR's `META-INF/NOTICE` lists its bundled open-source parts) | `libmediapipe_tasks_jni.so` (arm64-v8a 14.4 MB, armeabi-v7a 10.1 MB, x86 20.7 MB, x86_64 17.8 MB uncompressed) |

**The face model is not bundled.** `face_landmarker.task` (MediaPipe Face Landmarker, float16, version 1; 3 758 596
bytes; SHA-256 `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`) is downloaded once, the first time
a host turns beauty on, from Google's public model storage
(`https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task`)
into the app's private files, and used only if its SHA-256 matches. MediaPipe publishes its Face Landmarker models
under Apache-2.0 (MediaPipe's model page and model card); this was not re-verified from inside this environment —
the owner/legal should confirm before release. `FreeFxGl.kt`'s shaders are our own.

**What leaves the device.** The camera picture never does: segmentation, landmarks and every effect run on the phone
(MediaPipe's own notice in the AAR: "processing of the input data … takes place on device, and MediaPipe does not
send that input data to Google servers"). However, **both SDKs send Google usage and performance metrics** through
Google's `datatransport` (MediaPipe Tasks: `RemoteLoggingClient`, log source `COREML_ON_DEVICE_SOLUTIONS`; ML Kit
likewise depends on `transport-backend-cct`). MediaPipe's notice: "You are responsible for obtaining informed consent
from your app users about Google's processing of MediaPipe metrics data as required by applicable law." Not
disabled. The owner approved disclosing it (2026-11-01): the privacy policy text says so (`infra/deploy/site/privacy.html`
§2 and §5); the Play Data safety answers are PRE_PRODUCTION_CHECKLIST PP-39. The face model download is a plain GET of a public file (no identifiers sent by us).

## WebRTC (`io.github.webrtc-sdk:android`, via flutter_webrtc)

Not bundled by this plugin (compile-only; flutter_webrtc ships it). `ColorMatrixDrawer` in
`ColorStage.kt` follows the vertex/texture-matrix conventions and the I420 → RGB coefficients
of WebRTC's `GlGenericDrawer`, which is distributed under the BSD 3-Clause licence:
Copyright (c) 2011, The WebRTC project authors. All rights reserved. Full text:
https://webrtc.googlesource.com/src/+/refs/heads/main/LICENSE

## voxa_deepar 0.1.4

`DeepArStage.kt` is adapted from voxa_deepar's `DeepArBridgeFilter` (NV21 into DeepAR,
DeepAR rendering into a WebRTC `SurfaceTextureHelper` surface, a bounded wait, raw frames
passed on timeout). The MIT licence below applies to the parts derived from it.

```
MIT License

Copyright (c) 2026 Zaman Sheikh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
