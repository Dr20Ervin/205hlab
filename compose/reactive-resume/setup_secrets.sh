#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
AUTH_SECRET=$(openssl rand -hex 32)
ENCRYPTION_SECRET=$(openssl rand -hex 32)

SQL_FILE="create_reactive-resume_db.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER "reactive-resume_app" WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE "reactive-resume" OWNER "reactive-resume_app";
GRANT ALL PRIVILEGES ON DATABASE "reactive-resume" TO "reactive-resume_app";
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
echo "Your generated AUTH_SECRET is: $AUTH_SECRET"
echo "Your generated ENCRYPTION_SECRET is: $ENCRYPTION_SECRET"
