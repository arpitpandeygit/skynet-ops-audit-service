#!/bin/bash

echo "Starting Skynet Ops Audit Service (Local Dev)"

if [ ! -f .env ]; then
  echo "Copying .env.example to .env"
  cp .env.example .env
fi

npm run dev