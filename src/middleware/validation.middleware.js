// src/middleware/validation.middleware.js

const config = require("../config");

const allowedSeverities = [
  "info",
  "warning",
  "error",
  "critical"
];

function validateEvent(req, res, next) {
  const {
    type,
    tenantId,
    severity,
    message,
    source
  } = req.body;

  if (!type || !tenantId || !severity || !message || !source) {
    return res.status(400).json({
      error: "Missing required fields"
    });
  }

  if (tenantId.trim() === "") {
    return res.status(400).json({
      error: "tenantId must be non-empty"
    });
  }

  if (message.trim() === "") {
    return res.status(400).json({
      error: "message must be non-empty"
    });
  }

  if (!allowedSeverities.includes(severity)) {
    return res.status(400).json({
      error: "Invalid severity"
    });
  }

  next();
}

function validateQuery(req, res, next) {
  let { limit } = req.query;

  limit = parseInt(limit || "20", 10);

  if (limit > config.maxEventsLimit) {
    return res.status(400).json({
      error: `limit cannot exceed ${config.maxEventsLimit}`
    });
  }

  next();
}

module.exports = { validateEvent, validateQuery };