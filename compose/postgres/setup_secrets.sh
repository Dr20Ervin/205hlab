#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)

# Output the results to the terminal
echo "Your generated POSTGRES_PASSWORD is: $DB_PASSWORD"
