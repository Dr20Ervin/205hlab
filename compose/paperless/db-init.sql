-- Create a random password for paperless user: openssl rand -hex 16
CREATE USER paperless_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE paperless OWNER paperless_app;
GRANT ALL PRIVILEGES ON DATABASE paperless TO paperless_app;
