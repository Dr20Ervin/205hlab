#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
ADMIN_PASSWORD=$(openssl rand -base64 16)
OIDC_KEY=$(openssl rand -base64 32)

SQL_FILE="create_freshrss_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER freshrss_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE freshrss OWNER freshrss_app;
GRANT ALL PRIVILEGES ON DATABASE freshrss TO freshrss_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated ADMIN_PASSWORD is: $ADMIN_PASSWORD"
echo "Your generated OIDC_CLIENT_CRYPTO_KEY is: $OIDC_KEY"
