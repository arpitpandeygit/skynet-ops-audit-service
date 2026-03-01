// src/store/sqlite.store.js

const sqlite3 = require("sqlite3").verbose();
const config = require("../config");

const db = new sqlite3.Database(config.databaseUrl);

db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS events (
      eventId TEXT PRIMARY KEY,
      type TEXT,
      tenantId TEXT,
      severity TEXT,
      message TEXT,
      source TEXT,
      metadata TEXT,
      occurredAt TEXT,
      traceId TEXT,
      storedAt TEXT
    )
  `);
});

function insert(event) {
  const stmt = db.prepare(`
    INSERT INTO events (
      eventId, type, tenantId, severity,
      message, source, metadata,
      occurredAt, traceId, storedAt
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  stmt.run(
    event.eventId,
    event.type,
    event.tenantId,
    event.severity,
    event.message,
    event.source,
    JSON.stringify(event.metadata || null),
    event.occurredAt,
    event.traceId || null,
    event.storedAt
  );

  stmt.finalize();
}

function query({ tenantId, severity, type, limit, offset }) {
  return new Promise((resolve, reject) => {
    let filters = [];
    let params = [];

    if (tenantId) {
      filters.push("tenantId = ?");
      params.push(tenantId);
    }

    if (severity) {
      filters.push("severity = ?");
      params.push(severity);
    }

    if (type) {
      filters.push("type = ?");
      params.push(type);
    }

    let whereClause =
      filters.length > 0
        ? "WHERE " + filters.join(" AND ")
        : "";

    const queryStr = `
      SELECT * FROM events
      ${whereClause}
      ORDER BY datetime(storedAt) DESC
      LIMIT ? OFFSET ?
    `;

    db.all(
      queryStr,
      [...params, limit, offset],
      (err, rows) => {
        if (err) return reject(err);

        db.get(
          `SELECT COUNT(*) as count FROM events ${whereClause}`,
          params,
          (err2, countRow) => {
            if (err2) return reject(err2);

            const items = rows.map(r => ({
              ...r,
              metadata: r.metadata
                ? JSON.parse(r.metadata)
                : null
            }));

            resolve({
              items,
              total: countRow.count
            });
          }
        );
      }
    );
  });
}

module.exports = { insert, query };