// src/config.js

require("dotenv").config();

const config = {
  port: process.env.PORT || 8080,
  appEnv: process.env.APP_ENV || process.env.NODE_ENV || "dev",

  serviceName:
    process.env.SERVICE_NAME || "skynet-ops-audit-service",

  logLevel: process.env.LOG_LEVEL || "info",

  storeBackend: process.env.STORE_BACKEND || "memory",

  databaseUrl:
    process.env.DATABASE_URL || "/tmp/events.db",

  metricsDemoEnabled:
    process.env.METRICS_DEMO_ENABLED === "true",

  apiKey: process.env.API_KEY || null,

  maxEventsLimit: parseInt(
    process.env.MAX_EVENTS_LIMIT || "100",
    10
  )
};

module.exports = config;