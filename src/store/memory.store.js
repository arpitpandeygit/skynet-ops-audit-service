// src/store/memory.store.js

let events = [];

function insert(event) {
  events.push(event);
}

function query({ tenantId, severity, type, limit, offset }) {
  let result = [...events];

  if (tenantId)
    result = result.filter(e => e.tenantId === tenantId);

  if (severity)
    result = result.filter(e => e.severity === severity);

  if (type)
    result = result.filter(e => e.type === type);

  result.sort((a, b) =>
    new Date(b.storedAt) - new Date(a.storedAt)
  );

  const total = result.length;
  const paginated = result.slice(offset, offset + limit);

  return { items: paginated, total };
}

module.exports = { insert, query };