#!/bin/bash

# Generate secure random secrets
ADMIN_PASSWORD=$(openssl rand -base64 16)

echo "Your generated DNS_SERVER_ADMIN_PASSWORD is: $ADMIN_PASSWORD"
