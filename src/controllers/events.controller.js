// src/controllers/events.controller.js

const eventService = require("../services/event.service");

async function create(req, res, next) {
  try {
    const result = await eventService.createEvent(req.body);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

async function list(req, res, next) {
  try {
    const result = await eventService.getEvents(req.query);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { create, list };