#!/bin/bash

# Generate secure random secrets
DB_PASSWORD=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)
COOKIE_SECRET=$(openssl rand -hex 32)

echo "Your generated TRACEARR_DB_PASSWORD is: $DB_PASSWORD"
echo "Your generated TRACEARR_JWT_SECRET is:   $JWT_SECRET"
echo "Your generated TRACEARR_COOKIE_SECRET is: $COOKIE_SECRET"
