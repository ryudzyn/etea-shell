import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services

// Довідка про планету поточного столу. У темі "Пейзажі" -- про поверхню, на якій стоїш,
// з живим рядком у такт із шейдером (викид на Сонці, Іо на диску Юпітера, комета).
Column {
    id: root

    property real sky: 1080
    property var options: ({})
    readonly property var spec: Theme.planet
    readonly property var facts: spec.facts ?? {}
    readonly property var surface: spec.surface ?? null
    readonly property int page: Hyprland.focusedWorkspace?.id ?? 1

    // Той самий час, що бачить шейдер; цілі секунди, щоб текст не перебудовувався щокадру
    readonly property int second: Math.floor(Planet.deepTime)
    readonly property int scene: Planets.pages.indexOf(Theme.pageBody)

    function mmss(seconds) {
        const s = Math.max(0, Math.round(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function fract(v) {
        return v - Math.floor(v);
    }
    // Формули дзеркалять landscape.frag у nebula-config: змінив там -- зміни й тут
    readonly property string event: {
        const t = second;
        switch (surface?.event) {
        case "eruption": {
            const ph = fract(t / 90);
            return ph < 0.55 ? "викид через " + mmss((0.55 - ph) * 90) : "викид триває";
        }
        case "io": {
            const ph = fract(t / 300);
            return ph < 0.5 ? "Іо перед Юпітером ще " + mmss((0.5 - ph) * 300) : "Іо за Юпітером ще " + mmss((1 - ph) * 300);
        }
        case "comet": {
            const ph = fract(t / 420 + scene * 0.29);
            return ph > 0.155 && ph < 0.845 ? "комета в небі" : "комета через " + mmss((ph < 0.155 ? 0.155 - ph : 1.155 - ph) * 420);
        }
        }
        return "";
    }

    width: sky * 0.22
    visible: !spec.deep || surface !== null
    spacing: sky * 0.006

    ObsHeader {
        text: String(root.page).padStart(2, "0") + " · " + (root.surface ? root.surface.name : root.spec.name).toUpperCase()
        sky: root.sky
    }

    // Звичайні планети
    Column {
        width: parent.width
        spacing: root.sky * 0.006
        visible: root.surface === null

        ObsRow { label: "РАДІУС"; value: root.facts.radius ?? "—"; sky: root.sky }
        ObsRow { label: "ДОБА"; value: root.facts.day ?? "—"; sky: root.sky }
        ObsRow { label: "РІК"; value: root.facts.year ?? "—"; sky: root.sky }
        ObsRow { label: "ВІД СОНЦЯ"; value: root.spec.line ?? "—"; sky: root.sky }
        ObsRow { label: "НАХИЛ ОСІ"; value: root.facts.tilt ?? "—"; sky: root.sky }
    }

    // Поверхня
    Column {
        width: parent.width
        spacing: root.sky * 0.006
        visible: root.surface !== null

        ObsRow { label: "МІСЦЕ"; value: root.surface?.where ?? "—"; sky: root.sky }
        ObsRow { label: "ТЕМПЕРАТУРА"; value: root.surface?.temp ?? "—"; sky: root.sky }
        ObsRow { label: "ТЯЖІННЯ"; value: root.surface?.g ?? "—"; sky: root.sky }
        ObsRow { label: "ДОБА"; value: root.surface?.day ?? "—"; sky: root.sky }
        ObsRow { label: "НЕБО"; value: root.surface?.sky ?? "—"; sky: root.sky }

        // Живий рядок: маленька зірка, що дихає, і що зараз відбувається
        Row {
            visible: root.event !== ""
            spacing: root.sky * 0.006
            topPadding: root.sky * 0.004

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.sky * 0.005
                height: width
                radius: width / 2
                color: Theme.windowLit
                SequentialAnimation on opacity {
                    running: root.visible && Planet.pageEmpty
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: root.event.toUpperCase()
                color: Theme.windowLit
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0115
                font.letterSpacing: root.sky * 0.0012
            }
        }
    }
}
