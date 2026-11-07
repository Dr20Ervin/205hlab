-- Create a random password for mealie user: openssl rand -hex 16
CREATE USER mealie_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE mealie OWNER mealie_app;
GRANT ALL PRIVILEGES ON DATABASE mealie TO mealie_app;
