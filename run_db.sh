#!/usr/bin/env bash

set -e

PGDATA_DIR=./pgdata
DB_USER=postgres
DB_PASS=pass
DB_NAME=myapp_dev
PG_PORT=5432

echo "=== quick checks ==="

if ! command -v initdb >/dev/null 2>&1; then
    echo "ERROR: postgres tools not found (initdb)."; exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
    echo "ERROR: psql not found."; exit 1
fi

if [ -d "$PGDATA_DIR" ]; then
    echo "pgdata already exists at $PGDATA_DIR — skipping initdb"
else
    echo "Initializing new Postgres cluster at $PGDATA_DIR ..."
    initdb -D "$PGDATA_DIR" || { echo "initdb failed"; exit 1; }
fi

echo "Starting Postgres (pg_ctl -D $PGDATA_DIR) ..."
pg_ctl -D "$PGDATA_DIR" -l "$PGDATA_DIR/logfile" start

tries=0
while [ $tries -lt 15 ]; do
    pg_isready -h localhost -p $PG_PORT >/dev/null 2>&1 && break
    sleep 1
    tries=$((tries + 1))
done

if [ $tries -ge 15 ]; then
    echo "Postgres did not become ready in time. Check $PGDATA_DIR/logfile"
    exit 1
fi

echo "Postgres is ready."

echo "Ensuring superuser '$DB_USER' exists..."
if ! command -v docker >/dev/null 2>&1; then
    createuser -s "$DB_USER" >/dev/null 2>&1 || true
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';" >/dev/null 2>&1 \
        || psql -v ON_ERROR_STOP=1 -U "$(whoami)" -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';" >/dev/null 2>&1 || true
else
    echo "Docker detected; skipping createuser host flow."
fi

echo "Creating database $DB_NAME (if not exists)..."
createdb -h localhost -U "$DB_USER" "$DB_NAME" >/dev/null 2>&1 || true

echo "Enabling pgcrypto extension..."
psql "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME?sslmode=disable" \
    -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >/dev/null 2>&1 || \
    echo "Warning: failed to enable pgcrypto."

if [ -d migrations ]; then
    for f in migrations/*.up.sql; do
        if [ -f "$f" ]; then
            echo "running $f ..."
            psql "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME?sslmode=disable" \
                -v ON_ERROR_STOP=1 -f "$f" || { echo "ERROR: migration failed: $f"; exit 1; }
        fi
    done
else
    echo "No migrations/ directory found; skipping migration run."
fi

echo "=== verification ==="
psql "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME?sslmode=disable" -c '\dt'

echo ""
echo "Done. Postgres running with data in $PGDATA_DIR."
echo "To stop the DB: pg_ctl -D $PGDATA_DIR stop"
echo "To remove DB files (wipe): pg_ctl -D $PGDATA_DIR stop; rm -rf $PGDATA_DIR"
