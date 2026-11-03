import QtQuick
import qs.config
import qs.services

// Телеметрія: сегментні шкали й числа, а не метафори.
Column {
    id: root

    property real sky: 1080
    property var options: ({})

    // Числа тримаються нерухомо за вікнами, щоб не будити GPU
    property var snap: ({ cpu: 0, memory: 0, download: 0, upload: 0, temperature: 0 })

    Binding on snap {
        when: Planet.pageEmpty || root.snap.cpu === 0
        value: ({ cpu: Machine.cpu, memory: Machine.memory, download: Machine.download, upload: Machine.upload, temperature: Machine.temperature })
        restoreMode: Binding.RestoreNone
    }

    width: sky * 0.26
    spacing: sky * 0.01

    ObsHeader {
        text: "ТЕЛЕМЕТРІЯ"
        sky: root.sky
    }

    Repeater {
        model: [
            { label: "CPU", part: root.snap.cpu, value: (root.snap.cpu * 100).toFixed(1) + " %" },
            { label: "MEM", part: root.snap.memory, value: (root.snap.memory * 100).toFixed(1) + " %" },
            { label: "TEMP", part: Math.min(1, root.snap.temperature / 100), value: Math.round(root.snap.temperature) + " °C" }
        ]

        Column {
            required property var modelData
            width: parent.width
            spacing: root.sky * 0.004

            ObsRow {
                label: parent.modelData.label
                value: parent.modelData.value
                sky: root.sky
            }

            Row {
                id: cells
                readonly property var reading: parent.modelData
                width: parent.width
                spacing: 2

                Repeater {
                    model: 30
                    Rectangle {
                        required property int index
                        width: (cells.width - 29 * 2) / 30
                        height: root.sky * 0.0065
                        color: (index + 0.5) / 30 < cells.reading.part ? Theme.skyInk : Qt.alpha(Theme.skyInk, 0.12)
                    }
                }
            }
        }
    }

    ObsRow {
        label: "NET"
        value: "↓ " + Machine.rate(root.snap.download) + "   ↑ " + Machine.rate(root.snap.upload)
        sky: root.sky
    }
}
