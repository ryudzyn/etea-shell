.pragma library

// Положення світил для місця спостереження. Планети -- наближені елементи орбіт JPL
// (Standish, 1800-2050), Місяць -- спрощені ряди Міуса. Звірено з PyEphem на 2026-2030: найгірше
// 0.17° у Місяця і соті градуса у планет.
var rad = Math.PI / 180;

// a, e, I, L, w, node і їхні зміни за століття
var elements = {
    "Меркурій": [0.38709927, 0.00000037, 0.20563593, 0.00001906, 7.00497902, -0.00594749, 252.25032350, 149472.67411175, 77.45779628, 0.16047689, 48.33076593, -0.12534081],
    "Венера": [0.72333566, 0.00000390, 0.00677672, -0.00004107, 3.39467605, -0.00078890, 181.97909950, 58517.81538729, 131.60246718, 0.00268329, 76.67984255, -0.27769418],
    "Земля": [1.00000261, 0.00000562, 0.01671123, -0.00004392, -0.00001531, -0.01294668, 100.46457166, 35999.37244981, 102.93768193, 0.32327364, 0, 0],
    "Марс": [1.52371034, 0.00001847, 0.09339410, 0.00007882, 1.84969142, -0.00813131, -4.55343205, 19140.30268499, -23.94362959, 0.44441088, 49.55953891, -0.29257343],
    "Юпітер": [5.20288700, -0.00011607, 0.04838624, -0.00013253, 1.30439695, -0.00183714, 34.39644051, 3034.74612775, 14.72847983, 0.21252668, 100.47390909, 0.20469106],
    "Сатурн": [9.53667594, -0.00125060, 0.05386179, -0.00050991, 2.48599187, 0.00193609, 49.95424423, 1222.49362201, 92.59887831, -0.41897216, 113.66242448, -0.28867794],
    "Уран": [19.18916464, -0.00196176, 0.04725744, -0.00004397, 0.77263783, -0.00242939, 313.23810451, 428.48202785, 170.95427630, 0.40805281, 74.01692503, 0.04240589],
    "Нептун": [30.06992276, 0.00026291, 0.00859048, 0.00005105, 1.77004347, 0.00035372, -55.12002969, 218.45945325, 44.96476227, -0.32241464, 131.78422574, -0.00508664]
};

function heliocentric(name, T) {
    var q = elements[name];
    var a = q[0] + q[1] * T, e = q[2] + q[3] * T, I = (q[4] + q[5] * T) * rad;
    var L = q[6] + q[7] * T, w = q[8] + q[9] * T, node = (q[10] + q[11] * T) * rad;
    var M = ((L - w) % 360 + 540) % 360 - 180;
    M *= rad;
    var E = M + e * Math.sin(M);
    for (var i = 0; i < 6; i++)
        E -= (E - e * Math.sin(E) - M) / (1 - e * Math.cos(E));
    var x = a * (Math.cos(E) - e), y = a * Math.sqrt(1 - e * e) * Math.sin(E);
    var p = w * rad - node;
    var cp = Math.cos(p), sp = Math.sin(p), cn = Math.cos(node), sn = Math.sin(node), ci = Math.cos(I), si = Math.sin(I);
    return [
        (cp * cn - sp * sn * ci) * x + (-sp * cn - cp * sn * ci) * y,
        (cp * sn + sp * cn * ci) * x + (-sp * sn + cp * cn * ci) * y,
        sp * si * x + cp * si * y
    ];
}

// Елементи прив'язані до рівнодення J2000, а небо спостерігають на сьогодні: прецесія
function precess(v, T) {
    var a = 1.39697 * T * rad;
    return [v[0] * Math.cos(a) - v[1] * Math.sin(a), v[0] * Math.sin(a) + v[1] * Math.cos(a), v[2]];
}

// Екваторіальні координати з геоцентричного екліптичного вектора
function equatorial(v, T) {
    var eps = (23.43928 - 0.0130 * T) * rad;
    var y = v[1] * Math.cos(eps) - v[2] * Math.sin(eps);
    var z = v[1] * Math.sin(eps) + v[2] * Math.cos(eps);
    return { ra: Math.atan2(y, v[0]), dec: Math.atan2(z, Math.sqrt(v[0] * v[0] + y * y)) };
}

function moonVector(T) {
    function s(a, b) { return Math.sin((a + b * T) * rad); }
    var lon = 218.32 + 481267.881 * T + 6.29 * s(135.0, 477198.87) - 1.27 * s(259.3, -413335.36)
        + 0.66 * s(235.7, 890534.22) + 0.21 * s(269.9, 954397.74) - 0.19 * s(357.5, 35999.05) - 0.11 * s(186.5, 966404.03);
    var lat = 5.13 * s(93.3, 483202.02) + 0.28 * s(228.2, 960400.89) - 0.28 * s(318.3, 6003.15) - 0.17 * s(217.6, -407332.21);
    var L = lon * rad, B = lat * rad;
    return [Math.cos(B) * Math.cos(L), Math.cos(B) * Math.sin(L), Math.sin(B)];
}

function horizontal(eq, jd, latitude, longitude) {
    var gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0);
    var H = (gmst + longitude) * rad - eq.ra;
    var phi = latitude * rad;
    var alt = Math.asin(Math.sin(phi) * Math.sin(eq.dec) + Math.cos(phi) * Math.cos(eq.dec) * Math.cos(H));
    // Азимут від півночі за годинниковою стрілкою
    var az = Math.atan2(-Math.sin(H) * Math.cos(eq.dec), Math.cos(phi) * Math.sin(eq.dec) - Math.sin(phi) * Math.cos(eq.dec) * Math.cos(H));
    return { alt: alt / rad, az: ((az / rad) % 360 + 360) % 360 };
}

// Усі світила на момент date. Без рефракції: це геометрична висота.
function bodies(date, latitude, longitude) {
    var jd = date.getTime() / 86400000 + 2440587.5;
    var T = (jd - 2451545.0) / 36525;
    var earth = heliocentric("Земля", T);
    var out = [];
    var sun = horizontal(equatorial(precess([-earth[0], -earth[1], -earth[2]], T), T), jd, latitude, longitude);
    out.push({ name: "Сонце", alt: sun.alt, az: sun.az });
    var moon = horizontal(equatorial(moonVector(T), T), jd, latitude, longitude);
    // Місяць близько: паралакс опускає його приблизно на градус
    out.push({ name: "Місяць", alt: moon.alt - 0.95 * Math.cos(moon.alt * rad), az: moon.az });
    ["Меркурій", "Венера", "Марс", "Юпітер", "Сатурн", "Уран", "Нептун"].forEach(function (name) {
        var p = heliocentric(name, T);
        var h = horizontal(equatorial(precess([p[0] - earth[0], p[1] - earth[1], p[2] - earth[2]], T), T), jd, latitude, longitude);
        out.push({ name: name, alt: h.alt, az: h.az });
    });
    return out;
}
