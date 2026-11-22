.pragma library

var _idCounter = 1;

function getNextId() {
    return _idCounter++;
}

function parseIncomingMessage(messageStr) {
    try {
        var data = JSON.parse(messageStr);
        return { success: true, data: data };
    } catch (e) {
        return { success: false, error: e };
    }
}

function buildAuthPayload(token) {
    return JSON.stringify({
        type: "auth",
        access_token: token
    });
}

function buildSubscribeEventsPayload(msgId, eventType) {
    return JSON.stringify({
        id: msgId,
        type: "subscribe_events",
        event_type: eventType || "state_changed"
    });
}

function buildGetStatesPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "get_states"
    });
}

function buildGetConfigPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "get_config"
    });
}

function buildGetAreasPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/area_registry/list"
    });
}

function buildGetDevicesPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/device_registry/list"
    });
}

function buildGetEntityRegistryPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/entity_registry/list"
    });
}

function buildHistoryPayload(msgId, entityIds, startTime, endTime, minimalResponse, noAttributes) {
    return JSON.stringify({
        id: msgId,
        type: "history/history_during_period",
        start_time: startTime,
        end_time: endTime,
        entity_ids: Array.isArray(entityIds) ? entityIds : [entityIds],
        // The history section lists states and the moments they changed, so the
        // compact answer is the one it can show; a full one is bandwidth for the
        // chart this popup has no room for.
        minimal_response: minimalResponse !== false,
        no_attributes: noAttributes !== false
    });
}

function buildCallServicePayload(msgId, domain, service, serviceData, targetEntityId) {
    var payload = {
        id: msgId,
        type: "call_service",
        domain: domain,
        service: service,
        service_data: serviceData || {}
    };

    if (targetEntityId) {
        payload.target = {
            entity_id: targetEntityId
        };
    }

    return JSON.stringify(payload);
}
