#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
SERVICE_SECRET=$(openssl rand -hex 32)

SQL_FILE="create_vikunja_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
-- =============================================================================
-- Step 1: Execute on the server level (default database, e.g. postgres)
-- =============================================================================
CREATE USER vikunja_app WITH PASSWORD '$DB_PASSWORD';
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
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated VIKUNJA_SERVICE_SECRET is: $SERVICE_SECRET"
