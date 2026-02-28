#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DB_NAME="${POSTGRES_DATABASE:-chatwoot_dev}"
DB_USER="${POSTGRES_USERNAME:-postgres}"
BACKUP_DIR="${SAFE_MIGRATE_BACKUP_DIR:-$ROOT_DIR/tmp/db-backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/pre-migrate-$DB_NAME-$TIMESTAMP.dump"

mkdir -p "$BACKUP_DIR"

echo "[safe-migrate] Reading pre-migration counters..."
BEFORE_COUNTS="$(docker compose exec -T postgres sh -lc "PGPASSWORD=\"\$POSTGRES_PASSWORD\" psql -U \"$DB_USER\" -d \"$DB_NAME\" -Atc \"select (select count(*) from users), (select count(*) from accounts), (select count(*) from contacts), (select count(*) from schema_migrations);\"")"
IFS='|' read -r BEFORE_USERS BEFORE_ACCOUNTS BEFORE_CONTACTS BEFORE_MIGRATIONS <<< "$BEFORE_COUNTS"

echo "[safe-migrate] Creating backup: $BACKUP_FILE"
docker compose exec -T postgres sh -lc "PGPASSWORD=\"\$POSTGRES_PASSWORD\" pg_dump -U \"$DB_USER\" -d \"$DB_NAME\" -Fc" > "$BACKUP_FILE"

echo "[safe-migrate] Running migrations..."
docker compose exec -T rails bundle exec rails db:migrate

echo "[safe-migrate] Reading post-migration counters..."
AFTER_COUNTS="$(docker compose exec -T postgres sh -lc "PGPASSWORD=\"\$POSTGRES_PASSWORD\" psql -U \"$DB_USER\" -d \"$DB_NAME\" -Atc \"select (select count(*) from users), (select count(*) from accounts), (select count(*) from contacts), (select count(*) from schema_migrations);\"")"
IFS='|' read -r AFTER_USERS AFTER_ACCOUNTS AFTER_CONTACTS AFTER_MIGRATIONS <<< "$AFTER_COUNTS"

echo "[safe-migrate] Before: users=$BEFORE_USERS accounts=$BEFORE_ACCOUNTS contacts=$BEFORE_CONTACTS migrations=$BEFORE_MIGRATIONS"
echo "[safe-migrate] After:  users=$AFTER_USERS accounts=$AFTER_ACCOUNTS contacts=$AFTER_CONTACTS migrations=$AFTER_MIGRATIONS"

if { [ "$BEFORE_USERS" -gt 0 ] && [ "$AFTER_USERS" -eq 0 ]; } || \
   { [ "$BEFORE_ACCOUNTS" -gt 0 ] && [ "$AFTER_ACCOUNTS" -eq 0 ]; } || \
   { [ "$BEFORE_CONTACTS" -gt 0 ] && [ "$AFTER_CONTACTS" -eq 0 ]; }; then
  echo "[safe-migrate] Critical data loss detected. Rolling back from backup..."
  docker compose stop rails sidekiq >/dev/null || true
  cat "$BACKUP_FILE" | docker compose exec -T postgres sh -lc "PGPASSWORD=\"\$POSTGRES_PASSWORD\" pg_restore -U \"$DB_USER\" -d \"$DB_NAME\" --clean --if-exists --no-owner --no-privileges"
  docker compose start rails sidekiq >/dev/null || true
  echo "[safe-migrate] Rollback complete. Migration aborted."
  exit 1
fi

echo "[safe-migrate] Success. Backup kept at: $BACKUP_FILE"
