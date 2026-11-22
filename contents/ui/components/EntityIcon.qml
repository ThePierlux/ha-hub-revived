pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../../code/mdi_icons.mjs" as MdiIcons
import "../mdi"

// One entity glyph, drawn from whichever source its name points at.
//
// Three vocabularies answer to "which icon", and the widget can be asked for
// any of them (see HAHelpers.resolveEntityIcon):
//   mdi    a Material Design Icons name. Home Assistant stores its icons this
//          way and the Plasma icon theme has no such names, so they are drawn
//          from the bundled MDI font - that is what makes a tile show the very
//          icon the user picked in Home Assistant.
//   theme  an icon theme name, for the few callers that name one.
//   asset  one of the monochrome SVGs this widget bundles under contents/icons,
//          which is what an entity with no icon of its own is drawn by - the
//          set covers every domain the lists show.
Item {
    id: entityIcon
    objectName: "entityIcon"

    // "mdi", "theme" or "asset", as decided by HAHelpers.resolveEntityIcon().
    property string iconKind: "asset"
    // For "mdi" the bare name ("lightbulb"), for "theme" an icon theme name,
    // for "asset" the file under contents/icons without its extension.
    property string icon: ""
    // Icon theme name to use when the MDI path does not work out.
    property string fallbackIcon: ""
    property real size: Kirigami.Units.iconSizes.smallMedium
    property color color: Kirigami.Theme.textColor

    readonly property string mdiFamily: MdiFont.family
    // Only draw a glyph when the font is really there; otherwise the private
    // use area codepoints would render as empty boxes.
    readonly property bool isMdi: iconKind === "mdi" && mdiFamily.length > 0
        && MdiIcons.mdiCodepoint(icon) !== 0
    readonly property string glyph: MdiIcons.mdiGlyph(icon)
    readonly property string themeSource: iconKind === "theme" && icon.length > 0
        ? icon
        : fallbackIcon

    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)

    // Exactly one painter is instantiated. Kirigami.Icon keeps the visibility
    // of the icon it could not load to itself, so a `visible: false` binding
    // on it would be quietly overridden - a Loader cannot draw twice.
    Loader {
        anchors.fill: parent
        sourceComponent: entityIcon.isMdi ? glyphComponent
            : entityIcon.iconKind === "asset" ? assetComponent
            : themeComponent
    }

    Component {
        id: glyphComponent

        Text {
            objectName: "entityIconGlyph"
            anchors.fill: parent
            text: entityIcon.glyph
            font.family: entityIcon.mdiFamily
            // MDI glyphs are drawn on a 24px grid with a couple of pixels of
            // padding, so they are rendered slightly larger than the box to
            // end up the same visual size as the theme icons beside them.
            font.pixelSize: Math.round(entityIcon.size * 1.15)
            color: entityIcon.color
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Component {
        id: assetComponent

        // The bundled icons are monochrome, so they are drawn as a mask and
        // always take the colours of the current Plasma theme.
        Kirigami.Icon {
            objectName: "entityIconAsset"
            anchors.fill: parent
            source: Qt.resolvedUrl("../../icons/" + entityIcon.icon + ".svg")
            isMask: true
            color: entityIcon.color
        }
    }

    Component {
        id: themeComponent

        Kirigami.Icon {
            objectName: "entityIconTheme"
            anchors.fill: parent
            source: entityIcon.themeSource
            color: entityIcon.color
        }
    }
}
