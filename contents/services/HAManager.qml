import QtQuick
import QtQuick.LocalStorage
import QtWebSockets
import org.kde.plasma.plasmoid
import "../code/ha_client.js" as HAClient
import "../code/ha_helpers.mjs" as HAHelpers
import "../code/ha_storage.js" as HAStorage
// Registers the KDE Loc.t() global over this module's catalogs, so the words the
// header and the tray show come from the same 31 languages as the rest.
import "../l10n"

Item {
    id: manager

    property string host: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.host || "") : ""
    property int port: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.port || 8123) : 8123
    property bool useSsl: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.useSsl || false) : false
    property string accessToken: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.accessToken || "") : ""
    property string serverName: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.serverName || "Home Assistant") : "Home Assistant"

    property string state: "DISCONNECTED"
    property string connectionStatus: Loc.t("Disconnected")
    // Why the connection ended, in words, kept apart from the line the header
    // shows: the retry notice is built out of it, and a sentence cut out of the
    // previous notice only works in the language it was written in.
    property string failureReason: ""
    property bool isConnected: false
    property bool autoReconnectAllowed: true

    property bool _isManualDisconnecting: false

    property var entities: ({})
    property var _entitiesLowerMap: ({})

    property int entitiesRevision: 0
    // Bumped only when the *set* of listed entities changes (not on every state update)
    property int listsRevision: 0
    property int entityCount: 0
    property var _deviceById: ({})
    property bool _listsDirty: true
    property int _reconnectAttempts: 0
    property bool _awaitingPong: false
    property int _pingMsgId: 0
    property var discoveredServers: []
    // What the settings pages offer to pick: one entry per entity, so the two
    // gangs of a switch are two things the user can place. Filled with the four
    // lists below, in the same pass, in the same order.
    property var userDevicesList: []
    property var lightsAndSwitchesList: []
    property var climateAndSensorsList: []
    property var mediaAndOthersList: []
    property var allEntitiesList: []

    readonly property alias mdns: mdns
    readonly property bool isSearching: mdns ? mdns.isSearching : false

    property var areasList: []
    property var devicesList: []
    property var entityToAreaMap: ({})
    property var entityToDeviceMap: ({})
    property var deviceToEntitiesMap: ({})
    property var entityRegistryMap: ({})

    // ── What the views ask the manager for ───────────────────────────────────
    // The dashboard, the entity picker and the details page were written against
    // a manager that answers these. Everything below is derived from the maps
    // above, so one entity has one name and one icon everywhere it appears.

    // The names the user gave entities (Settings → Dashboard). main.qml binds it
    // from the configuration. aliasesRevision is what makes a rename re-title the
    // tiles at once: their text is computed from entitiesRevision, and without a
    // revision of its own an entity kept its old name until the next state update.
    property string entityAliases: "{}"
    readonly property var aliasMap: HAHelpers.parseAliases(manager.entityAliases)
    property int aliasesRevision: 0
    // A rename changes titles, so it is a structural change: the lists are
    // re-sorted and the catalogue re-titled, not only the revision bumped.
    onEntityAliasesChanged: manager._namesChanged()

    // Whether the lists and the picker may show entities the registry hides or
    // files under diagnostic/config. Off is what the lists did before.
    property bool includeHiddenEntities: false
    property bool includeDiagnosticEntities: false

    // One record per entity: name, domain, device, area, and whether the registry
    // hides it. Rebuilt in the debounced pass, with the lists, not per state.
    property var entityCatalog: []
    property var _catalogById: ({})

    // The person whose name and picture the header shows. The configured id wins;
    // otherwise the first person that actually has a picture.
    property string headerPersonEntityId: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
        ? (Plasmoid.configuration.headerPersonEntityId || "")
        : ""

    readonly property string primaryPersonEntityId: {
        var rev = manager.entitiesRevision;
        if (manager.headerPersonEntityId && manager.entities[manager.headerPersonEntityId]) {
            return manager.headerPersonEntityId;
        }
        var keys = Object.keys(manager.entities || {});
        var fallback = "";
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf("person.") !== 0) continue;
            if (!fallback) fallback = keys[i];
            var ent = manager.entities[keys[i]];
            if (ent && ent.attributes && ent.attributes.entity_picture) return keys[i];
        }
        return fallback;
    }

    readonly property string primaryPersonName: {
        var id = manager.primaryPersonEntityId;
        if (!id) return "";
        var ent = manager.entities[id];
        var alias = manager.entityAliasFor(id);
        if (alias) return alias;
        return (ent && ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name : "";
    }

    readonly property string primaryPersonPictureUrl: {
        var id = manager.primaryPersonEntityId;
        if (!id) return "";
        var ent = manager.entities[id];
        var picture = (ent && ent.attributes) ? (ent.attributes.entity_picture || "") : "";
        return picture ? manager.resourceUrl(picture) : "";
    }

    // The people to offer in Settings → Appearance.
    readonly property var personOptions: {
        var rev = manager.entitiesRevision;
        var keys = Object.keys(manager.entities || {});
        var result = [];
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf("person.") !== 0) continue;
            var ent = manager.entities[keys[i]];
            result.push({
                id: keys[i],
                name: manager.entityAliasFor(keys[i])
                    || ((ent && ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name : keys[i])
            });
        }
        result.sort(function(a, b) { return a.name.localeCompare(b.name); });
        return result;
    }

    // http(s)://host:port. HA only serves /api/* pictures to an authenticated
    // request, and an <Image> cannot sign one, so the token travels in the URL.
    readonly property string httpBaseUrl: {
        var clean = String(host || "").replace(/^https?:\/\//i, "").replace(/^wss?:\/\//i, "").replace(/\/+$/, "");
        if (!clean) return "";
        return (useSsl ? "https://" : "http://") + clean + ":" + port;
    }

    readonly property var _areaById: {
        var byId = {};
        var list = manager.areasList || [];
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].area_id) byId[list[i].area_id] = list[i];
        }
        return byId;
    }

    property int _getConfigMsgId: 0
    property int _getStatesMsgId: 0
    property int _getAreasMsgId: 0
    property int _getDevicesMsgId: 0
    property int _getEntityRegMsgId: 0

    property var _tempDeviceToAreaMap: ({})
    property var _customMsgHandlers: ({})
    property int _globalMsgIdCounter: 100

    function getNextMessageId() {
        manager._globalMsgIdCounter++;
        return manager._globalMsgIdCounter;
    }

    function registerStatsHandler(msgId, callback) {
        _customMsgHandlers[msgId] = callback;
    }

    function _updateCredentials(h, p, t, s, name) {
        if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) {
            try {
                if (h !== undefined) Plasmoid.configuration.host = h;
                if (p !== undefined) Plasmoid.configuration.port = p;
                if (t !== undefined) Plasmoid.configuration.accessToken = t;
                if (s !== undefined) Plasmoid.configuration.useSsl = s;
                if (name !== undefined) Plasmoid.configuration.serverName = name;
            } catch (e) {}
        } else {
            if (h !== undefined) host = h;
            if (p !== undefined) port = p;
            if (t !== undefined) accessToken = t;
            if (s !== undefined) useSsl = s;
            if (name !== undefined) serverName = name;
        }
    }

    function loadSharedCredentials() {
        if (accessToken && accessToken.length > 0) return true;
        var loaded = HAStorage.loadSharedCredentials(LocalStorage, host, port, serverName);
        if (loaded) {
            manager._updateCredentials(loaded.host, loaded.port, loaded.accessToken, loaded.useSsl, loaded.serverName);
            return true;
        }
        return false;
    }

    function saveSharedCredentials() {
        HAStorage.saveSharedCredentials(LocalStorage, host, port, accessToken, useSsl, serverName);
    }

    function _buildCategorizedLists() {
        var allKeys = manager.entities ? Object.keys(manager.entities) : [];
        var lights = [];
        var sensors = [];
        var media = [];
        var all = [];

        var lightDomains = ["light", "switch", "outlet", "fan", "input_boolean"];
        var sensorDomains = ["sensor", "binary_sensor", "climate", "air_quality", "humidifier", "weather", "water_heater"];
        var mediaDomains = ["media_player", "vacuum", "cover", "lock", "valve", "scene", "script", "camera", "button", "input_button",
                            "siren", "alarm_control_panel", "lawn_mower", "person"];
        var skipDomains = ["zone", "persistent_notification", "sun", "update", "tts", "stt", "conversation", "event",
                           "image", "todo", "wake_word", "assist_satellite", "ai_task", "notify", "tag"];
        var reg = manager.entityRegistryMap || {};

        for (var i = 0; i < allKeys.length; i++) {
            var entId = allKeys[i];
            var dom = entId.split(".")[0];

            if (skipDomains.indexOf(dom) !== -1) continue;
            var r = reg[entId];
            // "hidden" and "diagnostic" are the two toggles the Favorites page
            // binds on the manager; off, they stay out of the lists as they
            // always did. A disabled entity never comes back.
            if (r && r.disabled) continue;
            if (r && r.hidden && !manager.includeHiddenEntities) continue;
            if (r && (r.category === "diagnostic" || r.category === "config")
                && !manager.includeDiagnosticEntities) continue;

            all.push(entId);

            if (lightDomains.indexOf(dom) !== -1) {
                lights.push(entId);
            } else if (sensorDomains.indexOf(dom) !== -1) {
                sensors.push(entId);
            } else if (mediaDomains.indexOf(dom) !== -1) {
                media.push(entId);
            }
        }

        // Precompute titles once: sorting 700+ entities with lookups inside the comparator is slow
        var titles = {};
        for (var t = 0; t < all.length; t++) {
            titles[all[t]] = HAHelpers.getEntityTitle(all[t], manager.entities[all[t]]).toString().trim().toLowerCase();
        }
        function sortList(list) {
            return list.sort(function(a, b) {
                return titles[a].localeCompare(titles[b], undefined, { numeric: true, sensitivity: "base" });
            });
        }

        manager.lightsAndSwitchesList = sortList(lights);
        manager.climateAndSensorsList = sortList(sensors);
        manager.mediaAndOthersList = sortList(media);
        manager.allEntitiesList = sortList(all);
        // The settings pages pick entities, not devices: the two gangs of a
        // switch are two tiles placed separately, a favourite is one entity, and
        // the header's "value next to greeting" is whatever the user points at.
        // So this is the popup's "All" tab again - a copy of it, because a page
        // may sort what it is handed and must not re-sort what the popup shows.
        manager.userDevicesList = manager.allEntitiesList.slice();
        manager.entityCount = all.length;
        manager._listsDirty = false;
        manager.listsRevision++;
    }

    Timer {
        id: revisionDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (manager._listsDirty) {
                manager._buildCatalog();
                manager._buildCategorizedLists();
            }
            manager.entitiesRevision++;
        }
    }

    function _notifyEntitiesChanged(structural) {
        if (structural) manager._listsDirty = true;
        if (!revisionDebounceTimer.running) {
            revisionDebounceTimer.start();
        }
    }

    function _namesChanged() {
        manager.aliasesRevision++;
        manager._notifyEntitiesChanged(true);
    }

    Timer {
        id: pingTimer
        interval: 25000
        repeat: true
        running: manager.isConnected
        onTriggered: {
            if (!manager.isConnected || webSocket.status !== WebSocket.Open) return;
            if (manager._awaitingPong) {
                // Previous ping never answered: the connection is dead
                console.warn("HA-hub: no pong received, reconnecting");
                manager._awaitingPong = false;
                manager._dropAndReconnect(Loc.t("Connection lost, reconnecting…"));
                return;
            }
            manager._awaitingPong = true;
            manager._pingMsgId = manager.getNextMessageId();
            manager.safeSend(JSON.stringify({ id: manager._pingMsgId, type: "ping" }));
        }
    }

    // Close the socket without the "manual" flag so the normal reconnect path runs
    function _dropAndReconnect(statusText) {
        connTimeoutTimer.stop();
        manager.isConnected = false;
        manager.state = "ERROR";
        manager.failureReason = statusText;
        manager.connectionStatus = statusText;
        if (webSocket.status === WebSocket.Open || webSocket.status === WebSocket.Connecting) {
            manager._isManualDisconnecting = true;
            webSocket.active = false;
        }
        manager._scheduleReconnect();
    }

    // Exponential backoff: 3s, 6s, 12s … capped at 60s
    function _scheduleReconnect() {
        if (!manager.autoReconnectAllowed || !manager.accessToken || manager.accessToken.length === 0) return;
        if (autoReconnectTimer.running) return; // Error is often followed by Closed
        var delay = Math.min(60000, 3000 * Math.pow(2, manager._reconnectAttempts));
        manager._reconnectAttempts++;
        autoReconnectTimer.interval = delay;
        autoReconnectTimer.restart();
        var reason = manager.failureReason.length > 0 ? manager.failureReason : Loc.t("Reconnecting");
        manager.connectionStatus = Loc.t("%1 Retrying in %2 s", reason, Math.round(delay / 1000));
    }

    function reconnect() {
        manager._reconnectAttempts = 0;
        manager.disconnectFromHA();
        manager.startAutoConnect();
    }

    function refreshStates() {
        if (!manager.isConnected) {
            manager.reconnect();
            return;
        }
        manager._listsDirty = true;
        manager._fetchInitialStates();
        manager._fetchRegistries();
    }

    Timer {
        id: connTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (manager.state === "AUTHENTICATING" || manager.state === "DISCOVERING") {
                console.warn("HA-hub: Connection timed out for host:", manager.host);
                manager._dropAndReconnect(Loc.t("Connection to %1 timed out.", manager.host));
            }
        }
    }

    Timer {
        id: autoReconnectTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (!manager.isConnected && manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                manager._connectSocket();
            }
        }
    }

    MDNSDiscovery {
        id: mdns
        onDiscoveryFinished: function(serverList) {
            connTimeoutTimer.stop();
            manager.discoveredServers = serverList;
            if (serverList.length > 0) {
                manager.connectionStatus = Loc.t("Found devices: %1", serverList.length);
            } else {
                manager.connectionStatus = Loc.t("No devices found in local network");
            }
        }
    }

    WebSocket {
        id: webSocket
        active: false

        onStatusChanged: function() {
            if (webSocket.status === WebSocket.Open) {
                manager._isManualDisconnecting = false;
            } else if (webSocket.status === WebSocket.Error) {
                connTimeoutTimer.stop();
                var err = webSocket.errorString || Loc.t("Unable to connect to server");
                var msg;
                if (manager.useSsl && (err.indexOf("wrong version number") !== -1 || err.indexOf("SSL routines") !== -1 || err.indexOf("handshake") !== -1)) {
                    msg = Loc.t("SSL Error: HA server is running without SSL. Uncheck 'SSL (wss://)'");
                } else {
                    msg = Loc.t("Error: %1", err);
                }
                manager.state = "ERROR";
                manager.isConnected = false;
                manager.failureReason = msg;
                manager.connectionStatus = msg;
                manager._scheduleReconnect();
            } else if (webSocket.status === WebSocket.Closed) {
                connTimeoutTimer.stop();

                if (manager._isManualDisconnecting) {
                    manager._isManualDisconnecting = false;
                    return;
                }

                if (manager.state !== "ERROR") {
                    manager.state = "DISCONNECTED";
                    manager.connectionStatus = Loc.t("Disconnected");
                }
                manager.isConnected = false;
                manager._scheduleReconnect();
            }
        }

        onTextMessageReceived: function(message) {
            manager._handleIncomingMessage(message);
        }
    }

    function safeSend(messageText) {
        if (webSocket && webSocket.status === WebSocket.Open) {
            webSocket.sendTextMessage(messageText);
        }
    }

    function getEntity(id) {
        if (!id || !entities) return null;
        var cleanId = HAHelpers.cleanEntityId(id);
        if (entities[cleanId]) return entities[cleanId];
        var lower = cleanId.toLowerCase();
        if (_entitiesLowerMap[lower]) return _entitiesLowerMap[lower];
        return null;
    }

    function getDeviceRaw(deviceId) {
        if (!deviceId) return null;
        return _deviceById[deviceId] || null;
    }

    function entityAliasFor(entId) {
        return HAHelpers.aliasFor(manager.aliasMap, entId);
    }

    function getAreaRaw(areaId) {
        if (!areaId) return null;
        return manager._areaById[areaId] || null;
    }

    function getEntityRegistry(entId) {
        return manager.entityRegistryMap ? (manager.entityRegistryMap[entId] || null) : null;
    }

    function getCatalogEntry(entId) {
        if (!entId) return null;
        return manager._catalogById[entId] || null;
    }

    function resourceUrl(pathOrUrl) {
        if (!pathOrUrl) return "";
        if (/^https?:\/\//i.test(pathOrUrl)) return pathOrUrl;
        if (!manager.httpBaseUrl) return "";
        var url = manager.httpBaseUrl + (pathOrUrl.charAt(0) === "/" ? pathOrUrl : "/" + pathOrUrl);
        if (manager.accessToken && url.indexOf("auth_token=") === -1) {
            url += (url.indexOf("?") === -1 ? "?" : "&") + "auth_token=" + encodeURIComponent(manager.accessToken);
        }
        return url;
    }

    // The catalogue behind getCatalogEntry(): one record per entity, in the order
    // the picker and the dashboard list them. Runs in the debounced pass with the
    // lists, so a burst of state updates pays for it once.
    function _buildCatalog() {
        var byId = {};
        var list = [];
        var keys = manager.entities ? Object.keys(manager.entities) : [];
        var reg = manager.entityRegistryMap || {};

        for (var i = 0; i < keys.length; i++) {
            var id = keys[i];
            var ent = manager.entities[id];
            var r = reg[id] || null;
            var deviceId = manager.entityToDeviceMap ? (manager.entityToDeviceMap[id] || "") : "";
            var dev = deviceId ? manager.getDeviceRaw(deviceId) : null;
            var areaId = (manager.entityToAreaMap ? (manager.entityToAreaMap[id] || "") : "")
                || (dev && dev.area_id ? dev.area_id : "");
            var area = manager.getAreaRaw(areaId);
            var category = (r && r.category) || null;

            var entry = {
                id: id,
                entityId: id,
                name: HAHelpers.getEntityTitle(id, ent, r, manager) || id,
                domain: id.split(".")[0],
                deviceId: deviceId,
                deviceName: dev ? HAHelpers.getDeviceTitle(id, ent, deviceId, manager) : "",
                areaId: areaId,
                areaName: area ? (area.name || "") : "",
                category: category,
                hidden: !!(r && r.hidden),
                disabled: !!(r && r.disabled),
                isConfig: category === "config",
                isDiagnostic: category === "diagnostic"
            };
            list.push(entry);
            byId[id] = entry;
        }

        list.sort(function(a, b) {
            var cmp = String(a.name).localeCompare(String(b.name), undefined, { numeric: true, sensitivity: "base" });
            return cmp !== 0 ? cmp : a.id.localeCompare(b.id);
        });

        manager._catalogById = byId;
        manager.entityCatalog = list;
    }

    function _connectSocket() {
        if (!accessToken || accessToken.length === 0) {
            state = "ERROR";
            connectionStatus = Loc.t("Please enter Access Token");
            return;
        }

        // Only expect a Closed event if a socket is actually open; otherwise the
        // flag would stay set and swallow the next real disconnect (no auto-reconnect).
        if (webSocket.status === WebSocket.Open || webSocket.status === WebSocket.Connecting) {
            _isManualDisconnecting = true;
        }
        webSocket.active = false;
        _awaitingPong = false;

        connTimeoutTimer.restart();
        state = "AUTHENTICATING";
        connectionStatus = Loc.t("Connecting to %1:%2...", host, port);

        var protocol = useSsl ? "wss://" : "ws://";
        var targetUrl = protocol + host + ":" + port + "/api/websocket";

        webSocket.url = targetUrl;
        webSocket.active = true;
    }

    function startAutoConnect() {
        manager.loadSharedCredentials();
        if (host && host.length > 0 && accessToken && accessToken.length > 0) {
            manager._connectSocket();
        } else {
            manager.runAutoDiscovery();
        }
    }

    function runAutoDiscovery() {
        if (mdns && mdns.isSearching) return;
        manager.discoveredServers = [];
        connectionStatus = Loc.t("Searching for servers in network...");
        mdns.startDiscovery(host);
    }

    function connectWithParams(newHost, newPort, newToken, ssl) {
        autoReconnectTimer.stop();
        if (mdns) mdns.stopDiscovery();

        var cleanHost = newHost ? newHost.toString().trim() : "";
        cleanHost = cleanHost.replace(/^https?:\/\//i, "").replace(/^wss?:\/\//i, "");
        if (cleanHost.indexOf("/") !== -1) cleanHost = cleanHost.split("/")[0];
        if (cleanHost.indexOf(":") !== -1) {
            var parts = cleanHost.split(":");
            cleanHost = parts[0];
            if (parts[1] && parseInt(parts[1])) newPort = parseInt(parts[1]);
        }

        var h = cleanHost && cleanHost.length > 0 ? cleanHost : "homeassistant.local";
        var p = newPort > 0 ? newPort : 8123;
        var t = newToken ? newToken.trim() : "";
        var s = !!ssl;

        manager._updateCredentials(h, p, t, s, undefined);
        manager._connectSocket();
    }

    function disconnectFromHA() {
        autoReconnectTimer.stop();
        connTimeoutTimer.stop();
        if (webSocket.status === WebSocket.Open || webSocket.status === WebSocket.Connecting) {
            _isManualDisconnecting = true;
        }
        webSocket.active = false;
        _awaitingPong = false;
        state = "DISCONNECTED";
        connectionStatus = Loc.t("Disconnected");
        isConnected = false;

        // A request whose answer can no longer arrive still has someone waiting
        // for it: the history and the statistics sections clear their "loading"
        // line in their handler, so an unanswered one would leave them spinning
        // until the popup was rebuilt. They are answered with nothing.
        var pending = Object.keys(_customMsgHandlers);
        for (var i = 0; i < pending.length; i++) {
            var waiting = _customMsgHandlers[pending[i]];
            delete _customMsgHandlers[pending[i]];
            waiting(null);
        }
    }

    function callService(domain, service, entityId, serviceData) {
        if (!isConnected) return;
        var msgId = manager.getNextMessageId();
        var payload = HAClient.buildCallServicePayload(msgId, domain, service, serviceData || {}, entityId);
        manager.safeSend(payload);
    }

    function _handleIncomingMessage(rawMessage) {
        var parsed = HAClient.parseIncomingMessage(rawMessage);
        if (!parsed.success) return;
        var msg = parsed.data;

        if (msg.type === "pong") {
            manager._awaitingPong = false;
            return;
        }
        if (msg.type === "ping") {
            manager.safeSend(JSON.stringify({ type: "pong", id: msg.id }));
            return;
        }
        if (msg.type === "auth_required") {
            manager.safeSend(HAClient.buildAuthPayload(accessToken));
            return;
        }
        if (msg.type === "auth_ok") {
            connTimeoutTimer.stop();
            autoReconnectTimer.stop();
            isConnected = true;
            state = "CONNECTED";
            manager.failureReason = "";
            connectionStatus = Loc.t("Connected");
            _reconnectAttempts = 0;
            _awaitingPong = false;
            _listsDirty = true;
            manager.saveSharedCredentials();
            manager._subscribeToEvents();
            manager._fetchInitialStates();
            manager._fetchRegistries();
            return;
        }
        if (msg.type === "auth_invalid") {
            connTimeoutTimer.stop();
            autoReconnectTimer.stop();
            manager.disconnectFromHA();
            state = "ERROR";
            manager.failureReason = Loc.t("Invalid Access Token");
            connectionStatus = manager.failureReason;
            return;
        }

        if (msg.id && _customMsgHandlers[msg.id]) {
            var callback = _customMsgHandlers[msg.id];
            delete _customMsgHandlers[msg.id];
            if (msg.success && msg.result !== undefined) {
                callback(msg.result);
            } else {
                callback(null);
            }
            return;
        }

        if (msg.type === "event" && msg.event && msg.event.event_type === "state_changed") {
            var eventData = msg.event.data;
            if (eventData && eventData.entity_id) {
                var entId = eventData.entity_id;
                var old = manager.entities[entId];
                if (!eventData.new_state) {
                    delete manager.entities[entId];
                    delete manager._entitiesLowerMap[entId.toLowerCase()];
                    manager._notifyEntitiesChanged(true);
                } else {
                    manager.entities[entId] = eventData.new_state;
                    manager._entitiesLowerMap[entId.toLowerCase()] = eventData.new_state;
                    var oldName = old && old.attributes ? old.attributes.friendly_name : undefined;
                    var newName = eventData.new_state.attributes ? eventData.new_state.attributes.friendly_name : undefined;
                    manager._notifyEntitiesChanged(!old || oldName !== newName);
                }
            }
            return;
        }

        if (msg.type === "result" && msg.id === _getConfigMsgId && msg.success && msg.result) {
            if (msg.result.location_name) {
                manager._updateCredentials(undefined, undefined, undefined, undefined, msg.result.location_name);
                manager.saveSharedCredentials();
            }
            return;
        }

        if (msg.type === "result" && msg.id === _getStatesMsgId && msg.success && msg.result) {
            var temp = {};
            var tempLower = {};
            var list = msg.result;
            if (list && typeof list.length === "number") {
                for (var i = 0; i < list.length; i++) {
                    if (list[i] && list[i].entity_id) {
                        var eId = list[i].entity_id;
                        temp[eId] = list[i];
                        tempLower[eId.toLowerCase()] = list[i];
                    }
                }
            }
            manager.entities = temp;
            manager._entitiesLowerMap = tempLower;
            manager._notifyEntitiesChanged(true);
            return;
        }

        if (msg.type === "result" && msg.id === _getAreasMsgId && msg.success && msg.result) {
            manager.areasList = msg.result || [];
            manager._notifyEntitiesChanged(true);
            return;
        }

        if (msg.type === "result" && msg.id === _getDevicesMsgId && msg.success && msg.result) {
            var devs = msg.result || [];
            var devToArea = {};
            var byId = {};
            for (var b = 0; b < devs.length; b++) {
                if (devs[b] && devs[b].id) byId[devs[b].id] = devs[b];
            }
            manager._deviceById = byId;
            manager.devicesList = devs;
            for (var d = 0; d < devs.length; d++) {
                if (devs[d].id && devs[d].area_id) {
                    devToArea[devs[d].id] = devs[d].area_id;
                }
            }
            manager._tempDeviceToAreaMap = devToArea;
            _getEntityRegMsgId = manager.getNextMessageId();
            manager.safeSend(HAClient.buildGetEntityRegistryPayload(_getEntityRegMsgId));
            return;
        }

        if (msg.type === "result" && msg.id === _getEntityRegMsgId && msg.success && msg.result) {
            var entReg = msg.result || [];
            var entToArea = {};
            var entToDev = {};
            var devToEnts = {};
            var regMap = {};

            for (var e = 0; e < entReg.length; e++) {
                var item = entReg[e];
                if (item.entity_id) {
                    var isDisabled = (item.disabled_by !== null && item.disabled_by !== undefined);
                    var isHidden = (item.hidden_by !== null && item.hidden_by !== undefined);

                    regMap[item.entity_id] = {
                        disabled: isDisabled,
                        hidden: isHidden,
                        category: item.entity_category || null
                    };

                    if (isDisabled || isHidden) continue;

                    var areaId = item.area_id || (item.device_id ? manager._tempDeviceToAreaMap[item.device_id] : null);
                    if (areaId) entToArea[item.entity_id] = areaId;
                    if (item.device_id) {
                        entToDev[item.entity_id] = item.device_id;
                        if (!devToEnts[item.device_id]) devToEnts[item.device_id] = [];
                        devToEnts[item.device_id].push(item.entity_id);
                    }
                }
            }
            manager.entityRegistryMap = regMap;
            manager.entityToAreaMap = entToArea;
            manager.entityToDeviceMap = entToDev;
            manager.deviceToEntitiesMap = devToEnts;
            manager._notifyEntitiesChanged(true);
            return;
        }
    }

    function _subscribeToEvents() {
        manager.safeSend(HAClient.buildSubscribeEventsPayload(manager.getNextMessageId()));
    }

    function _fetchInitialStates() {
        _getConfigMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetConfigPayload(_getConfigMsgId));

        _getStatesMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetStatesPayload(_getStatesMsgId));
    }

    function _fetchRegistries() {
        _getAreasMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetAreasPayload(_getAreasMsgId));

        _getDevicesMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetDevicesPayload(_getDevicesMsgId));
    }
}
