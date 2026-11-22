pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../components" as Components
import "../../l10n"
Kirigami.ScrollablePage {
    id: generalSettings
    // Plasma assigns a page a title of its own when it opens it - the category
    // name it read *before* this page's bridge had set the language, from a copy
    // made while the dialog was still in the system language - and an assignment
    // breaks the binding, so the heading kept that first language. Re-asserting
    // it here puts the configured one back.
    readonly property string pageTitle: Loc.t("General")
    title: pageTitle
    onPageTitleChanged: generalSettings.title = generalSettings.pageTitle
    topPadding: 0

    // This dialog has its own Loc instance: without a language pushed into it,
    // every page here stays in the system language. The dialog hands each page
    // its own copy of the configuration, and that copy arrives as cfg_*, so this
    // is the source the bridge reads - the same one the applet reads, which is
    // why the widget and the dialog cannot disagree about the language.
    Components.LanguageBridge {
        id: settingsLanguageBridge
        pendingLanguage: generalSettings.cfg_language
    }

    readonly property string cfg_hostDefault: "192.168.1.100"
    readonly property string cfg_portDefault: "8123"
    readonly property bool cfg_useSslDefault: false
    readonly property string cfg_accessTokenDefault: ""
    readonly property bool cfg_autoConnectDefault: true
    readonly property string cfg_serverNameDefault: "Home Assistant"
    readonly property string cfg_favoriteEntitiesDefault: "[]"
    readonly property string cfg_viewModeDefault: "rows"
    readonly property int cfg_cornerRadiusDefault: 16
    readonly property int cfg_backgroundOpacityDefault: 70

    property string cfg_host: "192.168.1.100"
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_autoConnect: true
    property string cfg_serverName: "Home Assistant"
    // The fallback is the language this dialog is already showing, never a
    // hard-coded "system": whatever this page holds is what Apply writes out,
    // and a wrong "system" here silently erases a chosen language.
    property string cfg_language: Loc.configuredLanguage
    property string cfg_favoriteEntities: "[]"
    property string cfg_viewMode: "rows"
    property int cfg_cornerRadius: 16
    property int cfg_backgroundOpacity: 70
    // Keys edited elsewhere; declared so the config dialog doesn't warn
    property int cfg_lastTab
    property int cfg_lastTabDefault
    property int cfg_panelDisplayMode
    property int cfg_panelDisplayModeDefault
    property string cfg_primarySensorEntity
    property string cfg_primarySensorEntityDefault
    property string cfg_desktopEntityId
    property string cfg_desktopEntityIdDefault
    property bool cfg_showDashboard
    property bool cfg_showDashboardDefault

    // A pick assigns the picker's currentIndex, as the control's own delegate
    // does, and that drops the currentIndex binding - so keep the control
    // pointing at whatever the page holds instead. The dialog follows the same
    // property: the first change is not a pick at all, it is the saved language
    // arriving with the page, and that is what the dialog should be showing.
    onCfg_languageChanged: {
        if (!languageCombo) return
        languageCombo.currentIndex = languageCombo.indexForCode(cfg_language)
    }

    // One way to change the language, used by the picker (and by the tests): into
    // cfg_language, the value the dialog was opened with and Apply stores. The
    // language is also the one setting the dialog repaints itself with at once,
    // through the bridge above - a dialog that changed language only on Apply
    // would be unreadable in a language the user cannot yet read.
    //
    // One writer for the language: the page. The settings dialog keeps a copy of
    // the configuration of its own, and a write that goes around it - straight
    // into the applet's configuration, however tempting - leaves that copy holding
    // the old value, which the dialog then writes back over the choice when it
    // closes. So the language travels the way every other setting does.
    function selectLanguage(code) {
        if (code === generalSettings.cfg_language && Loc.configuredLanguage === code) return
        generalSettings.cfg_language = code
    }

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true

        Kirigami.Separator {
            Kirigami.FormData.label: Loc.t("Home Assistant connection")
            Kirigami.FormData.isSection: true
        }

        Controls.TextField {
            id: hostField
            Kirigami.FormData.label: Loc.t("Home Assistant host / IP:")
            placeholderText: "homeassistant.local or 192.168.1.100"
            text: generalSettings.cfg_host
            Layout.fillWidth: true
            onTextEdited: generalSettings.cfg_host = text
        }

        Controls.TextField {
            id: portField
            Kirigami.FormData.label: Loc.t("Port:")
            placeholderText: "8123"
            text: generalSettings.cfg_port
            inputMethodHints: Qt.ImhDigitsOnly
            onTextEdited: generalSettings.cfg_port = text
        }

        Controls.CheckBox {
            id: sslCheckBox
            Kirigami.FormData.label: Loc.t("Secure connection:")
            text: Loc.t("Use wss:// (HTTPS)")
            checked: generalSettings.cfg_useSsl
            onToggled: generalSettings.cfg_useSsl = checked
        }

        Controls.TextField {
            id: tokenField
            Kirigami.FormData.label: Loc.t("Long-lived access token:")
            placeholderText: Loc.t("Long-lived token (Profile → Security in Home Assistant)")
            text: generalSettings.cfg_accessToken
            echoMode: TextInput.Password
            Layout.fillWidth: true
            onTextEdited: generalSettings.cfg_accessToken = text
        }

        Controls.CheckBox {
            id: autoConnectCheckBox
            Kirigami.FormData.label: Loc.t("Auto Connect:")
            text: Loc.t("Connect on startup")
            checked: generalSettings.cfg_autoConnect
            onToggled: generalSettings.cfg_autoConnect = checked
        }

        Controls.ComboBox {
            id: languageCombo
            objectName: "languageCombo"
            Kirigami.FormData.label: Loc.t("Language:")
            Layout.fillWidth: true

            // The model carries only what never changes: the codes and the names
            // each language writes about itself. A translated string inside the
            // model would rebuild the model at the very moment the language
            // changes (the picker retranslates as it picks), and the control
            // resets its currentIndex when the model is swapped.
            readonly property var entries: [{ code: "system" }].concat(Loc.languages)
            readonly property string systemLabel: Loc.t("System language")
            model: entries
            textRole: "code"

            function labelFor(code) {
                if (code === "system") return languageCombo.systemLabel
                var langs = Loc.languages
                for (var i = 0; i < langs.length; ++i) {
                    if (langs[i].code === code) return langs[i].label
                }
                return code
            }
            function indexForCode(code) {
                for (var i = 0; i < entries.length; ++i) {
                    if (entries[i].code === code) return i
                }
                return 0
            }

            currentIndex: indexForCode(generalSettings.cfg_language)
            // Translated on its own, so switching language retranslates the button
            // and the list without touching the model.
            displayText: currentIndex >= 0 && currentIndex < entries.length
                ? languageCombo.labelFor(entries[currentIndex].code) : ""

            delegate: Controls.ItemDelegate {
                required property var modelData
                required property int index
                width: languageCombo.width
                text: languageCombo.labelFor(modelData.code)
                highlighted: languageCombo.highlightedIndex === index
                onClicked: {
                    languageCombo.currentIndex = index
                    languageCombo.popup.dismiss()
                    generalSettings.selectLanguage(modelData.code)
                }
            }

            // Keyboard navigation in the popup ends here instead of in a delegate
            // click. selectLanguage ignores a pick of the language already set.
            onActivated: (index) => generalSettings.selectLanguage(entries[index].code)
        }

        Controls.Label {
            text: Loc.t("Apply to keep this language after closing the settings.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Kirigami.Separator {
            Kirigami.FormData.label: Loc.t("Appearance")
            Kirigami.FormData.isSection: true
        }

        Controls.ComboBox {
            id: viewModeBox
            Kirigami.FormData.label: Loc.t("Default view:")
            model: [
                { text: Loc.t("Rows"), value: "rows" },
                { text: Loc.t("Tiles"), value: "tiles" },
                { text: Loc.t("Cards (Liquid Glass)"), value: "cards" }
            ]
            textRole: "text"
            valueRole: "value"
            currentIndex: {
                if (generalSettings.cfg_viewMode === "tiles") return 1;
                if (generalSettings.cfg_viewMode === "cards") return 2;
                return 0;
            }
            onActivated: {
                generalSettings.cfg_viewMode = model[currentIndex].value;
            }
        }

        RowLayout {
            Kirigami.FormData.label: Loc.t("Corner radius:")
            spacing: Kirigami.Units.smallSpacing

            Controls.Slider {
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
                from: 0
                to: 32
                stepSize: 1
                value: generalSettings.cfg_cornerRadius
                onMoved: generalSettings.cfg_cornerRadius = Math.round(value)
            }
            Controls.SpinBox {
                from: 0
                to: 32
                value: generalSettings.cfg_cornerRadius
                textFromValue: function(v) { return v + " px"; }
                valueFromText: function(t) { return parseInt(t); }
                onValueModified: generalSettings.cfg_cornerRadius = value
            }
        }

        RowLayout {
            Kirigami.FormData.label: Loc.t("Background opacity:")
            spacing: Kirigami.Units.smallSpacing

            Controls.Slider {
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
                from: 0
                to: 100
                stepSize: 5
                value: generalSettings.cfg_backgroundOpacity
                onMoved: generalSettings.cfg_backgroundOpacity = Math.round(value)
            }
            Controls.SpinBox {
                from: 0
                to: 100
                stepSize: 5
                value: generalSettings.cfg_backgroundOpacity
                textFromValue: function(v) { return v + " %"; }
                valueFromText: function(t) { return parseInt(t); }
                onValueModified: generalSettings.cfg_backgroundOpacity = value
            }
        }

        Controls.Label {
            text: Loc.t("Corner radius and opacity apply when the widget is on the desktop; in a panel, Plasma draws the popup frame. Colors always follow the system theme.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
