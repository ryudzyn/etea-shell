pragma Singleton

import QtQuick
import Quickshell

// The worlds you can live on. A theme is a planet, and a planet is just these few values,
// so adding one means adding one entry here.
Singleton {
    readonly property var all: builtIn.concat(Config.customPlanets)

    // Планети за порядком від Сонця (у них є текстури й орбіти)
    readonly property var solar: ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
    // Кожен робочий стіл -- своє тіло: 1 -- Сонце, 2-9 -- планети, 10 -- пояс астероїдів (Церера).
    // Раніше після восьми планет список ішов по колу, і 9-й стіл знову був Меркурієм.
    readonly property var pages: ["sun"].concat(solar, ["belt"])

    // Тема "Глибокий космос": шпалери-шейдери замість планет, спільні для всіх столів
    readonly property var deep: [
        { id: "blackhole", deep: true, name: "Чорна діра", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#e8b27a" },
        { id: "blackhole-gargantua", deep: true, name: "Гаргантюа", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#f0c98a" },
        { id: "galaxy", deep: true, name: "Галактика", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#b7a6e8" },
        { id: "nebula-dust", deep: true, name: "Туманність", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#d88ab0" },
        { id: "pulsar", deep: true, name: "Пульсар", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#8fc7e8" },
        { id: "wormhole", deep: true, name: "Кротовина", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#9fd6c8" },
        // Пейзажі: стоїш на поверхні Землі (шейдери earth-hills/earth-flight у nebula-config)
        { id: "earth-hills", deep: true, name: "Земля: пагорби", line: "Пейзаж", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#f0b48c" },
        { id: "earth-flight", deep: true, name: "Земля: політ", line: "Пейзаж", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#e8c9a8" },
        // Один шейдер, десять сцен: на кожному столі стоїш на поверхні його тіла (landscape.frag у nebula-config)
        { id: "landscape", deep: true, perPage: true, name: "Пейзажі", line: "Кожен стіл -- своя поверхня", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#e8a070",
          // Акцент кожної сцени (віджети, світло вікна) і довідка про місце, де стоїш.
          // event -- живий рядок, що йде в такт із шейдером (той самий Planet.deepTime).
          surfaces: {
              sun: { light: "#ffb060", name: "Фотосфера", where: "Сонце", temp: "5 500 °C", g: "27.9 g", day: "25.4 д", sky: "коронні дуги", event: "eruption" },
              mercury: { light: "#ece4d8", name: "Меркурій", where: "рівнина Калорис", temp: "+430 °C", g: "0.38 g", day: "176 д", sky: "Сонце втричі більше", event: "comet" },
              venus: { light: "#ffd086", name: "Венера", where: "гори Максвелла", temp: "+464 °C", g: "0.90 g", day: "117 д", sky: "сірчані хмари, грози" },
              earth: { light: "#ffc4a4", name: "Земля", where: "Карпати", temp: "+8 °C", g: "1.00 g", day: "24 г", sky: "Місяць, зорепад" },
              mars: { light: "#a8c4f0", name: "Марс", where: "кратер Ґейл", temp: "−63 °C", g: "0.38 g", day: "24 г 40 хв", sky: "Фобос, блакитний захід" },
              jupiter: { light: "#f2d4a8", name: "Європа", where: "супутник Юпітера", temp: "−160 °C", g: "0.13 g", day: "3.55 д", sky: "Юпітер", event: "io" },
              saturn: { light: "#d2e8ff", name: "Енцелад", where: "тигрові смуги", temp: "−198 °C", g: "0.011 g", day: "1.37 д", sky: "Сатурн, гейзери", event: "comet" },
              uranus: { light: "#aee6ea", name: "Міранда", where: "урвище Верона", temp: "−187 °C", g: "0.008 g", day: "1.41 д", sky: "Уран", event: "comet" },
              neptune: { light: "#96b4ff", name: "Тритон", where: "супутник Нептуна", temp: "−235 °C", g: "0.08 g", day: "5.88 д (ретр.)", sky: "Нептун, азотні струмені", event: "comet" },
              belt: { light: "#e2d8c8", name: "Церера", where: "гора Ахуна", temp: "−105 °C", g: "0.03 g", day: "9 г 04 хв", sky: "уламки поясу", event: "comet" }
          } },
        // Справжні відео NASA SVS (public domain), файли кладе збірка в assets/video
        { id: "earth-nasa", deep: true, video: "earth-spin-nasa.mp4", name: "Земля (NASA)", line: "Відео", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#7fb2d9" },
        { id: "blackhole-nasa", deep: true, video: "blackhole-nasa.mp4", name: "Чорна діра (NASA)", line: "Відео", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#e8b27a" }
    ]

    function forPage(page) {
        return pages[(Math.max(page, 1) - 1) % pages.length];
    }

    readonly property var builtIn: [
        // kind (shaders/planet.frag): 1 -- зоря, що світить сама; 2 -- Церера серед уламків поясу
        { id: "sun", kind: 1, facts: { radius: "696 340 км", day: "25.4 д", year: "230 млн р", tilt: "7.25°" }, size: 0.31, tilt: 0.13, name: "Сонце", line: "0 а.о.", skyTop: "#060403", skyMid: "#170d06", skyLow: "#33190a", terrain: ["#32190b", "#221008", "#150a05", "#0a0503"], light: "#f0b45a" },
        { id: "mercury", facts: { radius: "2 439.7 км", day: "58.6 д", year: "88.0 д", tilt: "0.03°" }, texture: "2k_mercury.jpg", size: 0.2, tilt: 0.0, name: "Меркурій", line: "0.39 а.о.", skyTop: "#040405", skyMid: "#0e0d0c", skyLow: "#23201d", terrain: ["#26231f", "#1a1815", "#100f0d", "#070606"], light: "#b8b0a6" },
        { id: "venus", facts: { radius: "6 051.8 км", day: "243 д (ретр.)", year: "224.7 д", tilt: "177.4°" }, texture: "2k_venus_atmosphere.jpg", size: 0.27, tilt: 0.05, name: "Венера", line: "0.72 а.о.", skyTop: "#050403", skyMid: "#14100a", skyLow: "#2e2414", terrain: ["#2b2214", "#1d170e", "#120e08", "#080604"], light: "#e0c388" },
        { id: "earth", facts: { radius: "6 371 км", day: "23 г 56 хв", year: "365.25 д", tilt: "23.4°" }, texture: "2k_earth_daymap.jpg", clouds: true, size: 0.29, tilt: -0.41, name: "Земля", line: "1.00 а.о.", skyTop: "#030406", skyMid: "#0a1119", skyLow: "#162636", terrain: ["#172635", "#101a25", "#0a1118", "#05080c"], light: "#7fb2d9" },
        { id: "mars", facts: { radius: "3 389.5 км", day: "24 г 37 хв", year: "687 д", tilt: "25.2°" }, texture: "2k_mars.jpg", size: 0.24, tilt: -0.44, name: "Марс", line: "1.52 а.о.", skyTop: "#050303", skyMid: "#160b08", skyLow: "#32170f", terrain: ["#2f1810", "#20100b", "#140a07", "#090504"], light: "#d97050" },
        { id: "jupiter", facts: { radius: "69 911 км", day: "9 г 56 хв", year: "11.86 р", tilt: "3.1°" }, texture: "2k_jupiter.jpg", size: 0.33, tilt: -0.05, name: "Юпітер", line: "5.20 а.о.", skyTop: "#050403", skyMid: "#140f0a", skyLow: "#2e2216", terrain: ["#2c2116", "#1e160f", "#130e09", "#080604"], light: "#d6a878" },
        { id: "saturn", facts: { radius: "58 232 км", day: "10 г 33 хв", year: "29.46 р", tilt: "26.7°" }, texture: "2k_saturn.jpg", size: 0.19, tilt: -0.3, ring: true, name: "Сатурн", line: "9.58 а.о.", skyTop: "#050404", skyMid: "#13110c", skyLow: "#2c2619", terrain: ["#2a2418", "#1c1810", "#120f0a", "#080705"], light: "#dcc898" },
        { id: "uranus", facts: { radius: "25 362 км", day: "17 г 14 хв", year: "84.0 р", tilt: "97.8°" }, texture: "2k_uranus.jpg", size: 0.28, tilt: 1.2, name: "Уран", line: "19.2 а.о.", skyTop: "#030505", skyMid: "#0a1415", skyLow: "#162b2e", terrain: ["#172b2e", "#0f1d1f", "#0a1314", "#050909"], light: "#9fd6dc" },
        { id: "neptune", facts: { radius: "24 622 км", day: "16 г 06 хв", year: "164.8 р", tilt: "28.3°" }, texture: "2k_neptune.jpg", size: 0.28, tilt: -0.49, name: "Нептун", line: "30.1 а.о.", skyTop: "#030406", skyMid: "#0a0f1c", skyLow: "#141f3a", terrain: ["#152038", "#0e1626", "#090e18", "#04070c"], light: "#6f92d6" },
        { id: "belt", kind: 2, facts: { radius: "469.7 км (Церера)", day: "9 г 04 хв", year: "4.60 р", tilt: "4°" }, size: 0.15, tilt: 0.07, name: "Пояс астероїдів", line: "2.2–3.3 а.о.", skyTop: "#040404", skyMid: "#0f0e0d", skyLow: "#24211e", terrain: ["#25221f", "#191715", "#100e0d", "#070606"], light: "#c2b8aa" },
        {
            id: "aster",
            name: "Aster",
            line: Lang.t("Le soir qui ne finit pas."),
            skyTop: "#2b3a55",
            skyMid: "#c9744b",
            skyLow: "#f2b872",
            terrain: ["#a8553c", "#7a3a33", "#4f2630", "#2c1622"],
            light: "#ffe2a8"
        },
        {
            id: "nere",
            name: "Néré",
            line: Lang.t("Un océan sous la brume."),
            skyTop: "#0e2a3a",
            skyMid: "#2a7f86",
            skyLow: "#b9e5d3",
            terrain: ["#3f9089", "#2a6a70", "#1a4a55", "#0e2c3a"],
            light: "#c8fff0"
        },
        {
            id: "ocre",
            name: "Ocre",
            line: Lang.t("La poussière et la lumière."),
            skyTop: "#3a4a43",
            skyMid: "#b59a3c",
            skyLow: "#ecdca0",
            terrain: ["#8a7a35", "#5f5a2e", "#3f4227", "#22281b"],
            light: "#fff0b0"
        },
        {
            id: "vesper",
            name: "Vesper",
            line: Lang.t("La nuit a déjà commencé."),
            skyTop: "#15102e",
            skyMid: "#6b3f9e",
            skyLow: "#e59ac0",
            terrain: ["#7a3f8a", "#54306e", "#382352", "#1c1430"],
            light: "#ffc8e6"
        }
    ]

    // Справжній день і ніч: поворот планети (spin у shaders/planet.frag) такий, щоб під сонцем
    // шейдера була та довгота, де зараз полудень. Шейдер показує в точці з кутом φ = atan(n.x, n.z)
    // довготу φ + spin, сонце стоїть під φ = atan2(SUN.x, SUN.z), тож spin = λ_полудня − φ_сонця.
    // Земля -- за UTC, Марс -- за марсіанським середнім часом MTC (як Mars24 у NASA), обидва
    // без «рівняння часу» (кілька градусів). Решта -- справжня тривалість сонячної доби від J2000,
    // але меридіан умовний: газові гіганти не мають твердої поверхні, Меркурій і Венера ледь рухаються.
    readonly property real sunPhi: Math.atan2(-0.78, 0.58) // має збігатися з SUN у shaders/planet.frag
    readonly property var solarDayHours: ({ sun: 25.38 * 24, belt: 9.074, mercury: 175.94 * 24, venus: -116.75 * 24, jupiter: 9.925, saturn: 10.656, uranus: -17.24, neptune: 16.11 })

    function spinAt(id, ms) {
        const deg = Math.PI / 180;
        let noon; // довгота (схід +), де сонце в зеніті
        if (id === "earth") {
            const utc = ((ms / 3600000) % 24 + 24) % 24;
            noon = (12 - utc) * 15 * deg;
        } else if (id === "mars") {
            const jdTT = ms / 86400000 + 2440587.5 + 69.184 / 86400;
            const msd = (jdTT - 2405522.0028779) / 1.0274912517; // марсіанська сонячна доба
            const mtc = 24 * (msd - Math.floor(msd));
            noon = (12 - mtc) * 15 * deg;
        } else if (solarDayHours[id] !== undefined) {
            const hours = (ms - Date.UTC(2000, 0, 1, 12)) / 3600000;
            noon = -2 * Math.PI * hours / solarDayHours[id];
        } else {
            return 0;
        }
        const s = (noon - sunPhi) % (2 * Math.PI);
        return s < 0 ? s + 2 * Math.PI : s;
    }

    // Пора року: широта, над якою сонце в зеніті (shaders/planet.frag, sunLat). Земля -- схилення
    // Сонця за датою, Марс -- Ls за алгоритмом Mars24, гіганти -- від дат рівнодень з їхнім роком,
    // решта -- нахил осі мізерний. Без цього межа дня й ночі завжди мала той самий нахил.
    function sunLatAt(id, ms) {
        const deg = Math.PI / 180;
        const d = ms / 86400000 + 2440587.5 - 2451545.0; // доби від J2000
        if (id === "earth") {
            const g = (357.528 + 0.9856003 * d) * deg;
            const lambda = (280.460 + 0.9856474 * d) * deg + (1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * deg;
            return Math.asin(Math.sin(23.44 * deg) * Math.sin(lambda));
        }
        if (id === "mars") {
            const dt = d + 69.184 / 86400;
            const m = (19.3871 + 0.52402073 * dt) * deg;
            const ls = (270.3871 + 0.524038496 * dt) * deg + (10.691 * Math.sin(m) + 0.623 * Math.sin(2 * m) + 0.050 * Math.sin(3 * m)) * deg;
            return Math.asin(0.42565 * Math.sin(ls)) + 0.25 * deg * Math.sin(ls);
        }
        // [нахил осі, рівнодення весни північної півкулі (Ls = 0), рік у земних роках]
        const giants = { saturn: [26.73, Date.UTC(2009, 7, 11), 29.457], uranus: [97.77, Date.UTC(2007, 11, 7), 84.02], neptune: [28.32, Date.UTC(1881, 2, 1), 164.8] };
        const g = giants[id];
        if (!g)
            return 0;
        const ls = 2 * Math.PI * (ms - g[1]) / (g[2] * 365.25 * 86400000);
        return Math.asin(Math.sin(g[0] * deg) * Math.sin(ls));
    }

    function find(id) {
        return all.concat(deep).find(planet => planet.id === id) ?? all[0];
    }
}
