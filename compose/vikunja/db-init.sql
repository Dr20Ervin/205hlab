-- =============================================================================
-- Step 1: Execute on the server level (default database, e.g. postgres)
-- =============================================================================
-- Generate a random password: openssl rand -hex 16
CREATE USER vikunja_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE vikunja OWNER vikunja_app;
GRANT ALL PRIVILEGES ON DATABASE vikunja TO vikunja_app;

-- =============================================================================
-- Step 2 (Optional - Vikunja 2.8+ Accent-Insensitive Search):
-- Extensions are database-specific. Do NOT run with '\c' in Adminer or GUI.
-- 1. In Adminer/GUI: Switch/select the 'vikunja' database in the dropdown/sidebar.
--    (Or in psql CLI: \c vikunja)
-- 2. Open SQL Command and execute:
-- =============================================================================
-- CREATE EXTENSION IF NOT EXISTS unaccent;
-- GRANT ALL ON SCHEMA public TO vikunja_app;
