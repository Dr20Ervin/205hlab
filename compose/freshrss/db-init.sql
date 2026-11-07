-- Create a random password for freshrss user: openssl rand -hex 16
CREATE USER freshrss_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE freshrss OWNER freshrss_app;
GRANT ALL PRIVILEGES ON DATABASE freshrss TO freshrss_app;
