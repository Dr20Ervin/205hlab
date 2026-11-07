#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
SESSION_SECRET=$(openssl rand -base64 36)

SQL_FILE="create_qui_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER qui_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE qui OWNER qui_app;
GRANT ALL PRIVILEGES ON DATABASE qui TO qui_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated QUI_DATABASE_PASSWORD is: $DB_PASSWORD"
echo "Your generated QUI_SESSION_SECRET is: $SESSION_SECRET"
