import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dart_webrtc/dart_webrtc.dart' as dw;
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

/// The web pipeline: camera → `<video>` → WebGL (edge-preserving smoothing,
/// brightening) → `<canvas>` → `captureStream` → the published track.
BeautyPipeline? createBeautyPipeline() => _WebBeautyPipeline();

class _WebBeautyPipeline implements BeautyPipeline {
  _BeautyProcessor? _processor;
  rtc.RTCVideoRenderer? _renderer;
  LiveBeauty _beauty = const LiveBeauty();

  @override
  Future<void> attach(lk.LocalVideoTrack track) async {
    final processor = _BeautyProcessor(_beauty);
    await track.setProcessor(processor);
    _processor = processor;
    final out = processor.outputStream;
    if (out != null) {
      final renderer = rtc.RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = dw.MediaStreamWeb(out, 'local');
      _renderer = renderer;
    }
  }

  @override
  void update(LiveBeauty beauty) {
    _beauty = beauty;
    _processor?.beauty = beauty;
  }

  @override
  Widget? preview({required bool mirror}) {
    final renderer = _renderer;
    if (renderer == null) return null;
    return rtc.RTCVideoView(
      renderer,
      mirror: mirror,
      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  @override
  Future<void> dispose() async {
    final renderer = _renderer;
    _renderer = null;
    renderer?.srcObject = null;
    await renderer?.dispose();
    await _processor?.destroy();
    _processor = null;
  }
}

class _BeautyProcessor implements lk.TrackProcessor<lk.VideoProcessorOptions> {
  new(this.beauty);

  LiveBeauty beauty;

  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  web.WebGLRenderingContext? _gl;
  web.WebGLUniformLocation? _uSmooth;
  web.WebGLUniformLocation? _uBright;
  web.WebGLUniformLocation? _uTexel;
  web.WebGLUniformLocation? _uMatrix;
  web.WebGLUniformLocation? _uOffset;
  web.MediaStream? outputStream;
  rtc.MediaStreamTrack? _processed;
  bool _running = false;

  @override
  String get name => 'kabso-beauty';

  @override
  rtc.MediaStreamTrack? get processedTrack => _processed;

  @override
  Future<void> init(lk.VideoProcessorOptions options) async {
    final input = (options.track as dw.MediaStreamTrackWeb).jsTrack;
    final settings = input.getSettings();
    final width = settings.width;
    final height = settings.height;

    final video = web.document.createElement('video') as web.HTMLVideoElement
      ..muted = true
      ..autoplay = true
      ..playsInline = true
      ..srcObject = web.MediaStream([input].toJS);
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = width
      ..height = height;
    final gl = canvas.getContext('webgl') as web.WebGLRenderingContext?;
    if (gl == null) return; // No WebGL: publish the camera as it is.
    _setUp(gl);
    _uTexel = gl.getUniformLocation(_program, 'u_texel');
    gl.uniform2f(_uTexel, 1 / width, 1 / height);

    await video.play().toDart;
    _video = video;
    _canvas = canvas;
    _gl = gl;
    final stream = canvas.captureStream(30);
    outputStream = stream;
    _processed = dw.MediaStreamTrackWeb(stream.getVideoTracks().toDart.first);
    _running = true;
    _scheduleFrame();
  }

  late web.WebGLProgram _program;

  void _setUp(web.WebGLRenderingContext gl) {
    web.WebGLShader compile(int type, String source) {
      final shader = gl.createShader(type)!;
      gl
        ..shaderSource(shader, source)
        ..compileShader(shader);
      return shader;
    }

    final program = gl.createProgram()!;
    gl
      ..attachShader(
        program,
        compile(web.WebGLRenderingContext.VERTEX_SHADER, _vertex),
      )
      ..attachShader(
        program,
        compile(web.WebGLRenderingContext.FRAGMENT_SHADER, _fragment),
      )
      ..linkProgram(program)
      ..useProgram(program);
    _program = program;

    final quad = gl.createBuffer();
    gl
      ..bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, quad)
      ..bufferData(
        web.WebGLRenderingContext.ARRAY_BUFFER,
        Float32List.fromList(const [-1, -1, 1, -1, -1, 1, 1, 1]).toJS,
        web.WebGLRenderingContext.STATIC_DRAW,
      );
    final position = gl.getAttribLocation(program, 'a_position');
    gl
      ..enableVertexAttribArray(position)
      ..vertexAttribPointer(
        position,
        2,
        web.WebGLRenderingContext.FLOAT,
        false,
        0,
        0,
      );

    final texture = gl.createTexture();
    gl
      ..bindTexture(web.WebGLRenderingContext.TEXTURE_2D, texture)
      ..texParameteri(
        web.WebGLRenderingContext.TEXTURE_2D,
        web.WebGLRenderingContext.TEXTURE_WRAP_S,
        web.WebGLRenderingContext.CLAMP_TO_EDGE,
      )
      ..texParameteri(
        web.WebGLRenderingContext.TEXTURE_2D,
        web.WebGLRenderingContext.TEXTURE_WRAP_T,
        web.WebGLRenderingContext.CLAMP_TO_EDGE,
      )
      ..texParameteri(
        web.WebGLRenderingContext.TEXTURE_2D,
        web.WebGLRenderingContext.TEXTURE_MIN_FILTER,
        web.WebGLRenderingContext.LINEAR,
      )
      ..pixelStorei(web.WebGLRenderingContext.UNPACK_FLIP_Y_WEBGL, 1);
    _uSmooth = gl.getUniformLocation(program, 'u_smooth');
    _uBright = gl.getUniformLocation(program, 'u_bright');
    _uMatrix = gl.getUniformLocation(program, 'u_cm');
    _uOffset = gl.getUniformLocation(program, 'u_co');
  }

  void _scheduleFrame() {
    if (!_running) return;
    web.window.requestAnimationFrame(((num _) => _draw()).toJS);
  }

  void _draw() {
    final gl = _gl;
    final video = _video;
    final canvas = _canvas;
    if (!_running || gl == null || video == null || canvas == null) return;
    if (video.readyState >= 2) {
      final on = beauty.enabled;
      final m = beauty.filter.shaderMatrix;
      final o = beauty.filter.shaderOffset;
      gl
        ..viewport(0, 0, canvas.width, canvas.height)
        ..texImage2D(
          web.WebGLRenderingContext.TEXTURE_2D,
          0,
          web.WebGLRenderingContext.RGBA,
          web.WebGLRenderingContext.RGBA.toJS,
          web.WebGLRenderingContext.UNSIGNED_BYTE.toJS,
          video,
        )
        ..uniform1f(_uSmooth, on ? beauty.smooth : 0)
        ..uniform1f(_uBright, on ? beauty.brighten : 0)
        // D143: the colour filter, on the published frame.
        ..uniformMatrix3fv(_uMatrix, false, Float32List.fromList(m).toJS)
        ..uniform3f(_uOffset, o[0], o[1], o[2])
        ..drawArrays(web.WebGLRenderingContext.TRIANGLE_STRIP, 0, 4);
    }
    _scheduleFrame();
  }

  @override
  Future<void> restart(lk.VideoProcessorOptions options) async {
    await destroy();
    await init(options);
  }

  @override
  Future<void> destroy() async {
    _running = false;
    _video?.srcObject = null;
    _video = null;
    for (final t
        in outputStream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      t.stop();
    }
    outputStream = null;
    _processed = null;
    _gl = null;
    _canvas = null;
  }

  @override
  Future<void> onPublish(lk.Room room) async {}

  @override
  Future<void> onUnpublish() async {}
}

const _vertex = '''
attribute vec2 a_position;
varying vec2 v_uv;
void main() {
  v_uv = a_position * 0.5 + 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}
''';

// Edge-preserving smoothing (a bilateral filter on 16 taps over two rings)
// weighted by a YCbCr skin mask, then a gentle gamma lift with a little
// warmth; then the colour filter (D143): an affine transform on RGB.
const _fragment = '''
precision mediump float;
varying vec2 v_uv;
uniform sampler2D u_tex;
uniform vec2 u_texel;
uniform float u_smooth;
uniform float u_bright;
uniform mat3 u_cm;
uniform vec3 u_co;

float skin(vec3 c) {
  float y = dot(c, vec3(0.299, 0.587, 0.114));
  float cb = (c.b - y) * 0.564 + 0.5;
  float cr = (c.r - y) * 0.713 + 0.5;
  float d = distance(vec2(cb, cr), vec2(0.44, 0.60));
  return 1.0 - smoothstep(0.06, 0.13, d);
}

void main() {
  vec3 base = texture2D(u_tex, v_uv).rgb;
  vec3 color = base;
  if (u_smooth > 0.0) {
    vec3 sum = base;
    float wsum = 1.0;
    for (int ring = 1; ring <= 2; ring++) {
      float r = float(ring) * 3.0;
      for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398;
        vec2 off = vec2(cos(a), sin(a)) * r * u_texel;
        vec3 s = texture2D(u_tex, v_uv + off).rgb;
        float diff = distance(s, base);
        float w = exp(-diff * diff * 40.0) * (ring == 1 ? 1.0 : 0.6);
        sum += s * w;
        wsum += w;
      }
    }
    vec3 smoothed = sum / wsum;
    color = mix(base, smoothed, clamp(u_smooth * skin(base) * 1.2, 0.0, 1.0));
  }
  if (u_bright > 0.0) {
    color = pow(color, vec3(1.0 / (1.0 + u_bright * 0.45)));
    color += vec3(0.02, 0.01, 0.0) * u_bright;
  }
  color = u_cm * clamp(color, 0.0, 1.0) + u_co;
  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
''';
