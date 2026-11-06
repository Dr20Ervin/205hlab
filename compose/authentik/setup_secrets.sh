#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
SECRET_KEY=$(openssl rand -base64 36)

SQL_FILE="create_authentik_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER authentik WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE authentik OWNER authentik;
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated DATABASE_PASSWORD is: $DB_PASSWORD"
echo "Your generated AUTHENTIK_SECRET_KEY is: $SECRET_KEY"