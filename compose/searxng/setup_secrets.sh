#!/bin/bash

# Generate secure random secrets
SEARXNG_SECRET=$(openssl rand -hex 32)

# Output the results to the terminal
echo "Your generated SEARXNG_SECRET is: $SEARXNG_SECRET"
