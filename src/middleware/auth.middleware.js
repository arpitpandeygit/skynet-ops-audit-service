// src/middleware/auth.middleware.js

const config = require("../config");

function apiKeyAuth(req, res, next) {
  if (!config.apiKey) {
    return next(); // No auth configured
  }

  const incomingKey = req.headers["x-api-key"];

  if (!incomingKey || incomingKey !== config.apiKey) {
    return res.status(401).json({
      error: "Unauthorized"
    });
  }

  next();
}

module.exports = apiKeyAuth;