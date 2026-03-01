// src/controllers/health.controller.js

const config = require("../config");

function health(req, res) {
  res.status(200).json({
    status: "ok",
    service: config.serviceName,
    environment: config.appEnv,
    timestamp: new Date().toISOString(),
    store: config.storeBackend
  });
}

module.exports = { health };