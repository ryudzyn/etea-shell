#version 440

// Погода за вікном: дощ, сніг, туман і спалахи грози поверх шпалер (World.qml, Weather.qml).
// Сила кожного -- 0..1 з коду погоди open-meteo; усе нуль -- шейдер не малюється взагалі.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float time;
    float rain;     // 0 мряка ... 1 злива
    float snow;
    float fog;
    float flash;    // спалах блискавки, 0..1
    float horizon;  // де починається земля, частка висоти згори
};

float hash(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Шар дощу: стовпці шириною w, у кожному крапля-риска зі своєю швидкістю й фазою; трохи навскіс
float rainLayer(vec2 px, float w, float speed, float len, float density) {
    px.x += px.y * 0.18;
    float col = floor(px.x / w);
    float h = hash(col);
    if (h > density)
        return 0.0;
    float x = fract(px.x / w) - 0.5;
    float line = smoothstep(0.12, 0.0, abs(x));
    float y = fract(px.y / resolution.y - time * speed * (0.8 + 0.4 * h) - hash(col + 7.3));
    float streak = smoothstep(0.0, len * 0.3, y) * smoothstep(len, len * 0.6, y) * step(y, len);
    return line * streak;
}

// Шар снігу: у кожній клітинці одна пластівка, падає повільно й гойдається
float snowLayer(vec2 uv, float cell, float speed, float size) {
    vec2 p = uv * resolution / cell;
    p.y -= time * speed;
    vec2 id = floor(p);
    vec2 f = fract(p) - 0.5;
    float h = hash2(id);
    if (h > 0.4) // приблизно кожна друга-третя клітинка
        return 0.0;
    vec2 c = vec2(hash2(id + 3.1) - 0.5, hash2(id + 5.7) - 0.5) * 0.6;
    c.x += 0.18 * sin(time * (0.8 + h) + h * 6.28);
    return smoothstep(size, 0.0, length(f - c)); // розмитий край замість різкої цятки
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    vec4 col = vec4(0.0);

    if (rain > 0.0) {
        float r = rainLayer(px, 9.0, 1.6, 0.07, 0.25 + 0.5 * rain) * 0.35
                + rainLayer(px + 3.0, 6.0, 1.15, 0.05, 0.2 + 0.45 * rain) * 0.22
                + rainLayer(px + 7.0, 4.0, 0.8, 0.035, 0.15 + 0.4 * rain) * 0.14;
        float a = clamp(r * (0.45 + 0.75 * rain), 0.0, 0.6);
        col += vec4(vec3(0.72, 0.80, 0.92) * a, a);
        // у зливу повітря сіріє
        float haze = 0.08 * rain;
        col = col + vec4(vec3(0.45, 0.5, 0.58) * haze, haze) * (1.0 - col.a);
    }

    if (snow > 0.0) {
        float s = snowLayer(uv, 46.0, 0.9, 0.16) * 0.9
                + snowLayer(uv + 0.37, 30.0, 0.6, 0.14) * 0.6
                + snowLayer(uv + 0.71, 20.0, 0.4, 0.12) * 0.4;
        // м'якше й тьмяніше: яскраві білі цятки по всьому екрану різали очі (автор, 2026-11-15)
        float a = clamp(s * (0.22 + 0.33 * snow), 0.0, 0.5);
        col = col + vec4(vec3(0.86, 0.9, 0.96) * a, a) * (1.0 - col.a);
    }

    if (fog > 0.0) {
        // імла від горизонту вгору, з повільними пасмами
        float d = clamp((uv.y - (horizon - 0.35)) / 0.55, 0.0, 1.0);
        float drift = 0.5 + 0.5 * sin(px.x * 0.004 + time * 0.07) * sin(px.x * 0.0013 - time * 0.04 + uv.y * 3.0);
        float a = fog * smoothstep(0.0, 1.0, d) * (0.35 + 0.25 * drift);
        col = col + vec4(vec3(0.62, 0.66, 0.72) * a, a) * (1.0 - col.a);
    }

    if (flash > 0.0) {
        float a = flash * 0.35;
        col = col + vec4(vec3(0.85, 0.88, 1.0) * a, a) * (1.0 - col.a);
    }

    fragColor = col * qt_Opacity;
}
