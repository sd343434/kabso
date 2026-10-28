# Third-party notices — kabso_camera_fx (D144)

## DeepAR SDK (`ai.deepar.ar:DeepAR:5.6.22`)

Proprietary SDK by DeepAR, used under DeepAR's terms of service and the plan bought for the
licence key (see `docs/DEPLOYMENT.md` §9.1). It is downloaded at build time from DeepAR's
Maven repository; none of its files are in this repository. Phase 1 uses only the SDK's
built-in background blur, so no DeepAR effect files are redistributed.

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
