// src/services/event.service.js

const config = require("../config");
const generateEventId = require("../utils/id");
const logger = require("../utils/logger");

let store;

if (config.storeBackend === "sqlite") {
  store = require("../store/sqlite.store");
} else {
  store = require("../store/memory.store");
}

async function createEvent(payload) {
  const now = new Date().toISOString();

  const event = {
    eventId: generateEventId(),
    type: payload.type,
    tenantId: payload.tenantId,
    severity: payload.severity,
    message: payload.message,
    source: payload.source,
    metadata: payload.metadata || null,
    occurredAt: payload.occurredAt || now,
    traceId: payload.traceId || null,
    storedAt: now
  };

  await store.insert(event);

  logger.info({ eventId: event.eventId }, "Event stored");

  return {
    success: true,
    eventId: event.eventId,
    storedAt: event.storedAt
  };
}

async function getEvents(queryParams) {
  const limit = parseInt(queryParams.limit || "20", 10);
  const offset = parseInt(queryParams.offset || "0", 10);

  const result = await store.query({
    tenantId: queryParams.tenantId,
    severity: queryParams.severity,
    type: queryParams.type,
    limit,
    offset
  });

  return {
    items: result.items,
    total: result.total,
    limit,
    offset
  };
}

module.exports = { createEvent, getEvents };