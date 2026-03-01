// src/controllers/metrics.controller.js

const logger = require("../utils/logger");
const config = require("../config");

async function metricsDemo(req, res) {
  if (!config.metricsDemoEnabled) {
    return res.status(404).json({
      error: "metrics-demo disabled"
    });
  }

  const mode = req.query.mode;

  if (mode === "error") {
    logger.error("Simulated error triggered");
    return res.status(500).json({
      error: "Simulated error"
    });
  }

  if (mode === "slow") {
    const delay = Math.floor(Math.random() * 2000) + 1000;
    await new Promise(resolve => setTimeout(resolve, delay));
    logger.warn({ delay }, "Simulated slow request");
    return res.status(200).json({
      status: "slow-response",
      delay
    });
  }

  if (mode === "burst") {
    for (let i = 0; i < 5; i++) {
      logger.info({ iteration: i }, "Burst log");
    }
    return res.status(200).json({
      status: "burst-logs-emitted"
    });
  }

  return res.status(200).json({
    status: "metrics-demo-ok"
  });
}

module.exports = { metricsDemo };