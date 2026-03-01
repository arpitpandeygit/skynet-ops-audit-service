// src/app.js

const express = require("express");
const config = require("./config");
const logger = require("./utils/logger");

const healthRoutes = require("./routes/health.routes");
const eventRoutes = require("./routes/events.routes");

const errorHandler =
  require("./middleware/error.middleware");

const app = express();

app.use(express.json());

app.use((err, req, res, next) => {
  if (err instanceof SyntaxError) {
    return res.status(400).json({
      error: "Invalid JSON"
    });
  }
  next();
});

app.use(healthRoutes);
app.use(eventRoutes);

app.use(errorHandler);

logger.info("App initialized");

module.exports = app;