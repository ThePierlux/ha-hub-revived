import QtQuick
import org.kde.kirigami as Kirigami

// The rounded plate an entity's glyph sits in.
//
// It answers to the states a row cares about - on, unavailable, clickable -
// and leaves the question of which glyph, and from where, to EntityIcon: the
// same glyph in the same plate, whether it came from Home Assistant's own icon,
// from the icon theme or from the files this widget bundles.
Rectangle {
    id: badge

    property string iconKind: "asset"
    property string icon: "device"
    property bool active: false
    property bool unavailable: false
    property real iconSize: Kirigami.Units.iconSizes.small
    property bool circular: false
    property bool interactive: false
    // soft: translucent tint when active (glass cards) instead of a solid fill
    property bool soft: false
    // Tiles read these two to move their own shadow; the plate owns the mouse,
    // so nobody else can report the hover.
    readonly property bool hovered: iconMouse.containsMouse
    readonly property bool pressed: iconMouse.pressed
    signal clicked()

    implicitWidth: Math.round(iconSize * 1.9)
    implicitHeight: implicitWidth
    radius: circular ? width / 2 : Math.round(width * 0.3)

    color: {
        if (unavailable) return Qt.alpha(Kirigami.Theme.disabledTextColor, 0.10);
        if (active && soft) return Qt.alpha(Kirigami.Theme.highlightColor, iconMouse.containsMouse ? 0.36 : 0.24);
        if (active) return iconMouse.containsMouse ? Qt.lighter(Kirigami.Theme.highlightColor, 1.15) : Kirigami.Theme.highlightColor;
        return Qt.alpha(Kirigami.Theme.textColor, iconMouse.containsMouse ? 0.14 : 0.07);
    }
    border.width: 0
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    EntityIcon {
        anchors.centerIn: parent
        iconKind: badge.iconKind
        icon: badge.icon
        size: badge.iconSize
        color: badge.unavailable ? Kirigami.Theme.disabledTextColor
             : badge.active ? (badge.soft ? Kirigami.Theme.highlightColor : Kirigami.Theme.highlightedTextColor)
             : Kirigami.Theme.textColor
        opacity: badge.active || badge.unavailable ? 1.0 : 0.75
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        enabled: badge.interactive && !badge.unavailable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: badge.clicked()
    }
}
