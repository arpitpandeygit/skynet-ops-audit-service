// src/utils/id.js

const { randomUUID } = require("crypto");

function generateEventId() {
  return `evt_${randomUUID().replace(/-/g, "").slice(0, 14)}`;
}

module.exports = generateEventId;