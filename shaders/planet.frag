#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 centre;     // у пікселях
    float radius;    // у пікселях
    float spin;      // радіани
    float tilt;      // радіани
    float hasRing;
    float hasClouds;
    float mode;      // 0: зорі, 1: планета з прозорим тлом
    float drift;     // зсув зір під час перельоту, у пікселях
    vec4 rim;
};

layout(binding = 1) uniform sampler2D surface;
layout(binding = 2) uniform sampler2D ringMap;
layout(binding = 3) uniform sampler2D cloudMap;

const float PI = 3.14159265;
const vec3 SUN = normalize(vec3(-0.78, -0.22, 0.58));
const float RING_IN = 1.24;   // кільце C
const float RING_OUT = 2.27;  // кільце A
const float RING_S = 0.30;    // нахил площини кілець до глядача

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Кільце в точці екрана: rgb і прозорість. Тінь планети падає на нього від Сонця.
vec4 ring(vec2 q) {
    float b = q.y / RING_S;
    float rr = length(vec2(q.x, b));
    if (rr < RING_IN || rr > RING_OUT)
        return vec4(0.0);
    float a = texture(ringMap, vec2((rr - RING_IN) / (RING_OUT - RING_IN), 0.5)).a;
    vec3 p = vec3(q.x, b * RING_S, b * sqrt(1.0 - RING_S * RING_S));
    float d = dot(p, SUN);
    float lit = (d < 0.0 && length(p - d * SUN) < 1.0) ? 0.04 : 1.0;
    return vec4(vec3(0.82, 0.76, 0.62) * lit, a * 0.92);
}

// Накладає шар rgb із прозорістю a поверх накопиченого (premultiplied)
vec4 over(vec4 under, vec3 rgb, float a) {
    return vec4(rgb * a, a) + under * (1.0 - a);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;

    if (mode < 0.5) {
        // Чорний космос: дрібні зорі зсуваються, коли камера летить
        vec2 cell = floor((px + vec2(drift, 0.0)) / 2.0);
        float star = step(0.9975, hash(cell + 3.7)) * (0.25 + 0.75 * hash(cell + 11.0));
        fragColor = vec4(vec3(0.008, 0.010, 0.014) + star * 0.8, 1.0) * qt_Opacity;
        return;
    }

    vec2 p = (px - centre) / radius;
    float ct = cos(tilt), st = sin(tilt);
    vec2 q = vec2(ct * p.x + st * p.y, -st * p.x + ct * p.y);
    float r = length(q);
    float aa = 1.5 / radius;
    vec4 out_ = vec4(0.0);

    // Тонка смуга атмосфери по краю
    float halo = smoothstep(1.035, 1.0, r) * step(1.0, r) * max(0.0, dot(normalize(vec3(q, 0.0)), SUN) + 0.45);
    out_ += vec4(rim.rgb * 0.22 * halo, 0.22 * halo);

    // Задня половина кілець -- за планетою
    if (hasRing > 0.5 && q.y < 0.0) {
        vec4 c = ring(q);
        out_ = over(out_, c.rgb, c.a);
    }

    if (r < 1.0 + aa) {
        vec3 n = vec3(q, sqrt(max(0.0, 1.0 - r * r)));
        float u = fract(atan(n.x, n.z) / (2.0 * PI) + 0.5 + spin / (2.0 * PI));
        float v = 0.5 + asin(clamp(n.y, -1.0, 1.0)) / PI;
        vec3 albedo = textureLod(surface, vec2(u, v), 1.0).rgb;
        float light = smoothstep(-0.04, 0.42, dot(n, SUN));
        vec3 body = albedo * (light * 1.05 + 0.008) * mix(0.7, 1.0, n.z);
        if (hasClouds > 0.5) {
            // Хмари дрейфують трохи швидше за поверхню й затіняють її під собою
            float cu = fract(u + spin * 0.06 / (2.0 * PI) + 0.31);
            float cloud = textureLod(cloudMap, vec2(cu, v), 1.0).r;
            body = mix(body, vec3(0.95) * (light * 1.05 + 0.004) * mix(0.75, 1.0, n.z), smoothstep(0.08, 0.72, cloud) * 0.92);
        }
        body += rim.rgb * pow(1.0 - n.z, 4.0) * light * 0.28;
        out_ = over(out_, body, 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r));
    }

    // Передня половина кілець -- перед планетою
    if (hasRing > 0.5 && q.y >= 0.0) {
        vec4 c = ring(q);
        out_ = over(out_, c.rgb, c.a);
    }

    fragColor = out_ * qt_Opacity;
}
