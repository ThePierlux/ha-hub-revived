// Translations this branch carries without a call site, grouped by why.
//
// The catalogs came over whole from HA-hub 1.3.1, and this fork kept its own
// popup, its own settings wording and its own header, so a few dozen strings
// are translated by work nobody here asks for. They are listed rather than
// deleted for two reasons: the translations are the expensive part of a
// language, and if the 1.3.1 list or its wording ever lands here, the words are
// already there in 31 languages.
//
// translations.test.js compares this list against what the code actually asks
// for, in both directions: a key that joins these without being named here
// fails, and a key named here that the code has started to ask for fails, so
// the list cannot quietly rot in either direction.

module.exports = {
    // Words Home Assistant itself answers with - a weather condition, a binary
    // sensor's or a climate's state, the units a duration is counted in. The
    // 1.3.1 list printed them straight from the entity; this fork's list prints
    // what its own helpers say.
    ha_answers: [
        "%1d", "%1h", "%1m", "%1s",
        "Activate", "Active", "Clear night", "Cloudy", "Disabled", "Enabled",
        "Exceptional", "Fan", "Fog", "Hail", "Inactive", "Lightning",
        "Low battery", "Motion", "No motion", "Partly cloudy", "Pouring",
        "Quiet", "Rainy", "Ready", "Snowy", "Sunny", "Windy"
    ],

    // The 1.3.1 popup: a list of devices with its own headings, search line and
    // empty states. This fork's popup shows the same thing its own way - among
    // them "Unassigned", the heading 1.3.1 gives the devices that belong to no
    // area; this fork's room filter lists the areas it was given, so it has no
    // such group to name.
    ha_hub_list: [
        "ATTRIBUTES", "Areas", "Devices", "Labels:", "Device List:",
        "Search by name, area or entity ID…", "Search device by name or ID...",
        "No devices found", "Unassigned",
        "Try changing the search query or check the connection.",
        "Open settings to add devices to favorites."
    ],

    // The 1.3.1 General page, whose fields this fork labels in its own words -
    // same settings, different sentences, so both sets would be in the catalogs
    // whichever page had been kept.
    ha_hub_general: [
        "Access Token:", "A previously saved token is kept in the widget's private storage and used automatically. Enter a new token here only to replace it.",
        "SSL Connection:", "Use wss://",
        "SSL error: the server does not use SSL. Disable “wss://”.",
        "HA Host / IP:", "Servers found: %1",
        "Show hidden entities", "Show diagnostic / config entities",
        "Connection closed.", "Connection lost",
        "Error: Connection timed out for %1", "Error: %1.",
        "Connected (%1:%2)", "Install"
    ],

    // The two-tab popup of 1.3.1, whose toggles were dropped when the page was
    // ported: this fork's four views are chosen from the header's menu, so there
    // is no switch between two tabs to show or hide.
    ha_hub_tabs: [
        "Views in popup:", "Show 'Dashboard' tab", "Show 'Devices' tab",
        "Only one view is shown, so the switch button between Dashboard and Devices is hidden."
    ]
};
