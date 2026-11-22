const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const { loadLibrary } = require("./load-library.js");
const client = loadLibrary("contents/code/ha_client.js");

test("call_service supports entity target", () => {
    const payload = JSON.parse(client.buildCallServicePayload(1, "light", "turn_on", { brightness: 10 }, "light.kitchen"));
    assert.equal(payload.type, "call_service");
    assert.deepEqual(payload.target, { entity_id: "light.kitchen" });
    assert.equal(payload.service_data.brightness, 10);
});

test("call_service leaves the target out when no entity is named", () => {
    const payload = JSON.parse(client.buildCallServicePayload(2, "scene", "turn_on", {}, null));
    assert.equal(payload.type, "call_service");
    assert.equal(payload.domain, "scene");
    assert.equal(payload.target, undefined);
});

// The 1.3.1 client also built requests for the floor and label registries,
// get_services, search/related and the logbook. Nothing here asks for those, so
// the builder is not carried and neither is a test for it.
test("registry payload builders use the commands the manager asks for", () => {
    assert.equal(JSON.parse(client.buildGetStatesPayload(1)).type, "get_states");
    assert.equal(JSON.parse(client.buildGetAreasPayload(2)).type, "config/area_registry/list");
    assert.equal(JSON.parse(client.buildGetDevicesPayload(3)).type, "config/device_registry/list");
    assert.equal(JSON.parse(client.buildGetEntityRegistryPayload(4)).type, "config/entity_registry/list");
});

test("history payload covers a period and names its entities", () => {
    const history = JSON.parse(client.buildHistoryPayload(5, ["sensor.temp"], "2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z"));
    assert.equal(history.type, "history/history_during_period");
    assert.deepEqual(history.entity_ids, ["sensor.temp"]);
    assert.equal(history.start_time, "2026-01-01T00:00:00Z");
    assert.equal(history.end_time, "2026-01-02T00:00:00Z");
    assert.equal(history.minimal_response, true);
    assert.equal(history.no_attributes, true);

    // one id, given on its own, still travels as a list
    assert.deepEqual(JSON.parse(client.buildHistoryPayload(6, "sensor.temp", "a", "b")).entity_ids, ["sensor.temp"]);
});

test("auth and event subscription payloads", () => {
    assert.deepEqual(JSON.parse(client.buildAuthPayload("tok")), { type: "auth", access_token: "tok" });

    const sub = JSON.parse(client.buildSubscribeEventsPayload(7, "state_changed"));
    assert.equal(sub.id, 7);
    assert.equal(sub.type, "subscribe_events");
    assert.equal(sub.event_type, "state_changed");

    // default subscription is state_changed
    assert.equal(JSON.parse(client.buildSubscribeEventsPayload(8)).event_type, "state_changed");
});

test("incoming message parser reports malformed JSON", () => {
    assert.equal(client.parseIncomingMessage('{"ok":1}').success, true);
    assert.equal(client.parseIncomingMessage("not json").success, false);
});
