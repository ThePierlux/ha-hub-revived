import QtQuick
import QtTest
import "../../contents/services" as Services

// The catalogue the views read their names from: the dashboard tiles, the entity
// picker, the details page. It is derived from the entity states and the two
// registries, so these fixtures are what the ingestion leaves behind.
TestCase {
    name: "HAManagerCatalog"

    Services.HAManager {
        id: manager
    }

    function init() {
        manager.entityAliases = "{}"
        manager.includeHiddenEntities = false
        manager.includeDiagnosticEntities = false
        manager.entities = {
            "switch.gang_1": { entity_id: "switch.gang_1", state: "on", attributes: { friendly_name: "Gang 1" } },
            "switch.gang_2": { entity_id: "switch.gang_2", state: "off", attributes: { friendly_name: "Gang 2" } },
            "switch.template_switch": { entity_id: "switch.template_switch", state: "on", attributes: { friendly_name: "Template Switch" } },
            "light.standalone": { entity_id: "light.standalone", state: "on", attributes: { friendly_name: "Standalone Light" } },
            "sensor.temperature": { entity_id: "sensor.temperature", state: "21.5", attributes: { friendly_name: "Temperature", unit_of_measurement: "°C" } }
        };

        manager.devicesList = [
            { id: "dev1", name: "Multi Gang", name_by_user: null, area_id: "kitchen" }
        ];
        manager._deviceById = {
            "dev1": { id: "dev1", name: "Multi Gang", name_by_user: null, area_id: "kitchen" }
        };
        manager.areasList = [
            { area_id: "kitchen", name: "Kitchen", floor_id: "ground" }
        ];
        manager.entityRegistryMap = {
            "switch.gang_1": { disabled: false, hidden: false, category: null },
            "switch.gang_2": { disabled: false, hidden: false, category: null }
        };
        manager.entityToDeviceMap = {
            "switch.gang_1": "dev1",
            "switch.gang_2": "dev1"
        };
        // The entity registry does not name an area for the gangs: they inherit
        // the one their device stands in.
        manager.entityToAreaMap = {};
        manager.deviceToEntitiesMap = {
            "dev1": ["switch.gang_1", "switch.gang_2"]
        };

        manager._buildCatalog()
    }

    function test_catalog_holds_every_entity_the_manager_knows() {
        compare(manager.entityCatalog.length, 5)
        verify(manager.getCatalogEntry("switch.gang_1") !== null)
        verify(manager.getCatalogEntry("switch.gang_2") !== null)
        verify(manager.getCatalogEntry("switch.template_switch") !== null)
        verify(manager.getCatalogEntry("light.standalone") !== null)
        verify(manager.getCatalogEntry("sensor.temperature") !== null)
    }

    function test_a_channel_knows_its_device_and_the_area_of_that_device() {
        var entry = manager.getCatalogEntry("switch.gang_1")
        compare(entry.domain, "switch")
        compare(entry.deviceId, "dev1")
        compare(entry.deviceName, "Multi Gang")
        compare(entry.areaId, "kitchen")
        compare(entry.areaName, "Kitchen")
    }

    function test_multi_gang_device_keeps_both_channels() {
        var first = manager.getCatalogEntry("switch.gang_1")
        var second = manager.getCatalogEntry("switch.gang_2")
        compare(first.deviceId, second.deviceId)
        verify(first.name !== second.name, "the two channels are told apart")
    }

    function test_the_picker_list_holds_every_channel_and_not_one_per_device() {
        // The dashboard and the Favorites page place and favourite entities, so
        // a list with one row per device hid the second gang of a switch: the
        // user could see both channels in the popup and pick only one.
        manager._listsDirty = true
        manager._buildCategorizedLists()

        verify(manager.userDevicesList.indexOf("switch.gang_1") !== -1)
        verify(manager.userDevicesList.indexOf("switch.gang_2") !== -1)
        verify(manager.userDevicesList.indexOf("sensor.temperature") !== -1,
               "an entity whose device is unknown is pickable too")
        compare(manager.userDevicesList.length, manager.allEntitiesList.length)

        // A page is free to sort the list it is handed; the popup's own list
        // must not move because of it.
        var popupOrder = manager.allEntitiesList.slice()
        manager.userDevicesList.reverse()
        compare(manager.allEntitiesList, popupOrder)
    }

    function test_standalone_entities_have_neither_device_nor_area() {
        var entries = ["switch.template_switch", "light.standalone"]
        for (var i = 0; i < entries.length; i++) {
            var entry = manager.getCatalogEntry(entries[i])
            compare(entry.deviceId, "")
            compare(entry.deviceName, "")
            compare(entry.areaId, "")
            compare(entry.areaName, "")
        }
    }

    function test_same_named_channels_keep_pure_friendly_titles() {
        // Both entities of dev1 inherit the device name. The user asked for
        // exactly the Home Assistant friendly name, so the titles stay equal
        // instead of getting a synthetic channel suffix.
        manager.entities["switch.gang_1"].attributes.friendly_name = "Multi Gang"
        manager.entities["switch.gang_2"].attributes.friendly_name = "Multi Gang"
        manager._buildCatalog()

        compare(manager.getCatalogEntry("switch.gang_1").name, "Multi Gang")
        compare(manager.getCatalogEntry("switch.gang_2").name, "Multi Gang")
    }

    function test_a_name_the_user_gave_wins_over_the_registry() {
        manager.entityAliases = JSON.stringify({ "light.standalone": "Люстра" })
        wait(200)   // the catalogue is rebuilt with the lists, once per burst
        compare(manager.getCatalogEntry("light.standalone").name, "Люстра")
    }

    function test_hidden_entities_stay_out_of_the_lists_until_asked_for() {
        manager.entityRegistryMap["switch.gang_2"].hidden = true
        manager._listsDirty = true
        manager._buildCategorizedLists()
        verify(manager.allEntitiesList.indexOf("switch.gang_2") === -1, "hidden by default")
        verify(manager.userDevicesList.indexOf("switch.gang_2") === -1,
               "hidden by default in the picker as well")

        // The same toggle on the Favorites page reaches the views through the
        // manager, so asking for hidden entities is enough to see them again.
        manager.includeHiddenEntities = true
        manager._listsDirty = true
        manager._buildCategorizedLists()
        verify(manager.allEntitiesList.indexOf("switch.gang_2") !== -1, "asked for, so shown")
        verify(manager.userDevicesList.indexOf("switch.gang_2") !== -1,
               "asked for, so pickable")
    }

    function test_disabled_entities_never_come_back() {
        manager.entityRegistryMap["switch.gang_2"].disabled = true
        manager.includeHiddenEntities = true
        manager.includeDiagnosticEntities = true
        manager._listsDirty = true
        manager._buildCategorizedLists()
        verify(manager.allEntitiesList.indexOf("switch.gang_2") === -1)
    }

    function test_catalog_title_follows_state_change() {
        compare(manager.getCatalogEntry("light.standalone").name, "Standalone Light")

        var evt = JSON.stringify({
            type: "event",
            event: {
                event_type: "state_changed",
                data: {
                    entity_id: "light.standalone",
                    new_state: { entity_id: "light.standalone", state: "on", attributes: { friendly_name: "Renamed Light" } }
                }
            }
        })
        manager._handleIncomingMessage(evt)
        wait(200)   // one rebuild per burst of updates, not one per update

        var entry = manager.getCatalogEntry("light.standalone")
        verify(entry !== null)
        compare(entry.name, "Renamed Light")
    }

    function test_catalog_drops_removed_entities() {
        var evt = JSON.stringify({
            type: "event",
            event: {
                event_type: "state_changed",
                data: { entity_id: "light.standalone", new_state: null }
            }
        })
        manager._handleIncomingMessage(evt)
        wait(200)

        verify(manager.getEntity("light.standalone") === null)
        verify(manager.getCatalogEntry("light.standalone") === null)
        compare(manager.entityCatalog.length, 4)
    }

    function test_pending_requests_are_answered_when_the_connection_ends() {
        var called = 0
        var got = "still waiting"
        manager.registerStatsHandler(99991, function (result) {
            called++
            got = result
        })

        manager.disconnectFromHA()

        compare(called, 1)
        verify(got === null, "answered with nothing, so the caller stops waiting")
        verify(manager._customMsgHandlers[99991] === undefined, "and forgotten")
    }
}
