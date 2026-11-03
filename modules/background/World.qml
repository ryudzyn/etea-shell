import QtQuick
import Quickshell
import Quickshell.Hyprland
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
            visible: false
            mipmap: true
            source: "file://" + Quickshell.shellPath("assets/planets/" + Planets.find(modelData).texture)
        }
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
        property real spin: root.spin
        property real tilt: spec.tilt ?? 0
        property real hasRing: spec.ring ? 1 : 0
        property real hasClouds: spec.clouds ? 1 : 0
        property var cloudMap: cloudImage
        property real mode: 1
        property real drift: 0
        property color rim: spec.light
        property var surface: surfaces.itemAt(Planets.solar.indexOf(spec.id))
        property var ringMap: ringImage

        fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
    }

    // Тема "Глибокий космос": шейдер замість планети, 30 кадрів на секунду, за вікнами
    // час стоїть, тож GPU відпочиває
    readonly property string deep: Config.deepSpace
    ShaderEffect {
        anchors.fill: parent
        visible: root.deep !== "" && root.farOpacity > 0
        opacity: root.farOpacity

        property real time: Planet.deepTime
        property real camOffset: Config.deepAngle
        property vector2d resolution: Qt.vector2d(width, height)

        Behavior on camOffset {
            NumberAnimation { duration: 1400; easing.type: Easing.InOutCubic }
        }

        fragmentShader: root.deep ? Qt.resolvedUrl("../../shaders/deep-" + root.deep + ".frag.qsb") : ""
    }
    // Зорі шейдерів яскраві: за колонками віджетів трохи затемнюємо, щоб текст читався
    Repeater {
        model: root.deep !== "" ? [{ left: true }, { left: false }] : []
        Rectangle {
            required property var modelData
            x: modelData.left ? 0 : root.width - width
            width: root.width * 0.24
            height: root.height
            opacity: root.farOpacity
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, modelData.left ? 0.78 : 0) }
                GradientStop { position: modelData.left ? 0.72 : 0.28; color: Qt.rgba(0, 0, 0, 0.66) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, modelData.left ? 0 : 0.78) }
            }
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.interactive && root.deep !== "" && Planet.pageEmpty && root.visible
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

        fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
    }

    // Планета, яку лишаємо: камера пролітає повз, вона росте і йде за край екрана
    PlanetLayer {
        forPage: root.leaving
        visible: root.flight < 1 && root.farOpacity > 0 && root.deep === ""
        centreX: root.width * 0.55 - root.direction * root.width * 1.35 * root.flight
        centreY: root.height * 0.52 + root.height * 0.1 * root.flight
        scale_: 1 + 1.8 * root.flight
    }

    // Планета, до якої летимо: перспектива, спершу цятка вдалині, потім наближається
    PlanetLayer {
        forPage: root.arriving
        visible: root.farOpacity > 0 && root.deep === ""
        centreX: root.width * 0.55 + root.direction * root.width * 0.1 * (1 - root.flight)
        scale_: 1 / (1 + 30 * (1 - root.flight) * (1 - root.flight))
    }

    // Повний оберт за 10 хвилин, 15 кадрів на секунду і лише коли стіл порожній: інакше GPU відпочиває
    property real spin: 0
    Timer {
        interval: 66
        repeat: true
        running: root.interactive && Planet.pageEmpty && root.visible
        onTriggered: root.spin = (root.spin + 0.00069) % (Math.PI * 2)
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
}
