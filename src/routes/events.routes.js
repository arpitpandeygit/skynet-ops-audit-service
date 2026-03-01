// src/routes/events.routes.js

const express = require("express");
const router = express.Router();

const {
  create,
  list
} = require("../controllers/events.controller");

const { metricsDemo } =
  require("../controllers/metrics.controller");

const {
  validateEvent,
  validateQuery
} = require("../middleware/validation.middleware");

const apiKeyAuth =
  require("../middleware/auth.middleware");

/*
  Routes:

  POST   /events
  GET    /events
  GET    /metrics-demo

  Spec aligned with:
  - Validation rules
  - Optional auth
  - Metrics demo support
*/

// Ingest event
router.post(
  "/events",
  apiKeyAuth,
  validateEvent,
  create
);

// Retrieve events
router.get(
  "/events",
  apiKeyAuth,
  validateQuery,
  list
);

// Metrics testing endpoint (optional but recommended)
router.get(
  "/metrics-demo",
  apiKeyAuth,
  metricsDemo
);

module.exports = router;