#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)

SQL_FILE="create_mealie_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER mealie_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE mealie OWNER mealie_app;
GRANT ALL PRIVILEGES ON DATABASE mealie TO mealie_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
