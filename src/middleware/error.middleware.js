// src/middleware/error.middleware.js

const logger = require("../utils/logger");

function errorHandler(err, req, res, next) {
  logger.error({ err }, "Unhandled error");

  res.status(500).json({
    error: "Internal Server Error"
  });
}

module.exports = errorHandler;