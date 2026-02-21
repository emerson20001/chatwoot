#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

# Install gems only when needed to keep restart time low.
bundle check || bundle install

# Keep local Docker resilient: create/migrate DB on every boot if needed.
if [ "${AUTO_PREPARE_DB:-true}" = "true" ]; then
  bundle exec rails db:version >/dev/null 2>&1 || bundle exec rails db:chatwoot_prepare
fi

# Execute the main process of the container
exec "$@"
