---
name: psql
description: Query PostgreSQL databases using psql. Use when the user asks to run SQL queries, inspect database schema, list tables/columns, check data, or interact with a Postgres database.
argument-hint: <query or meta-command> [connection options]
allowed-tools: Bash(psql:*)
---

Use `psql` to interact with a PostgreSQL database for the user.

The user asked: $ARGUMENTS

## Connection

If the user has not specified connection details, check for a running local Postgres instance first. Common connection patterns:
- `psql -U user -d dbname` — connect to a specific database
- `psql -h host -p port -U user -d dbname` — remote connection
- `psql "connection_string"` — use a connection URI
- `psql` with no args — uses defaults from environment variables (PGHOST, PGPORT, PGUSER, PGDATABASE)

For a deployed database, use credentials the user gives or the project's documented route. Never search a secrets store for them (listing or decrypting parameters), and never after a permission denial: ask the user, or give them the query to run. Connect read-only (`PGOPTIONS='-c default_transaction_read_only=on'`), and to the reader endpoint when there is one.

## Running queries

- `-c 'SQL'` — execute a single query
- `-f file.sql` — execute queries from a file
- `-t` — tuples only (no headers/footers)
- `-A` — unaligned output (useful for scripting)
- `-x` — expanded/vertical output (useful for wide rows)
- `--csv` — CSV output format
- `-q` — quiet mode (suppress informational messages)
- `-1` — execute as a single transaction

To find a deployed schema's drift, diff `information_schema.columns` against the environment it must match (staging against production, say), not against the migration files: that environment may have drifted from them too. Give back plain statements grouped as needed, parity-only and destructive, not a script.

## Useful meta-commands (pass via `-c`)

- `\dt` — list tables
- `\dt+` — list tables with sizes
- `\d tablename` — describe table structure
- `\di` — list indexes
- `\dv` — list views
- `\df` — list functions
- `\dn` — list schemas
- `\du` — list roles
- `\l` — list databases
- `\conninfo` — show current connection info

## Safety

- **NEVER** run destructive queries (DROP, DELETE, TRUNCATE, ALTER) without explicit user confirmation
- Prefer `SELECT` queries and read-only operations by default
- Use `LIMIT` on queries against unfamiliar tables to avoid dumping large result sets
- Use `\x` or `-x` for tables with many columns to improve readability
- Use `EXPLAIN` or `EXPLAIN ANALYSE` when the user asks about query performance
- Before giving the user SQL to run on another database, run it against local Postgres and say it ran there
- SQL for someone else to run selects `current_database()`, so its output shows where it ran
- When a result the user pastes contradicts the code or the metrics, confirm which database it ran on and check another signal (app counters, a second query) before taking a finding back

Run the appropriate `psql` command for what the user wants. Present results clearly and summarise large outputs.
