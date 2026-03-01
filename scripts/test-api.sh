#!/bin/bash

echo "Testing Health Endpoint"
curl -s http://localhost:8080/health | jq

echo "Posting Sample Event"
curl -X POST http://localhost:8080/events \
  -H "Content-Type: application/json" \
  -d '{
    "type":"roster_update",
    "tenantId":"academy_001",
    "severity":"info",
    "message":"Test event",
    "source":"cli-test"
  }'

echo ""
echo "Fetching Events"
curl -s http://localhost:8080/events | jq