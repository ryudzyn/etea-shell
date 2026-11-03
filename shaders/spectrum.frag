#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 centre;     // у пікселях
    float radius;    // радіус планети, у пікселях
    float tilt;      // радіани
    float inner;     // де починаються кільця, у радіусах планети
    float amount;    // наскільки сильно їх гне музика
    vec4 tint;
    vec4 l0;
    vec4 l1;
    vec4 l2;
    vec4 l3;
    vec4 l4;
    vec4 l5;
    vec4 l6;
};

const float PI = 3.14159265;
const float FLAT = 0.34; // нахил площини кілець до глядача

float level(float t) {
    vec4 bands[7] = vec4[7](l0, l1, l2, l3, l4, l5, l6);
    float x = clamp(t, 0.0, 1.0) * 26.999;
    int i = int(x);
    int j = i + 1;
    float a = bands[i / 4][i % 4];
    float b = bands[j / 4][j % 4];
    return mix(a, b, smoothstep(0.0, 1.0, fract(x)));
}

// Одна лінія кільця: base у радіусах планети, gain -- частка деформації
float ring(vec2 e, float rr, float t, float base, float gain, float px) {
    float target = base + level(t) * amount * gain;
    return 1.0 - smoothstep(px * 0.6, px * 1.6, abs(rr - target));
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    vec2 p = (px - centre) / radius;
    float ct = cos(tilt), st = sin(tilt);
    vec2 q = vec2(ct * p.x + st * p.y, -st * p.x + ct * p.y);

    // Задня половина кілець ховається за диском планети
    if (q.y < 0.0 && length(q) < 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 e = vec2(q.x, q.y / FLAT);
    float rr = length(e);
    float pixel = 1.0 / radius / max(0.34, length(vec2(q.x / max(rr, 0.001), q.y / max(rr, 0.001) / FLAT)) * FLAT);
    // Частоти дзеркально від лівого краю до правого, обидві половини кільця однакові
    float t = abs(atan(e.y, e.x)) / PI;

    float a = ring(e, rr, t, inner, 1.0, pixel) * 0.85;
    a = max(a, ring(e, rr, t, inner + 0.11, 0.62, pixel) * 0.5);
    a = max(a, ring(e, rr, t, inner + 0.22, 0.34, pixel) * 0.28);

    fragColor = vec4(tint.rgb * a, a) * qt_Opacity;
}
