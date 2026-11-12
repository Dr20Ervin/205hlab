#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
APP_KEY=$(openssl rand -base64 32)

SQL_FILE="create_speedtest_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER speedtest_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE speedtest_tracker OWNER speedtest_app;
GRANT ALL PRIVILEGES ON DATABASE speedtest_tracker TO speedtest_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated APP_KEY is: base64:$APP_KEY"
