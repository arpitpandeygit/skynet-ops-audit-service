// src/utils/logger.js

const pino = require("pino");
const config = require("../config");

const logger = pino({
  level: config.logLevel,
  base: {
    service: config.serviceName,
    environment: config.appEnv
  },
  timestamp: pino.stdTimeFunctions.isoTime
});

module.exports = logger;