pragma Singleton

import QtQuick
import Quickshell

// The worlds you can live on. A theme is a planet, and a planet is just these few values,
// so adding one means adding one entry here.
Singleton {
    readonly property var all: builtIn.concat(Config.customPlanets)

    // Кожен робочий стіл -- своя планета, за порядком від Сонця
    readonly property var solar: ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]

    // Тема "Глибокий космос": шпалери-шейдери замість планет, спільні для всіх столів
    readonly property var deep: [
        { id: "blackhole", deep: true, name: "Чорна діра", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#e8b27a" },
        { id: "blackhole-gargantua", deep: true, name: "Гаргантюа", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#f0c98a" },
        { id: "galaxy", deep: true, name: "Галактика", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#b7a6e8" },
        { id: "nebula-dust", deep: true, name: "Туманність", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#d88ab0" },
        { id: "pulsar", deep: true, name: "Пульсар", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#8fc7e8" },
        { id: "wormhole", deep: true, name: "Кротовина", line: "Глибокий космос", skyTop: "#030406", skyMid: "#0a0c10", skyLow: "#14181e", terrain: ["#14181e", "#0e1115", "#090b0e", "#040506"], light: "#9fd6c8" }
    ]

    function forPage(page) {
        return solar[(Math.max(page, 1) - 1) % solar.length];
    }

    readonly property var builtIn: [
        { id: "mercury", facts: { radius: "2 439.7 км", day: "58.6 д", year: "88.0 д", tilt: "0.03°" }, texture: "2k_mercury.jpg", size: 0.2, tilt: 0.0, name: "Меркурій", line: "0.39 а.о.", skyTop: "#040405", skyMid: "#0e0d0c", skyLow: "#23201d", terrain: ["#26231f", "#1a1815", "#100f0d", "#070606"], light: "#b8b0a6" },
        { id: "venus", facts: { radius: "6 051.8 км", day: "243 д (ретр.)", year: "224.7 д", tilt: "177.4°" }, texture: "2k_venus_atmosphere.jpg", size: 0.27, tilt: 0.05, name: "Венера", line: "0.72 а.о.", skyTop: "#050403", skyMid: "#14100a", skyLow: "#2e2414", terrain: ["#2b2214", "#1d170e", "#120e08", "#080604"], light: "#e0c388" },
        { id: "earth", facts: { radius: "6 371 км", day: "23 г 56 хв", year: "365.25 д", tilt: "23.4°" }, texture: "2k_earth_daymap.jpg", clouds: true, size: 0.29, tilt: -0.41, name: "Земля", line: "1.00 а.о.", skyTop: "#030406", skyMid: "#0a1119", skyLow: "#162636", terrain: ["#172635", "#101a25", "#0a1118", "#05080c"], light: "#7fb2d9" },
        { id: "mars", facts: { radius: "3 389.5 км", day: "24 г 37 хв", year: "687 д", tilt: "25.2°" }, texture: "2k_mars.jpg", size: 0.24, tilt: -0.44, name: "Марс", line: "1.52 а.о.", skyTop: "#050303", skyMid: "#160b08", skyLow: "#32170f", terrain: ["#2f1810", "#20100b", "#140a07", "#090504"], light: "#d97050" },
        { id: "jupiter", facts: { radius: "69 911 км", day: "9 г 56 хв", year: "11.86 р", tilt: "3.1°" }, texture: "2k_jupiter.jpg", size: 0.33, tilt: -0.05, name: "Юпітер", line: "5.20 а.о.", skyTop: "#050403", skyMid: "#140f0a", skyLow: "#2e2216", terrain: ["#2c2116", "#1e160f", "#130e09", "#080604"], light: "#d6a878" },
        { id: "saturn", facts: { radius: "58 232 км", day: "10 г 33 хв", year: "29.46 р", tilt: "26.7°" }, texture: "2k_saturn.jpg", size: 0.19, tilt: -0.3, ring: true, name: "Сатурн", line: "9.58 а.о.", skyTop: "#050404", skyMid: "#13110c", skyLow: "#2c2619", terrain: ["#2a2418", "#1c1810", "#120f0a", "#080705"], light: "#dcc898" },
        { id: "uranus", facts: { radius: "25 362 км", day: "17 г 14 хв", year: "84.0 р", tilt: "97.8°" }, texture: "2k_uranus.jpg", size: 0.28, tilt: 1.2, name: "Уран", line: "19.2 а.о.", skyTop: "#030505", skyMid: "#0a1415", skyLow: "#162b2e", terrain: ["#172b2e", "#0f1d1f", "#0a1314", "#050909"], light: "#9fd6dc" },
        { id: "neptune", facts: { radius: "24 622 км", day: "16 г 06 хв", year: "164.8 р", tilt: "28.3°" }, texture: "2k_neptune.jpg", size: 0.28, tilt: -0.49, name: "Нептун", line: "30.1 а.о.", skyTop: "#030406", skyMid: "#0a0f1c", skyLow: "#141f3a", terrain: ["#152038", "#0e1626", "#090e18", "#04070c"], light: "#6f92d6" },
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

    function find(id) {
        return all.concat(deep).find(planet => planet.id === id) ?? all[0];
    }
}
