#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
SECRET_KEY=$(openssl rand -hex 32)

SQL_FILE="create_paperless_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER paperless_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE paperless OWNER paperless_app;
GRANT ALL PRIVILEGES ON DATABASE paperless TO paperless_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated PAPERLESS_SECRET_KEY is: $SECRET_KEY"
