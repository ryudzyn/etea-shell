import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services

// Довідка про планету поточного столу.
Column {
    id: root

    property real sky: 1080
    property var options: ({})
    readonly property var spec: Theme.planet
    readonly property var facts: spec.facts ?? {}
    readonly property int page: Hyprland.focusedWorkspace?.id ?? 1

    width: sky * 0.22
    visible: !spec.deep
    spacing: sky * 0.006

    ObsHeader {
        text: String(root.page).padStart(2, "0") + " · " + root.spec.name.toUpperCase()
        sky: root.sky
    }

    ObsRow { label: "РАДІУС"; value: root.facts.radius ?? "—"; sky: root.sky }
    ObsRow { label: "ДОБА"; value: root.facts.day ?? "—"; sky: root.sky }
    ObsRow { label: "РІК"; value: root.facts.year ?? "—"; sky: root.sky }
    ObsRow { label: "ВІД СОНЦЯ"; value: root.spec.line ?? "—"; sky: root.sky }
    ObsRow { label: "НАХИЛ ОСІ"; value: root.facts.tilt ?? "—"; sky: root.sky }
}
