-- Database and User initialization for Servarr stack (PostgreSQL)

-- Prowlarr
CREATE USER prowlarr_app WITH PASSWORD 'your_prowlarr_password';
CREATE DATABASE "prowlarr-main" OWNER prowlarr_app;
CREATE DATABASE "prowlarr-log" OWNER prowlarr_app;
GRANT ALL PRIVILEGES ON DATABASE "prowlarr-main" TO prowlarr_app;
GRANT ALL PRIVILEGES ON DATABASE "prowlarr-log" TO prowlarr_app;

-- Radarr
CREATE USER radarr_app WITH PASSWORD 'your_radarr_password';
CREATE DATABASE "radarr-main" OWNER radarr_app;
CREATE DATABASE "radarr-log" OWNER radarr_app;
GRANT ALL PRIVILEGES ON DATABASE "radarr-main" TO radarr_app;
GRANT ALL PRIVILEGES ON DATABASE "radarr-log" TO radarr_app;

-- Sonarr
CREATE USER sonarr_app WITH PASSWORD 'your_sonarr_password';
CREATE DATABASE "sonarr-main" OWNER sonarr_app;
CREATE DATABASE "sonarr-log" OWNER sonarr_app;
GRANT ALL PRIVILEGES ON DATABASE "sonarr-main" TO sonarr_app;
GRANT ALL PRIVILEGES ON DATABASE "sonarr-log" TO sonarr_app;

-- Lidarr
CREATE USER lidarr_app WITH PASSWORD 'your_lidarr_password';
CREATE DATABASE "lidarr-main" OWNER lidarr_app;
CREATE DATABASE "lidarr-log" OWNER lidarr_app;
GRANT ALL PRIVILEGES ON DATABASE "lidarr-main" TO lidarr_app;
GRANT ALL PRIVILEGES ON DATABASE "lidarr-log" TO lidarr_app;
