#version 460 core
// Kabso Live (D207, CONVENTIONS §10.66): a side-by-side alpha gift effect. The input is the MP4's whole frame, laid
// out twice as wide as the effect: its left half is the colour, its right half the alpha mask (grey: the red channel
// is used). The left half is drawn with that alpha (premultiplied); the right half comes out transparent and is
// clipped away by the widget. Applied with ImageFilter.shader (Impeller only).

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  if (uv.x >= 0.5) {
    frag_color = vec4(0.0);
    return;
  }
  vec4 colour = texture(u_texture, uv);
  float alpha = texture(u_texture, vec2(uv.x + 0.5, uv.y)).r;
  // The video is opaque: un-premultiply is not needed; premultiply by the mask.
  frag_color = vec4(colour.rgb * alpha, alpha);
}
