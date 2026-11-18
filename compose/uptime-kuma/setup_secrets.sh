#!/bin/bash

# Generate secure random secrets for Uptime Kuma MariaDB
KUMA_DB_PASSWORD=$(openssl rand -hex 16)
KUMA_DB_ROOT_PASSWORD=$(openssl rand -hex 24)

ENV_FILE=".env"

if [ -f "$ENV_FILE" ]; then
    echo "Found existing $ENV_FILE, updating passwords..."
    sed -i "s/^KUMA_DB_PASSWORD=.*/KUMA_DB_PASSWORD=$KUMA_DB_PASSWORD/" "$ENV_FILE"
    sed -i "s/^KUMA_DB_ROOT_PASSWORD=.*/KUMA_DB_ROOT_PASSWORD=$KUMA_DB_ROOT_PASSWORD/" "$ENV_FILE"
else
    echo "Creating new $ENV_FILE from example.env..."
    cp example.env "$ENV_FILE"
    sed -i "s/^KUMA_DB_PASSWORD=.*/KUMA_DB_PASSWORD=$KUMA_DB_PASSWORD/" "$ENV_FILE"
    sed -i "s/^KUMA_DB_ROOT_PASSWORD=.*/KUMA_DB_ROOT_PASSWORD=$KUMA_DB_ROOT_PASSWORD/" "$ENV_FILE"
fi

echo "Successfully configured MariaDB passwords in $ENV_FILE"
echo "KUMA_DB_PASSWORD: $KUMA_DB_PASSWORD"
echo "KUMA_DB_ROOT_PASSWORD: $KUMA_DB_ROOT_PASSWORD"
