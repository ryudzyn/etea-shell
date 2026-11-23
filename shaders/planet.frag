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
    float mode;      // 0: зорі, 1: планета з прозорим тлом, 2: те саме, але без поля уламків (значок у Сонячній системі)
    float drift;     // зсув зір під час перельоту, у пікселях
    float sunLat;    // широта, над якою сонце в зеніті (пори року), радіани, північ +
    vec4 rim;
    float kind;      // 0: планета з текстурою, 1: Сонце (світить саме), 2: Церера в поясі астероїдів
};

layout(binding = 1) uniform sampler2D surface;
layout(binding = 2) uniform sampler2D ringMap;
layout(binding = 3) uniform sampler2D cloudMap;

const float PI = 3.14159265;
// Сонце зліва-спереду: кут по горизонталі як завжди (від нього рахує Planets.spinAt), а висоту
// задає sunLat -- справжня пора року; рахуємо на початку main
const float SUN_PHI = -0.931363; // atan2(-0.78, 0.58)
vec3 SUN;
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

// Тривимірний шум для тих, у кого немає текстури: Сонця й каміння поясу
float hash3(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise3(p);
        p = p * 2.03 + 17.1;
        a *= 0.5;
    }
    return v;
}

// Точка сфери n, повернута навколо осі на spin -- щоб візерунок обертався разом із тілом
vec3 spun(vec3 n) {
    float c = cos(spin), s = sin(spin);
    return vec3(c * n.x + s * n.z, n.y, -s * n.x + c * n.z);
}

// Сонце: грануляція, темніший край диска, плями й корона. Освітлення ззовні немає -- світить саме.
vec4 star(vec2 q, float r, float aa) {
    vec4 out_ = vec4(0.0);
    // Корона: м'яке сяйво, з променями, що повільно повертаються з Сонцем
    if (r > 0.98) {
        float ang = atan(q.y, q.x);
        float rays = 0.75 + 0.25 * noise3(vec3(cos(ang) * 3.0, sin(ang) * 3.0, spin * 0.5));
        float glow = exp(-(r - 1.0) * 5.5) * 0.55 * rays + exp(-(r - 1.0) * 1.6) * 0.12;
        glow *= smoothstep(0.98, 1.02, r);
        out_ += vec4(vec3(1.0, 0.62, 0.24) * glow, glow);
    }
    if (r < 1.0 + aa) {
        vec3 n = vec3(q, sqrt(max(0.0, 1.0 - r * r)));
        vec3 sp = spun(n);
        // Дрібні гранули поверх великих комірок -- кипляча поверхня, а не плями
        float gran = 0.6 * fbm(sp * 34.0) + 0.4 * fbm(sp * 7.0);
        float spots = smoothstep(0.66, 0.72, fbm(sp * 2.6 + 5.0)) * smoothstep(0.5, 0.1, abs(n.y)); // плями -- біля екватора
        float limb = pow(n.z, 0.55);
        float heat = clamp(limb * (0.78 + 0.55 * (gran - 0.5)) - spots * 0.55, 0.0, 1.2);
        vec3 body = mix(vec3(0.62, 0.16, 0.03), vec3(1.0, 0.58, 0.18), smoothstep(0.1, 0.55, heat));
        body = mix(body, vec3(1.0, 0.92, 0.72), smoothstep(0.62, 0.95, heat));
        out_ = over(out_, body, 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r));
    }
    return out_;
}

// Камінь у точці d (його власні координати, радіус ~1): горбкуватий край, тінь від Сонця
vec4 rock(vec2 d, float seed, float aa) {
    float ang = atan(d.y, d.x);
    float edge = 0.78 + 0.22 * noise3(vec3(cos(ang) * 1.6, sin(ang) * 1.6, seed * 7.0)) + 0.08 * noise3(vec3(cos(ang) * 5.0, sin(ang) * 5.0, seed * 3.0));
    float r = length(d) / edge;
    if (r > 1.0 + aa)
        return vec4(0.0);
    vec3 n = normalize(vec3(d / edge, sqrt(max(0.0, 1.0 - r * r)) + 0.05));
    float tex = fbm(vec3(d * 3.0, seed * 11.0));
    n = normalize(n + 0.35 * vec3(tex - 0.5, noise3(vec3(d * 4.0, seed)) - 0.5, 0.0));
    float light = smoothstep(0.05, 0.85, dot(n, SUN));
    vec3 col = mix(vec3(0.17, 0.155, 0.14), vec3(0.46, 0.42, 0.37), tex) * (light * 1.15 + 0.012);
    return vec4(col, 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r));
}

// Поле уламків по діагональній смузі через увесь екран; p -- у радіусах Церери від її центру
vec4 belt(vec2 p, float aa) {
    vec4 out_ = vec4(0.0);
    // Три шари: далекі дрібні, середні й поодинокі ближчі. Далекі малюємо першими.
    for (int layer = 0; layer < 3; layer++) {
        float fl = float(layer);
        float cell = 0.55 + fl * 0.6;
        vec2 shift = vec2(fl * 13.7, fl * 5.3);
        vec2 g = p / cell + shift;
        vec2 id = floor(g);
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                vec2 c = id + vec2(i, j);
                vec2 at = c + vec2(hash(c + 7.1), hash(c + 3.9));
                vec2 home = (at - shift) * cell; // де камінь на екрані, у радіусах Церери
                float band = exp(-pow((home.y + home.x * 0.28) / (1.15 + fl * 0.45), 2.0)); // густіше вздовж смуги
                float h = hash(c + fl * 41.0);
                if (h > 0.04 + 0.9 * band)
                    continue;
                float size = cell * (0.05 + 0.16 * pow(hash(c + 9.3), 3.0)) * (0.6 + 0.4 * fl);
                vec2 d = (g - at) * cell / size;
                if (dot(d, d) > 2.0)
                    continue;
                vec4 k = rock(d, h * 100.0 + fl, aa / size);
                out_ = over(out_, k.rgb * (0.45 + 0.25 * fl), k.a); // далекі темніші
            }
    }
    return out_;
}

void main() {
    SUN = vec3(cos(sunLat) * sin(SUN_PHI), -sin(sunLat), cos(sunLat) * cos(SUN_PHI));
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

    if (kind > 0.5 && kind < 1.5) {
        fragColor = star(q, r, aa) * qt_Opacity;
        return;
    }
    if (kind > 1.5) {
        // Уламки поясу за Церерою, потім вона сама -- брила без текстури, у кратерах
        if (mode < 1.5)
            out_ = belt(p, aa);
        if (r < 1.0 + aa) {
            vec3 n = vec3(q, sqrt(max(0.0, 1.0 - r * r)));
            vec3 sp = spun(n);
            float tex = fbm(sp * 4.0);
            float craters = smoothstep(0.62, 0.70, fbm(sp * 7.0 + 3.0)) - smoothstep(0.70, 0.76, fbm(sp * 7.0 + 3.0)) * 0.6;
            float bright = smoothstep(0.90, 0.93, noise3(sp * 9.0 + 1.0)) * 0.5; // світлі плями солей, як Окатор
            vec3 albedo = mix(vec3(0.17, 0.16, 0.15), vec3(0.33, 0.31, 0.29), tex) - craters * 0.06 + bright * vec3(0.35);
            float light = smoothstep(-0.04, 0.42, dot(n, SUN));
            vec3 body = albedo * (light * 1.05 + 0.008) * mix(0.7, 1.0, n.z);
            body += rim.rgb * pow(1.0 - n.z, 4.0) * light * 0.18;
            out_ = over(out_, body, 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r));
        }
        fragColor = out_ * qt_Opacity;
        return;
    }

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
