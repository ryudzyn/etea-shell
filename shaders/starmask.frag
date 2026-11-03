#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
    vec2 resolution;
    vec2 center;
    float reach;
    float shine;
    float flipped; // 1 keeps the outside and cuts a star-shaped hole instead
};

layout(binding = 1) uniform sampler2D source;

// Shows the picture through a four-pointed star, or punches that star out of it.
// This is the same star as everywhere else in ETEA, written as a distance so it
// stays sharp at any size.
void main() {
    vec2 p = qt_TexCoord0 * resolution - center;
    float d = max(abs(p.x), abs(p.y) * resolution.x / resolution.y);

    float inside = smoothstep(reach + 1.5, reach - 1.5, d);
    inside = mix(inside, 1.0 - inside, flipped);
    float edge = 0.0;

    vec4 picture = texture(source, qt_TexCoord0) * inside;
    float light = edge * (1.0 - picture.a * 0.4);
    fragColor = (picture + vec4(tint.rgb * light, light)) * qt_Opacity;
}
