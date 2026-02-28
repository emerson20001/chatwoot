#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid

# Avoid expensive reinstall on every container restart.
# Install dependencies only when node_modules is missing.
if [ ! -d "/app/node_modules/.pnpm" ]; then
  pnpm install --frozen-lockfile
fi

if [ ! -f "/app/public/packs/js/sdk.js" ]; then
  echo "Building Chatwoot SDK..."
  pnpm build:sdk
fi

echo "Ready to run Vite development server."

exec "$@"
