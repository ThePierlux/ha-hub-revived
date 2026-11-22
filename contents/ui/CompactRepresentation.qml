import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot

    property var haManager: null
    signal clicked()

    // The icon Settings -> Appearance asks for. Both empty means "follow the
    // connection", which is also what the fallback modes resolve to.
    property string preferredIconName: ""
    property string preferredImagePath: ""

    readonly property bool isOnline: haManager && haManager.isConnected

    readonly property string imageSource: {
        if (compactRoot.preferredImagePath.length === 0) return "";
        var path = compactRoot.preferredImagePath;
        return path.indexOf("file:") === 0 ? path : "file://" + path;
    }

    readonly property real sideLength: {
        if (!parent) return Kirigami.Units.iconSizes.medium;
        var pWidth = parent.width > 0 ? parent.width : Kirigami.Units.iconSizes.medium;
        var pHeight = parent.height > 0 ? parent.height : Kirigami.Units.iconSizes.medium;
        return Math.min(pWidth, pHeight);
    }

    Layout.preferredWidth: sideLength
    Layout.preferredHeight: sideLength
    Layout.minimumWidth: Kirigami.Units.iconSizes.small
    Layout.minimumHeight: Kirigami.Units.iconSizes.small

    // The panel asks for a fixed icon size; filling the item instead makes the
    // glyph jump in size as the panel is resized.
    Kirigami.Icon {
        objectName: "trayThemedIcon"
        anchors.centerIn: parent
        visible: compactRoot.imageSource.length === 0
        source: compactRoot.preferredIconName.length > 0
            ? compactRoot.preferredIconName
            : (compactRoot.isOnline ? Qt.resolvedUrl("../icons/home.svg") : "network-offline")
        isMask: compactRoot.preferredIconName.length > 0
        color: Kirigami.Theme.textColor
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium
        opacity: compactRoot.isOnline ? 1.0 : 0.6
    }

    // A picture cannot be recoloured by the theme, so the offline state is
    // shown by dimming it the same way.
    Image {
        id: pictureImage
        objectName: "trayPicture"
        anchors.centerIn: parent
        // Named so tests can observe the load state: under qmltestrunner no
        // item ever reports visible == true, so the flag has to be checked.
        readonly property bool loaded: status === Image.Ready
        visible: compactRoot.imageSource.length > 0 && loaded
        source: compactRoot.imageSource
        sourceSize.width: Kirigami.Units.iconSizes.smallMedium * 2
        sourceSize.height: Kirigami.Units.iconSizes.smallMedium * 2
        width: Kirigami.Units.iconSizes.smallMedium
        height: Kirigami.Units.iconSizes.smallMedium
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: compactRoot.isOnline ? 1.0 : 0.6
    }

    // Small red dot when disconnected
    Rectangle {
        visible: !compactRoot.isOnline
        width: Math.max(6, Math.round(compactRoot.sideLength * 0.25))
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(compactRoot.sideLength * 0.08)
        color: Kirigami.Theme.negativeTextColor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: compactRoot.clicked()
    }
}
