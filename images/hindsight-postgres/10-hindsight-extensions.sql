-- The official PostgreSQL entrypoint runs this once for the initial database.
-- Hindsight's startup migration verifies the same extensions and exact versions.
\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS pgroonga;
CREATE EXTENSION IF NOT EXISTS vector;
