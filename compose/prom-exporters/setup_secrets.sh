#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)

SQL_FILE="create_postgres_exporter_user.sql"

# Create and populate the SQL file with the generated password
cat <<EOF > "$SQL_FILE"
CREATE USER postgres_exporter WITH PASSWORD '$DB_PASSWORD';
GRANT pg_monitor TO postgres_exporter;
EOF

# Output the results to the terminal
echo "Successfully created: $SQL_FILE"
echo "Your generated POSTGRES_EXPORTER_PASSWORD is: $DB_PASSWORD"
