import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"
Item {
    id: headerView

    property var fullRoot: null
    property var haManager: null

    // One entity the user picked to be read off the header (Settings ->
    // Appearance): a binary sensor, a number, whatever answers. With the label
    // on, its name is shown as well as its value.
    property string headerEntityId: ""
    property bool headerEntityLabel: false

    // The person picked in Settings -> Appearance, greeted by the hour. Empty
    // without a person: the header then says what the server is called, which
    // is the more useful of the two answers when nobody was chosen.
    readonly property string greetingText: {
        var who = connected && haManager ? (haManager.primaryPersonName || "") : "";
        if (who.length === 0) return "";
        var hour = new Date().getHours();
        var greeting = Loc.t("Welcome");
        if (hour >= 5 && hour < 12) greeting = Loc.t("Good morning");
        else if (hour >= 12 && hour < 18) greeting = Loc.t("Good afternoon");
        else if (hour >= 18 && hour < 23) greeting = Loc.t("Good evening");
        else greeting = Loc.t("Good night");
        return greeting + ", " + who + "!";
    }

    // What the server is called, where it still fits: on the title line while
    // nobody is being greeted, next to the count once a greeting has taken it.
    readonly property bool greetingInTitle: headerView.greetingText.length > 0

    readonly property string personName: connected && haManager ? (haManager.primaryPersonName || "") : ""
    readonly property string pictureUrl: connected && haManager ? (haManager.primaryPersonPictureUrl || "") : ""

    readonly property string headerEntityText: {
        if (!connected || headerEntityId.length === 0) return "";
        return HAHelpers.getEntityHeaderValue(headerEntityId,
            haManager.getEntity(HAHelpers.cleanEntityId(headerEntityId)),
            haManager, Loc.language, headerEntityLabel);
    }

    signal configureRequested()
    signal toggleSearchRequested()
    signal viewModeSelected(string mode)

    readonly property bool connected: haManager && haManager.isConnected
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 15

    readonly property var viewModes: [
        { mode: "rows",  icon: "rows",  label: Loc.t("Rows") },
        { mode: "tiles", icon: "grid",  label: Loc.t("Tiles") },
        { mode: "cards", icon: "cards", label: Loc.t("Cards") },
        // Named after the settings page rather than after the style, so the
        // word is one the 31 catalogs already agree on.
        { mode: "metro", icon: "metro", label: Loc.t("Dashboard") }
    ]
    readonly property var currentMode: {
        var m = fullRoot ? fullRoot.viewMode : "rows";
        for (var i = 0; i < viewModes.length; i++) if (viewModes[i].mode === m) return viewModes[i];
        return viewModes[0];
    }

    implicitHeight: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Status dot with a soft halo; pulses while (re)connecting
        Item {
            implicitWidth: 14
            implicitHeight: 14
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: halo
                anchors.centerIn: parent
                width: 14; height: 14; radius: 7
                color: dot.color
                opacity: 0.25
                SequentialAnimation on opacity {
                    running: headerView.haManager && !headerView.connected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.05; duration: 700 }
                    NumberAnimation { to: 0.35; duration: 700 }
                    onRunningChanged: if (!running) halo.opacity = 0.25
                }
            }
            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: headerView.connected ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }
        }

        // A picture of who is being greeted earns its space more easily than
        // the word that greets them, so it sits beside the status dot rather
        // than in the text.
        Kirigami.Avatar {
            visible: headerView.personName.length > 0 || headerView.pictureUrl.length > 0
            name: headerView.personName
            source: headerView.pictureUrl
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            PlasmaComponents3.Label {
                text: {
                    // A greeted person takes the title line; the server's name
                    // moves down to where the count is, so neither is lost.
                    var greeting = headerView.greetingText;
                    if (greeting.length > 0) return greeting;
                    return (haManager && haManager.serverName) ? haManager.serverName : "Home Assistant";
                }
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                visible: headerView.headerEntityText.length > 0
                text: headerView.headerEntityText
                font.weight: Font.Bold
                color: Kirigami.Theme.highlightColor
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents3.Label {
                text: {
                    if (!haManager) return Loc.t("Disconnected");
                    if (!haManager.isConnected) return haManager.connectionStatus || Loc.t("Disconnected");
                    // The catalogs key on the English text, so the one number
                    // that decides the wording picks the key as well; a plural
                    // rule of its own per language is not modelled here. Both
                    // keys are written out as literals rather than chosen
                    // inside Loc.t(): the completeness test reads the first
                    // argument of every call, and a key hidden in an expression
                    // is a key no catalog is ever asked to have.
                    var n = haManager.entityCount;
                    var count = n === 1 ? Loc.t("%1 entity", n) : Loc.t("%1 entities", n);
                    // The greeting took the title line, so the server's name
                    // comes down here; otherwise the connection says what it is.
                    if (headerView.greetingInTitle && haManager.serverName) {
                        return haManager.serverName + " \u00b7 " + count;
                    }
                    return Loc.t("Connected") + " \u00b7 " + count;
                }
                font: Kirigami.Theme.smallFont
                color: headerView.connected ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.negativeTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        PlasmaComponents3.ToolButton {
            visible: haManager && !headerView.connected
            icon.name: "view-refresh-symbolic"
            text: Loc.t("Reconnect")
            display: headerView.narrow ? PlasmaComponents3.AbstractButton.IconOnly : PlasmaComponents3.AbstractButton.TextBesideIcon
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered && headerView.narrow
            onClicked: haManager.reconnect()
        }

        PlasmaComponents3.ToolButton {
            visible: headerView.connected
            icon.source: Qt.resolvedUrl("../../icons/search.svg")
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: Loc.t("Search")
            checkable: true
            checked: fullRoot ? fullRoot.showSearchBar : false
            PlasmaComponents3.ToolTip.text: Loc.t("Search (Esc to close)")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: headerView.toggleSearchRequested()
        }

        PlasmaComponents3.ToolButton {
            id: viewButton
            visible: headerView.connected
            icon.source: Qt.resolvedUrl("../../icons/" + headerView.currentMode.icon + ".svg")
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: Loc.t("View: %1", headerView.currentMode.label)
            down: viewMenu.opened || pressed
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered && !viewMenu.opened
            onClicked: viewMenu.opened ? viewMenu.close() : viewMenu.popup(viewButton, 0, viewButton.height)

            PlasmaComponents3.Menu {
                id: viewMenu
                Repeater {
                    model: headerView.viewModes
                    delegate: PlasmaComponents3.MenuItem {
                        required property var modelData
                        text: modelData.label
                        icon.source: Qt.resolvedUrl("../../icons/" + modelData.icon + ".svg")
                        checkable: true
                        checked: headerView.currentMode.mode === modelData.mode
                        onTriggered: headerView.viewModeSelected(modelData.mode)
                    }
                }
            }
        }

        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: Loc.t("Settings")
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: headerView.configureRequested()
        }
    }
}
