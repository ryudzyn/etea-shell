import QtQuick

// Melts whatever it's applied to away towards the bottom, like the bars behind the hills.
ShaderEffect {
    property real from: 0.3 // where it starts to fade, as a share of the height
    property real to: 0.84 // where nothing is left

}
