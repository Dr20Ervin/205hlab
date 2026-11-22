#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
APP_SECRET=$(openssl rand -hex 32)

SQL_FILE="create_umami_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER umami_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE umami OWNER umami_app;
GRANT ALL PRIVILEGES ON DATABASE umami TO umami_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated UMAMI_APP_SECRET is: $APP_SECRET"
