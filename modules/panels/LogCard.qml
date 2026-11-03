import QtQuick
import qs.config

// A quiet card for the logbook, lighter than the panel's own porthole.
Rectangle {
    radius: 0
    color: Qt.alpha(Theme.windowLit, 0.06)
    border.width: 1
    border.color: Qt.alpha(Theme.windowLit, 0.14)
}
