#!/bin/bash

# Generate secure random secrets
PROWLARR_PASS=$(openssl rand -hex 16)
RADARR_PASS=$(openssl rand -hex 16)
SONARR_PASS=$(openssl rand -hex 16)
LIDARR_PASS=$(openssl rand -hex 16)
CHAPTARR_PASS=$(openssl rand -hex 16)
PROFILARR_KEY=$(openssl rand -hex 16)

SQL_FILE="create_servarr_dbs.sql"

cat <<EOF > "$SQL_FILE"
-- Prowlarr
CREATE USER prowlarr_app WITH PASSWORD '$PROWLARR_PASS';
CREATE DATABASE "prowlarr-main" OWNER prowlarr_app;
CREATE DATABASE "prowlarr-log" OWNER prowlarr_app;
GRANT ALL PRIVILEGES ON DATABASE "prowlarr-main" TO prowlarr_app;
GRANT ALL PRIVILEGES ON DATABASE "prowlarr-log" TO prowlarr_app;

-- Radarr
CREATE USER radarr_app WITH PASSWORD '$RADARR_PASS';
CREATE DATABASE "radarr-main" OWNER radarr_app;
CREATE DATABASE "radarr-log" OWNER radarr_app;
GRANT ALL PRIVILEGES ON DATABASE "radarr-main" TO radarr_app;
GRANT ALL PRIVILEGES ON DATABASE "radarr-log" TO radarr_app;

-- Sonarr
CREATE USER sonarr_app WITH PASSWORD '$SONARR_PASS';
CREATE DATABASE "sonarr-main" OWNER sonarr_app;
CREATE DATABASE "sonarr-log" OWNER sonarr_app;
GRANT ALL PRIVILEGES ON DATABASE "sonarr-main" TO sonarr_app;
GRANT ALL PRIVILEGES ON DATABASE "sonarr-log" TO sonarr_app;

-- Lidarr
CREATE USER lidarr_app WITH PASSWORD '$LIDARR_PASS';
CREATE DATABASE "lidarr-main" OWNER lidarr_app;
CREATE DATABASE "lidarr-log" OWNER lidarr_app;
GRANT ALL PRIVILEGES ON DATABASE "lidarr-main" TO lidarr_app;
GRANT ALL PRIVILEGES ON DATABASE "lidarr-log" TO lidarr_app;

-- Chaptarr
CREATE USER chaptarr_app WITH PASSWORD '$CHAPTARR_PASS' CREATEDB;
CREATE DATABASE "chaptarr-main" OWNER chaptarr_app;
CREATE DATABASE "chaptarr-log" OWNER chaptarr_app;
CREATE DATABASE "chaptarr-cache" OWNER chaptarr_app;
GRANT ALL PRIVILEGES ON DATABASE "chaptarr-main" TO chaptarr_app;
GRANT ALL PRIVILEGES ON DATABASE "chaptarr-log" TO chaptarr_app;
GRANT ALL PRIVILEGES ON DATABASE "chaptarr-cache" TO chaptarr_app;
EOF

echo "Successfully created: $SQL_FILE"
echo "PROWLARR_DB_PASSWORD: $PROWLARR_PASS"
echo "RADARR_DB_PASSWORD:   $RADARR_PASS"
echo "SONARR_DB_PASSWORD:   $SONARR_PASS"
echo "LIDARR_DB_PASSWORD:   $LIDARR_PASS"
echo "CHAPTARR_DB_PASSWORD: $CHAPTARR_PASS"
echo "PROFILARR_API_KEY:    $PROFILARR_KEY"
