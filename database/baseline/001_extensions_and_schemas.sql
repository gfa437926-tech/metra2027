-- METRA baseline 001 — extensions and schemas
-- Isolated / empty PostgreSQL only. Not a hosted apply authorization.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS public;
