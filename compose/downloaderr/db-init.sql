-- Create a random password for qui user: openssl rand -hex 16
CREATE USER qui_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE qui OWNER qui_app;
GRANT ALL PRIVILEGES ON DATABASE qui TO qui_app;
