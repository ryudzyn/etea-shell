import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.modules.widgets
import qs.services

// Stack the sky, the decorations, the widgets, then the terrain so it sits in front.
Item {
    id: root

    property real angle: 0 // how far the planet has turned
    property real radius: Theme.terrainCurve // shrink it and the ground becomes a planet
    property real horizon: 1 - Theme.terrainHeight
    property real space: 0
    property real groundOpacity: 1
    property bool showWidgets: true
    property bool interactive: false // only the real desktop answers the pointer
    // Keep the sky and the ground as pictures while they hold still, so a widget moving in
    // front doesn't make the GPU paint them again pixel by pixel. Off where they move every frame.
    property bool cached: true

    // Four sound levels at a time, the way the shader wants them
    function bands(first) {
        const levels = Beat.shown;
        return Qt.vector4d(levels[first] ?? 0, levels[first + 1] ?? 0, levels[first + 2] ?? 0, levels[first + 3] ?? 0);
    }

    ShaderEffect {
        anchors.fill: parent

        property color colorTop: Theme.skyTop
        property color colorMid: Theme.skyMid
        property color colorLow: Theme.skyLow
        property vector2d resolution: Qt.vector2d(width, height)
        property real grain: Theme.grain
        property real space: root.space

        layer.enabled: root.cached
        fragmentShader: Qt.resolvedUrl("../../shaders/sky.frag.qsb")
    }

    // Планета цього столу, що висить у космосі. Гори лишились лише для орбіти.
    // Усі текстури завантажені наперед, тож переліт не смикається на декодуванні.
    Repeater {
        id: surfaces
        model: Planets.solar
        Image {
            required property var modelData
            readonly property bool live: modelData === "earth" && root.liveEarth
            visible: false
            mipmap: true
            cache: !live
            // «#версія» лише змушує перечитати той самий файл, коли він оновився
            source: live ? "file://" + root.livePath + "#" + root.liveVersion
                         : "file://" + Quickshell.shellPath("assets/planets/" + Planets.find(modelData).texture)
        }
    }

    // Жива Земля: супутникові хмари поверх Blue Marble (clouds.matteason.co.uk, CC0, дані EUMETSAT),
    // свіжа картинка щогодини -- її кладе сюди окрема служба (nebula-config: crew/etea, etea-live-earth).
    // Немає файлу чи мережі -- лишається звичайна Земля з хмарами, що пливуть.
    readonly property string livePath: Quickshell.env("HOME") + "/.cache/etea/earth-live.jpg"
    property bool liveEarth: false
    property int liveVersion: 0
    FileView {
        path: root.livePath
        watchChanges: true
        onLoaded: {
            root.liveEarth = true;
            root.liveVersion++;
        }
        onLoadFailed: root.liveEarth = false
        onFileChanged: reload()
    }
    Image {
        id: ringImage
        visible: false
        source: "file://" + Quickshell.shellPath("assets/planets/2k_saturn_ring_alpha.png")
    }

    Image {
        id: cloudImage
        visible: false
        mipmap: true
        source: "file://" + Quickshell.shellPath("assets/planets/2k_earth_clouds.jpg")
    }

    readonly property int page: Hyprland.focusedWorkspace?.id ?? 1
    property int leaving: page
    property int arriving: page
    property real direction: 1
    property real flight: 1 // 0 щойно вилетіли, 1 прибули
    readonly property real farOpacity: 1 - Math.min(1, space * 3)

    onPageChanged: {
        if (page === arriving)
            return;
        leaving = arriving;
        arriving = page;
        direction = page > leaving ? 1 : -1;
        flightAnim.restart();
    }

    NumberAnimation {
        id: flightAnim
        target: root
        property: "flight"
        from: 0
        to: 1
        duration: root.interactive ? 800 * Theme.pace : 0
        easing.type: Easing.InOutCubic
    }

    component PlanetLayer: ShaderEffect {
        required property int forPage
        property real centreX: root.width * 0.55
        property real centreY: root.height * 0.52
        property real scale_: 1
        readonly property var spec: Planets.find(Planets.forPage(forPage))

        anchors.fill: parent
        opacity: root.farOpacity
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d centre: Qt.vector2d(centreX, centreY)
        property real radius: root.height * (spec.size ?? 0.26) * scale_
        property real spin: Planets.spinAt(spec.id, root.now)
        property real sunLat: Planets.sunLatAt(spec.id, root.now)
        property real tilt: spec.tilt ?? 0
        property real hasRing: spec.ring ? 1 : 0
        property real hasClouds: spec.clouds && !(spec.id === "earth" && root.liveEarth) ? 1 : 0 // у живій Землі хмари вже є
        property var cloudMap: cloudImage
        property real mode: 1
        property real drift: 0
        property color rim: spec.light
        property var surface: surfaces.itemAt(Planets.solar.indexOf(spec.id)) ?? ringImage // у Сонця й поясу текстур немає
        property var ringMap: ringImage
        property real kind: spec.kind ?? 0

        fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
    }

    // Тема "Глибокий космос": шейдер замість планети, 30 кадрів на секунду, за вікнами
    // час стоїть, тож GPU відпочиває
    readonly property string deep: Config.deepSpace
    readonly property var deepSpec: Planets.deep.find(entry => entry.id === root.deep) ?? null
    readonly property string deepVideo: deepSpec?.video ?? ""
    // "Пейзажі": один шейдер на всі столи, а сцену (поверхню тіла цього столу) задає uniform scene
    readonly property bool deepPerPage: deepSpec?.perPage ?? false

    component DeepLayer: ShaderEffect {
        property int forPage: root.arriving

        anchors.fill: parent

        property real time: Planet.deepTime
        property real camOffset: Config.deepAngle
        property vector2d resolution: Qt.vector2d(width, height)
        property real scene: Math.max(0, Planets.pages.indexOf(Planets.forPage(forPage)))

        Behavior on camOffset {
            NumberAnimation { duration: 1400; easing.type: Easing.InOutCubic }
        }

        fragmentShader: root.deep && !root.deepVideo ? Qt.resolvedUrl("../../shaders/deep-" + root.deep + ".frag.qsb") : ""
    }
    // Пейзаж столу, з якого пішли: лежить під новим, поки той проступає
    DeepLayer {
        forPage: root.leaving
        visible: root.deepPerPage && root.deepVideo === "" && root.flight < 1 && root.farOpacity > 0
        opacity: root.farOpacity
    }
    DeepLayer {
        forPage: root.arriving
        visible: root.deep !== "" && root.deepVideo === "" && root.farOpacity > 0
        opacity: root.farOpacity * (root.deepPerPage ? root.flight : 1)
    }
    // Відео-тема: окремий файл, щоб без QtMultimedia ламалось лише відео, а не весь фон.
    // Лише на справжньому столі (один декодер), за вікнами на паузі, як і шейдери.
    Loader {
        anchors.fill: parent
        active: root.interactive && root.deepVideo !== ""
        opacity: root.farOpacity
        source: "DeepVideo.qml"
        onLoaded: {
            item.source = Qt.binding(() => "file://" + Quickshell.shellPath("assets/video/" + root.deepVideo));
            item.playing = Qt.binding(() => Planet.pageEmpty && root.visible);
        }
    }
    // Зорі шейдерів яскраві: за колонками віджетів трохи затемнюємо, щоб текст читався
    Repeater {
        model: root.deep !== "" ? [{ left: true }, { left: false }] : []
        Rectangle {
            required property var modelData
            x: modelData.left ? 0 : root.width - width
            width: root.width * (root.deepPerPage ? 0.3 : 0.24)
            height: root.height
            opacity: root.farOpacity
            // У пейзажах світлі сцени: тінь слабша й сходить поступово, без видимого краю
            readonly property real edgeDark: root.deepPerPage ? 0.62 : 0.78
            readonly property real midDark: root.deepPerPage ? 0.34 : 0.66
            readonly property real midAt: root.deepPerPage ? 0.45 : 0.72
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, modelData.left ? edgeDark : 0) }
                GradientStop { position: modelData.left ? midAt : 1 - midAt; color: Qt.rgba(0, 0, 0, midDark) }
                GradientStop { position: modelData.left ? 0.8 : 0.2; color: Qt.rgba(0, 0, 0, midDark * (root.deepPerPage ? 0.25 : 0.714)) } // без пейзажів -- та сама пряма, що й раніше
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, modelData.left ? 0 : edgeDark) }
            }
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.interactive && root.deep !== "" && root.deepVideo === "" && Planet.pageEmpty && root.visible
        onTriggered: Planet.deepTime += 0.033
    }

    // Зорі
    ShaderEffect {
        anchors.fill: parent
        opacity: root.farOpacity
        visible: opacity > 0 && root.deep === ""
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d centre: Qt.vector2d(0, 0)
        property real radius: 0
        property real spin: 0
        property real tilt: 0
        property real hasRing: 0
        property real hasClouds: 0
        property var cloudMap: ringImage
        property real mode: 0
        property real drift: root.arriving * 240 + root.direction * -240 * (1 - root.flight)
        property color rim: "#000000"
        property var surface: ringImage
        property var ringMap: ringImage
        property real kind: 0

        fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
    }

    // Планета, до якої летимо: перспектива, спершу цятка вдалині, потім наближається
    PlanetLayer {
        forPage: root.arriving
        visible: root.farOpacity > 0 && root.deep === ""
        centreX: root.width * 0.55 + root.direction * root.width * 0.1 * (1 - root.flight)
        scale_: 1 / (1 + 30 * (1 - root.flight) * (1 - root.flight))
    }

    // Планета, яку лишаємо: камера пролітає повз, вона росте і йде за край екрана. Іде після
    // тієї, до якої летимо: вона ближче, тож мусить бути зверху (інакше далека налазить на неї)
    PlanetLayer {
        forPage: root.leaving
        visible: root.flight < 1 && root.farOpacity > 0 && root.deep === ""
        centreX: root.width * 0.55 - root.direction * root.width * 1.35 * root.flight
        centreY: root.height * 0.52 + root.height * 0.1 * root.flight
        scale_: 1 + 1.8 * root.flight
    }

    // Планети показують справжній день і ніч (Planets.spinAt): поворот рахується з годинника.
    // Земля зсувається на 0.25° за хвилину, тож раз на 20 с досить -- GPU майже не працює
    property real now: Date.now()
    Timer {
        interval: 20000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    // Спектр музики: деформовані кільця навколо планети, у її ж нахилі
    ShaderEffect {
        readonly property var spec: Planets.find(Planets.forPage(root.arriving))
        readonly property real planetRadius: root.height * (spec.size ?? 0.26)

        anchors.fill: parent
        visible: root.interactive && Beat.dancing && root.farOpacity > 0 && root.flight > 0.85 && root.deep === ""
        opacity: (root.flight - 0.85) / 0.15 * root.farOpacity

        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d centre: Qt.vector2d(root.width * 0.55, root.height * 0.52)
        property real radius: planetRadius
        property real tilt: spec.tilt ?? 0
        property real inner: spec.ring ? 2.42 : 1.32
        property real amount: 0.42
        property color tint: spec.light
        property vector4d l0: root.bands(0)
        property vector4d l1: root.bands(4)
        property vector4d l2: root.bands(8)
        property vector4d l3: root.bands(12)
        property vector4d l4: root.bands(16)
        property vector4d l5: root.bands(20)
        property vector4d l6: root.bands(24)

        fragmentShader: Qt.resolvedUrl("../../shaders/spectrum.frag.qsb")
    }

    // Everyone's own images, placed by proportion so they fit on any screen
    Repeater {
        model: Config.decorations

        Image {
            required property var modelData

            source: "file://" + Quickshell.shellPath("decorations/" + modelData.file)
            x: modelData.x * root.width - width / 2
            y: modelData.y * root.height - height / 2
            width: modelData.width * root.width
            height: width * (implicitHeight / Math.max(1, implicitWidth))
            sourceSize.width: width
            fillMode: Image.PreserveAspectFit
            opacity: modelData.opacity ?? 1
            rotation: modelData.rotation ?? 0
            smooth: true
        }
    }

    // Погода -- за віджетами (текст читається) і за рельєфом (дощ іде з неба)
    ShaderEffect {
        anchors.fill: parent
        opacity: 1 - Math.min(1, root.space * 3)
        visible: root.weatherOn && opacity > 0
        property vector2d resolution: Qt.vector2d(width, height)
        property real time: root.weatherTime
        property real rain: root.fx.rain
        property real snow: root.fx.snow
        property real fog: root.fx.fog
        property real flash: root.flash
        property real horizon: root.horizon
        fragmentShader: Qt.resolvedUrl("../../shaders/weather.frag.qsb")
        Component.onCompleted: {
            if (root.interactive)
                Weather.join(); // служба питає погоду, лише коли хтось її хоче
        }
    }

    Widgets {
        anchors.fill: parent
        interactive: root.interactive
        opacity: 1 - root.space * 3
        visible: root.showWidgets && opacity > 0
    }

    ShaderEffect {
        anchors.fill: parent

        opacity: root.groundOpacity * Math.min(1, root.space * 3)
        visible: opacity > 0

        // planetAngle is what will spin the planet between pages
        property color layer0: Theme.terrainLayers[0]
        property color layer1: Theme.terrainLayers[1]
        property color layer2: Theme.terrainLayers[2]
        property color layer3: Theme.terrainLayers[3]
        property vector2d resolution: Qt.vector2d(width, height)
        property real horizon: root.horizon
        property real relief: Theme.terrainRelief
        property real curve: root.radius
        property real planetAngle: root.angle
        property real orbit: root.space
        property color rimColor: Theme.skyLow
        property vector4d l0: root.bands(0)
        property vector4d l1: root.bands(4)
        property vector4d l2: root.bands(8)
        property vector4d l3: root.bands(12)
        property vector4d l4: root.bands(16)
        property vector4d l5: root.bands(20)
        property vector4d l6: root.bands(24)
        property real music: Beat.dancing && Beat.shown.length ? 1 : 0
        property real lift: Theme.groundLift
        property real bars: Config.groundMusic === "bars" ? 1 : 0

        Behavior on music {
            NumberAnimation { duration: 1800; easing.type: Easing.InOutSine }
        }
        property real grain: Theme.grain

        layer.enabled: root.cached && music === 0
        fragmentShader: Qt.resolvedUrl("../../shaders/terrain.frag.qsb")
    }

    // Погода за вікном (shaders/weather.frag): дощ, сніг, туман і гроза за кодом open-meteo з
    // Weather.qml (місто -- з віджета погоди, без нього -- приблизно за IP). Анімація йде лише
    // на порожньому столі. Перевірити без справжньої погоди: echo 65 > ~/.cache/etea/weather-test
    // (61-65 дощ, 71-75 сніг, 45 туман, 95 гроза; видалити файл -- знову справжня).
    readonly property int weatherCode: weatherTest.code >= 0 ? weatherTest.code : (Weather.known ? Weather.code : 0)
    readonly property var fx: weatherFx(weatherCode)
    function weatherFx(c) {
        let rain = 0, snow = 0, fog = 0, storm = false;
        if (c === 45 || c === 48)
            fog = 0.7;
        else if (c >= 51 && c <= 57)
            rain = c >= 55 ? 0.35 : 0.2;
        else if (c === 61 || c === 80)
            rain = 0.45;
        else if (c === 63 || c === 81 || c === 66)
            rain = 0.7;
        else if (c === 65 || c === 82 || c === 67)
            rain = 1.0;
        else if (c === 71 || c === 77)
            snow = 0.4;
        else if (c === 73 || c === 85)
            snow = 0.7;
        else if (c === 75 || c === 86)
            snow = 1.0;
        else if (c >= 95) {
            rain = 1.0;
            storm = true;
        }
        return { rain: rain, snow: snow, fog: fog, storm: storm };
    }
    readonly property bool weatherOn: interactive && deep === "" && fx.rain + fx.snow + fx.fog > 0
    property real weatherTime: 0
    property real flash: 0

    Timer {
        interval: 33
        repeat: true
        running: root.weatherOn && Planet.pageEmpty && root.visible
        onTriggered: {
            root.weatherTime += 0.033;
            if (root.fx.storm && !flashAnim.running && Math.random() < 0.004)
                flashAnim.restart();
        }
    }
    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: root; property: "flash"; to: 1; duration: 60 }
        NumberAnimation { target: root; property: "flash"; to: 0.15; duration: 140 }
        NumberAnimation { target: root; property: "flash"; to: 0.8; duration: 70 }
        NumberAnimation { target: root; property: "flash"; to: 0; duration: 700 }
    }

    FileView {
        id: weatherTest
        property int code: -1
        path: Quickshell.env("HOME") + "/.cache/etea/weather-test"
        watchChanges: true
        onLoaded: {
            const n = parseInt(text().trim());
            code = n >= 0 ? n : -1;
        }
        onLoadFailed: code = -1
        onFileChanged: reload()
    }
}
