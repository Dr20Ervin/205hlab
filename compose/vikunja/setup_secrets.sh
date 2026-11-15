#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)

SQL_FILE="create_vikunja_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER vikunja_app WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE vikunja OWNER vikunja_app;
GRANT ALL PRIVILEGES ON DATABASE vikunja TO vikunja_app;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated VIKUNJA_JWT_SECRET is: $JWT_SECRET"
