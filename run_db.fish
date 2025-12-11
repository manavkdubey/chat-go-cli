#!/usr/bin/env fish
# run_db.fish
# Usage: ./run_db.fish
# Requires: fish shell, psql/initdb/pg_ctl/createuser/createdb in PATH (Homebrew postgresql provides them)

set -l PGDATA_DIR ./pgdata
set -l DB_USER postgres
set -l DB_PASS pass
set -l DB_NAME myapp_dev
set -l PG_PORT 5432

echo "=== quick checks ==="
if not type -q initdb
    echo "ERROR: postgres client/server tools not found (initdb)."
    echo "Install Postgres (Homebrew): brew install postgresql"
    exit 1
end

if not type -q psql
    echo "ERROR: psql not found. Install Postgres client (Homebrew): brew install postgresql"
    exit 1
end

if test -d $PGDATA_DIR
    echo "pgdata already exists at $PGDATA_DIR — skipping initdb"
else
    echo "Initializing new Postgres cluster at $PGDATA_DIR ..."
    initdb -D $PGDATA_DIR
    if test $status -ne 0
        echo "initdb failed"
        exit 1
    end
end

echo "Starting Postgres (pg_ctl -D $PGDATA_DIR) ..."
pg_ctl -D $PGDATA_DIR -l $PGDATA_DIR/logfile start

set -l tries 0
while test $tries -lt 15
    pg_isready -h localhost -p $PG_PORT >/dev/null 2>&1
    if test $status -eq 0
        break
    end
    sleep 1
    set tries (math $tries + 1)
end

if test $tries -ge 15
    echo "Postgres did not become ready in time. Check $PGDATA_DIR/logfile"
    exit 1
end

echo "Postgres is ready."


echo "Ensuring superuser '$DB_USER' exists..."
if not docker 2>/dev/null
    createuser -s $DB_USER >/dev/null 2>&1 || true
    psql -v ON_ERROR_STOP=1 -U $DB_USER -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';" >/dev/null 2>&1 || \
    psql -v ON_ERROR_STOP=1 -U (whoami) -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';" >/dev/null 2>&1 || true
else
    echo "Docker detected; skipping createuser host flow."
end

echo "Creating database $DB_NAME (if not exists)..."
createdb -h localhost -U $DB_USER $DB_NAME >/dev/null 2>&1 || true

echo "Enabling pgcrypto extension on $DB_NAME (for gen_random_uuid())..."
psql "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME?sslmode=disable" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >/dev/null 2>&1
if test $status -ne 0
    echo "Warning: failed to enable pgcrypto. You may need to run the command manually."
end

if test -d migrations
    for f in migrations/*.up.sql
        if test -f $f
            echo "running $f ..."
            psql "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME?sslmode=disable" -v ON_ERROR_STOP=1 -f $f
            if test $status -ne 0
                echo "ERROR: migration failed: $f"
                exit 1
            end
        end
    end
else
    echo "No migrations/ directory found; skipping migration run."
end

echo "=== verification ==="
psql "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME?sslmode=disable" -c '\dt'

echo ""
echo "Done. Postgres running with data in $PGDATA_DIR."
echo "To stop the DB: pg_ctl -D $PGDATA_DIR stop"
echo "To remove DB files (wipe): pg_ctl -D $PGDATA_DIR stop; rm -rf $PGDATA_DIR"
